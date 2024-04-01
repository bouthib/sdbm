-- *
-- * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
-- * Licensed under the MIT license.
-- * See LICENSE file in the project root for full license information.
-- *



---------------------------------------------
---------------------------------------------
---------------------------------------------
--  V E R S I O N   0 . 2 9  -   B e t a   --
---------------------------------------------
---------------------------------------------

#
# Update Linux
#
yum update
reboot

- Modification de /boot/grub/grub.conf

yum remove kernel-2.6.18-274.12*
yum remove kernel-devel-2.6.18-274.12*


#
# Installation Apache
#

# Obtenir httpd-2.2.22.tar.gz et le placer sous /tmp
cd /tmp
gunzip httpd-2.2.22.tar.gz
tar -xvf httpd-2.2.22.tar
rm -f httpd-2.2.22.tar

cd /tmp/httpd-2.2.22
./configure --enable-cache --enable-proxy --enable-ssl --enable-setenvif
make
make install

cd /tmp
rm -Rf httpd-2.2.22


- Upgrade APEX 4.1.1.txt


- Modification de /etc/init.d/update-ip.sh
- Modification de /etc/init.d/network (/etc/init.d/update-ip.sh) ou rm network.rpmsave



/*

   OUVRIR MODIFICATION.SQL (POUR RÉPEROIRE COURRANT)

*/

/*

   VÉRIFIER POUR TÂCHE EN COURS

*/

ALTER USER SDBMAGT ACCOUNT LOCK;

/*

   KILL

*/


ALTER SESSION SET CURRENT_SCHEMA = SDBM;


DROP INDEX HTA_IE_NOM_SERVEUR_NOM_TACHE;

ALTER TABLE HIST_TACHE_AGT
   DROP CONSTRAINT HTA_CHK_STATUT_EXEC;

ALTER TABLE HIST_TACHE_AGT
   DROP CONSTRAINT HTA_CHK_STATUT_NOTIF_AVER;

ALTER TABLE HIST_TACHE_AGT
   DROP CONSTRAINT HTA_CHK_STATUT_NOTIF_EXEC;

ALTER TABLE HIST_TACHE_AGT
   DROP CONSTRAINT HTA_PK_HIST_TACHE_AGT;

ALTER TABLE HIST_TACHE_AGT
   DROP CONSTRAINT HTA_FK_TACHE_AGT;


ALTER TABLE HIST_TACHE_AGT RENAME TO HIST_TACHE_AGT_029;

CREATE TABLE HIST_TACHE_AGT
(
   ID_SOUMISSION          NUMBER(10)                          NOT NULL
  ,NOM_SERVEUR            VARCHAR2(64)                        NOT NULL
  ,NOM_TACHE              VARCHAR2(50)                        NOT NULL
  ,FICHIER_JOURNAL        VARCHAR2(256)
  ,STATUT_EXEC            CHAR(2)                             NOT NULL
  ,STATUT_NOTIF_AVER      CHAR(2)         DEFAULT 'NO'        NOT NULL
  ,STATUT_NOTIF_EXEC      CHAR(2)         DEFAULT 'NO'        NOT NULL
  ,STATUT_NOTIF_EXEC_OPT  CHAR(2)         DEFAULT 'NO'        NOT NULL
  ,DH_SOUMISSION          DATE                                NOT NULL
  ,DH_DEBUT               DATE
  ,DH_FIN                 DATE
  ,CODE_RETOUR            NUMBER
  ,JOURNAL                CLOB
  ,EVALUATION             VARCHAR2(512)
)
LOB (JOURNAL) STORE AS (DISABLE STORAGE IN ROW)
TABLESPACE SDBM_DATA
MONITORING;


INSERT INTO HIST_TACHE_AGT
(
   ID_SOUMISSION
  ,NOM_SERVEUR
  ,NOM_TACHE
  ,FICHIER_JOURNAL
  ,STATUT_EXEC
  ,STATUT_NOTIF_AVER
  ,STATUT_NOTIF_EXEC
  ,DH_SOUMISSION
  ,DH_DEBUT
  ,DH_FIN
  ,CODE_RETOUR
  ,JOURNAL
  ,EVALUATION
)
SELECT *
  FROM HIST_TACHE_AGT_029;

DROP TABLE HIST_TACHE_AGT_029 PURGE;


ALTER TABLE HIST_TACHE_AGT
   ADD CONSTRAINT HTA_CHK_STATUT_EXEC
      CHECK (STATUT_EXEC IN (/* Soumission */ 'SB',/* Soumission reçu */ 'SR',/* Erreur à la soumission */ 'SF',/* Exécution */ 'EX',/* Incomplet */ 'NC',/* Évaluation */ 'EV',/* Fin en erreur */ 'ER',/* Fin avec succès */ 'OK'));

ALTER TABLE HIST_TACHE_AGT
   ADD CONSTRAINT HTA_CHK_STATUT_NOTIF_AVER
      CHECK (STATUT_NOTIF_AVER IN (/* Normal */ 'NO',/* À notifier */ 'AE',/* Final */ 'OK'));

ALTER TABLE HIST_TACHE_AGT
   ADD CONSTRAINT HTA_CHK_STATUT_NOTIF_EXEC
      CHECK (STATUT_NOTIF_EXEC IN (/* Normal */ 'NO',/* À notifier */ 'AE',/* Final */ 'OK'));

ALTER TABLE HIST_TACHE_AGT
   ADD CONSTRAINT HTA_CHK_STATUT_NOTIF_EXEC_OPT
      CHECK (STATUT_NOTIF_EXEC_OPT IN (/* Normal */ 'NO',/* À notifier */ 'AE',/* Final */ 'OK'));


CREATE INDEX HTA_IE_NOM_SERVEUR_NOM_TACHE ON HIST_TACHE_AGT (NOM_SERVEUR, NOM_TACHE)
   TABLESPACE SDBM_DATA;

ALTER TABLE HIST_TACHE_AGT
   ADD CONSTRAINT HTA_PK_HIST_TACHE_AGT PRIMARY KEY (ID_SOUMISSION)
      USING INDEX
      TABLESPACE SDBM_DATA;

ALTER TABLE HIST_TACHE_AGT
   ADD CONSTRAINT HTA_FK_TACHE_AGT
       FOREIGN KEY (NOM_SERVEUR, NOM_TACHE) REFERENCES TACHE_AGT
       ON DELETE CASCADE;

GRANT SELECT ON HIST_TACHE_AGT TO SDBMON;


@../_package/pb-sdbm_agent.sql
@../_package/pb-sdbm_util.sql

@../_package/ps-sdbm_audit_appl.sql
@../_package/pb-sdbm_audit_appl.sql

@e-sdbm_audit.sql


ALTER FUNCTION          SDBM_APEX_AUTHENTIFICATION  COMPILE;
ALTER FUNCTION          SDBM_APEX_VERSION           COMPILE;
ALTER TRIGGER           USA_TR_BIU_USAGER           COMPILE;
ALTER MATERIALIZED VIEW MV_INFO_VOLUME_FICHIER      COMPILE;
ALTER MATERIALIZED VIEW MV_INFO_VOLUME_UTILISATION  COMPILE;


ALTER USER SDBMAGT ACCOUNT UNLOCK;


ALTER TABLE CIBLE
   DROP CONSTRAINT CIB_CHK_SOUS_TYPE_CIBLE;

ALTER TABLE CIBLE
   ADD CONSTRAINT CIB_CHK_SOUS_TYPE_CIBLE
      CHECK (SOUS_TYPE_CIBLE IN (/* Oracle */ 'OR', /* Microsoft SQL */ 'MS', /* MySQL */ 'MY'));


ALTER TABLE EVENEMENT
   DROP CONSTRAINT EVE_CHK_SOUS_TYPE_CIBLE;

ALTER TABLE EVENEMENT
   ADD CONSTRAINT EVE_CHK_SOUS_TYPE_CIBLE
      CHECK (SOUS_TYPE_CIBLE IN (/* Oracle */ 'OR', /* Microsoft SQL */ 'MS', /* MySQL */ 'MY'));


ALTER TABLE DESTI_NOTIF_SURCHARGE_MESSAGE
   DROP CONSTRAINT DNSM_CHK_SOUS_TYPE_CIBLE;

ALTER TABLE DESTI_NOTIF_SURCHARGE_MESSAGE
   ADD CONSTRAINT DNSM_CHK_SOUS_TYPE_CIBLE
      CHECK (SOUS_TYPE_CIBLE IN (/* Oracle */ 'OR', /* Microsoft SQL */ 'MS', /* MySQL */ 'MY'));


ALTER TABLE EVENEMENT_CIBLE
   DROP CONSTRAINT EVC_CHK_SOUS_TYPE_CIBLE;

ALTER TABLE EVENEMENT_CIBLE
   ADD CONSTRAINT EVC_CHK_SOUS_TYPE_CIBLE
      CHECK (SOUS_TYPE_CIBLE IN (/* Oracle */ 'OR', /* Microsoft SQL */ 'MS', /* MySQL */ 'MY'));


ALTER TABLE REPARATION
   DROP CONSTRAINT REP_CHK_SOUS_TYPE_CIBLE;

ALTER TABLE REPARATION
   ADD CONSTRAINT REP_CHK_SOUS_TYPE_CIBLE
      CHECK (SOUS_TYPE_CIBLE IN (/* Oracle */ 'OR', /* Microsoft SQL */ 'MS', /* MySQL */ 'MY'));


ALTER TABLE REPARATION_EVEN_CIBLE
   DROP CONSTRAINT REC_CHK_SOUS_TYPE_CIBLE;

ALTER TABLE REPARATION_EVEN_CIBLE
   ADD CONSTRAINT REC_CHK_SOUS_TYPE_CIBLE
      CHECK (SOUS_TYPE_CIBLE IN (/* Oracle */ 'OR', /* Microsoft SQL */ 'MS', /* MySQL */ 'MY'));


INSERT INTO DEFAUT
(
   CLE
  ,VALEUR
)
VALUES
(
   'CONNEXION_MY'
  ,'//{adresse IP}:{port IP}'
);


INSERT INTO SDBM.EVENEMENT
(
   TYPE_CIBLE
  ,SOUS_TYPE_CIBLE
  ,NOM_EVENEMENT
  ,TYPE_EVENEMENT
  ,COMMANDE
  ,INTERVAL_DEFAUT
  ,DESTI_NOTIF_DEFAUT
  ,DELAI_MAX_EXEC_SEC
)
VALUES
(
   'BD'
  ,'MY'
  ,'ALERT'
  ,'AG'
  ,'N/A'
  ,'N/A'
  ,'---'
  ,30
);


sqlplus "/ as sysdba"

EXECUTE DBMS_EPG.SET_DAD_ATTRIBUTE(DAD_NAME => 'SDBM', ATTR_NAME => 'nls-language',      ATTR_VALUE => 'AMERICAN_AMERICA.AL32UTF8');
EXECUTE APEX_INSTANCE_ADMIN.ENABLE_WORKSPACE('SDBM');
COMMIT;

PURGE DBA_RECYCLEBIN;
@?/rdbms/admin/utlrp
SELECT COUNT(1) FROM DBA_OBJECTS WHERE STATUS != 'VALID';

exit


SDBMSrv version = "0.10 - Beta"; + jdbc
SDBMAgt version = "0.17 - Beta"; + sigar


ALTER SESSION SET CURRENT_SCHEMA = SDBM;

ALTER TABLE CIBLE
   ADD (COMMENTAIRE VARCHAR2(4000));

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
                  ,COMMENTAIRE                                                                                                "COMMENTAIRE"
              FROM CIBLE
                  ,PARAMETRE
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

@../_package/pb-sdbm_audit_appl.sql
@../e-sdbm_audit.sql

SET SERVEROUTPUT ON
DECLARE

   CURSOR C_INVALID_OBJ IS
      SELECT 'ALTER ' || DECODE(OBJECT_TYPE,'PACKAGE BODY','PACKAGE ',OBJECT_TYPE || ' ') || OWNER || '.' || OBJECT_NAME || ' COMPILE' || DECODE(OBJECT_TYPE,'PACKAGE BODY',' BODY','') CMD
        FROM DBA_OBJECTS
       WHERE STATUS != 'VALID'
         AND OWNER   = 'SDBM';

BEGIN

   FOR RC_INVALID_OBJ IN C_INVALID_OBJ LOOP
      BEGIN
         EXECUTE IMMEDIATE RC_INVALID_OBJ.CMD;
         DBMS_OUTPUT.PUT_LINE('OK     : ' || RC_INVALID_OBJ.CMD);
      EXCEPTION
         WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('FAILED : ' || RC_INVALID_OBJ.CMD);
      END;
   END LOOP;

END;
/


#
# Mise à jour Apex à 0.29a
#
