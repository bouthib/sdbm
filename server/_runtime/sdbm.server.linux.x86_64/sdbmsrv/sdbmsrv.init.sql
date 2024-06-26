set echo     off
set feedback off
set termout  off


spool /opt/sdbm/sdbmsrv/sdbmsrv.init.log
connect / as sysdba
alter session set container = XEPDB1;

INSERT INTO SDBM.CIBLE
(
   TYPE_CIBLE
  ,SOUS_TYPE_CIBLE
  ,NOM_CIBLE
  ,NOM_USAGER
  ,MDP_USAGER
  ,TYPE_CONNEXION
  ,CONNEXION
  ,DESTI_NOTIF
  ,SQL_HORAIRE
)
VALUES
(
   'BD'
  ,'OR'
  ,'SDBM'
  ,'SDBMON'
  ,'changeme-mon'
  ,'NO'
  ,'(DESCRIPTION =
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
'
  ,'---'
  ,'SELECT 1
  FROM DUAL
 WHERE /* JOUR  */ (TRIM(TO_CHAR(SYSDATE,''DAY'',''NLS_DATE_LANGUAGE = AMERICAN''))
    IN (''MONDAY'',''TUESDAY'',''WEDNESDAY'',''THURSDAY'',''FRIDAY'',''SATURDAY'',''SUNDAY''))
   AND /* HEURE */ (TO_CHAR(SYSDATE,''HH24:MI'') BETWEEN ''00:00'' AND ''23:59'')
'
);

INSERT INTO SDBM.EVENEMENT_CIBLE
(
   TYPE_CIBLE
  ,SOUS_TYPE_CIBLE
  ,NOM_CIBLE
  ,NOM_EVENEMENT
)
SELECT TYPE_CIBLE
      ,SOUS_TYPE_CIBLE
      ,'SDBM'
      ,NOM_EVENEMENT
  FROM SDBM.EVENEMENT
 WHERE TYPE_CIBLE      = 'BD'
   AND SOUS_TYPE_CIBLE = 'OR' 
   AND NOM_EVENEMENT   NOT LIKE 'ASM%'
   AND NOM_EVENEMENT   NOT LIKE 'DEFERROR'
   AND NOM_EVENEMENT   NOT LIKE 'LOGSTDBY.%'
   AND NOM_EVENEMENT   NOT LIKE 'PHYSTDBY.%'
   AND NOM_EVENEMENT   NOT LIKE 'SDBM.SDBMSRV'
   AND NOM_EVENEMENT   NOT LIKE 'SPACE_CRITICAL'
   AND NOM_EVENEMENT   NOT LIKE 'STREAM.%'
   AND NOM_EVENEMENT   NOT LIKE 'TEST'
   AND NOM_EVENEMENT   NOT LIKE 'CD_ASM_DISKGROUP';

INSERT INTO SDBM.VOLUME_PHY
(
   DESC_VOLUME_PHY
  ,TOTAL_MB
  ,CHEMIN_ACCES_DEFAUT
)
VALUES
(
   'SDBM_/opt'
   ,10240
   ,'/opt/oracle'
);

INSERT INTO SDBM.VOLUME_PHY_CIBLE
(
   ID_VOLUME_PHY
  ,TYPE_CIBLE
  ,NOM_CIBLE
  ,CHEMIN_ACCES
)
VALUES
(
   1
  ,'BD'
  ,'SDBM'
  ,'/opt/oracle'
);

INSERT INTO SDBM.TACHE_AGT
(
   NOM_SERVEUR
  ,NOM_TACHE
  ,EXECUTABLE
  ,PARAMETRE
  ,REPERTOIRE
  ,REPERTOIRE_JOURNAL
  ,EXECUTION
  ,TYPE_NOTIF
  ,DESTI_NOTIF
  ,INTERVAL
  ,DELAI_AVERTISSEMENT
  ,DH_PROCHAINE_EXEC
  ,CODE_RETOUR_SUCCES
)
VALUES
(
   (SELECT UPPER(HOST_NAME) FROM V$INSTANCE)
  ,'BACKUP_ARCH_SDBM'
  ,'/bin/bash'
  ,'./rman-bkarc-sdbm.sh'
  ,'/opt/sdbm'
  ,'/tmp'
  ,'AC'
  ,'OF'
  ,'---'
  ,'TRUNC(SYSDATE,''HH24'') + 1.75/24'
  ,30
  ,TRUNC(SYSDATE,'HH24') + 1.75/24
  ,'{RC} = 0'
);

INSERT INTO SDBM.TACHE_DET_MSG_AGT
(
   NOM_SERVEUR
  ,NOM_TACHE
  ,TYPE_MSG
  ,MSG
)
VALUES
(
   (SELECT UPPER(HOST_NAME) FROM V$INSTANCE)
  ,'BACKUP_ARCH_SDBM'
  ,'ER'
  ,'ORA-'
);

INSERT INTO SDBM.TACHE_AGT
(
   NOM_SERVEUR
  ,NOM_TACHE
  ,EXECUTABLE
  ,PARAMETRE
  ,REPERTOIRE
  ,REPERTOIRE_JOURNAL
  ,EXECUTION
  ,TYPE_NOTIF
  ,DESTI_NOTIF
  ,INTERVAL
  ,DELAI_AVERTISSEMENT
  ,DH_PROCHAINE_EXEC
  ,CODE_RETOUR_SUCCES
)
VALUES
(
   (SELECT UPPER(HOST_NAME) FROM V$INSTANCE)
  ,'BACKUP_FULL_SDBM'
  ,'/bin/bash'
  ,'./rman-bkdbs-sdbm.sh'
  ,'/opt/sdbm'
  ,'/tmp'
  ,'AC'
  ,'OF'
  ,'---'
  ,'TRUNC(SYSDATE) + 1 + 12.25/24'
  ,90
  ,TRUNC(SYSDATE) + 1 + 12.25/24
  ,'{RC} = 0'
);

INSERT INTO SDBM.TACHE_DET_MSG_AGT
(
   NOM_SERVEUR
  ,NOM_TACHE
  ,TYPE_MSG
  ,MSG
)
VALUES
(
   (SELECT UPPER(HOST_NAME) FROM V$INSTANCE)
  ,'BACKUP_FULL_SDBM'
  ,'ER'
  ,'ORA-'
);

COMMIT;

EXIT
