-- *
-- * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
-- * Licensed under the MIT license.
-- * See LICENSE file in the project root for full license information.
-- *


--
-- Script :
--    sdbm_apex_vue.sql
--
-- Description :
--    Mise en place des vues requises pour l'accès au statut de l'environnement (APEX).
--


CREATE OR REPLACE VIEW SDBM.APEX_CIBLE_BD
AS 
   /******************************************************************
   * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
   * Licensed under the MIT license.
   *******************************************************************/   
   SELECT TO_CHAR(
                   DECODE(STATUT
                        ,'DN',5
                        ,DECODE(STATUT
                               ,'UK',5
                               ,DECODE(NB_EVENEMENT_OUVERT
                                      ,0,DECODE(NB_ALERT_OUVERT
                                               ,0,DECODE(NB_EVENEMENT_REPARATION
                                                        ,0,1
                                                        ,2
                                                        )
                                               ,3
                                               )
                                      ,4
                                      )
                               )
                         )
                 )                                                                                                            "SEVERITE"
         ,NOM_CIBLE
         ,TYPE                                                                                                                "TYPE"
         ,NOM_SERVEUR
         ,INFORMATION_OS
         ,SGBD
         ,VERSION
         ,STATUT_AFF
         ,STATUT
         ,DH_STATUT
         ,NB_JOUR_STATUT
         ,DH_DERN_VERIF
         ,DH_PROCHAINE_VERIF
         ,NOTIFICATION_AFF
         ,NOTIFICATION
         ,NOTIFICATION_EN_ATTENTE
         ,STATUT_ALERT
         ,NB_ALERT_OUVERT
         ,STATUT_COLLECTE
         ,NB_EVENEMENT_OUVERT
         ,COMMENTAIRE
     FROM (
            SELECT NOM_CIBLE                                                                                                  "NOM_CIBLE"
                  ,(CASE LANGUE
                       WHEN 'FR' THEN
                          DECODE(TYPE_BD
                                ,'NI','Instance standard'
                                ,'AI','Instance ASM'
                                ,'RI','Instance RAC (' || NOM_CIBLE_REF || ')'
                                ,'RD','Base de données RAC'
                                )
                       WHEN 'AN' THEN
                          DECODE(TYPE_BD
                                ,'NI','Standard instance'
                                ,'AI','ASM instance'
                                ,'RI','RAC instance (' || NOM_CIBLE_REF || ')'
                                ,'RD','RAC database'
                                )
                   END)                                                                                                       "TYPE"
                  ,DECODE(INSTR(NOM_SERVEUR,'.')
                         ,0,UPPER(NOM_SERVEUR)
                         ,UPPER(SUBSTR(NOM_SERVEUR,1,INSTR(NOM_SERVEUR,'.')-1))
                         )                                                                                                    "NOM_SERVEUR"
                  ,(SELECT NOM_OS
                      FROM INFO_AGT
                     WHERE NOM_SERVEUR = UPPER(CIBLE.NOM_SERVEUR)
                   )                                                                                                          "INFORMATION_OS"
                  ,DECODE(SOUS_TYPE_CIBLE
                         ,'OR','(1) Oracle'
                         ,'MS','(2) SQLServer'
                         ,'MY','(3) MySQL'
                         ,'(4) ' || SOUS_TYPE_CIBLE
                         )                                                                                                    "SGBD"
                  ,DECODE(VERSION
                         ,TO_CHAR(NULL),'N/D'
                         ,SUBSTR(VERSION,INSTR(VERSION,':')+2)
                         )                                                                                                    "VERSION"
                  ,(CASE LANGUE
                       WHEN 'FR' THEN
                          DECODE(STATUT
                                ,'UP','Disponible'
                                ,'DN','Non-disponible'
                                ,'Inconnu'
                               )
                       WHEN 'AN' THEN
                          DECODE(STATUT
                                ,'UP','Up'
                                ,'DN','Down'
                                ,'Unknown'
                               )
                   END)                                                                                                       "STATUT_AFF"
                  ,STATUT                                                                                                     "STATUT"
                  ,TO_CHAR(DECODE(STATUT
                                 ,'UP',STARTUP_TIME
                                 ,DH_MAJ_STATUT
                                 )
                          ,'YYYY/MM/DD:HH24:MI:SS'
                          )                                                                                                   "DH_STATUT"
                  ,TO_CHAR(TRUNC(SYSDATE - DECODE(STATUT
                                                 ,'UP',STARTUP_TIME
                                                 ,DH_MAJ_STATUT
                                                 )
                                )
                          )                                                                                                   "NB_JOUR_STATUT"
                  ,NVL(TO_CHAR(DH_DERN_VERIF
                              ,'YYYY/MM/DD:HH24:MI:SS'
                              )
                      ,'N/D'
                      )                                                                                                       "DH_DERN_VERIF"
                  ,NVL(TO_CHAR(DH_PROCHAINE_VERIF
                              ,'YYYY/MM/DD:HH24:MI:SS'
                              )
                      ,'N/D'
                      )                                                                                                       "DH_PROCHAINE_VERIF"
                  ,(CASE LANGUE
                       WHEN 'FR' THEN
                          DECODE(NOTIFICATION
                                ,'AC','Actif'
                                ,'IN','Inactif'
                                )
                       WHEN 'AN' THEN
                          DECODE(NOTIFICATION
                                ,'AC','Active'
                                ,'IN','Inactive'
                                )
                   END)                                                                                                       "NOTIFICATION_AFF"
                  ,NOTIFICATION                                                                                               "NOTIFICATION"
                  ,DECODE(NOTIF_EFFECT
                         ,'OK','Non'
                         ,'Oui'
                         )                                                                                                    "NOTIFICATION_EN_ATTENTE"
                  ,(SELECT DECODE(COUNT(1),0,'IN','AC')
                      FROM EVENEMENT_CIBLE
                     WHERE TYPE_CIBLE   = CIBLE.TYPE_CIBLE
                       AND NOM_CIBLE    = CIBLE.NOM_CIBLE
                       AND NOM_EVENEMENT = 'ALERT'
                   )                                                                                                          "STATUT_ALERT"
                  ,(SELECT TO_CHAR(COUNT(1))
                      FROM HIST_EVENEMENT_CIBLE_AGT
                     WHERE DH_HIST_EVENEMENT > SYSDATE - 1/24
                       AND TYPE_CIBLE        = CIBLE.TYPE_CIBLE
                       AND NOM_CIBLE         = CIBLE.NOM_CIBLE
                       AND TEXTE         NOT LIKE '%ORA-00000%'
                   )                                                                                                          "NB_ALERT_OUVERT"
                  ,(SELECT DECODE(COUNT(1),0,'IN','AC')
                      FROM EVENEMENT_CIBLE
                     WHERE TYPE_CIBLE   = CIBLE.TYPE_CIBLE
                       AND NOM_CIBLE    = CIBLE.NOM_CIBLE
                       AND NOM_EVENEMENT IN
                           (
                              'CD_ASM_DISKGROUP'
                             ,'CD_DBA_DATA_FILES'
                             ,'CD_ESPACE_ARCHIVED_LOG'
                             ,'CD_FILESTAT'
                             ,'CD_TRANSACTION_LOG'
                           )
                   )                                                                                                          "STATUT_COLLECTE"
                  ,(SELECT TO_CHAR(COUNT(1))
                      FROM HIST_EVENEMENT_CIBLE
                     WHERE TYPE_CIBLE   = CIBLE.TYPE_CIBLE
                       AND NOM_CIBLE    = CIBLE.NOM_CIBLE
                       AND DH_FERMETURE IS NULL
                   )                                                                                                          "NB_EVENEMENT_OUVERT"
                  ,GREATEST((
                              SELECT COUNT(1)
                                FROM HIST_EVENEMENT_CIBLE HEC
                                    ,EVENEMENT            EVE
                               WHERE HEC.TYPE_CIBLE       = CIBLE.TYPE_CIBLE
                                 AND HEC.NOM_CIBLE        = CIBLE.NOM_CIBLE
                                 AND EVE.TYPE_CIBLE       = CIBLE.TYPE_CIBLE
                                 AND EVE.SOUS_TYPE_CIBLE  = CIBLE.SOUS_TYPE_CIBLE
                                 AND EVE.NOM_EVENEMENT    = HEC.NOM_EVENEMENT
                                 AND HEC.DH_FERMETURE     > SYSDATE - 1/24
                                 AND EVE.TYPE_FERMETURE  != 'AU'
                            )
                           ,(
                              SELECT COUNT(1)
                                FROM DUAL
                               WHERE CIBLE.DH_MAJ_STATUT > SYSDATE - 1/24
                            )
                           )                                                                                                  "NB_EVENEMENT_REPARATION"
                  ,COMMENTAIRE                                                                                                "COMMENTAIRE"
              FROM CIBLE
                  ,PARAMETRE
             WHERE TYPE_CIBLE = 'BD'
          );


CREATE OR REPLACE TRIGGER SDBM.APEX_CIBLE_BD_TRIOU_CIBLE
   INSTEAD OF UPDATE ON SDBM.APEX_CIBLE_BD

   /******************************************************************
   * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
   * Licensed under the MIT license.
   *******************************************************************/

BEGIN

   IF (:OLD.STATUT != :NEW.STATUT) THEN

      UPDATE CIBLE
         SET STATUT = :NEW.STATUT
       WHERE NOM_CIBLE = :NEW.NOM_CIBLE;

   END IF;
         
   IF (:OLD.NOTIFICATION != :NEW.NOTIFICATION) THEN

      UPDATE CIBLE
         SET NOTIFICATION = :NEW.NOTIFICATION
       WHERE NOM_CIBLE = :NEW.NOM_CIBLE;

   END IF;

END APEX_CIBLE_BD_TRIOU_CIBLE;
/



CREATE OR REPLACE VIEW SDBM.APEX_EVENEMENT_BD
AS 
   /******************************************************************
   * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
   * Licensed under the MIT license.
   *******************************************************************/
   SELECT NOM_CIBLE                                                       "NOM_CIBLE"
         ,TO_CHAR(DH_HIST_EVENEMENT,'YYYY/MM/DD:HH24:MI:SS')              "DH_HIST_EVENEMENT"
         ,NOM_EVENEMENT                                                   "NOM_EVENEMENT"
         ,NOM_OBJET                                                       "NOM_OBJET"
         ,TO_CHAR(DH_DERN_OCCURRENCE,'YYYY/MM/DD:HH24:MI:SS')             "DH_DERN_OCCURRENCE"
         ,TO_CHAR(DH_FERMETURE,'YYYY/MM/DD:HH24:MI:SS')                   "DH_FERMETURE"
         ,RESULTAT                                                        "RESULTAT"
     FROM HIST_EVENEMENT_CIBLE
    WHERE TYPE_CIBLE = 'BD'
    UNION ALL
   SELECT NOM_CIBLE                                                       "NOM_CIBLE"
         ,TO_CHAR(DH_HIST_CIBLE,'YYYY/MM/DD:HH24:MI:SS')                  "DH_HIST_EVENEMENT"
         ,(CASE LANGUE
              WHEN 'FR' THEN
                 DECODE(STATUT
                       ,'UP','Instance : Disponible'
                       ,'DN','Instance : Non-Disponible'
                       ,'RD','Instance : Redémarrée'
                       ,'Inconnu'
                       )
              WHEN 'AN' THEN
                 DECODE(STATUT
                       ,'UP','Instance : Up'
                       ,'DN','Instance : Down'
                       ,'RD','Instance : Restarted'
                       ,'Unknown'
                       )
          END)                                                            "NOM_EVENEMENT"
         ,'N/A'                                                           "NOM_OBJET"
         ,'N/A'                                                           "DH_DERN_OCCURRENCE"
         ,'N/A'                                                           "DH_FERMETURE"
         ,(CASE LANGUE
              WHEN 'FR' THEN
                 DECODE(STATUT
                       ,'UP',NOM_CIBLE || ' est disponible'     || DECODE(ERREUR_RESEAU,'VR',' (connexion seulement).','.')
                       ,'DN',NOM_CIBLE || ' est NON-DISPONIBLE' || DECODE(ERREUR_RESEAU,'VR',' (connexion seulement).','.')
                       ,'RD',NOM_CIBLE || ' est de nouveau disponible (a été redémarrée).'
                       ,'Le statut de l''instance ' || NOM_CIBLE || ' est inconnu.'
                       )                                                    
              WHEN 'AN' THEN
                 DECODE(STATUT
                       ,'UP',NOM_CIBLE || ' is up'   || DECODE(ERREUR_RESEAU,'VR',' (connection only).','.')
                       ,'DN',NOM_CIBLE || ' is DOWN' || DECODE(ERREUR_RESEAU,'VR',' (connection only).','.')
                       ,'RD',NOM_CIBLE || ' is now up (has been restarted).'
                       ,'Le statut de l''instance ' || NOM_CIBLE || ' est inconnu.'
                       )                                                    
          END)                                                            "RESULTAT"
     FROM HIST_CIBLE
         ,PARAMETRE
    WHERE TYPE_CIBLE = 'BD';



CREATE OR REPLACE VIEW SDBM.APEX_REPARATION_BD
AS
   /******************************************************************
   * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
   * Licensed under the MIT license.
   *******************************************************************/
   SELECT HRE.NOM_CIBLE                                                   "NOM_CIBLE"
         ,TO_CHAR(HRE.DH_HIST_REPARATION,'YYYY/MM/DD:HH24:MI:SS')         "DH_HIST_REPARATION"
         ,HRE.NOM_EVENEMENT                                               "NOM_EVENEMENT"
         ,HRE.NOM_REPARATION                                              "NOM_REPARATION"
         ,NVL((SELECT DISTINCT DECODE(LANGUE
                                     ,'FR','Ouvert'
                                     ,'AN','Open'
                                     )
                   FROM HIST_EVENEMENT_CIBLE HEC
                  WHERE HEC.TYPE_CIBLE         = HRE.TYPE_CIBLE
                    AND HEC.NOM_CIBLE          = HRE.NOM_CIBLE
                    AND HEC.NOM_EVENEMENT      = HRE.NOM_EVENEMENT
                    AND HEC.DH_HIST_EVENEMENT <= HRE.DH_HIST_REPARATION
                    AND HEC.DH_FERMETURE      IS NULL
              )
              ,DECODE(LANGUE
                     ,'FR','Fermé'
                     ,'AN','Closed'
                     )
              )
                                                                          "STATUT"
         ,(CASE LANGUE
              WHEN 'FR' THEN
                 DECODE(HRE.STATUT
                      ,'OK','Terminée avec succès'
                      ,'Terminée en échec'
                       )       
              WHEN 'AN' THEN
                 DECODE(HRE.STATUT
                      ,'OK','Completed sucessfully'
                      ,'Completed with error'
                       )       
          END)                                                            "RESULTAT"
     FROM HIST_REPARATION_EVEN_CIBLE HRE
         ,PARAMETRE
    WHERE HRE.TYPE_CIBLE = 'BD';



CREATE OR REPLACE VIEW SDBM.APEX_ALERTE_BD
AS
   /******************************************************************
   * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
   * Licensed under the MIT license.
   *******************************************************************/
   SELECT NOM_CIBLE                                                       "NOM_CIBLE"
         ,TO_CHAR(DH_HIST_EVENEMENT,'YYYY/MM/DD:HH24:MI:SS')              "DH_HIST_EVENEMENT"
         ,NOM_EVENEMENT                                                   "NOM_EVENEMENT"
         ,TEXTE                                                           "TEXTE"
         ,(CASE LANGUE
              WHEN 'FR' THEN
                 DECODE(STATUT
                      ,'AE','Notification en cours'
                      ,'Notification effectuée'
                       )
              WHEN 'AN' THEN
                 DECODE(STATUT
                      ,'AE','Notification in progress'
                      ,'Notification completed'
                       )
          END)                                                            "STATUT"
         ,DECODE((SELECT COUNT(1) FROM DUAL
                   WHERE (SYSDATE - DH_HIST_EVENEMENT) * 1440 < 60
                 )
                ,1,1
                ,0
                )                                                         "EVENEMENT_RECENT" 
     FROM HIST_EVENEMENT_CIBLE_AGT
         ,PARAMETRE
    WHERE TYPE_CIBLE = 'BD';



CREATE OR REPLACE VIEW SDBM.APEX_HIS_PANNE_BD
AS
   /******************************************************************
   * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
   * Licensed under the MIT license.
   *******************************************************************/
   SELECT HC.NOM_CIBLE                                                    "NOM_CIBLE"
         ,HC.DH_HIST_CIBLE                                                "DH_DEB_PANNE"
         ,NVL(
                (SELECT MIN(DH_HIST_CIBLE)
                   FROM HIST_CIBLE
                  WHERE STATUT        = 'UP'
                    AND TYPE_CIBLE    = HC.TYPE_CIBLE
                    AND NOM_CIBLE     = HC.NOM_CIBLE
                    AND DH_HIST_CIBLE > HC.DH_HIST_CIBLE
                )
                ,DECODE((SELECT COUNT(1)
                           FROM CIBLE
                          WHERE NOM_CIBLE    = HC.NOM_CIBLE
                            AND TYPE_CIBLE   = HC.TYPE_CIBLE
                            AND NOTIFICATION = 'AC'
                        )
                       ,1,SYSDATE
                       ,HC.DH_HIST_CIBLE
                       )
             )                                                            "DH_FIN_PANNE"
         ,DECODE(PA.LANGUE
                ,'FR','Réelle'
                ,'AN','Reel'
                )                                                         "TYPE_PANNE"
         ,DECODE(INSTR(CI.NOM_SERVEUR,'.')
                ,0,UPPER(CI.NOM_SERVEUR)
                ,UPPER(SUBSTR(CI.NOM_SERVEUR,1,INSTR(CI.NOM_SERVEUR,'.')-1))
                )                                                         "NOM_SERVEUR"
         ,DECODE(CI.SOUS_TYPE_CIBLE
                ,'OR','(1) Oracle'
                ,'MS','(2) SQLServer'
                ,'MY','(3) MySQL'
                ,'(4) ' || SOUS_TYPE_CIBLE
                )                                                         "SGBD"
         ,SUBSTR(CI.VERSION,INSTR(CI.VERSION,':')+2)                      "VERSION"
     FROM HIST_CIBLE HC
         ,CIBLE      CI
         ,PARAMETRE  PA
    WHERE HC.NOM_CIBLE     = CI.NOM_CIBLE(+)
      AND HC.TYPE_CIBLE    = CI.TYPE_CIBLE(+)
      AND HC.STATUT        = 'DN'
      AND HC.ERREUR_RESEAU = 'FA'
      AND HC.TYPE_CIBLE    = 'BD'
   UNION ALL
   SELECT HC.NOM_CIBLE                                                    "NOM_CIBLE"
         ,HC.DH_HIST_CIBLE                                                "DH_DEB_PANNE"
         ,HC.DH_HIST_CIBLE                                                "DH_FIN_PANNE"
         ,DECODE(PA.LANGUE
                ,'FR','Connexion'
                ,'AN','Connection'
                )                                                         "TYPE_PANNE"
         ,DECODE(INSTR(CI.NOM_SERVEUR,'.')
                ,0,UPPER(CI.NOM_SERVEUR)
                ,UPPER(SUBSTR(CI.NOM_SERVEUR,1,INSTR(CI.NOM_SERVEUR,'.')-1))
                )                                                         "NOM_SERVEUR"
         ,DECODE(CI.SOUS_TYPE_CIBLE
                ,'OR','(1) Oracle'
                ,'MS','(2) SQLServer'
                ,'MY','(3) MySQL'
                ,'(4) ' || SOUS_TYPE_CIBLE
                )                                                         "SGBD"
         ,SUBSTR(CI.VERSION,INSTR(CI.VERSION,':')+2)                      "VERSION"
     FROM HIST_CIBLE HC
         ,CIBLE      CI
         ,PARAMETRE  PA
    WHERE HC.NOM_CIBLE     = CI.NOM_CIBLE(+)
      AND HC.TYPE_CIBLE    = CI.TYPE_CIBLE(+)
      AND HC.STATUT        = 'DN'
      AND HC.ERREUR_RESEAU = 'VR'
      AND HC.TYPE_CIBLE    = 'BD'
   UNION ALL
   SELECT HC.NOM_CIBLE                                                    "NOM_CIBLE"
         ,HC.DH_HIST_CIBLE                                                "DH_DEB_PANNE"
         ,HC.DH_HIST_CIBLE + 1/1440                                       "DH_FIN_PANNE"
         ,DECODE(PA.LANGUE
                ,'FR','Redémarrage'
                ,'AN','Restart'
                )                                                         "TYPE_PANNE"
         ,DECODE(INSTR(CI.NOM_SERVEUR,'.')
                ,0,UPPER(CI.NOM_SERVEUR)
                ,UPPER(SUBSTR(CI.NOM_SERVEUR,1,INSTR(CI.NOM_SERVEUR,'.')-1))
                )                                                         "NOM_SERVEUR"
         ,DECODE(CI.SOUS_TYPE_CIBLE
                ,'OR','(1) Oracle'
                ,'MS','(2) SQLServer'
                ,'MY','(3) MySQL'
                ,'(4) ' || SOUS_TYPE_CIBLE
                )                                                         "SGBD"
         ,SUBSTR(CI.VERSION,INSTR(CI.VERSION,':')+2)                      "VERSION"
     FROM HIST_CIBLE HC
         ,CIBLE      CI
         ,PARAMETRE  PA
    WHERE HC.NOM_CIBLE     = CI.NOM_CIBLE(+)
      AND HC.TYPE_CIBLE    = CI.TYPE_CIBLE(+)
      AND HC.STATUT        = 'RD'
      AND HC.TYPE_CIBLE    = 'BD';



CREATE OR REPLACE VIEW SDBM.APEX_NIV_SER_DERN_MOIS_COMPLET
AS
   /******************************************************************
   * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
   * Licensed under the MIT license.
   *******************************************************************/
   SELECT LC.NOM_CIBLE                                                    "NOM_CIBLE"
         ,LC.DH_MISE_EN_SERVICE                                           "DH_MISE_EN_SERVICE"
         ,DECODE(INSTR(CI.NOM_SERVEUR,'.')
                ,0,UPPER(CI.NOM_SERVEUR)
                ,UPPER(SUBSTR(CI.NOM_SERVEUR,1,INSTR(CI.NOM_SERVEUR,'.')-1))
                )                                                         "NOM_SERVEUR"
         ,DECODE(CI.SOUS_TYPE_CIBLE
                ,'OR','(1) Oracle'
                ,'MS','(2) SQLServer'
                ,'MY','(3) MySQL'
                ,'(4) ' || SOUS_TYPE_CIBLE
                )                                                         "SGBD"
         ,SUBSTR(CI.VERSION,INSTR(CI.VERSION,':')+2)                      "VERSION"
         ,LC.DATE_DEB_PERIODE                                             "DATE_DEB_PERIODE"
         ,LC.DATE_FIN_PERIODE                                             "DATE_FIN_PERIODE"
         ,NVL(
               (SELECT SUM(DH_FIN_PANNE - DH_DEB_PANNE)
                   FROM APEX_HIS_PANNE_BD
                  WHERE NOM_CIBLE    = LC.NOM_CIBLE
                    AND DH_FIN_PANNE > LC.DATE_DEB_PERIODE
                    AND DH_DEB_PANNE < LC.DATE_FIN_PERIODE
                )
                ,0
             ) * 1440                                                     "TEMPS_PANNE_MIN"
         ,CEIL(
                (LC.DATE_FIN_PERIODE - GREATEST(NVL(LC.DH_MISE_EN_SERVICE
                                                   ,LC.DATE_FIN_PERIODE
                                                )
                                               ,LC.DATE_DEB_PERIODE
                                               )
                ) * 1440
              )                                                           "TEMPS_TOTAL_MIN"
     FROM (
            SELECT HC.NOM_CIBLE                         "NOM_CIBLE"
                  ,HC.TYPE_CIBLE                        "TYPE_CIBLE"
                  ,(SELECT MIN(DH_HIST_CIBLE)
                      FROM HIST_CIBLE
                     WHERE TYPE_CIBLE = 'BD'
                       AND STATUT     = 'UP'
                       AND NOM_CIBLE  = HC.NOM_CIBLE
                   )                                    "DH_MISE_EN_SERVICE"
                   ,TRUNC(ADD_MONTHS(SYSDATE,-1),'MM')  "DATE_DEB_PERIODE"
                   ,TRUNC(SYSDATE,'MM') - 1/86400       "DATE_FIN_PERIODE"
              FROM HIST_CIBLE HC
             GROUP BY HC.NOM_CIBLE
                     ,HC.TYPE_CIBLE
          ) LC
          ,CIBLE CI
     WHERE LC.NOM_CIBLE  = CI.NOM_CIBLE
       AND LC.TYPE_CIBLE = CI.TYPE_CIBLE;
 

CREATE OR REPLACE VIEW SDBM.APEX_NIV_SER_DERN_MOIS
AS
   /******************************************************************
   * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
   * Licensed under the MIT license.
   *******************************************************************/
   SELECT LC.NOM_CIBLE                                                    "NOM_CIBLE"
         ,LC.DH_MISE_EN_SERVICE                                           "DH_MISE_EN_SERVICE"
         ,DECODE(INSTR(CI.NOM_SERVEUR,'.')
                ,0,UPPER(CI.NOM_SERVEUR)
                ,UPPER(SUBSTR(CI.NOM_SERVEUR,1,INSTR(CI.NOM_SERVEUR,'.')-1))
                )                                                         "NOM_SERVEUR"
         ,DECODE(CI.SOUS_TYPE_CIBLE
                ,'OR','(1) Oracle'
                ,'MS','(2) SQLServer'
                ,'MY','(3) MySQL'
                ,'(4) ' || SOUS_TYPE_CIBLE
                )                                                         "SGBD"
         ,SUBSTR(CI.VERSION,INSTR(CI.VERSION,':')+2)                      "VERSION"
         ,LC.DATE_DEB_PERIODE                                             "DATE_DEB_PERIODE"
         ,LC.DATE_FIN_PERIODE                                             "DATE_FIN_PERIODE"
         ,NVL(
               (SELECT SUM(DH_FIN_PANNE - DH_DEB_PANNE)
                   FROM APEX_HIS_PANNE_BD
                  WHERE NOM_CIBLE    = LC.NOM_CIBLE
                    AND DH_FIN_PANNE > LC.DATE_DEB_PERIODE
                    AND DH_DEB_PANNE < LC.DATE_FIN_PERIODE
                )
                ,0
             ) * 1440                                                     "TEMPS_PANNE_MIN"
         ,CEIL(
                (LC.DATE_FIN_PERIODE - GREATEST(NVL(LC.DH_MISE_EN_SERVICE
                                                   ,LC.DATE_FIN_PERIODE
                                                )
                                               ,LC.DATE_DEB_PERIODE
                                               )
                ) * 1440
              )                                                           "TEMPS_TOTAL_MIN"
     FROM (
            SELECT HC.NOM_CIBLE                         "NOM_CIBLE"
                  ,HC.TYPE_CIBLE                        "TYPE_CIBLE"
                  ,(SELECT MIN(DH_HIST_CIBLE)
                      FROM HIST_CIBLE
                     WHERE TYPE_CIBLE = 'BD'
                       AND STATUT     = 'UP'
                       AND NOM_CIBLE  = HC.NOM_CIBLE
                   )                                    "DH_MISE_EN_SERVICE"
                   ,ADD_MONTHS(SYSDATE,-1)              "DATE_DEB_PERIODE"
                   ,SYSDATE - 1/86400                   "DATE_FIN_PERIODE"
              FROM HIST_CIBLE HC
             GROUP BY HC.NOM_CIBLE
                     ,HC.TYPE_CIBLE
          ) LC
          ,CIBLE CI
     WHERE LC.NOM_CIBLE  = CI.NOM_CIBLE
       AND LC.TYPE_CIBLE = CI.TYPE_CIBLE;
 

CREATE OR REPLACE VIEW SDBM.APEX_NIV_SER_DERN_ANNEE
AS
   /******************************************************************
   * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
   * Licensed under the MIT license.
   *******************************************************************/
   SELECT LC.NOM_CIBLE                                                    "NOM_CIBLE"
         ,LC.DH_MISE_EN_SERVICE                                           "DH_MISE_EN_SERVICE"
         ,DECODE(INSTR(CI.NOM_SERVEUR,'.')
                ,0,UPPER(CI.NOM_SERVEUR)
                ,UPPER(SUBSTR(CI.NOM_SERVEUR,1,INSTR(CI.NOM_SERVEUR,'.')-1))
                )                                                         "NOM_SERVEUR"
         ,DECODE(CI.SOUS_TYPE_CIBLE
                ,'OR','(1) Oracle'
                ,'MS','(2) SQLServer'
                ,'MY','(3) MySQL'
                ,'(4) ' || SOUS_TYPE_CIBLE
                )                                                         "SGBD"
         ,SUBSTR(CI.VERSION,INSTR(CI.VERSION,':')+2)                      "VERSION"
         ,LC.DATE_DEB_PERIODE                                             "DATE_DEB_PERIODE"
         ,LC.DATE_FIN_PERIODE                                             "DATE_FIN_PERIODE"
         ,NVL(
               (SELECT SUM(DH_FIN_PANNE - DH_DEB_PANNE)
                   FROM APEX_HIS_PANNE_BD
                  WHERE NOM_CIBLE    = LC.NOM_CIBLE
                    AND DH_FIN_PANNE > LC.DATE_DEB_PERIODE
                    AND DH_DEB_PANNE < LC.DATE_FIN_PERIODE
                )
                ,0
             ) * 1440                                                     "TEMPS_PANNE_MIN"
         ,CEIL(
                (LC.DATE_FIN_PERIODE - GREATEST(NVL(LC.DH_MISE_EN_SERVICE
                                                   ,LC.DATE_FIN_PERIODE
                                                )
                                               ,LC.DATE_DEB_PERIODE
                                               )
                ) * 1440
              )                                                           "TEMPS_TOTAL_MIN"
     FROM (
            SELECT HC.NOM_CIBLE                         "NOM_CIBLE"
                  ,HC.TYPE_CIBLE                        "TYPE_CIBLE"
                  ,(SELECT MIN(DH_HIST_CIBLE)
                      FROM HIST_CIBLE
                     WHERE TYPE_CIBLE = 'BD'
                       AND STATUT     = 'UP'
                       AND NOM_CIBLE  = HC.NOM_CIBLE
                   )                                    "DH_MISE_EN_SERVICE"
                   ,ADD_MONTHS(SYSDATE,-12)             "DATE_DEB_PERIODE"
                   ,SYSDATE - 1/86400                   "DATE_FIN_PERIODE"
              FROM HIST_CIBLE HC
             GROUP BY HC.NOM_CIBLE
                     ,HC.TYPE_CIBLE
          ) LC
          ,CIBLE CI
     WHERE LC.NOM_CIBLE  = CI.NOM_CIBLE
       AND LC.TYPE_CIBLE = CI.TYPE_CIBLE;

 
CREATE OR REPLACE VIEW SDBM.APEX_NIV_SER_VIE
AS
   /******************************************************************
   * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
   * Licensed under the MIT license.
   *******************************************************************/
   SELECT LC.NOM_CIBLE                                                    "NOM_CIBLE"
         ,LC.DH_MISE_EN_SERVICE                                           "DH_MISE_EN_SERVICE"
         ,DECODE(INSTR(CI.NOM_SERVEUR,'.')
                ,0,UPPER(CI.NOM_SERVEUR)
                ,UPPER(SUBSTR(CI.NOM_SERVEUR,1,INSTR(CI.NOM_SERVEUR,'.')-1))
                )                                                         "NOM_SERVEUR"
         ,DECODE(CI.SOUS_TYPE_CIBLE
                ,'OR','(1) Oracle'
                ,'MS','(2) SQLServer'
                ,'MY','(3) MySQL'
                ,'(4) ' || SOUS_TYPE_CIBLE
                )                                                         "SGBD"
         ,SUBSTR(CI.VERSION,INSTR(CI.VERSION,':')+2)                      "VERSION"
         ,LC.DATE_DEB_PERIODE                                             "DATE_DEB_PERIODE"
         ,LC.DATE_FIN_PERIODE                                             "DATE_FIN_PERIODE"
         ,NVL(
               (SELECT SUM(DH_FIN_PANNE - DH_DEB_PANNE)
                   FROM APEX_HIS_PANNE_BD
                  WHERE NOM_CIBLE    = LC.NOM_CIBLE
                    AND DH_FIN_PANNE > LC.DATE_DEB_PERIODE
                    AND DH_DEB_PANNE < LC.DATE_FIN_PERIODE
                )
                ,0
             ) * 1440                                                     "TEMPS_PANNE_MIN"
         ,CEIL(
                (LC.DATE_FIN_PERIODE - GREATEST(NVL(LC.DH_MISE_EN_SERVICE
                                                   ,LC.DATE_FIN_PERIODE
                                                )
                                               ,LC.DATE_DEB_PERIODE
                                               )
                ) * 1440
              )                                                           "TEMPS_TOTAL_MIN"
     FROM (
            SELECT HC.NOM_CIBLE                         "NOM_CIBLE"
                  ,HC.TYPE_CIBLE                        "TYPE_CIBLE"
                  ,(SELECT MIN(DH_HIST_CIBLE)
                      FROM HIST_CIBLE
                     WHERE TYPE_CIBLE = 'BD'
                       AND STATUT     = 'UP'
                       AND NOM_CIBLE  = HC.NOM_CIBLE
                   )                                    "DH_MISE_EN_SERVICE"
                  ,(SELECT MIN(DH_HIST_CIBLE)
                      FROM HIST_CIBLE
                     WHERE TYPE_CIBLE = 'BD'
                       AND STATUT     = 'UP'
                       AND NOM_CIBLE  = HC.NOM_CIBLE
                   )                                    "DATE_DEB_PERIODE"
                   ,SYSDATE - 1/86400                   "DATE_FIN_PERIODE"
              FROM HIST_CIBLE HC
             GROUP BY HC.NOM_CIBLE
                     ,HC.TYPE_CIBLE
          ) LC
          ,CIBLE CI
     WHERE LC.NOM_CIBLE  = CI.NOM_CIBLE
       AND LC.TYPE_CIBLE = CI.TYPE_CIBLE;
 


CREATE OR REPLACE VIEW SDBM.APEX_JOURNAL
AS
   /******************************************************************
   * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
   * Licensed under the MIT license.
   *******************************************************************/
   SELECT ID_JOURNAL
         ,TO_CHAR(DH_JOURNAL,'YYYY/MM/DD:HH24:MI:SS.FF') "DH_JOURNAL"
         ,NIVEAU
         ,SOURCE
         ,TEXTE
     FROM JOURNAL;



CREATE MATERIALIZED VIEW MV_INFO_VOLUME_FICHIER
   REFRESH COMPLETE
   AS
   /******************************************************************
   * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
   * Licensed under the MIT license.
   *******************************************************************/
      SELECT VOP.ID_VOLUME_PHY
            ,VOP.DESC_VOLUME_PHY
            ,DDF.NOM_CIBLE
            ,DDF.FILE_ID
        FROM CD_DBA_DATA_FILES DDF
            ,VOLUME_PHY        VOP
       WHERE DDF.ID_VOLUME_PHY  = VOP.ID_VOLUME_PHY
         AND DH_COLLECTE_DONNEE = (SELECT MAX(DH_COLLECTE_DONNEE)
                                     FROM CD_DBA_DATA_FILES
                                    WHERE NOM_CIBLE = DDF.NOM_CIBLE
                                      AND FILE_ID   = DDF.FILE_ID
                                  )
         AND DDF.ID_VOLUME_PHY != 0;


CREATE MATERIALIZED VIEW MV_INFO_VOLUME_UTILISATION
   REFRESH COMPLETE
   AS
   /******************************************************************
   * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
   * Licensed under the MIT license.
   *******************************************************************/
      SELECT VLP.ID_VOLUME_PHY                                                                           ID_VOLUME_PHY
            ,VOL.NOM_CIBLE                                                                               NOM_CIBLE
            ,ROUND((AUJ.BYTES_FIC - HIE.BYTES_FIC) / 1024 / 1024 /   1,1)                                TAUX_CR_FIC_DERN_JOUR
            ,ROUND((AUJ.BYTES_FIC - SEM.BYTES_FIC) / 1024 / 1024 /   7,1)                                TAUX_CR_FIC_DERN_SEMAINE
            ,ROUND((AUJ.BYTES_FIC - MO1.BYTES_FIC) / 1024 / 1024 /  30,1)                                TAUX_CR_FIC_DERN_30_JRS
            ,ROUND((AUJ.BYTES_FIC - MO3.BYTES_FIC) / 1024 / 1024 /  90,1)                                TAUX_CR_FIC_DERN_90_JRS
            ,ROUND((AUJ.BYTES_FIC - ANN.BYTES_FIC) / 1024 / 1024 / 365,1)                                TAUX_CR_FIC_DERN_365_JRS
            ,NVL(ROUND(AUJ.BYTES_FIC / 1024 / 1024,1),0)                                                 TAILLE_FIC_UTILISE
            ,DECODE((SELECT DISTINCT 1
                       FROM CD_DBA_DATA_FILES
                      WHERE NOM_CIBLE = VOL.NOM_CIBLE
                        AND BYTES_FREE = -1
                    )
                    ,1,TO_NUMBER(NULL)
                    ,ROUND((AUJ.BYTES_OBJ - HIE.BYTES_OBJ) / 1024 / 1024 /   1,1)
                   )                                                                                     TAUX_CR_OBJ_DERN_JOUR
            ,DECODE((SELECT DISTINCT 1
                       FROM CD_DBA_DATA_FILES
                      WHERE NOM_CIBLE = VOL.NOM_CIBLE
                        AND BYTES_FREE = -1
                    )
                    ,1,TO_NUMBER(NULL)
                    ,ROUND((AUJ.BYTES_OBJ - SEM.BYTES_OBJ) / 1024 / 1024 /   7,1)
                   )                                                                                     TAUX_CR_OBJ_DERN_SEMAINE
            ,DECODE((SELECT DISTINCT 1
                       FROM CD_DBA_DATA_FILES
                      WHERE NOM_CIBLE = VOL.NOM_CIBLE
                        AND BYTES_FREE = -1
                    )
                    ,1,TO_NUMBER(NULL)
                    ,ROUND((AUJ.BYTES_OBJ - MO1.BYTES_OBJ) / 1024 / 1024 /  30,1)
                   )                                                                                     TAUX_CR_OBJ_DERN_30_JRS
            ,DECODE((SELECT DISTINCT 1
                       FROM CD_DBA_DATA_FILES
                      WHERE NOM_CIBLE = VOL.NOM_CIBLE
                        AND BYTES_FREE = -1
                    )
                    ,1,TO_NUMBER(NULL)
                    ,ROUND((AUJ.BYTES_OBJ - MO3.BYTES_OBJ) / 1024 / 1024 /  90,1)
                   )                                                                                     TAUX_CR_OBJ_DERN_90_JRS
            ,DECODE((SELECT DISTINCT 1
                       FROM CD_DBA_DATA_FILES
                      WHERE NOM_CIBLE = VOL.NOM_CIBLE
                        AND BYTES_FREE = -1
                    )
                    ,1,TO_NUMBER(NULL)
                    ,ROUND((AUJ.BYTES_OBJ - ANN.BYTES_OBJ) / 1024 / 1024 / 365,1)
                   )                                                                                     TAUX_CR_OBJ_DERN_365_JRS
            ,DECODE((SELECT DISTINCT 1
                       FROM CD_DBA_DATA_FILES
                      WHERE NOM_CIBLE = VOL.NOM_CIBLE
                        AND BYTES_FREE = -1
                    )
                    ,1,TO_NUMBER(NULL)
                    ,NVL(ROUND(AUJ.BYTES_OBJ / 1024 / 1024,1),0)
                   )                                                                                     TAILLE_OBJ_UTILISE
        FROM VOLUME_PHY
             VLP
            ,(
                SELECT ID_VOLUME_PHY ID_VOLUME_PHY
                      ,NOM_CIBLE     NOM_CIBLE
                  FROM CD_DBA_DATA_FILES
                 WHERE DH_COLLECTE_DONNEE > TRUNC(SYSDATE) - 365
                 GROUP BY ID_VOLUME_PHY
                         ,NOM_CIBLE
             )
             VOL
            ,(
                SELECT ID_VOLUME_PHY                  ID_VOLUME_PHY
                      ,NOM_CIBLE                      NOM_CIBLE
                      ,SUM(BYTES)                     BYTES_FIC
                      ,SUM(BYTES - NVL(BYTES_FREE,0)) BYTES_OBJ
                  FROM CD_DBA_DATA_FILES
                 WHERE DH_COLLECTE_DONNEE BETWEEN TRUNC(SYSDATE) - 0
                                              AND TRUNC(SYSDATE) - 0 + 1 - 1/86400
                 GROUP BY ID_VOLUME_PHY
                         ,NOM_CIBLE
             )
             AUJ
            ,(
                SELECT ID_VOLUME_PHY                  ID_VOLUME_PHY
                      ,NOM_CIBLE                      NOM_CIBLE
                      ,SUM(BYTES)                     BYTES_FIC
                      ,SUM(BYTES - NVL(BYTES_FREE,0)) BYTES_OBJ
                  FROM CD_DBA_DATA_FILES
                 WHERE DH_COLLECTE_DONNEE BETWEEN TRUNC(SYSDATE) - 1
                                              AND TRUNC(SYSDATE) - 1 + 1 - 1/86400
                 GROUP BY ID_VOLUME_PHY
                         ,NOM_CIBLE
             )
             HIE
            ,(
                SELECT ID_VOLUME_PHY                  ID_VOLUME_PHY
                      ,NOM_CIBLE                      NOM_CIBLE
                      ,SUM(BYTES)                     BYTES_FIC
                      ,SUM(BYTES - NVL(BYTES_FREE,0)) BYTES_OBJ
                  FROM CD_DBA_DATA_FILES
                 WHERE DH_COLLECTE_DONNEE BETWEEN TRUNC(SYSDATE) - 7
                                              AND TRUNC(SYSDATE) - 7 + 1 - 1/86400
                 GROUP BY ID_VOLUME_PHY
                         ,NOM_CIBLE
             )
             SEM
            ,(
                SELECT ID_VOLUME_PHY                 ID_VOLUME_PHY
                      ,NOM_CIBLE                      NOM_CIBLE
                      ,SUM(BYTES)                     BYTES_FIC
                      ,SUM(BYTES - NVL(BYTES_FREE,0)) BYTES_OBJ
                  FROM CD_DBA_DATA_FILES
                 WHERE DH_COLLECTE_DONNEE BETWEEN TRUNC(SYSDATE) - 30
                                              AND TRUNC(SYSDATE) - 30 + 1 - 1/86400
                 GROUP BY ID_VOLUME_PHY
                         ,NOM_CIBLE
             )
             MO1
            ,(
                SELECT ID_VOLUME_PHY                  ID_VOLUME_PHY
                      ,NOM_CIBLE                      NOM_CIBLE
                      ,SUM(BYTES)                     BYTES_FIC
                      ,SUM(BYTES - NVL(BYTES_FREE,0)) BYTES_OBJ
                  FROM CD_DBA_DATA_FILES
                 WHERE DH_COLLECTE_DONNEE BETWEEN TRUNC(SYSDATE) - 90
                                              AND TRUNC(SYSDATE) - 90 + 1 - 1/86400
                 GROUP BY ID_VOLUME_PHY
                         ,NOM_CIBLE
             )
             MO3
            ,(
                SELECT ID_VOLUME_PHY                  ID_VOLUME_PHY
                      ,NOM_CIBLE                      NOM_CIBLE
                      ,SUM(BYTES)                     BYTES_FIC
                      ,SUM(BYTES - NVL(BYTES_FREE,0)) BYTES_OBJ
                  FROM CD_DBA_DATA_FILES
                 WHERE DH_COLLECTE_DONNEE BETWEEN TRUNC(SYSDATE) - 365
                                              AND TRUNC(SYSDATE) - 365 + 1 - 1/86400
                 GROUP BY ID_VOLUME_PHY
                         ,NOM_CIBLE
             )
             ANN
       WHERE VOL.ID_VOLUME_PHY      = VLP.ID_VOLUME_PHY
         AND VOL.ID_VOLUME_PHY      = AUJ.ID_VOLUME_PHY(+)
         AND VOL.NOM_CIBLE          = AUJ.NOM_CIBLE(+) 
         AND VOL.ID_VOLUME_PHY      = HIE.ID_VOLUME_PHY(+)
         AND VOL.NOM_CIBLE          = HIE.NOM_CIBLE(+) 
         AND VOL.ID_VOLUME_PHY      = SEM.ID_VOLUME_PHY(+)
         AND VOL.NOM_CIBLE          = SEM.NOM_CIBLE(+) 
         AND VOL.ID_VOLUME_PHY      = MO1.ID_VOLUME_PHY(+)
         AND VOL.NOM_CIBLE          = MO1.NOM_CIBLE(+) 
         AND VOL.ID_VOLUME_PHY      = MO3.ID_VOLUME_PHY(+)
         AND VOL.NOM_CIBLE          = MO3.NOM_CIBLE(+) 
         AND VOL.ID_VOLUME_PHY      = ANN.ID_VOLUME_PHY(+)
         AND VOL.NOM_CIBLE          = ANN.NOM_CIBLE(+);



CREATE OR REPLACE VIEW SDBM.APEX_TAB_EVOLUTION_FIC_BD
AS 
   /******************************************************************
   * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
   * Licensed under the MIT license.
   *******************************************************************/
   SELECT NOM_CIBLE
         ,ID_VOLUME_PHY
         ,VOLUME
         ,COMMENTAIRE
         ,DERN_JOUR
         ,DERN_SEMAINE
         ,DERN_30_JRS
         ,DERN_90_JRS
         ,DERN_365_JRS
         ,ESPACE_UTIL_GB
         ,ESPACE_UTIL_VOL_GB
         ,ESPACE_DISP_VOL_GB
         ,CASE
             WHEN (TAUX_JOUR_MB_LT = 0)                                                         THEN 'N/A - Stable'
             WHEN ((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_LT / 1024) > 1095) THEN 'N/A - Stable'
             WHEN ((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_LT / 1024) <    0) THEN DECODE(LANGUE,'FR','N/A - Régression','AN','N/A - Regression')
             ELSE
                TO_CHAR(TRUNC(SYSDATE)
                      + FLOOR((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_LT / 1024))
                       ,'YYYY/MM/DD'
                       )
          END
          DATE_LIMITE_LT
         ,CASE
             WHEN (TAUX_JOUR_MB_LT = 0)                                                         THEN 100
             WHEN ((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_LT / 1024) > 1095) THEN 100
             WHEN ((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_LT / 1024) <    0) THEN 100
             ELSE
                FLOOR((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_LT / 1024))
             END
          NB_JOUR_LT
         ,CASE
             WHEN (TAUX_JOUR_MB_WC = 0)                                                         THEN 'N/A - Stable'
             WHEN ((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_WC / 1024) > 1095) THEN 'N/A - Stable'
             WHEN ((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_WC / 1024) <    0) THEN DECODE(LANGUE,'FR','N/A - Régression','AN','N/A - Regression')
             ELSE
                TO_CHAR(TRUNC(SYSDATE)
                      + FLOOR((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_WC / 1024))
                       ,'YYYY/MM/DD'
                       )
          END
          DATE_LIMITE_WC
         ,CASE
             WHEN (TAUX_JOUR_MB_WC = 0)                                                         THEN 100
             WHEN ((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_WC / 1024) > 1095) THEN 100
             WHEN ((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_WC / 1024) <    0) THEN 100
             ELSE
                FLOOR((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_WC / 1024))
             END
          NB_JOUR_WC
     FROM (
            SELECT INVU.NOM_CIBLE                                                                           NOM_CIBLE
                  ,INVU.ID_VOLUME_PHY                                                                       ID_VOLUME_PHY
                  ,VOLP.DESC_VOLUME_PHY                                                                     VOLUME
                  ,VOLP.COMMENTAIRE                                                                         COMMENTAIRE
                   /* Long term scenario */
                  ,DECODE(INVU.ID_VOLUME_PHY
                         ,0,TO_NUMBER(NULL)
                         ,(SELECT SUM(CASE
                                         WHEN TAUX_CR_FIC_DERN_365_JRS IS NOT NULL THEN TAUX_CR_FIC_DERN_365_JRS
                                         WHEN TAUX_CR_FIC_DERN_90_JRS  IS NOT NULL THEN TAUX_CR_FIC_DERN_90_JRS
                                         WHEN TAUX_CR_FIC_DERN_30_JRS  IS NOT NULL THEN TAUX_CR_FIC_DERN_30_JRS
                                         WHEN TAUX_CR_FIC_DERN_SEMAINE IS NOT NULL THEN TAUX_CR_FIC_DERN_SEMAINE
                                         WHEN TAUX_CR_FIC_DERN_JOUR    IS NOT NULL THEN TAUX_CR_FIC_DERN_JOUR
                                      END
                                     )
                             FROM MV_INFO_VOLUME_UTILISATION
                            WHERE ID_VOLUME_PHY = INVU.ID_VOLUME_PHY
                          )
                         )
                   TAUX_JOUR_MB_LT
                   /* Worst case scenario */
                  ,DECODE(INVU.ID_VOLUME_PHY
                         ,0,TO_NUMBER(NULL)
                         ,(SELECT SUM(GREATEST(NVL(TAUX_CR_FIC_DERN_365_JRS,0)
                                              ,NVL(TAUX_CR_FIC_DERN_90_JRS,0)
                                              ,NVL(TAUX_CR_FIC_DERN_30_JRS,0)
                                              ,NVL(TAUX_CR_FIC_DERN_SEMAINE,0)
                                              )
                                     )
                             FROM MV_INFO_VOLUME_UTILISATION
                            WHERE ID_VOLUME_PHY  = INVU.ID_VOLUME_PHY
                          )
                         )
                   TAUX_JOUR_MB_WC
                  ,INVU.TAUX_CR_FIC_DERN_JOUR                                                               DERN_JOUR
                  ,INVU.TAUX_CR_FIC_DERN_SEMAINE                                                            DERN_SEMAINE
                  ,INVU.TAUX_CR_FIC_DERN_30_JRS                                                             DERN_30_JRS
                  ,INVU.TAUX_CR_FIC_DERN_90_JRS                                                             DERN_90_JRS
                  ,INVU.TAUX_CR_FIC_DERN_365_JRS                                                            DERN_365_JRS
                  ,ROUND(INVU.TAILLE_FIC_UTILISE / 1024,3)                                                  ESPACE_UTIL_GB
                  ,DECODE(INVU.ID_VOLUME_PHY
                         ,0,TO_NUMBER(NULL)
                         ,DECODE((SELECT VOLP.FREE_MB
                                    FROM DUAL
                                   WHERE VOLP.FREE_MB     != -1
                                     AND EXISTS (SELECT MAX(DH_COLLECTE_DONNEE)
                                                   FROM CD_ASM_DISKGROUP
                                                  WHERE NOM_CIBLE = VOLP.NOM_CIBLE_DERN_MAJ
                                                    AND HOST_NAME || '_+' || DISKGROUP_NAME = VOLP.DESC_VOLUME_PHY
                                                 HAVING MAX(DH_COLLECTE_DONNEE) > SYSDATE - 1
                                                )
                                 )
                                 ,TO_NUMBER(NULL),(SELECT ROUND(SUM(TAILLE_FIC_UTILISE) / 1024,3)
                                                     FROM MV_INFO_VOLUME_UTILISATION
                                                    WHERE ID_VOLUME_PHY = INVU.ID_VOLUME_PHY
                                                  )
                                 ,ROUND((VOLP.TOTAL_MB - VOLP.FREE_MB) / 1024,3)
                                )
                         )                                                                                  ESPACE_UTIL_VOL_GB
                  ,DECODE(INVU.ID_VOLUME_PHY
                         ,0,TO_NUMBER(NULL)
                         ,ROUND(VOLP.TOTAL_MB / 1024,3)
                         )                                                                                  ESPACE_DISP_VOL_GB
              FROM MV_INFO_VOLUME_UTILISATION INVU
                  ,VOLUME_PHY                 VOLP
             WHERE INVU.ID_VOLUME_PHY = VOLP.ID_VOLUME_PHY
          )
         ,PARAMETRE;



CREATE OR REPLACE VIEW SDBM.APEX_TAB_EVOLUTION_OBJ_BD
AS
   /******************************************************************
   * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
   * Licensed under the MIT license.
   *******************************************************************/
   SELECT NOM_CIBLE
         ,ID_VOLUME_PHY
         ,VOLUME
         ,COMMENTAIRE
         ,DERN_JOUR
         ,DERN_SEMAINE
         ,DERN_30_JRS
         ,DERN_90_JRS
         ,DERN_365_JRS
         ,ESPACE_UTIL_GB
         ,ESPACE_UTIL_VOL_GB
         ,ESPACE_DISP_VOL_GB
         ,CASE
             WHEN (TAUX_JOUR_MB_LT = 0)                                                         THEN 'N/A - Stable'
             WHEN ((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_LT / 1024) > 1095) THEN 'N/A - Stable'
             WHEN ((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_LT / 1024) <    0) THEN DECODE(LANGUE,'FR','N/A - Régression','AN','N/A - Regression')
             ELSE
                TO_CHAR(TRUNC(SYSDATE)
                      + FLOOR((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_LT / 1024))
                       ,'YYYY/MM/DD'
                       )
          END
          DATE_LIMITE_LT
         ,CASE
             WHEN (TAUX_JOUR_MB_LT = 0)                                                         THEN 100
             WHEN ((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_LT / 1024) > 1095) THEN 100
             WHEN ((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_LT / 1024) <    0) THEN 100
             ELSE
                FLOOR((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_LT / 1024))
             END
          NB_JOUR_LT
         ,CASE
             WHEN (TAUX_JOUR_MB_WC = 0)                                                         THEN 'N/A - Stable'
             WHEN ((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_WC / 1024) > 1095) THEN 'N/A - Stable'
             WHEN ((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_WC / 1024) <    0) THEN DECODE(LANGUE,'FR','N/A - Régression','AN','N/A - Regression')
             ELSE
                TO_CHAR(TRUNC(SYSDATE)
                      + FLOOR((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_WC / 1024))
                       ,'YYYY/MM/DD'
                       )
          END
          DATE_LIMITE_WC
         ,CASE
             WHEN (TAUX_JOUR_MB_WC = 0)                                                         THEN 100
             WHEN ((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_WC / 1024) > 1095) THEN 100
             WHEN ((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_WC / 1024) <    0) THEN 100
             ELSE
                FLOOR((ESPACE_DISP_VOL_GB - ESPACE_UTIL_VOL_GB) / (TAUX_JOUR_MB_WC / 1024))
             END
          NB_JOUR_WC
     FROM (
            SELECT INVU.NOM_CIBLE                                                                           NOM_CIBLE
                  ,INVU.ID_VOLUME_PHY                                                                       ID_VOLUME_PHY
                  ,VOLP.DESC_VOLUME_PHY                                                                     VOLUME
                  ,VOLP.COMMENTAIRE                                                                         COMMENTAIRE
                   /* Long term scenario */
                  ,DECODE(INVU.ID_VOLUME_PHY
                         ,0,TO_NUMBER(NULL)
                         ,(SELECT SUM(CASE
                                         WHEN TAUX_CR_OBJ_DERN_365_JRS IS NOT NULL THEN TAUX_CR_OBJ_DERN_365_JRS
                                         WHEN TAUX_CR_OBJ_DERN_90_JRS  IS NOT NULL THEN TAUX_CR_OBJ_DERN_90_JRS
                                         WHEN TAUX_CR_OBJ_DERN_30_JRS  IS NOT NULL THEN TAUX_CR_OBJ_DERN_30_JRS
                                         WHEN TAUX_CR_OBJ_DERN_SEMAINE IS NOT NULL THEN TAUX_CR_OBJ_DERN_SEMAINE
                                         WHEN TAUX_CR_OBJ_DERN_JOUR    IS NOT NULL THEN TAUX_CR_OBJ_DERN_JOUR
                                      END
                                     )
                             FROM MV_INFO_VOLUME_UTILISATION
                            WHERE ID_VOLUME_PHY = INVU.ID_VOLUME_PHY
                          )
                         )
                   TAUX_JOUR_MB_LT
                   /* Worst case scenario */
                  ,DECODE(INVU.ID_VOLUME_PHY
                         ,0,TO_NUMBER(NULL)
                         ,(SELECT SUM(GREATEST(NVL(TAUX_CR_OBJ_DERN_365_JRS,0)
                                              ,NVL(TAUX_CR_OBJ_DERN_90_JRS,0)
                                              ,NVL(TAUX_CR_OBJ_DERN_30_JRS,0)
                                              ,NVL(TAUX_CR_OBJ_DERN_SEMAINE,0)
                                              )
                                     )
                             FROM MV_INFO_VOLUME_UTILISATION
                            WHERE ID_VOLUME_PHY = INVU.ID_VOLUME_PHY
                          )
                         )
                   TAUX_JOUR_MB_WC
                  ,INVU.TAUX_CR_OBJ_DERN_JOUR                                                               DERN_JOUR
                  ,INVU.TAUX_CR_OBJ_DERN_SEMAINE                                                            DERN_SEMAINE
                  ,INVU.TAUX_CR_OBJ_DERN_30_JRS                                                             DERN_30_JRS
                  ,INVU.TAUX_CR_OBJ_DERN_90_JRS                                                             DERN_90_JRS
                  ,INVU.TAUX_CR_OBJ_DERN_365_JRS                                                            DERN_365_JRS
                  ,ROUND(INVU.TAILLE_OBJ_UTILISE / 1024,3)                                                  ESPACE_UTIL_GB
                  ,DECODE(INVU.ID_VOLUME_PHY
                         ,0,TO_NUMBER(NULL)
                         ,DECODE((SELECT VOLP.FREE_MB
                                    FROM DUAL
                                   WHERE VOLP.FREE_MB     != -1
                                     AND EXISTS (SELECT MAX(DH_COLLECTE_DONNEE)
                                                   FROM CD_ASM_DISKGROUP
                                                  WHERE NOM_CIBLE = VOLP.NOM_CIBLE_DERN_MAJ
                                                    AND HOST_NAME || '_+' || DISKGROUP_NAME = VOLP.DESC_VOLUME_PHY
                                                 HAVING MAX(DH_COLLECTE_DONNEE) > SYSDATE - 1
                                                )
                                 )
                                 ,TO_NUMBER(NULL),(SELECT ROUND(SUM(TAILLE_FIC_UTILISE) / 1024,3)
                                                     FROM MV_INFO_VOLUME_UTILISATION
                                                    WHERE ID_VOLUME_PHY = INVU.ID_VOLUME_PHY
                                                  )
                                 ,ROUND((VOLP.TOTAL_MB - VOLP.FREE_MB) / 1024,3)
                                )
                         )                                                                                  ESPACE_UTIL_VOL_GB
                  ,DECODE(INVU.ID_VOLUME_PHY
                         ,0,TO_NUMBER(NULL)
                         ,ROUND(VOLP.TOTAL_MB / 1024,3)
                         )                                                                                  ESPACE_DISP_VOL_GB
              FROM MV_INFO_VOLUME_UTILISATION INVU
                  ,VOLUME_PHY                 VOLP
             WHERE INVU.ID_VOLUME_PHY = VOLP.ID_VOLUME_PHY
          )
         ,PARAMETRE;



CREATE OR REPLACE VIEW SDBM.APEX_CD_LISTE_VOLUME_HO
AS
   /******************************************************************
   * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
   * Licensed under the MIT license.
   *******************************************************************/
   SELECT DISTINCT
          DDF.NOM_CIBLE        "NOM_CIBLE"
         ,VOP.DESC_VOLUME_PHY  "VOLUME"
     FROM CD_DBA_DATA_FILES DDF
         ,VOLUME_PHY        VOP
    WHERE DDF.ID_VOLUME_PHY       = VOP.ID_VOLUME_PHY
      AND DDF.DH_COLLECTE_DONNEE >= TRUNC(SYSDATE) - 2
      AND (
             (
                DDF.ID_VOLUME_PHY != 0
             )
             OR
             (
                DDF.ID_VOLUME_PHY = 0
                AND NOT EXISTS (SELECT 1
                                  FROM MV_INFO_VOLUME_FICHIER
                                 WHERE NOM_CIBLE        = DDF.NOM_CIBLE
                                   AND FILE_ID          = DDF.FILE_ID
                               )
             )
          )
    ORDER BY VOLUME;


CREATE OR REPLACE VIEW SDBM.APEX_CD_LISTE_VOLUME_30
AS 
   SELECT DISTINCT
          DDF.NOM_CIBLE        "NOM_CIBLE"
         ,VOP.DESC_VOLUME_PHY  "VOLUME"
     FROM CD_DBA_DATA_FILES DDF
         ,VOLUME_PHY        VOP
    WHERE DDF.ID_VOLUME_PHY       = VOP.ID_VOLUME_PHY
      AND DDF.DH_COLLECTE_DONNEE >= TRUNC(SYSDATE) - 30
      AND (
             (
                DDF.ID_VOLUME_PHY != 0
             )
             OR
             (
                DDF.ID_VOLUME_PHY = 0
                AND NOT EXISTS (SELECT 1
                                  FROM MV_INFO_VOLUME_FICHIER
                                 WHERE NOM_CIBLE        = DDF.NOM_CIBLE
                                   AND FILE_ID          = DDF.FILE_ID
                               )
             )
          )
    ORDER BY VOLUME;


CREATE OR REPLACE VIEW SDBM.APEX_CD_LISTE_VOLUME_90
AS
   /******************************************************************
   * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
   * Licensed under the MIT license.
   *******************************************************************/
   SELECT DISTINCT
          DDF.NOM_CIBLE        "NOM_CIBLE"
         ,VOP.DESC_VOLUME_PHY  "VOLUME"
     FROM CD_DBA_DATA_FILES DDF
         ,VOLUME_PHY        VOP
    WHERE DDF.ID_VOLUME_PHY       = VOP.ID_VOLUME_PHY
      AND DDF.DH_COLLECTE_DONNEE >= TRUNC(SYSDATE) - 90
      AND (
             (
                DDF.ID_VOLUME_PHY != 0
             )
             OR
             (
                DDF.ID_VOLUME_PHY = 0
                AND NOT EXISTS (SELECT 1
                                  FROM MV_INFO_VOLUME_FICHIER
                                 WHERE NOM_CIBLE        = DDF.NOM_CIBLE
                                   AND FILE_ID          = DDF.FILE_ID
                               )
             )
          )
    ORDER BY VOLUME;


CREATE OR REPLACE VIEW SDBM.APEX_CD_LISTE_VOLUME_365
AS 
   SELECT DISTINCT
          DDF.NOM_CIBLE        "NOM_CIBLE"
         ,VOP.DESC_VOLUME_PHY  "VOLUME"
     FROM CD_DBA_DATA_FILES DDF
         ,VOLUME_PHY        VOP
    WHERE DDF.ID_VOLUME_PHY       = VOP.ID_VOLUME_PHY
      AND DDF.DH_COLLECTE_DONNEE >= TRUNC(SYSDATE) - 365
      AND (
             (
                DDF.ID_VOLUME_PHY != 0
             )
             OR
             (
                DDF.ID_VOLUME_PHY = 0
                AND NOT EXISTS (SELECT 1
                                  FROM MV_INFO_VOLUME_FICHIER
                                 WHERE NOM_CIBLE        = DDF.NOM_CIBLE
                                   AND FILE_ID          = DDF.FILE_ID
                               )
             )
          )
    ORDER BY VOLUME;



CREATE OR REPLACE VIEW SDBM.APEX_CD_ACT_DISQUE_PAR_VOL_HO
AS
   /******************************************************************
   * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
   * Licensed under the MIT license.
   *******************************************************************/
   SELECT /*+ FIRST_ROWS */
          NOM_CIBLE        "NOM_CIBLE"
         ,VOLUME           "VOLUME"
         ,PERIODE          "PERIODE"
         ,SUM(IO_MIN_RDS)  "IO_MIN_RDS"
         ,SUM(IO_MIN_WRTS) "IO_MIN_WRTS"
     FROM (
            SELECT NOM_CIBLE                                                     "NOM_CIBLE"
                  ,NVL
                   (
                      (
                         SELECT DESC_VOLUME_PHY
                           FROM MV_INFO_VOLUME_FICHIER
                          WHERE NOM_CIBLE = IOS.NOM_CIBLE
                            AND FILE_ID   = IOS.FILE#
                      )
                  ,'N/D'
                   )                                                             "VOLUME"
                  ,TRUNC(IOS.DH_PER_STAT_DEB,'MI')                               "PERIODE"
                  ,ROUND(PHYRDS  / ((DH_PER_STAT_FIN - DH_PER_STAT_DEB) * 1440)) "IO_MIN_RDS"
                  ,ROUND(PHYWRTS / ((DH_PER_STAT_FIN - DH_PER_STAT_DEB) * 1440)) "IO_MIN_WRTS"
              FROM CD_RAPPORT_IO_STAT IOS
             WHERE DH_PER_STAT_DEB > SYSDATE - 2
               AND TYPE_RAPPORT    = 'HO'
          )
    GROUP BY NOM_CIBLE
            ,VOLUME
            ,PERIODE;


CREATE OR REPLACE VIEW SDBM.APEX_CD_ACT_DISQUE_PAR_VOL_30
AS
   /******************************************************************
   * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
   * Licensed under the MIT license.
   *******************************************************************/
   SELECT /*+ FIRST_ROWS */
          NOM_CIBLE         "NOM_CIBLE"
         ,VOLUME            "VOLUME"
         ,PERIODE           "PERIODE"
         ,SUM(IO_JOUR_RDS)  "IO_JOUR_RDS"
         ,SUM(IO_JOUR_WRTS) "IO_JOUR_WRTS"
     FROM (
            SELECT NOM_CIBLE                                                     "NOM_CIBLE"
                  ,NVL
                   (
                      (
                         SELECT DESC_VOLUME_PHY
                           FROM MV_INFO_VOLUME_FICHIER
                          WHERE NOM_CIBLE = IOS.NOM_CIBLE
                            AND FILE_ID   = IOS.FILE#
                      )
                  ,'N/D'
                   )                                                             "VOLUME"
                  ,TRUNC(IOS.DH_PER_STAT_DEB)                                    "PERIODE"
                  ,ROUND(PHYRDS  / ((DH_PER_STAT_FIN - DH_PER_STAT_DEB)))        "IO_JOUR_RDS"
                  ,ROUND(PHYWRTS / ((DH_PER_STAT_FIN - DH_PER_STAT_DEB)))        "IO_JOUR_WRTS"
              FROM CD_RAPPORT_IO_STAT IOS
             WHERE DH_PER_STAT_DEB > SYSDATE - 30
               AND TYPE_RAPPORT    = 'QU'
          )
    GROUP BY NOM_CIBLE
            ,VOLUME
            ,PERIODE;


CREATE OR REPLACE VIEW SDBM.APEX_CD_ACT_DISQUE_PAR_VOL_90
AS
   /******************************************************************
   * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
   * Licensed under the MIT license.
   *******************************************************************/
   SELECT /*+ FIRST_ROWS */
          NOM_CIBLE         "NOM_CIBLE"
         ,VOLUME            "VOLUME"
         ,PERIODE           "PERIODE"
         ,SUM(IO_JOUR_RDS)  "IO_JOUR_RDS"
         ,SUM(IO_JOUR_WRTS) "IO_JOUR_WRTS"
     FROM (
            SELECT NOM_CIBLE                                                     "NOM_CIBLE"
                  ,NVL
                   (
                      (
                         SELECT DESC_VOLUME_PHY
                           FROM MV_INFO_VOLUME_FICHIER
                          WHERE NOM_CIBLE = IOS.NOM_CIBLE
                            AND FILE_ID   = IOS.FILE#
                      )
                  ,'N/D'
                   )                                                             "VOLUME"
                  ,TRUNC(IOS.DH_PER_STAT_DEB)                                    "PERIODE"
                  ,ROUND(PHYRDS  / ((DH_PER_STAT_FIN - DH_PER_STAT_DEB)))        "IO_JOUR_RDS"
                  ,ROUND(PHYWRTS / ((DH_PER_STAT_FIN - DH_PER_STAT_DEB)))        "IO_JOUR_WRTS"
              FROM CD_RAPPORT_IO_STAT IOS
             WHERE DH_PER_STAT_DEB > SYSDATE - 90
               AND TYPE_RAPPORT    = 'QU'
          )
    GROUP BY NOM_CIBLE
            ,VOLUME
            ,PERIODE;


CREATE OR REPLACE VIEW SDBM.APEX_CD_ACT_DISQUE_PAR_VOL_365
AS
   /******************************************************************
   * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
   * Licensed under the MIT license.
   *******************************************************************/
   SELECT /*+ FIRST_ROWS */
          NOM_CIBLE         "NOM_CIBLE"
         ,VOLUME            "VOLUME"
         ,PERIODE           "PERIODE"
         ,SUM(IO_JOUR_RDS)  "IO_JOUR_RDS"
         ,SUM(IO_JOUR_WRTS) "IO_JOUR_WRTS"
     FROM (
            SELECT NOM_CIBLE                                                     "NOM_CIBLE"
                  ,NVL
                   (
                      (
                         SELECT DESC_VOLUME_PHY
                           FROM MV_INFO_VOLUME_FICHIER
                          WHERE NOM_CIBLE = IOS.NOM_CIBLE
                            AND FILE_ID   = IOS.FILE#
                      )
                  ,'N/D'
                   )                                                             "VOLUME"
                  ,TRUNC(IOS.DH_PER_STAT_DEB)                                    "PERIODE"
                  ,ROUND(PHYRDS  / ((DH_PER_STAT_FIN - DH_PER_STAT_DEB)))        "IO_JOUR_RDS"
                  ,ROUND(PHYWRTS / ((DH_PER_STAT_FIN - DH_PER_STAT_DEB)))        "IO_JOUR_WRTS"
              FROM CD_RAPPORT_IO_STAT IOS
             WHERE DH_PER_STAT_DEB > SYSDATE - 365
               AND TYPE_RAPPORT    = 'QU'
          )
    GROUP BY NOM_CIBLE
            ,VOLUME
            ,PERIODE;


CREATE OR REPLACE VIEW SDBM.APEX_STATUT_SESSION_SDBM
AS
   /******************************************************************
   * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
   * Licensed under the MIT license.
   *******************************************************************/
   SELECT 'N/D'                                               "SERVEUR"
          ,'SDBMSRV - SCHEMA : ' || SDBM_APEX_UTIL.INFOSCHEMA "MODULE"
          ,'*** SDBMSrv is not running ***'                   "DESCRIPTION"
          ,'N/D'                                              "DERNIERE_ACTION"
          ,'N/D'                                              "ORACLE_LOGON"
          ,'N/D'                                              "ORACLE_SPID"
          ,'N/D'                                              "ORACLE_SID"
          ,'N/D'                                              "ORACLE_SERIAL"
          ,'N/D'                                              "ORACLE_STATUS"
          ,5                                                  "MISE_EN_EVIDENCE"
      FROM DUAL
     WHERE NOT EXISTS (SELECT 1
                         FROM V$SESSION
                        WHERE MODULE LIKE 'SDBMSRV - SCHEMA : ' || SDBM_APEX_UTIL.INFOSCHEMA
                      )
    UNION ALL
   SELECT 'N/D'                                               "SERVEUR"
          ,'SDBMDAC - SCHEMA : ' || SDBM_APEX_UTIL.INFOSCHEMA "MODULE"
          ,'*** SDBMDaC is not running ***'                   "DESCRIPTION"
          ,'N/D'                                              "DERNIERE_ACTION"
          ,'N/D'                                              "ORACLE_LOGON"
          ,'N/D'                                              "ORACLE_SPID"
          ,'N/D'                                              "ORACLE_SID"
          ,'N/D'                                              "ORACLE_SERIAL"
          ,'N/D'                                              "ORACLE_STATUS"
          ,3                                                  "MISE_EN_EVIDENCE"
      FROM DUAL
     WHERE NOT EXISTS (SELECT 1
                         FROM V$SESSION
                        WHERE MODULE LIKE 'SDBMDAC - SCHEMA : ' || SDBM_APEX_UTIL.INFOSCHEMA
                      )
    UNION ALL
    (
       SELECT UPPER(CIB.NOM_SERVEUR)                             "SERVEUR"
             ,'SDBMAGT - SCHEMA : ' || SDBM_APEX_UTIL.INFOSCHEMA "MODULE"
             ,'*** SDBMAgt is not running ***'                   "DESCRIPTION"
             ,'N/D'                                              "DERNIERE_ACTION"
             ,'N/D'                                              "ORACLE_LOGON"
             ,'N/D'                                              "ORACLE_SPID"
             ,'N/D'                                              "ORACLE_SID"
             ,'N/D'                                              "ORACLE_SERIAL"
             ,'N/D'                                              "ORACLE_STATUS"
             ,3                                                  "MISE_EN_EVIDENCE"
         FROM CIBLE           CIB
             ,EVENEMENT_CIBLE EVC
        WHERE CIB.TYPE_CIBLE    = EVC.TYPE_CIBLE
          AND CIB.NOM_CIBLE     = EVC.NOM_CIBLE
          AND CIB.NOTIFICATION  = 'AC'
          AND CIB.NOM_SERVEUR IS NOT NULL
          AND EVC.TYPE_CIBLE    = 'BD'
          AND EVC.NOM_EVENEMENT = 'ALERT'
          AND UPPER(CIB.NOM_SERVEUR) NOT IN (SELECT UPPER(CLIENT_IDENTIFIER) "SERVEUR"
                                               FROM V$SESSION
                                              WHERE MODULE LIKE 'SDBMAGT - SCHEMA : ' || SDBM_APEX_UTIL.INFOSCHEMA
                                            )
        UNION
       SELECT UPPER(NOM_SERVEUR)                                 "SERVEUR"
             ,'SDBMAGT - SCHEMA : ' || SDBM_APEX_UTIL.INFOSCHEMA "MODULE"
             ,'*** SDBMAgt is not running ***'                   "DESCRIPTION"
             ,'N/D'                                              "DERNIERE_ACTION"
             ,'N/D'                                              "ORACLE_LOGON"
             ,'N/D'                                              "ORACLE_SPID"
             ,'N/D'                                              "ORACLE_SID"
             ,'N/D'                                              "ORACLE_SERIAL"
             ,'N/D'                                              "ORACLE_STATUS"
             ,3                                                  "MISE_EN_EVIDENCE"
         FROM TACHE_AGT
        WHERE EXECUTION = 'AC'
          AND NOM_SERVEUR NOT IN (SELECT UPPER(CLIENT_IDENTIFIER) "SERVEUR"
                                    FROM V$SESSION
                                   WHERE MODULE LIKE 'SDBMAGT - SCHEMA : ' || SDBM_APEX_UTIL.INFOSCHEMA
                                 )
    )
     UNION ALL
    SELECT DECODE(SUBSTR(SESS.MODULE,1,7)
                 ,'SDBMSRV',UPPER(SUBSTR(SESS.CLIENT_INFO,INSTR(SESS.CLIENT_INFO,'running on ') + 11))
                 ,'SDBMDAC',UPPER(SUBSTR(SESS.CLIENT_INFO,INSTR(SESS.CLIENT_INFO,'running on ') + 11))
                 ,UPPER(CLIENT_IDENTIFIER)
                 )                                                                                           "SERVEUR"
          ,SESS.MODULE                                                                                       "MODULE"
          ,SUBSTR(SESS.CLIENT_INFO,1,INSTR(SESS.CLIENT_INFO,' running on ')-1)                               "DESCRIPTION"
          ,DECODE(SUBSTR(SESS.MODULE,1,7)
                 ,'SDBMSRV',SESS.ACTION || ' (' || NVL(CLIENT_IDENTIFIER,'--') || ')'
                 ,'SDBMDAC',SESS.ACTION || ' (' || NVL(CLIENT_IDENTIFIER,'--') || ')'
                 ,SESS.ACTION
                 )                                                                                           "DERNIERE_ACTION"
          ,TO_CHAR(SESS.LOGON_TIME,'YYYY/MM/DD:HH24:MI:SS')                                                  "ORACLE_LOGON"
          ,TO_CHAR(PROC.SPID)                                                                                "ORACLE_SPID"
          ,TO_CHAR(SESS.SID)                                                                                 "ORACLE_SID"
          ,TO_CHAR(SESS.SERIAL#)                                                                             "ORACLE_SERIAL"
          ,STATUS                                                                                            "ORACLE_STATUS"
          ,DECODE(SUBSTR(SESS.MODULE,1,7)
                 ,'SDBMSRV',(CASE WHEN (SYSDATE - TO_DATE(ACTION,'YYYY/MM/DD:HH24:MI:SS') > (SELECT (FREQU_VERIF_CIBLE_SEC + 60) / 86400 FROM PARAMETRE)) THEN 3 ELSE 1 END)
                 ,'SDBMDAC',(CASE WHEN (SYSDATE - TO_DATE(ACTION,'YYYY/MM/DD:HH24:MI:SS') >                                                 (90 / 86400)) THEN 3 ELSE 1 END)
                 ,'SDBMAGT',(CASE WHEN (SYSDATE - TO_DATE(ACTION,'YYYY/MM/DD:HH24:MI:SS') > (SELECT (FREQU_VERIF_AGENT     + 60) / 86400 FROM PARAMETRE)) THEN 3 ELSE 1 END)
                 )                                                                                           "MISE_EN_EVIDENCE"
      FROM V$SESSION SESS
          ,V$PROCESS PROC
     WHERE SESS.PADDR = PROC.ADDR
       AND SESS.MODULE LIKE 'SDBM___ - SCHEMA : ' || SDBM_APEX_UTIL.INFOSCHEMA;
