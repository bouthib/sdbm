-- *
-- * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
-- * Licensed under the MIT license.
-- * See LICENSE file in the project root for full license information.
-- *


CREATE OR REPLACE PACKAGE BODY SDBM.SDBM_APEX_UTIL
IS
/*********************************************************************
*
* Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
* Licensed under the MIT license.
*
**********************************************************************/
/*********************************************************************
  PACKAGE : SDBM_APEX_UTIL
  AUTEUR  : Benoit Bouthillier 2010-02-16 (2015-11-24)
 ---------------------------------------------------------------------
  BUT : Ce package permet l'implantation des procédures utilitaire
        APEX pour SDBM.

**********************************************************************/


   /******************************************************************
     FONCTION  : INFOENV
     AUTEUR    : Benoit Bouthillier 2009-01-06
    ------------------------------------------------------------------
     BUT : Cette fonction à pour but de fournir l'information
           d'affichage de l'environnement.

   ******************************************************************/

   FUNCTION INFOENV
   RETURN VARCHAR2
   IS

   BEGIN
   
      RETURN(SYS_CONTEXT('USERENV','CURRENT_SCHEMA') || ' (' || SYS_CONTEXT('USERENV','DB_NAME') || '@' || SYS_CONTEXT('USERENV','SERVER_HOST') || ')');

   END INFOENV;


   /******************************************************************
     FONCTION  : INFOSCHEMA
     AUTEUR    : Benoit Bouthillier 2009-02-11
    ------------------------------------------------------------------
     BUT : Cette fonction à pour but de fournir l'information
           d'affichage de l'environnement.

   ******************************************************************/

   FUNCTION INFOSCHEMA
   RETURN VARCHAR2
   IS

   BEGIN
   
      RETURN(UPPER(SYS_CONTEXT('USERENV','CURRENT_SCHEMA')));

   END INFOSCHEMA;


   /******************************************************************
     FONCTION  : ENCRYPTER_MDP_USAGER
     AUTEUR    : Benoit Bouthillier 2015-11-24
    ------------------------------------------------------------------
     BUT : Cette fonction à pour but de encrypter le mot de passe d'un
           usager.

     PARAMETRES:  Nom de l'usager           (A_NOM_USAGER)
                  Mot de passe de l'usager  (A_MOT_PASSE)
   ******************************************************************/

   FUNCTION ENCRYPTER_MDP_USAGER
   (
      A_NOM_USAGER IN USAGER.NOM_USAGER%TYPE   -- Nom de l'usager
     ,A_MOT_PASSE  IN USAGER.MOT_PASSE%TYPE    -- Mot de passe de l'usager
   )
   RETURN VARCHAR2
   IS
   
   BEGIN

      RETURN(RAWTOHEX(DBMS_CRYPTO.HASH(UTL_I18N.STRING_TO_RAW(A_NOM_USAGER || A_MOT_PASSE,'AL32UTF8'),DBMS_CRYPTO.HASH_SH1)));
   
   END ENCRYPTER_MDP_USAGER;


   /******************************************************************
     PROCEDURE : VIDER_JOURNAL
     AUTEUR    : Benoit Bouthillier 2009-03-14
    ------------------------------------------------------------------
     BUT : Cette procédure vide le contenu du journal.

   ******************************************************************/

   PROCEDURE VIDER_JOURNAL
   IS
   
   BEGIN

      EXECUTE IMMEDIATE ('TRUNCATE TABLE JOURNAL');
      SDBM_UTIL.JOURNALISER(A_SOURCE => 'SDBM_APEX_UTIL.VIDER_JOURNAL'
                           ,A_NIVEAU => 'INFO'
                           ,A_TEXTE  => 'The journal has been truncated by user ' || APEX_APPLICATION.G_USER || '.'
                           );

   END VIDER_JOURNAL;


   /******************************************************************
     PROCEDURE : TELECHARGER_JOURNAL_TACHE
     AUTEUR    : Benoit Bouthillier 2010-02-16
    ------------------------------------------------------------------
     BUT : Cette procédure permet le téléchargement d'un journal de
           tâche en format fichier.

   ******************************************************************/

   PROCEDURE TELECHARGER_JOURNAL_TACHE
   (
      A_ID_SOUMISSION HIST_TACHE_AGT.ID_SOUMISSION%TYPE
   )
   IS

      V_FICHIER_JOURNAL HIST_TACHE_AGT.FICHIER_JOURNAL%TYPE;
      V_JOURNAL         HIST_TACHE_AGT.JOURNAL%TYPE;
      V_LENGTH          NUMBER;

      V_BLOB            BLOB;
      V_DEST_OFFSET     INTEGER := 1;
      V_SRC_OFFSET      INTEGER := 1;
      V_LANG_CTX        INTEGER := DBMS_LOB.DEFAULT_LANG_CTX;
      V_RC              INTEGER;

   BEGIN

      SDBM_UTIL.JOURNALISER(A_SOURCE => 'SDBM_APEX_UTIL.TELECHARGER_JOURNAL_TACHE'
                           ,A_NIVEAU => 'INFO'
                           ,A_TEXTE  => 'A request for download has been received for submission ID ' || A_ID_SOUMISSION || '.'
                           );


      SELECT SUBSTR(FICHIER_JOURNAL,DECODE(INSTR(FICHIER_JOURNAL,'/')
                                          ,0,INSTR(FICHIER_JOURNAL,'\',-1) + 1
                                          ,INSTR(FICHIER_JOURNAL,'/',-1) + 1
                                          )
                   )
            ,JOURNAL
        INTO V_FICHIER_JOURNAL
            ,V_JOURNAL
        FROM HIST_TACHE_AGT
       WHERE ID_SOUMISSION = A_ID_SOUMISSION;

       -- Conversion de CLOB vers BLOB
       DBMS_LOB.CREATETEMPORARY(V_BLOB, TRUE);
       DBMS_LOB.CONVERTTOBLOB(DEST_LOB    => V_BLOB
                             ,SRC_CLOB    => V_JOURNAL
                             ,AMOUNT      => DBMS_LOB.LOBMAXSIZE
                             ,DEST_OFFSET => V_DEST_OFFSET
                             ,SRC_OFFSET  => V_SRC_OFFSET
                             ,BLOB_CSID   => DBMS_LOB.DEFAULT_CSID
                             ,LANG_CONTEXT=> V_LANG_CTX
                             ,WARNING     => V_RC
                             );

       -- Vérification de la conversion
       IF (V_RC = DBMS_LOB.WARN_INCONVERTIBLE_CHAR) THEN

          SDBM_UTIL.JOURNALISER(A_SOURCE => 'SDBM_APEX_UTIL.TELECHARGER_JOURNAL_TACHE'
                               ,A_NIVEAU => 'INFO'
                               ,A_TEXTE  => 'CONVERTTOBLOB return warning  : WARN_INCONVERTIBLE_CHAR.'
                               );

       END IF;


       -- Obtenir la longueur
       V_LENGTH := DBMS_LOB.GETLENGTH(V_BLOB);


       --
       -- Construction de l'entête HTTP
       --
       OWA_UTIL.MIME_HEADER('plain/text',FALSE);

       -- Aviser le browser de la grosseur à télécharger
       HTP.P('Content-length: ' || V_LENGTH);

       -- Nom du fichier par défaut
       HTP.P('Content-Disposition: attachment; filename="' || V_FICHIER_JOURNAL || '"');

       -- Fin de l'entête
       OWA_UTIL.HTTP_HEADER_CLOSE;


       SDBM_UTIL.JOURNALISER(A_SOURCE => 'SDBM_APEX_UTIL.TELECHARGER_JOURNAL_TACHE'
                            ,A_NIVEAU => 'INFO'
                            ,A_TEXTE  => 'The Content-length of the request for submission ID is ' || V_LENGTH || '.'
                            );

       -- Téléchargement
       WPG_DOCLOAD.DOWNLOAD_FILE(V_BLOB);
       DBMS_LOB.FREETEMPORARY(V_BLOB);


       SDBM_UTIL.JOURNALISER(A_SOURCE => 'SDBM_APEX_UTIL.TELECHARGER_JOURNAL_TACHE'
                            ,A_NIVEAU => 'INFO'
                            ,A_TEXTE  => 'The request for download for submission ID ' || A_ID_SOUMISSION || ' is completed.'
                            );


   EXCEPTION

      WHEN OTHERS THEN
         SDBM_UTIL.JOURNALISER(A_SOURCE => 'SDBM_APEX_UTIL.TELECHARGER_JOURNAL_TACHE'
                              ,A_NIVEAU => 'WARNING'
                              ,A_TEXTE  => 'The request for download for submission ID ' || A_ID_SOUMISSION || ' failed (' || SUBSTR(SQLERRM,1,512) || ').'
                              );

   END TELECHARGER_JOURNAL_TACHE;


   /******************************************************************
     PROCEDURE : INSERER_EVENEMENT_DEFAUT
     AUTEUR    : Benoit Bouthillier 2012-05-18 (2012-05-25)
    ------------------------------------------------------------------
     BUT : Cette procédure permet de faire les insertion des
           événement par défaut.

   ******************************************************************/

   PROCEDURE INSERER_EVENEMENT_DEFAUT
   (
      A_TYPE_CIBLE      CIBLE.TYPE_CIBLE%TYPE
     ,A_SOUS_TYPE_CIBLE CIBLE.SOUS_TYPE_CIBLE%TYPE
     ,A_NOM_CIBLE       CIBLE.NOM_CIBLE%TYPE
     ,A_TYPE_BD         CIBLE.TYPE_BD%TYPE
   )
   IS

   BEGIN

      IF (A_TYPE_CIBLE = 'BD') THEN
      
         -- ALERT (toutes BD sauf une Oracle, instance RAC)
         IF NOT ((A_SOUS_TYPE_CIBLE = 'OR') AND (A_TYPE_BD = 'RI')) THEN
         
            INSERT INTO EVENEMENT_CIBLE
            (
               TYPE_CIBLE
              ,SOUS_TYPE_CIBLE
              ,NOM_CIBLE
              ,NOM_EVENEMENT
              ,VERIFICATION
              ,DH_PROCHAINE_VERIF
            )
            VALUES
            (
               A_TYPE_CIBLE
              ,A_SOUS_TYPE_CIBLE
              ,A_NOM_CIBLE
              ,'ALERT'
              ,'AC'
              ,SYSDATE
            );

         END IF;

         -- Traitement Oracle
         IF (A_SOUS_TYPE_CIBLE = 'OR') THEN

            -- Instance ASM
            IF (A_TYPE_BD = 'AI') THEN

               INSERT INTO EVENEMENT_CIBLE
               (
                  TYPE_CIBLE
                 ,SOUS_TYPE_CIBLE
                 ,NOM_CIBLE
                 ,NOM_EVENEMENT
                 ,VERIFICATION
                 ,DH_PROCHAINE_VERIF
               )
               VALUES
               (
                  A_TYPE_CIBLE
                 ,A_SOUS_TYPE_CIBLE
                 ,A_NOM_CIBLE
                 ,'CD_ASM_DISKGROUP'
                 ,'AC'
                 ,SYSDATE
               );

            -- Instance normale ou base de données RAC
            ELSIF ((A_TYPE_BD = 'NI') OR (A_TYPE_BD = 'RD')) THEN

               INSERT INTO EVENEMENT_CIBLE
               (
                  TYPE_CIBLE
                 ,SOUS_TYPE_CIBLE
                 ,NOM_CIBLE
                 ,NOM_EVENEMENT
                 ,VERIFICATION
                 ,DH_PROCHAINE_VERIF
               )
               VALUES
               (
                  A_TYPE_CIBLE
                 ,A_SOUS_TYPE_CIBLE
                 ,A_NOM_CIBLE
                 ,'CD_DBA_DATA_FILES'
                 ,'AC'
                 ,SYSDATE
               );

               INSERT INTO EVENEMENT_CIBLE
               (
                  TYPE_CIBLE
                 ,SOUS_TYPE_CIBLE
                 ,NOM_CIBLE
                 ,NOM_EVENEMENT
                 ,VERIFICATION
                 ,DH_PROCHAINE_VERIF
               )
               VALUES
               (
                  A_TYPE_CIBLE
                 ,A_SOUS_TYPE_CIBLE
                 ,A_NOM_CIBLE
                 ,'CD_ESPACE_ARCHIVED_LOG'
                 ,'AC'
                 ,SYSDATE
               );

               INSERT INTO EVENEMENT_CIBLE
               (
                  TYPE_CIBLE
                 ,SOUS_TYPE_CIBLE
                 ,NOM_CIBLE
                 ,NOM_EVENEMENT
                 ,VERIFICATION
                 ,DH_PROCHAINE_VERIF
               )
               VALUES
               (
                  A_TYPE_CIBLE
                 ,A_SOUS_TYPE_CIBLE
                 ,A_NOM_CIBLE
                 ,'CD_FILESTAT'
                 ,'AC'
                 ,SYSDATE
               );

               INSERT INTO EVENEMENT_CIBLE
               (
                  TYPE_CIBLE
                 ,SOUS_TYPE_CIBLE
                 ,NOM_CIBLE
                 ,NOM_EVENEMENT
                 ,VERIFICATION
                 ,DH_PROCHAINE_VERIF
               )
               VALUES
               (
                  A_TYPE_CIBLE
                 ,A_SOUS_TYPE_CIBLE
                 ,A_NOM_CIBLE
                 ,'CD_SYSSTAT_CPU'
                 ,'AC'
                 ,SYSDATE
               );

            END IF;

         -- Traitement Microsoft SQL
         ELSIF (A_SOUS_TYPE_CIBLE = 'MS') THEN
         
            INSERT INTO EVENEMENT_CIBLE
            (
               TYPE_CIBLE
              ,SOUS_TYPE_CIBLE
              ,NOM_CIBLE
              ,NOM_EVENEMENT
              ,VERIFICATION
              ,DH_PROCHAINE_VERIF
            )
            VALUES
            (
               A_TYPE_CIBLE
              ,A_SOUS_TYPE_CIBLE
              ,A_NOM_CIBLE
              ,'CD_DBA_DATA_FILES'
              ,'AC'
              ,SYSDATE
            );

            INSERT INTO EVENEMENT_CIBLE
            (
               TYPE_CIBLE
              ,SOUS_TYPE_CIBLE
              ,NOM_CIBLE
              ,NOM_EVENEMENT
              ,VERIFICATION
              ,DH_PROCHAINE_VERIF
            )
            VALUES
            (
               A_TYPE_CIBLE
              ,A_SOUS_TYPE_CIBLE
              ,A_NOM_CIBLE
              ,'CD_TRANSACTION_LOG'
              ,'AC'
              ,SYSDATE
            );

         END IF;
      
      END IF;

   END INSERER_EVENEMENT_DEFAUT;


   /******************************************************************
     PROCEDURE : AJUSTER_EVENEMENT_REF_TYPE
     AUTEUR    : Benoit Bouthillier 2009-09-24 (2012-05-03)
    ------------------------------------------------------------------
     BUT : Cette procédure permet l'ajustement des événements en
           fonction du type (et des entrées en références).

   ******************************************************************/

   PROCEDURE AJUSTER_EVENEMENT_REF_TYPE
   (
      A_NOM_CIBLE CIBLE.NOM_CIBLE%TYPE
   )
   IS
   
      -- Liste des instances RAC associées
      CURSOR C_INSTANCE_RAC IS
         SELECT NOM_CIBLE
           FROM CIBLE
          WHERE TYPE_CIBLE_REF = 'BD'
            AND NOM_CIBLE_REF  = A_NOM_CIBLE;

      -- Variable locales
      V_TYPE_BD        CIBLE.TYPE_BD%TYPE;
      V_NOM_CIBLE_REF  CIBLE.NOM_CIBLE_REF%TYPE;

   BEGIN

      -- Recherche du type de base de données et la base de données RAC (dans le cas d'une instance RAC)
      SELECT TYPE_BD
            ,NOM_CIBLE_REF
        INTO V_TYPE_BD
            ,V_NOM_CIBLE_REF
        FROM CIBLE
       WHERE TYPE_CIBLE      = 'BD'
         AND SOUS_TYPE_CIBLE = 'OR'
         AND NOM_CIBLE       = A_NOM_CIBLE;


      --
      -- Traitement d'une instance ASM
      --
      IF (V_TYPE_BD = 'AI') THEN

         -- Retrait des collectes de données (s'il y a lieu)
         DELETE FROM EVENEMENT_CIBLE
          WHERE TYPE_CIBLE      = 'BD'
            AND SOUS_TYPE_CIBLE = 'OR'
            AND NOM_CIBLE       = A_NOM_CIBLE
            AND NOM_EVENEMENT IN (SELECT NOM_EVENEMENT
                                    FROM EVENEMENT
                                   WHERE TYPE_CIBLE      = 'BD'
                                     AND SOUS_TYPE_CIBLE = 'OR'
                                     AND TYPE_EVENEMENT  = 'CD'
                                     AND NOM_EVENEMENT  != 'CD_ASM_DISKGROUP'
                                 ); 

      ELSE

         -- Retrait des collectes de données (s'il y a lieu)
         DELETE FROM EVENEMENT_CIBLE
          WHERE TYPE_CIBLE       = 'BD'
            AND SOUS_TYPE_CIBLE  = 'OR'
            AND NOM_CIBLE        = A_NOM_CIBLE
            AND NOM_EVENEMENT    = 'CD_ASM_DISKGROUP';

      END IF;


      --
      -- Traitement d'une instance RAC
      --
      IF (V_TYPE_BD = 'RI') THEN

         -- Retrait des collectes de données et ALERT
         DELETE FROM EVENEMENT_CIBLE
          WHERE TYPE_CIBLE      = 'BD'
            AND SOUS_TYPE_CIBLE = 'OR'
            AND NOM_CIBLE       = A_NOM_CIBLE
            AND NOM_EVENEMENT IN (SELECT NOM_EVENEMENT
                                    FROM EVENEMENT
                                   WHERE TYPE_CIBLE      = 'BD'
                                     AND SOUS_TYPE_CIBLE = 'OR'
                                     AND (
                                               TYPE_EVENEMENT = 'CD' 
                                            OR TYPE_EVENEMENT = 'AG'
                                         )
                                 ); 

         -- Harmonisation de l'instances RAC avec la base de données (événement de niveau instance seulement)
         INSERT INTO EVENEMENT_CIBLE
         (
            TYPE_CIBLE
           ,SOUS_TYPE_CIBLE
           ,NOM_CIBLE
           ,NOM_EVENEMENT
           ,VERIFICATION
           ,DH_PROCHAINE_VERIF
           ,INTERVAL
           ,DESTI_NOTIF
         )
         SELECT TYPE_CIBLE
               ,SOUS_TYPE_CIBLE
               ,A_NOM_CIBLE
               ,NOM_EVENEMENT
               ,VERIFICATION
               ,DH_PROCHAINE_VERIF
               ,INTERVAL
               ,DESTI_NOTIF
           FROM EVENEMENT_CIBLE
          WHERE TYPE_CIBLE      = 'BD'
            AND SOUS_TYPE_CIBLE = 'OR'
            AND NOM_CIBLE       = V_NOM_CIBLE_REF
            AND NOM_EVENEMENT IN ('ALERT','CD_ESPACE_ARCHIVED_LOG','CD_FILESTAT','CD_SYSSTAT_CPU');

      END IF;


      --
      -- Validation de la dépendance entre CD_DBA_DATA_FILES et CD_FILESTAT
      --    (traitement d'une instance RAC convertit en instance standard / base de données RAC)
      --
      IF (V_TYPE_BD = 'NI' OR V_TYPE_BD = 'RD') THEN

         INSERT INTO EVENEMENT_CIBLE
         (
            TYPE_CIBLE
           ,SOUS_TYPE_CIBLE
           ,NOM_CIBLE
           ,NOM_EVENEMENT
           ,VERIFICATION
           ,DH_PROCHAINE_VERIF
           ,INTERVAL
           ,DESTI_NOTIF
         )
         SELECT TYPE_CIBLE
               ,SOUS_TYPE_CIBLE
               ,A_NOM_CIBLE
               ,'CD_DBA_DATA_FILES'
               ,VERIFICATION
               ,DH_PROCHAINE_VERIF
               ,INTERVAL
               ,DESTI_NOTIF
           FROM EVENEMENT_CIBLE
          WHERE TYPE_CIBLE      = 'BD'
            AND SOUS_TYPE_CIBLE = 'OR'
            AND NOM_CIBLE       = A_NOM_CIBLE
            AND NOM_EVENEMENT   = 'CD_FILESTAT'
            AND NOT EXISTS (SELECT 1
                              FROM EVENEMENT_CIBLE
                             WHERE TYPE_CIBLE      = 'BD'
                               AND SOUS_TYPE_CIBLE = 'OR'
                               AND NOM_CIBLE       = A_NOM_CIBLE
                               AND NOM_EVENEMENT   = 'CD_DBA_DATA_FILES'
                           );

      END IF;


      --
      -- Traitement d'une base de données RAC
      --
      IF (V_TYPE_BD = 'RD') THEN

         -- Pour chaque instance RAC associé à la base de données modifiée
         FOR RC_INSTANCE_RAC IN C_INSTANCE_RAC LOOP

            -- Retrait des collectes de données et ALERT
            DELETE FROM EVENEMENT_CIBLE
             WHERE TYPE_CIBLE      = 'BD'
               AND SOUS_TYPE_CIBLE = 'OR'
               AND NOM_CIBLE       = RC_INSTANCE_RAC.NOM_CIBLE
               AND NOM_EVENEMENT IN (SELECT NOM_EVENEMENT
                                       FROM EVENEMENT
                                      WHERE TYPE_CIBLE      = 'BD'
                                        AND SOUS_TYPE_CIBLE = 'OR'
                                        AND (
                                                  TYPE_EVENEMENT = 'CD' 
                                               OR TYPE_EVENEMENT = 'AG'
                                            )
                                    ); 

            -- Harmonisation de l'instances RAC avec la base de données (événement de niveau instance seulement)
            INSERT INTO EVENEMENT_CIBLE
            (
               TYPE_CIBLE
              ,SOUS_TYPE_CIBLE
              ,NOM_CIBLE
              ,NOM_EVENEMENT
              ,VERIFICATION
              ,DH_PROCHAINE_VERIF
              ,INTERVAL
              ,DESTI_NOTIF
            )
            SELECT TYPE_CIBLE
                  ,SOUS_TYPE_CIBLE
                  ,RC_INSTANCE_RAC.NOM_CIBLE
                  ,NOM_EVENEMENT
                  ,VERIFICATION
                  ,DH_PROCHAINE_VERIF
                  ,INTERVAL
                  ,DESTI_NOTIF
              FROM EVENEMENT_CIBLE
             WHERE TYPE_CIBLE      = 'BD'
               AND SOUS_TYPE_CIBLE = 'OR'
               AND NOM_CIBLE       = A_NOM_CIBLE
               AND NOM_EVENEMENT IN ('ALERT','CD_ESPACE_ARCHIVED_LOG','CD_FILESTAT','CD_SYSSTAT_CPU');

         END LOOP;

      END IF;

   EXCEPTION

      -- Si ce n'est pas une base de données Oracle
      WHEN NO_DATA_FOUND THEN
         NULL;

   END AJUSTER_EVENEMENT_REF_TYPE;


   /******************************************************************
     PROCEDURE : TRADUIRE_EVENEMENT
     AUTEUR    : Benoit Bouthillier 2009-10-03
    ------------------------------------------------------------------
     BUT : Cette procédure permet l'ajustement des événements en
           fonction de la langue du système.

   ******************************************************************/

   PROCEDURE TRADUIRE_EVENEMENT

   IS

      CURSOR C_TRADUCTION IS
         SELECT TYPE_CIBLE
               ,SOUS_TYPE_CIBLE
               ,NOM_EVENEMENT
               ,CHAINE_FR
               ,CHAINE_AN
               ,COMMENTAIRE_FR
               ,COMMENTAIRE_AN
           FROM EVENEMENT_DEFAUT_TRADUCTION;

      -- Variables locales
      V_LANGUE       PARAMETRE.LANGUE%TYPE;
      V_COMMANDE     EVENEMENT.COMMANDE%TYPE;
      V_COMMENTAIRE  EVENEMENT.COMMENTAIRE%TYPE;

      V_TAMPON       VARCHAR2(8000 CHAR);

   BEGIN

      -- Recherche de la nouvelle langue
      SELECT LANGUE
        INTO V_LANGUE
        FROM PARAMETRE;


      FOR RC_TRADUCTION IN C_TRADUCTION LOOP

         BEGIN

            -- Recherche de l'evénement 
            SELECT COMMANDE
                  ,COMMENTAIRE
              INTO V_COMMANDE
                  ,V_COMMENTAIRE
              FROM EVENEMENT
             WHERE TYPE_CIBLE      = RC_TRADUCTION.TYPE_CIBLE 
               AND SOUS_TYPE_CIBLE = RC_TRADUCTION.SOUS_TYPE_CIBLE
               AND NOM_EVENEMENT   = RC_TRADUCTION.NOM_EVENEMENT;

            IF (V_LANGUE = 'FR') THEN

               IF (INSTR(V_COMMANDE,RC_TRADUCTION.CHAINE_AN) != 0) THEN

                  V_TAMPON := REPLACE(V_COMMANDE,RC_TRADUCTION.CHAINE_AN,RC_TRADUCTION.CHAINE_FR);

                  IF (LENGTH(V_TAMPON) <= 4000) THEN

                     UPDATE EVENEMENT
                        SET COMMANDE    = V_TAMPON
                           ,COMMENTAIRE = RC_TRADUCTION.COMMENTAIRE_FR
                      WHERE TYPE_CIBLE      = RC_TRADUCTION.TYPE_CIBLE 
                        AND SOUS_TYPE_CIBLE = RC_TRADUCTION.SOUS_TYPE_CIBLE
                        AND NOM_EVENEMENT   = RC_TRADUCTION.NOM_EVENEMENT;

                     SDBM_UTIL.JOURNALISER(A_SOURCE => 'SDBM_APEX_UTIL.TRADUIRE_EVENEMENT'
                                          ,A_NIVEAU => 'INFO'
                                          ,A_TEXTE  => 'EVENT : ' || RC_TRADUCTION.NOM_EVENEMENT || '(' || RC_TRADUCTION.SOUS_TYPE_CIBLE || ') - The event has been updated.'
                                          );
                  ELSE

                     SDBM_UTIL.JOURNALISER(A_SOURCE => 'SDBM_APEX_UTIL.TRADUIRE_EVENEMENT'
                                          ,A_NIVEAU => 'WARNING'
                                          ,A_TEXTE  => 'EVENT : ' || RC_TRADUCTION.NOM_EVENEMENT || '(' || RC_TRADUCTION.SOUS_TYPE_CIBLE || ') - The command after translation would exceed 4000 caracters which is not allowed.'
                                          );

                  END IF;

               ELSE

                  SDBM_UTIL.JOURNALISER(A_SOURCE => 'SDBM_APEX_UTIL.TRADUIRE_EVENEMENT'
                                       ,A_NIVEAU => 'INFO'
                                       ,A_TEXTE  => 'EVENT : ' || RC_TRADUCTION.NOM_EVENEMENT || '(' || RC_TRADUCTION.SOUS_TYPE_CIBLE || ') - The string to replace was not found (maybe the event was already changed).'
                                       );
               END IF;

            ELSE

               IF (INSTR(V_COMMANDE,RC_TRADUCTION.CHAINE_FR) != 0) THEN

                  V_TAMPON := REPLACE(V_COMMANDE,RC_TRADUCTION.CHAINE_FR,RC_TRADUCTION.CHAINE_AN);

                  IF (LENGTH(V_TAMPON) <= 4000) THEN

                     UPDATE EVENEMENT
                        SET COMMANDE    = V_TAMPON
                           ,COMMENTAIRE = RC_TRADUCTION.COMMENTAIRE_AN
                      WHERE TYPE_CIBLE      = RC_TRADUCTION.TYPE_CIBLE 
                        AND SOUS_TYPE_CIBLE = RC_TRADUCTION.SOUS_TYPE_CIBLE
                        AND NOM_EVENEMENT   = RC_TRADUCTION.NOM_EVENEMENT;

                     SDBM_UTIL.JOURNALISER(A_SOURCE => 'SDBM_APEX_UTIL.TRADUIRE_EVENEMENT'
                                          ,A_NIVEAU => 'INFO'
                                          ,A_TEXTE  => 'EVENT : ' || RC_TRADUCTION.NOM_EVENEMENT || '(' || RC_TRADUCTION.SOUS_TYPE_CIBLE || ') - The event has been updated.'
                                          );
                  ELSE

                     SDBM_UTIL.JOURNALISER(A_SOURCE => 'SDBM_APEX_UTIL.TRADUIRE_EVENEMENT'
                                          ,A_NIVEAU => 'WARNING'
                                          ,A_TEXTE  => 'EVENT : ' || RC_TRADUCTION.NOM_EVENEMENT || '(' || RC_TRADUCTION.SOUS_TYPE_CIBLE || ') - The command after translation would exceed 4000 caracters which is not allowed.'
                                          );

                  END IF;

               ELSE

                  SDBM_UTIL.JOURNALISER(A_SOURCE => 'SDBM_APEX_UTIL.TRADUIRE_EVENEMENT'
                                       ,A_NIVEAU => 'INFO'
                                       ,A_TEXTE  => 'EVENT : ' || RC_TRADUCTION.NOM_EVENEMENT || '(' || RC_TRADUCTION.SOUS_TYPE_CIBLE || ') - The string to replace was not found (maybe the event was already changed).'
                                       );
               END IF;

            END IF;

         EXCEPTION

            WHEN NO_DATA_FOUND THEN
               SDBM_UTIL.JOURNALISER(A_SOURCE => 'SDBM_APEX_UTIL.TRADUIRE_EVENEMENT'
                                    ,A_NIVEAU => 'INFO'
                                    ,A_TEXTE  => 'EVENT : ' || RC_TRADUCTION.NOM_EVENEMENT || '(' || RC_TRADUCTION.SOUS_TYPE_CIBLE || ') - This event does not exists.'
                                    );

         END;

      END LOOP;

      -- Fin de la transaction
      COMMIT;

   END TRADUIRE_EVENEMENT;


END SDBM_APEX_UTIL;
/
