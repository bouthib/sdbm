-- *
-- * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
-- * Licensed under the MIT license.
-- * See LICENSE file in the project root for full license information.
-- *


CREATE OR REPLACE PACKAGE BODY SDBM.SDBM_AGENT
IS
/*********************************************************************
*
* Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
* Licensed under the MIT license.
*
**********************************************************************/
/*********************************************************************
  PACKAGE : SDBM_AGENT
  AUTEUR  : Benoit Bouthillier 2011-10-14 (2019-06-21)
 ---------------------------------------------------------------------
  BUT : Ce package permet l'implantation des procédures requise pour
        le moniteur Oracle (agent).

**********************************************************************/


   /*******************************************************************
     CONSTANTE :
    ******************************************************************/

    -- Version de l'entête PL/SQL
    VERSION_PB     CONSTANT VARCHAR2(4 CHAR) := '0.27';

    -- Message sur journal incomplet
    MSG_INCOMPLETE CONSTANT VARCHAR2(18) := '<<<_INCOMPLETE_>>>';



   /******************************************************************
     GLOBALES :
    *****************************************************************/

    -- Version de l'entête PL/SQL
    INITIALISATION BOOLEAN := TRUE;



   /******************************************************************
     PROCEDURE : VERSION
     AUTEUR    : Benoit Bouthillier 2009-10-02
    ------------------------------------------------------------------
     BUT : Cette procédure à pour but de retourner la version de
           de l'entête PL/SQL et du code de ce package Oracle.
   
           Particularité:
              SERVEROUTPUT doit être activé

     PARAMETRES: N/A

   *******************************************************************/
   PROCEDURE VERSION
   IS

   BEGIN

      DBMS_OUTPUT.PUT_LINE('Version');
      DBMS_OUTPUT.PUT_LINE('----------------------------');

      -- Affichage de la version de l'entête PL/SQL (PS)
      DBMS_OUTPUT.PUT_LINE('Package Specification : ' || VERSION_PS);

      -- Affichage de la version du code PL/SQL (PB)
      DBMS_OUTPUT.PUT_LINE('Package Body          : ' || VERSION_PB);

   END VERSION;


   /******************************************************************
     PROCEDURE : JOURNALISER
     AUTEUR    : Benoit Bouthillier 2008-07-23
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

   BEGIN
   
      SDBM_UTIL.JOURNALISER(A_SOURCE => A_SOURCE
                           ,A_NIVEAU => A_NIVEAU
                           ,A_TEXTE  => A_TEXTE
                           );
   
   END JOURNALISER;


   /******************************************************************
     PROCEDURE : TRAITEMENT_EVENEMENTS_AGT_BD
     AUTEUR    : Benoit Bouthillier 2010-06-28 (2011-12-21)
    ------------------------------------------------------------------
     BUT : Obtenir la liste des fichiers d'alerte pour le serveur
           reçu en paramètre.

     PARAMETRES:  Version de l'agent         (A_VERSION_AGENT)
                  Nom du serveur             (A_NOM_SERVEUR)
                  Nom de l'événement         (A_NOM_EVENEMENT)
                  Fréquence de vérification  (A_FREQU_VERIF_AGENT)
                  Curseur de retour          (A_CUR_INFO)
   ******************************************************************/

   PROCEDURE TRAITEMENT_EVENEMENTS_AGT_BD
   (
      A_VERSION_AGENT     IN  VARCHAR2 DEFAULT 'N/D'            -- Version de l'agent
     ,A_NOM_SERVEUR       IN  CIBLE.NOM_SERVEUR%TYPE            -- Nom du serveur
     ,A_NOM_EVENEMENT     IN  EVENEMENT.NOM_EVENEMENT%TYPE      -- Nom de l'événement
     ,A_FREQU_VERIF_AGENT OUT PARAMETRE.FREQU_VERIF_AGENT%TYPE  -- Fréquence de vérification
     ,A_CUR_INFO          OUT T_RC_INFO                         -- Curseur de retour
   )
   IS

      -- Curseur dynamique de retour d'information
      VC_INFO T_RC_INFO;

   BEGIN
  
      DBMS_APPLICATION_INFO.SET_MODULE(MODULE_NAME => 'SDBMAGT - SCHEMA : ' || SDBM_APEX_UTIL.INFOSCHEMA
                                      ,ACTION_NAME => TO_CHAR(SYSDATE,'YYYY/MM/DD:HH24:MI:SS')
                                      );
      DBMS_APPLICATION_INFO.SET_CLIENT_INFO('SDBMAGT version ' || A_VERSION_AGENT || ' running on ' || A_NOM_SERVEUR);
      DBMS_SESSION.SET_IDENTIFIER(A_NOM_SERVEUR);

      -- Initialisation complétée (en cas de reconnexion)
      IF (INITIALISATION) THEN
         INITIALISATION := FALSE;
      END IF;

      -- Ouverture du curseur de recherche
      OPEN VC_INFO FOR SELECT EVC.NOM_CIBLE
                             ,EVC.SOUS_TYPE_CIBLE
                             ,CIB.FICHIER_ALERTE
                         FROM EVENEMENT_CIBLE EVC
                             ,EVENEMENT       EVE
                             ,CIBLE           CIB
                        WHERE EVC.TYPE_CIBLE                                 = EVE.TYPE_CIBLE
                          AND EVC.SOUS_TYPE_CIBLE                            = EVE.SOUS_TYPE_CIBLE
                          AND EVC.NOM_EVENEMENT                              = EVE.NOM_EVENEMENT
                          AND EVC.TYPE_CIBLE                                 = CIB.TYPE_CIBLE
                          AND EVC.SOUS_TYPE_CIBLE                            = CIB.SOUS_TYPE_CIBLE
                          AND EVC.NOM_CIBLE                                  = CIB.NOM_CIBLE
                          AND EVC.NOM_EVENEMENT                              = A_NOM_EVENEMENT
                          AND EVC.VERIFICATION                               = 'AC'
                          AND EVE.TYPE_CIBLE                                 = 'BD'
                          AND EVE.TYPE_EVENEMENT                             = 'AG'
                          AND CIB.NOTIFICATION                               = 'AC'
                          AND SDBM_UTIL.EVALUER_SQL_HORAIRE(CIB.SQL_HORAIRE) = 1
                          AND UPPER(CIB.NOM_SERVEUR)                         = UPPER(A_NOM_SERVEUR)
                          AND FICHIER_ALERTE                                   IS NOT NULL
                          AND EXISTS (SELECT 1
                                        FROM PARAMETRE
                                       WHERE STATUT_AGENT = 'AC'
                                     )
                          /* Retrait de l'événement ALERT pour les bases de données RAC */
                          AND (CIB.TYPE_BD != 'RD' OR EVC.NOM_EVENEMENT != 'ALERT');

      -- Assignation de retour
      A_CUR_INFO := VC_INFO;
   
      -- Envoi du pilotage a l'agent
      SELECT FREQU_VERIF_AGENT
        INTO A_FREQU_VERIF_AGENT
        FROM PARAMETRE;

   END TRAITEMENT_EVENEMENTS_AGT_BD;


   /******************************************************************
     PROCEDURE : SAUVEGARDE_STATUT_EVEN_AGT_BD
     AUTEUR    : Benoit Bouthillier 2009-01-06 (2015-04-07)
    ------------------------------------------------------------------
     BUT : Enregistre les messages en provenance de l'agent.

     PARAMETRES:  Nom de la cible     (A_NOM_CIBLE)
                  Nom de l'événement  (A_NOM_EVENEMENT)
                  Texte obtenu        (A_TEXTE)
   ******************************************************************/

   PROCEDURE SAUVEGARDE_STATUT_EVEN_AGT_BD
   (
      A_NOM_CIBLE     IN HIST_EVENEMENT_CIBLE_AGT.NOM_CIBLE%TYPE      -- Nom de la cible
     ,A_NOM_EVENEMENT IN HIST_EVENEMENT_CIBLE_AGT.NOM_EVENEMENT%TYPE  -- Nom de l'événement
     ,A_TEXTE         IN HIST_EVENEMENT_CIBLE_AGT.TEXTE%TYPE          -- Texte obtenu
   )
   IS

      V_TAMPON VARCHAR2(4000 BYTE);

   BEGIN
   
      -- Création de l'événement (nouveau)
      V_TAMPON := SUBSTRB(A_TEXTE,1,4000);
      INSERT INTO HIST_EVENEMENT_CIBLE_AGT
      (
         TYPE_CIBLE
        ,NOM_CIBLE
        ,NOM_EVENEMENT
        ,TEXTE
        ,STATUT
      )
      VALUES
      (
         'BD'
        ,A_NOM_CIBLE
        ,A_NOM_EVENEMENT
        ,V_TAMPON
        ,'AE'
      );
      
      -- On ne retourne pas en arrière (l'agent pousuivra de toute façon au prochain bloc de message)
      COMMIT;

   END SAUVEGARDE_STATUT_EVEN_AGT_BD;


   /******************************************************************
     PROCEDURE : TRAITER_STATUT_EVEN_AGT_BD
     AUTEUR    : Benoit Bouthillier 2009-10-07 (2011-12-06)
    ------------------------------------------------------------------
     BUT : Effectue le traitement associé aux résultats obtenus pour
           un serveur (AGENT).

     PARAMETRES:  Nom du serveur  (A_NOM_SERVEUR)
   ******************************************************************/

   PROCEDURE TRAITER_STATUT_EVEN_AGT_BD
   (
      A_NOM_SERVEUR IN CIBLE.NOM_SERVEUR%TYPE  -- Nom du serveur
   )
   IS

      PRAGMA AUTONOMOUS_TRANSACTION;

      -- Curseurs
      CURSOR C_EVENEMENT_A_NOTIFIER_AGT IS
         SELECT HEC.TYPE_CIBLE
               ,HEC.NOM_CIBLE
               ,HEC.NOM_EVENEMENT
               ,HEC.TEXTE
               ,(SELECT NVL(EVC.DESTI_NOTIF,OBTENIR_DESTI_NOTIF(EVC.TYPE_CIBLE,EVC.SOUS_TYPE_CIBLE,EVC.NOM_EVENEMENT,HEC.TEXTE))
                   FROM EVENEMENT
                  WHERE TYPE_CIBLE      = CIB.TYPE_CIBLE
                    AND SOUS_TYPE_CIBLE = CIB.SOUS_TYPE_CIBLE
                    AND NOM_EVENEMENT   = HEC.NOM_EVENEMENT
                )                                                 C_DESTI_NOTIF
               ,EVE.TYPE_FERMETURE
           FROM HIST_EVENEMENT_CIBLE_AGT HEC
               ,EVENEMENT_CIBLE          EVC
               ,EVENEMENT                EVE
               ,CIBLE                    CIB
          WHERE HEC.TYPE_CIBLE         = EVC.TYPE_CIBLE
            AND HEC.NOM_CIBLE          = EVC.NOM_CIBLE
            AND HEC.NOM_EVENEMENT      = EVC.NOM_EVENEMENT
            AND HEC.TYPE_CIBLE         = EVE.TYPE_CIBLE
            AND CIB.SOUS_TYPE_CIBLE    = EVE.SOUS_TYPE_CIBLE
            AND HEC.NOM_EVENEMENT      = EVE.NOM_EVENEMENT
            AND HEC.TYPE_CIBLE         = CIB.TYPE_CIBLE
            AND HEC.NOM_CIBLE          = CIB.NOM_CIBLE
            AND HEC.STATUT             = 'AE'
            AND CIB.TYPE_CIBLE         = 'BD'
            AND UPPER(CIB.NOM_SERVEUR) = UPPER(A_NOM_SERVEUR)
          FOR UPDATE OF HEC.STATUT;

      -- Variables locales
      V_LIMITE_NOTIF_CYCLE_AGENT NUMBER;
      V_IND_ENVOI                NUMBER(1);

   BEGIN

      -- Obtenir la limite de notification permise dans un cycle (flow control...)
      SELECT DECODE(LIMITE_NOTIF_CYCLE_AGENT
                   ,0,9999 /* 0 : sans limite */
                   ,LIMITE_NOTIF_CYCLE_AGENT
                   )
        INTO V_LIMITE_NOTIF_CYCLE_AGENT
        FROM PARAMETRE;

      -- Traitement de tous les événéments en statut AE (notification)
      FOR RC_EVENEMENT_A_NOTIFIER_AGT IN C_EVENEMENT_A_NOTIFIER_AGT LOOP


         -- Ajustement de la limite restante (si une envoi est effectué)
         IF (V_LIMITE_NOTIF_CYCLE_AGENT > 0) THEN

            -- Vérification si la destination n'est pas vide
            SELECT COUNT(1)
              INTO V_IND_ENVOI
              FROM DESTI_NOTIF_DETAIL
             WHERE DESTI_NOTIF                                = RC_EVENEMENT_A_NOTIFIER_AGT.C_DESTI_NOTIF
               AND SDBM_UTIL.EVALUER_SQL_HORAIRE(SQL_HORAIRE) = 1
               AND ROWNUM                                    <= 1;

            IF (V_IND_ENVOI != 0) THEN
               V_LIMITE_NOTIF_CYCLE_AGENT := V_LIMITE_NOTIF_CYCLE_AGENT - 1;
            END IF;

            -- Notification
            IF SDBM_UTIL.NOTIFIER_EVENEMENT(RC_EVENEMENT_A_NOTIFIER_AGT.TYPE_CIBLE
                                           ,RC_EVENEMENT_A_NOTIFIER_AGT.NOM_CIBLE
                                           ,RC_EVENEMENT_A_NOTIFIER_AGT.NOM_EVENEMENT
                                           ,NULL
                                           ,RC_EVENEMENT_A_NOTIFIER_AGT.TEXTE
                                           ,'AG'
                                           ,RC_EVENEMENT_A_NOTIFIER_AGT.C_DESTI_NOTIF) THEN

               -- Mise à jour du statut de notification (fermeture normale : résolution)
               UPDATE HIST_EVENEMENT_CIBLE_AGT
                  SET STATUT  = 'OK'
                WHERE CURRENT OF C_EVENEMENT_A_NOTIFIER_AGT;

            END IF;
      
         ELSE

            -- Ajustement de la limite restante (calcul du nombre de messages restants)
            V_LIMITE_NOTIF_CYCLE_AGENT := V_LIMITE_NOTIF_CYCLE_AGENT - 1;

         END IF;

      END LOOP;


      -- Message d'avertissement sur la limite
      IF (V_LIMITE_NOTIF_CYCLE_AGENT < 0) THEN
         JOURNALISER('SDBM_AGENT.TRAITER_STATUT_EVEN_AGT_BD','WARNING',ABS(V_LIMITE_NOTIF_CYCLE_AGENT) || ' event(s) has not been sent yet - notification limit (agent) has been reach for that cycle.');
      END IF;


      -- Fin de la transaction locale
      COMMIT;
      

   END TRAITER_STATUT_EVEN_AGT_BD;


   /******************************************************************
     FONCTION  : OBTENIR_DESTI_NOTIF
     AUTEUR    : Benoit Bouthillier 2008-07-23
    ------------------------------------------------------------------
     BUT : Effectue la recherche de la destination d'envoi pour les
           sous événements (sinon, c'est le défaut de l'événement qui
           est retourné).

     PARAMETRES:  Type de cible      (A_TYPE_CIBLE)
                  Nom de l'événement (A_NOM_EVENEMENT)
                  Texte à valider    (A_TEXTE)
   ******************************************************************/

   FUNCTION OBTENIR_DESTI_NOTIF
   (
      A_TYPE_CIBLE       IN EVENEMENT_CIBLE.TYPE_CIBLE%TYPE       -- Type de cible
     ,A_SOUS_TYPE_CIBLE  IN EVENEMENT_CIBLE.SOUS_TYPE_CIBLE%TYPE  -- Type de cible
     ,A_NOM_EVENEMENT    IN EVENEMENT_CIBLE.NOM_EVENEMENT%TYPE    -- Nom de l'événement
     ,A_TEXTE            IN HIST_EVENEMENT_CIBLE_AGT.TEXTE%TYPE   -- Texte à valider
   )
   RETURN EVENEMENT.DESTI_NOTIF_DEFAUT%TYPE
   IS

      -- Curseur de recherche de traitement spécifique
      CURSOR C_DESTI_NOTIF_SUR_MESS IS
         SELECT MESSAGE
               ,DESTI_NOTIF
           FROM DESTI_NOTIF_SURCHARGE_MESSAGE
          WHERE TYPE_CIBLE      = A_TYPE_CIBLE
            AND SOUS_TYPE_CIBLE = A_SOUS_TYPE_CIBLE
            AND NOM_EVENEMENT   = A_NOM_EVENEMENT
          ORDER BY SEQ_SURCHARGE;

      -- Valeur de retour
      V_DESTI_NOTIF EVENEMENT.DESTI_NOTIF_DEFAUT%TYPE;

   BEGIN

      -- Recherche de traitement spécifique
      FOR RC_DESTI_NOTIF_SUR_MESS IN C_DESTI_NOTIF_SUR_MESS LOOP

         IF (INSTR(A_TEXTE,RC_DESTI_NOTIF_SUR_MESS.MESSAGE) != 0) THEN
            RETURN(RC_DESTI_NOTIF_SUR_MESS.DESTI_NOTIF);
         END IF;

      END LOOP;

      -- Aucun traitement spécifique, recherche de la valeur de défaut...
      SELECT DESTI_NOTIF_DEFAUT
        INTO V_DESTI_NOTIF
        FROM EVENEMENT
       WHERE TYPE_CIBLE      = A_TYPE_CIBLE
         AND SOUS_TYPE_CIBLE = A_SOUS_TYPE_CIBLE
         AND NOM_EVENEMENT   = A_NOM_EVENEMENT;

       RETURN(V_DESTI_NOTIF);

   END OBTENIR_DESTI_NOTIF;


   /******************************************************************
     PROCEDURE : ENREGISTRER_AGT
     AUTEUR    : Benoit Bouthillier 2009-10-20 (2011-12-22)
    ------------------------------------------------------------------
     BUT : Permet l'enregistrement d'un agent.

     PARAMETRES:  Nom du serveur                       (A_NOM_SERVEUR)
                  Nom du os                            (A_NOM_OS)
                  Nom de l'usager d'exécution          (A_USAGER_EXECUTION)
                  Interpréteurs disponible             (A_LISTE_INTERPRETEUR)
                  Statut de l'exécution des tâches     (A_STATUT_TACHE)
                  Collecte CD_INFO_STATIQUE_AGT        (...)

   ******************************************************************/

   PROCEDURE ENREGISTRER_AGT
   (
      A_NOM_SERVEUR         IN INFO_AGT.NOM_SERVEUR%TYPE                                   -- Nom du serveur
     ,A_NOM_OS              IN INFO_AGT.NOM_OS%TYPE                                        -- Nom du os
     ,A_USAGER_EXECUTION    IN INFO_AGT.USAGER_EXECUTION%TYPE                              -- Nom de l'usager d'exécution
     ,A_LISTE_INTERPRETEUR  IN VARCHAR2                                                    -- Interpréteurs disponible
     ,A_STATUT_TACHE        IN VARCHAR2                                      DEFAULT 'AC'  -- Statut de l'exécution des tâches
     ,A_SYS_UPTIME          IN CD_INFO_STATIQUE_AGT.SYS_UPTIME%TYPE          DEFAULT NULL  -- Collecte CD_INFO_STATIQUE_AGT
     ,A_SYS_ARCH            IN CD_INFO_STATIQUE_AGT.SYS_ARCH%TYPE            DEFAULT NULL  -- ...
     ,A_SYS_VENDOR          IN CD_INFO_STATIQUE_AGT.SYS_VENDOR%TYPE          DEFAULT NULL
     ,A_SYS_DESCRIPTION     IN CD_INFO_STATIQUE_AGT.SYS_DESCRIPTION%TYPE     DEFAULT NULL
     ,A_SYS_VENDOR_NAME     IN CD_INFO_STATIQUE_AGT.SYS_VENDOR_NAME%TYPE     DEFAULT NULL
     ,A_SYS_VENDOR_VERSION  IN CD_INFO_STATIQUE_AGT.SYS_VENDOR_VERSION%TYPE  DEFAULT NULL
     ,A_SYS_VERSION         IN CD_INFO_STATIQUE_AGT.SYS_VERSION%TYPE         DEFAULT NULL
     ,A_SYS_PATCH_LEVEL     IN CD_INFO_STATIQUE_AGT.SYS_PATCH_LEVEL%TYPE     DEFAULT NULL
     ,A_SYS_NB_CORE         IN CD_INFO_STATIQUE_AGT.SYS_NB_CORE%TYPE         DEFAULT NULL
     ,A_HAR_CPU_VENDOR      IN CD_INFO_STATIQUE_AGT.HAR_CPU_VENDOR%TYPE      DEFAULT NULL
     ,A_HAR_CPU_MODEL       IN CD_INFO_STATIQUE_AGT.HAR_CPU_MODEL%TYPE       DEFAULT NULL
     ,A_HAR_CPU_CLOCK_MHZ   IN CD_INFO_STATIQUE_AGT.HAR_CPU_CLOCK_MHZ%TYPE   DEFAULT NULL
     ,A_HAR_RAM_SIZE        IN CD_INFO_STATIQUE_AGT.HAR_RAM_SIZE%TYPE        DEFAULT NULL
   )
   IS

      CURSOR C_SESSION IS
         SELECT 'ALTER SYSTEM KILL SESSION ''' || SID || ',' || SERIAL# || ''' IMMEDIATE' COMMANDE
           FROM V$SESSION
          WHERE MODULE LIKE 'SDBMAGT - SCHEMA : ' || SDBM_APEX_UTIL.INFOSCHEMA /* TRAITEMENT DE SDBMAGT SEULEMENT, SCHEMA ACTUEL */
            AND MODULE            = SYS_CONTEXT('USERENV','MODULE')            /* TRAITEMENT DU MÊME MODULE                      */
            AND CLIENT_IDENTIFIER = SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER') /* TRAITEMENT DU MÊME CLIENT                      */
            AND SID              != SYS_CONTEXT('USERENV','SID');

      CURSOR C_TACHE_EN_COURS IS
         SELECT *
           FROM HIST_TACHE_AGT
          WHERE NOM_SERVEUR = UPPER(A_NOM_SERVEUR)
            AND STATUT_EXEC IN ('SB','SR','EX')
            FOR UPDATE OF STATUT_EXEC
                         ,STATUT_NOTIF_EXEC;

      V_TAB_INT_VAL APEX_APPLICATION_GLOBAL.VC_ARR2;

   BEGIN
  
      -- Identification
      DBMS_APPLICATION_INFO.SET_MODULE(MODULE_NAME => 'SDBMAGT - SCHEMA : ' || SDBM_APEX_UTIL.INFOSCHEMA
                                      ,ACTION_NAME => TO_CHAR(SYSDATE,'YYYY/MM/DD:HH24:MI:SS')
                                      );
      DBMS_SESSION.SET_IDENTIFIER(A_NOM_SERVEUR);

      IF (INITIALISATION) THEN

         -- Fermeture des sessions en double
         FOR RC_SESSION IN C_SESSION LOOP

            BEGIN

               SDBM_UTIL.JOURNALISER('SDBM_AGENT.ENREGISTRER_AGT','INFO','The following statement will be executed to ensure uniqueness of the session : ' || RC_SESSION.COMMANDE);
               EXECUTE IMMEDIATE RC_SESSION.COMMANDE;
               SDBM_UTIL.JOURNALISER('SDBM_AGENT.ENREGISTRER_AGT','INFO','The following statement was successfully executed to ensure uniqueness of the session : ' || RC_SESSION.COMMANDE);

            EXCEPTION
      
               WHEN OTHERS THEN
                  SDBM_UTIL.JOURNALISER('SDBM_AGENT.ENREGISTRER_AGT','WARNING','The following statement ended with error ' || SQLERRM || ' : ' || RC_SESSION.COMMANDE);
            END;
      
         END LOOP;

         -- Forcer toutes les tâches en cours d'exécution comme incomplète (agent à été redémarraré pendant l'exécution)
         JOURNALISER('SDBM_AGENT.ENREGISTRER_AGT','INFO','The jobs that were running on the agent ' || A_NOM_SERVEUR || ' will be marked as incomplete.');

         FOR RC_TACHE_EN_COURS IN C_TACHE_EN_COURS LOOP

            UPDATE HIST_TACHE_AGT
               SET STATUT_EXEC       = 'NC'
                  ,STATUT_NOTIF_EXEC = 'AE'
             WHERE CURRENT OF C_TACHE_EN_COURS;

            UPDATE TACHE_AGT
               SET DH_PROCHAINE_EXEC = SDBM_UTIL.INTERVAL_TO_DATE(INTERVAL)
             WHERE NOM_SERVEUR       = RC_TACHE_EN_COURS.NOM_SERVEUR
               AND NOM_TACHE         = RC_TACHE_EN_COURS.NOM_TACHE;

         END LOOP;
         
         -- Initialisation complétée
         INITIALISATION := FALSE;

      END IF;

      -- Mise à jour de l'information sur l'agent
      DELETE FROM INFO_DET_INT_AGT
       WHERE NOM_SERVEUR = UPPER(A_NOM_SERVEUR);

      UPDATE INFO_AGT
         SET NOM_OS           = A_NOM_OS
            ,USAGER_EXECUTION = A_USAGER_EXECUTION
            ,STATUT_TACHE     = A_STATUT_TACHE
       WHERE NOM_SERVEUR      = UPPER(A_NOM_SERVEUR);

      IF (SQL%ROWCOUNT = 0) THEN
      
         -- Création
         INSERT INTO INFO_AGT
         (
            NOM_SERVEUR
           ,NOM_OS
           ,USAGER_EXECUTION
           ,STATUT_TACHE
         )
         VALUES
         (
            UPPER(A_NOM_SERVEUR)
           ,A_NOM_OS
           ,A_USAGER_EXECUTION
           ,A_STATUT_TACHE
         );
      
      END IF;
   
      -- Interpreteur
      IF (LENGTH(A_LISTE_INTERPRETEUR) > 0) THEN

         V_TAB_INT_VAL := APEX_UTIL.STRING_TO_TABLE(A_LISTE_INTERPRETEUR,',');
         FOR I IN 1..V_TAB_INT_VAL.COUNT LOOP

            INSERT INTO INFO_DET_INT_AGT
            (
               NOM_SERVEUR
              ,INTERPRETEUR
            )
            VALUES
            (
               UPPER(A_NOM_SERVEUR)
              ,V_TAB_INT_VAL(I)
            );

         END LOOP;

      END IF;


      -- Mise à jour de l'information CD_INFO_STATIQUE_AGT
      UPDATE CD_INFO_STATIQUE_AGT
         SET DH_COLLECTE_DONNEE = SYSDATE 
            ,SYS_UPTIME         = A_SYS_UPTIME
            ,SYS_ARCH           = SUBSTR(A_SYS_ARCH,1,50)
            ,SYS_VENDOR         = SUBSTR(A_SYS_VENDOR,1,50)
            ,SYS_DESCRIPTION    = SUBSTR(A_SYS_DESCRIPTION,1,50)
            ,SYS_VENDOR_NAME    = SUBSTR(A_SYS_VENDOR_NAME,1,50)
            ,SYS_VENDOR_VERSION = SUBSTR(A_SYS_VENDOR_VERSION,1,50)
            ,SYS_VERSION        = SUBSTR(A_SYS_VERSION,1,50)
            ,SYS_PATCH_LEVEL    = SUBSTR(A_SYS_PATCH_LEVEL,1,50)
            ,SYS_NB_CORE        = A_SYS_NB_CORE
            ,HAR_CPU_VENDOR     = SUBSTR(A_HAR_CPU_VENDOR,1,50)
            ,HAR_CPU_MODEL      = SUBSTR(A_HAR_CPU_MODEL,1,50)
            ,HAR_CPU_CLOCK_MHZ  = A_HAR_CPU_CLOCK_MHZ
            ,HAR_RAM_SIZE       = A_HAR_RAM_SIZE
       WHERE NOM_SERVEUR = UPPER(A_NOM_SERVEUR);
       
      IF (SQL%ROWCOUNT = 0) THEN
      
         INSERT INTO CD_INFO_STATIQUE_AGT
         (
            NOM_SERVEUR
           ,DH_COLLECTE_DONNEE
           ,SYS_UPTIME
           ,SYS_ARCH
           ,SYS_VENDOR
           ,SYS_DESCRIPTION
           ,SYS_VENDOR_NAME
           ,SYS_VENDOR_VERSION
           ,SYS_VERSION
           ,SYS_PATCH_LEVEL
           ,SYS_NB_CORE
           ,HAR_CPU_VENDOR
           ,HAR_CPU_MODEL
           ,HAR_CPU_CLOCK_MHZ
           ,HAR_RAM_SIZE
         )
         VALUES
         (
            UPPER(A_NOM_SERVEUR)
           ,SYSDATE
           ,A_SYS_UPTIME
           ,SUBSTR(A_SYS_ARCH,1,50)
           ,SUBSTR(A_SYS_VENDOR,1,50)
           ,SUBSTR(A_SYS_DESCRIPTION,1,50)
           ,SUBSTR(A_SYS_VENDOR_NAME,1,50)
           ,SUBSTR(A_SYS_VENDOR_VERSION,1,50)
           ,SUBSTR(A_SYS_VERSION,1,50)
           ,SUBSTR(A_SYS_PATCH_LEVEL,1,50)
           ,A_SYS_NB_CORE
           ,SUBSTR(A_HAR_CPU_VENDOR,1,50)
           ,SUBSTR(A_HAR_CPU_MODEL,1,50)
           ,A_HAR_CPU_CLOCK_MHZ
           ,A_HAR_RAM_SIZE
         );
      
      END IF;


   END ENREGISTRER_AGT;


   /******************************************************************
     PROCEDURE : TRAITEMENT_EPURATION_AGT
     AUTEUR    : Benoit Bouthillier 2009-04-14
    ------------------------------------------------------------------
     BUT : Obtenir la liste des fichiers de log à supprimer pour le
           serveur reçu en paramètre.

     PARAMETRES:  Nom du serveur    (A_NOM_SERVEUR)
                  Curseur de retour (A_CUR_INFO)
   ******************************************************************/

   PROCEDURE TRAITEMENT_EPURATION_AGT
   (
      A_NOM_SERVEUR IN  CIBLE.NOM_SERVEUR%TYPE  -- Nom du serveur
     ,A_CUR_INFO    OUT T_RC_INFO               -- Curseur de retour
   )
   IS

      -- Curseur dynamique de retour d'information
      VC_INFO T_RC_INFO;

   BEGIN
  
      -- Ouverture du curseur de suppression des log (fichiers) - par l'agent
      OPEN VC_INFO FOR SELECT FICHIER_JOURNAL || '.' || ID_SOUMISSION  FICHIER_JOURNAL
                         FROM HIST_TACHE_AGT
                        WHERE NOM_SERVEUR = UPPER(A_NOM_SERVEUR)
                          AND (
                                 (
                                    DH_FIN < TRUNC(SYSDATE) - (SELECT DELAI_EPURATION_LOG_FIC_TACHE
                                                                 FROM PARAMETRE
                                                              )
                                 )
                                 OR 
                                 (
                                        DH_FIN        IS NULL
                                    AND STATUT_EXEC   IN ('SF','NC')
                                    AND DH_SOUMISSION  < TRUNC(SYSDATE) - (SELECT DELAI_EPURATION_LOG_FIC_TACHE
                                                                             FROM PARAMETRE
                                                                          )
                                 )
                              )
                          AND FICHIER_JOURNAL IS NOT NULL
                        ORDER BY ID_SOUMISSION;

      -- Assignation de retour
      A_CUR_INFO := VC_INFO;
   

      -- Suppression de l'historique des tâches (plus conservateur de DELAI_EPURATION_LOG_FIC_TACHE / DELAI_EPURATION_LOG_BD_TACHE)
      DELETE FROM HIST_TACHE_AGT
       WHERE NOM_SERVEUR = UPPER(A_NOM_SERVEUR)
         AND (
                (
                   DH_FIN < TRUNC(SYSDATE) - (SELECT GREATEST(DELAI_EPURATION_LOG_FIC_TACHE,DELAI_EPURATION_LOG_BD_TACHE)
                                                FROM PARAMETRE
                                             )
                )
                OR 
                (
                       DH_FIN        IS NULL
                   AND STATUT_EXEC   IN ('SF','NC')
                   AND DH_SOUMISSION  < TRUNC(SYSDATE) - (SELECT GREATEST(DELAI_EPURATION_LOG_FIC_TACHE,DELAI_EPURATION_LOG_BD_TACHE)
                                                            FROM PARAMETRE
                                                         )
                )
             );


      -- Suppression des log (FICHIER)
      UPDATE HIST_TACHE_AGT
         SET FICHIER_JOURNAL = NULL
       WHERE NOM_SERVEUR = UPPER(A_NOM_SERVEUR)
         AND (
                (
                   DH_FIN < TRUNC(SYSDATE) - (SELECT DELAI_EPURATION_LOG_FIC_TACHE
                                                FROM PARAMETRE
                                             )
                )
                OR 
                (
                       DH_FIN        IS NULL
                   AND STATUT_EXEC   IN ('SF','NC')
                   AND DH_SOUMISSION  < TRUNC(SYSDATE) - (SELECT DELAI_EPURATION_LOG_FIC_TACHE
                                                            FROM PARAMETRE
                                                         )
                )
             )
         AND FICHIER_JOURNAL IS NOT NULL;

      -- Suppression des log (BD)
      UPDATE HIST_TACHE_AGT
         SET JOURNAL = NULL
       WHERE NOM_SERVEUR = UPPER(A_NOM_SERVEUR)
         AND (
                (
                   DH_FIN < TRUNC(SYSDATE) - (SELECT DELAI_EPURATION_LOG_BD_TACHE
                                                FROM PARAMETRE
                                             )
                )
                OR 
                (
                       DH_FIN        IS NULL
                   AND STATUT_EXEC   IN ('SF','NC')
                   AND DH_SOUMISSION  < TRUNC(SYSDATE) - (SELECT DELAI_EPURATION_LOG_BD_TACHE
                                                            FROM PARAMETRE
                                                         )
                )
             )
         AND JOURNAL IS NOT NULL;

   END TRAITEMENT_EPURATION_AGT;


   /******************************************************************
     PROCEDURE : EVALUATION_STATUT_TACHE
     AUTEUR    : Benoit Bouthillier 2009-10-02 (2017-06-01)
    ------------------------------------------------------------------
     BUT : Effectue l'évaluation de l'exécution d'une tâche.

     PARAMETRES:  Numéro de soumission (A_ID_SOUMISSION)
                  Statut d'exécution   (A_STATUT_EXEC)
                  Texte d'évaluation   (A_EVALUATION)
   ******************************************************************/

   PROCEDURE EVALUATION_STATUT_TACHE
   (
      A_ID_SOUMISSION IN  HIST_TACHE_AGT.ID_SOUMISSION%TYPE  -- Numéro de soumission
     ,A_STATUT_EXEC   OUT HIST_TACHE_AGT.STATUT_EXEC%TYPE    -- Statut d'exécution
     ,A_EVALUATION    OUT HIST_TACHE_AGT.EVALUATION%TYPE     -- Texte d'évaluation
   )
   IS

      -- Curseur de recherche des chaines de vérification
      CURSOR C_TACHE_DET_MSG_AGT(A_NOM_SERVEUR TACHE_DET_MSG_AGT.NOM_SERVEUR%TYPE
                                ,A_NOM_TACHE   TACHE_DET_MSG_AGT.NOM_TACHE%TYPE
                                ,A_TYPE_MSG    TACHE_DET_MSG_AGT.TYPE_MSG%TYPE   ) IS
         SELECT MSG
           FROM TACHE_DET_MSG_AGT
          WHERE NOM_SERVEUR = A_NOM_SERVEUR
            AND NOM_TACHE   = A_NOM_TACHE
            AND TYPE_MSG    = A_TYPE_MSG;


      -- Variables locales
      V_CODE_RETOUR        HIST_TACHE_AGT.CODE_RETOUR%TYPE;
      V_CODE_RETOUR_SUCCES TACHE_AGT.CODE_RETOUR_SUCCES%TYPE;
      V_NOM_SERVEUR        TACHE_AGT.NOM_SERVEUR%TYPE;
      V_NOM_TACHE          TACHE_AGT.NOM_TACHE%TYPE;
      V_LANGUE             PARAMETRE.LANGUE%TYPE;
      V_EVAL_CODE_RETOUR   VARCHAR2(512 CHAR);
      V_INDICATEUR         NUMBER(1);
      V_JOURNAL            HIST_TACHE_AGT.JOURNAL%TYPE;

   BEGIN

      -- Initialisation
      A_STATUT_EXEC := 'OK';


      --
      -- Recherche de l'information requise pour le traitement
      --
      SELECT HTA.CODE_RETOUR
            ,TAG.CODE_RETOUR_SUCCES
            ,TAG.NOM_SERVEUR
            ,TAG.NOM_TACHE
            ,PAR.LANGUE
        INTO V_CODE_RETOUR
            ,V_CODE_RETOUR_SUCCES
            ,V_NOM_SERVEUR
            ,V_NOM_TACHE
            ,V_LANGUE
        FROM HIST_TACHE_AGT HTA
            ,TACHE_AGT      TAG
            ,PARAMETRE      PAR
       WHERE HTA.NOM_SERVEUR   = TAG.NOM_SERVEUR
         AND HTA.NOM_TACHE     = TAG.NOM_TACHE
         AND HTA.ID_SOUMISSION = A_ID_SOUMISSION;

      --
      -- Évaluation du code de retour
      --
      SELECT HTA.CODE_RETOUR
            ,TAG.CODE_RETOUR_SUCCES
        INTO V_CODE_RETOUR
            ,V_CODE_RETOUR_SUCCES
        FROM HIST_TACHE_AGT HTA
            ,TACHE_AGT      TAG
       WHERE HTA.NOM_SERVEUR   = TAG.NOM_SERVEUR
         AND HTA.NOM_TACHE     = TAG.NOM_TACHE
         AND HTA.ID_SOUMISSION = A_ID_SOUMISSION;

      V_EVAL_CODE_RETOUR := REPLACE(V_CODE_RETOUR_SUCCES,'{RC}',V_CODE_RETOUR);

      BEGIN

         EXECUTE IMMEDIATE 'SELECT COUNT(1) FROM DUAL WHERE ' || V_EVAL_CODE_RETOUR
            INTO V_INDICATEUR;

      EXCEPTION

         WHEN OTHERS THEN
            V_INDICATEUR := 0;

      END;
      
      -- Vérification du résultat
      IF (V_INDICATEUR = 0) THEN
         A_STATUT_EXEC := 'ER';
      END IF;
      A_EVALUATION  := 'RC = ' || A_STATUT_EXEC || ' (' || V_CODE_RETOUR_SUCCES || ' -> ' || V_EVAL_CODE_RETOUR || ')' || CHR(13) || CHR(10);


      --
      -- Évaluation du statut via la recherche de chaîne
      --
      SELECT JOURNAL
        INTO V_JOURNAL
        FROM HIST_TACHE_AGT
       WHERE ID_SOUMISSION = A_ID_SOUMISSION;
       
      -- Vérification si le journal est incomplet (termine par MSG_INCOMPLETE)
      IF (DBMS_LOB.SUBSTR(V_JOURNAL,LENGTH(MSG_INCOMPLETE),DBMS_LOB.GETLENGTH(V_JOURNAL) - LENGTH(MSG_INCOMPLETE) + 1) = MSG_INCOMPLETE) THEN

         A_STATUT_EXEC := 'ER';

         IF (V_LANGUE = 'FR') THEN
            A_EVALUATION  := A_EVALUATION || '*** Impossible d''évaluer le contenu du journal ***'  || CHR(13) || CHR(10) || '*** La tâche à générée un journal supérieur à la limite de ' || C_GROSSEUR_MAX_JOURNAL || ' octets (' || $$PLSQL_UNIT || '.C_GROSSEUR_MAX_JOURNAL) ***';
         ELSE
            A_EVALUATION  := A_EVALUATION || '*** Unable to evaluate log contents ***'  || CHR(13) || CHR(10) || '*** The task generated a log greater than the limit of ' || C_GROSSEUR_MAX_JOURNAL || ' bytes (' || $$PLSQL_UNIT || '.C_GROSSEUR_MAX_JOURNAL) ***';
         END IF;

      ELSE

         IF (V_JOURNAL IS NOT NULL) THEN

            --
            -- Traitement des chaines OK
            --

            A_EVALUATION  := SUBSTR(A_EVALUATION || 'OK : ',1,512);

            -- Traitement de chacune des chaînes (OK : si non existantes -> ERREUR)
            FOR RC_TACHE_DET_MSG_AGT IN C_TACHE_DET_MSG_AGT(V_NOM_SERVEUR,V_NOM_TACHE,'OK') LOOP

               IF (DBMS_LOB.INSTR(V_JOURNAL,RC_TACHE_DET_MSG_AGT.MSG) = 0) THEN
                  A_STATUT_EXEC := 'ER';

                  IF (V_LANGUE = 'FR') THEN
                     A_EVALUATION  := SUBSTR(A_EVALUATION || RC_TACHE_DET_MSG_AGT.MSG || ' -> PAS TROUVÉ, ',1,512);
                  ELSE
                     A_EVALUATION  := SUBSTR(A_EVALUATION || RC_TACHE_DET_MSG_AGT.MSG || ' -> NOT FOUND, ',1,512);
                  END IF;

               ELSE

                  IF (V_LANGUE = 'FR') THEN
                     A_EVALUATION  := SUBSTR(A_EVALUATION || RC_TACHE_DET_MSG_AGT.MSG || ' -> trouvé, ',1,512);
                  ELSE
                     A_EVALUATION  := SUBSTR(A_EVALUATION || RC_TACHE_DET_MSG_AGT.MSG || ' -> found, ',1,512);
                  END IF;

               END IF;

            END LOOP;

            IF (SUBSTR(A_EVALUATION,LENGTH(A_EVALUATION) - 1,2) = ', ') THEN
               A_EVALUATION := SUBSTR(A_EVALUATION,1,LENGTH(A_EVALUATION) - 2) || CHR(13) || CHR(10);
            ELSE

               IF (V_LANGUE = 'FR') THEN
                  A_EVALUATION := SUBSTR(A_EVALUATION || 'Aucun.' || CHR(13) || CHR(10),1,512);
               ELSE
                  A_EVALUATION := SUBSTR(A_EVALUATION || 'None.' || CHR(13) || CHR(10),1,512);
               END IF;

            END IF;


            --
            -- Traitement des chaines ER
            --

            A_EVALUATION  := SUBSTR(A_EVALUATION || 'ER : ',1,512);

            -- Traitement de chacune des chaînes (ER : si existantes -> ERREUR)
            FOR RC_TACHE_DET_MSG_AGT IN C_TACHE_DET_MSG_AGT(V_NOM_SERVEUR,V_NOM_TACHE,'ER') LOOP

               IF (DBMS_LOB.INSTR(V_JOURNAL,RC_TACHE_DET_MSG_AGT.MSG) != 0) THEN
                  A_STATUT_EXEC := 'ER';

                  IF (V_LANGUE = 'FR') THEN
                     A_EVALUATION  := SUBSTR(A_EVALUATION || RC_TACHE_DET_MSG_AGT.MSG || ' -> TROUVÉ, ',1,512);
                  ELSE
                     A_EVALUATION  := SUBSTR(A_EVALUATION || RC_TACHE_DET_MSG_AGT.MSG || ' -> FOUND, ',1,512);
                  END IF;

               ELSE

                  IF (V_LANGUE = 'FR') THEN
                     A_EVALUATION  := SUBSTR(A_EVALUATION || RC_TACHE_DET_MSG_AGT.MSG || ' -> pas trouvé, ',1,512);
                  ELSE
                     A_EVALUATION  := SUBSTR(A_EVALUATION || RC_TACHE_DET_MSG_AGT.MSG || ' -> not found, ',1,512);
                  END IF;

               END IF;

            END LOOP;

            IF (SUBSTR(A_EVALUATION,LENGTH(A_EVALUATION) - 1,2) = ', ') THEN
               A_EVALUATION := SUBSTR(A_EVALUATION,1,LENGTH(A_EVALUATION) - 2) || CHR(13) || CHR(10);
            ELSE

               IF (V_LANGUE = 'FR') THEN
                  A_EVALUATION := SUBSTR(A_EVALUATION || 'Aucun.' || CHR(13) || CHR(10),1,512);
               ELSE
                  A_EVALUATION := SUBSTR(A_EVALUATION || 'None.' || CHR(13) || CHR(10),1,512);
               END IF;

            END IF;

         END IF;

      END IF;

   END EVALUATION_STATUT_TACHE;


   /******************************************************************
     PROCEDURE : TRAITER_STATUT_TACHE_AGT
     AUTEUR    : Benoit Bouthillier 2010-06-04 (2019-06-21)
    ------------------------------------------------------------------
     BUT : Effectue le traitement associé aux résultats obtenus pour
           un serveur - volet tâche.

     PARAMETRES:  Nom du serveur       (A_NOM_SERVEUR)
                  Numéro de soumission (A_ID_SOUMISSION)
   ******************************************************************/

   PROCEDURE TRAITER_STATUT_TACHE_AGT
   (
      A_NOM_SERVEUR   IN CIBLE.NOM_SERVEUR%TYPE            DEFAULT NULL  -- Nom du serveur
     ,A_ID_SOUMISSION IN HIST_TACHE_AGT.ID_SOUMISSION%TYPE DEFAULT NULL  -- Numéro de soumission
   )
   IS

      PRAGMA AUTONOMOUS_TRANSACTION;

      -- Curseur de recherche des évaluation à effectuer
      CURSOR C_EVALUATION IS
         SELECT ID_SOUMISSION
               ,NOM_SERVEUR
               ,NOM_TACHE
           FROM HIST_TACHE_AGT
          WHERE (
                      NOM_SERVEUR     = UPPER(A_NOM_SERVEUR)
                   OR A_NOM_SERVEUR   IS NULL
                )
            AND (
                      ID_SOUMISSION   = A_ID_SOUMISSION
                   OR A_ID_SOUMISSION IS NULL
                )
            AND STATUT_EXEC = 'EV'
         FOR UPDATE OF STATUT_EXEC
                      ,EVALUATION
         ORDER BY ID_SOUMISSION;

      -- Curseur de recherche des notification à effectuer
      CURSOR C_EVENEMENT_A_NOTIFIER_TACHE IS
         SELECT HTA.ID_SOUMISSION
               ,HTA.NOM_SERVEUR
               ,HTA.NOM_TACHE
               ,HTA.STATUT_EXEC
               ,HTA.DH_DEBUT
               ,HTA.DH_FIN
               ,HTA.CODE_RETOUR
               ,HTA.EVALUATION
               ,HTA.JOURNAL
               ,HTA.STATUT_NOTIF_AVER
               ,HTA.STATUT_NOTIF_EXEC
               ,HTA.STATUT_NOTIF_EXEC_OPT
               ,TAG.DESTI_NOTIF
               ,TAG.TYPE_NOTIF_JOURNAL
               ,TAG.DESTI_NOTIF_OPT
               ,TAG.TYPE_NOTIF_JOURNAL_OPT
               ,PAR.LANGUE
           FROM HIST_TACHE_AGT HTA
               ,TACHE_AGT      TAG
               ,PARAMETRE      PAR
          WHERE HTA.NOM_SERVEUR = TAG.NOM_SERVEUR
            AND HTA.NOM_TACHE   = TAG.NOM_TACHE
            AND (
                      HTA.NOM_SERVEUR    = UPPER(A_NOM_SERVEUR)
                   OR A_NOM_SERVEUR     IS NULL
                )
            AND (
                      HTA.ID_SOUMISSION  = A_ID_SOUMISSION
                   OR A_ID_SOUMISSION   IS NULL
                )
            AND (
                      HTA.STATUT_NOTIF_AVER     = 'AE'
                   OR HTA.STATUT_NOTIF_EXEC     = 'AE'
                   OR HTA.STATUT_NOTIF_EXEC_OPT = 'AE'
                )
          FOR UPDATE OF HTA.STATUT_NOTIF_AVER
                       ,HTA.STATUT_NOTIF_EXEC
          ORDER BY HTA.ID_SOUMISSION;

      -- Variables locales
      V_STATUT_EXEC      HIST_TACHE_AGT.STATUT_EXEC%TYPE;
      V_TEXTE_EVALUATION HIST_TACHE_AGT.EVALUATION%TYPE;
      V_TEXTE            VARCHAR2(1024 CHAR);

      -- Variables locales (envoi journal, si requis)
      V_FICHIER_JOURNAL      HIST_TACHE_AGT.FICHIER_JOURNAL%TYPE;
      V_FICHIER_JOURNAL_OPT  HIST_TACHE_AGT.FICHIER_JOURNAL%TYPE;
      V_JOURNAL              BLOB;
      V_DEST_OFFSET          INTEGER;
      V_SRC_OFFSET           INTEGER;
      V_LANG_CTX             INTEGER;
      V_RC                   INTEGER;

   BEGIN

      -- Vérification pour délai d'exécution
      UPDATE HIST_TACHE_AGT HTA
         SET STATUT_NOTIF_AVER = 'AE'
       WHERE NOM_SERVEUR       = UPPER(A_NOM_SERVEUR)
         AND STATUT_EXEC       = 'EX'
         AND STATUT_NOTIF_AVER = 'NO'
         AND (SYSDATE - DH_DEBUT) * 1440 > (SELECT DELAI_AVERTISSEMENT
                                              FROM TACHE_AGT
                                             WHERE NOM_SERVEUR = HTA.NOM_SERVEUR
                                               AND NOM_TACHE   = HTA.NOM_TACHE
                                           );

      -- Évaluation de la fin d'une tâche
      FOR RC_EVALUATION IN C_EVALUATION LOOP
      
         EVALUATION_STATUT_TACHE(RC_EVALUATION.ID_SOUMISSION,V_STATUT_EXEC,V_TEXTE_EVALUATION);

         -- Mise à jour des notifications requises
         UPDATE HIST_TACHE_AGT HTA
            SET STATUT_NOTIF_EXEC      = DECODE((SELECT TYPE_NOTIF
                                                   FROM TACHE_AGT
                                                  WHERE NOM_SERVEUR = RC_EVALUATION.NOM_SERVEUR
                                                    AND NOM_TACHE   = RC_EVALUATION.NOM_TACHE
                                                )
                                                /* Toujours */
                                               ,'AL','AE'
                                                /* Notification de retard (avis de fin de tâche) */
                                               ,DECODE(STATUT_NOTIF_AVER
                                                      ,'OK','AE'
                                                       /* Notification sur statut */
                                                      ,DECODE(V_STATUT_EXEC
                                                             ,'ER','AE'
                                                             ,'OK'
                                                             )
                                                      )
                                               )
                ,STATUT_NOTIF_EXEC_OPT = DECODE((SELECT TYPE_NOTIF_OPT
                                                   FROM TACHE_AGT
                                                  WHERE NOM_SERVEUR = RC_EVALUATION.NOM_SERVEUR
                                                    AND NOM_TACHE   = RC_EVALUATION.NOM_TACHE
                                                )
                                                /* Pas de notification OPT */
                                               ,TO_CHAR(NULL),'OK'
                                                /* Toujours */
                                               ,'AL','AE'
                                                /* Notification de retard (avis de fin de tâche) */
                                               ,DECODE(STATUT_NOTIF_AVER
                                                      ,'OK','AE'
                                                       /* Notification sur statut */
                                                      ,DECODE(V_STATUT_EXEC
                                                             ,'ER','AE'
                                                             ,'OK'
                                                             )
                                                      )
                                               )
               ,STATUT_EXEC = V_STATUT_EXEC
               ,EVALUATION  = V_TEXTE_EVALUATION
          WHERE CURRENT OF C_EVALUATION;
      
      END LOOP;

      -- Traitement de tous les tâches en statut AE (notification)
      FOR RC_EVENEMENT_A_NOTIFIER_TACHE IN C_EVENEMENT_A_NOTIFIER_TACHE LOOP
      
         -- Initialisation
         V_FICHIER_JOURNAL     := NULL;
         V_FICHIER_JOURNAL_OPT := NULL;
         V_JOURNAL             := NULL;

         -- Incomplet
         IF (RC_EVENEMENT_A_NOTIFIER_TACHE.STATUT_EXEC = 'NC') THEN
            
            IF (RC_EVENEMENT_A_NOTIFIER_TACHE.LANGUE = 'FR') THEN
               V_TEXTE := 'La tâche ' || RC_EVENEMENT_A_NOTIFIER_TACHE.ID_SOUMISSION || ' était en cours d''exécution pendant un redémarrage de l''agent. Le statut de la tâche est incertain (intervention manuelle requise).' || CHR(13) || CHR(10);
            ELSE
               V_TEXTE := 'The job ' || RC_EVENEMENT_A_NOTIFIER_TACHE.ID_SOUMISSION || ' was running while the agent restart. The status of the job is uncertain (manual follow up is required).' || CHR(13) || CHR(10);
            END IF;

         -- En cours (trop long)
         ELSIF (RC_EVENEMENT_A_NOTIFIER_TACHE.STATUT_EXEC = 'EX') THEN

            IF (RC_EVENEMENT_A_NOTIFIER_TACHE.LANGUE = 'FR') THEN
               V_TEXTE := 'La tâche ' || RC_EVENEMENT_A_NOTIFIER_TACHE.ID_SOUMISSION || ' est encore en cours d''exécution (n''a pas terminée dans le délai prescrit).' || CHR(13) || CHR(10);
            ELSE
               V_TEXTE := 'The job ' || RC_EVENEMENT_A_NOTIFIER_TACHE.ID_SOUMISSION || ' is still running (failed to complete within the threashold).' || CHR(13) || CHR(10);
            END IF;

         -- Erreur
         ELSIF (RC_EVENEMENT_A_NOTIFIER_TACHE.STATUT_EXEC = 'ER') THEN

            IF (RC_EVENEMENT_A_NOTIFIER_TACHE.LANGUE = 'FR') THEN
               V_TEXTE := 'La tâche ' || RC_EVENEMENT_A_NOTIFIER_TACHE.ID_SOUMISSION || ' a terminée anormalement.'                  || CHR(13) || CHR(10) || CHR(13) || CHR(10)
                       || 'Début'     || CHR(9) || ' : ' || TO_CHAR(RC_EVENEMENT_A_NOTIFIER_TACHE.DH_DEBUT,'YYYY/MM/DD:HH24:MI:SS')  || CHR(13) || CHR(10)
                       || 'Fin'       || CHR(9) || ' : ' || TO_CHAR(RC_EVENEMENT_A_NOTIFIER_TACHE.DH_FIN,'YYYY/MM/DD:HH24:MI:SS')    || CHR(13) || CHR(10) || CHR(13) || CHR(10)
                       || 'RC était'  || CHR(9) || ' : ' || RC_EVENEMENT_A_NOTIFIER_TACHE.CODE_RETOUR                                || CHR(13) || CHR(10) || CHR(13) || CHR(10)
                       || 'EV était'  || CHR(9) || ' : '                                                                             || CHR(13) || CHR(10)
                       || ' - ' || REPLACE(RC_EVENEMENT_A_NOTIFIER_TACHE.EVALUATION,CHR(10),CHR(10) || ' - ');
            ELSE
               V_TEXTE := 'The job ' || RC_EVENEMENT_A_NOTIFIER_TACHE.ID_SOUMISSION || ' has failed.'                               || CHR(13) || CHR(10) || CHR(13) || CHR(10)
                       || 'Start at' || CHR(9) || ' : ' || TO_CHAR(RC_EVENEMENT_A_NOTIFIER_TACHE.DH_DEBUT,'YYYY/MM/DD:HH24:MI:SS')  || CHR(13) || CHR(10)
                       || 'End at'   || CHR(9) || ' : ' || TO_CHAR(RC_EVENEMENT_A_NOTIFIER_TACHE.DH_FIN,'YYYY/MM/DD:HH24:MI:SS')    || CHR(13) || CHR(10) || CHR(13) || CHR(10)
                       || 'RC was'   || CHR(9) || ' : ' || RC_EVENEMENT_A_NOTIFIER_TACHE.CODE_RETOUR                                || CHR(13) || CHR(10) || CHR(13) || CHR(10)
                       || 'EV was'   || CHR(9) || ' : '                                                                             || CHR(13) || CHR(10)
                       || ' - ' || REPLACE(RC_EVENEMENT_A_NOTIFIER_TACHE.EVALUATION,CHR(10),CHR(10) || ' - ');
            END IF;

            IF (SUBSTR(V_TEXTE,LENGTH(V_TEXTE) - 2,3) = ' - ') THEN
               V_TEXTE := SUBSTR(V_TEXTE,1,LENGTH(V_TEXTE) - 2);
            END IF;

            -- Si le journal doit être envoyé via SMTP
            IF (RC_EVENEMENT_A_NOTIFIER_TACHE.TYPE_NOTIF_JOURNAL IN ('OF','VR')) THEN
               V_FICHIER_JOURNAL := RC_EVENEMENT_A_NOTIFIER_TACHE.ID_SOUMISSION || '.LOG.TXT';
            END IF;

            -- Si le journal optionnel doit être envoyé via SMTP
            IF (RC_EVENEMENT_A_NOTIFIER_TACHE.TYPE_NOTIF_JOURNAL_OPT IN ('OF','VR')) THEN
               V_FICHIER_JOURNAL_OPT := RC_EVENEMENT_A_NOTIFIER_TACHE.ID_SOUMISSION || '.LOG.TXT';
            END IF;

         -- OK
         ELSIF (RC_EVENEMENT_A_NOTIFIER_TACHE.STATUT_EXEC = 'OK') THEN

            IF (RC_EVENEMENT_A_NOTIFIER_TACHE.LANGUE = 'FR') THEN
               V_TEXTE := 'La tâche ' || RC_EVENEMENT_A_NOTIFIER_TACHE.ID_SOUMISSION || ' a terminée normalement.'                   || CHR(13) || CHR(10) || CHR(13) || CHR(10)
                       || 'Début'     || CHR(9) || ' : ' || TO_CHAR(RC_EVENEMENT_A_NOTIFIER_TACHE.DH_DEBUT,'YYYY/MM/DD:HH24:MI:SS')  || CHR(13) || CHR(10)
                       || 'Fin'       || CHR(9) || ' : ' || TO_CHAR(RC_EVENEMENT_A_NOTIFIER_TACHE.DH_FIN,'YYYY/MM/DD:HH24:MI:SS')    || CHR(13) || CHR(10) || CHR(13) || CHR(10)
                       || 'RC était'  || CHR(9) || ' : ' || RC_EVENEMENT_A_NOTIFIER_TACHE.CODE_RETOUR                                || CHR(13) || CHR(10) || CHR(13) || CHR(10)
                       || 'EV était'  || CHR(9) || ' : '                                                                             || CHR(13) || CHR(10)
                       || ' - ' || REPLACE(RC_EVENEMENT_A_NOTIFIER_TACHE.EVALUATION,CHR(10),CHR(10) || ' - ');
            ELSE
               V_TEXTE := 'The job ' || RC_EVENEMENT_A_NOTIFIER_TACHE.ID_SOUMISSION || ' has completed sucessfully.'                || CHR(13) || CHR(10) || CHR(13) || CHR(10)
                       || 'Start at' || CHR(9) || ' : ' || TO_CHAR(RC_EVENEMENT_A_NOTIFIER_TACHE.DH_DEBUT,'YYYY/MM/DD:HH24:MI:SS')  || CHR(13) || CHR(10)
                       || 'End at'   || CHR(9) || ' : ' || TO_CHAR(RC_EVENEMENT_A_NOTIFIER_TACHE.DH_FIN,'YYYY/MM/DD:HH24:MI:SS')    || CHR(13) || CHR(10) || CHR(13) || CHR(10)
                       || 'RC was'   || CHR(9) || ' : ' || RC_EVENEMENT_A_NOTIFIER_TACHE.CODE_RETOUR                                || CHR(13) || CHR(10) || CHR(13) || CHR(10)
                       || 'EV was'   || CHR(9) || ' : '                                                                             || CHR(13) || CHR(10)
                       || ' - ' || REPLACE(RC_EVENEMENT_A_NOTIFIER_TACHE.EVALUATION,CHR(10),CHR(10) || ' - ');
            END IF;

            IF (SUBSTR(V_TEXTE,LENGTH(V_TEXTE) - 2,3) = ' - ') THEN
               V_TEXTE := SUBSTR(V_TEXTE,1,LENGTH(V_TEXTE) - 2);
            END IF;

            -- Si le journal doit être envoyé via SMTP
            IF (RC_EVENEMENT_A_NOTIFIER_TACHE.TYPE_NOTIF_JOURNAL IN ('VR')) THEN
               V_FICHIER_JOURNAL := RC_EVENEMENT_A_NOTIFIER_TACHE.ID_SOUMISSION || '.LOG.TXT';
            END IF;

            -- Si le journal optionnel doit être envoyé via SMTP
            IF (RC_EVENEMENT_A_NOTIFIER_TACHE.TYPE_NOTIF_JOURNAL_OPT IN ('VR')) THEN
               V_FICHIER_JOURNAL_OPT := RC_EVENEMENT_A_NOTIFIER_TACHE.ID_SOUMISSION || '.LOG.TXT';
            END IF;

         END IF;

         -- Conversion du journal de CLOB vers BLOB pour envoi SMTP (si requis)         
         IF (V_FICHIER_JOURNAL IS NOT NULL OR V_FICHIER_JOURNAL_OPT IS NOT NULL) THEN

            DBMS_LOB.CREATETEMPORARY(V_JOURNAL, TRUE);
            V_DEST_OFFSET := 1;
            V_SRC_OFFSET  := 1;
            V_LANG_CTX    := DBMS_LOB.DEFAULT_LANG_CTX;
            DBMS_LOB.CONVERTTOBLOB(DEST_LOB    => V_JOURNAL
                                  ,SRC_CLOB    => RC_EVENEMENT_A_NOTIFIER_TACHE.JOURNAL
                                  ,AMOUNT      => DBMS_LOB.LOBMAXSIZE
                                  ,DEST_OFFSET => V_DEST_OFFSET
                                  ,SRC_OFFSET  => V_SRC_OFFSET
                                  ,BLOB_CSID   => DBMS_LOB.DEFAULT_CSID
                                  ,LANG_CONTEXT=> V_LANG_CTX
                                  ,WARNING     => V_RC
                                  );

         END IF;
         

         -- Notification
         IF ((RC_EVENEMENT_A_NOTIFIER_TACHE.STATUT_NOTIF_AVER = 'AE') OR (RC_EVENEMENT_A_NOTIFIER_TACHE.STATUT_NOTIF_EXEC = 'AE')) THEN

            IF (SDBM_UTIL.NOTIFIER_EVENEMENT('TR'
                                            ,RC_EVENEMENT_A_NOTIFIER_TACHE.NOM_SERVEUR
                                            ,RC_EVENEMENT_A_NOTIFIER_TACHE.NOM_TACHE
                                            ,NULL
                                            ,V_TEXTE
                                            ,'AGENT'
                                            ,RC_EVENEMENT_A_NOTIFIER_TACHE.DESTI_NOTIF
                                            ,V_FICHIER_JOURNAL
                                            ,(CASE V_FICHIER_JOURNAL WHEN NULL THEN NULL ELSE V_JOURNAL END)
                                            )
               ) THEN

               -- Mise à jour du statut de notification (si la notification est réussis)
               UPDATE HIST_TACHE_AGT
                  SET STATUT_NOTIF_AVER = DECODE(STATUT_NOTIF_AVER
                                                ,'AE','OK'
                                                ,STATUT_NOTIF_AVER
                                                )
                     ,STATUT_NOTIF_EXEC = DECODE(STATUT_NOTIF_EXEC
                                                ,'AE','OK'
                                                ,STATUT_NOTIF_EXEC
                                                )
                WHERE CURRENT OF C_EVENEMENT_A_NOTIFIER_TACHE;

            END IF;
         
         END IF;


         -- Notification optionnelle
         IF (RC_EVENEMENT_A_NOTIFIER_TACHE.STATUT_NOTIF_EXEC_OPT = 'AE') THEN

            IF (SDBM_UTIL.NOTIFIER_EVENEMENT('TR'
                                            ,RC_EVENEMENT_A_NOTIFIER_TACHE.NOM_SERVEUR
                                            ,RC_EVENEMENT_A_NOTIFIER_TACHE.NOM_TACHE
                                            ,NULL
                                            ,V_TEXTE
                                            ,'AGENT'
                                            ,RC_EVENEMENT_A_NOTIFIER_TACHE.DESTI_NOTIF_OPT
                                            ,V_FICHIER_JOURNAL_OPT
                                            ,(CASE V_FICHIER_JOURNAL_OPT WHEN NULL THEN NULL ELSE V_JOURNAL END)
                                            )
               ) THEN
               NULL;
            END IF;

            -- Mise à jour du statut de notification (dans tout les cas, sans égard à la réussite)
            UPDATE HIST_TACHE_AGT
               SET STATUT_NOTIF_EXEC_OPT = 'OK'
             WHERE CURRENT OF C_EVENEMENT_A_NOTIFIER_TACHE;

         END IF;

         -- Libération du BLOB temporaire (si requis)
         IF (V_JOURNAL IS NOT NULL) THEN
            DBMS_LOB.FREETEMPORARY(V_JOURNAL);
         END IF;

      END LOOP;


      -- Fin de la transaction locale
      COMMIT;


   END TRAITER_STATUT_TACHE_AGT;


   /******************************************************************
     PROCEDURE : TRAITEMENT_TACHES_AGT
     AUTEUR    : Benoit Bouthillier 2011-10-14
    ------------------------------------------------------------------
     BUT : Obtenir la liste des tâches à exécuter pour le serveur
           reçu en paramètre.

     PARAMETRES:  Nom du serveur            (A_NOM_SERVEUR)
                  Fréquence de vérification (A_FREQU_VERIF_AGENT_TACHE)
                  Curseur de retour         (A_CUR_INFO)
   ******************************************************************/

   PROCEDURE TRAITEMENT_TACHES_AGT
   (
      A_NOM_SERVEUR             IN  CIBLE.NOM_SERVEUR%TYPE                  -- Nom du serveur
     ,A_FREQU_VERIF_AGENT_TACHE OUT PARAMETRE.FREQU_VERIF_AGENT_TACHE%TYPE  -- Fréquence de vérification
     ,A_CUR_INFO                OUT T_RC_INFO                               -- Curseur de retour
   )
   IS

      -- Curseur de recherche des tâches à exécuter
      CURSOR C_TACHE (A_SEP_REP CHAR) IS
         SELECT NOM_TACHE                                                                                              NOM_TACHE
               ,REPERTOIRE_JOURNAL || A_SEP_REP || TO_CHAR(SYSDATE,'YYYYMMDD.HH24MISS') || '.' || NOM_TACHE || '.LOG'  FICHIER_JOURNAL
               ,DH_PROCHAINE_EXEC                                                                                      DH_PROCHAINE_EXEC
           FROM TACHE_AGT TAG
          WHERE EXECUTION          = 'AC'
            AND NOM_SERVEUR        = UPPER(A_NOM_SERVEUR)
            AND DH_PROCHAINE_EXEC <= SYSDATE
            AND EXISTS (SELECT 1
                          FROM PARAMETRE
                         WHERE STATUT_AGENT = 'AC'
                       )
            AND NOT EXISTS (SELECT 1
                              FROM HIST_TACHE_AGT
                             WHERE NOM_SERVEUR  = TAG.NOM_SERVEUR
                               AND NOM_TACHE    = TAG.NOM_TACHE
                               AND STATUT_EXEC  IN ('SB','SR','EX','EV')
                           )
          ORDER BY DH_PROCHAINE_EXEC;

      -- Curseur dynamique de retour d'information
      VC_INFO T_RC_INFO;

      -- Variable locale
      V_SEP_REP                     CHAR(1 CHAR) := '/';
      V_RETARD_MAX_SOUMISSION_TACHE PARAMETRE.RETARD_MAX_SOUMISSION_TACHE%TYPE;
      V_LANGUE                      PARAMETRE.LANGUE%TYPE;

   BEGIN
  
      -- Initialisation complétée (en cas de reconnexion)
      IF (INITIALISATION) THEN
         INITIALISATION := FALSE;
      END IF;

      -- Traitement des statuts en attente
      TRAITER_STATUT_TACHE_AGT(A_NOM_SERVEUR => UPPER(A_NOM_SERVEUR));
      
      -- Recherche du séparateur de répertoire
      BEGIN

         SELECT '\'
           INTO V_SEP_REP
           FROM INFO_AGT
          WHERE NOM_SERVEUR = UPPER(A_NOM_SERVEUR)
            AND UPPER(NOM_OS) LIKE 'WINDOWS%';

      EXCEPTION
      
         WHEN NO_DATA_FOUND THEN
            V_SEP_REP := '/';
      END;
         

      -- Envoi du pilotage a l'agent / Obtenir le délai de retard maximum
      SELECT RETARD_MAX_SOUMISSION_TACHE
            ,LANGUE
            ,FREQU_VERIF_AGENT_TACHE
        INTO V_RETARD_MAX_SOUMISSION_TACHE
            ,V_LANGUE
            ,A_FREQU_VERIF_AGENT_TACHE
        FROM PARAMETRE;

      -- Préparation de l'envoi des tâches à exécuter
      FOR RC_TACHE IN C_TACHE(V_SEP_REP) LOOP
      
         IF (RC_TACHE.DH_PROCHAINE_EXEC >= (SYSDATE - V_RETARD_MAX_SOUMISSION_TACHE/1440)) THEN

            INSERT INTO HIST_TACHE_AGT
            (
               ID_SOUMISSION
              ,NOM_SERVEUR
              ,NOM_TACHE
              ,FICHIER_JOURNAL
              ,DH_SOUMISSION
              ,STATUT_EXEC
            )
            VALUES
            (
               HTA_ID_SOUMISSION.NEXTVAL
              ,UPPER(A_NOM_SERVEUR)
              ,RC_TACHE.NOM_TACHE
              ,RC_TACHE.FICHIER_JOURNAL
              ,SYSDATE
              ,'SB'
            );

         ELSE

            INSERT INTO HIST_TACHE_AGT
            (
               ID_SOUMISSION
              ,NOM_SERVEUR
              ,NOM_TACHE
              ,FICHIER_JOURNAL
              ,DH_SOUMISSION
              ,STATUT_EXEC
              ,EVALUATION
            )
            VALUES
            (
               HTA_ID_SOUMISSION.NEXTVAL
              ,UPPER(A_NOM_SERVEUR)
              ,RC_TACHE.NOM_TACHE
              ,RC_TACHE.FICHIER_JOURNAL
              ,SYSDATE
              ,'SF'
              ,DECODE(V_LANGUE
                     ,'FR','La tâche n''a pas été soumise parce que le délai maximum de retard à été atteint (une nouvelle date d''exécution sera calculée).'
                          ,'The task was not submitted because the maximum period of delay has been reached (a new execution date will be calculated).'
                     )
            );

            -- Mise à jour de la date de prochaine exécution
            UPDATE TACHE_AGT
               SET DH_PROCHAINE_EXEC = SDBM_UTIL.INTERVAL_TO_DATE(INTERVAL)
             WHERE NOM_SERVEUR = UPPER(A_NOM_SERVEUR)
               AND NOM_TACHE   = RC_TACHE.NOM_TACHE;

            JOURNALISER('SDBM_AGENT.TRAITEMENT_TACHES_AGT','WARNING','The task ' || UPPER(A_NOM_SERVEUR) || ' / ' || RC_TACHE.NOM_TACHE || ' was not submitted because the maximum period of delay has been reached (a new execution date will be calculated).');

         END IF;
      
      END LOOP;

      -- Fin de la transaction de préparation
      COMMIT;
  
      -- Ouverture du curseur de recherche
      OPEN VC_INFO FOR SELECT HTA.ID_SOUMISSION
                             ,TAG.NOM_TACHE
                             ,TAG.EXECUTABLE
                             ,TAG.PARAMETRE
                             ,TAG.REPERTOIRE
                             ,HTA.FICHIER_JOURNAL
                         FROM HIST_TACHE_AGT HTA
                             ,TACHE_AGT      TAG
                        WHERE HTA.NOM_SERVEUR = TAG.NOM_SERVEUR
                          AND HTA.NOM_TACHE   = TAG.NOM_TACHE
                          AND HTA.NOM_SERVEUR = UPPER(A_NOM_SERVEUR)
                          AND HTA.STATUT_EXEC = 'SB'
                        ORDER BY ID_SOUMISSION;

      -- Assignation de retour
      A_CUR_INFO := VC_INFO;

   END TRAITEMENT_TACHES_AGT;


   /******************************************************************
     PROCEDURE : CHANGER_STATUT_EXEC_TACHE_AGT
     AUTEUR    : Benoit Bouthillier 2009-04-01
    ------------------------------------------------------------------
     BUT : Changement du statut d'une tâche
           reçu en paramètre.

     PARAMETRES:  Numéro de soumission (A_ID_SOUMISSION)
                  Nouveau statut       (A_STATUT_EXEC)
                  Code de retour       (A_CODE_RETOUR)
   ******************************************************************/

   PROCEDURE CHANGER_STATUT_EXEC_TACHE_AGT
   (
      A_ID_SOUMISSION IN HIST_TACHE_AGT.ID_SOUMISSION%TYPE             -- Numéro de soumission
     ,A_STATUT_EXEC   IN HIST_TACHE_AGT.STATUT_EXEC%TYPE               -- Nouveau statut d'exécution
     ,A_CODE_RETOUR   IN HIST_TACHE_AGT.CODE_RETOUR%TYPE DEFAULT NULL  -- Code de retour
   )
   IS

   BEGIN
  
      -- Mise à jour de la prochaine exécution (s'il y a lieu)
      IF (A_STATUT_EXEC = 'EV') THEN

         UPDATE TACHE_AGT
            SET DH_PROCHAINE_EXEC = SDBM_UTIL.INTERVAL_TO_DATE(INTERVAL)
          WHERE (NOM_SERVEUR,NOM_TACHE) = (SELECT NOM_SERVEUR, NOM_TACHE
                                             FROM HIST_TACHE_AGT
                                            WHERE ID_SOUMISSION = A_ID_SOUMISSION
                                           );

      END IF;

      -- Mise à jour de l'historique d'une tâche
      UPDATE HIST_TACHE_AGT
         SET STATUT_EXEC = A_STATUT_EXEC
            ,DH_DEBUT    = DECODE(A_STATUT_EXEC
                                 ,'EX',SYSDATE
                                 ,DH_DEBUT
                                 )
            ,DH_FIN      = DECODE(A_STATUT_EXEC
                                 ,'EV',SYSDATE
                                 ,DH_FIN
                                 )
            ,CODE_RETOUR = A_CODE_RETOUR
            ,JOURNAL     = DECODE(A_STATUT_EXEC
                                 ,'EX',EMPTY_CLOB()
                                 ,JOURNAL
                                 )
       WHERE ID_SOUMISSION = A_ID_SOUMISSION;

      -- On ne retourne pas en arrière (l'agent pousuivra de toute façon)
      COMMIT;


      -- Traitement immédiat du statut sur fin d'une tâche
      IF (A_STATUT_EXEC = 'EV') THEN

         TRAITER_STATUT_TACHE_AGT(A_ID_SOUMISSION => A_ID_SOUMISSION);

      END IF;

   END CHANGER_STATUT_EXEC_TACHE_AGT;


   /******************************************************************
     PROCEDURE : AJOUTER_JOURNAL_TACHE_AGT
     AUTEUR    : Benoit Bouthillier 2009-04-08 (2018-02-01)
    ------------------------------------------------------------------
     BUT : Ajout d'un bloc au journal d'une tâche.

     PARAMETRES:  Numéro de soumission (A_ID_SOUMISSION)
                  Tampon à ajouter     (A_JOURNAL)
                  Vidange du journal   (A_VIDER_JOURNAL)
   ******************************************************************/

   PROCEDURE AJOUTER_JOURNAL_TACHE_AGT
   (
      A_ID_SOUMISSION IN HIST_TACHE_AGT.ID_SOUMISSION%TYPE  -- Numéro de soumission
     ,A_JOURNAL       IN HIST_TACHE_AGT.JOURNAL%TYPE        -- Tampon à ajouter
     ,A_VIDER_JOURNAL IN NUMBER DEFAULT 0                   -- Vidange du journal
   )
   IS
   
      V_PTR_JOURNAL CLOB;

   BEGIN
  
      IF (A_VIDER_JOURNAL = 1) THEN
      
         UPDATE HIST_TACHE_AGT
            SET JOURNAL = EMPTY_CLOB()
          WHERE ID_SOUMISSION = A_ID_SOUMISSION;

      END IF;
      
      SELECT JOURNAL
        INTO V_PTR_JOURNAL
        FROM HIST_TACHE_AGT
       WHERE ID_SOUMISSION = A_ID_SOUMISSION
         FOR UPDATE;

      -- Ajout de la ligne au tampon existant - si l'espace maximale n'est pas atteint
      IF ((DBMS_LOB.GETLENGTH(V_PTR_JOURNAL) + DBMS_LOB.GETLENGTH(A_JOURNAL)) < C_GROSSEUR_MAX_JOURNAL) THEN
         DBMS_LOB.APPEND(V_PTR_JOURNAL,A_JOURNAL);
      ELSE
         -- Ajout de l'indicateur MSG_INCOMPLETE si pas déjà là
         IF NOT (DBMS_LOB.SUBSTR(V_PTR_JOURNAL,LENGTH(MSG_INCOMPLETE),DBMS_LOB.GETLENGTH(V_PTR_JOURNAL) - LENGTH(MSG_INCOMPLETE) + 1) = MSG_INCOMPLETE) THEN
            DBMS_LOB.APPEND(V_PTR_JOURNAL,CHR(13) || CHR(10) || MSG_INCOMPLETE);
         END IF;
      END IF;
   
   END AJOUTER_JOURNAL_TACHE_AGT;


   /******************************************************************
     PROCEDURE : ENREGISTRER_INFO_DYNAMIQUE
     AUTEUR    : Benoit Bouthillier 2009-06-27
    ------------------------------------------------------------------
     BUT : Permet l'enregistrement d'information dans :
              CD_INFO_DYNAMIQUE_AGT
              CD_INFO_DYNAMIQUE_CPU_AGT

     PARAMETRES:  Date/heure collecte                 (A_DH_COLLECTE_DONNEE)
                  Nom du serveur                      (A_NOM_SERVEUR)
                  Collecte CD_INFO_DYNAMIQUE_AGT      (...)
                  Collecte CD_INFO_DYNAMIQUE_CPU_AGT  (...)

   ******************************************************************/

   PROCEDURE ENREGISTRER_INFO_DYNAMIQUE
   (
      A_DH_COLLECTE_DONNEE IN CD_INFO_DYNAMIQUE_AGT.DH_COLLECTE_DONNEE%TYPE  -- Date/heure collecte
     ,A_NOM_SERVEUR        IN CD_INFO_DYNAMIQUE_AGT.NOM_SERVEUR%TYPE         -- Nom du serveur
     ,A_MEM_TOTAL          IN CD_INFO_DYNAMIQUE_AGT.MEM_TOTAL%TYPE           -- Collecte CD_INFO_DYNAMIQUE_AGT
     ,A_MEM_ACTUAL_USED    IN CD_INFO_DYNAMIQUE_AGT.MEM_ACTUAL_USED%TYPE     -- ...
     ,A_MEM_ACTUAL_FREE    IN CD_INFO_DYNAMIQUE_AGT.MEM_ACTUAL_FREE%TYPE
     ,A_MEM_USED           IN CD_INFO_DYNAMIQUE_AGT.MEM_USED%TYPE
     ,A_MEM_FREE           IN CD_INFO_DYNAMIQUE_AGT.MEM_FREE%TYPE
     ,A_SWP_TOTAL          IN CD_INFO_DYNAMIQUE_AGT.SWP_TOTAL%TYPE
     ,A_SWP_USED           IN CD_INFO_DYNAMIQUE_AGT.SWP_USED%TYPE
     ,A_SWP_FREE           IN CD_INFO_DYNAMIQUE_AGT.SWP_FREE%TYPE
     ,A_SWP_PAGE_IN        IN CD_INFO_DYNAMIQUE_AGT.SWP_PAGE_IN%TYPE
     ,A_SWP_PAGE_OUT       IN CD_INFO_DYNAMIQUE_AGT.SWP_PAGE_OUT%TYPE
     ,A_SWP_DELTA_PAGE_IN  IN CD_INFO_DYNAMIQUE_AGT.SWP_DELTA_PAGE_IN%TYPE
     ,A_SWP_DELTA_PAGE_OUT IN CD_INFO_DYNAMIQUE_AGT.SWP_DELTA_PAGE_OUT%TYPE
     ,A_SYS_LOAD_AVG       IN CD_INFO_DYNAMIQUE_AGT.SYS_LOAD_AVG%TYPE
     ,A_LISTE_USER_TIME    IN VARCHAR2                                       -- Collecte CD_INFO_DYNAMIQUE_CPU_AGT
     ,A_LISTE_SYS_TIME     IN VARCHAR2                                       -- ...
     ,A_LISTE_NICE_TIME    IN VARCHAR2
     ,A_LISTE_WAIT_TIME    IN VARCHAR2
     ,A_LISTE_TOTAL_TIME   IN VARCHAR2
     ,A_LISTE_IDLE_TIME    IN VARCHAR2
   )
   IS

      V_TAB_USER_TIME      APEX_APPLICATION_GLOBAL.VC_ARR2;
      V_TAB_SYS_TIME       APEX_APPLICATION_GLOBAL.VC_ARR2;
      V_TAB_NICE_TIME      APEX_APPLICATION_GLOBAL.VC_ARR2;
      V_TAB_WAIT_TIME      APEX_APPLICATION_GLOBAL.VC_ARR2;
      V_TAB_TOTAL_TIME     APEX_APPLICATION_GLOBAL.VC_ARR2;
      V_TAB_IDLE_TIME      APEX_APPLICATION_GLOBAL.VC_ARR2;

      V_SKIP               BOOLEAN                                   := FALSE;
      V_CPU_USER_TIME      CD_INFO_DYNAMIQUE_AGT.CPU_USER_TIME%TYPE  := 0;
      V_CPU_SYS_TIME       CD_INFO_DYNAMIQUE_AGT.CPU_SYS_TIME%TYPE   := 0;
      V_CPU_NICE_TIME      CD_INFO_DYNAMIQUE_AGT.CPU_NICE_TIME%TYPE  := 0;
      V_CPU_WAIT_TIME      CD_INFO_DYNAMIQUE_AGT.CPU_WAIT_TIME%TYPE  := 0;
      V_CPU_TOTAL_TIME     CD_INFO_DYNAMIQUE_AGT.CPU_TOTAL_TIME%TYPE := 0;
      V_CPU_IDLE_TIME      CD_INFO_DYNAMIQUE_AGT.CPU_IDLE_TIME%TYPE  := 0;

      E_INVALID_NUMBER     EXCEPTION;
      PRAGMA EXCEPTION_INIT(E_INVALID_NUMBER,-01722);

   BEGIN

      -- Initialisation complétée (en cas de reconnexion)
      IF (INITIALISATION) THEN
         INITIALISATION := FALSE;
      END IF;

      -- Traitement des données par CPUs
      IF (LENGTH(A_LISTE_USER_TIME) > 0) THEN

         -- Conversion des listes en tableau
         V_TAB_USER_TIME  := APEX_UTIL.STRING_TO_TABLE(A_LISTE_USER_TIME,',');
         V_TAB_SYS_TIME   := APEX_UTIL.STRING_TO_TABLE(A_LISTE_SYS_TIME,',');
         V_TAB_NICE_TIME  := APEX_UTIL.STRING_TO_TABLE(A_LISTE_NICE_TIME,',');
         V_TAB_WAIT_TIME  := APEX_UTIL.STRING_TO_TABLE(A_LISTE_WAIT_TIME,',');
         V_TAB_TOTAL_TIME := APEX_UTIL.STRING_TO_TABLE(A_LISTE_TOTAL_TIME,',');
         V_TAB_IDLE_TIME  := APEX_UTIL.STRING_TO_TABLE(A_LISTE_IDLE_TIME,',');

         FOR I IN 1..V_TAB_USER_TIME.COUNT LOOP

            BEGIN

               INSERT INTO CD_INFO_DYNAMIQUE_CPU_AGT
               (
                  DH_COLLECTE_DONNEE
                 ,NOM_SERVEUR
                 ,ID
                 ,USER_TIME
                 ,SYS_TIME
                 ,NICE_TIME
                 ,WAIT_TIME
                 ,TOTAL_TIME
                 ,IDLE_TIME
               )
               VALUES
               (
                  A_DH_COLLECTE_DONNEE
                 ,UPPER(A_NOM_SERVEUR)
                 ,I - 1
                 ,V_TAB_USER_TIME(I)
                 ,V_TAB_SYS_TIME(I)
                 ,V_TAB_NICE_TIME(I)
                 ,V_TAB_WAIT_TIME(I)
                 ,V_TAB_TOTAL_TIME(I)
                 ,V_TAB_IDLE_TIME(I)
               );
            
            EXCEPTION
            
               WHEN E_INVALID_NUMBER THEN
                  
                  -- Ne pas comptabilisé au global (données invalides)
                  V_SKIP := TRUE;
                  JOURNALISER('SDBM_AGENT.ENREGISTRER_INFO_DYNAMIQUE','WARNING','Unable to insert the system statistics into CD_INFO_DYNAMIQUE_CPU_AGT '
                             || '(DH_COLLECTE_DONNEE,NOM_SERVEUR,ID,USER_TIME,SYS_TIME,NICE_TIME,WAIT_TIME,TOTAL_TIME,IDLE_TIME. '
                             || 'Data was : ('
                             || TO_CHAR(A_DH_COLLECTE_DONNEE,'YYYY/MM/DD:HH24:MI:SS')
                             || ',' || UPPER(A_NOM_SERVEUR)
                             || ',' || TRIM(TO_CHAR(I - 1))
                             || ',' || V_TAB_USER_TIME(I)
                             || ',' || V_TAB_SYS_TIME(I)
                             || ',' || V_TAB_NICE_TIME(I)
                             || ',' || V_TAB_WAIT_TIME(I)
                             || ',' || V_TAB_TOTAL_TIME(I)
                             || ',' || V_TAB_IDLE_TIME(I)
                             || ').');

               WHEN DUP_VAL_ON_INDEX THEN
               
                  DELETE FROM CD_INFO_DYNAMIQUE_CPU_AGT
                     WHERE DH_COLLECTE_DONNEE = A_DH_COLLECTE_DONNEE
                       AND NOM_SERVEUR        = UPPER(A_NOM_SERVEUR)      
                       AND ID                 = I - 1;

                  INSERT INTO CD_INFO_DYNAMIQUE_CPU_AGT
                  (
                     DH_COLLECTE_DONNEE
                    ,NOM_SERVEUR
                    ,ID
                    ,USER_TIME
                    ,SYS_TIME
                    ,NICE_TIME
                    ,WAIT_TIME
                    ,TOTAL_TIME
                    ,IDLE_TIME
                  )
                  VALUES
                  (
                     A_DH_COLLECTE_DONNEE
                    ,UPPER(A_NOM_SERVEUR)
                    ,I - 1
                    ,V_TAB_USER_TIME(I)
                    ,V_TAB_SYS_TIME(I)
                    ,V_TAB_NICE_TIME(I)
                    ,V_TAB_WAIT_TIME(I)
                    ,V_TAB_TOTAL_TIME(I)
                    ,V_TAB_IDLE_TIME(I)
                  );

            END;

            IF (V_SKIP = FALSE) THEN

               -- Calcul de l'usage global de tous les CPUs
               V_CPU_USER_TIME  := V_CPU_USER_TIME  + (V_TAB_USER_TIME(I)  / V_TAB_USER_TIME.COUNT);
               V_CPU_SYS_TIME   := V_CPU_SYS_TIME   + (V_TAB_SYS_TIME(I)   / V_TAB_SYS_TIME.COUNT);
               V_CPU_NICE_TIME  := V_CPU_NICE_TIME  + (V_TAB_NICE_TIME(I)  / V_TAB_NICE_TIME.COUNT);
               V_CPU_WAIT_TIME  := V_CPU_WAIT_TIME  + (V_TAB_WAIT_TIME(I)  / V_TAB_WAIT_TIME.COUNT);
               V_CPU_TOTAL_TIME := V_CPU_TOTAL_TIME + (V_TAB_TOTAL_TIME(I) / V_TAB_TOTAL_TIME.COUNT);
               V_CPU_IDLE_TIME  := V_CPU_IDLE_TIME  + (V_TAB_IDLE_TIME(I)  / V_TAB_IDLE_TIME.COUNT);

            ELSE

               V_SKIP := FALSE;

            END IF;

         END LOOP;

      END IF;


      -- Si le total est supérieur à 100%
      IF (V_CPU_USER_TIME > 1) THEN
         V_CPU_USER_TIME := 1;
      END IF;
      
      IF (V_CPU_SYS_TIME > 1) THEN
         V_CPU_SYS_TIME := 1;
      END IF;

      IF (V_CPU_NICE_TIME > 1) THEN
         V_CPU_NICE_TIME := 1;
      END IF;

      IF (V_CPU_WAIT_TIME > 1) THEN
         V_CPU_WAIT_TIME := 1;
      END IF;

      IF (V_CPU_TOTAL_TIME > 1) THEN
         V_CPU_TOTAL_TIME := 1;
      END IF;

      IF (V_CPU_IDLE_TIME > 1) THEN
         V_CPU_IDLE_TIME := 1;
      END IF;


      BEGIN

         -- Traitement des données globales
         INSERT INTO CD_INFO_DYNAMIQUE_AGT
         (
            DH_COLLECTE_DONNEE
           ,NOM_SERVEUR
           ,TYPE_INFO
           ,CPU_USER_TIME
           ,CPU_SYS_TIME
           ,CPU_NICE_TIME
           ,CPU_WAIT_TIME
           ,CPU_TOTAL_TIME
           ,CPU_IDLE_TIME
           ,MEM_TOTAL
           ,MEM_ACTUAL_USED
           ,MEM_ACTUAL_FREE
           ,MEM_USED
           ,MEM_FREE
           ,SWP_TOTAL
           ,SWP_USED
           ,SWP_FREE
           ,SWP_PAGE_IN
           ,SWP_PAGE_OUT
           ,SWP_DELTA_PAGE_IN
           ,SWP_DELTA_PAGE_OUT
           ,SYS_LOAD_AVG
         )
         VALUES
         (
            A_DH_COLLECTE_DONNEE
           ,UPPER(A_NOM_SERVEUR)
           ,'BR'
           ,V_CPU_USER_TIME
           ,V_CPU_SYS_TIME
           ,V_CPU_NICE_TIME
           ,V_CPU_WAIT_TIME
           ,V_CPU_TOTAL_TIME
           ,V_CPU_IDLE_TIME
           ,A_MEM_TOTAL
           ,A_MEM_ACTUAL_USED
           ,A_MEM_ACTUAL_FREE
           ,A_MEM_USED
           ,A_MEM_FREE
           ,A_SWP_TOTAL
           ,A_SWP_USED
           ,A_SWP_FREE
           ,A_SWP_PAGE_IN
           ,A_SWP_PAGE_OUT
           ,A_SWP_DELTA_PAGE_IN
           ,A_SWP_DELTA_PAGE_OUT
           ,A_SYS_LOAD_AVG
         );


      EXCEPTION

         WHEN DUP_VAL_ON_INDEX THEN
               
            DELETE FROM CD_INFO_DYNAMIQUE_AGT
             WHERE DH_COLLECTE_DONNEE = A_DH_COLLECTE_DONNEE
               AND NOM_SERVEUR        = UPPER(A_NOM_SERVEUR);

            -- Traitement des données globales
            INSERT INTO CD_INFO_DYNAMIQUE_AGT
            (
               DH_COLLECTE_DONNEE
              ,NOM_SERVEUR
              ,TYPE_INFO
              ,CPU_USER_TIME
              ,CPU_SYS_TIME
              ,CPU_NICE_TIME
              ,CPU_WAIT_TIME
              ,CPU_TOTAL_TIME
              ,CPU_IDLE_TIME
              ,MEM_TOTAL
              ,MEM_ACTUAL_USED
              ,MEM_ACTUAL_FREE
              ,MEM_USED
              ,MEM_FREE
              ,SWP_TOTAL
              ,SWP_USED
              ,SWP_FREE
              ,SWP_PAGE_IN
              ,SWP_PAGE_OUT
              ,SWP_DELTA_PAGE_IN
              ,SWP_DELTA_PAGE_OUT
              ,SYS_LOAD_AVG
            )
            VALUES
            (
               A_DH_COLLECTE_DONNEE
              ,UPPER(A_NOM_SERVEUR)
              ,'BR'
              ,V_CPU_USER_TIME
              ,V_CPU_SYS_TIME
              ,V_CPU_NICE_TIME
              ,V_CPU_WAIT_TIME
              ,V_CPU_TOTAL_TIME
              ,V_CPU_IDLE_TIME
              ,A_MEM_TOTAL
              ,A_MEM_ACTUAL_USED
              ,A_MEM_ACTUAL_FREE
              ,A_MEM_USED
              ,A_MEM_FREE
              ,A_SWP_TOTAL
              ,A_SWP_USED
              ,A_SWP_FREE
              ,A_SWP_PAGE_IN
              ,A_SWP_PAGE_OUT
              ,A_SWP_DELTA_PAGE_IN
              ,A_SWP_DELTA_PAGE_OUT
              ,A_SYS_LOAD_AVG
            );

      END;

      -- Mise à jour de l'enregistrement horaire
      UPDATE CD_INFO_DYNAMIQUE_AGT
         SET (
                CPU_USER_TIME
               ,CPU_SYS_TIME
               ,CPU_NICE_TIME
               ,CPU_WAIT_TIME
               ,CPU_TOTAL_TIME
               ,CPU_IDLE_TIME
               ,MEM_TOTAL
               ,MEM_ACTUAL_USED
               ,MEM_ACTUAL_FREE
               ,MEM_USED
               ,MEM_FREE
               ,SWP_TOTAL
               ,SWP_USED
               ,SWP_FREE
               ,SWP_PAGE_IN
               ,SWP_PAGE_OUT
               ,SWP_DELTA_PAGE_IN
               ,SWP_DELTA_PAGE_OUT
               ,SYS_LOAD_AVG
               ,MAX_CPU_USER_TIME
               ,MAX_CPU_SYS_TIME
               ,MAX_CPU_NICE_TIME
               ,MAX_CPU_WAIT_TIME
               ,MAX_CPU_TOTAL_TIME
               ,MAX_MEM_ACTUAL_USED
               ,MAX_MEM_USED
               ,MAX_SWP_USED
               ,MAX_SWP_DELTA_PAGE_IN
               ,MAX_SWP_DELTA_PAGE_OUT
               ,MAX_SYS_LOAD_AVG
             ) = (SELECT AVG(CPU_USER_TIME)
                        ,AVG(CPU_SYS_TIME)
                        ,AVG(CPU_NICE_TIME)
                        ,AVG(CPU_WAIT_TIME)
                        ,AVG(CPU_TOTAL_TIME)
                        ,AVG(CPU_IDLE_TIME)
                        ,AVG(DECODE(MEM_TOTAL          ,-1,TO_NUMBER(NULL),MEM_TOTAL))
                        ,AVG(DECODE(MEM_ACTUAL_USED    ,-1,TO_NUMBER(NULL),MEM_ACTUAL_USED))
                        ,AVG(DECODE(MEM_ACTUAL_FREE    ,-1,TO_NUMBER(NULL),MEM_ACTUAL_FREE))
                        ,AVG(DECODE(MEM_USED           ,-1,TO_NUMBER(NULL),MEM_USED))
                        ,AVG(DECODE(MEM_FREE           ,-1,TO_NUMBER(NULL),MEM_FREE))
                        ,AVG(DECODE(SWP_TOTAL          ,-1,TO_NUMBER(NULL),SWP_TOTAL))
                        ,AVG(DECODE(SWP_USED           ,-1,TO_NUMBER(NULL),SWP_USED))
                        ,AVG(DECODE(SWP_FREE           ,-1,TO_NUMBER(NULL),SWP_FREE))
                        ,AVG(DECODE(SWP_PAGE_IN        ,-1,TO_NUMBER(NULL),SWP_PAGE_IN))
                        ,AVG(DECODE(SWP_PAGE_OUT       ,-1,TO_NUMBER(NULL),SWP_PAGE_OUT))
                        ,AVG(DECODE(SWP_DELTA_PAGE_IN  ,-1,TO_NUMBER(NULL),SWP_DELTA_PAGE_IN))
                        ,AVG(DECODE(SWP_DELTA_PAGE_OUT ,-1,TO_NUMBER(NULL),SWP_DELTA_PAGE_OUT))
                        ,AVG(DECODE(SYS_LOAD_AVG       ,-1,TO_NUMBER(NULL),SYS_LOAD_AVG))
                        ,MAX(CPU_USER_TIME)
                        ,MAX(CPU_SYS_TIME)
                        ,MAX(CPU_NICE_TIME)
                        ,MAX(CPU_WAIT_TIME)
                        ,MAX(CPU_TOTAL_TIME)
                        ,MAX(DECODE(MEM_ACTUAL_USED    ,-1,TO_NUMBER(NULL),MEM_ACTUAL_USED))
                        ,MAX(DECODE(MEM_USED           ,-1,TO_NUMBER(NULL),MEM_USED))
                        ,MAX(DECODE(SWP_USED           ,-1,TO_NUMBER(NULL),SWP_USED))
                        ,MAX(DECODE(SWP_DELTA_PAGE_IN  ,-1,TO_NUMBER(NULL),SWP_DELTA_PAGE_IN))
                        ,MAX(DECODE(SWP_DELTA_PAGE_OUT ,-1,TO_NUMBER(NULL),SWP_DELTA_PAGE_OUT))
                        ,MAX(DECODE(SYS_LOAD_AVG       ,-1,TO_NUMBER(NULL),SYS_LOAD_AVG))
                    FROM CD_INFO_DYNAMIQUE_AGT
                   WHERE DH_COLLECTE_DONNEE BETWEEN TRUNC(A_DH_COLLECTE_DONNEE,'HH24') 
                                                AND TRUNC(A_DH_COLLECTE_DONNEE,'HH24') + 3599/3600
                     AND NOM_SERVEUR        = UPPER(A_NOM_SERVEUR)
                     AND TYPE_INFO          = 'BR'
                 )
       WHERE DH_COLLECTE_DONNEE = TRUNC(A_DH_COLLECTE_DONNEE,'HH24')
         AND NOM_SERVEUR        = UPPER(A_NOM_SERVEUR)
         AND TYPE_INFO          = 'HO';

      -- Vérification si l'enregistrement horaire existe
      IF (SQL%ROWCOUNT = 0) THEN
      
         INSERT INTO CD_INFO_DYNAMIQUE_AGT
         (
            DH_COLLECTE_DONNEE
           ,NOM_SERVEUR
           ,TYPE_INFO
           ,CPU_USER_TIME
           ,CPU_SYS_TIME
           ,CPU_NICE_TIME
           ,CPU_WAIT_TIME
           ,CPU_TOTAL_TIME
           ,CPU_IDLE_TIME
           ,MEM_TOTAL
           ,MEM_ACTUAL_USED
           ,MEM_ACTUAL_FREE
           ,MEM_USED
           ,MEM_FREE
           ,SWP_TOTAL
           ,SWP_USED
           ,SWP_FREE
           ,SWP_PAGE_IN
           ,SWP_PAGE_OUT
           ,SWP_DELTA_PAGE_IN
           ,SWP_DELTA_PAGE_OUT
           ,SYS_LOAD_AVG
           ,MAX_CPU_USER_TIME
           ,MAX_CPU_SYS_TIME
           ,MAX_CPU_NICE_TIME
           ,MAX_CPU_WAIT_TIME
           ,MAX_CPU_TOTAL_TIME
           ,MAX_MEM_ACTUAL_USED
           ,MAX_MEM_USED
           ,MAX_SWP_USED
           ,MAX_SWP_DELTA_PAGE_IN
           ,MAX_SWP_DELTA_PAGE_OUT
           ,MAX_SYS_LOAD_AVG
         )
         VALUES
         (
            TRUNC(A_DH_COLLECTE_DONNEE,'HH24')
           ,UPPER(A_NOM_SERVEUR)
           ,'HO'
           ,V_CPU_USER_TIME
           ,V_CPU_SYS_TIME
           ,V_CPU_NICE_TIME
           ,V_CPU_WAIT_TIME
           ,V_CPU_TOTAL_TIME
           ,V_CPU_IDLE_TIME
           ,DECODE(A_MEM_TOTAL          ,-1,TO_NUMBER(NULL),A_MEM_TOTAL)
           ,DECODE(A_MEM_ACTUAL_USED    ,-1,TO_NUMBER(NULL),A_MEM_ACTUAL_USED)
           ,DECODE(A_MEM_ACTUAL_FREE    ,-1,TO_NUMBER(NULL),A_MEM_ACTUAL_FREE)
           ,DECODE(A_MEM_USED           ,-1,TO_NUMBER(NULL),A_MEM_USED)
           ,DECODE(A_MEM_FREE           ,-1,TO_NUMBER(NULL),A_MEM_FREE)
           ,DECODE(A_SWP_TOTAL          ,-1,TO_NUMBER(NULL),A_SWP_TOTAL)
           ,DECODE(A_SWP_USED           ,-1,TO_NUMBER(NULL),A_SWP_USED)
           ,DECODE(A_SWP_FREE           ,-1,TO_NUMBER(NULL),A_SWP_FREE)
           ,DECODE(A_SWP_PAGE_IN        ,-1,TO_NUMBER(NULL),A_SWP_PAGE_IN)
           ,DECODE(A_SWP_PAGE_OUT       ,-1,TO_NUMBER(NULL),A_SWP_PAGE_OUT)
           ,DECODE(A_SWP_DELTA_PAGE_IN  ,-1,TO_NUMBER(NULL),A_SWP_DELTA_PAGE_IN)
           ,DECODE(A_SWP_DELTA_PAGE_OUT ,-1,TO_NUMBER(NULL),A_SWP_DELTA_PAGE_OUT)
           ,DECODE(A_SYS_LOAD_AVG       ,-1,TO_NUMBER(NULL),A_SYS_LOAD_AVG)
           ,V_CPU_USER_TIME
           ,V_CPU_SYS_TIME
           ,V_CPU_NICE_TIME
           ,V_CPU_WAIT_TIME
           ,V_CPU_TOTAL_TIME
           ,DECODE(A_MEM_ACTUAL_USED    ,-1,TO_NUMBER(NULL),A_MEM_ACTUAL_USED)
           ,DECODE(A_MEM_USED           ,-1,TO_NUMBER(NULL),A_MEM_USED)
           ,DECODE(A_SWP_USED           ,-1,TO_NUMBER(NULL),A_SWP_USED)
           ,DECODE(A_SWP_DELTA_PAGE_IN  ,-1,TO_NUMBER(NULL),A_SWP_DELTA_PAGE_IN)
           ,DECODE(A_SWP_DELTA_PAGE_OUT ,-1,TO_NUMBER(NULL),A_SWP_DELTA_PAGE_OUT)
           ,DECODE(A_SYS_LOAD_AVG       ,-1,TO_NUMBER(NULL),A_SYS_LOAD_AVG)
         );

      END IF;


   END ENREGISTRER_INFO_DYNAMIQUE;


END SDBM_AGENT;
/
