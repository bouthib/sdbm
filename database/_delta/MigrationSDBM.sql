-- *
-- * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
-- * Licensed under the MIT license.
-- * See LICENSE file in the project root for full license information.
-- *


#
# A partir du nouveau serveur
#
su -

systemctl stop sdbmagt
systemctl stop sdbmdac
systemctl stop sdbmsrv


su - oracle

sqlplus / as sysdba
alter session set container = XEPDB1;
alter user sdbm account unlock;
exit


#
# Avec SDBM (nouvelle BD)
#
export TWO_TASK=localhost:1521/xepdb1
sqlplus sdbm/admin

--
-- Retrait de toutes les constaintes et suppression des données
--
DECLARE

   CURSOR C_FK IS
      SELECT TABLE_NAME
            ,CONSTRAINT_NAME
        FROM USER_CONSTRAINTS
       WHERE CONSTRAINT_TYPE = 'R'
         AND STATUS = 'ENABLED';

   CURSOR C_TABLE IS
      SELECT TABLE_NAME
        FROM USER_TABLES;

   CURSOR C_SEQUENCE IS
      SELECT SEQUENCE_NAME
        FROM USER_SEQUENCES;
       
   CURSOR C_JOB IS
      SELECT JOB
        FROM USER_JOBS;

BEGIN

   -- Retrait des constraintes
   FOR RC_FK IN C_FK LOOP
      EXECUTE IMMEDIATE 'ALTER TABLE ' || RC_FK.TABLE_NAME || ' DISABLE CONSTRAINT ' || RC_FK.CONSTRAINT_NAME;
   END LOOP;
   
   FOR RC_TABLE IN C_TABLE LOOP
      EXECUTE IMMEDIATE 'ALTER TABLE ' || RC_TABLE.TABLE_NAME || ' DISABLE ALL TRIGGERS';
   END LOOP;

   -- Suppression des données
   FOR RC_TABLE IN C_TABLE LOOP
      EXECUTE IMMEDIATE 'TRUNCATE TABLE ' || RC_TABLE.TABLE_NAME || ' DROP STORAGE';
   END LOOP;

   FOR RC_SEQUENCE IN C_SEQUENCE LOOP
      EXECUTE IMMEDIATE 'DROP SEQUENCE ' || RC_SEQUENCE.SEQUENCE_NAME;
   END LOOP;

   FOR RC_JOB IN C_JOB LOOP
      DBMS_JOB.REMOVE(RC_JOB.JOB);
   END LOOP;
   COMMIT;

END;
/


#
# A partir de l'ancien serveur
#
su - oracle

# *** Avant export, détruire les tables de "backups" s'il y a lieu pour éviter les erreurs à l'import ***
cd /tmp
export NLS_LANG=AMERICAN_AMERICA.WE8MSWIN1252
exp SDBM/admin file=sdbm.transfert.dmp log=exp-sdbm.transfert.log consistent=Y direct=Y statistics=NONE


#
# A partir du nouveau serveur
#

# Obtenir /tmp/sdbm.transfert.dmp de l'ancien serveur

su - oracle
cd /tmp
export TWO_TASK=localhost:1521/xepdb1
export NLS_LANG=AMERICAN_AMERICA.AL32UTF8


sqlplus SDBM/admin

RENAME HIST_EVENEMENT_CIBLE_AGT TO HIST_EVENEMENT_CIBLE_AGT_TMP;
CREATE VIEW HIST_EVENEMENT_CIBLE_AGT AS SELECT * FROM HIST_EVENEMENT_CIBLE_AGT_TMP;

CREATE OR REPLACE TRIGGER SDBM.HECA_SUBSTR_TEXTE

/******************************************************************
  TRIGGER : HECA_SUBSTR_TEXTE
  AUTEUR  : Benoit Bouthillier
 ------------------------------------------------------------------
  BUT : Garantir que le champ TEXTE ne dépassera pas 4000 bytes.

*******************************************************************/

   INSTEAD OF INSERT 
   ON HIST_EVENEMENT_CIBLE_AGT
   FOR EACH ROW

BEGIN

   INSERT INTO HIST_EVENEMENT_CIBLE_AGT_TMP
   (
      DH_HIST_EVENEMENT
     ,TYPE_CIBLE
     ,NOM_CIBLE
     ,NOM_EVENEMENT
     ,TEXTE
     ,STATUT
   )
   VALUES
   (
      :NEW.DH_HIST_EVENEMENT
     ,:NEW.TYPE_CIBLE
     ,:NEW.NOM_CIBLE
     ,:NEW.NOM_EVENEMENT
     ,SUBSTRB(:NEW.TEXTE,1,4000)
     ,:NEW.STATUT
    );

END HECA_SUBSTR_TEXTE;
/
exit

imp SDBM/admin file=sdbm.transfert.dmp log=imp-sdbm.transfert.log constraints=N grants=N ignore=Y


#
# Avec SDBM (nouvelle BD)
#
sqlplus sdbm/admin

DROP VIEW HIST_EVENEMENT_CIBLE_AGT;
RENAME HIST_EVENEMENT_CIBLE_AGT_TMP TO HIST_EVENEMENT_CIBLE_AGT;

-- Correction des chemins (/usr/lib/oracle vers /opt/oracle)
UPDATE SDBM.VOLUME_PHY
   SET DESC_VOLUME_PHY     = REPLACE(DESC_VOLUME_PHY,'/usr','/opt')
      ,TOTAL_MB            = 10240
      ,CHEMIN_ACCES_DEFAUT = '/opt/oracle'
 WHERE DESC_VOLUME_PHY LIKE 'SDBM%';

UPDATE SDBM.VOLUME_PHY_CIBLE
   SET CHEMIN_ACCES = '/opt/oracle'
 WHERE NOM_CIBLE = 'SDBM';

-- Correction du nom de l'agent d'exécution
UPDATE SDBM.TACHE_DET_MSG_AGT
   SET NOM_SERVEUR = UPPER(SYS_CONTEXT('USERENV','SERVER_HOST'))
 WHERE (NOM_SERVEUR,NOM_TACHE) IN (SELECT NOM_SERVEUR, NOM_TACHE FROM SDBM.TACHE_AGT WHERE NOM_TACHE LIKE 'BACKUP______SDBM');

UPDATE SDBM.HIST_TACHE_AGT
   SET NOM_SERVEUR = UPPER(SYS_CONTEXT('USERENV','SERVER_HOST'))
 WHERE (NOM_SERVEUR,NOM_TACHE) IN (SELECT NOM_SERVEUR, NOM_TACHE FROM SDBM.TACHE_AGT WHERE NOM_TACHE LIKE 'BACKUP______SDBM');

UPDATE SDBM.TACHE_AGT
   SET NOM_SERVEUR = UPPER(SYS_CONTEXT('USERENV','SERVER_HOST'))
      ,REPERTOIRE  = '/opt/sdbm'
 WHERE NOM_TACHE LIKE 'BACKUP______SDBM';

COMMIT;
exit


--
-- Correction des mots de passe - UTF8 + mise à jour à DBMS_CRYPTO
--

-- Via SYS
export TWO_TASK=

sqlplus / as sysdba
alter session set container = XEPDB1;

ALTER SYSTEM FLUSH SHARED_POOL;
BEGIN
   DBMS_RESULT_CACHE.FLUSH;
END;
/
exit


-- Via SDBM
cd /staging/sdbm-sql
export TWO_TASK=localhost:1521/xepdb1
export NLS_LANG=AMERICAN_AMERICA.AL32UTF8

sqlplus SDBM/admin
@ps-conv_mdp_usager_temp.sql
@pb-conv_mdp_usager_temp.sql
DROP TRIGGER USA_TR_BIU_USAGER;
ALTER TRIGGER USA_TR_BIU_MOT_PASSE DISABLE;
ALTER TRIGGER CIB_TR_BIU_MOT_PASSE DISABLE;
ALTER TRIGGER PAR_TR_BIU_MOT_PASSE DISABLE;

UPDATE USAGER
   SET MOT_PASSE = SDBM_APEX_UTIL.ENCRYPTER_MDP_USAGER(NOM_USAGER
                                                      ,CONV_MDP_USAGER_TEMP.DECRYPTER_MDP_USAGER(NOM_USAGER
                                                                                                ,CONVERT(MOT_PASSE,'WE8MSWIN1252')
                                                                                                )
                                                      );

UPDATE CIBLE
   SET MDP_USAGER = SDBM_UTIL.ENCRYPTER_MDP_CIBLE(NOM_CIBLE
                                                 ,CONV_MDP_USAGER_TEMP.DECRYPTER_MDP_CIBLE(NOM_CIBLE
                                                                                          ,CONVERT(MDP_USAGER,'WE8MSWIN1252')
                                                                                          )
                                                 );

UPDATE PARAMETRE
   SET MDP_USAGER_SMTP = SDBM_UTIL.ENCRYPTER_MDP_SMTP(NOM_USAGER_SMTP
                                                     ,CONV_MDP_USAGER_TEMP.DECRYPTER_MDP_SMTP(NOM_USAGER_SMTP
                                                                                             ,CONVERT(MDP_USAGER_SMTP,'WE8MSWIN1252')
                                                                                             )
                                                     )
 WHERE NOM_USAGER_SMTP IS NOT NULL;

ALTER TRIGGER USA_TR_BIU_MOT_PASSE ENABLE;
ALTER TRIGGER CIB_TR_BIU_MOT_PASSE ENABLE;
ALTER TRIGGER PAR_TR_BIU_MOT_PASSE ENABLE;
drop package CONV_MDP_USAGER_TEMP;



--
-- Activation des triggers et contraintes
--
DECLARE

   CURSOR C_FK IS
      SELECT TABLE_NAME
            ,CONSTRAINT_NAME
        FROM USER_CONSTRAINTS
       WHERE CONSTRAINT_TYPE = 'R'
         AND STATUS = 'DISABLED';

   CURSOR C_TRIGGER IS
      SELECT TRIGGER_NAME
        FROM USER_TRIGGERS
       WHERE STATUS = 'DISABLED';

BEGIN

   -- Activation des constraintes
   FOR RC_FK IN C_FK LOOP
      EXECUTE IMMEDIATE 'ALTER TABLE ' || RC_FK.TABLE_NAME || ' ENABLE CONSTRAINT ' || RC_FK.CONSTRAINT_NAME;
   END LOOP;
   
   FOR RC_TRIGGER IN C_TRIGGER LOOP
      EXECUTE IMMEDIATE 'ALTER TRIGGER ' || RC_TRIGGER.TRIGGER_NAME || ' ENABLE';
   END LOOP;

END;
/

DROP PROCEDURE UNICENTER_INTERFACE;
DROP FUNCTION EXT_UNICENTER_INTERFACE;

exit


-- Via SYS
export TWO_TASK=

sqlplus / as sysdba
alter session set container = XEPDB1;

alter user SDBM account lock;

@?/rdbms/admin/utlrp
SELECT OWNER, STATUS, COUNT(1) FROM DBA_OBJECTS WHERE STATUS != 'VALID' GROUP BY OWNER, STATUS;

exit
exit


#
# Correction de la cible SDBM - via l'interface graphique
#
(DESCRIPTION =
   (ADDRESS_LIST =
      (ADDRESS =
         (PROTOCOL = TCP)
         (HOST     = localhost)
         (PORT     = 1521)
      )
   )
   (CONNECT_DATA =
      (SERVICE_NAME = XEPDB1)
      (SERVER       = DEDICATED)
   )
)


#
# A partir du nouveau serveur
#
su -

systemctl start sdbmagt
systemctl start sdbmdac
systemctl start sdbmsrv
