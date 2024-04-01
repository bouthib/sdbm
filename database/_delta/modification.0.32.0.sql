-- *
-- * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
-- * Licensed under the MIT license.
-- * See LICENSE file in the project root for full license information.
-- *



---------------------------------------------
---------------------------------------------
---------------------------------------------
--  V E R S I O N   0 . 3 2  -   B e t a   --
---------------------------------------------
---------------------------------------------


alter profile DEFAULT limit PASSWORD_LIFE_TIME unlimited;


DELETE FROM SDBM.EVENEMENT
 WHERE NOM_EVENEMENT = 'CD_DBA_SEGMENTS';


UPDATE SDBM.EVENEMENT
   SET COMMANDE = REPLACE(COMMANDE,'<DATABASE>.sys','[<DATABASE>].sys')
 WHERE TYPE_CIBLE      = 'BD'
   AND SOUS_TYPE_CIBLE = 'MS'
   AND NOM_EVENEMENT IN
   (
      'SPACE'
     ,'SPACE_CRITICAL'
     ,'SPACE(LOG)'
     ,'CD_DBA_DATA_FILES'
     ,'CD_TRANSACTION_LOG'
   );


* APEX 312111 : Faire un TRIM sur le chemin par défaut (INSERT / UPDATE)
* APEX 3181   : Faire un TRIM sur le nom de la tâche (INSERT / UPDATE)
* APEX 3062   : Retirer le décode du DELETE

*

JOB-DELAYED

SELECT j.name
      ,'La tâche ' + j.name + ' s''execute depuis plus de ' + CONVERT(varchar,ISNULL(DATEDIFF(mi,p.last_batch,getdate()),0)) + ' minutes (spid = ' + CONVERT(varchar,p.spid) + ', program_name = ' + CONVERT(varchar,p.program_name) + ', last_batch = ' + CONVERT(varchar,last_batch) + ').'
  FROM master..sysprocesses p
       JOIN msdb..sysjobs j ON (substring(left(j.job_id,8),7,2)
         + substring(left(j.job_id,8),5,2)
       + substring(left(j.job_id,8),3,2)
       + substring(left(j.job_id,8),1,2)) = substring(p.program_name,32,8)
WHERE program_name like 'SQLAgent - TSQL JobStep (Job %'
  AND ISNULL(DATEDIFF(mi,p.last_batch,getdate()),0) > 15  /* Number of minutes */

Vérification des tâches SQL (tâche longue)

   Le privilège suivant est requis :
      grant select on msdb.dbo.sysjobs to [usager SDBM];
      

ARCx

SELECT 'N/A'
      ,'Attention : Les processus "ARCx" semblent être en problème (80% des "REDO LOGS" ne sont pas archivés).'
  FROM V$DATABASE
 WHERE (SELECT COUNT(1) FROM V$LOG WHERE ARCHIVED = 'NO') / (SELECT COUNT(1) FROM V$LOG) * 100 >= 80
   AND LOG_MODE != 'NOARCHIVELOG'
UNION ALL
SELECT THREAD# || ',' || SEQUENCE#
      ,'Attention : L''archivage du log ' || SEQUENCE# || ' (thread# ' || THREAD# || ') semble être en problème.'
  FROM V$LOG LOG_E
 WHERE LOG_E.ARCHIVED = 'NO'
   AND EXISTS (SELECT 1
                 FROM V$LOG LOG_I
                WHERE LOG_I.THREAD#    = LOG_E.THREAD#
                  AND LOG_I.ARCHIVED   = 'YES'
                  AND LOG_I.SEQUENCE#  > LOG_E.SEQUENCE#
              )


Activation suivi CPU ++ en production SPVM...

SPACE :  OR STATUS = 'READ ONLY'



-- Retrait des accents (ASM 11.2)
UPDATE SDBM.EVENEMENT
   SET COMMANDE = REPLACE(REPLACE(REPLACE(REPLACE(COMMANDE,'é','e'),'è','e'),'à','a'),'ê','e')
 WHERE TYPE_CIBLE       = 'BD'
   AND SOUS_TYPE_CIBLE  = 'OR'
   AND NOM_EVENEMENT   IN ('ASM.SPACE','ASM.STATUS','ASM.RAP_SPACE_HS'); 

UPDATE SDBM.EVENEMENT_DEFAUT_TRADUCTION
   SET CHAINE_FR = REPLACE(REPLACE(REPLACE(REPLACE(CHAINE_FR,'é','e'),'è','e'),'à','a'),'ê','e')
 WHERE TYPE_CIBLE       = 'BD'
   AND SOUS_TYPE_CIBLE  = 'OR'
   AND NOM_EVENEMENT   IN ('ASM.SPACE','ASM.STATUS','ASM.RAP_SPACE_HS'); 


*** DEVREQ 17-04-01 ***
-- ASM.STATUS
UPDATE SDBM.EVENEMENT
   SET COMMANDE = '
SELECT NAME
      ,''Le diskgroup '' || NAME || '' est en probleme (STATE = '' || STATE || '', OFFLINE_DISKS = '' || OFFLINE_DISKS || '')''
  FROM V$ASM_DISKGROUP
 WHERE OFFLINE_DISKS > 0
    OR STATE         = ''BROKEN''
UNION ALL
SELECT PATH
      ,''Le disque '' || NVL(PATH,'NULL') || '' semble etre en probleme (MOUNT_STATUS = '' || MOUNT_STATUS || '', HEADER_STATUS = '' || HEADER_STATUS || '')''
  FROM V$ASM_DISK
 WHERE MOUNT_STATUS  != ''CACHED''
    OR HEADER_STATUS != ''MEMBER''
'
WHERE TYPE_CIBLE      = 'BD'
  AND SOUS_TYPE_CIBLE = 'OR'
  AND NOM_EVENEMENT   = 'ASM.STATUS';


ALTER TABLE SDBM.EVENEMENT_DEFAUT_TRADUCTION
   DROP CONSTRAINT EVEDT_PK_EVENEMENT;
DROP INDEX SDBM.EVEDT_PK_EVENEMENT;

ALTER TABLE SDBM.EVENEMENT_DEFAUT_TRADUCTION
   ADD CONSTRAINT EVEDT_PK_EVENEMENT PRIMARY KEY (TYPE_CIBLE, SOUS_TYPE_CIBLE, NOM_EVENEMENT, CHAINE_FR)
      USING INDEX
      TABLESPACE SDBM_DATA;


*** DEVREQ 17-04-01 ***
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
  ,'ASM.STATUS'
  ,'''Le disque '' || NVL(PATH,''NULL'') || '' semble etre en probleme (MOUNT_STATUS = '' || MOUNT_STATUS || '', HEADER_STATUS = '' || HEADER_STATUS || '')'''
  ,'''The disk '' || NVL(PATH,''NULL'') || '' seem to be in trouble (STATE = '' || STATE || '', OFFLINE_DISKS = '' || OFFLINE_DISKS || '')'''
  ,'Vérification du statut des diskgroups ASM'
  ,'Validate the status of ASM diskgroups'
);


-- Prépration UTF8 - COMMENTAIRE
ALTER TABLE PARAMETRE_NOTIF_EXT            MODIFY COMMENTAIRE        VARCHAR2(1000 CHAR);
ALTER TABLE DESTI_NOTIF                    MODIFY COMMENTAIRE        VARCHAR2(1000 CHAR);
ALTER TABLE DESTI_NOTIF_DETAIL             MODIFY COMMENTAIRE        VARCHAR2(1000 CHAR);
ALTER TABLE CIBLE                          MODIFY COMMENTAIRE        VARCHAR2(1000 CHAR);
ALTER TABLE EVENEMENT                      MODIFY COMMENTAIRE        VARCHAR2(1000 CHAR);
ALTER TABLE EVENEMENT_DEFAUT_TRADUCTION    MODIFY COMMENTAIRE_FR     VARCHAR2(1000 CHAR);
ALTER TABLE EVENEMENT_DEFAUT_TRADUCTION    MODIFY COMMENTAIRE_AN     VARCHAR2(1000 CHAR);
ALTER TABLE DESTI_NOTIF_SURCHARGE_MESSAGE  MODIFY COMMENTAIRE        VARCHAR2(1000 CHAR);
ALTER TABLE REPARATION                     MODIFY COMMENTAIRE        VARCHAR2(1000 CHAR);
ALTER TABLE TACHE_AGT                      MODIFY COMMENTAIRE        VARCHAR2(1000 CHAR);
ALTER TABLE TACHE_DET_MSG_AGT              MODIFY COMMENTAIRE        VARCHAR2(1000 CHAR);
ALTER TABLE CD_INFO_STATIQUE_AGT           MODIFY COMMENTAIRE        VARCHAR2(1000 CHAR);

ALTER TABLE TACHE_AGT                      MODIFY PARAMETRE          VARCHAR2(1000 CHAR);

ALTER TABLE DESTI_NOTIF_SURCHARGE_MESSAGE  MODIFY MESSAGE            VARCHAR2(1000 CHAR);

ALTER TABLE CIBLE                          MODIFY CONNEXION          VARCHAR2(1000 CHAR);

ALTER TABLE DESTI_NOTIF_DETAIL             MODIFY FORMULE_NOTIF_DIF  VARCHAR2(1000 CHAR);



-- MYSQL.SESSION

SET @Threads_connected := '';
SHOW GLOBAL STATUS WHERE Variable_name = 'Threads_connected' AND (@Threads_connected := CONCAT(@Threads_connected, `Value`,'')) IS NULL;

SELECT 'N/A'
      ,CAST(CONCAT('Le nombre de connexions utilisées à atteint ',CEILING((CONVERT(@Threads_connected,UNSIGNED INTEGER) / @@GLOBAL.max_connections * 100)),'% des connexions possibles (threads_connected = ',@Threads_connected,' max_connections = ',@@GLOBAL.max_connections,').') AS CHAR(1000))
  FROM DUAL
 WHERE (CONVERT(@Threads_connected,UNSIGNED INTEGER) / @@GLOBAL.max_connections * 100) > 50

Vérification que le nombre de session n'approche pas trop de la capacité de l'instance



-- BACKUP-SQL-OPEN
DECLARE @SQLString NVARCHAR(MAX);

SET @SQLString = ' 

SELECT name
      ,''Attention : Aucune prise de copie SQL (OPEN) depuis plus de 36 heures.''
FROM master.sys.databases db
WHERE db.state_desc NOT IN (''RESTORING'',''RECOVERING'')
  AND db.name       NOT IN (''model'',''tempdb'')
  AND db.name       NOT IN (SELECT secondary_database
                            FROM msdb.dbo.log_shipping_secondary_databases
                            )
   AND NOT EXISTS (SELECT 1
                   FROM msdb.dbo.backupset
                   WHERE database_name      = db.name
                     AND type              IN (''D'',''I'')
                     AND backup_finish_date > DATEADD(hour,-36,GETDATE())
                  ) '

--SQL 2012 + plus récent > Perferred replica only--
--*Si la base de données ne fait partie d'un AG, la fonction retournera 1 - backup expected
IF OBJECT_ID('sys.fn_hadr_backup_is_preferred_replica') IS NOT NULL
BEGIN
 SET @SQLString = @SQLString + 'AND sys.fn_hadr_backup_is_preferred_replica(db.name) = 1';
END
 
EXECUTE sp_executesql @SQLString;



-- CD - DBA_DATA_FILES
UPDATE SDBM.EVENEMENT
   SET COMMANDE = '
SET NOCOUNT ON

/* Construction de la liste des bases de données à traitées */
IF OBJECT_ID(''sys.dm_hadr_database_replica_states'') IS NULL

   /* Sans Always-on */
   DECLARE c_database CURSOR FOR
      SELECT name
        FROM master.sys.databases
       WHERE state_desc       = ''ONLINE''
         AND user_access_desc = ''MULTI_USER''
         AND name        NOT IN (SELECT secondary_database FROM msdb.dbo.log_shipping_secondary_databases)

ELSE

   /* Avec Always-on */
   DECLARE c_database CURSOR FOR
      SELECT name
        FROM master.sys.databases
       WHERE state_desc       = ''ONLINE''
         AND user_access_desc = ''MULTI_USER''
         AND name        NOT IN (SELECT secondary_database FROM msdb.dbo.log_shipping_secondary_databases)
         AND database_id NOT IN (SELECT RS.database_id FROM master.sys.dm_hadr_database_replica_states AS RS, master.sys.dm_hadr_availability_replica_states AS AR WHERE RS.replica_id = AR.replica_id AND RS.group_id = AR.group_id AND AR.is_local = 1 AND AR.role_desc  <> ''PRIMARY'')

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
  FROM                 [<DATABASE>].sys.database_files     dbf
       LEFT OUTER JOIN [<DATABASE>].sys.allocation_units   alu  ON dbf.data_space_id = alu.data_space_id
            INNER JOIN [<DATABASE>].sys.sysfiles           fil  ON dbf.file_id       = fil.fileid
            INNER JOIN [<DATABASE>].sys.sysfilegroups      grp  ON fil.groupid       = grp.groupid
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
 WHERE TYPE_CIBLE      = 'BD'
   AND SOUS_TYPE_CIBLE = 'MS'
   AND NOM_EVENEMENT   = 'CD_DBA_DATA_FILES';


-- CD - TRANSACTION_LOG
UPDATE SDBM.EVENEMENT
   SET COMMANDE = '
SET NOCOUNT ON

IF OBJECT_ID(''sys.dm_hadr_database_replica_states'') IS NULL

   DECLARE c_database CURSOR FOR
      SELECT name
        FROM master.sys.databases
       WHERE state_desc       = ''ONLINE''
         AND user_access_desc = ''MULTI_USER''
         AND name        NOT IN (SELECT secondary_database FROM msdb.dbo.log_shipping_secondary_databases)

ELSE

   DECLARE c_database CURSOR FOR
      SELECT name
        FROM master.sys.databases
       WHERE state_desc       = ''ONLINE''
         AND user_access_desc = ''MULTI_USER''
         AND name        NOT IN (SELECT secondary_database FROM msdb.dbo.log_shipping_secondary_databases)
         AND database_id NOT IN (SELECT RS.database_id FROM master.sys.dm_hadr_database_replica_states AS RS, master.sys.dm_hadr_availability_replica_states AS AR WHERE RS.replica_id = AR.replica_id AND RS.group_id = AR.group_id AND AR.is_local = 1 AND AR.role_desc  <> ''PRIMARY'')

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
   SELECT ''''<DATABASE>'''' AS "DATABASE"
         ,SUM(USED_SPACE.USED_SPACE) AS "USED_SPACE"
         ,SUM(
                (
                   CASE
                      WHEN TOTAL_SPACE.SIZE < TOTAL_SPACE.MAX_SIZE

                         THEN TOTAL_SPACE.MAX_SIZE
                         ELSE TOTAL_SPACE.SIZE
                   END
                )
             ) AS "TOTAL_SPACE"

     FROM (
            /* Used space per file with AUTOGROWTH */
            SELECT fil.filename AS "DATA_FILE"
                  ,(CONVERT(numeric,fil.size) * 8) * 1024 AS "SIZE"
                  ,(
                       CASE fil.maxsize
                          WHEN -1 THEN
                             CONVERT(numeric,268435456)   * 8 * 1024 /* APPROX. 2T */
                          ELSE
                             CONVERT(numeric,fil.maxsize) * 8 * 1024
                       END
                   )
                   * (CASE fil.growth WHEN 0 THEN 0 ELSE 1 END) AS "MAX_SIZE"
              FROM [<DATABASE>].sys.sysfiles fil

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
      ,{NOM_CIBLE} "NOM_CIBLE"
      ,TDS.database_name  "DATABASE_NAME"
      ,CONVERT(varchar,DATABASEPROPERTYEX(TDS.database_name,''Recovery'')) "RECOVERY_MODE"
      ,TDS.total_space  "TOTAL_SPACE"
      ,TDS.used_space  "USED_SPACE"
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
 WHERE TYPE_CIBLE      = 'BD'
   AND SOUS_TYPE_CIBLE = 'MS'
   AND NOM_EVENEMENT   = 'CD_TRANSACTION_LOG';


DROP TRIGGER SDBM.USA_TR_BIU_USAGER;
CREATE OR REPLACE TRIGGER SDBM.USA_TR_BIU_MOT_PASSE

/******************************************************************
  TRIGGER : USA_TR_BIU_MOT_PASSE
  AUTEUR  : Benoit Bouthillier 2008-06-27
 ------------------------------------------------------------------
  BUT : Mise à jour des enregistrement de contrôle et encryption du
        mot de passe s'il y a lieu.

*******************************************************************/

   BEFORE INSERT OR UPDATE
   ON USAGER
   FOR EACH ROW

BEGIN

   IF (INSERTING) THEN

      -- Traitement du nom de l'usager et du mot de passe
      :NEW.NOM_USAGER      := UPPER(:NEW.NOM_USAGER);
      :NEW.MOT_PASSE       := SDBM_APEX_UTIL.ENCRYPTER_MDP_USAGER(:NEW.NOM_USAGER,:NEW.MOT_PASSE);

      :NEW.USAGER_CREATION := NVL(V('APP_USER'),'N/A');

   ELSE
   
      -- Validation (le code d'usager ne peut pas être modifié)
      IF (:OLD.NOM_USAGER <> :NEW.NOM_USAGER) THEN
         RAISE_APPLICATION_ERROR(-20000,'Le code usager ne peut être modifié.');
      END IF;

      -- Si la modification est autre chose qu'une connexion
      IF (UPDATING('DH_DERN_CONNEXION') = FALSE) THEN

         IF (UPDATING('MOT_PASSE')) THEN
            :NEW.MOT_PASSE      := SDBM_APEX_UTIL.ENCRYPTER_MDP_USAGER(:OLD.NOM_USAGER,:NEW.MOT_PASSE);
         END IF;

         :NEW.DH_DERN_MODIF     := SYSDATE;
         :NEW.USAGER_DERN_MODIF := NVL(V('APP_USER'),'N/A');

      END IF;

   END IF;

END USA_TR_BIU_MOT_PASSE;
/


ALTER TABLE USAGER    MODIFY MOT_PASSE       VARCHAR2(40 CHAR);
ALTER TABLE CIBLE     MODIFY MDP_USAGER      VARCHAR2(512 CHAR);
ALTER TABLE PARAMETRE MODIFY MDP_USAGER_SMTP VARCHAR2(512 CHAR);
@../_package/pb-sdbm_util.sql

-- Correction et changement de l'algorythme de protection des mots de passe usager (AL32UTF8 + HASH)
-- *************************************************************************************************
-- * voir "Correction des mots de passe - UTF8 + mise à jour à DBMS_CRYPTO" dans MigrationSDBM.sql *
-- *************************************************************************************************
