-- *
-- * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
-- * Licensed under the MIT license.
-- * See LICENSE file in the project root for full license information.
-- *



---------------------------------------------
---------------------------------------------
---------------------------------------------
--  V E R S I O N   0 . 2 2  -   B e t a   --
---------------------------------------------
---------------------------------------------


#
# Mise à jour APEX de 3.2 à 3.2.1
#
voir _Installation OS & Oracle XE\Upgrade APEX 3.2.1.txt



#
# Modification du Firewall Linux (iptables)
#

vi /etc/sysconfig/iptables

# Ajout des lignes suivantes
---
-A RH-Firewall-1-INPUT -m state --state NEW -m tcp -p tcp --dport 8080 -j ACCEPT
---

service iptables restart



#
# SDBMSrv
#

- Nouvelle compilation : SDBMSrv version = "0.05 - Beta";


#
# SDBMAgt
#

- Nouvelle version : SDBMAgt version = "0.11 - Beta";

- Nouveau environnement de service Windows

   -> Retrait de JavaSignalHandler.exe
   -> Nouvelle version de JavaVM.exe
   -> Nouvelle version de SDBMAgt.exe
   -> Nouvelle version de WinUtils.dll
   -> Faire un SDBMAgt.exe -UNINSTALL + InsstallSDBMAgt.cmd
   


#
# Nouveau APEX 0.22
#
UPDATE SDBM.PARAMETRE
   SET ADRESSE_PROXY_HTTP = '{BROWSER_ADDR}';



#
# SCHEMA 0.22
#
ALTER TABLE SDBM.HIST_TACHE_AGT
   MODIFY FICHIER_JOURNAL NULL;

ALTER TABLE SDBM.CIBLE
   ADD 
   (
      TYPE_BD              CHAR(2)         DEFAULT 'NI'     NOT NULL
     ,TYPE_CIBLE_REF       CHAR(2)
     ,NOM_CIBLE_REF        VARCHAR2(30)
   );

CREATE INDEX SDBM.CIB_FK_CIBLE_REF ON SDBM.CIBLE (TYPE_CIBLE_REF, NOM_CIBLE_REF)
   TABLESPACE SDBM_DATA;

ALTER TABLE SDBM.CIBLE
   ADD CONSTRAINT CIB_CHK_TYPE_BD
      CHECK (TYPE_BD IN (/* Instance standard */ 'NI',/* Instance ASM */ 'AI',/* Instance RAC */ 'RI',/* Base de données RAC */ 'RD'));

ALTER TABLE SDBM.CIBLE
   ADD CONSTRAINT CIB_FK_CIBLE
       FOREIGN KEY (TYPE_CIBLE_REF, NOM_CIBLE_REF) REFERENCES SDBM.CIBLE (TYPE_CIBLE, NOM_CIBLE);



CREATE OR REPLACE VIEW SDBM.APEX_CIBLE_BD
AS 
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
     FROM (
            SELECT NOM_CIBLE                                                                                                  "NOM_CIBLE"
                  ,DECODE(TYPE_BD
                         ,'NI','Instance Standard'
                         ,'AI','Instance ASM'
                         ,'RI','Instance RAC (' || NOM_CIBLE_REF || ')'
                         ,'RD','Base de données RAC'
                         )                                                                                                    "TYPE"
                  ,DECODE(INSTR(NOM_SERVEUR,'.')
                         ,0,UPPER(NOM_SERVEUR)
                         ,UPPER(SUBSTR(NOM_SERVEUR,1,INSTR(NOM_SERVEUR,'.')-1))
                         )                                                                                                    "NOM_SERVEUR"
                  ,(SELECT NOM_OS
                      FROM INFO_AGT
                     WHERE NOM_SERVEUR = UPPER(CIBLE.NOM_SERVEUR)
                   )                                                                                                          "INFORMATION_OS"
                  ,DECODE(SOUS_TYPE_CIBLE
                         ,'OR','Oracle'
                         ,'MS','SQLServer'
                         ,SOUS_TYPE_CIBLE
                         )                                                                                                    "SGBD"
                  ,DECODE(VERSION
                         ,TO_CHAR(NULL),'N/D'
                         ,SUBSTR(VERSION,INSTR(VERSION,':')+2)
                         )                                                                                                    "VERSION"
                  ,DECODE(STATUT
                         ,'UP','Disponible'
                         ,'DN','Non-disponible'
                         ,'Inconnu'
                         )                                                                                                    "STATUT_AFF"
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
                  ,DECODE(NOTIFICATION
                         ,'AC','Actif'
                         ,'IN','Inactif'
                         )                                                                                                    "NOTIFICATION_AFF"
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
                              'CD_DBA_DATA_FILES'
                             ,'CD_ESPACE_ARCHIVED_LOG'
                             ,'CD_FILESTAT'
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
              FROM CIBLE
             WHERE TYPE_CIBLE = 'BD'
          );


CREATE OR REPLACE TRIGGER SDBM.APEX_CIBLE_BD_TRIOU_CIBLE
   INSTEAD OF UPDATE ON SDBM.APEX_CIBLE_BD

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


UPDATE SDBM.EVENEMENT
   SET COMMANDE =
'
SELECT TRUNC(SYSDATE,''HH24'') - 1/24 "DH_COLLECTE_DONNEE"
      ,{NOM_CIBLE}                  "NOM_CIBLE"
      ,NVL(
             (SELECT SUM(BLOCKS * BLOCK_SIZE)
                FROM V$ARCHIVED_LOG@{DB_LINK}
                    ,V$INSTANCE@{DB_LINK}
               WHERE COMPLETION_TIME BETWEEN TRUNC(SYSDATE,''HH24'') - 1/24
                                         AND TRUNC(SYSDATE,''HH24'') - 1/86400
                 AND V$ARCHIVED_LOG.THREAD# = V$INSTANCE.THREAD# 
                 AND DEST_ID = (SELECT MIN(DEST_ID) FROM V$ARCHIVED_LOG@{DB_LINK}
                                 WHERE COMPLETION_TIME BETWEEN TRUNC(SYSDATE,''HH24'') - 1/24
                                                           AND TRUNC(SYSDATE,''HH24'') - 1/86400
                                   AND THREAD# = V$INSTANCE.THREAD#
                               )
             )
            ,0
          )
       "ESPACE"
  FROM DUAL
 WHERE NOT EXISTS (SELECT 1
                     FROM CD_ESPACE_ARCHIVED_LOG
                    WHERE DH_COLLECTE_DONNEE = TRUNC(SYSDATE,''HH24'') - 1/24
                      AND NOM_CIBLE          = {NOM_CIBLE}
                  )
'
WHERE TYPE_CIBLE      = 'BD'
  AND SOUS_TYPE_CIBLE = 'OR'
  AND NOM_EVENEMENT   = 'CD_ESPACE_ARCHIVED_LOG';


@../_package/ps-sdbm_apex_util.sql
@../_package/pb-sdbm_apex_util.sql
@../_package/pb-sdbm_collecte.sql
@../_package/pb-sdbm_agent.sql
