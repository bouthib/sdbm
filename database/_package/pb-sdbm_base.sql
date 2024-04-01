-- *
-- * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
-- * Licensed under the MIT license.
-- * See LICENSE file in the project root for full license information.
-- *


CREATE OR REPLACE PACKAGE BODY SDBM_BASE
IS
/*********************************************************************
*
* Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
* Licensed under the MIT license.
*
**********************************************************************/
/*********************************************************************
  PACKAGE : SDBM_BASE
  AUTEUR  : Benoit Bouthillier 2009-10-02 (2021-03-17)
 ---------------------------------------------------------------------
  BUT : Ce package permet l'implantation des procédures requise pour
        le moniteur Oracle (serveur).

**********************************************************************/


   /******************************************************************
     CONSTANTE :
    *****************************************************************/

    -- Version de PL/SQL
    VERSION_PB CONSTANT VARCHAR2(4 CHAR) := '0.14';



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
     PROCEDURE : AJUSTEMENT_FUSEAU_HOR - privé
     AUTEUR    : Benoit Bouthillier 2008-07-23 (2021-03-17)
    ------------------------------------------------------------------
     BUT : Cette procédure à pour but de faire l'ajustement de l'heure
           d'exécution des évévements (suite aux changement d'heure,
           si on recule l'heure).

   ******************************************************************/

   PROCEDURE AJUSTEMENT_FUSEAU_HOR
   IS

      -- Transaction locale
      PRAGMA AUTONOMOUS_TRANSACTION;

      V_OLD_FUSEAU_HOR_DERN_EXEC PARAMETRE.FUSEAU_HOR_DERN_EXEC%TYPE;
      V_NEW_FUSEAU_HOR_DERN_EXEC PARAMETRE.FUSEAU_HOR_DERN_EXEC%TYPE := EXTRACT(TIMEZONE_HOUR FROM SYSTIMESTAMP);
      
      V_DELAI_AJUSTEMENT_DST_SEC PARAMETRE.DELAI_AJUSTEMENT_DST_SEC%TYPE;
      V_NB_SEC_DELAI_ATTENTE     NUMBER(4);

   BEGIN

      -- Recherche du dernier TIMEZONE (dernière exécution)
      BEGIN

         SELECT FUSEAU_HOR_DERN_EXEC
           INTO V_OLD_FUSEAU_HOR_DERN_EXEC
           FROM PARAMETRE
          WHERE ((FUSEAU_HOR_DERN_EXEC IS NULL) OR (FUSEAU_HOR_DERN_EXEC <> V_NEW_FUSEAU_HOR_DERN_EXEC));

         -- Sauvegarde du TIMEZONE
         UPDATE PARAMETRE
            SET FUSEAU_HOR_DERN_EXEC = V_NEW_FUSEAU_HOR_DERN_EXEC;

         IF (V_OLD_FUSEAU_HOR_DERN_EXEC IS NULL) THEN

            -- Ajustement à zéro - fin
            COMMIT;

         ELSE

            -- Modification au fuseau horaire - DST (heure avancée -> heure normale)
            IF (V_OLD_FUSEAU_HOR_DERN_EXEC - V_NEW_FUSEAU_HOR_DERN_EXEC > 0) THEN
            
               UPDATE CIBLE
                  SET DH_PROCHAINE_VERIF = DH_PROCHAINE_VERIF - ((V_OLD_FUSEAU_HOR_DERN_EXEC - V_NEW_FUSEAU_HOR_DERN_EXEC) / 24)
                WHERE DH_PROCHAINE_VERIF IS NOT NULL;

               UPDATE EVENEMENT_CIBLE
                  SET DH_PROCHAINE_VERIF = DH_PROCHAINE_VERIF - ((V_OLD_FUSEAU_HOR_DERN_EXEC - V_NEW_FUSEAU_HOR_DERN_EXEC) / 24)
                WHERE DH_PROCHAINE_VERIF BETWEEN TRUNC(SYSDATE + ((V_OLD_FUSEAU_HOR_DERN_EXEC - V_NEW_FUSEAU_HOR_DERN_EXEC) / 24),'HH24')
                                             AND TRUNC(SYSDATE + ((V_OLD_FUSEAU_HOR_DERN_EXEC - V_NEW_FUSEAU_HOR_DERN_EXEC) / 24),'HH24') + 3599/3600; 

               UPDATE EVENEMENT_CIBLE
                  SET DH_LOC_DERN_VERIF  = TRUNC(DH_LOC_DERN_VERIF  - ((V_OLD_FUSEAU_HOR_DERN_EXEC - V_NEW_FUSEAU_HOR_DERN_EXEC) / 24),'HH24') + 1/24
                WHERE DH_LOC_DERN_VERIF  > SYSDATE;

               JOURNALISER('SDBM_BASE.AJUSTEMENT_FUSEAU_HOR','INFO','The execution time of all events was adjusted by SDBMSrv. DST update has been detected.');

            -- Modification au fuseau horaire - DST (heure normales -> heure avancée)
            ELSE

               -- Recherche du délai d'attente (permettre aux diverses processus de s'exécuté une fois l'heure avancée en fonction)
               SELECT DELAI_AJUSTEMENT_DST_SEC
                 INTO V_DELAI_AJUSTEMENT_DST_SEC
                 FROM PARAMETRE;
                 
               -- Calcul du délai d'attente (délai de changement d'heure
               V_NB_SEC_DELAI_ATTENTE := (TRUNC(SYSDATE,'HH24') + (V_DELAI_AJUSTEMENT_DST_SEC / 86400) - SYSDATE) * 86400;

	       IF (V_NB_SEC_DELAI_ATTENTE > 0) THEN
                  JOURNALISER('SDBM_BASE.AJUSTEMENT_FUSEAU_HOR','INFO','SDBMSrv is now waiting (will resume at ' || TO_CHAR(TRUNC(SYSDATE,'HH24') + (V_DELAI_AJUSTEMENT_DST_SEC / 86400),'HH24:MI:SS') || '). DST update has been detected.');
                  DBMS_SESSION.SLEEP((TRUNC(SYSDATE,'HH24') + (V_DELAI_AJUSTEMENT_DST_SEC / 86400) - SYSDATE) * 86400);
                  JOURNALISER('SDBM_BASE.AJUSTEMENT_FUSEAU_HOR','INFO','SDBMSrv is now resuming.');
               END IF;

            END IF;
            
            COMMIT;

         END IF;

      EXCEPTION

         WHEN NO_DATA_FOUND THEN

            -- Ajustement à zéro - fin
            ROLLBACK;

      END;

   END AJUSTEMENT_FUSEAU_HOR;


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
     PROCEDURE : TRAITEMENT_CIBLES_BD
     AUTEUR    : Benoit Bouthillier 2008-07-23 (2011-10-31)
    ------------------------------------------------------------------
     BUT : Obtenir la liste des cibles enregistrées et actives.

     PARAMETRES:  Curseur  (A_CUR_INFO)
   ******************************************************************/

   PROCEDURE TRAITEMENT_CIBLES_BD
   (
      A_VERSION_SERVEUR         IN  VARCHAR2 DEFAULT 'N/D'
     ,A_CUR_INFO                OUT T_RC_INFO
     ,A_DELAI_MAX_CONNEXION_SEC OUT PARAMETRE.DELAI_MAX_CONNEXION_SEC%TYPE
     ,A_FREQU_VERIF_CIBLE_SEC   OUT PARAMETRE.FREQU_VERIF_CIBLE_SEC%TYPE
     ,A_NIVEAU_JOURNAL_SERVEUR  OUT PARAMETRE.NIVEAU_JOURNAL_SERVEUR%TYPE
   )
   IS

      -- Curseur dynamique de retour d'information
      VC_INFO T_RC_INFO;

      V_MACHINE V$SESSION.MACHINE%TYPE;
      
   BEGIN
  
      SELECT MACHINE
        INTO V_MACHINE
        FROM V$SESSION WHERE SID = (SELECT DISTINCT SID FROM V$MYSTAT);


      DBMS_APPLICATION_INFO.SET_MODULE(MODULE_NAME => 'SDBMSRV - SCHEMA : ' || SDBM_APEX_UTIL.INFOSCHEMA
                                      ,ACTION_NAME => TO_CHAR(SYSDATE,'YYYY/MM/DD:HH24:MI:SS')
                                      );
      DBMS_APPLICATION_INFO.SET_CLIENT_INFO('SDBMSRV version ' || A_VERSION_SERVEUR || ' running on ' || NVL(V_MACHINE,'N/A'));


      -- Envoi des notifications en différées
      SDBM_UTIL.NOTIFIER_DIF;

      -- Ajustement relatif aux changements d'heure
      AJUSTEMENT_FUSEAU_HOR;

      -- Ouverture du curseur de recherche
      OPEN VC_INFO FOR SELECT NOM_CIBLE                                           "NOM_CIBLE"
                             ,SOUS_TYPE_CIBLE                                     "SOUS_TYPE_CIBLE"
                             ,NOM_USAGER                                          "NOM_USAGER"
                             ,SDBM_UTIL.DECRYPTER_MDP_CIBLE(NOM_CIBLE,MDP_USAGER) "MOT_PASSE"
                             ,TYPE_CONNEXION                                      "TYPE_CONNEXION"
                             ,CONNEXION                                           "CONNEXION"
                         FROM CIBLE
                        WHERE TYPE_CIBLE                                 = 'BD'
                          AND NOTIFICATION                               = 'AC'
                          AND SDBM_UTIL.EVALUER_SQL_HORAIRE(SQL_HORAIRE) = 1
                          AND EXISTS (SELECT 1
                                        FROM PARAMETRE
                                       WHERE STATUT_SERVEUR = 'AC'
                                     )
                          AND (DH_PROCHAINE_VERIF IS NULL OR STATUT != 'UP' OR DH_PROCHAINE_VERIF <= SYSDATE)
                        ORDER BY SOUS_TYPE_CIBLE
                                ,NOM_CIBLE;
 
      -- Assignation de retour
      A_CUR_INFO := VC_INFO;
      
      -- Envoi du pilotage au serveur
      SELECT FREQU_VERIF_CIBLE_SEC
            ,DELAI_MAX_CONNEXION_SEC
            ,NIVEAU_JOURNAL_SERVEUR
        INTO A_FREQU_VERIF_CIBLE_SEC
            ,A_DELAI_MAX_CONNEXION_SEC
            ,A_NIVEAU_JOURNAL_SERVEUR
        FROM PARAMETRE;
   
   END TRAITEMENT_CIBLES_BD;


   /******************************************************************
     PROCEDURE : SAUVEGARDE_STATUT_CIBLE
     AUTEUR    : Benoit Bouthillier 2008-07-23 (2018-03-13)
    ------------------------------------------------------------------
     BUT : Cette procédure à pour but la sauvegarde du statut de
           disponibilité d'une cible.

     PARAMETRES:  Type de cible                 (A_TYPE_CIBLE) 
                  Nom de la cible               (A_NOM_CIBLE)
                  Statut de la cible            (A_STATUT)
                  STARTUP_TIME (V$INSTANCE)     (A_STARTUP_TIME)
                  HOST_NAME (V$INSTANCE)        (A_NOM_SERVEUR)
                  INSTANCE_NAME (V$INSTANCE)    (A_NOM_INSTANCE)
                  VERSION (V$INSTANCE)          (A_VERSION)
                  FICHIER_ALERTE (V$PARAMETER)  (A_FICHIER_ALERTE)
   ******************************************************************/

   PROCEDURE SAUVEGARDE_STATUT_CIBLE
   (
      A_TYPE_CIBLE     IN CIBLE.TYPE_CIBLE%TYPE                  -- Type de cible
     ,A_NOM_CIBLE      IN CIBLE.NOM_CIBLE%TYPE                   -- Nom de la cible
     ,A_STATUT         IN CIBLE.STATUT%TYPE                      -- Statut de la cible
     ,A_STARTUP_TIME   IN CIBLE.STARTUP_TIME%TYPE   DEFAULT NULL -- STARTUP_TIME (V$INSTANCE)
     ,A_NOM_SERVEUR    IN CIBLE.NOM_SERVEUR%TYPE    DEFAULT NULL -- HOST_NAME (V$INSTANCE)
     ,A_NOM_INSTANCE   IN CIBLE.NOM_INSTANCE%TYPE   DEFAULT NULL -- INSTANCE_NAME (V$INSTANCE)
     ,A_VERSION        IN CIBLE.VERSION%TYPE        DEFAULT NULL -- VERSION (V$INSTANCE)
     ,A_FICHIER_ALERTE IN CIBLE.FICHIER_ALERTE%TYPE DEFAULT NULL -- FICHIER_ALERTE (V$PARAMETER)
   )
   IS

      -- Variables locales
      V_INDICATEUR     NUMBER(1);

      V_DESTI_NOTIF    CIBLE.DESTI_NOTIF%TYPE;
      V_DH_MAJ_STATUT  CIBLE.DH_MAJ_STATUT%TYPE;
      V_STARTUP_TIME   CIBLE.STARTUP_TIME%TYPE;
      V_STATUT         CIBLE.STATUT%TYPE;
      V_SQL_HORAIRE    CIBLE.SQL_HORAIRE%TYPE;

      V_ERREUR_RESEAU  HIST_CIBLE.ERREUR_RESEAU%TYPE;
   
   BEGIN

      -- Vérification d'un changement de statut
      BEGIN

         SELECT 1
           INTO V_INDICATEUR
           FROM CIBLE
          WHERE NOM_CIBLE   = A_NOM_CIBLE
            AND TYPE_CIBLE  = A_TYPE_CIBLE
            AND STATUT     != A_STATUT;

         --
         -- Changement de statut requis
         --
         
         -- Initialisation (par défaut, ce n'est pas une erreur réseau)
         V_ERREUR_RESEAU := 'FA';

         -- Vérification pour erreur réseau
         IF (A_STATUT = 'UP') THEN

            -- Recherche du dernier démarrage
            SELECT STARTUP_TIME
                  ,DH_MAJ_STATUT
              INTO V_STARTUP_TIME
                  ,V_DH_MAJ_STATUT
              FROM CIBLE
             WHERE NOM_CIBLE  = A_NOM_CIBLE
               AND TYPE_CIBLE = A_TYPE_CIBLE;

            IF (V_STARTUP_TIME = A_STARTUP_TIME) THEN

               -- Erreur réseau : Mise à jour de HIST_CIBLE (pour le UP)
               V_ERREUR_RESEAU := 'VR';

               -- Erreur réseau : Mise à jour de HIST_CIBLE (pour le DN)
               UPDATE HIST_CIBLE
                  SET ERREUR_RESEAU = V_ERREUR_RESEAU
                WHERE NOM_CIBLE     = A_NOM_CIBLE
                  AND TYPE_CIBLE    = A_TYPE_CIBLE
                  AND STATUT        = 'DN'
                  AND DH_HIST_CIBLE = V_DH_MAJ_STATUT;

            END IF;

         END IF;

         -- Mise à jour du statut
         UPDATE CIBLE
            SET STARTUP_TIME  = NVL(A_STARTUP_TIME,STARTUP_TIME)
               ,DH_MAJ_STATUT = SYSDATE
               ,STATUT        = A_STATUT
               ,NOTIF_EFFECT  = 'AE'
          WHERE NOM_CIBLE  = A_NOM_CIBLE
            AND TYPE_CIBLE = A_TYPE_CIBLE;

         -- Insertion dans l'historique
         INSERT INTO HIST_CIBLE
         (
            TYPE_CIBLE
           ,NOM_CIBLE
           ,STATUT
           ,ERREUR_RESEAU
         )
         VALUES
         (
            A_TYPE_CIBLE
           ,A_NOM_CIBLE
           ,A_STATUT
           ,V_ERREUR_RESEAU
         );

      EXCEPTION

         WHEN NO_DATA_FOUND THEN

            -- Le statut n'a pas changé
            NULL;

      END;


      -- Vérification d'un redémarrage sans changement de statut
      BEGIN

         -- Vérification (incluant la recherche SQL_HORAIRE)
         SELECT SQL_HORAIRE
           INTO V_SQL_HORAIRE
           FROM CIBLE
          WHERE NOM_CIBLE   = A_NOM_CIBLE
            AND TYPE_CIBLE  = A_TYPE_CIBLE
            AND NOM_SERVEUR = A_NOM_SERVEUR  /* Ne pas tenir compte d'un changement de STARTUP_TIME dans le cas d'un cluster (ex. RAC ou ALWAYS-ON) */
            AND (
                   /* Situation régulière */
                   (
                          SOUS_TYPE_CIBLE != 'MY'
                      AND STARTUP_TIME    != A_STARTUP_TIME
                   )
                   OR 
                   /* Tolérence de 5 secondes - voir SDBMSrv : Correctif pour MySQL 5.0.x (GLOBAL_STATUS et GLOBAL_VARIABLES ne sont pas dans INFORMATION_SCHEMA) */
                   (
                          SOUS_TYPE_CIBLE                               = 'MY'
                      AND ABS((STARTUP_TIME - A_STARTUP_TIME) * 86400)  > 5
                      /* Vérification pour calcul du DST */
                      AND DH_DERN_VERIF                                <= A_STARTUP_TIME
                   )
                );
            
         -- Vérification du SQL_HORAIRE
         IF (SDBM_UTIL.EVALUER_SQL_HORAIRE(REPLACE(V_SQL_HORAIRE,'SYSDATE','TO_DATE(''' || TO_CHAR(A_STARTUP_TIME,'YYYY/MM/DD:HH24:MI:SS') ||''',''YYYY/MM/DD:HH24:MI:SS'')')) = 1) THEN
            
            -- Redémarrage sans changement de statut avec notification
            UPDATE CIBLE
               SET NOTIF_EFFECT = 'AE'
             WHERE NOM_CIBLE  = A_NOM_CIBLE
               AND TYPE_CIBLE = A_TYPE_CIBLE;

         END IF;

         -- Insertion dans l'historique
         BEGIN

            INSERT INTO HIST_CIBLE
            (
               DH_HIST_CIBLE
              ,TYPE_CIBLE
              ,NOM_CIBLE
              ,STATUT
            )
            VALUES
            (
               A_STARTUP_TIME
              ,A_TYPE_CIBLE
              ,A_NOM_CIBLE
              ,'RD'
            );

         EXCEPTION

            /* Garantir qu'une mise à jour de l'historique en double ne peut perturber le fonctionnement - ref. dern. problème DST MySQL */ 
            WHEN DUP_VAL_ON_INDEX THEN

               -- Journalisation de l'erreur ORA-00001: unique constraint (SDBM.CDEAL_PK_CD_ESP_ARCHIVED_LOG) violated
               JOURNALISER('SDBM_BASE.SAUVEGARDE_STATUT_CIBLE','WARNING','An error (' || SUBSTR(SQLERRM,1,100) || ') occured while inserting into HIST_CIBLE (values were : ' || TO_CHAR(A_STARTUP_TIME,'YYYY/MM/DD:HH24:MI:SS') || ', ' || A_TYPE_CIBLE || ', ' || A_NOM_CIBLE || ', RD).');

         END;

      EXCEPTION

         WHEN NO_DATA_FOUND THEN

            -- Pas de redémarrage
            NULL;

      END;


      -- Sauvegarde des données informatives
      UPDATE CIBLE
         SET STARTUP_TIME       = NVL(A_STARTUP_TIME,STARTUP_TIME)
            ,DH_DERN_VERIF      = SYSDATE
            ,DH_PROCHAINE_VERIF = SDBM_UTIL.INTERVAL_TO_DATE(INTERVAL)
            ,NOM_SERVEUR        = NVL(A_NOM_SERVEUR,NOM_SERVEUR)
            ,NOM_INSTANCE       = NVL(A_NOM_INSTANCE,NOM_INSTANCE)
            ,VERSION            = NVL(A_VERSION,VERSION)
            ,FICHIER_ALERTE     = NVL(A_FICHIER_ALERTE,FICHIER_ALERTE)
       WHERE NOM_CIBLE          = A_NOM_CIBLE
         AND TYPE_CIBLE         = A_TYPE_CIBLE;


      -- Notification (si requise)
      BEGIN

         SELECT STATUT
               ,DESTI_NOTIF
           INTO V_STATUT
               ,V_DESTI_NOTIF
           FROM CIBLE
          WHERE NOM_CIBLE    =  A_NOM_CIBLE
            AND TYPE_CIBLE   =  A_TYPE_CIBLE
            AND NOTIF_EFFECT = 'AE';

         -- Notification
         IF SDBM_UTIL.NOTIFIER_CIBLE(A_TYPE_CIBLE,A_NOM_CIBLE,V_STATUT,V_DESTI_NOTIF) THEN

            -- Mise à jour du statut de notification
            UPDATE CIBLE
               SET NOTIF_EFFECT  = 'OK'
             WHERE NOM_CIBLE  = A_NOM_CIBLE
               AND TYPE_CIBLE = A_TYPE_CIBLE;

         END IF;

      EXCEPTION

         -- Aucune notification requise
         WHEN NO_DATA_FOUND THEN
            NULL;
      
      END;

   END SAUVEGARDE_STATUT_CIBLE;


   /******************************************************************
     PROCEDURE : TRAITEMENT_EVENEMENTS_BD
     AUTEUR    : Benoit Bouthillier 2008-07-23 (2011-11-22)
    ------------------------------------------------------------------
     BUT : Obtenir la liste des evenements enregistrés et actifs
           contre une cible de type BD.

     PARAMETRES:  Nom de la cible  (A_NOM_CIBLE)
                  Curseur          (A_CUR_INFO)
   ******************************************************************/

   PROCEDURE TRAITEMENT_EVENEMENTS_BD
   (
      A_NOM_CIBLE IN  EVENEMENT_CIBLE.NOM_CIBLE%TYPE -- Nom de la cible
     ,A_CUR_INFO  OUT T_RC_INFO                      -- Curseur
   )
   IS

      -- Curseur dynamique de retour d'information
      VC_INFO         T_RC_INFO;

      -- Sauvegarde de l'heure d'exécution consistante (étapes successives)
      V_SYSDATE       DATE      := SYSDATE;
      V_TIMESTAMP_UTC TIMESTAMP := SYSTIMESTAMP AT TIME ZONE 'UTC';

   BEGIN
  
      -- Ouverture du curseur de recherche
      OPEN VC_INFO FOR SELECT EVC.NOM_EVENEMENT
                             ,REPLACE(REPLACE(REPLACE(REPLACE(EVE.COMMANDE
                                                             ,'{LAST_SYSDATE}'
                                                             ,'TO_DATE(''' || TO_CHAR(DH_LOC_DERN_VERIF,'YYYYMMDDHH24MISS') || ''',''YYYYMMDDHH24MISS'')'
                                                             )
                                                     ,'{LAST_TIMESTAMP_UTC}'
                                                     ,'TO_TIMESTAMP_TZ(''' || TO_CHAR(TS_UTC_DERN_VERIF,'YYYYMMDDHH24MISSFF') || ' 0:0'',''YYYYMMDDHH24MISSFF TZH:TZM'')'
                                                     )
                                             ,'{CURR_SYSDATE}'
                                             ,'TO_DATE(''' || TO_CHAR(V_SYSDATE,'YYYYMMDDHH24MISS') || ''',''YYYYMMDDHH24MISS'')'
                                             )
                                     ,'{CURR_TIMESTAMP_UTC}'
                                     ,'TO_TIMESTAMP_TZ(''' || TO_CHAR(V_TIMESTAMP_UTC,'YYYYMMDDHH24MISSFF') || ' 0:0'',''YYYYMMDDHH24MISSFF TZH:TZM'')'
                                     )        
                              "COMMANDE"
                             ,EVE.DELAI_MAX_EXEC_SEC
                         FROM EVENEMENT_CIBLE EVC
                             ,EVENEMENT       EVE
                        WHERE EVE.TYPE_CIBLE          = EVC.TYPE_CIBLE
                          AND EVE.SOUS_TYPE_CIBLE     = EVC.SOUS_TYPE_CIBLE
                          AND EVE.NOM_EVENEMENT       = EVC.NOM_EVENEMENT
                          AND EVE.TYPE_EVENEMENT      = 'MN'
                          AND EVC.TYPE_CIBLE          = 'BD'
                          AND EVC.NOM_CIBLE           = A_NOM_CIBLE
                          AND EVC.VERIFICATION        = 'AC'
                          AND (
                                 -- Si l'événement est actuellement à traiter
                                 EVC.DH_PROCHAINE_VERIF <= V_SYSDATE

                                 -- Si l'événement est actuellement OUVERT
                                 OR EXISTS (SELECT 1
                                              FROM HIST_EVENEMENT_CIBLE HEC
                                             WHERE HEC.TYPE_CIBLE    = EVC.TYPE_CIBLE
                                               AND HEC.NOM_CIBLE     = EVC.NOM_CIBLE
                                               AND HEC.NOM_EVENEMENT = EVC.NOM_EVENEMENT
                                               AND HEC.DH_FERMETURE  IS NULL
                                           )
                              )
                          ORDER BY EVC.DH_PROCHAINE_VERIF;


 
      -- Assignation de retour
      A_CUR_INFO := VC_INFO;
   

      -- Mise à jour de l'interval de traitement
      UPDATE EVENEMENT_CIBLE EVC
         SET EVC.DH_PROCHAINE_VERIF = SDBM_UTIL.INTERVAL_TO_DATE(NVL(EVC.INTERVAL,(SELECT INTERVAL_DEFAUT
                                                                                     FROM EVENEMENT
                                                                                    WHERE TYPE_CIBLE      = 'BD'
                                                                                      AND SOUS_TYPE_CIBLE = EVC.SOUS_TYPE_CIBLE
                                                                                      AND NOM_EVENEMENT   = EVC.NOM_EVENEMENT
                                                                                  )
                                                                    )
                                                                )
            ,DH_LOC_DERN_VERIF      = V_SYSDATE
            ,TS_UTC_DERN_VERIF      = V_TIMESTAMP_UTC
       WHERE EVC.TYPE_CIBLE    = 'BD'
         AND EVC.NOM_CIBLE     = A_NOM_CIBLE
         AND EVC.NOM_EVENEMENT IN (
                                     SELECT EVC.NOM_EVENEMENT
                                       FROM EVENEMENT_CIBLE EVC
                                           ,EVENEMENT       EVE
                                      WHERE EVE.TYPE_CIBLE          = EVC.TYPE_CIBLE
                                        AND EVE.SOUS_TYPE_CIBLE     = EVC.SOUS_TYPE_CIBLE
                                        AND EVE.NOM_EVENEMENT       = EVC.NOM_EVENEMENT
                                        AND EVE.TYPE_EVENEMENT      = 'MN'
                                        AND EVC.TYPE_CIBLE          = 'BD'
                                        AND EVC.DH_PROCHAINE_VERIF <= V_SYSDATE
                                        AND EVC.NOM_CIBLE           = A_NOM_CIBLE
                                  )
         AND EVC.VERIFICATION  = 'AC';


   END TRAITEMENT_EVENEMENTS_BD;


   /******************************************************************
     PROCEDURE : SAUVEGARDE_STATUT_EVENEMENT_BD
     AUTEUR    : Benoit Bouthillier 2008-07-23 (2015-04-07)
    ------------------------------------------------------------------
     BUT : Enregistre les résultats obtenu contre une cible de type
           BD.

     PARAMETRES:  Nom de la cible     (A_NOM_CIBLE)
                  Nom de l'événement  (A_NOM_EVENEMENT)
                  Nom de l'objet      (A_NOM_OBJET)
                  Résultat obtenu     (A_RESULTAT)
   ******************************************************************/

   PROCEDURE SAUVEGARDE_STATUT_EVENEMENT_BD
   (
      A_NOM_CIBLE     IN HIST_EVENEMENT_CIBLE.NOM_CIBLE%TYPE                   -- Nom de la cible
     ,A_NOM_EVENEMENT IN HIST_EVENEMENT_CIBLE.NOM_EVENEMENT%TYPE               -- Nom de l'événement
     ,A_NOM_OBJET     IN HIST_EVENEMENT_CIBLE.NOM_OBJET%TYPE     DEFAULT '?'   -- Nom de l'objet
     ,A_RESULTAT      IN HIST_EVENEMENT_CIBLE.RESULTAT%TYPE      DEFAULT '?'   -- Résultat obtenu
   )
   IS

      V_TAMPON VARCHAR2(4000 BYTE);

   BEGIN
   
      -- Vérification si les condition sont normales (pour un EVENEMENT au complet, sans OBJET)
      IF (A_NOM_OBJET = '?' AND A_RESULTAT = '?') THEN
      
         UPDATE HIST_EVENEMENT_CIBLE
            SET DH_FERMETURE = SYSDATE
               ,STATUT       = 'AT'
          WHERE TYPE_CIBLE    = 'BD'
            AND NOM_CIBLE     = A_NOM_CIBLE
            AND NOM_EVENEMENT = A_NOM_EVENEMENT
            AND DH_FERMETURE  IS NULL;

      ELSE
      
         -- Un problème existe... Vérification s'il est déjà enregistré...
         UPDATE HIST_EVENEMENT_CIBLE
            SET DH_DERN_OCCURRENCE = SYSDATE
          WHERE TYPE_CIBLE    = 'BD'
            AND NOM_CIBLE     = A_NOM_CIBLE
            AND NOM_EVENEMENT = A_NOM_EVENEMENT
            AND NOM_OBJET     = A_NOM_OBJET
            AND DH_FERMETURE  IS NULL;

         IF (SQL%ROWCOUNT = 0) THEN

            -- Création de l'événement (nouveau)
            V_TAMPON := SUBSTRB(A_RESULTAT,1,4000);
            INSERT INTO HIST_EVENEMENT_CIBLE
            (
               TYPE_CIBLE
              ,NOM_CIBLE
              ,NOM_EVENEMENT
              ,NOM_OBJET
              ,RESULTAT
              ,STATUT
            )
            VALUES
            (
               'BD'
              ,A_NOM_CIBLE
              ,A_NOM_EVENEMENT
              ,A_NOM_OBJET
              ,V_TAMPON
              ,'AT'
            );            

         END IF;

      END IF;

   END SAUVEGARDE_STATUT_EVENEMENT_BD;


   /******************************************************************
     PROCEDURE : TRAITER_STATUT_EVENEMENT_BD
     AUTEUR    : Benoit Bouthillier 2008-07-23 (2019-04-04)
    ------------------------------------------------------------------
     BUT : Effectue le traitement associé aux événements obtenus pour
           une cible BD.

     PARAMETRES:  Nom de la cible  (A_NOM_CIBLE)
   ******************************************************************/

   PROCEDURE TRAITER_STATUT_EVENEMENT_BD
   (
      A_NOM_CIBLE IN EVENEMENT_CIBLE.NOM_CIBLE%TYPE -- Nom de la cible
   )
   IS

      -- Curseurs
      CURSOR C_EVENEMENT_A_TRAITER IS
         SELECT HEC.*
               ,CIB.SOUS_TYPE_CIBLE
           FROM HIST_EVENEMENT_CIBLE HEC
               ,CIBLE                CIB
          WHERE HEC.NOM_CIBLE  = CIB.NOM_CIBLE
            AND HEC.TYPE_CIBLE = CIB.TYPE_CIBLE
            AND HEC.TYPE_CIBLE = 'BD'
            AND HEC.NOM_CIBLE  = A_NOM_CIBLE
            AND HEC.STATUT     = 'AT'
          FOR UPDATE OF HEC.STATUT;
      
      CURSOR C_EVENEMENT_A_NOTIFIER IS
         SELECT HEC.TYPE_CIBLE
               ,HEC.NOM_CIBLE
               ,HEC.NOM_EVENEMENT
               ,HEC.NOM_OBJET
               ,HEC.RESULTAT
               ,DECODE(HEC.DH_FERMETURE
                      ,TO_DATE(NULL),DECODE(EVE.TYPE_FERMETURE
                                           ,'RE','ER'
                                           ,'--'
                                           )
                                     
                      ,'OK'
                      )                                           C_STATUT
               ,NVL(EVC.DESTI_NOTIF,EVE.DESTI_NOTIF_DEFAUT)       C_DESTI_NOTIF
               ,EVE.TYPE_FERMETURE
               ,HEC.DH_FERMETURE
               ,PAR.GARANTIE_NOTIF_SERVEUR
           FROM HIST_EVENEMENT_CIBLE HEC
               ,EVENEMENT_CIBLE      EVC
               ,EVENEMENT            EVE
               ,PARAMETRE            PAR
          WHERE HEC.TYPE_CIBLE      = EVC.TYPE_CIBLE
            AND HEC.NOM_CIBLE       = EVC.NOM_CIBLE
            AND HEC.NOM_EVENEMENT   = EVC.NOM_EVENEMENT
            AND EVC.TYPE_CIBLE      = EVE.TYPE_CIBLE
            AND EVC.SOUS_TYPE_CIBLE = EVE.SOUS_TYPE_CIBLE
            AND EVC.NOM_EVENEMENT   = EVE.NOM_EVENEMENT
            AND HEC.TYPE_CIBLE      = 'BD'
            AND HEC.NOM_CIBLE       = A_NOM_CIBLE
            AND HEC.STATUT          = 'AE'
          FOR UPDATE OF HEC.STATUT, HEC.DH_FERMETURE;

      -- Variables locales
      V_LIMITE_NOTIF_CYCLE_SERVEUR NUMBER;
      V_IND_ENVOI                  NUMBER(1);

   BEGIN

      -- Vérification si les condition sont normales (pour un EVENEMENT au complet, sans OBJET)
      UPDATE HIST_EVENEMENT_CIBLE HEC
         SET DH_FERMETURE = SYSDATE
            ,STATUT       = 'AT'
       WHERE TYPE_CIBLE             = 'BD'
         AND NOM_CIBLE              = A_NOM_CIBLE
         AND DH_FERMETURE           IS NULL
         AND HEC.DH_DERN_OCCURRENCE < (SELECT MAX(DH_DERN_OCCURRENCE) - 1/1440  -- Délai max. du temps de sauvegarde
                                         FROM HIST_EVENEMENT_CIBLE
                                        WHERE TYPE_CIBLE    = HEC.TYPE_CIBLE
                                          AND NOM_CIBLE     = HEC.NOM_CIBLE
                                          AND NOM_EVENEMENT = HEC.NOM_EVENEMENT
                                      );

      -- Traitement de tous les événéments en statut AT (traitement)
      FOR RC_EVENEMENT_A_TRAITER IN C_EVENEMENT_A_TRAITER LOOP

         -- Mise à jour du statut de traitement
         UPDATE HIST_EVENEMENT_CIBLE
            SET STATUT = 'AE'
          WHERE CURRENT OF C_EVENEMENT_A_TRAITER;

         -- Vérification si une réparation est à exécuter
         IF (RC_EVENEMENT_A_TRAITER.DH_FERMETURE IS NULL) THEN

            UPDATE REPARATION_EVEN_CIBLE
               SET STATUT = 'AT'
             WHERE TYPE_CIBLE      = RC_EVENEMENT_A_TRAITER.TYPE_CIBLE
               AND SOUS_TYPE_CIBLE = RC_EVENEMENT_A_TRAITER.SOUS_TYPE_CIBLE
               AND NOM_CIBLE       = RC_EVENEMENT_A_TRAITER.NOM_CIBLE
               AND NOM_EVENEMENT   = RC_EVENEMENT_A_TRAITER.NOM_EVENEMENT;

         END IF;

      END LOOP;
      

      -- Obtenir la limite de notification permise dans un cycle (flow control...)
      SELECT DECODE(LIMITE_NOTIF_CYCLE_SERVEUR
                   ,0,9999 /* 0 : sans limite */
                   ,LIMITE_NOTIF_CYCLE_SERVEUR
                   )
        INTO V_LIMITE_NOTIF_CYCLE_SERVEUR
        FROM PARAMETRE;

      -- Traitement de tous les événéments en statut AE (notification)
      FOR RC_EVENEMENT_A_NOTIFIER IN C_EVENEMENT_A_NOTIFIER LOOP

         IF (V_LIMITE_NOTIF_CYCLE_SERVEUR > 0) THEN

            -- Vérification si la destination n'est pas vide
            SELECT COUNT(1)
              INTO V_IND_ENVOI
              FROM DESTI_NOTIF_DETAIL
             WHERE DESTI_NOTIF                                = RC_EVENEMENT_A_NOTIFIER.C_DESTI_NOTIF
               AND SDBM_UTIL.EVALUER_SQL_HORAIRE(SQL_HORAIRE) = 1
               AND ROWNUM                                    <= 1;

            IF (V_IND_ENVOI != 0) THEN
               V_LIMITE_NOTIF_CYCLE_SERVEUR := V_LIMITE_NOTIF_CYCLE_SERVEUR - 1;
            END IF;

            -- Notification
            IF SDBM_UTIL.NOTIFIER_EVENEMENT(RC_EVENEMENT_A_NOTIFIER.TYPE_CIBLE
                                           ,RC_EVENEMENT_A_NOTIFIER.NOM_CIBLE
                                           ,RC_EVENEMENT_A_NOTIFIER.NOM_EVENEMENT
                                           ,RC_EVENEMENT_A_NOTIFIER.NOM_OBJET
                                           ,RC_EVENEMENT_A_NOTIFIER.RESULTAT
                                           ,RC_EVENEMENT_A_NOTIFIER.C_STATUT
                                           ,RC_EVENEMENT_A_NOTIFIER.C_DESTI_NOTIF
                                                                                 ) THEN

               IF (RC_EVENEMENT_A_NOTIFIER.TYPE_FERMETURE = 'RE') THEN

                  -- Mise à jour du statut de notification (fermeture normale : résolution)
                  UPDATE HIST_EVENEMENT_CIBLE
                     SET STATUT  = 'OK'
                   WHERE CURRENT OF C_EVENEMENT_A_NOTIFIER;

               ELSE

                  -- Mise à jour de la fermeture et du statut de notification (fermeture automatique)
                  UPDATE HIST_EVENEMENT_CIBLE
                     SET DH_FERMETURE = SYSDATE
                        ,STATUT       = 'OK'
                   WHERE CURRENT OF C_EVENEMENT_A_NOTIFIER;

               END IF;

            END IF;

         ELSE

            -- Ajustement de la limite restante (calcul du nombre de messages restants)
            V_LIMITE_NOTIF_CYCLE_SERVEUR := V_LIMITE_NOTIF_CYCLE_SERVEUR - 1;

         END IF;
      
      END LOOP;


      -- Message d'avertissement sur la limite
      IF (V_LIMITE_NOTIF_CYCLE_SERVEUR < 0) THEN
         JOURNALISER('SDBM_BASE.TRAITER_STATUT_EVENEMENT_BD','WARNING',ABS(V_LIMITE_NOTIF_CYCLE_SERVEUR) || ' event(s) has not been sent yet - notification limit (server) has been reach for that cycle.');
      END IF;


   END TRAITER_STATUT_EVENEMENT_BD;


   /******************************************************************
     PROCEDURE : TRAITEMENT_REPARATIONS_BD
     AUTEUR    : Benoit Bouthillier 2008-07-23
    ------------------------------------------------------------------
     BUT : Obtenir la liste des réparation enregistrés et actifs
           contre une cible de type BD.

     PARAMETRES:  Nom de la cible  (A_NOM_CIBLE)
                  Curseur          (A_CUR_INFO)
   ******************************************************************/

   PROCEDURE TRAITEMENT_REPARATIONS_BD
   (
      A_NOM_CIBLE IN  REPARATION_EVEN_CIBLE.NOM_CIBLE%TYPE -- Nom de la cible
     ,A_CUR_INFO  OUT T_RC_INFO                            -- Curseur
   )
   IS

      -- Curseur dynamique de retour d'information
      VC_INFO T_RC_INFO;

   BEGIN
  
      -- Ouverture du curseur de recherche
      OPEN VC_INFO FOR SELECT REC.NOM_EVENEMENT
                             ,REC.NOM_REPARATION
                             ,REP.COMMANDE
                         FROM REPARATION_EVEN_CIBLE REC
                             ,REPARATION            REP
                        WHERE REC.TYPE_CIBLE      = REP.TYPE_CIBLE
                          AND REC.SOUS_TYPE_CIBLE = REP.SOUS_TYPE_CIBLE
                          AND REC.NOM_EVENEMENT   = REP.NOM_EVENEMENT
                          AND REC.NOM_REPARATION  = REP.NOM_REPARATION
                          AND REC.TYPE_CIBLE      = 'BD'
                          AND REC.NOM_CIBLE       = A_NOM_CIBLE
                          AND REC.STATUT          = 'AT';
 
      -- Assignation de retour
      A_CUR_INFO := VC_INFO;
   
   END TRAITEMENT_REPARATIONS_BD;


   /******************************************************************
     PROCEDURE : SAUVEGARDE_REPARATION_BD
     AUTEUR    : Benoit Bouthillier 2008-07-23
    ------------------------------------------------------------------
     BUT : Enregistre les résultats obtenu contre une cible de type
           BD.

     PARAMETRES:  Nom de la cible          (A_NOM_CIBLE)
                  Nom de l'événement       (A_NOM_EVENEMENT)
                  Nom de la réparation     (A_NOM_REPARATION)
                  Statut de la réparation  (A_STATUT)
   ******************************************************************/

   PROCEDURE SAUVEGARDE_REPARATION_BD
   (
      A_NOM_CIBLE      IN HIST_REPARATION_EVEN_CIBLE.NOM_CIBLE%TYPE      -- Nom de la cible
     ,A_NOM_EVENEMENT  IN HIST_REPARATION_EVEN_CIBLE.NOM_EVENEMENT%TYPE  -- Nom de l'événement
     ,A_NOM_REPARATION IN HIST_REPARATION_EVEN_CIBLE.NOM_REPARATION%TYPE -- Nom de la réparation
     ,A_STATUT         IN HIST_REPARATION_EVEN_CIBLE.STATUT%TYPE         -- Statut de la réparation
   )
   IS

   BEGIN
   
      INSERT INTO HIST_REPARATION_EVEN_CIBLE
      (
         TYPE_CIBLE
        ,NOM_CIBLE
        ,NOM_EVENEMENT
        ,NOM_REPARATION
        ,STATUT
      )
      VALUES
      (
         'BD'
        ,A_NOM_CIBLE
        ,A_NOM_EVENEMENT
        ,A_NOM_REPARATION
        ,A_STATUT
      );
      
      UPDATE REPARATION_EVEN_CIBLE
         SET STATUT = 'OK'
       WHERE TYPE_CIBLE     = 'BD'
         AND NOM_CIBLE      = A_NOM_CIBLE
         AND NOM_EVENEMENT  = A_NOM_EVENEMENT
         AND NOM_REPARATION = A_NOM_REPARATION;
      
   END SAUVEGARDE_REPARATION_BD;


END SDBM_BASE;
/
