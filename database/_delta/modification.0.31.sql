-- *
-- * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
-- * Licensed under the MIT license.
-- * See LICENSE file in the project root for full license information.
-- *



---------------------------------------------
---------------------------------------------
---------------------------------------------
--  V E R S I O N   0 . 3 1  -   B e t a   --
---------------------------------------------
---------------------------------------------


CONNECT SDBM
EXECUTE DBMS_JOB.REMOVE(101);
COMMIT;

DECLARE

   CURSOR C_DBL IS
      SELECT 'DROP DATABASE LINK ' || DB_LINK "CMD"
        FROM USER_DB_LINKS;

BEGIN

   FOR RC_DBL IN C_DBL LOOP
      EXECUTE IMMEDIATE RC_DBL.CMD;  
   END LOOP;
   
END;
/

DISCONNECT


-- CD - FILESTAT
UPDATE SDBM.EVENEMENT
   SET COMMANDE =
'
SELECT SYSDATE
      ,{NOM_CIBLE}
      ,FILE#
      ,PHYRDS
      ,PHYWRTS
      ,PHYBLKRD
      ,PHYBLKWRT
      ,0 /* Incompatible avec 8i : SINGLEBLKRDS   */
      ,READTIM
      ,WRITETIM
      ,0 /* Incompatible avec 8i : SINGLEBLKRDTIM */
      ,AVGIOTIM
      ,LSTIOTIM
      ,MINIOTIM
      ,MAXIORTM
      ,MAXIOWTM
      ,STARTUP_TIME
  FROM V$FILESTAT
      ,V$INSTANCE
UNION ALL
SELECT SYSDATE
      ,{NOM_CIBLE}
      ,FILE# + 10000
      ,PHYRDS
      ,PHYWRTS
      ,PHYBLKRD
      ,PHYBLKWRT
      ,0 /* Incompatible avec 8i : SINGLEBLKRDS   */
      ,READTIM
      ,WRITETIM
      ,0 /* Incompatible avec 8i : SINGLEBLKRDTIM */
      ,AVGIOTIM
      ,LSTIOTIM
      ,MINIOTIM
      ,MAXIORTM
      ,MAXIOWTM
      ,STARTUP_TIME
  FROM V$TEMPSTAT
      ,V$INSTANCE
'
WHERE TYPE_CIBLE     = 'BD'
  AND TYPE_EVENEMENT = 'CD'
  AND NOM_EVENEMENT  = 'CD_FILESTAT';


-- CD - DBA_DATA_FILES
UPDATE SDBM.EVENEMENT
   SET COMMANDE =
'
SELECT SYSDATE
      ,{NOM_CIBLE}
      ,DBA_DATA_FILES.FILE_NAME
      ,DBA_DATA_FILES.FILE_ID
      ,DBA_DATA_FILES.TABLESPACE_NAME
      ,DBA_DATA_FILES.BYTES
      ,DECODE(DBA_TABLESPACES.CONTENTS
             ,''UNDO'',0
             ,(SELECT SUM(BYTES)
                 FROM DBA_FREE_SPACE
                WHERE FILE_ID = DBA_DATA_FILES.FILE_ID
              )
             )
      ,0
  FROM DBA_DATA_FILES
      ,DBA_TABLESPACES
 WHERE DBA_DATA_FILES.TABLESPACE_NAME = DBA_TABLESPACES.TABLESPACE_NAME
UNION ALL
SELECT SYSDATE
      ,{NOM_CIBLE}
      ,FILE_NAME
      ,FILE_ID + 10000
      ,TABLESPACE_NAME
      ,BYTES
      ,0
      ,0
  FROM DBA_TEMP_FILES
{*** ALTERNATE SQL ***}
SELECT SYSDATE
      ,{NOM_CIBLE}
      ,DDF.NAME
      ,DDF.FILE#
      ,(SELECT NAME FROM V$TABLESPACE WHERE TS# = DDF.TS#)
      ,DDF.BYTES
      ,-1
      ,0
  FROM V$DATAFILE DDF
UNION ALL
SELECT SYSDATE
      ,{NOM_CIBLE}
      ,NAME
      ,FILE# + 10000
      ,(SELECT NAME FROM V$TABLESPACE WHERE TS# = DTF.TS#)
      ,BYTES
      ,0
      ,0
  FROM V$TEMPFILE DTF
'
WHERE TYPE_CIBLE      = 'BD'
  AND SOUS_TYPE_CIBLE = 'OR'
  AND TYPE_EVENEMENT  = 'CD'
  AND NOM_EVENEMENT   = 'CD_DBA_DATA_FILES';


-- CD - ESPACE_ARCHIVED_LOG
UPDATE SDBM.EVENEMENT
   SET COMMANDE =
'
SELECT TRUNC(SYSDATE,''HH24'') - 1/24 "DH_COLLECTE_DONNEE"
      ,{NOM_CIBLE}                  "NOM_CIBLE"
      ,NVL(
             (SELECT SUM(BLOCKS * BLOCK_SIZE)
                FROM V$ARCHIVED_LOG
                    ,V$INSTANCE
               WHERE COMPLETION_TIME BETWEEN TRUNC(SYSDATE,''HH24'') - 1/24
                                         AND TRUNC(SYSDATE,''HH24'') - 1/86400
                 AND V$ARCHIVED_LOG.THREAD# = V$INSTANCE.THREAD# 
                 AND DEST_ID = (SELECT MIN(DEST_ID) FROM V$ARCHIVED_LOG
                                 WHERE COMPLETION_TIME BETWEEN TRUNC(SYSDATE,''HH24'') - 1/24
                                                           AND TRUNC(SYSDATE,''HH24'') - 1/86400
                                   AND THREAD# = V$INSTANCE.THREAD#
                               )
             )
            ,0
          )
       "ESPACE"
  FROM DUAL
'
      ,INTERVAL_DEFAUT = 'TRUNC(SYSDATE,''HH24'') + 60/1440 + 15/86400'
WHERE TYPE_CIBLE     = 'BD'
  AND TYPE_EVENEMENT = 'CD'
  AND NOM_EVENEMENT  = 'CD_ESPACE_ARCHIVED_LOG';



CREATE TABLE CD_ASM_DISKGROUP
(
   DH_COLLECTE_DONNEE  DATE
  ,NOM_CIBLE           VARCHAR2(30)
  ,HOST_NAME           VARCHAR2(64)
  ,DISKGROUP_NAME      VARCHAR2(30)
  ,TOTAL_MB            NUMBER
  ,FREE_MB             NUMBER
)
TABLESPACE SDBM_DATA
MONITORING;

ALTER TABLE CD_ASM_DISKGROUP
   ADD CONSTRAINT CDAD_PK_CD_ASM_DISKGROUP PRIMARY KEY (DH_COLLECTE_DONNEE, NOM_CIBLE, DISKGROUP_NAME)
      USING INDEX
      TABLESPACE SDBM_DATA;


-- CD - ASM_DISKGROUP
INSERT INTO SDBM.EVENEMENT
(
   TYPE_CIBLE
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
  ,'CD_ASM_DISKGROUP'
  ,'CD'
  ,'
SELECT TRUNC(SYSDATE,''HH24'')                   "DH_COLLECTE_DONNEE"
      ,{NOM_CIBLE}                             "NOM_CIBLE"
      ,INS.HOST_NAME                           "HOST_NAME"
      ,ADG.NAME                                "DISKGROUP_NAME"
      ,ROUND(ADG.TOTAL_MB / DECODE(ADG.TYPE
                                  ,''EXTERN'',1
                                  ,''NORMAL'',2
                                  ,''HIGH'',3
                                  )
            ,0
            )                                  "TOTAL_MB"
      ,ADG.FREE_MB / DECODE(ADG.TYPE
                           ,''EXTERN'',1
                           ,''NORMAL'',2
                           ,''HIGH'',3
                           )                   "FREE_MB"
  FROM V$ASM_DISKGROUP ADG
      ,V$INSTANCE      INS
 WHERE ADG.STATE = ''MOUNTED''
'
  ,'TRUNC(SYSDATE,''HH24'') + 60/1440 + 15/86400'
  ,'---'
  ,30
);



CREATE TABLE CD_TRANSACTION_LOG
(
   DH_COLLECTE_DONNEE  DATE
  ,NOM_CIBLE           VARCHAR2(30)
  ,DATABASE_NAME       VARCHAR2(257)
  ,RECOVERY_MODE       VARCHAR2(60)
  ,TOTAL_SPACE         NUMBER
  ,USED_SPACE          NUMBER
  ,USED_SPACE_BACKUP   NUMBER
)
TABLESPACE SDBM_DATA
MONITORING;

ALTER TABLE CD_TRANSACTION_LOG
   ADD CONSTRAINT CDTL_PK_CD_TRANSACTION_LOG PRIMARY KEY (DH_COLLECTE_DONNEE, NOM_CIBLE, DATABASE_NAME)
      USING INDEX
      TABLESPACE SDBM_DATA;


-- CD - TRANSACTION_LOG
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
  ,'MS'
  ,'CD_TRANSACTION_LOG'
  ,'CD'
  ,'
SET NOCOUNT ON

DECLARE c_database CURSOR FOR
   SELECT name
     FROM master.sys.databases
    WHERE state_desc       = ''ONLINE''
      AND user_access_desc = ''MULTI_USER''
      AND name        NOT IN (SELECT secondary_database
                                FROM msdb.dbo.log_shipping_secondary_databases
                             )

DECLARE @TDATSPACE TABLE
(
   database_name  sysname
  ,used_space     numeric
  ,total_space    numeric
)

DECLARE @v_database  sysname
DECLARE @SQLTemplate nvarchar(4000)
DECLARE @SQLString   nvarchar(4000)


SET @SQLTemplate = ''
   -- SPACE (LOG)
   SELECT ''''<DATABASE>''''                            AS "DATABASE"
         ,SUM(USED_SPACE.USED_SPACE)                AS "USED_SPACE"
         ,SUM(
                (
                   CASE
                      WHEN TOTAL_SPACE.SIZE < TOTAL_SPACE.MAX_SIZE

                         THEN TOTAL_SPACE.MAX_SIZE
                         ELSE TOTAL_SPACE.SIZE
                   END
                )
             )                                      AS "TOTAL_SPACE"

     FROM (
            /* Used space per file with AUTOGROWTH */
            SELECT fil.filename                                                                        AS "DATA_FILE"
                  ,(CONVERT(numeric,fil.size) * 8) * 1024                                              AS "SIZE"
                  ,(
                       CASE fil.maxsize
                          WHEN -1 THEN
                             CONVERT(numeric,268435456)   * 8 * 1024 /* APPROX. 2T */
                          ELSE
                             CONVERT(numeric,fil.maxsize) * 8 * 1024
                       END
                   )
                   * (CASE fil.growth WHEN 0 THEN 0 ELSE 1 END)                                        AS "MAX_SIZE"
              FROM <DATABASE>.sys.sysfiles fil

             WHERE groupid = 0
          ) TOTAL_SPACE
         ,(
             SELECT CONVERT(numeric,cntr_value) * 1024  AS "USED_SPACE"
               FROM sys.dm_os_performance_counters

              WHERE instance_name = ''''<DATABASE>''''
                AND counter_name = ''''Log File(s) Used Size (KB)''''
          ) USED_SPACE
''   


OPEN c_database

FETCH NEXT FROM c_database
   INTO @v_database

WHILE @@FETCH_STATUS = 0
BEGIN

   SET @SQLString = REPLACE(@SQLTemplate,''<DATABASE>'',@v_database)

   INSERT INTO @TDATSPACE
      EXECUTE sp_executesql @SQLString


   FETCH NEXT FROM c_database
      INTO @v_database
END

CLOSE c_database
DEALLOCATE c_database


-- Retour de l''information
DECLARE @CUR_DATE DATETIME
SET @CUR_DATE = GETDATE()

SELECT DATEADD(hour,DATEPART(hour,@CUR_DATE),CAST(FLOOR(CAST(@CUR_DATE AS FLOAT)) AS DATETIME)) "DH_COLLECTE_DONNEE"
      ,{NOM_CIBLE}                                                                              "NOM_CIBLE"
      ,TDS.database_name                                                                        "DATABASE_NAME"
      ,CONVERT(varchar,DATABASEPROPERTYEX(TDS.database_name,''Recovery''))                        "RECOVERY_MODE"
      ,TDS.total_space                                                                          "TOTAL_SPACE"
      ,TDS.used_space                                                                           "USED_SPACE"
      ,(SELECT SUM(backup_size)
          FROM msdb.dbo.backupset
         WHERE database_name = TDS.database_name
           AND type          = ''L''
           AND backup_finish_date BETWEEN DATEADD(hour,DATEPART(hour,@CUR_DATE) - 1,CAST(FLOOR(CAST(@CUR_DATE AS FLOAT)) AS DATETIME))
                                      AND DATEADD(ms,-2,DATEADD(hour,DATEPART(hour,@CUR_DATE),CAST(FLOOR(CAST(@CUR_DATE AS FLOAT)) AS DATETIME)))
         GROUP BY database_name
       )
       "USED_SPACE_BACKUP"
  FROM @TDATSPACE TDS
'
  ,'TRUNC(SYSDATE,''HH24'') + 60/1440 + 15/86400'
  ,'---'
  ,30
);



DROP TABLE SDBM.CD_DBA_SEGMENTS PURGE;


CREATE OR REPLACE VIEW SDBM.APEX_STATUT_SESSION_SDBM
AS 
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

-- SDBM.SDBMDAC
INSERT INTO SDBM.EVENEMENT
(
   TYPE_CIBLE
  ,SOUS_TYPE_CIBLE
  ,NOM_EVENEMENT
  ,COMMANDE
  ,INTERVAL_DEFAUT
  ,DESTI_NOTIF_DEFAUT
  ,DELAI_MAX_EXEC_SEC
)
VALUES
(
   'BD'
  ,'OR'
  ,'SDBM.SDBMDAC'
  ,'
SELECT ''N/A''
      ,''Le service principal SDBMDaC - SDBM (collecte de données) ne semble pas fonctionnel.'' 
  FROM SDBM.APEX_STATUT_SESSION_SDBM
 WHERE MISE_EN_EVIDENCE IN (3,5)
   AND MODULE         LIKE ''SDBMDAC%''
'
  ,'SYSDATE + 15/1440'
  ,'---'
  ,30
);

INSERT INTO SDBM.EVENEMENT_DEFAUT_TRADUCTION
(
   TYPE_CIBLE
  ,SOUS_TYPE_CIBLE
  ,NOM_EVENEMENT
  ,CHAINE_FR
  ,CHAINE_AN
  ,COMMENTAIRE_FR
  ,COMMENTAIRE_AN
)
VALUES
(
   'BD'
  ,'OR'
  ,'SDBM.SDBMDAC'
  ,'''Le service principal SDBMDaC - SDBM (collecte de données) ne semble pas fonctionnel.'''
  ,'''SDBMDaC SDBM (data collection) service does not seem to be working.'''
  ,'Vérification que le serveur SDBMDaC s''exécute'
  ,'Validate that SDBMDaC server is running'
);


/* Correction commentaire dans les événements SDBM */
-> Changement via l'interface Web Anglais -> Fraçais -> Anglais


#
# Installation de SDBMDaC
#


# Modification de l'usager Oracle
GRANT EXECUTE ON SDBM.SDBM_COLLECTE           TO SDBMSRV;
GRANT INSERT  ON SDBM.CD_ASM_DISKGROUP        TO SDBMSRV;
GRANT INSERT  ON SDBM.CD_DBA_DATA_FILES       TO SDBMSRV;
GRANT INSERT  ON SDBM.CD_ESPACE_ARCHIVED_LOG  TO SDBMSRV;
GRANT INSERT  ON SDBM.CD_FILESTAT             TO SDBMSRV;
GRANT INSERT  ON SDBM.CD_TRANSACTION_LOG      TO SDBMSRV;


ALTER TABLE SDBM.CD_DBA_DATA_FILES
   MODIFY TABLESPACE_NAME VARCHAR2(257);

ALTER TABLE SDBM.EVENEMENT_CIBLE
   ADD NB_ERREUR NUMBER;


ALTER SESSION SET CURRENT_SCHEMA = SDBM;

@../_package/pb-sdbm_util.sql

@../_package/ps-sdbm_collecte.sql
@../_package/pb-sdbm_collecte.sql


-- CD - DBA_DATA_FILES
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
  ,'MS'
  ,'CD_DBA_DATA_FILES'
  ,'CD'
  ,'
SET NOCOUNT ON


DECLARE c_database CURSOR FOR
   SELECT name
     FROM master.sys.databases
    WHERE state_desc       = ''ONLINE''

      AND user_access_desc = ''MULTI_USER''
      AND name        NOT IN (SELECT secondary_database
                                FROM msdb.dbo.log_shipping_secondary_databases
                             )


DECLARE @TDATSPACE TABLE
(
   DH_COLLECTE_DONNEE datetime
  ,NOM_CIBLE          nvarchar(30)

  ,FILE_NAME          nvarchar(260)
  ,FILE_ID            numeric
  ,TABLESPACE_NAME    nvarchar(257)
  ,BYTES              numeric
  ,FREE_SPACE         numeric

  ,ID_VOLUME_PHY      numeric
)

DECLARE @v_database  sysname
DECLARE @SQLTemplate nvarchar(4000)

DECLARE @SQLString   nvarchar(4000)


SET @SQLTemplate = ''
SELECT GETDATE()                                                                              AS "DH_COLLECTE_DONNEE"

      ,''{NOM_CIBLE}''                                                                          AS "NOM_CIBLE"
      ,dbf.physical_name                                                                      AS "FILE_NAME"
      ,(DB_ID(''''<DATABASE>'''') * 10000) + dbf.file_id                                          AS "FILE_ID"
      ,''''<DATABASE>'''' + ''''.'''' + grp.groupname                                                 AS "TABLESPACE_NAME"

      ,((CONVERT(NUMERIC,dbf.size) * 8) * 1024)                                               AS "BYTES"
      ,CASE 
         WHEN ((CONVERT(NUMERIC,dbf.size) * 8) * 1024) - SUM(ISNULL(alu.total_pages,0)) * 8 * 1024 < 0 THEN 0 
         ELSE ((CONVERT(NUMERIC,dbf.size) * 8) * 1024) - SUM(ISNULL(alu.total_pages,0)) * 8 * 1024 
       END                                                                                    AS "FREE_SPACE"

      ,0                                                                                      AS "ID_VOLUME_PHY"
  FROM                 <DATABASE>.sys.database_files     dbf
       LEFT OUTER JOIN <DATABASE>.sys.allocation_units   alu  ON dbf.data_space_id = alu.data_space_id
            INNER JOIN <DATABASE>.sys.sysfiles           fil  ON dbf.file_id       = fil.fileid
            INNER JOIN <DATABASE>.sys.sysfilegroups      grp  ON fil.groupid       = grp.groupid

 GROUP BY dbf.physical_name
         ,dbf.file_id
         ,grp.groupname
         ,dbf.size
''

OPEN c_database

FETCH NEXT FROM c_database
   INTO @v_database


WHILE @@FETCH_STATUS = 0
BEGIN

   SET @SQLString = REPLACE(@SQLTemplate,''<DATABASE>'',@v_database)


   INSERT INTO @TDATSPACE
      EXECUTE sp_executesql @SQLString

   FETCH NEXT FROM c_database

      INTO @v_database
END

CLOSE c_database
DEALLOCATE c_database



-- Information return
SELECT *
  FROM @TDATSPACE
'
  ,'TRUNC(SYSDATE + 1) + 15/1440'
  ,'---'
  ,30
);


INSERT INTO SDBM.DEFAUT
(
   CLE
  ,VALEUR
)
VALUES
(
   'CD_NB_ESSAI'
  ,'3'
);

INSERT INTO SDBM.DEFAUT
(
   CLE
  ,VALEUR
)
VALUES
(
   'CD_MIN_ENTRE_ESSAI'
  ,'5'
);


DROP MATERIALIZED VIEW MV_INFO_VOLUME_UTILISATION;
CREATE MATERIALIZED VIEW MV_INFO_VOLUME_UTILISATION
   REFRESH COMPLETE
   AS SELECT VLP.ID_VOLUME_PHY                                                                           ID_VOLUME_PHY
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


#
# Mise en place des composantes
#
mkdir -p /usr/lib/oracle/sdbm/sdbmdac/log
cd /usr/lib/oracle/sdbm/sdbmdac
--> obtenir sdbmdac
--> obtenir sdbmdacctl
--> obtenir SDBMDaC.sh
--> obtenir SDBMDaC.jar
--> obtenir SDBMDac.properties
chmod 640 SDBMDaC.*
chmod 750 sdbmdacctl SDBMDaC.sh
chown -R oracle:dba /usr/lib/oracle/sdbm/sdbmdac

# Avec root :
cd /usr/lib/oracle/sdbm/sdbmdac
mv sdbmdac /etc/init.d

chown root:root /etc/init.d/sdbmdac
chmod 755 /etc/init.d/sdbmdac
chkconfig --add sdbmdac


/* Correction événement RMAN_DATAFILE */
UPDATE SDBM.EVENEMENT
   SET COMMANDE =
'
SELECT ''N/A''
      ,DECODE(COUNT(1)
             ,1,COUNT(1) || '' fichier de la base de données n''''a pas été sauvegardé dans RMAN''   || DECODE(MIN(COMPLETION_TIME)
                                                                                                           ,TO_DATE(NULL),''.''
                                                                                                           ,'' depuis le '' || TO_CHAR(MIN(COMPLETION_TIME),''YYYY/MM/DD:HH24:MI:SS'') || ''.''
                                                                                                           )
             ,COUNT(1) || '' fichiers de la base de données n''''ont pas été sauvegardés dans RMAN'' || DECODE(MIN(COMPLETION_TIME)
                                                                                                           ,TO_DATE(NULL),''.''
                                                                                                           ,'' depuis le '' || TO_CHAR(MIN(COMPLETION_TIME),''YYYY/MM/DD:HH24:MI:SS'') || ''.''
                                                                                                           )
             )
  FROM (
         SELECT MAX(BDF.COMPLETION_TIME) "COMPLETION_TIME"
           FROM V$DATAFILE        DBF
               ,V$BACKUP_DATAFILE BDF
          WHERE DBF.FILE# = BDF.FILE#(+)
            AND (
                      DBF.ENABLED != ''READ ONLY''
                   OR (
                             DBF.ENABLED = ''READ ONLY''
                         AND NOT EXISTS (SELECT 1
                                           FROM V$BACKUP_DATAFILE
                                          WHERE FILE#           = DBF.FILE#
                                            AND COMPLETION_TIME > DBF.LAST_TIME
                                        ) 
                      )     
                ) 
          GROUP BY DBF.FILE#
       )
 WHERE COMPLETION_TIME < SYSDATE - 7
    OR COMPLETION_TIME IS NULL
HAVING COUNT(1) > 0
'
WHERE TYPE_CIBLE      = 'BD'
  AND SOUS_TYPE_CIBLE = 'OR'
  AND NOM_EVENEMENT   = 'RMAN_DATAFILE';


DELETE FROM SDBM.EVENEMENT_DEFAUT_TRADUCTION
   WHERE NOM_EVENEMENT = 'RMAN_DATAFILE';

INSERT INTO SDBM.EVENEMENT_DEFAUT_TRADUCTION
(
   TYPE_CIBLE
  ,SOUS_TYPE_CIBLE
  ,NOM_EVENEMENT
  ,CHAINE_FR
  ,CHAINE_AN
  ,COMMENTAIRE_FR
  ,COMMENTAIRE_AN
)
VALUES
(
   'BD'
  ,'OR'
  ,'RMAN_DATAFILE'
  ,(SELECT SUBSTR(COMMANDE,54,1081) FROM SDBM.EVENEMENT WHERE NOM_EVENEMENT = 'RMAN_DATAFILE')
  ,       ',1,COUNT(1) || '' file of the database was not backup within RMAN''   || DECODE(MIN(COMPLETION_TIME)
                                                                                          ,TO_DATE(NULL),''.''
                                                                                          ,'' since '' || TO_CHAR(MIN(COMPLETION_TIME),''YYYY/MM/DD:HH24:MI:SS'') || ''.''
                                                                                          )
              ,COUNT(1) || '' files of the database were not backup within RMAN'' || DECODE(MIN(COMPLETION_TIME)
                                                                                        ,TO_DATE(NULL),''.''
                                                                                        ,'' since '' || TO_CHAR(MIN(COMPLETION_TIME),''YYYY/MM/DD:HH24:MI:SS'') || ''.''
                                                                                        )'
  ,'Vérification de l''exécution des prises de copie RMAN (DATAFILE)'
  ,'Validate that RMAN backup are running (DATAFILE)'
);


DELETE FROM SDBM.EVENEMENT_DEFAUT_TRADUCTION
   WHERE NOM_EVENEMENT = 'SDBM.WARNING';

INSERT INTO SDBM.EVENEMENT_DEFAUT_TRADUCTION
(
   TYPE_CIBLE
  ,SOUS_TYPE_CIBLE
  ,NOM_EVENEMENT
  ,CHAINE_FR
  ,CHAINE_AN
  ,COMMENTAIRE_FR
  ,COMMENTAIRE_AN
)
VALUES
(
   'BD'
  ,'OR'
  ,'SDBM.WARNING'
  ,'WARNING'
  ,'WARNING'
  ,'Envoi des messages du journal SDBM (WARNING : Unable to process event ...)'
  ,'Send message from SDBM event log (WARNING : Unable to process event ...)'
);

CREATE OR REPLACE VIEW SDBM.APEX_HIS_PANNE_BD
AS
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


ALTER SESSION SET CURRENT_SCHEMA = SDBM;

ALTER TABLE VOLUME_PHY_CIBLE
   DROP CONSTRAINT VPC_FK_VOLUME_PHY;

ALTER TABLE VOLUME_PHY
   DROP CONSTRAINT VP_PK_VOLUME_PHY;

ALTER TABLE VOLUME_PHY
   DROP CONSTRAINT VP_CHK_STATUT;

ALTER TABLE VOLUME_PHY RENAME TO VOLUME_PHY_031;

CREATE TABLE VOLUME_PHY
(
   ID_VOLUME_PHY        NUMBER(6)                        NOT NULL
  ,DESC_VOLUME_PHY      VARCHAR2(100)                    NOT NULL
  ,TOTAL_MB             NUMBER(8)                        NOT NULL
  ,FREE_MB              NUMBER(8)       DEFAULT -1       NOT NULL
  ,DH_DERN_MAJ          DATE            DEFAULT SYSDATE  NOT NULL
  ,MAJ_CD_AUTORISE      CHAR(2)         DEFAULT 'FA'     NOT NULL
  ,CHEMIN_ACCES_DEFAUT  VARCHAR2(512)                    NOT NULL
  ,STATUT               CHAR(2)         DEFAULT 'AC'     NOT NULL
  ,COMMENTAIRE          VARCHAR2(500)
  ,NOM_CIBLE_DERN_MAJ   VARCHAR2(30)
)
TABLESPACE SDBM_DATA
MONITORING;

INSERT INTO VOLUME_PHY
SELECT ID_VOLUME_PHY
      ,DESC_VOLUME_PHY
      ,TOTAL_MB
      ,-1
      ,SYSDATE
      ,DECODE((SELECT 1 FROM DUAL WHERE INSTR(DESC_VOLUME_PHY,'+') != 0)
             ,TO_NUMBER(NULL),'FA'
             ,'VR'
             )
      ,CHEMIN_ACCES_DEFAUT
      ,STATUT
      ,COMMENTAIRE
      ,NULL
  FROM VOLUME_PHY_031;

UPDATE SDBM.VOLUME_PHY
   SET DESC_VOLUME_PHY = LOWER(SUBSTR(DESC_VOLUME_PHY,1,INSTR(DESC_VOLUME_PHY,'_'))) || SUBSTR(DESC_VOLUME_PHY,INSTR(DESC_VOLUME_PHY,'+'))
 WHERE CHEMIN_ACCES_DEFAUT LIKE '+DG%';

DROP TRIGGER SDBM.VP_TR_INIT_ID_VOLUME_PHY;
CREATE OR REPLACE TRIGGER SDBM.VP_TR_INIT_ID_VOLUME_PHY

/******************************************************************
  TRIGGER : VP_TR_INIT_ID_VOLUME_PHY
  AUTEUR  : Benoit Bouthillier 2009-02-13
 ------------------------------------------------------------------
  BUT : Initialisation de la clé primaire.

*******************************************************************/

   BEFORE INSERT
   ON VOLUME_PHY
   FOR EACH ROW

BEGIN

   SELECT VP_ID_VOLUME_PHY.NEXTVAL
     INTO :NEW.ID_VOLUME_PHY
     FROM DUAL;

END VP_TR_INIT_ID_VOLUME_PHY;
/


ALTER TABLE VOLUME_PHY
   ADD CONSTRAINT VP_CHK_STATUT
      CHECK (STATUT IN (/* Actif */ 'AC',/* Inactif */ 'IN'));

ALTER TABLE VOLUME_PHY
   ADD CONSTRAINT VP_CHK_MAJ_CD_AUTORISE
      CHECK (MAJ_CD_AUTORISE IN (/* Vrai */ 'VR',/* Faux */ 'FA'));

DROP INDEX VP_PK_VOLUME_PHY;
ALTER TABLE VOLUME_PHY
   ADD CONSTRAINT VP_PK_VOLUME_PHY PRIMARY KEY (ID_VOLUME_PHY)
      USING INDEX
      TABLESPACE SDBM_DATA;

ALTER TABLE VOLUME_PHY_CIBLE
   ADD CONSTRAINT VPC_FK_VOLUME_PHY
       FOREIGN KEY (ID_VOLUME_PHY) REFERENCES VOLUME_PHY
       ON DELETE CASCADE;

DROP TABLE SDBM.VOLUME_PHY_031 PURGE;

BEGIN

   SDBM_AUDIT_APPL.GENERER_TRIGGER('VOLUME_PHY','''ID_VOLUME_PHY'',''DESC_VOLUME_PHY'',''TOTAL_MB'',''MAJ_CD_AUTORISE'',''CHEMIN_ACCES_DEFAUT'',''STATUT'',''COMMENTAIRE''');

END;
/


CREATE OR REPLACE TRIGGER SDBM.CDAD_TR_MAJ_VOLUME_PHY

/******************************************************************
  TRIGGER : CDAD_TR_MAJ_VOLUME_PHY
  AUTEUR  : Benoit Bouthillier 2012-05-22
 ------------------------------------------------------------------
  BUT : Mise à jour de la table VOLUME_PHY (diskgroup ASM).

*******************************************************************/

   BEFORE INSERT
   ON CD_ASM_DISKGROUP
   FOR EACH ROW

DECLARE

   V_INDICATEUR_MODIF NUMBER(1);

BEGIN

   -- Vérification si une mise à jour est requise
   SELECT DISTINCT 1
     INTO V_INDICATEUR_MODIF
     FROM VOLUME_PHY
    WHERE DESC_VOLUME_PHY     = :NEW.HOST_NAME || '_+' || :NEW.DISKGROUP_NAME
      AND CHEMIN_ACCES_DEFAUT = '+' || :NEW.DISKGROUP_NAME || '/'
      AND MAJ_CD_AUTORISE     = 'VR'
      AND DH_DERN_MAJ         < :NEW.DH_COLLECTE_DONNEE
      AND STATUT              = 'AC'
      AND (
                TOTAL_MB != :NEW.TOTAL_MB
             OR FREE_MB  != :NEW.FREE_MB
          );

   -- Mise à jour requise
   UPDATE VOLUME_PHY
      SET TOTAL_MB           = NVL(:NEW.TOTAL_MB,0)
         ,FREE_MB            = NVL(:NEW.FREE_MB,0)
         ,DH_DERN_MAJ        = :NEW.DH_COLLECTE_DONNEE
         ,NOM_CIBLE_DERN_MAJ = :NEW.NOM_CIBLE
    WHERE DESC_VOLUME_PHY     = :NEW.HOST_NAME || '_+' || :NEW.DISKGROUP_NAME
      AND CHEMIN_ACCES_DEFAUT = '+' || :NEW.DISKGROUP_NAME || '/'
      AND MAJ_CD_AUTORISE     = 'VR'
      AND DH_DERN_MAJ         < :NEW.DH_COLLECTE_DONNEE
      AND STATUT              = 'AC'
      AND (
                TOTAL_MB != :NEW.TOTAL_MB
             OR FREE_MB  != :NEW.FREE_MB
          );

EXCEPTION

   WHEN NO_DATA_FOUND THEN

      BEGIN

         -- Vérification si une insertion est requise
         SELECT DISTINCT 1
           INTO V_INDICATEUR_MODIF
           FROM VOLUME_PHY
          WHERE DESC_VOLUME_PHY = :NEW.HOST_NAME || '_+' || :NEW.DISKGROUP_NAME
            AND STATUT          = 'AC';
      
      EXCEPTION

         WHEN NO_DATA_FOUND THEN

            INSERT INTO VOLUME_PHY
            (
               DESC_VOLUME_PHY
              ,CHEMIN_ACCES_DEFAUT
              ,MAJ_CD_AUTORISE
              ,DH_DERN_MAJ
              ,TOTAL_MB
              ,FREE_MB
              ,NOM_CIBLE_DERN_MAJ
            )
            VALUES
            (
               :NEW.HOST_NAME || '_+' || :NEW.DISKGROUP_NAME
              ,'+' || :NEW.DISKGROUP_NAME || '/'
              ,'VR'
              ,:NEW.DH_COLLECTE_DONNEE
              ,NVL(:NEW.TOTAL_MB,0)
              ,NVL(:NEW.FREE_MB,0)
              ,:NEW.NOM_CIBLE
            );

      END;

END CDAD_TR_MAJ_VOLUME_PHY;
/


CREATE TABLE CD_SYSSTAT_CPU
(
   DH_COLLECTE_DONNEE              DATE
  ,NOM_CIBLE                       VARCHAR2(30)
  ,HOST_NAME                       VARCHAR2(64)
  ,INSTANCE_NAME                   VARCHAR2(16)
  ,STARTUP_TIME                    DATE
  ,CPU_USED_BY_SESSION             NUMBER
  ,CPU_RECURSIVE                   NUMBER
  ,CPU_PARSE_TIME                  NUMBER
  ,CPU_USED_BY_SESSION_C_DERN_PER  NUMBER
  ,CPU_RECURSIVE_C_DERN_PER        NUMBER
  ,CPU_PARSE_TIME_C_DERN_PER       NUMBER
)
TABLESPACE SDBM_DATA
MONITORING;

GRANT INSERT  ON SDBM.CD_SYSSTAT_CPU  TO SDBMSRV;

ALTER TABLE SDBM.CD_SYSSTAT_CPU
   ADD CONSTRAINT CDSC_PK_CD_SYSSTAT_CPU PRIMARY KEY (DH_COLLECTE_DONNEE, NOM_CIBLE)
      USING INDEX
      TABLESPACE SDBM_DATA;

-- CD - SYSSTAT_CPU
INSERT INTO SDBM.EVENEMENT
(
   TYPE_CIBLE
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
  ,'CD_SYSSTAT_CPU'
  ,'CD'
  ,'
SELECT SYSDATE                                                               "DH_COLLECTE_DONNEE"
      ,{NOM_CIBLE}                                                           "NOM_CIBLE"
      ,HOST_NAME                                                             "HOST_NAME"
      ,INSTANCE_NAME                                                         "INSTANCE_NAME"
      ,STARTUP_TIME                                                          "STARTUP_TIME"
      ,(SELECT VALUE FROM V$SYSSTAT WHERE NAME = ''CPU used by this session'') "CPU_USED_BY_SESSION"
      ,(SELECT VALUE FROM V$SYSSTAT WHERE NAME = ''recursive cpu usage'')      "CPU_RECURSIVE"
      ,(SELECT VALUE FROM V$SYSSTAT WHERE NAME = ''parse time cpu'')           "PARSE_TIME"
      ,TO_NUMBER(NULL)                                                       "CPU_USED_BY_SESSION_C_DERN_PER"
      ,TO_NUMBER(NULL)                                                       "CPU_RECURSIVE_C_DERN_PER"
      ,TO_NUMBER(NULL)                                                       "CPU_PARSE_TIME_C_DERN_PER"
  FROM V$INSTANCE
'
  ,'TRUNC(SYSDATE,''HH24'') + ((SUBSTR(TO_CHAR(SYSDATE,''MI''),1,1) + 1) || 0) / 1440'
  ,'---'
  ,30
);


CREATE OR REPLACE TRIGGER SDBM.CDSC_TR_MAJ_CPU_CALC_DERN_PER

/******************************************************************
  TRIGGER : CDSC_TR_MAJ_CPU_CALC_DERN_PER
  AUTEUR  : Benoit Bouthillier 2012-06-02
 ------------------------------------------------------------------
  BUT : Mise à jour de la table CD_SYSSTAT_CPU (calcul des colonnes
        C_DERN_PER).

*******************************************************************/

   BEFORE INSERT
   ON CD_SYSSTAT_CPU
   FOR EACH ROW

DECLARE

   V_DH_COLLECTE_DONNEE       CD_SYSSTAT_CPU.DH_COLLECTE_DONNEE%TYPE;
   V_HOST_NAME                CD_SYSSTAT_CPU.HOST_NAME%TYPE;
   V_INSTANCE_NAME            CD_SYSSTAT_CPU.INSTANCE_NAME%TYPE;
   V_STARTUP_TIME             CD_SYSSTAT_CPU.STARTUP_TIME%TYPE;
   V_CPU_USED_BY_SESSION_PREC CD_SYSSTAT_CPU.CPU_USED_BY_SESSION%TYPE;
   V_CPU_RECURSIVE_PREC       CD_SYSSTAT_CPU.CPU_RECURSIVE%TYPE;
   V_CPU_PARSE_TIME_PREC      CD_SYSSTAT_CPU.CPU_PARSE_TIME%TYPE;

BEGIN

   -- Recherche de la valeur précédente
   SELECT DH_COLLECTE_DONNEE
         ,HOST_NAME
         ,INSTANCE_NAME
         ,STARTUP_TIME
         ,CPU_USED_BY_SESSION
         ,CPU_RECURSIVE
         ,CPU_PARSE_TIME
     INTO V_DH_COLLECTE_DONNEE
         ,V_HOST_NAME
         ,V_INSTANCE_NAME
         ,V_STARTUP_TIME
         ,V_CPU_USED_BY_SESSION_PREC
         ,V_CPU_RECURSIVE_PREC
         ,V_CPU_PARSE_TIME_PREC
     FROM CD_SYSSTAT_CPU
    WHERE DH_COLLECTE_DONNEE = (SELECT MAX(DH_COLLECTE_DONNEE)
                                  FROM CD_SYSSTAT_CPU
                                 WHERE DH_COLLECTE_DONNEE < :NEW.DH_COLLECTE_DONNEE
                                   AND NOM_CIBLE          = :NEW.NOM_CIBLE
                               )
      AND NOM_CIBLE          = :NEW.NOM_CIBLE;

   -- Vérification pour redémarrage de l'instance
   IF (V_STARTUP_TIME = :NEW.STARTUP_TIME) THEN

      -- Situation régulière
      :NEW.CPU_USED_BY_SESSION_C_DERN_PER := ((:NEW.CPU_USED_BY_SESSION - V_CPU_USED_BY_SESSION_PREC) / 100) / ((:NEW.DH_COLLECTE_DONNEE - V_DH_COLLECTE_DONNEE) * 86400);
      :NEW.CPU_RECURSIVE_C_DERN_PER       := ((:NEW.CPU_RECURSIVE       - V_CPU_RECURSIVE_PREC      ) / 100) / ((:NEW.DH_COLLECTE_DONNEE - V_DH_COLLECTE_DONNEE) * 86400);
      :NEW.CPU_PARSE_TIME_C_DERN_PER      := ((:NEW.CPU_PARSE_TIME      - V_CPU_PARSE_TIME_PREC     ) / 100) / ((:NEW.DH_COLLECTE_DONNEE - V_DH_COLLECTE_DONNEE) * 86400);

   ELSE

      -- Redémarrage
      :NEW.CPU_USED_BY_SESSION_C_DERN_PER := ((:NEW.CPU_USED_BY_SESSION - 0) / 100) / ((:NEW.DH_COLLECTE_DONNEE - V_STARTUP_TIME) * 86400);
      :NEW.CPU_RECURSIVE_C_DERN_PER       := ((:NEW.CPU_RECURSIVE       - 0) / 100) / ((:NEW.DH_COLLECTE_DONNEE - V_STARTUP_TIME) * 86400);
      :NEW.CPU_PARSE_TIME_C_DERN_PER      := ((:NEW.CPU_PARSE_TIME      - 0) / 100) / ((:NEW.DH_COLLECTE_DONNEE - V_STARTUP_TIME) * 86400);

   END IF;


EXCEPTION

   WHEN NO_DATA_FOUND THEN

      -- Première estimation
      :NEW.CPU_USED_BY_SESSION_C_DERN_PER := ((:NEW.CPU_USED_BY_SESSION - 0) / 100) / ((:NEW.DH_COLLECTE_DONNEE - :NEW.STARTUP_TIME) * 86400);
      :NEW.CPU_RECURSIVE_C_DERN_PER       := ((:NEW.CPU_RECURSIVE       - 0) / 100) / ((:NEW.DH_COLLECTE_DONNEE - :NEW.STARTUP_TIME) * 86400);
      :NEW.CPU_PARSE_TIME_C_DERN_PER      := ((:NEW.CPU_PARSE_TIME      - 0) / 100) / ((:NEW.DH_COLLECTE_DONNEE - :NEW.STARTUP_TIME) * 86400);

END CDSC_TR_MAJ_CPU_CALC_DERN_PER;
/



@../_package/ps-sdbm_apex_util.sql
@../_package/pb-sdbm_apex_util.sql
@../_package/pb-sdbm_util.sql



CREATE OR REPLACE VIEW SDBM.APEX_TAB_EVOLUTION_FIC_BD
AS 
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
         

         
SDBMDac version = "0.05 - Beta";
SDBMSrv version = "0.13 - Beta";
+ SDBMSrv.sh





#
# Mise à jour Apex à 0.31
#

DROP VIEW SDBM.APEX_CD_ESPACE_ARCHIVED_LOG;




#
# POST-MODIFICATION
#

- Enregistrement de SDBMDAC
- Changement de la destination par défaut pour SDBMDAC


-- REPLICATION_DST
INSERT INTO SDBM.EVENEMENT
(
   TYPE_CIBLE
  ,SOUS_TYPE_CIBLE
  ,NOM_EVENEMENT
  ,COMMANDE
  ,INTERVAL_DEFAUT
  ,DESTI_NOTIF_DEFAUT
  ,DELAI_MAX_EXEC_SEC
)
VALUES
(
   'BD'
  ,'MS'
  ,'REPLICATION_DST'
  ,'
SELECT RTRIM(instance_name)
      ,''La replication de la base de données (source->distribution) '' + RTRIM(instance_name) + '' semble en problème (transactions en attentes : '' + CONVERT(varchar,cntr_value) + '').''
  FROM sys.dm_os_performance_counters OPC
 WHERE RTRIM(object_name) LIKE ''MSSQL$%:Databases''
   AND counter_name          = ''Repl. Pending Xacts''
   AND instance_name    NOT IN (''_Total'',''master'',''model'')
   AND cntr_value            > 500  /* 500 transactions en attentes max. */
'
  ,'SYSDATE + 5/1440'
  ,'---'
  ,30
);

-- REPLICATION_PUB
INSERT INTO SDBM.EVENEMENT
(
   TYPE_CIBLE
  ,SOUS_TYPE_CIBLE
  ,NOM_EVENEMENT
  ,COMMANDE
  ,INTERVAL_DEFAUT
  ,DESTI_NOTIF_DEFAUT
  ,DELAI_MAX_EXEC_SEC
)
VALUES
(
   'BD'
  ,'MS'
  ,'REPLICATION_PUB'
  ,'
SET NOCOUNT ON
USE distribution;

SELECT AGT.publisher_db + ''->'' + AGT.subscriber_db
      ,''La replication de la base de données (publisher_db : '' + AGT.publisher_db + '', subscriber_db : '' + AGT.subscriber_db + '') semble en problème (transactions en attentes : '' + CONVERT(varchar,SUM(MDS.UndelivCmdsInDistDB)) + '').'' 
  FROM dbo.MSdistribution_status AS MDS WITH (NOLOCK)
        INNER JOIN
       dbo.MSdistribution_agents AS AGT WITH (NOLOCK)
          ON AGT.id = MDS.agent_id
 GROUP BY AGT.publisher_db
         ,AGT.subscriber_db
HAVING SUM(MDS.UndelivCmdsInDistDB) > 25000  /* 25000 transactions en attentes max. */
'
  ,'SYSDATE + 5/1440'
  ,'---'
  ,60
);


INSERT INTO SDBM.EVENEMENT_DEFAUT_TRADUCTION
(
   TYPE_CIBLE
  ,SOUS_TYPE_CIBLE
  ,NOM_EVENEMENT
  ,CHAINE_FR
  ,CHAINE_AN
  ,COMMENTAIRE_FR
  ,COMMENTAIRE_AN
)
VALUES
(
   'BD'
  ,'MS'
  ,'REPLICATION_DST'
  ,'''La replication de la base de données (source->distribution) '' + RTRIM(instance_name) + '' semble en problème (transactions en attentes :'
  ,'''The replication of the database (source->distribution) '' + RTRIM(instance_name) + '' does not seem to keep up (transactions not sent yet:'
  ,'Suivi de la réplication (source vers distribution)'
  ,'Validate of the status of replication (source to distribution)'
);

INSERT INTO SDBM.EVENEMENT_DEFAUT_TRADUCTION
(
   TYPE_CIBLE
  ,SOUS_TYPE_CIBLE
  ,NOM_EVENEMENT
  ,CHAINE_FR
  ,CHAINE_AN
  ,COMMENTAIRE_FR
  ,COMMENTAIRE_AN
)
VALUES
(
   'BD'
  ,'MS'
  ,'REPLICATION_PUB'
  ,'''La replication de la base de données (publisher_db : '' + AGT.publisher_db + '', subscriber_db : '' + AGT.subscriber_db + '') semble en problème (transactions en attentes :'
  ,'''The replication of the database (publisher_db: '' + AGT.publisher_db + '', subscriber_db : '' + AGT.subscriber_db + '') does not seem to keep up (waiting transactions:'
  ,'Suivi de la réplication (distribution vers destination)

   Les privilèges suivants sont requis :
      grant select on distribution..MSdistribution_agents to [usager SDBM];
      grant select on distribution..MSdistribution_status to [usager SDBM];
'
  ,'Validate of the status of replication (distribution to destination)

   Thoses privileges are required:
      grant select on distribution..MSdistribution_agents to [SDBM user];
      grant select on distribution..MSdistribution_status to [SDBM user];
'
);
