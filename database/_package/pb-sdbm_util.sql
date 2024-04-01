-- *
-- * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
-- * Licensed under the MIT license.
-- * See LICENSE file in the project root for full license information.
-- *


CREATE OR REPLACE PACKAGE BODY SDBM_UTIL
IS
/*********************************************************************
*
* Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
* Licensed under the MIT license.
*
**********************************************************************/
/*********************************************************************
  PACKAGE : SDBM_UTIL
  AUTEUR  : Benoit Bouthillier 2011-10-14 (2022-01-15)
 ---------------------------------------------------------------------
  BUT : Ce package permet l'implantation des procédures utilitaire
        pour le moniteur Oracle.

**********************************************************************/


   -- Constante
   C_TYPE_ENCRYPTION PLS_INTEGER := DBMS_CRYPTO.ENCRYPT_AES256 + DBMS_CRYPTO.CHAIN_CBC + DBMS_CRYPTO.PAD_PKCS5;

   -- Clé d'encryption (temporaire)
   GV_KEY_BYTES_RAW  RAW(28) := NULL;


   /******************************************************************
     PROCEDURE : MAINTENANCE
     AUTEUR    : Benoit Bouthillier 2009-06-30 (2021-03-18)
    ------------------------------------------------------------------
     BUT : Cette procédure effectue la maintenance d'un schéma SDBM.

   ******************************************************************/

   PROCEDURE MAINTENANCE
   IS

      PRAGMA AUTONOMOUS_TRANSACTION;
   
      CURSOR C_REBUILD_INDEX IS
         SELECT DBI.INDEX_NAME
               ,SQL_TABLE_SIZE.SIZE_MB "TABLE_SIZE"
               ,SQL_INDEX_SIZE.SIZE_MB "INDEX_SIZE"
           FROM USER_INDEXES DBI
               ,(
                   SELECT SEGMENT_NAME             "TABLE_NAME"
                         ,SUM(BYTES) / 1024 / 1024 "SIZE_MB"
                     FROM USER_SEGMENTS
                    WHERE SEGMENT_TYPE = 'TABLE'
                    GROUP BY SEGMENT_NAME
                 ) SQL_TABLE_SIZE
               ,(
                   SELECT SEGMENT_NAME             "INDEX_NAME"
                         ,SUM(BYTES) / 1024 / 1024 "SIZE_MB"
                     FROM USER_SEGMENTS
                    WHERE SEGMENT_TYPE = 'INDEX'
                    GROUP BY SEGMENT_NAME
                 ) SQL_INDEX_SIZE
          WHERE DBI.INDEX_NAME         = SQL_INDEX_SIZE.INDEX_NAME
            AND DBI.TABLE_NAME         = SQL_TABLE_SIZE.TABLE_NAME
            AND SQL_INDEX_SIZE.SIZE_MB > SQL_TABLE_SIZE.SIZE_MB;

   BEGIN
   
      --
      -- JOURNAL
      --

      DELETE FROM JOURNAL
       WHERE DH_JOURNAL < (SELECT TRUNC(SYSDATE) - DELAI_EPURATION_JOURNAL
                             FROM PARAMETRE
                          );
   
      --
      -- NOTIF_DIF
      --

      DELETE FROM NOTIF_DIF
       WHERE DH_ENVOI < (SELECT TRUNC(SYSDATE) - DELAI_EPURATION_JOURNAL
                           FROM PARAMETRE
                        );
   
      --
      -- COLLECTE DE DONNÉES
      --

      DELETE FROM CD_ASM_DISKGROUP
       WHERE DH_COLLECTE_DONNEE < (SELECT TRUNC(SYSDATE) - DELAI_EPURATION_COLLECTE - 1
                                     FROM PARAMETRE
                                  );

      DELETE FROM CD_DBA_DATA_FILES
       WHERE DH_COLLECTE_DONNEE < (SELECT TRUNC(SYSDATE) - DELAI_EPURATION_COLLECTE - 1
                                     FROM PARAMETRE
                                  );

      DELETE FROM CD_ESPACE_ARCHIVED_LOG
       WHERE DH_COLLECTE_DONNEE < (SELECT TRUNC(SYSDATE) - DELAI_EPURATION_COLLECTE - 1
                                     FROM PARAMETRE
                                  );

      DELETE FROM CD_FILESTAT
       WHERE DH_COLLECTE_DONNEE < (SELECT TRUNC(SYSDATE) - DELAI_EPURATION_COLLECTE - 1
                                     FROM PARAMETRE
                                  );

      DELETE FROM CD_RAPPORT_IO_STAT
       WHERE DH_PER_STAT_DEB    < (SELECT TRUNC(SYSDATE) - DELAI_EPURATION_COLLECTE - 1
                                     FROM PARAMETRE
                                  );

      DELETE FROM CD_SYSSTAT_CPU
       WHERE DH_COLLECTE_DONNEE < (SELECT TRUNC(SYSDATE) - DELAI_EPURATION_COLLECTE - 1
                                     FROM PARAMETRE
                                  );

      DELETE FROM CD_TRANSACTION_LOG
       WHERE DH_COLLECTE_DONNEE < (SELECT TRUNC(SYSDATE) - DELAI_EPURATION_COLLECTE - 1
                                     FROM PARAMETRE
                                  );

      --
      -- COLLECTE DE DONNÉES - AGENT
      --

      DELETE FROM CD_INFO_DYNAMIQUE_AGT
       WHERE DH_COLLECTE_DONNEE < TRUNC(SYSDATE) - 14
         AND TYPE_INFO          = 'BR';

      DELETE FROM CD_INFO_DYNAMIQUE_AGT
       WHERE DH_COLLECTE_DONNEE < (SELECT TRUNC(SYSDATE) - DELAI_EPURATION_COLLECTE - 1
                                     FROM PARAMETRE
                                  );

      DELETE FROM CD_INFO_DYNAMIQUE_CPU_AGT
       WHERE DH_COLLECTE_DONNEE < TRUNC(SYSDATE) - 2;

      COMMIT;


      --
      -- REBUILD INDEX 
      --
      FOR RC_REBUILD_INDEX IN C_REBUILD_INDEX LOOP

         BEGIN

            EXECUTE IMMEDIATE 'ALTER INDEX ' || RC_REBUILD_INDEX.INDEX_NAME || ' REBUILD';

         EXCEPTION

            WHEN OTHERS THEN
               JOURNALISER('SDBM_UTIL.MAINTENANCE','WARNING','Error executing ALTER INDEX ' || RC_REBUILD_INDEX.INDEX_NAME || ' REBUILD : ' || SUBSTR(SQLERRM,1,3500));

         END;      

      END LOOP;

      
   END MAINTENANCE;


   /******************************************************************
     PROCEDURE : JOURNALISER
     AUTEUR    : Benoit Bouthillier 2008-07-23 (2015-04-07)
    ------------------------------------------------------------------
     BUT : Cette procédure effectue une insertion dans la table
           JOURNAL du système.

     PARAMETRES:  Source du message  (A_SOURCE)
                  Niveau du message  (A_NIVEAU)
                  Texte du message   (A_TEXTE)
   ******************************************************************/

   PROCEDURE JOURNALISER
   (
      A_SOURCE IN JOURNAL.SOURCE%TYPE -- Source du message
     ,A_NIVEAU IN JOURNAL.NIVEAU%TYPE -- Niveau du message
     ,A_TEXTE  IN JOURNAL.TEXTE%TYPE  -- Texte du message
   )
   IS

      PRAGMA AUTONOMOUS_TRANSACTION;

      V_TAMPON VARCHAR2(4000 BYTE);
   
   BEGIN
   
      V_TAMPON := SUBSTRB(A_TEXTE,1,4000);
      INSERT INTO JOURNAL
      (
         SOURCE
        ,NIVEAU
        ,TEXTE
      )
      VALUES
      (
         SUBSTR(A_SOURCE,1,100)
        ,SUBSTR(A_NIVEAU,1,10)
        ,V_TAMPON
      );
      
      COMMIT;
   
   END JOURNALISER;


   /******************************************************************
     FONCTION  : EVALUER_SQL_HORAIRE
     AUTEUR    : Benoit Bouthillier 2008-07-23
    ------------------------------------------------------------------
     BUT : Cette fonction à pour but de faire l'évaluation de la
           chaîne SQL_HORAIRE.

     PARAMETRES:  SQL horaire  (A_SQL_HORAIRE) 
   ******************************************************************/

   FUNCTION EVALUER_SQL_HORAIRE
   (
      A_SQL_HORAIRE IN DESTI_NOTIF.SQL_HORAIRE%TYPE -- SQL horaire
   )
   RETURN NUMBER
   IS
   
      V_RETOUR VARCHAR2(50 CHAR);

   BEGIN

      EXECUTE IMMEDIATE A_SQL_HORAIRE INTO V_RETOUR;
      RETURN(1);
      
   EXCEPTION

      WHEN NO_DATA_FOUND THEN
         RETURN(0);

      WHEN OTHERS THEN
         RETURN(-1);

   END EVALUER_SQL_HORAIRE;


   /******************************************************************
     FONCTION  : INTERVAL_TO_DATE
     AUTEUR    : Benoit Bouthillier 2009-01-19
    ------------------------------------------------------------------
     BUT : Cette fonction à pour but de faire la conversion d'une
           chaine INTERVAL vers un type DATE.

     PARAMETRES:  Interval  (A_INTERVAL) 
   ******************************************************************/

   FUNCTION INTERVAL_TO_DATE
   (
      A_INTERVAL IN EVENEMENT_CIBLE.INTERVAL%TYPE  -- Interval
   )
   RETURN DATE
   IS

      PRAGMA AUTONOMOUS_TRANSACTION;

      V_NLS_LANGUAGE NLS_SESSION_PARAMETERS.VALUE%TYPE;
      V_DATE         DATE;

   BEGIN

      -- Sauvegarde du NLS_LANG courrant
      SELECT VALUE
        INTO V_NLS_LANGUAGE
       FROM NLS_SESSION_PARAMETERS
      WHERE PARAMETER = 'NLS_LANGUAGE';

      -- La routine doit toujours s'exécutée en AMERICAN
      IF (V_NLS_LANGUAGE != 'AMERICAN') THEN
         EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_LANGUAGE = ''AMERICAN''';
      END IF;

      EXECUTE IMMEDIATE 'SELECT ' || A_INTERVAL || ' FROM DUAL' INTO V_DATE;

      -- Remise à l'état initial du NLS_LANGUAGE (si ce n'était pas AMERICAN)
      IF (V_NLS_LANGUAGE != 'AMERICAN') THEN
         EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_LANGUAGE = ''' || V_NLS_LANGUAGE || '''';
      END IF;

      RETURN(V_DATE);
      
   EXCEPTION

      WHEN OTHERS THEN

         -- Remise à l'état initial du NLS_LANG (si ce n'était pas AMERICAN)
         IF (V_NLS_LANGUAGE IS NOT NULL AND V_NLS_LANGUAGE != 'AMERICAN') THEN
            EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_LANGUAGE = ''' || V_NLS_LANGUAGE || '''';
         END IF;

         RETURN(TO_DATE(NULL));

   END INTERVAL_TO_DATE;


   /******************************************************************
     FONCTION  : PREPARER_KEY_BYTES
     AUTEUR    : Benoit Bouthillier 2015-12-07
    ------------------------------------------------------------------
     BUT : Cette procedure à pour but d'obtenir (ou de générer et
           sauvegarder) la clé d'encryption pour cette installation.
   ******************************************************************/

   PROCEDURE PREPARER_KEY_BYTES
   IS

      PRAGMA AUTONOMOUS_TRANSACTION;
      
   BEGIN

      IF (GV_KEY_BYTES_RAW IS NULL) THEN

         SELECT HEXTORAW(VALEUR)
           INTO GV_KEY_BYTES_RAW
           FROM DEFAUT
          WHERE CLE = 'KEY_BYTES_HEX';

      END IF;

   
   EXCEPTION

      WHEN NO_DATA_FOUND THEN
         GV_KEY_BYTES_RAW  := DBMS_CRYPTO.RANDOMBYTES(224/8);

      INSERT INTO DEFAUT
      (
         CLE
        ,VALEUR
      )
      VALUES
      (
         'KEY_BYTES_HEX'
         ,RAWTOHEX(GV_KEY_BYTES_RAW)
      );
      COMMIT;
   
   END PREPARER_KEY_BYTES;


   /******************************************************************
     FONCTION  : ENCRYPTER_MDP
     AUTEUR    : Benoit Bouthillier 2022-01-15
    ------------------------------------------------------------------
     BUT : Cette fonction à pour but de encrypter une chaine en
           utilisant une chaine fixe pour augmenter la variabilité de
	   la clé.

     PARAMETRES:  Nom de la chaine fixe  (A_CHAINE_FIXE)
                  Mot de passe en clair  (A_MDP_CLAIR)
   ******************************************************************/

   FUNCTION ENCRYPTER_MDP
   (
      A_CHAINE_FIXE  IN VARCHAR2 -- Nom de la chaine fixe
     ,A_MDP_CLAIR    IN VARCHAR2 -- Mot de passe en clair
   )
   RETURN VARCHAR2 RESULT_CACHE
   IS

      -- Ajout de la variabilité de la clé
      V_KEY_BYTES_RAW RAW(32) := UTL_RAW.CAST_TO_RAW(SUBSTRB(GREATEST(A_CHAINE_FIXE,RPAD(A_CHAINE_FIXE,4)),-2)) || GV_KEY_BYTES_RAW || UTL_RAW.CAST_TO_RAW(SUBSTRB(GREATEST(A_CHAINE_FIXE,RPAD(A_CHAINE_FIXE,4)),1,2));
   
   BEGIN

      RETURN(RAWTOHEX(DBMS_CRYPTO.ENCRYPT(SRC => UTL_I18N.STRING_TO_RAW(A_MDP_CLAIR,'AL32UTF8')
                                         ,TYP => C_TYPE_ENCRYPTION
                                         ,KEY => V_KEY_BYTES_RAW
                                         )
                     )
            );
   
   END ENCRYPTER_MDP;


   /******************************************************************
     FONCTION  : DECRYPTER_MDP
     AUTEUR    : Benoit Bouthillier 2022-01-15
    ------------------------------------------------------------------
     BUT : Cette fonction à pour but de décrypter une chaine en
           utilisant la même chaine fixe qu'au moment de l'encryption.

     PARAMETRES:  Nom de la chaine fixe  (A_CHAINE_FIXE)
                  Mot de passe (ENC)     (A_MDP_ENC)
   ******************************************************************/

   FUNCTION DECRYPTER_MDP
   (
      A_CHAINE_FIXE  IN VARCHAR2 -- Nom de la chaine fixe
     ,A_MDP_ENC      IN VARCHAR2 -- Mot de passe
   )
   RETURN VARCHAR2 RESULT_CACHE
   IS
   
      -- Ajout de la variabilité de la clé
      V_KEY_BYTES_RAW RAW(32) := UTL_RAW.CAST_TO_RAW(SUBSTRB(GREATEST(A_CHAINE_FIXE,RPAD(A_CHAINE_FIXE,4)),-2)) || GV_KEY_BYTES_RAW || UTL_RAW.CAST_TO_RAW(SUBSTRB(GREATEST(A_CHAINE_FIXE,RPAD(A_CHAINE_FIXE,4)),1,2));
   
   BEGIN

      RETURN(UTL_I18N.RAW_TO_CHAR(DBMS_CRYPTO.DECRYPT(SRC => HEXTORAW(A_MDP_ENC)
                                                     ,TYP => C_TYPE_ENCRYPTION
                                                     ,KEY => V_KEY_BYTES_RAW
                                                     )
                                 ,'AL32UTF8'
                                 )
            );
   
   END DECRYPTER_MDP;


   /******************************************************************
     FONCTION  : ENCRYPTER_MDP_CIBLE
     AUTEUR    : Benoit Bouthillier 2022-01-15
    ------------------------------------------------------------------
     BUT : Cette fonction à pour but de encrypter le mot de passe de
           la cible.

     PARAMETRES:  Nom de la cible            (A_NOM_CIBLE)
                  Mot de passe de connexion  (A_MDP_USAGER)
   ******************************************************************/

   FUNCTION ENCRYPTER_MDP_CIBLE
   (
      A_NOM_CIBLE   IN CIBLE.NOM_CIBLE%TYPE  -- Nom de la cible
     ,A_MDP_CLAIR   IN CIBLE.MDP_USAGER%TYPE -- Mot de passe de connexion
   )
   RETURN VARCHAR2 RESULT_CACHE
   IS
   
   BEGIN

      RETURN(ENCRYPTER_MDP(A_NOM_CIBLE,A_MDP_CLAIR));
   
   END ENCRYPTER_MDP_CIBLE;


   /******************************************************************
     FONCTION  : DECRYPTER_MDP_CIBLE
     AUTEUR    : Benoit Bouthillier 2022-01-15
    ------------------------------------------------------------------
     BUT : Cette fonction à pour but de décrypter le mot de passe de
           la cible.

     PARAMETRES:  Nom de la cible                (A_NOM_CIBLE)
                  Mot de passe de connexion ENC  (A_MDP_USAGER)
   ******************************************************************/

   FUNCTION DECRYPTER_MDP_CIBLE
   (
      A_NOM_CIBLE   IN CIBLE.NOM_CIBLE%TYPE  -- Nom de la cible
     ,A_MDP_ENC     IN CIBLE.MDP_USAGER%TYPE -- Mot de passe de connexion (ENC)
   )
   RETURN VARCHAR2 RESULT_CACHE
   IS
   
   BEGIN

      RETURN(DECRYPTER_MDP(A_NOM_CIBLE,A_MDP_ENC));
   
   END DECRYPTER_MDP_CIBLE;


   /******************************************************************
     FONCTION  : ENCRYPTER_MDP_SMTP
     AUTEUR    : Benoit Bouthillier 2022-01-15
    ------------------------------------------------------------------
     BUT : Cette fonction à pour but de encrypter le mot de passe
           SMTP.

     PARAMETRES:  Nom de l'usager    (A_NOM_USAGER)
                  Mot de passe SMTP  (A_MDP_USAGER)
   ******************************************************************/

   FUNCTION ENCRYPTER_MDP_SMTP
   (
      A_NOM_USAGER  IN PARAMETRE.NOM_USAGER_SMTP%TYPE -- Nom de l'usager
     ,A_MDP_CLAIR   IN PARAMETRE.MDP_USAGER_SMTP%TYPE -- Mot de passe
   )
   RETURN VARCHAR2 RESULT_CACHE
   IS

   BEGIN

      RETURN(ENCRYPTER_MDP(A_NOM_USAGER,A_MDP_CLAIR));
   
   END ENCRYPTER_MDP_SMTP;


   /******************************************************************
     FONCTION  : DECRYPTER_MDP_SMTP
     AUTEUR    : Benoit Bouthillier 2022-01-15
    ------------------------------------------------------------------
     BUT : Cette fonction à pour but de décrypter le mot de passe 
           SMTP.

     PARAMETRES:  Nom de l'usager     (A_NOM_USAGER)
                  Mot de passe (ENC)  (A_MDP_ENC)
   ******************************************************************/

   FUNCTION DECRYPTER_MDP_SMTP
   (
      A_NOM_USAGER  IN PARAMETRE.NOM_USAGER_SMTP%TYPE -- Nom de l'usager
     ,A_MDP_ENC     IN PARAMETRE.MDP_USAGER_SMTP%TYPE -- Mot de passe (ENC)
   )
   RETURN VARCHAR2 RESULT_CACHE
   IS
   
   BEGIN

      RETURN(DECRYPTER_MDP(A_NOM_USAGER,A_MDP_ENC));
   
   END DECRYPTER_MDP_SMTP;


   /******************************************************************
     FONCTION  : ENCRYPTER_MDP_WALLET_SMTP
     AUTEUR    : Benoit Bouthillier 2022-01-15
    ------------------------------------------------------------------
     BUT : Cette fonction à pour but de encrypter le mot de passe
           du "wallet" SMTP.

     PARAMETRES:  Chemin du wallet        (A_CHEMIN_WALLET_SMTP)
                  Mot de passe du wallet  (A_MDP_CLAIR)
   ******************************************************************/

   FUNCTION ENCRYPTER_MDP_WALLET_SMTP
   (
      A_CHEMIN_WALLET_SMTP  IN PARAMETRE.CHEMIN_WALLET_SMTP%TYPE -- Chemin du wallet
     ,A_MDP_CLAIR           IN PARAMETRE.MDP_WALLET_SMTP%TYPE    -- Mot de passe (ENC)
   )
   RETURN VARCHAR2 RESULT_CACHE
   IS

   BEGIN

      RETURN(ENCRYPTER_MDP(A_CHEMIN_WALLET_SMTP,A_MDP_CLAIR));
   
   END ENCRYPTER_MDP_WALLET_SMTP;


   /******************************************************************
     FONCTION  : DECRYPTER_MDP_WALLET_SMTP
     AUTEUR    : Benoit Bouthillier 2022-01-15
    ------------------------------------------------------------------
     BUT : Cette fonction à pour but de décrypter le mot de passe
           du "wallet" SMTP.

     PARAMETRES:  Chemin du wallet              (A_CHEMIN_WALLET_SMTP)
                  Mot de passe du wallet (ENC)  (A_MDP_CLAIR)
   ******************************************************************/

   FUNCTION DECRYPTER_MDP_WALLET_SMTP
   (
      A_CHEMIN_WALLET_SMTP  IN PARAMETRE.CHEMIN_WALLET_SMTP%TYPE -- Chemin du wallet
     ,A_MDP_ENC             IN PARAMETRE.MDP_WALLET_SMTP%TYPE    -- Mot de passe (ENC)
   )
   RETURN VARCHAR2 RESULT_CACHE
   IS
   
   BEGIN

      RETURN(DECRYPTER_MDP(A_CHEMIN_WALLET_SMTP,A_MDP_ENC));
   
   END DECRYPTER_MDP_WALLET_SMTP;


   /******************************************************************
     FONCTION  : NOTIFIER_CIBLE
     AUTEUR    : Benoit Bouthillier 2011-10-26 (2015-04-08)
    ------------------------------------------------------------------
     BUT : Cette fonction à pour but de faire la notification des
           évenement.

     PARAMETRES:  Type de cible                  (A_TYPE_CIBLE) 
                  Nom de la cible                (A_NOM_CIBLE)
                  Statut de la cible             (A_STATUT)
                  Destinination de notification  (A_DESTI_NOTIF)
   ******************************************************************/

   FUNCTION NOTIFIER_CIBLE
   (
      A_TYPE_CIBLE  IN CIBLE.TYPE_CIBLE%TYPE  -- Type de cible
     ,A_NOM_CIBLE   IN CIBLE.NOM_CIBLE%TYPE   -- Nom de la cible
     ,A_STATUT      IN CIBLE.STATUT%TYPE      -- Statut de la cible
     ,A_DESTI_NOTIF IN CIBLE.DESTI_NOTIF%TYPE -- Destination de notification
   )
   RETURN BOOLEAN
   IS

      -- Curseur de notification
      CURSOR C_NOTIFICATION IS
         SELECT DND.TYPE_NOTIF
               ,DND.DESTI_NOTIF
               ,DND.ADRESSE
               ,DND.RETRAIT_ACCENT
               ,DND.FORMULE_NOTIF_DIF
               ,DEN.SQL_HORAIRE        DEN_SQL_HORAIRE 
               ,DND.SQL_HORAIRE        DND_SQL_HORAIRE
           FROM DESTI_NOTIF        DEN
               ,DESTI_NOTIF_DETAIL DND
          WHERE DEN.DESTI_NOTIF = DND.DESTI_NOTIF
            AND DEN.DESTI_NOTIF = A_DESTI_NOTIF;
  
      -- Variables locales
      V_LANGUE                 PARAMETRE.LANGUE%TYPE;
      V_MSG_STATUT             VARCHAR2(30 CHAR);
      
      V_GARANTIE_NOTIF_SERVEUR PARAMETRE.GARANTIE_NOTIF_SERVEUR%TYPE;
      V_NOTIF_SUCCES           BOOLEAN := FALSE;
      V_NOTIF_ECHEC            BOOLEAN := FALSE;

      V_ENTETE                 VARCHAR2(100 CHAR) := SUBSTR(SYS_CONTEXT('USERENV','CURRENT_SCHEMA') || ' (' || SYS_CONTEXT('USERENV','DB_NAME') || '@' || SYS_CONTEXT('USERENV','SERVER_HOST') || ') : ',1,100);
      V_MESSAGE                VARCHAR2(1000 CHAR);
      V_MESSAGE_TEMP           VARCHAR2(1000 CHAR);
      V_SIGNATURE_FONCTION     VARCHAR2(1500 CHAR);
      
      V_TAMPON                 VARCHAR2(4000 BYTE);
      V_CLOB_MESSAGE           NOTIF_DIF.MESSAGE%TYPE;
      
      -- Variable de retour de la fonction
      V_RETOUR                 BOOLEAN := TRUE;
      
   BEGIN

      -- Recherche de la langue
      SELECT LANGUE
        INTO V_LANGUE
        FROM PARAMETRE;
        
      -- Recherche du message de statut
      BEGIN

         SELECT SUBSTR(VALEUR,1,30)
           INTO V_MSG_STATUT
           FROM DEFAUT
          WHERE CLE    = V_LANGUE || '_' || A_STATUT
            AND ROWNUM = 1;

      EXCEPTION

         WHEN NO_DATA_FOUND THEN
            V_MSG_STATUT := 'NOT FOUND - SDBM.DEFAULT (CLE = ' || V_LANGUE || '_' || A_STATUT || ')';
         
      END;


      -- Composition du message
      IF (V_LANGUE = 'FR') THEN

         V_MESSAGE := CASE A_STATUT
                         WHEN 'UP' THEN
                            V_MSG_STATUT || ' : ' || A_NOM_CIBLE || ' - Est de nouveau disponible.'

                         WHEN 'DN' THEN
                            V_MSG_STATUT || ' : ' || A_NOM_CIBLE || ' - Impossible d''établir une connexion.'

                      END;

      ELSE
      
         V_MESSAGE := CASE A_STATUT
                         WHEN 'UP' THEN
                            V_MSG_STATUT || ' : ' || A_NOM_CIBLE || ' - Is now up.'

                         WHEN 'DN' THEN
                            V_MSG_STATUT || ' : ' || A_NOM_CIBLE || ' - Unable to connect.'

                      END;

      END IF;

      FOR RC_NOTIFICATION IN C_NOTIFICATION LOOP

         -- Retrait des accents (si requis)
         IF (RC_NOTIFICATION.RETRAIT_ACCENT = 'VR') THEN
            V_MESSAGE_TEMP := CONVERT(V_MESSAGE,'US7ASCII');
         ELSE
            V_MESSAGE_TEMP := V_MESSAGE;
         END IF;

         -- Vérification pour notification hors période (Schedule SQL statement)
         IF (SDBM_UTIL.EVALUER_SQL_HORAIRE(RC_NOTIFICATION.DEN_SQL_HORAIRE) != 1 OR SDBM_UTIL.EVALUER_SQL_HORAIRE(RC_NOTIFICATION.DND_SQL_HORAIRE) != 1) THEN
         
            JOURNALISER('SDBM_UTIL.NOTIFIER_CIBLE','INFO','The notification for the target ' || A_NOM_CIBLE || ' will not be sent to ' || RC_NOTIFICATION.ADRESSE || '(' || RC_NOTIFICATION.DESTI_NOTIF || ') because the destination is not available at this time (see Schedule SQL statement).');

         ELSE

            --
            -- Notification immédiate
            --

            IF (RC_NOTIFICATION.TYPE_NOTIF = 'SMTP') THEN

               -- Vérification pour notification différée
               IF ((RC_NOTIFICATION.FORMULE_NOTIF_DIF IS NOT NULL) AND (INTERVAL_TO_DATE(RC_NOTIFICATION.FORMULE_NOTIF_DIF) > SYSDATE)) THEN 

                  --
                  -- Notification différée
                  --
                  DBMS_LOB.CREATETEMPORARY(V_CLOB_MESSAGE,TRUE);
                  DBMS_LOB.APPEND(V_CLOB_MESSAGE,V_MESSAGE_TEMP);

                  V_TAMPON := SUBSTRB(V_ENTETE || V_MSG_STATUT || ' : ' || A_NOM_CIBLE || (CASE WHEN V_LANGUE = 'FR' THEN ' - Différée : ' ELSE ' - Delayed: ' END) || TO_CHAR(SYSDATE,'YYYY/MM/DD HH24:MI'),1,4000);
                  INSERT INTO NOTIF_DIF
                  (
                     DH_ENVOI_CALC
                    ,TYPE_CIBLE
                    ,NOM_CIBLE
                    ,DESTI_NOTIF
                    ,TYPE_NOTIF
                    ,ADRESSE
                    ,ENTETE
                    ,MESSAGE
                  )
                  VALUES
                  (
                     INTERVAL_TO_DATE(RC_NOTIFICATION.FORMULE_NOTIF_DIF)
                    ,A_TYPE_CIBLE
                    ,A_NOM_CIBLE
                    ,A_DESTI_NOTIF
                    ,RC_NOTIFICATION.TYPE_NOTIF
                    ,RC_NOTIFICATION.ADRESSE
                    ,V_TAMPON
                    ,V_CLOB_MESSAGE
                  );

                  DBMS_LOB.FREETEMPORARY(V_CLOB_MESSAGE);

                  JOURNALISER('SDBM_UTIL.NOTIFIER_CIBLE','INFO','The notification for the target ' || A_NOM_CIBLE || ' will be processed later (' || TO_CHAR(INTERVAL_TO_DATE(RC_NOTIFICATION.FORMULE_NOTIF_DIF),'YYYY/MM/DD:HH24:MI') || ') because the destination ' || RC_NOTIFICATION.ADRESSE || ' (' || RC_NOTIFICATION.DESTI_NOTIF || ') is configure as delayed (see Delayed notification).');
                  V_NOTIF_SUCCES := TRUE;

               ELSE
               
                  JOURNALISER('SDBM_UTIL.NOTIFIER_CIBLE','INFO','The notification for the target ' || A_NOM_CIBLE || ' is now being sent at the destination ' || RC_NOTIFICATION.ADRESSE || ' (' || RC_NOTIFICATION.DESTI_NOTIF || ') - ' || RC_NOTIFICATION.TYPE_NOTIF || '.');
                  BEGIN

                     -- Notification courriel
                     SDBM_SMTP.ENVOYER_SMTP(RC_NOTIFICATION.ADRESSE
                                           ,V_ENTETE || V_MSG_STATUT || ' : ' || A_NOM_CIBLE
                                           ,V_MESSAGE_TEMP
                                           );

                     V_NOTIF_SUCCES := TRUE;

                  EXCEPTION

                     WHEN OTHERS THEN

                        JOURNALISER('SDBM_UTIL.NOTIFIER_CIBLE','WARNING','Error executing SDBM_SMTP.ENVOYER_SMTP : ' || A_NOM_CIBLE || ' : ' || SUBSTR(SQLERRM,1,3500));
                        V_NOTIF_ECHEC := TRUE;

                  END;

               END IF;

            ELSE

               -- Recherche de la signature de la fonction
               SELECT SIGNATURE_FONCTION
                 INTO V_SIGNATURE_FONCTION
                 FROM PARAMETRE_NOTIF_EXT
                WHERE TYPE_NOTIF = RC_NOTIFICATION.TYPE_NOTIF;

               -- Remplacement des valeurs dynamique
               V_SIGNATURE_FONCTION := REPLACE(V_SIGNATURE_FONCTION,CHR(13),' ');
               V_SIGNATURE_FONCTION := REPLACE(V_SIGNATURE_FONCTION,'{ADDRESS}' ,RC_NOTIFICATION.ADRESSE);
               V_SIGNATURE_FONCTION := REPLACE(V_SIGNATURE_FONCTION,'{SEVERITY}',(CASE A_STATUT WHEN 'UP' THEN 'I' WHEN 'DN' THEN 'E' END));
               V_SIGNATURE_FONCTION := REPLACE(V_SIGNATURE_FONCTION,'''{MESSAGE}''',':V_MESSAGE_TEMP');

               -- Vérification pour notification différée
               IF ((RC_NOTIFICATION.FORMULE_NOTIF_DIF IS NOT NULL) AND (INTERVAL_TO_DATE(RC_NOTIFICATION.FORMULE_NOTIF_DIF) > SYSDATE)) THEN 

                  --
                  -- Notification différée
                  --
                  DBMS_LOB.CREATETEMPORARY(V_CLOB_MESSAGE,TRUE);
                  DBMS_LOB.APPEND(V_CLOB_MESSAGE,V_SIGNATURE_FONCTION);
   
                  INSERT INTO NOTIF_DIF
                  (
                     DH_ENVOI_CALC
                    ,TYPE_CIBLE
                    ,NOM_CIBLE
                    ,DESTI_NOTIF
                    ,TYPE_NOTIF
                    ,ADRESSE
                    ,MESSAGE
                  )
                  VALUES
                  (
                     INTERVAL_TO_DATE(RC_NOTIFICATION.FORMULE_NOTIF_DIF)
                    ,A_TYPE_CIBLE
                    ,A_NOM_CIBLE
                    ,A_DESTI_NOTIF
                    ,RC_NOTIFICATION.TYPE_NOTIF
                    ,RC_NOTIFICATION.ADRESSE
                    ,V_CLOB_MESSAGE
                  );

                  DBMS_LOB.FREETEMPORARY(V_CLOB_MESSAGE);

                  JOURNALISER('SDBM_UTIL.NOTIFIER_CIBLE','INFO','The notification for the target ' || A_NOM_CIBLE || ' will be processed later (' || TO_CHAR(INTERVAL_TO_DATE(RC_NOTIFICATION.FORMULE_NOTIF_DIF),'YYYY/MM/DD:HH24:MI') || ') because the destination ' || RC_NOTIFICATION.ADRESSE || ' (' || RC_NOTIFICATION.DESTI_NOTIF || ') is configure as delayed (see Delayed notification).');
                  V_NOTIF_SUCCES := TRUE;

               ELSE

                  JOURNALISER('SDBM_UTIL.NOTIFIER_CIBLE','INFO','The notification for the target ' || A_NOM_CIBLE || ' is now being sent at the destination ' || RC_NOTIFICATION.ADRESSE || ' (' || RC_NOTIFICATION.DESTI_NOTIF || ') - ' || RC_NOTIFICATION.TYPE_NOTIF || '.');
                  BEGIN

                     EXECUTE IMMEDIATE 'BEGIN ' || V_SIGNATURE_FONCTION || '; END;'
                        USING V_MESSAGE_TEMP;

                     V_NOTIF_SUCCES := TRUE;

                  EXCEPTION

                     WHEN OTHERS THEN

                        JOURNALISER('SDBM_UTIL.NOTIFIER_CIBLE','WARNING','Error executing ' || 'BEGIN ' || V_SIGNATURE_FONCTION || '; END;' || ' : ' || SUBSTR(SQLERRM,1,3500));
                        V_NOTIF_ECHEC := TRUE;

                  END;

               END IF;

            END IF;

         END IF;

      END LOOP;


      -- Vérification du statut de notification en fonction des paramètres
      SELECT GARANTIE_NOTIF_SERVEUR
        INTO V_GARANTIE_NOTIF_SERVEUR
        FROM PARAMETRE;

      -- Si la garantie n'est pas requise
      IF (V_GARANTIE_NOTIF_SERVEUR = 'AU') THEN
         RETURN (TRUE);
      END IF;

      IF (V_GARANTIE_NOTIF_SERVEUR = 'PA' AND V_NOTIF_SUCCES) THEN
         RETURN (TRUE);
      END IF;

      IF (V_GARANTIE_NOTIF_SERVEUR = 'CO' AND NOT V_NOTIF_ECHEC) THEN
         RETURN (TRUE);
      END IF;

      -- Non respect de la garantie de notification
      RETURN(FALSE);

   END NOTIFIER_CIBLE;


   /******************************************************************
     FONCTION  : NOTIFIER_EVENEMENT
     AUTEUR    : Benoit Bouthillier 2011-10-26 (2015-04-08)
    ------------------------------------------------------------------
     BUT : Cette fonction à pour but de faire la notification des
           évenement.

     PARAMETRES:  Type de cible                  (A_TYPE_CIBLE) 
                  Nom de la cible                (A_NOM_CIBLE)
                  Nom de l'événement             (A_NOM_EVENEMENT)
                  Nom de l'objet                 (A_NOM_OBJET)
                  Résultat                       (A_RESULTAT)
                  Statut de la cible             (A_STATUT)
                  Destinination de notification  (A_DESTI_NOTIF)
                  Nom du fichier (optionnel)     (A_NOM_FICHIER)
                  Données du fichier (optionnel) (A_BLB_FICHIER)
   ******************************************************************/

   FUNCTION NOTIFIER_EVENEMENT
   (
      A_TYPE_CIBLE     IN HIST_EVENEMENT_CIBLE.TYPE_CIBLE%TYPE    -- Type de cible
     ,A_NOM_CIBLE      IN HIST_EVENEMENT_CIBLE.NOM_CIBLE%TYPE     -- Nom de la cible
     ,A_NOM_EVENEMENT  IN HIST_EVENEMENT_CIBLE.NOM_EVENEMENT%TYPE -- Nom de l'événement
     ,A_NOM_OBJET      IN HIST_EVENEMENT_CIBLE.NOM_OBJET%TYPE     -- Nom de l'objet
     ,A_RESULTAT       IN HIST_EVENEMENT_CIBLE.RESULTAT%TYPE      -- Résultat
     ,A_STATUT         IN CHAR                                    -- Statut de la cible
     ,A_DESTI_NOTIF    IN EVENEMENT_CIBLE.DESTI_NOTIF%TYPE        -- Destination de notification
     ,A_NOM_FICHIER    IN VARCHAR2 DEFAULT NULL                   -- Nom du fichier (optionnel)
     ,A_BLB_FICHIER    IN BLOB     DEFAULT NULL                   -- Données du fichier (optionnel)
   )
   RETURN BOOLEAN
   IS

      -- Curseur de notification
      CURSOR C_NOTIFICATION IS

         SELECT DND.TYPE_NOTIF
               ,DND.DESTI_NOTIF
               ,DND.ADRESSE
               ,DND.RETRAIT_ACCENT
               ,DND.SUPPORT_FICHIER
               ,DND.FORMULE_NOTIF_DIF
               ,PAR.SIGNATURE_FONCTION
               ,DEN.SQL_HORAIRE         DEN_SQL_HORAIRE 
               ,DND.SQL_HORAIRE         DND_SQL_HORAIRE
           FROM DESTI_NOTIF         DEN
               ,DESTI_NOTIF_DETAIL  DND
               ,PARAMETRE_NOTIF_EXT PAR
          WHERE DEN.DESTI_NOTIF = DND.DESTI_NOTIF
            AND DEN.DESTI_NOTIF = A_DESTI_NOTIF
            AND DND.TYPE_NOTIF  = PAR.TYPE_NOTIF;

      -- Variables locales
      V_LANGUE                 PARAMETRE.LANGUE%TYPE;
      V_MSG_STATUT             VARCHAR2(30 CHAR);

      V_GARANTIE_NOTIF_SERVEUR PARAMETRE.GARANTIE_NOTIF_SERVEUR%TYPE;
      V_NOTIF_SUCCES           BOOLEAN := FALSE;
      V_NOTIF_ECHEC            BOOLEAN := FALSE;

      V_ENTETE                 VARCHAR2(100 CHAR) := SUBSTR(SYS_CONTEXT('USERENV','CURRENT_SCHEMA') || ' (' || SYS_CONTEXT('USERENV','DB_NAME') || '@' || SYS_CONTEXT('USERENV','SERVER_HOST') || ') : ',1,100);
      V_MESSAGE                VARCHAR2(8000 CHAR);
      V_MESSAGE_TEMP           VARCHAR2(8000 CHAR);
      V_SIGNATURE_FONCTION     VARCHAR2(8500 CHAR);

      V_TAMPON                 VARCHAR2(4000 BYTE);
      V_CLOB_MESSAGE           NOTIF_DIF.MESSAGE%TYPE;
      
      -- Variable de retour de la fonction
      V_RETOUR             BOOLEAN := TRUE;
      
   BEGIN


      -- Recherche de la langue
      SELECT LANGUE
        INTO V_LANGUE
        FROM PARAMETRE;
        
      -- Recherche du message de statut
      BEGIN

         SELECT SUBSTR(VALEUR,1,30)
           INTO V_MSG_STATUT
           FROM DEFAUT
          WHERE CLE    = V_LANGUE || '_' || A_STATUT
            AND ROWNUM = 1;

      EXCEPTION

         WHEN NO_DATA_FOUND THEN
            V_MSG_STATUT := 'NOT FOUND - SDBM.DEFAULT (CLE = ' || V_LANGUE || '_' || A_STATUT || ')';
         
      END;


      -- Composition du message
      V_MESSAGE := V_MSG_STATUT || ' : ' || A_NOM_CIBLE || ' - ' || A_NOM_EVENEMENT || (CASE WHEN A_NOM_OBJET IS NULL THEN '' ELSE '(' || A_NOM_OBJET || ')' END) || ' : ' || CHR(13) || CHR(10) || A_RESULTAT;

      FOR RC_NOTIFICATION IN C_NOTIFICATION LOOP

         -- Retrait des accents (si requis)
         IF (RC_NOTIFICATION.RETRAIT_ACCENT = 'VR') THEN
            V_MESSAGE_TEMP := CONVERT(V_MESSAGE,'US7ASCII');
         ELSE
            V_MESSAGE_TEMP := V_MESSAGE;
         END IF;

         -- Vérification pour notification hors période (Schedule SQL statement)
         IF (SDBM_UTIL.EVALUER_SQL_HORAIRE(RC_NOTIFICATION.DEN_SQL_HORAIRE) != 1 OR SDBM_UTIL.EVALUER_SQL_HORAIRE(RC_NOTIFICATION.DND_SQL_HORAIRE) != 1) THEN
         
            JOURNALISER('SDBM_UTIL.NOTIFIER_EVENEMENT','INFO','The notification for the event ' || A_NOM_EVENEMENT || (CASE WHEN A_NOM_OBJET IS NULL THEN '' ELSE '(' || A_NOM_OBJET || ')' END) || '@' || A_NOM_CIBLE || ' will not be sent to ' || RC_NOTIFICATION.ADRESSE || '(' || RC_NOTIFICATION.DESTI_NOTIF || ') because the destination is not available at this time (see Schedule SQL statement).');

         ELSE

            --
            -- Notification immédiate
            --

            IF (RC_NOTIFICATION.TYPE_NOTIF = 'SMTP') THEN

               -- Vérification pour notification différée
               IF ((RC_NOTIFICATION.FORMULE_NOTIF_DIF IS NOT NULL) AND (INTERVAL_TO_DATE(RC_NOTIFICATION.FORMULE_NOTIF_DIF) > SYSDATE)) THEN 

                  --
                  -- Notification différée
                  --
                  DBMS_LOB.CREATETEMPORARY(V_CLOB_MESSAGE,TRUE);
                  DBMS_LOB.APPEND(V_CLOB_MESSAGE,V_MESSAGE_TEMP);

                  V_TAMPON := SUBSTRB(V_ENTETE || V_MSG_STATUT || ' : ' || A_NOM_CIBLE || ' - ' || A_NOM_EVENEMENT || (CASE WHEN A_NOM_OBJET IS NULL THEN '' ELSE '(' || A_NOM_OBJET || ')' END) || (CASE WHEN V_LANGUE = 'FR' THEN ' - Différée : ' ELSE ' - Delayed: ' END) || TO_CHAR(SYSDATE,'YYYY/MM/DD HH24:MI'),1,4000);
                  INSERT INTO NOTIF_DIF
                  (
                     DH_ENVOI_CALC
                    ,TYPE_CIBLE
                    ,NOM_CIBLE
                    ,DESTI_NOTIF
                    ,TYPE_NOTIF
                    ,ADRESSE
                    ,NOM_EVENEMENT
                    ,NOM_OBJET
                    ,ENTETE
                    ,MESSAGE
                    ,NOM_FICHIER
                    ,BLB_FICHIER
                  )
                  VALUES
                  (
                     INTERVAL_TO_DATE(RC_NOTIFICATION.FORMULE_NOTIF_DIF)
                    ,A_TYPE_CIBLE
                    ,A_NOM_CIBLE
                    ,A_DESTI_NOTIF
                    ,RC_NOTIFICATION.TYPE_NOTIF
                    ,RC_NOTIFICATION.ADRESSE
                    ,A_NOM_EVENEMENT
                    ,A_NOM_OBJET
                    ,V_TAMPON
                    ,V_CLOB_MESSAGE
                     /* Si la destination supporte l'envoi de fichier */
                    ,(CASE RC_NOTIFICATION.SUPPORT_FICHIER
                         WHEN 'VR' THEN
                            A_NOM_FICHIER
                         ELSE
                            NULL
                      END
                     )
                     /* Si la destination supporte l'envoi de fichier */
                    ,(CASE RC_NOTIFICATION.SUPPORT_FICHIER
                         WHEN 'VR' THEN
                            A_BLB_FICHIER
                         ELSE
                            NULL
                      END
                     )
                  );

                  DBMS_LOB.FREETEMPORARY(V_CLOB_MESSAGE);

                  JOURNALISER('SDBM_UTIL.NOTIFIER_EVENEMENT','INFO','The notification for the event ' || A_NOM_EVENEMENT || (CASE WHEN A_NOM_OBJET IS NULL THEN '' ELSE '(' || A_NOM_OBJET || ')' END) || '@' || A_NOM_CIBLE || ' will be processed later (' || TO_CHAR(INTERVAL_TO_DATE(RC_NOTIFICATION.FORMULE_NOTIF_DIF),'YYYY/MM/DD:HH24:MI') || ') because the destination ' || RC_NOTIFICATION.ADRESSE || ' (' || RC_NOTIFICATION.DESTI_NOTIF || ') is configure as delayed (see Delayed notification).');
                  V_NOTIF_SUCCES := TRUE;

               ELSE

                  JOURNALISER('SDBM_UTIL.NOTIFIER_EVENEMENT','INFO','The notification for the event ' || A_NOM_EVENEMENT || (CASE WHEN A_NOM_OBJET IS NULL THEN '' ELSE '(' || A_NOM_OBJET || ')' END) || '@' || A_NOM_CIBLE || ' is now being sent at the destination ' || RC_NOTIFICATION.ADRESSE || ' (' || RC_NOTIFICATION.DESTI_NOTIF || ') - ' || RC_NOTIFICATION.TYPE_NOTIF || '.');
                  BEGIN

                     -- Notification courriel (avec journal si il y a lieu)
                     SDBM_SMTP.ENVOYER_SMTP(RC_NOTIFICATION.ADRESSE
                                           ,V_ENTETE || V_MSG_STATUT || ' : ' || A_NOM_CIBLE || ' - ' || A_NOM_EVENEMENT || (CASE WHEN A_NOM_OBJET IS NULL THEN '' ELSE '(' || A_NOM_OBJET || ')' END)
                                           ,V_MESSAGE_TEMP
                    ,(CASE RC_NOTIFICATION.SUPPORT_FICHIER
                         WHEN 'VR' THEN
                            A_NOM_FICHIER
                         ELSE
                            NULL
                      END
                     )
                     /* Si la destination supporte l'envoi de fichier */
                    ,(CASE RC_NOTIFICATION.SUPPORT_FICHIER
                         WHEN 'VR' THEN
                            A_BLB_FICHIER
                         ELSE
                            NULL
                      END
                     )
                                           );
                     V_NOTIF_SUCCES := TRUE;

                  EXCEPTION

                     WHEN OTHERS THEN

                        JOURNALISER('SDBM_UTIL.NOTIFIER_EVENEMENT','WARNING','Error executing SDBM_SMTP.ENVOYER_SMTP : ' || A_NOM_EVENEMENT || (CASE WHEN A_NOM_OBJET IS NULL THEN '' ELSE '(' || A_NOM_OBJET || ')' END) || '@' || A_NOM_CIBLE || ' : ' || SUBSTR(SQLERRM,1,3500));
                        V_NOTIF_ECHEC := TRUE;

                  END;

               END IF;

            ELSE

               -- Remplacement des valeurs dynamique
               V_SIGNATURE_FONCTION := RC_NOTIFICATION.SIGNATURE_FONCTION;
               V_SIGNATURE_FONCTION := REPLACE(V_SIGNATURE_FONCTION,CHR(13),' ');
               V_SIGNATURE_FONCTION := REPLACE(V_SIGNATURE_FONCTION,'{ADDRESS}' ,RC_NOTIFICATION.ADRESSE);
               V_SIGNATURE_FONCTION := REPLACE(V_SIGNATURE_FONCTION,'{SEVERITY}',(CASE A_STATUT WHEN 'ER' THEN 'W' WHEN 'AG' THEN 'W' ELSE 'I' END));
               V_SIGNATURE_FONCTION := REPLACE(V_SIGNATURE_FONCTION,'''{MESSAGE}''',':V_MESSAGE_TEMP');

               -- Vérification pour notification différée
               IF ((RC_NOTIFICATION.FORMULE_NOTIF_DIF IS NOT NULL) AND (INTERVAL_TO_DATE(RC_NOTIFICATION.FORMULE_NOTIF_DIF) > SYSDATE)) THEN 

                  --
                  -- Notification différée
                  --
                  DBMS_LOB.CREATETEMPORARY(V_CLOB_MESSAGE,TRUE);
                  DBMS_LOB.APPEND(V_CLOB_MESSAGE,V_SIGNATURE_FONCTION);

                  INSERT INTO NOTIF_DIF
                  (
                     DH_ENVOI_CALC
                    ,TYPE_CIBLE
                    ,NOM_CIBLE
                    ,DESTI_NOTIF
                    ,TYPE_NOTIF
                    ,ADRESSE
                    ,NOM_EVENEMENT
                    ,NOM_OBJET
                    ,MESSAGE
                  )
                  VALUES
                  (
                     INTERVAL_TO_DATE(RC_NOTIFICATION.FORMULE_NOTIF_DIF)
                    ,A_TYPE_CIBLE
                    ,A_NOM_CIBLE
                    ,A_DESTI_NOTIF
                    ,RC_NOTIFICATION.TYPE_NOTIF
                    ,RC_NOTIFICATION.ADRESSE
                    ,A_NOM_EVENEMENT
                    ,A_NOM_OBJET
                    ,V_CLOB_MESSAGE
                  );

                  DBMS_LOB.FREETEMPORARY(V_CLOB_MESSAGE);

                  JOURNALISER('SDBM_UTIL.NOTIFIER_EVENEMENT','INFO','The notification for the event ' || A_NOM_EVENEMENT || (CASE WHEN A_NOM_OBJET IS NULL THEN '' ELSE '(' || A_NOM_OBJET || ')' END) || '@' || A_NOM_CIBLE || ' will be processed later (' || TO_CHAR(INTERVAL_TO_DATE(RC_NOTIFICATION.FORMULE_NOTIF_DIF),'YYYY/MM/DD:HH24:MI') || ') because the destination ' || RC_NOTIFICATION.ADRESSE || ' (' || RC_NOTIFICATION.DESTI_NOTIF || ') is configure as delayed (see Delayed notification).');
                  V_NOTIF_SUCCES := TRUE;

               ELSE

                  JOURNALISER('SDBM_UTIL.NOTIFIER_EVENEMENT','INFO','The notification for the event ' || A_NOM_EVENEMENT || (CASE WHEN A_NOM_OBJET IS NULL THEN '' ELSE '(' || A_NOM_OBJET || ')' END) || '@' || A_NOM_CIBLE || ' is now being sent at the destination ' || RC_NOTIFICATION.ADRESSE || ' (' || RC_NOTIFICATION.DESTI_NOTIF || ') - ' || RC_NOTIFICATION.TYPE_NOTIF || '.');
                  BEGIN

                     EXECUTE IMMEDIATE 'BEGIN ' || V_SIGNATURE_FONCTION || '; END;'
                        USING V_MESSAGE_TEMP;

                     V_NOTIF_SUCCES := TRUE;

                  EXCEPTION

                     WHEN OTHERS THEN

                        JOURNALISER('SDBM_UTIL.NOTIFIER_EVENEMENT','WARNING','Error executing ' || 'BEGIN ' || V_SIGNATURE_FONCTION || '; END;' || ' : ' || SUBSTR(SQLERRM,1,3500));
                        V_NOTIF_ECHEC := TRUE;

                  END;

               END IF;

            END IF;

         END IF;

      END LOOP;


      -- Vérification du statut de notification en fonction des paramètres
      SELECT GARANTIE_NOTIF_SERVEUR
        INTO V_GARANTIE_NOTIF_SERVEUR
        FROM PARAMETRE;

      -- Si la garantie n'est pas requise
      IF (V_GARANTIE_NOTIF_SERVEUR = 'AU') THEN
         RETURN (TRUE);
      END IF;

      IF (V_GARANTIE_NOTIF_SERVEUR = 'PA' AND V_NOTIF_SUCCES) THEN
         RETURN (TRUE);
      END IF;

      IF (V_GARANTIE_NOTIF_SERVEUR = 'CO' AND NOT V_NOTIF_ECHEC) THEN
         RETURN (TRUE);
      END IF;

      -- Non respect de la garantie de notification
      RETURN(FALSE);
      
   END NOTIFIER_EVENEMENT;


   /******************************************************************
     PROCEDURE : NOTIFIER_DIF
     AUTEUR    : Benoit Bouthillier 2011-10-26 (2011-11-23)
    ------------------------------------------------------------------
     BUT : Cette procédure à pour but de faire l'envoi des
           notification différé.

   ******************************************************************/

   PROCEDURE NOTIFIER_DIF
   IS

      PRAGMA AUTONOMOUS_TRANSACTION;

      -- Curseur de notification
      CURSOR C_NOTIFICATION IS
         SELECT NOD.TYPE_CIBLE
               ,NOD.NOM_CIBLE
               ,NOD.NOM_EVENEMENT
               ,NOD.NOM_OBJET
               ,NOD.ENTETE
               ,NOD.MESSAGE
               ,NOD.NOM_FICHIER
               ,NOD.BLB_FICHIER
               ,NOD.DESTI_NOTIF
               ,DND.TYPE_NOTIF
               ,DND.ADRESSE
               ,DND.RETRAIT_ACCENT
               ,DND.SUPPORT_FICHIER
               ,PAR.SIGNATURE_FONCTION
               ,DEN.SQL_HORAIRE        DEN_SQL_HORAIRE 
               ,DND.SQL_HORAIRE        DND_SQL_HORAIRE
           FROM NOTIF_DIF           NOD
               ,DESTI_NOTIF         DEN
               ,DESTI_NOTIF_DETAIL  DND
               ,PARAMETRE_NOTIF_EXT PAR
          WHERE NOD.DESTI_NOTIF    = DEN.DESTI_NOTIF
            AND DEN.DESTI_NOTIF    = DND.DESTI_NOTIF
            AND DND.TYPE_NOTIF     = PAR.TYPE_NOTIF
            AND NOD.DH_ENVOI_CALC <= SYSDATE
            AND NOD.DH_ENVOI      IS NULL
            FOR UPDATE OF DH_ENVOI;

      -- Variables locales
      V_LIMITE_NOTIF_CYCLE_SERVEUR PARAMETRE.LIMITE_NOTIF_CYCLE_SERVEUR%TYPE;
      
   BEGIN

      -- Obtenir la limite de notification permise dans un cycle (flow control...)
      SELECT DECODE(LIMITE_NOTIF_CYCLE_SERVEUR
                   ,0,9999 /* 0 : sans limite */
                   ,LIMITE_NOTIF_CYCLE_SERVEUR
                   )
        INTO V_LIMITE_NOTIF_CYCLE_SERVEUR
        FROM PARAMETRE;

      -- Traitement de toutes les notifications en attente
      FOR RC_NOTIFICATION IN C_NOTIFICATION LOOP

         IF (V_LIMITE_NOTIF_CYCLE_SERVEUR > 0) THEN

            -- Vérification pour notification hors période (Schedule SQL statement)
            IF (SDBM_UTIL.EVALUER_SQL_HORAIRE(RC_NOTIFICATION.DEN_SQL_HORAIRE) != 1 OR SDBM_UTIL.EVALUER_SQL_HORAIRE(RC_NOTIFICATION.DND_SQL_HORAIRE) != 1) THEN

               -- Vérification si c'est un cible ou un événement
               IF (RC_NOTIFICATION.NOM_EVENEMENT IS NULL) THEN

                  -- Cible
                  JOURNALISER('SDBM_UTIL.NOTIFIER_DIF','INFO','The notification for the target ' || RC_NOTIFICATION.NOM_CIBLE || ' will not be sent to ' || RC_NOTIFICATION.ADRESSE || '(' || RC_NOTIFICATION.DESTI_NOTIF || ') because the destination is not available at this time (see Schedule SQL statement).');

               ELSE

                  -- Evénement
                  JOURNALISER('SDBM_UTIL.NOTIFIER_DIF','INFO','The notification for the event ' || RC_NOTIFICATION.NOM_EVENEMENT || '(' || NVL(RC_NOTIFICATION.NOM_OBJET,'N/A') || ')' || '@' || RC_NOTIFICATION.NOM_CIBLE || ' will not be sent to ' || RC_NOTIFICATION.ADRESSE || '(' || RC_NOTIFICATION.DESTI_NOTIF || ') because the destination is not available at this time (see Schedule SQL statement).');

               END IF;

            ELSE

               --
               -- Notification immédiate
               --

               IF (RC_NOTIFICATION.TYPE_NOTIF = 'SMTP') THEN

                  BEGIN

                     -- Notification courriel (avec journal si il y a lieu)
                     SDBM_SMTP.ENVOYER_SMTP(RC_NOTIFICATION.ADRESSE
                                           ,RC_NOTIFICATION.ENTETE
                                           ,DBMS_LOB.SUBSTR(RC_NOTIFICATION.MESSAGE)
                                           ,RC_NOTIFICATION.NOM_FICHIER
                                           ,RC_NOTIFICATION.BLB_FICHIER
                                           );

                     -- Ajustement de la date d'envoi
                     UPDATE NOTIF_DIF
                        SET DH_ENVOI = SYSDATE
                      WHERE CURRENT OF C_NOTIFICATION;

                  EXCEPTION

                     WHEN OTHERS THEN

                        -- Evénement
                        JOURNALISER('SDBM_UTIL.NOTIFIER_DIF','WARNING','Error executing SDBM_SMTP.ENVOYER_SMTP : ' || RC_NOTIFICATION.ENTETE || ' : ' || SUBSTR(SQLERRM,1,3500));

                  END;

               ELSE

                  BEGIN

                     EXECUTE IMMEDIATE 'BEGIN ' || DBMS_LOB.SUBSTR(RC_NOTIFICATION.MESSAGE) || '; END;';

                     -- Ajustement de la date d'envoi
                     UPDATE NOTIF_DIF
                        SET DH_ENVOI = SYSDATE
                      WHERE CURRENT OF C_NOTIFICATION;

                  EXCEPTION

                     WHEN OTHERS THEN

                        JOURNALISER('SDBM_UTIL.NOTIFIER_DIF','WARNING','Error executing ' || 'BEGIN ' || DBMS_LOB.SUBSTR(RC_NOTIFICATION.MESSAGE) || '; END;' || ' : ' || SUBSTR(SQLERRM,1,3500));

                  END;

               END IF;

            END IF;

         ELSE

            -- Ajustement de la limite restante (calcul du nombre de messages restants)
            V_LIMITE_NOTIF_CYCLE_SERVEUR := V_LIMITE_NOTIF_CYCLE_SERVEUR - 1;

         END IF;

      END LOOP;


      -- Message d'avertissement sur la limite
      IF (V_LIMITE_NOTIF_CYCLE_SERVEUR < 0) THEN
         JOURNALISER('SDBM_UTIL.NOTIFIER_DIF','WARNING',ABS(V_LIMITE_NOTIF_CYCLE_SERVEUR) || ' event(s) has not been sent yet - notification limit (server) has been reach for that cycle.');
      END IF;


      -- Fin de la transaction locale
      COMMIT;

   END NOTIFIER_DIF;


BEGIN

   PREPARER_KEY_BYTES;

END SDBM_UTIL;
/

