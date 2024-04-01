-- *
-- * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
-- * Licensed under the MIT license.
-- * See LICENSE file in the project root for full license information.
-- *


CREATE OR REPLACE PACKAGE BODY SDBM_COLLECTE
IS
/*********************************************************************
*
* Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
* Licensed under the MIT license.
*
**********************************************************************/
/*********************************************************************
  PACKAGE : SDBM_COLLECTE
  AUTEUR  : Benoit Bouthillier 2009-11-11 (2012-05-25)
 ---------------------------------------------------------------------
  BUT : Ce package permet l'implantation des procédures requise pour
        SDBM.

**********************************************************************/


   /******************************************************************
     CONSTANTE :
    *****************************************************************/

    -- Version de l'entête PL/SQL
    VERSION_PB CONSTANT VARCHAR2(4 CHAR) := '0.17';



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
     PROCEDURE : GENERER_ARCHIVED_LOG_RAC
     AUTEUR    : Benoit Bouthillier 2009-09-25
    ------------------------------------------------------------------
     BUT : Effectuée la génération des statistiques pour les base de
           données RAC (CD_ESPACE_ARCHIVED_LOG).

     PARAMETRES:  N/A
   ******************************************************************/

   PROCEDURE GENERER_ARCHIVED_LOG_RAC
   IS

      -- Curseur de traitement (base de données RAC)
      CURSOR C_BD_RAC IS
         SELECT NOM_CIBLE
           FROM CIBLE
          WHERE TYPE_CIBLE      = 'BD'
            AND SOUS_TYPE_CIBLE = 'OR'
            AND TYPE_BD         = 'RD';

   BEGIN

      --
      -- Traitement horaire (base de données RAC)
      --
      FOR RC_BD_RAC IN C_BD_RAC LOOP    

         BEGIN

            INSERT INTO CD_ESPACE_ARCHIVED_LOG
            (
               DH_COLLECTE_DONNEE
              ,NOM_CIBLE
              ,ESPACE
            )
            SELECT DH_COLLECTE_DONNEE   "DH_COLLECTE_DONNEE"
                  ,RC_BD_RAC.NOM_CIBLE  "NOM_CIBLE" 
                  ,SUM(ESPACE)          "ESPACE"
              FROM CD_ESPACE_ARCHIVED_LOG
             WHERE NOM_CIBLE         IN (SELECT NOM_CIBLE
                                           FROM CIBLE
                                          WHERE TYPE_CIBLE_REF = 'BD'
                                            AND NOM_CIBLE_REF  = RC_BD_RAC.NOM_CIBLE
                                        ) 
               AND DH_COLLECTE_DONNEE > (SELECT NVL(MAX(DH_COLLECTE_DONNEE),TO_DATE('2000','YYYY'))
                                           FROM CD_ESPACE_ARCHIVED_LOG
                                          WHERE NOM_CIBLE    = RC_BD_RAC.NOM_CIBLE
                                        )
             GROUP BY DH_COLLECTE_DONNEE;

         EXCEPTION

            -- Statistique précédentes incomplète
            WHEN DUP_VAL_ON_INDEX THEN

               DELETE FROM CD_ESPACE_ARCHIVED_LOG
                WHERE (DH_COLLECTE_DONNEE, NOM_CIBLE)
                   IN (
                        SELECT DH_COLLECTE_DONNEE   "DH_COLLECTE_DONNEE"
                              ,RC_BD_RAC.NOM_CIBLE  "NOM_CIBLE" 
                          FROM CD_ESPACE_ARCHIVED_LOG
                         WHERE NOM_CIBLE         IN (SELECT NOM_CIBLE
                                                       FROM CIBLE
                                                      WHERE TYPE_CIBLE_REF = 'BD'
                                                        AND NOM_CIBLE_REF  = RC_BD_RAC.NOM_CIBLE
                                                    ) 
                           AND DH_COLLECTE_DONNEE > (SELECT NVL(MAX(DH_COLLECTE_DONNEE),TO_DATE('2000','YYYY'))
                                                       FROM CD_ESPACE_ARCHIVED_LOG
                                                      WHERE NOM_CIBLE    = RC_BD_RAC.NOM_CIBLE
                                                    )
                         GROUP BY DH_COLLECTE_DONNEE
                      );

               INSERT INTO CD_ESPACE_ARCHIVED_LOG
               (
                  DH_COLLECTE_DONNEE
                 ,NOM_CIBLE
                 ,ESPACE
               )
               SELECT DH_COLLECTE_DONNEE   "DH_COLLECTE_DONNEE"
                     ,RC_BD_RAC.NOM_CIBLE  "NOM_CIBLE" 
                     ,SUM(ESPACE)          "ESPACE"
                 FROM CD_ESPACE_ARCHIVED_LOG
                WHERE NOM_CIBLE         IN (SELECT NOM_CIBLE
                                              FROM CIBLE
                                             WHERE TYPE_CIBLE_REF = 'BD'
                                               AND NOM_CIBLE_REF  = RC_BD_RAC.NOM_CIBLE
                                           ) 
                  AND DH_COLLECTE_DONNEE > (SELECT NVL(MAX(DH_COLLECTE_DONNEE),TO_DATE('2000','YYYY'))
                                              FROM CD_ESPACE_ARCHIVED_LOG
                                             WHERE NOM_CIBLE    = RC_BD_RAC.NOM_CIBLE
                                           )
                GROUP BY DH_COLLECTE_DONNEE;

         END;

      END LOOP;

      -- Fin de la transaction
      COMMIT;

   END GENERER_ARCHIVED_LOG_RAC;


   /******************************************************************
     PROCEDURE : GENERER_IO_STAT
     AUTEUR    : Benoit Bouthillier 2009-11-11
    ------------------------------------------------------------------
     BUT : Effectuée la génération des statistiques base sur
           CD_FILESTAT ainsi que la génération des données pour les
           base de données RAC.

     PARAMETRES:  N/A
   ******************************************************************/

   PROCEDURE GENERER_IO_STAT
   IS

      -- Curseur de traitement
      CURSOR C_CD_FILESTAT IS
         SELECT DH_COLLECTE_DONNEE
               ,NOM_CIBLE
               ,FILE#
               ,PHYRDS
               ,PHYWRTS
               ,STARTUP_TIME
           FROM CD_FILESTAT
          WHERE DH_COLLECTE_DONNEE > NVL((SELECT MAX(DH_PER_STAT_DEB) FROM CD_RAPPORT_IO_STAT),TO_DATE('2000','YYYY'))
          ORDER BY DH_COLLECTE_DONNEE;

      -- Curseur de traitement (base de données RAC)
      CURSOR C_BD_RAC IS
         SELECT NOM_CIBLE
           FROM CIBLE
          WHERE TYPE_CIBLE      = 'BD'
            AND SOUS_TYPE_CIBLE = 'OR'
            AND TYPE_BD         = 'RD';

      -- Curseur d'épuration CD_FILESTAT
      CURSOR C_DEL_CD_FILESTAT IS
         SELECT NOM_CIBLE             "NOM_CIBLE"
               ,MAX(DH_PER_STAT_DEB)  "DH_COLLECTE_DONNEE"
           FROM CD_RAPPORT_IO_STAT
          WHERE TYPE_RAPPORT = 'QU'
          GROUP BY NOM_CIBLE
          ORDER BY 1;

      -- Variable de traitement (début de l'intervalle)
      V_DH_COLLECTE_DONNEE_COUR CD_FILESTAT.DH_COLLECTE_DONNEE%TYPE;
      V_PHYRDS_COUR             CD_FILESTAT.PHYRDS%TYPE;
      V_PHYWRTS_COUR            CD_FILESTAT.PHYWRTS%TYPE;
      V_STARTUP_TIME_COUR       CD_FILESTAT.STARTUP_TIME%TYPE;

      -- Variable de traitement (fin de l'intervalle)
      V_DH_COLLECTE_DONNEE_SUIV CD_FILESTAT.DH_COLLECTE_DONNEE%TYPE;
      V_PHYRDS_SUIV             CD_FILESTAT.PHYRDS%TYPE;
      V_PHYWRTS_SUIV            CD_FILESTAT.PHYWRTS%TYPE;
      V_STARTUP_TIME_SUIV       CD_FILESTAT.STARTUP_TIME%TYPE;

      -- Variable de traitement
      V_STATUT                  CD_RAPPORT_IO_STAT.STATUT%TYPE;

      -- Indicateur de présence
      V_IND_PRESENCE            NUMBER;

   BEGIN

      --
      -- Traitement horaire
      --
      FOR RC_CD_FILESTAT IN C_CD_FILESTAT LOOP

         BEGIN

            -- Transfert des valeurs courrante
            V_DH_COLLECTE_DONNEE_COUR := RC_CD_FILESTAT.DH_COLLECTE_DONNEE;
            V_PHYRDS_COUR             := RC_CD_FILESTAT.PHYRDS;
            V_PHYWRTS_COUR            := RC_CD_FILESTAT.PHYWRTS;
            V_STARTUP_TIME_COUR       := RC_CD_FILESTAT.STARTUP_TIME;

            -- Recherche du la valeur suivante
            SELECT DH_COLLECTE_DONNEE
                  ,PHYRDS
                  ,PHYWRTS
                  ,STARTUP_TIME
              INTO V_DH_COLLECTE_DONNEE_SUIV
                  ,V_PHYRDS_SUIV
                  ,V_PHYWRTS_SUIV
                  ,V_STARTUP_TIME_SUIV
              FROM (
                      SELECT DH_COLLECTE_DONNEE
                            ,PHYRDS
                            ,PHYWRTS
                            ,STARTUP_TIME
                        FROM CD_FILESTAT
                       WHERE DH_COLLECTE_DONNEE > RC_CD_FILESTAT.DH_COLLECTE_DONNEE
                         AND NOM_CIBLE          = RC_CD_FILESTAT.NOM_CIBLE
                         AND FILE#              = RC_CD_FILESTAT.FILE#
                       ORDER BY DH_COLLECTE_DONNEE
                   )
             WHERE ROWNUM <= 1;

            -- Vérification si un redémarrage Oracle à eu lien
            IF (RC_CD_FILESTAT.STARTUP_TIME != V_STARTUP_TIME_SUIV) THEN

               -- On utilise le date de démarrage pour le calcul du temps
               V_DH_COLLECTE_DONNEE_COUR := V_STARTUP_TIME_SUIV;
               V_PHYRDS_COUR             := 0;
               V_PHYWRTS_COUR            := 0;
               V_STATUT                  := 'IN';

            ELSE
            
               V_STATUT                  := 'CO';

            END IF;


            -- Insertion des données
            INSERT INTO CD_RAPPORT_IO_STAT
            (
               NOM_CIBLE
              ,FILE#
              ,TYPE_RAPPORT
              ,DH_PER_STAT_DEB
              ,DH_PER_STAT_FIN
              ,PHYRDS
              ,PHYWRTS
              ,STATUT
            )
            VALUES
            (
               RC_CD_FILESTAT.NOM_CIBLE
              ,RC_CD_FILESTAT.FILE#
              ,'HO'
              ,V_DH_COLLECTE_DONNEE_COUR
              ,V_DH_COLLECTE_DONNEE_SUIV - 1/86400
              ,(V_PHYRDS_SUIV  - V_PHYRDS_COUR)
              ,(V_PHYWRTS_SUIV - V_PHYWRTS_COUR)
              ,V_STATUT
            );

         EXCEPTION

            WHEN NO_DATA_FOUND THEN 
               NULL;

            WHEN DUP_VAL_ON_INDEX THEN 
               SDBM_UTIL.JOURNALISER('SDBM_COLLECTE.GENERER_IO_STAT'
                                    ,'WARNING'
                                    ,'Duplicate on INSERT into CD_RAPPORT_IO_STAT (' ||         RC_CD_FILESTAT.NOM_CIBLE
                                                                                     || ', ' || RC_CD_FILESTAT.FILE#
                                                                                     || ', ' || 'HO'
                                                                                     || ', ' || TO_CHAR(V_DH_COLLECTE_DONNEE_COUR,'YYYY/MM/DD:HH24:MI:SS')
                                                                                     || ', ' || TO_CHAR(V_DH_COLLECTE_DONNEE_COUR,'YYYY/MM/DD:HH24:MI:SS')
                                                                                     || ', ' || TO_CHAR(V_PHYRDS_SUIV  - V_PHYRDS_COUR)
                                                                                     || ', ' || TO_CHAR(V_PHYWRTS_SUIV - V_PHYWRTS_COUR)
                                                                                     || ', ' || V_STATUT
                                                                              || '). Is time synchronized between servers?'
                                    );

         END;

      END LOOP;


      --
      -- Traitement horaire (base de données RAC)
      --
      FOR RC_BD_RAC IN C_BD_RAC LOOP    

         BEGIN

            INSERT INTO CD_RAPPORT_IO_STAT
            (
               NOM_CIBLE
              ,FILE#
              ,TYPE_RAPPORT
              ,DH_PER_STAT_DEB
              ,DH_PER_STAT_FIN
              ,PHYRDS
              ,PHYWRTS
              ,STATUT
            )
            SELECT RC_BD_RAC.NOM_CIBLE                                                                                                "NOM_CIBLE"
                  ,FILE#                                                                                                              "FILE#"
                  ,TYPE_RAPPORT                                                                                                       "TYPE_RAPPORT"
                  ,(TRUNC(DH_PER_STAT_DEB) + FLOOR((DH_PER_STAT_DEB - TRUNC(DH_PER_STAT_DEB)) * 144) * 10 / 1440)                     "DH_PER_STAT_DEB"
                  ,(TRUNC(DH_PER_STAT_DEB) + FLOOR((DH_PER_STAT_DEB - TRUNC(DH_PER_STAT_DEB)) * 144) * 10 / 1440) + 10/1440 - 1/86400 "DH_PER_STAT_FIN"
                  ,SUM(PHYRDS)                                                                                                        "PHYRDS"
                  ,SUM(PHYWRTS)                                                                                                       "PHYWRTS"
                  ,'ES'                                                                                                               "STATUT"    
              FROM CD_RAPPORT_IO_STAT
             WHERE NOM_CIBLE      IN (SELECT NOM_CIBLE
                                        FROM CIBLE
                                       WHERE TYPE_CIBLE_REF = 'BD'
                                         AND NOM_CIBLE_REF  = RC_BD_RAC.NOM_CIBLE
                                     ) 
               AND DH_PER_STAT_DEB > (SELECT NVL(MAX(DH_PER_STAT_FIN),TO_DATE('2000','YYYY'))
                                        FROM CD_RAPPORT_IO_STAT
                                       WHERE NOM_CIBLE    = RC_BD_RAC.NOM_CIBLE
                                         AND TYPE_RAPPORT = 'HO'
                                     )
               AND TYPE_RAPPORT    = 'HO'
             GROUP BY FILE#
                     ,TYPE_RAPPORT
                     ,TRUNC(DH_PER_STAT_DEB) + FLOOR((DH_PER_STAT_DEB - TRUNC(DH_PER_STAT_DEB)) * 144) * 10 / 1440;

         EXCEPTION

            WHEN DUP_VAL_ON_INDEX THEN

               -- Statistique précédentes incomplète
               DELETE FROM CD_RAPPORT_IO_STAT
                  WHERE (NOM_CIBLE, FILE#, TYPE_RAPPORT, DH_PER_STAT_DEB)
                     IN (
                           SELECT RC_BD_RAC.NOM_CIBLE                                                                                                "NOM_CIBLE"
                                 ,FILE#                                                                                                              "FILE#"
                                 ,TYPE_RAPPORT                                                                                                       "TYPE_RAPPORT"
                                 ,(TRUNC(DH_PER_STAT_DEB) + FLOOR((DH_PER_STAT_DEB - TRUNC(DH_PER_STAT_DEB)) * 144) * 10 / 1440)                     "DH_PER_STAT_DEB"
                             FROM CD_RAPPORT_IO_STAT
                            WHERE NOM_CIBLE      IN (SELECT NOM_CIBLE
                                                       FROM CIBLE
                                                      WHERE TYPE_CIBLE_REF = 'BD'
                                                        AND NOM_CIBLE_REF  = RC_BD_RAC.NOM_CIBLE
                                                    ) 
                              AND DH_PER_STAT_DEB > (SELECT NVL(MAX(DH_PER_STAT_FIN),TO_DATE('2000','YYYY'))
                                                       FROM CD_RAPPORT_IO_STAT
                                                      WHERE NOM_CIBLE    = RC_BD_RAC.NOM_CIBLE
                                                        AND TYPE_RAPPORT = 'HO'
                                                    )
                              AND TYPE_RAPPORT    = 'HO'
                            GROUP BY FILE#
                                    ,TYPE_RAPPORT
                                    ,TRUNC(DH_PER_STAT_DEB) + FLOOR((DH_PER_STAT_DEB - TRUNC(DH_PER_STAT_DEB)) * 144) * 10 / 1440
                        );

               INSERT INTO CD_RAPPORT_IO_STAT
               (
                  NOM_CIBLE
                 ,FILE#
                 ,TYPE_RAPPORT
                 ,DH_PER_STAT_DEB
                 ,DH_PER_STAT_FIN
                 ,PHYRDS
                 ,PHYWRTS
                 ,STATUT
               )
               SELECT RC_BD_RAC.NOM_CIBLE                                                                                                "NOM_CIBLE"
                     ,FILE#                                                                                                              "FILE#"
                     ,TYPE_RAPPORT                                                                                                       "TYPE_RAPPORT"
                     ,(TRUNC(DH_PER_STAT_DEB) + FLOOR((DH_PER_STAT_DEB - TRUNC(DH_PER_STAT_DEB)) * 144) * 10 / 1440)                     "DH_PER_STAT_DEB"
                     ,(TRUNC(DH_PER_STAT_DEB) + FLOOR((DH_PER_STAT_DEB - TRUNC(DH_PER_STAT_DEB)) * 144) * 10 / 1440) + 10/1440 - 1/86400 "DH_PER_STAT_FIN"
                     ,SUM(PHYRDS)                                                                                                        "PHYRDS"
                     ,SUM(PHYWRTS)                                                                                                       "PHYWRTS"
                     ,'ES'                                                                                                               "STATUT"    
                 FROM CD_RAPPORT_IO_STAT
                WHERE NOM_CIBLE      IN (SELECT NOM_CIBLE
                                           FROM CIBLE
                                          WHERE TYPE_CIBLE_REF = 'BD'
                                            AND NOM_CIBLE_REF  = RC_BD_RAC.NOM_CIBLE
                                        ) 
                  AND DH_PER_STAT_DEB > (SELECT NVL(MAX(DH_PER_STAT_FIN),TO_DATE('2000','YYYY'))
                                           FROM CD_RAPPORT_IO_STAT
                                          WHERE NOM_CIBLE    = RC_BD_RAC.NOM_CIBLE
                                            AND TYPE_RAPPORT = 'HO'
                                        )
                  AND TYPE_RAPPORT    = 'HO'
                GROUP BY FILE#
                        ,TYPE_RAPPORT
                        ,TRUNC(DH_PER_STAT_DEB) + FLOOR((DH_PER_STAT_DEB - TRUNC(DH_PER_STAT_DEB)) * 144) * 10 / 1440;

         END;

      END LOOP;


      --
      -- Traitement quotidien
      --
      SELECT COUNT(*)
        INTO V_IND_PRESENCE
        FROM CD_RAPPORT_IO_STAT
       WHERE DH_PER_STAT_DEB = TRUNC(SYSDATE - 1)
         AND TYPE_RAPPORT    = 'QU';

      -- Vérification d'exécution requise
      IF (V_IND_PRESENCE = 0) THEN
      
         -- Insertion des données quotidienne
         INSERT INTO CD_RAPPORT_IO_STAT
         (
            NOM_CIBLE
           ,FILE#
           ,TYPE_RAPPORT
           ,DH_PER_STAT_DEB
           ,DH_PER_STAT_FIN
           ,PHYRDS
           ,PHYWRTS
           ,STATUT
         )
         SELECT NOM_CIBLE
               ,FILE#
               ,'QU'
               ,TRUNC(DH_PER_STAT_DEB)
               ,TRUNC(DH_PER_STAT_DEB) + 1 - 1/86400
               ,SUM(PHYRDS)
               ,SUM(PHYWRTS)
               ,'NA'
           FROM CD_RAPPORT_IO_STAT
          WHERE TYPE_RAPPORT = 'HO'
            AND TRUNC(DH_PER_STAT_DEB) = TRUNC(SYSDATE - 1)
          GROUP BY TRUNC(DH_PER_STAT_DEB), NOM_CIBLE, FILE#;

         -- Épuration des données horaires (traitées)
         DELETE FROM CD_RAPPORT_IO_STAT
          WHERE DH_PER_STAT_DEB    < TRUNC(SYSDATE) - 2
            AND TYPE_RAPPORT       = 'HO';
      
         -- Épuration des données brutes (traitées)
         FOR RC_DEL_CD_FILESTAT IN C_DEL_CD_FILESTAT LOOP

            DELETE FROM CD_FILESTAT
             WHERE DH_COLLECTE_DONNEE < RC_DEL_CD_FILESTAT.DH_COLLECTE_DONNEE - 1
               AND NOM_CIBLE          = RC_DEL_CD_FILESTAT.NOM_CIBLE;

         END LOOP;
          
      END IF;

      -- Fin de la transaction
      COMMIT;

   END GENERER_IO_STAT;


   /******************************************************************
     PROCEDURE : TRAITEMENT_FIN_COLLECTE_BD
     AUTEUR    : Benoit Bouthillier 2012-04-23 (2012-05-07)
    ------------------------------------------------------------------
     BUT : Exécution des traitements sur les statistiques reçues.

     PARAMETRES:  N/A
   ******************************************************************/

   PROCEDURE TRAITEMENT_FIN_COLLECTE_BD
   IS

      -- Recherche des cibles à traiter (corretion des données après utilisation du "ALTERNATE SQL" - DBA_FREE_SPACE non disponible)
      CURSOR C_CIBLE IS
         SELECT NOM_CIBLE
           FROM CD_DBA_DATA_FILES DDF
          WHERE BYTES_FREE = -1
            AND EXISTS ((SELECT 1
                           FROM CD_DBA_DATA_FILES
                          WHERE NOM_CIBLE           = DDF.NOM_CIBLE
                            AND FILE_ID             = DDF.FILE_ID
                            AND DH_COLLECTE_DONNEE  > DDF.DH_COLLECTE_DONNEE
                            AND BYTES_FREE         != -1
                       ))
          GROUP BY NOM_CIBLE
          ORDER BY NOM_CIBLE;

      -- Variables locales
      V_DERN_COLLECTE_DONNNE_DDF DATE; 
      V_DERN_REFRESH_INFO_VOLUME DATE; 
      
   BEGIN

      -- Génération des statistiques
      GENERER_IO_STAT;
      GENERER_ARCHIVED_LOG_RAC;


      -- Refresh du MV (si requis)
      SELECT MAX(DH_COLLECTE_DONNEE)
        INTO V_DERN_COLLECTE_DONNNE_DDF
        FROM CD_DBA_DATA_FILES;

      SELECT LAST_REFRESH_DATE
        INTO V_DERN_REFRESH_INFO_VOLUME
        FROM USER_MVIEWS
       WHERE MVIEW_NAME = 'MV_INFO_VOLUME_FICHIER';

      IF (V_DERN_COLLECTE_DONNNE_DDF IS NULL OR V_DERN_REFRESH_INFO_VOLUME IS NULL OR V_DERN_COLLECTE_DONNNE_DDF > V_DERN_REFRESH_INFO_VOLUME) THEN

         -- Corretion des données après utilisation du "ALTERNATE SQL" - DBA_FREE_SPACE non disponible
         FOR RC_CIBLE IN C_CIBLE LOOP

            -- Tentative de mise à jour (avec les données suivantes)
            UPDATE CD_DBA_DATA_FILES UDDF
               SET BYTES_FREE = NVL(
                                      (SELECT BYTES_FREE
                                         FROM CD_DBA_DATA_FILES
                                        WHERE NOM_CIBLE          = RC_CIBLE.NOM_CIBLE
                                          AND FILE_ID            = UDDF.FILE_ID
                                          AND DH_COLLECTE_DONNEE = (SELECT MIN(DH_COLLECTE_DONNEE)
                                                                      FROM CD_DBA_DATA_FILES
                                                                     WHERE NOM_CIBLE           = RC_CIBLE.NOM_CIBLE
                                                                       AND FILE_ID             = UDDF.FILE_ID
                                                                       AND DH_COLLECTE_DONNEE  > UDDF.DH_COLLECTE_DONNEE
                                                                       AND BYTES_FREE         != -1
                                                                   )
                                      )
                                      ,-1
                                   )
             WHERE NOM_CIBLE  = RC_CIBLE.NOM_CIBLE
               AND BYTES_FREE = -1;

            IF (SQL%ROWCOUNT > 0) THEN

               SDBM_UTIL.JOURNALISER('SDBM_COLLECTE.TRAITEMENT_FIN_COLLECTE_BD','INFO','CD_DBA_DATA_FILES.BYTES_FREE has been updated for target ' || RC_CIBLE.NOM_CIBLE || ' with next values.');

               -- Tentative de mise à jour (avec les données précédentes, le fichier existait mais à été supprimé depuis)
               UPDATE CD_DBA_DATA_FILES UDDF
                  SET BYTES_FREE = NVL(
                                         (SELECT BYTES_FREE
                                            FROM CD_DBA_DATA_FILES
                                           WHERE NOM_CIBLE          = RC_CIBLE.NOM_CIBLE
                                             AND FILE_ID            = UDDF.FILE_ID
                                             AND DH_COLLECTE_DONNEE = (SELECT MAX(DH_COLLECTE_DONNEE)
                                                                         FROM CD_DBA_DATA_FILES
                                                                        WHERE NOM_CIBLE            = RC_CIBLE.NOM_CIBLE
                                                                          AND FILE_ID              = UDDF.FILE_ID
                                                                          AND DH_COLLECTE_DONNEE   < UDDF.DH_COLLECTE_DONNEE
                                                                          AND BYTES_FREE          != -1
                                                                      )
                                         )
                                        ,-1
                                      )
                WHERE NOM_CIBLE  = RC_CIBLE.NOM_CIBLE
                  AND BYTES_FREE = -1;

               IF (SQL%ROWCOUNT > 0) THEN

                  SDBM_UTIL.JOURNALISER('SDBM_COLLECTE.TRAITEMENT_FIN_COLLECTE_BD','INFO','CD_DBA_DATA_FILES.BYTES_FREE has been updated for target ' || RC_CIBLE.NOM_CIBLE || ' with previous values.');

               END IF;

               -- Suppression des données qu'ont ne peut corrigées (nouveau fichiers créé à -1, qui n'existe plus)...
               DELETE FROM CD_DBA_DATA_FILES
                WHERE NOM_CIBLE  = RC_CIBLE.NOM_CIBLE
                  AND BYTES_FREE = -1;

               IF (SQL%ROWCOUNT > 0) THEN

                  SDBM_UTIL.JOURNALISER('SDBM_COLLECTE.TRAITEMENT_FIN_COLLECTE_BD','INFO','CD_DBA_DATA_FILES.BYTES_FREE has been deleted for target ' || RC_CIBLE.NOM_CIBLE || ' (no data available to fix the BYTES_FREE column).');

               END IF;

            END IF;

         END LOOP;

         DBMS_MVIEW.REFRESH('MV_INFO_VOLUME_FICHIER');
         DBMS_MVIEW.REFRESH('MV_INFO_VOLUME_UTILISATION');

      END IF;
   
      -- Fin de la transaction
      COMMIT;         

   END TRAITEMENT_FIN_COLLECTE_BD;


   /******************************************************************
     PROCEDURE : SAUVEGARDE_STATUT_COLLECTE_BD
     AUTEUR    : Benoit Bouthillier 2012-04-23 (2012-05-13)
    ------------------------------------------------------------------
     BUT : Cette procédure à pour but la sauvegarde de l'exécution
           d'un collecte.

     PARAMETRES:  Nom de la cible     (A_NOM_CIBLE)
                  Nom de l'événement  (A_NOM_EVENEMENT)
                  Statut d'exécution  (A_STATUT)
   ******************************************************************/

   PROCEDURE SAUVEGARDE_STATUT_COLLECTE_BD
   (
      A_NOM_CIBLE     IN EVENEMENT_CIBLE.NOM_CIBLE%TYPE     -- Nom de la cible
     ,A_NOM_EVENEMENT IN EVENEMENT_CIBLE.NOM_EVENEMENT%TYPE -- Nom de l'événement
     ,A_STATUT        IN VARCHAR2                           -- Statut d'exécution (UK : Clé unique, ER : Erreur, OK : Succès)
   )
   IS

      V_DH_PROCHAINE_VERIF DATE;

      -- Gestion des erreurs
      V_NB_ERREUR          EVENEMENT_CIBLE.NB_ERREUR%TYPE := 0;
      V_CD_NB_ESSAI        NUMBER;
      V_CD_MIN_ENTRE_ESSAI NUMBER;

   BEGIN

      -- Recherche de la date de prochaine exécution (situation régulière)
      SELECT SDBM_UTIL.INTERVAL_TO_DATE(INTERVAL_DEFAUT)
        INTO V_DH_PROCHAINE_VERIF
        FROM EVENEMENT
       WHERE TYPE_CIBLE      = 'BD'
         AND SOUS_TYPE_CIBLE = (SELECT SOUS_TYPE_CIBLE FROM CIBLE WHERE NOM_CIBLE = A_NOM_CIBLE)
         AND NOM_EVENEMENT   = A_NOM_EVENEMENT;

      IF (A_STATUT = 'ER') THEN

         -- Recherche du nombre d'erreur depuis le dernier succès
         SELECT NVL(NB_ERREUR,0)
           INTO V_NB_ERREUR
           FROM EVENEMENT_CIBLE
          WHERE TYPE_CIBLE      = 'BD'
            AND SOUS_TYPE_CIBLE = (SELECT SOUS_TYPE_CIBLE FROM CIBLE WHERE NOM_CIBLE = A_NOM_CIBLE)
            AND NOM_CIBLE       = A_NOM_CIBLE
            AND NOM_EVENEMENT   = A_NOM_EVENEMENT;

         BEGIN

            SELECT TO_NUMBER(VALEUR)
              INTO V_CD_NB_ESSAI
              FROM DEFAUT
             WHERE CLE = 'CD_NB_ESSAI';
 
         EXCEPTION

            WHEN OTHERS THEN
               SDBM_UTIL.JOURNALISER('SDBM_COLLECTE.SAUVEGARDE_STATUT_COLLECTE_BD','WARNING','The default value CD_NB_ESSAI was not found into DEFAUT table (a default value of 3 will be used).');
               V_CD_NB_ESSAI := 3;

         END;

         BEGIN

         SELECT TO_NUMBER(VALEUR)
           INTO V_CD_MIN_ENTRE_ESSAI
           FROM DEFAUT
          WHERE CLE = 'CD_MIN_ENTRE_ESSAI';
 
         EXCEPTION

            WHEN OTHERS THEN
               SDBM_UTIL.JOURNALISER('SDBM_COLLECTE.SAUVEGARDE_STATUT_COLLECTE_BD','WARNING','The default value CD_MIN_ENTRE_ESSAI was not found into DEFAUT table (a default value of 5 will be used).');
               V_CD_MIN_ENTRE_ESSAI := 5;

         END;


         --
         -- Calcul de la date de prochaine exécution (erreur)
         --

         IF (V_NB_ERREUR >= V_CD_NB_ESSAI) THEN

            -- Le nombre d'erreur est trop grand, l'evénement est cédulé comme s'il avait réussi (et le nombre d'erreur est remis à zéro)
            V_NB_ERREUR := 0;

            SDBM_UTIL.JOURNALISER('SDBM_COLLECTE.SAUVEGARDE_STATUT_COLLECTE_BD','WARNING','Too many errors occurred for event ' || A_NOM_EVENEMENT || ' (on target ' || A_NOM_CIBLE || '). The next attempt will take place based on the regular schedule.');

         ELSE

            -- Le nombre d'erreur n'est pas atteint, on calcul donc une nouvelle date de prochaine exécution qui ne doit pas être trop proche de la date régulière
            IF ((SYSDATE + ((V_CD_MIN_ENTRE_ESSAI * 2) / 1440)) < V_DH_PROCHAINE_VERIF) THEN

               V_DH_PROCHAINE_VERIF := (SYSDATE + (V_CD_MIN_ENTRE_ESSAI / 1440));
               V_NB_ERREUR := V_NB_ERREUR + 1;

               SDBM_UTIL.JOURNALISER('SDBM_COLLECTE.SAUVEGARDE_STATUT_COLLECTE_BD','WARNING','An errors occurred for event ' || A_NOM_EVENEMENT || ' (on target ' || A_NOM_CIBLE || '). The next attempt will take place in ' || V_CD_MIN_ENTRE_ESSAI || ' minute(s).');

            ELSE

               -- La date régulière est trop proche, on ne fait plus de tentatives supplémentaires
               V_NB_ERREUR := 0;

               SDBM_UTIL.JOURNALISER('SDBM_COLLECTE.SAUVEGARDE_STATUT_COLLECTE_BD','WARNING','An errors occurred for event ' || A_NOM_EVENEMENT || ' (on target ' || A_NOM_CIBLE || '). The next attempt will take place based on the regular schedule.');

            END IF;

         END IF;

      END IF;


      -- Mise à jour de l'interval de traitement
      UPDATE EVENEMENT_CIBLE EVC
         SET EVC.DH_PROCHAINE_VERIF = V_DH_PROCHAINE_VERIF
            ,NB_ERREUR              = V_NB_ERREUR
       WHERE EVC.TYPE_CIBLE      = 'BD'
         AND EVC.SOUS_TYPE_CIBLE = (SELECT SOUS_TYPE_CIBLE FROM CIBLE WHERE NOM_CIBLE = A_NOM_CIBLE)
         AND EVC.NOM_CIBLE       = A_NOM_CIBLE
         AND EVC.NOM_EVENEMENT   = A_NOM_EVENEMENT
         AND EVC.VERIFICATION    = 'AC';

      -- Fin de la transaction / par collecte
      COMMIT;         

   END SAUVEGARDE_STATUT_COLLECTE_BD;


   /******************************************************************
     PROCEDURE : TRAITEMENT_COLLECTE_BD
     AUTEUR    : Benoit Bouthillier 2012-04-23 (2012-05-25)
    ------------------------------------------------------------------
     BUT : Obtenir la liste des collectes enregistrées et actives
           contre une cible de type BD.

     PARAMETRES:  Nom de la cible  (A_NOM_CIBLE)
                  Curseur          (A_CUR_INFO)
   ******************************************************************/

   PROCEDURE TRAITEMENT_COLLECTE_BD
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
      OPEN VC_INFO FOR SELECT EVC.NOM_EVENEMENT                                               "NOM_EVENEMENT"
                             ,REPLACE(EVE.COMMANDE,'{NOM_CIBLE}','''' || A_NOM_CIBLE || '''') "COMMANDE"
                             ,DELAI_MAX_EXEC_SEC                                              "DELAI_MAX_EXEC_SEC"
                         FROM CIBLE           CIB
                             ,EVENEMENT_CIBLE EVC
                             ,EVENEMENT       EVE
                        WHERE EVE.TYPE_CIBLE          = EVC.TYPE_CIBLE
                          AND EVE.SOUS_TYPE_CIBLE     = EVC.SOUS_TYPE_CIBLE
                          AND EVE.NOM_EVENEMENT       = EVC.NOM_EVENEMENT
                          AND EVC.TYPE_CIBLE          = CIB.TYPE_CIBLE
                          AND EVC.NOM_CIBLE           = CIB.NOM_CIBLE
                          /* La cible doit être active et une connexion valide doit avoir été établie */
                          AND CIB.NOTIFICATION        = 'AC'
                          AND CIB.NOM_SERVEUR         IS NOT NULL
                          AND EVE.TYPE_EVENEMENT      = 'CD'
                          AND EVC.TYPE_CIBLE          = 'BD'
                          AND EVC.VERIFICATION        = 'AC'
                          AND EVC.DH_PROCHAINE_VERIF <= SYSDATE
                          /* Retrait des événements CD_ESPACE_ARCHIVED_LOG, CD_FILESTAT et CD_SYSSTAT_CPU pour les bases de données RAC */
                          AND (CIB.TYPE_BD != 'RD' OR EVC.NOM_EVENEMENT NOT IN ('CD_ESPACE_ARCHIVED_LOG','CD_FILESTAT','CD_SYSSTAT_CPU'))
                          AND EVC.NOM_CIBLE           = A_NOM_CIBLE
                        ORDER BY EVC.DH_PROCHAINE_VERIF;

 
      -- Assignation de retour
      A_CUR_INFO := VC_INFO;

   END TRAITEMENT_COLLECTE_BD;


   /******************************************************************
     PROCEDURE : TRAITEMENT_CIBLES_BD
     AUTEUR    : Benoit Bouthillier 2012-04-23 (2012-05-25)
    ------------------------------------------------------------------
     BUT : Obtenir la liste des cibles enregistrées et actives.

     PARAMETRES:  Curseur  (A_CUR_INFO)
   ******************************************************************/

   PROCEDURE TRAITEMENT_CIBLES_BD
   (
      A_VERSION_SERVEUR         IN  VARCHAR2 DEFAULT 'N/D'
     ,A_CUR_INFO                OUT T_RC_INFO
     ,A_DELAI_MAX_CONNEXION_SEC OUT PARAMETRE.DELAI_MAX_CONNEXION_SEC%TYPE
     ,A_NIVEAU_JOURNAL_SERVEUR  OUT PARAMETRE.NIVEAU_JOURNAL_SERVEUR%TYPE
   )
   IS

      -- Curseur dynamique de retour d'information
      VC_INFO T_RC_INFO;

   BEGIN
  
      DBMS_APPLICATION_INFO.SET_MODULE(MODULE_NAME => 'SDBMDAC - SCHEMA : ' || SDBM_APEX_UTIL.INFOSCHEMA
                                      ,ACTION_NAME => TO_CHAR(SYSDATE,'YYYY/MM/DD:HH24:MI:SS')
                                      );
      DBMS_APPLICATION_INFO.SET_CLIENT_INFO('SDBMDAC version ' || A_VERSION_SERVEUR || ' running on ' || NVL(SYS_CONTEXT('USERENV','HOST'),'N/A'));

      -- Ouverture du curseur de recherche
      OPEN VC_INFO FOR SELECT DISTINCT
                              CIB.NOM_CIBLE                                               "NOM_CIBLE"
                             ,CIB.SOUS_TYPE_CIBLE                                         "SOUS_TYPE_CIBLE"
                             ,CIB.NOM_USAGER                                              "NOM_USAGER"
                             ,SDBM_UTIL.DECRYPTER_MDP_CIBLE(CIB.NOM_CIBLE,CIB.MDP_USAGER) "MOT_PASSE"
                             ,TYPE_CONNEXION                                              "TYPE_CONNEXION"
                             ,CIB.CONNEXION                                               "CONNEXION"
                         FROM CIBLE           CIB
                             ,EVENEMENT_CIBLE EVC
                             ,EVENEMENT       EVE
                             ,PARAMETRE       PAR
                        WHERE EVE.TYPE_CIBLE          = EVC.TYPE_CIBLE
                          AND EVE.SOUS_TYPE_CIBLE     = EVC.SOUS_TYPE_CIBLE
                          AND EVE.NOM_EVENEMENT       = EVC.NOM_EVENEMENT
                          AND EVC.TYPE_CIBLE          = CIB.TYPE_CIBLE
                          AND EVC.NOM_CIBLE           = CIB.NOM_CIBLE
                          /* La cible doit être active et une connexion valide doit avoir été établie */
                          AND CIB.NOTIFICATION        = 'AC'
                          AND CIB.NOM_SERVEUR         IS NOT NULL
                          AND EVE.TYPE_EVENEMENT      = 'CD'
                          AND EVC.TYPE_CIBLE          = 'BD'
                          AND EVC.VERIFICATION        = 'AC'
                          AND EVC.DH_PROCHAINE_VERIF <= SYSDATE
                          /* Retrait des événements CD_ESPACE_ARCHIVED_LOG, CD_FILESTAT et CD_SYSSTAT_CPU pour les bases de données RAC */
                          AND (CIB.TYPE_BD != 'RD' OR EVC.NOM_EVENEMENT NOT IN ('CD_ESPACE_ARCHIVED_LOG','CD_FILESTAT','CD_SYSSTAT_CPU'))
                          AND PAR.STATUT_COLLECTE     = 'AC'
                        ORDER BY CIB.NOM_CIBLE;
 
      -- Assignation de retour
      A_CUR_INFO := VC_INFO;
      
      -- Envoi du pilotage au serveur
      SELECT DELAI_MAX_CONNEXION_SEC
            ,NIVEAU_JOURNAL_SERVEUR
        INTO A_DELAI_MAX_CONNEXION_SEC
            ,A_NIVEAU_JOURNAL_SERVEUR
        FROM PARAMETRE;
   
   END TRAITEMENT_CIBLES_BD;


END SDBM_COLLECTE;
/
