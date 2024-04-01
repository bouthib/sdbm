-- *
-- * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
-- * Licensed under the MIT license.
-- * See LICENSE file in the project root for full license information.
-- *


WHENEVER OSERROR  EXIT 8
WHENEVER SQLERROR EXIT SQL.SQLCODE


CONNECT / as sysdba
alter session set container = XEPDB1;

SET ECHO         ON
SET SQLBLANKLINE ON



-- Usager ADMIN - APEX
INSERT INTO SDBM.USAGER
(
   NOM_USAGER
  ,MOT_PASSE
  ,NIVEAU_SEC
)
VALUES
(
   'ADMIN'
  ,'admin'
  ,'Administrateurs'
);


-- Fin de la transaction
COMMIT;




--
-- Création de la destination par défaut "N/D"
--
INSERT INTO SDBM.DESTI_NOTIF
(
   DESTI_NOTIF
  ,COMMENTAIRE
)
VALUES
(
   '---'
  ,'---'
);



--
-- Création des événements de base SDBM / Oracle
--

-- ALERT
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
  ,'OR'
  ,'ALERT'
  ,'AG'
  ,'N/A'
  ,'N/A'
  ,'---'
  ,30
);


INSERT INTO SDBM.DESTI_NOTIF_SURCHARGE_MESSAGE
(
   TYPE_CIBLE
  ,SOUS_TYPE_CIBLE
  ,NOM_EVENEMENT
  ,SEQ_SURCHARGE
  ,DESC_SURCHARGE
  ,MESSAGE
  ,DESTI_NOTIF
  ,COMMENTAIRE
)
VALUES
(
   'BD'
  ,'OR'
  ,'ALERT'
  ,1
  ,'ORA-00600'
  ,'ORA-00600'
  ,'---'
  ,'Special handling of ORA-00600 messages / Gestion particulière des messages ORA-00600'
);


-- TEST
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
  ,'TEST'
  ,'
SELECT ''N/A''
      ,''Ceci est un test.''
  FROM DUAL
 WHERE MOD(TO_CHAR(SYSDATE,''MI''),2) = 0
'
  ,'SYSDATE + 30/86400'
  ,'---'
  ,30
);


-- ASM.SPACE
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
  ,'ASM.SPACE'
  ,'
SELECT NAME
      ,''Le diskgroup '' || NAME || '' est utilise a '' || TO_CHAR((ESPACE_TOTAL - ESPACE_LIBRE) / ESPACE_TOTAL * 100,''FM990.00'') || ''% (espace libre : '' || ESPACE_LIBRE || ''M)''
  FROM (
          SELECT NAME
                ,ROUND(TOTAL_MB / DECODE(TYPE
                                        ,''EXTERN'',1
                                        ,''NORMAL'',2
                                        ,''HIGH'',3
                                        )
                      ,0
                      )
                 "ESPACE_TOTAL"
                ,FREE_MB / DECODE(TYPE
                                 ,''EXTERN'',1
                                 ,''NORMAL'',2
                                 ,''HIGH'',3
                                 )
                 "ESPACE_LIBRE"
            FROM V$ASM_DISKGROUP
       )
 WHERE (ESPACE_TOTAL - ESPACE_LIBRE) / ESPACE_TOTAL * 100 > 75
   AND ESPACE_LIBRE                                       < 10240
'
  ,'SYSDATE + 60/1440'
  ,'---'
  ,30
);


-- ASM.STATUS
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
  ,'ASM.STATUS'
  ,'
SELECT NAME
      ,''Le diskgroup '' || NAME || '' est en probleme (STATE = '' || STATE || '', OFFLINE_DISKS = '' || OFFLINE_DISKS || '')''
  FROM V$ASM_DISKGROUP
 WHERE OFFLINE_DISKS > 0
    OR STATE         = ''BROKEN''
UNION ALL
SELECT PATH
      ,''Le disque '' || PATH || '' semble etre en probleme (MOUNT_STATUS = '' || MOUNT_STATUS || '', HEADER_STATUS = '' || HEADER_STATUS || '')''
  FROM V$ASM_DISK
 WHERE MOUNT_STATUS  != ''CACHED''
    OR HEADER_STATUS != ''MEMBER''
'
  ,'SYSDATE + 60/1440'
  ,'---'
  ,30
);


-- ARCx
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
  ,'ARCx'
  ,'
SELECT ''N/A''
      ,''Attention : Les processus "ARCx" semblent être en problème (80% des "REDO LOGS" ne sont pas archivés).''
  FROM V$DATABASE
 WHERE (SELECT COUNT(1) FROM V$LOG WHERE ARCHIVED = ''NO'') / (SELECT COUNT(1) FROM V$LOG) * 100 >= 80
   AND LOG_MODE != ''NOARCHIVELOG''
UNION ALL
SELECT THREAD# || '','' || SEQUENCE#
      ,''Attention : L''''archivage du log '' || SEQUENCE# || '' (thread# '' || THREAD# || '') semble être en problème.''
  FROM V$LOG LOG_E
 WHERE LOG_E.ARCHIVED = ''NO''
   AND EXISTS (SELECT 1
                 FROM V$LOG LOG_I
                WHERE LOG_I.THREAD#    = LOG_E.THREAD#
                  AND LOG_I.ARCHIVED   = ''YES''
                  AND LOG_I.SEQUENCE#  > LOG_E.SEQUENCE#
              )
'
  ,'SYSDATE + 2/1440'
  ,'---'
  ,30
);


-- BLOCKING_LOCKS
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
  ,'BLOCKING_LOCKS'
  ,'
SELECT GL1.SID || '' ('' || INS.INSTANCE_NAME || '')''
      ,''La session '' || GL1.SID || '' (SID), '' || INS.INSTANCE_NAME || '' (INSTANCE), ''
       || (SELECT NVL(USERNAME,''NULL'')
             FROM GV$SESSION
            WHERE INST_ID = GL1.INST_ID
              AND SID     = GL1.SID
          )
       || '' (USERNAME) est en attente d''''un lock sur l''''objet ''
       || NVL((SELECT OWNER || ''.'' || OBJECT_NAME
                 FROM DBA_OBJECTS      OBJ
                     ,GV$LOCKED_OBJECT LKO
                WHERE OBJ.OBJECT_ID  = LKO.OBJECT_ID
                  AND LKO.INST_ID    = GL1.INST_ID
                  AND LKO.SESSION_ID = GL1.SID
                  AND ROWNUM        <= 1
              )
             ,GL1.ID1
             )
       || '' (mode requis : '' || DECODE(GL1.REQUEST
                                      ,0,''None''
                                      ,1,''Null''
                                      ,2,''Row share''
                                      ,3,''Row exclusive''
                                      ,4,''Share''
                                      ,5,''Share + Row exclusive''
                                      ,6,''Exclusive''
                                      ,GL1.REQUEST
                                      )
       || '') depuis '' || GL1.CTIME || '' secondes.''
       || NVL((SELECT '' La session '' || ML1.SID || '' (SID), ''
                                     || MIN.INSTANCE_NAME || '' (INSTANCE) détient la ressource requise (mode : '' || DECODE(ML1.LMODE
                                                                                                                          ,0,''None''
                                                                                                                          ,1,''Null''
                                                                                                                          ,2,''Row share''
                                                                                                                          ,3,''Row exclusive''
                                                                                                                          ,4,''Share''
                                                                                                                          ,5,''Share + Row exclusive''
                                                                                                                          ,6,''Exclusive''
                                                                                                                          ,ML1.LMODE
                                                                                                                          )
                      || '') depuis plus de '' || ML1.CTIME || '' secondes.''
                 FROM GV$LOCK     ML1
                     ,GV$INSTANCE MIN
                WHERE ML1.INST_ID = MIN.INST_ID
                  AND ML1.ID1     = GL1.ID1
                  AND ML1.BLOCK  != 0
                  AND ROWNUM     <= 1
              )
             ,'' Impossible d''''obtenir l''''information sur la session qui détient la ressource.''
             )
  FROM GV$LOCK     GL1
      ,GV$INSTANCE INS
 WHERE GL1.INST_ID  = INS.INST_ID
   AND GL1.BLOCK    = 0
   AND GL1.REQUEST != 0
   AND GL1.CTIME    > 300 /* 5 minutes */
'
  ,'SYSDATE + 5/1440'
  ,'---'
  ,30
);


-- CORRUPTION
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
  ,'CORRUPTION'
  ,'
SELECT ''N/A'' 
      ,''Corruption de la base de données détectée (V$BACKUP_CORRUPTION : '' || COUNT_BBC || '', V$DATABASE_BLOCK_CORRUPTION : '' || COUNT_DBC || '').''  
  FROM (SELECT COUNT(1) "COUNT_BBC" FROM V$BACKUP_CORRUPTION)
      ,(SELECT COUNT(1) "COUNT_DBC" FROM V$DATABASE_BLOCK_CORRUPTION)
      ,DUAL
 WHERE COUNT_BBC != 0 OR COUNT_DBC != 0
'
  ,'SYSDATE + 10/1440'
  ,'---'
  ,30
);


-- DBA_2PC_PENDING
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
  ,'DBA_2PC_PENDING'
  ,'
SELECT ''N/A''
      ,''Attention : transactions dans DBA_2PC_PENDING.''
  FROM DBA_2PC_PENDING
 GROUP BY ''N/A''
         ,''Attention : transactions dans DBA_2PC_PENDING.''
'
  ,'SYSDATE + 2/1440'
  ,'---'
  ,30
);


-- DEFERROR
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
  ,'DEFERROR'
  ,'
SELECT ''N/A''
      ,''Attention : transactions dans DEFERROR.''
  FROM DEFERROR
 GROUP BY ''N/A''
         ,''Attention : transactions dans DEFERROR.''
'
  ,'SYSDATE + 2/1440'
  ,'---'
  ,30
);


-- FILE_STATUS
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
  ,'FILE_STATUS'
  ,'
SELECT FILE# || '' (FILE#)''
      ,''Le fichier '' || NAME || '' n''''a pas un statut normal (STATUS = '' || STATUS || '').''
  FROM V$DATAFILE
 WHERE STATUS NOT IN (''SYSTEM'',''ONLINE'')
'
  ,'SYSDATE + 5/1440'
  ,'---'
  ,30
);


-- FILE_UNRECOVERABLE
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
  ,'FILE_UNRECOVERABLE'
  ,'
SELECT FILE# || '' (FILE#)''
      ,''Le fichier '' || NAME || '' n''''est pas recupérable actuellement via RMAN (UNRECOVERABLE_TIME = '' || TO_CHAR(UNRECOVERABLE_TIME,''YYYY/MM/DD:HH24:MI:SS'') || '').''
  FROM V$DATAFILE DBF
 WHERE UNRECOVERABLE_TIME IS NOT NULL
   AND NOT EXISTS (SELECT 1
                     FROM V$BACKUP_DATAFILE
                    WHERE FILE#           = DBF.FILE#
                      AND COMPLETION_TIME > DBF.UNRECOVERABLE_TIME
                  ) 
'
  ,'SYSDATE + 60/1440'
  ,'---'
  ,30
);


-- JOB-BROKEN
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
  ,'JOB-BROKEN'
  ,'
SELECT TO_CHAR(JOB)
      ,''La tâche '' || JOB || '' ('' || SUBSTR(WHAT,1,75) || '') est ''''BROKEN''''.''
  FROM DBA_JOBS
 WHERE BROKEN = ''Y''
'
  ,'SYSDATE + 5/1440'
  ,'---'
  ,30
);


-- JOB-FAILURES
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
  ,'JOB-FAILURES'
  ,'
SELECT TO_CHAR(JOB)
      ,''La tâche '' || JOB || '' ('' || SUBSTR(WHAT,1,75) || '') à 10 ''''FAILURES'''' ou plus.''
  FROM DBA_JOBS
 WHERE FAILURES >= 10
'
  ,'SYSDATE + 5/1440'
  ,'---'
  ,30
);


-- JOB-DELAYED
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
  ,'JOB-DELAYED'
  ,'
SELECT /*+ RULE */ TO_CHAR(JOB)
      ,''Retard d''''exécution sur la tâche '' || JOB || '' ('' || SUBSTR(WHAT,1,75) || '').''
  FROM DBA_JOBS
 WHERE /* Job has not started on time */
       (
              NEXT_DATE < (SYSDATE - 15/1440)
          AND THIS_DATE IS NULL
       )
       /* Job is executing for more than 1 hour (exception : DBMS_STATS.GATHER) */
    OR (
              THIS_DATE < SYSDATE - 1/24
          AND UPPER(WHAT) NOT LIKE ''%DBMS_STATS.GATHER%''
       )
       /* Job is executing for more than 4 hour (no exception) */
    OR (
          THIS_DATE < SYSDATE - 4/24
       )
'
  ,'SYSDATE + 5/1440'
  ,'---'
  ,30
);


-- LOGSTDBY.APPLY
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
  ,'LOGSTDBY.APPLY'
  ,'
SELECT ''N/A''
      ,''Attention : Le processus APPLY semble être en retard (voir DBA_LOGSTDBY_PROGRESS, APPLIED_TIME = '' || TO_CHAR(APPLIED_TIME,''YYYY/MM/DD:HH24:MI:SS'') || '').''
  FROM DBA_LOGSTDBY_PROGRESS
 WHERE (NEWEST_TIME - APPLIED_TIME) * 1440 > 15
'
  ,'SYSDATE + 10/1440'
  ,'---'
  ,30
);


-- LOGSTDBY.EVENTS
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
  ,'LOGSTDBY.EVENTS'
  ,'
SELECT ''ORA-'' || LPAD(STATUS_CODE,5,''0'')
      ,''Attention : '' || COUNT(1) || '' nouveau(x) enregistrement(s) de ce type dans DBA_LOGSTDBY_EVENTS pour les 15 dernières minutes.''
  FROM DBA_LOGSTDBY_EVENTS
 WHERE EVENT_TIME > SYSDATE - 15/1440
   AND STATUS_CODE NOT IN (448,16110,16111,16128,16200,16201,16204,16205)
 GROUP BY STATUS_CODE
'
  ,'SYSDATE + 10/1440'
  ,'---'
  ,30
);


-- LOGSTDBY.RECEPTION
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
  ,'LOGSTDBY.RECEPTION'
  ,'
SELECT ''N/A''
      ,''Attention : Aucune réception de REDO depuis plus de 90 minutes (voir DBA_LOGSTDBY_PROGRESS, NEWEST_TIME = '' || TO_CHAR(NEWEST_TIME,''YYYY/MM/DD:HH24:MI:SS'') || '').''
  FROM DBA_LOGSTDBY_PROGRESS
 WHERE NEWEST_TIME < SYSDATE - 90/1440
'
  ,'SYSDATE + 10/1440'
  ,'---'
  ,30
);


-- PHYSTDBY.STATUS
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
  ,'PHYSTDBY.STATUS'
  ,'
SELECT ''N/A''
      ,''Le standby database ne semble plus suivre la base de données primaire (la différence est de '' || TO_CHAR(TRUNC((SYSDATE - CONTROLFILE_TIME) * 1440)) || '' minutes)''
  FROM V$DATABASE
 WHERE (SYSDATE - CONTROLFILE_TIME) * 1440 > 720
'
  ,'SYSDATE + 60/1440'
  ,'---'
  ,30
);


-- RMAN_ARCHIVE
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
  ,'RMAN_ARCHIVE'
  ,'
SELECT ''N/A''
      ,NB_ARCHIVED_LOG || '' "archived log(s)" semble(nt) ne pas avoir été détruit(s) (donc sauvegardé(s)) dans RMAN depuis le '' || TO_CHAR(DEPUIS,''YYYY/MM/DD:HH24:MI:SS'') || ''.''
   FROM (
         SELECT COUNT(1)             "NB_ARCHIVED_LOG"
               ,MIN(COMPLETION_TIME) "DEPUIS"
           FROM V$ARCHIVED_LOG
          WHERE DELETED         = ''NO''
            AND STANDBY_DEST    = ''NO''
            AND COMPLETION_TIME < SYSDATE - 7
       )
 WHERE NB_ARCHIVED_LOG != 0
   AND EXISTS (SELECT 1
                 FROM V$DATABASE
                WHERE LOG_MODE != ''NOARCHIVELOG''
              ) 
'
  ,'TRUNC(SYSDATE) + 1 + 9/24'
  ,'---'
  ,30
);


-- RMAN_DATAFILE
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
  ,'RMAN_DATAFILE'
  ,'
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
  ,'TRUNC(SYSDATE) + 1 + 9/24'
  ,'---'
  ,30
);


-- SDBM.CPU_NO_IDLE
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
  ,'SDBM.CPU_NO_IDLE'
  ,'
SELECT NOM_SERVEUR
      ,''Le serveur '' || NOM_SERVEUR || '' semble être très solicité (CPU IDLE = '' || TO_CHAR(ROUND(AVG(CPU_IDLE_TIME),2),''0.00'') || ''%).''
  FROM SDBM.CD_INFO_DYNAMIQUE_AGT
 WHERE DH_COLLECTE_DONNEE > SYSDATE - 10/1440
   AND TYPE_INFO     = ''BR''
   AND CPU_IDLE_TIME < 0.01
 GROUP BY NOM_SERVEUR HAVING COUNT(*) >= 7
'
  ,'SYSDATE + 2/1440'
  ,'---'
  ,30
);


-- SDBM.ERROR
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
  ,'SDBM.ERROR'
  ,'
SELECT ''N/A''
      ,''Attention : '' || COUNT(1) || '' nouveau(x) enregistrement(s) dans le journal SDBM depuis '' || TO_CHAR({LAST_SYSDATE},''YYYY/MM/DD HH24:MI:SS'') || ''.''
  FROM SDBM.JOURNAL
 WHERE DH_JOURNAL >= {LAST_SYSDATE}
   AND NIVEAU NOT IN (''INFO'',''CONFIG'')
 HAVING COUNT(1) > 0
'
  ,'SYSDATE + 60/1440'
  ,'---'
  ,30
);

-- SDBM.JOB
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
  ,'SDBM.JOB'
  ,'
SELECT ''('' || NOM_SERVEUR || '','' || NOM_TACHE || '')''
      ,''La tâche '' || NOM_TACHE || '' (agent : '' || NOM_SERVEUR || '') aurait du être soumise depuis '' || TO_CHAR(DH_PROCHAINE_EXEC,''YYYY/MM/DD:HH24:MI:SS'') || ''.''
  FROM SDBM.TACHE_AGT TAG
 WHERE EXECUTION         = ''AC''
   AND DH_PROCHAINE_EXEC < SYSDATE - (SELECT (FREQU_VERIF_AGENT_TACHE + 60) / 86400 FROM SDBM.PARAMETRE)
   AND EXISTS (SELECT 1
                 FROM SDBM.PARAMETRE
                WHERE STATUT_AGENT = ''AC''
              )
   AND NOT EXISTS (SELECT 1
                     FROM SDBM.HIST_TACHE_AGT
                    WHERE NOM_SERVEUR  = TAG.NOM_SERVEUR
                      AND NOM_TACHE    = TAG.NOM_TACHE
                      AND STATUT_EXEC  IN (''SB'',''SR'',''EX'',''EV'')
                  )
'
  ,'SYSDATE + 15/1440'
  ,'---'
  ,30
);


-- SDBM.SDBMAGT
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
  ,'SDBM.SDBMAGT'
  ,'
SELECT SERVEUR
      ,''L''''agent SDBMAgt - SDBM ne semble pas fonctionnel sur '' || SERVEUR || ''.'' 
  FROM SDBM.APEX_STATUT_SESSION_SDBM
 WHERE MISE_EN_EVIDENCE = 3
   AND MODULE        LIKE ''SDBMAGT%''
'
  ,'SYSDATE + 60/1440'
  ,'---'
  ,30
);


-- SDBM.SDBMSRV
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
  ,'SDBM.SDBMSRV'
  ,'
SELECT ''N/A''
      ,''Le service principal SDBMSrv - SDBM ne semble pas fonctionnel.'' 
  FROM SDBM.APEX_STATUT_SESSION_SDBM
 WHERE MISE_EN_EVIDENCE IN (3,5)
   AND MODULE         LIKE ''SDBMSRV%''
'
  ,'SYSDATE + 15/1440'
  ,'---'
  ,30
);


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


-- SDBM.WARNING
INSERT INTO SDBM.EVENEMENT
(
   TYPE_CIBLE
  ,SOUS_TYPE_CIBLE
  ,NOM_EVENEMENT
  ,TYPE_FERMETURE
  ,COMMANDE
  ,INTERVAL_DEFAUT
  ,DESTI_NOTIF_DEFAUT
  ,DELAI_MAX_EXEC_SEC
)
VALUES
(
   'BD'
  ,'OR'
  ,'SDBM.WARNING'
  ,'AU'
  ,'
SELECT REPLACE(SUBSTR(SUBSTR(TEXTE,25),1,INSTR(SUBSTR(TEXTE,25),'' ('',INSTR(SUBSTR(TEXTE,25),'' target'')) - 1),'' target'','''')
      ,TO_CHAR(DH_JOURNAL,''YYYY/MM/DD:HH24:MI:SS'') || '' : '' || TEXTE
  FROM SDBM.JOURNAL
 WHERE DH_JOURNAL >= {LAST_SYSDATE}
   AND SOURCE   = ''SDBMSrv''
   AND NIVEAU   = ''WARNING''
   AND TEXTE LIKE ''Unable to process event %''
'
  ,'SYSDATE + 15/1440'
  ,'---'
  ,30
);


-- SEQUENCE
INSERT INTO SDBM.EVENEMENT
(
   TYPE_CIBLE
  ,SOUS_TYPE_CIBLE
  ,NOM_EVENEMENT
  ,TYPE_FERMETURE
  ,COMMANDE
  ,INTERVAL_DEFAUT
  ,DESTI_NOTIF_DEFAUT
  ,DELAI_MAX_EXEC_SEC
)
VALUES
(
   'BD'
  ,'OR'
  ,'SEQUENCE'
  ,'AU'
  ,'
SELECT SEQUENCE_OWNER || ''.'' || SEQUENCE_NAME
      ,''La séquence '' || SEQUENCE_OWNER || ''.'' || SEQUENCE_NAME || '' est utilisé à '' || TO_CHAR((LAST_NUMBER - MIN_VALUE) / (MAX_VALUE - MIN_VALUE) * 100,''FM990.00'') || ''% (nombre disponible = '' || (MAX_VALUE - LAST_NUMBER) || '')''
  FROM DBA_SEQUENCES
 WHERE (LAST_NUMBER - MIN_VALUE) / (MAX_VALUE - MIN_VALUE) * 100 > 85
   AND CYCLE_FLAG = ''N''
'
  ,'TRUNC(NEXT_DAY(SYSDATE, ''MONDAY'')) + 1 + 9/24'
  ,'---'
  ,30
);


-- SESSION
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
  ,'SESSION'
  ,'
SELECT INST.INSTANCE_NAME
      ,''Le nombre de session approche de la capacité de l''''instance '' || INST.INSTANCE_NAME || '' ('' || PROC.NB_SESSION || ''/'' || PARA.NB_PROCESS || '' : '' || TO_CHAR(ROUND((PROC.NB_SESSION / PARA.NB_PROCESS) * 100)) || ''%).''
  FROM GV$INSTANCE
       "INST"
      ,(SELECT INST_ID  "INST_ID"
              ,VALUE    "NB_PROCESS"
          FROM GV$PARAMETER
         WHERE NAME = ''processes''
         GROUP BY INST_ID
                 ,VALUE
       ) "PARA"
      ,(SELECT INST_ID  "INST_ID"
              ,COUNT(1) "NB_SESSION"
          FROM GV$PROCESS
         GROUP BY INST_ID
       ) "PROC"
 WHERE INST.INST_ID = PARA.INST_ID
   AND INST.INST_ID = PROC.INST_ID
   AND (PROC.NB_SESSION / PARA.NB_PROCESS) * 100 > 90
'
  ,'SYSDATE + 5/1440'
  ,'---'
  ,30
);


-- SPACE
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
  ,'SPACE'
  ,'
SELECT TABLESPACE_NAME 
      ,''Le tablespace '' || TABLESPACE_NAME || '' est utilisé à '' || TO_CHAR(POURCENTAGE,''FM990.00'') || ''% (espace libre : '' || LIBRE || ''M)'' 
  FROM (  
         SELECT DDF.TABLESPACE_NAME                                              "TABLESPACE_NAME" 
               ,(SUM(DDF.BYTES) - SUM(NVL(DFS.BYTES,0))) / SUM(DDF.BYTES) * 100  "POURCENTAGE" 
               ,TRUNC(SUM(NVL(DFS.BYTES,0)) / 1024 / 1024)                       "LIBRE" 
           FROM ( 
                   SELECT TABLESPACE_NAME                                 "TABLESPACE_NAME" 
                         ,SUM(DECODE(AUTOEXTENSIBLE 
                                    ,''YES'',( 
                                              CASE WHEN MAXBYTES > BYTES 
                                                 THEN 
                                                    MAXBYTES 
                                                 ELSE 
                                                    BYTES 
                                                 END 
                                           ) 
                                    ,BYTES 
                                    ) 
                             )                                            "BYTES" 
                     FROM DBA_DATA_FILES 
                    GROUP BY TABLESPACE_NAME 
                ) 
                DDF 
               ,(SELECT TABLESPACE_NAME "TABLESPACE_NAME" 
                       ,SUM(BYTES)      "BYTES" 
                   FROM ( 
                           /* Free space - normal file */ 
                           SELECT TABLESPACE_NAME                                           "TABLESPACE_NAME" 
                                 ,SUM(BYTES)                                                "BYTES" 
                             FROM DBA_FREE_SPACE 
                            GROUP BY TABLESPACE_NAME 
                           UNION ALL 
                           /* Free space - AUTOEXTEND file */ 
                           SELECT TABLESPACE_NAME                                           "TABLESPACE_NAME" 
                                 ,SUM(MAXBYTES - BYTES)                                     "BYTES" 
                             FROM DBA_DATA_FILES 
                            WHERE AUTOEXTENSIBLE = ''YES'' 
                              AND MAXBYTES       > BYTES 
                            GROUP BY TABLESPACE_NAME 
                        ) 
                  GROUP BY TABLESPACE_NAME 
                ) 
                DFS 
          WHERE DDF.TABLESPACE_NAME = DFS.TABLESPACE_NAME(+) 
          GROUP BY DDF.TABLESPACE_NAME 
       ) 
 WHERE TABLESPACE_NAME NOT IN (''ROLLBACK'')
   AND TABLESPACE_NAME NOT IN (SELECT TABLESPACE_NAME FROM DBA_TABLESPACES WHERE CONTENTS IN (''UNDO'',''TEMPORARY'') OR STATUS = ''READ ONLY'') 
   AND POURCENTAGE      > 90    /* Used space > 90% and */ 
   AND LIBRE            < 1536  /* Free space < 1.5GB   */ 
'
  ,'SYSDATE + 60/1440'
  ,'---'
  ,30
);


-- SPACE_CRITICAL
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
  ,'SPACE_CRITICAL'
  ,'
SELECT TABLESPACE_NAME 
      ,''Le tablespace '' || TABLESPACE_NAME || '' est utilisé à '' || TO_CHAR(POURCENTAGE,''FM990.00'') || ''% (espace libre : '' || LIBRE || ''M)'' 
  FROM (  
         SELECT DDF.TABLESPACE_NAME                                              "TABLESPACE_NAME" 
               ,(SUM(DDF.BYTES) - SUM(NVL(DFS.BYTES,0))) / SUM(DDF.BYTES) * 100  "POURCENTAGE" 
               ,TRUNC(SUM(NVL(DFS.BYTES,0)) / 1024 / 1024)                       "LIBRE" 
           FROM ( 
                   SELECT TABLESPACE_NAME                                 "TABLESPACE_NAME" 
                         ,SUM(DECODE(AUTOEXTENSIBLE 
                                    ,''YES'',( 
                                              CASE WHEN MAXBYTES > BYTES 
                                                 THEN 
                                                    MAXBYTES 
                                                 ELSE 
                                                    BYTES 
                                                 END 
                                           ) 
                                    ,BYTES 
                                    ) 
                             )                                            "BYTES" 
                     FROM DBA_DATA_FILES 
                    GROUP BY TABLESPACE_NAME 
                ) 
                DDF 
               ,(SELECT TABLESPACE_NAME "TABLESPACE_NAME" 
                       ,SUM(BYTES)      "BYTES" 
                   FROM ( 
                           /* Free space - normal file */ 
                           SELECT TABLESPACE_NAME                                           "TABLESPACE_NAME" 
                                 ,SUM(BYTES)                                                "BYTES" 
                             FROM DBA_FREE_SPACE 
                            GROUP BY TABLESPACE_NAME 
                           UNION ALL 
                           /* Free space - AUTOEXTEND file */ 
                           SELECT TABLESPACE_NAME                                           "TABLESPACE_NAME" 
                                 ,SUM(MAXBYTES - BYTES)                                     "BYTES" 
                             FROM DBA_DATA_FILES 
                            WHERE AUTOEXTENSIBLE = ''YES'' 
                              AND MAXBYTES       > BYTES 
                            GROUP BY TABLESPACE_NAME 
                        ) 
                  GROUP BY TABLESPACE_NAME 
                ) 
                DFS 
          WHERE DDF.TABLESPACE_NAME = DFS.TABLESPACE_NAME(+) 
          GROUP BY DDF.TABLESPACE_NAME 
       ) 
 WHERE TABLESPACE_NAME NOT IN (''ROLLBACK'')
   AND TABLESPACE_NAME NOT IN (SELECT TABLESPACE_NAME FROM DBA_TABLESPACES WHERE CONTENTS IN (''UNDO'',''TEMPORARY'') OR STATUS = ''READ ONLY'') 
   AND POURCENTAGE      > 95    /* Used space > 95% and */ 
   AND LIBRE            < 1024  /* Free space < 1.0GB   */ 
'
  ,'SYSDATE + 60/1440'
  ,'---'
  ,30
);


-- STREAM.CAPTURE
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
  ,'STREAM.CAPTURE'
  ,'
SELECT CAPTURE_NAME
      ,''Attention : Le processus stream CAPTURE n''''a pas le statut ENABLED (DBA_CAPTURE.STATUS = '' || STATUS || '').''
  FROM DBA_CAPTURE
 WHERE STATUS != ''ENABLED''
'
  ,'SYSDATE + 10/1440'
  ,'---'
  ,30
);


-- STREAM.PROPAGATION
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
  ,'STREAM.PROPAGATION'
  ,'
SELECT QNAME
      ,''Attention : Le processus stream PROPAGATION à destination de '' || DESTINATION || '' à un nombre d''''erreur supérieur à zéro (DBA_QUEUE_SCHEDULES.FAILURES = '' || FAILURES || '').''
  FROM DBA_QUEUE_SCHEDULES
 WHERE FAILURES != 0
'
  ,'SYSDATE + 10/1440'
  ,'---'
  ,30
);


-- STREAM.APPLY
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
  ,'STREAM.APPLY'
  ,'
SELECT APPLY_NAME
      ,''Attention : Le processus stream APPLY n''''a pas le statut ENABLED (DBA_APPLY.STATUS = '' || STATUS || '').''
  FROM DBA_APPLY
 WHERE STATUS != ''ENABLED''
'
  ,'SYSDATE + 10/1440'
  ,'---'
  ,30
);


-- STREAM.APPLY.ERR
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
  ,'STREAM.APPLY.ERR'
  ,'
SELECT APPLY_NAME
      ,''Attention : Le processus stream APPLY a généré des erreurs (voir DBA_APPLY_ERROR).''
  FROM DBA_APPLY_ERROR
 GROUP BY APPLY_NAME
         ,''Attention : Le processus stream APPLY a généré des erreurs (voir DBA_APPLY_ERROR).''
'
  ,'SYSDATE + 10/1440'
  ,'---'
  ,30
);



--
-- Création des événements de collecte de données SDBM / Oracle
--


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


-- CD - FILESTAT
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
  ,'CD_FILESTAT'
  ,'CD'
  ,'
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
  ,'TRUNC(SYSDATE,''HH24'') + ((SUBSTR(TO_CHAR(SYSDATE,''MI''),1,1) + 1) || 0) / 1440'
  ,'---'
  ,30
);


-- CD - DBA_DATA_FILES
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
  ,'CD_DBA_DATA_FILES'
  ,'CD'
  ,'
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
  ,'TRUNC(SYSDATE + 1) + 15/1440'
  ,'---'
  ,30
);


-- CD - ESPACE_ARCHIVED_LOG
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
  ,'CD_ESPACE_ARCHIVED_LOG'
  ,'CD'
  ,'
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
  ,'TRUNC(SYSDATE,''HH24'') + 60/1440 + 15/86400'
  ,'---'
  ,30
);


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



--
-- Création des événements de base SDBM / Microsoft SQL Server
--


-- ALERT
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
  ,'ALERT'
  ,'AG'
  ,'N/A'
  ,'N/A'
  ,'---'
  ,30
);


-- BACKUP-SQL-LOG
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
  ,'BACKUP-SQL-LOG'
  ,'
SELECT name
      ,''Attention : Aucune prise de copie SQL (LOG) depuis plus de 3 heures.''
  FROM master.sys.databases db
 WHERE db.recovery_model_desc <> ''SIMPLE''
   AND db.name       NOT IN (''model'',''tempdb'')
   AND db.name       NOT IN (SELECT secondary_database
                               FROM msdb.dbo.log_shipping_secondary_databases
                            )
   AND db.state_desc NOT IN (''RESTORING'',''RECOVERING'')
   AND NOT EXISTS (SELECT 1
                     FROM msdb.dbo.backupset
                    WHERE database_name      = db.name
                      AND type               = ''L''
                      AND backup_finish_date > DATEADD(hour,-3,GETDATE())
                  ) 
'
  ,'DECODE(SUBSTR(TO_CHAR(SYSDATE,''HH24''),1,2),''22'',TRUNC(SYSDATE) + 1 + 9/24,SYSDATE + 60/1440)'
  ,'---'
  ,30
);


-- BACKUP-SQL-OPEN
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
  ,'BACKUP-SQL-OPEN'
  ,'
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
                  ) 
'
  ,'TRUNC(SYSDATE) + 1 + 9/24'
  ,'---'
  ,30
);


-- JOB-DELAYED
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
  ,'JOB-DELAYED'
  ,'
SELECT j.name
      ,''La tâche '' + j.name + '' s''''execute depuis plus de '' + CONVERT(varchar,ISNULL(DATEDIFF(mi,p.last_batch,getdate()),0)) + '' minutes (spid = '' + CONVERT(varchar,p.spid) + '', program_name = '' + CONVERT(varchar,p.program_name) + '', last_batch = '' + CONVERT(varchar,last_batch) + '').''
  FROM master..sysprocesses p
       JOIN msdb..sysjobs j ON (substring(left(j.job_id,8),7,2)
         + substring(left(j.job_id,8),5,2)
       + substring(left(j.job_id,8),3,2)
       + substring(left(j.job_id,8),1,2)) = substring(p.program_name,32,8)
WHERE program_name like ''SQLAgent - TSQL JobStep (Job %''
  AND ISNULL(DATEDIFF(mi,p.last_batch,getdate()),0) > 15  /* Number of minutes */
'
  ,'SYSDATE + 15/1440'
  ,'---'
  ,30
);


-- LOG_SHIPPING
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
  ,'LOG_SHIPPING'
  ,'
SELECT secondary_database
      ,''Le standby database ne semble plus suivre la base de données primaire (la différence est de '' + CONVERT(varchar,DATEDIFF(mi, last_restored_date, GETDATE())) + '' minutes)''
  FROM msdb.dbo.log_shipping_secondary_databases
 WHERE DATEDIFF(mi, last_restored_date, GETDATE()) > 30
'
  ,'SYSDATE + 10/1440'
  ,'---'
  ,30
);


-- MIRRORING
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
  ,'MIRRORING'
  ,'
SELECT db.name
      ,''Attention : Le statut du mirror '' + mi.mirroring_partner_instance + '' de la base de données n''''est plus SYNCHRONIZED (statut actuel : '' + mi.mirroring_state_desc COLLATE Latin1_General_CI_AS + '').''
  FROM sys.database_mirroring mi
      ,sys.databases          db
 WHERE db.database_id           = mi.database_id
   AND mi.mirroring_guid       IS NOT NULL
   AND mi.mirroring_state_desc <> ''SYNCHRONIZED''
'
  ,'SYSDATE + 2/1440'
  ,'---'
  ,30
);


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
SET SQLTERMINATOR "%"
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
)%
SET SQLTERMINATOR ";"


-- SPACE
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
  ,'SPACE'
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
  ,filegroup      sysname
  ,used_space     numeric
  ,total_space    numeric
)

DECLARE @v_database  sysname
DECLARE @SQLTemplate nvarchar(4000)
DECLARE @SQLString   nvarchar(4000)


SET @SQLTemplate = ''
   -- SPACE
   SELECT ''''<DATABASE>''''           AS "DATABASE"
         ,TOTAL_SPACE.FILE_GROUP   AS "FILE_GROUP"
         ,USED_SPACE.USED_SPACE    AS "USED_SPACE"
         ,TOTAL_SPACE.TOTAL_SPACE  AS "TOTAL_SPACE"
     FROM (
            /* Used space per file with AUTOGROWTH */
            SELECT FILE_SPACE.FILE_GROUP                              AS "FILE_GROUP"
                  ,SUM(CASE
                          WHEN FILE_SPACE.SIZE < FILE_SPACE.MAX_SIZE
                             THEN FILE_SPACE.MAX_SIZE
                             ELSE FILE_SPACE.SIZE
                       END
                      )                                               AS "TOTAL_SPACE"
              FROM (
                      SELECT grp.groupname                                        AS "FILE_GROUP"
                            ,fil.filename                                         AS "DATA_FILE"
                            ,(CONVERT(numeric,fil.size) * 8) * 1024               AS "SIZE"
                            ,(
                                 CASE fil.maxsize
                                    WHEN -1 THEN
                                       CONVERT(numeric,268435456)   * 8 * 1024 /* APPROX. 2T */
                                    ELSE
                                       CONVERT(numeric,fil.maxsize) * 8 * 1024
                                 END
                             )
                             * (CASE fil.growth WHEN 0 THEN 0 ELSE 1 END)         AS "MAX_SIZE"
                        FROM [<DATABASE>].sys.sysfiles fil LEFT JOIN [<DATABASE>].sys.sysfilegroups grp
                          ON fil.groupid = grp.groupid
                   ) FILE_SPACE
             GROUP BY FILE_SPACE.FILE_GROUP
          ) TOTAL_SPACE
         ,(
            SELECT das.name                         AS "FILE_GROUP"
                  ,sum(total_pages) * 8 * 1024      AS "USED_SPACE"
              FROM [<DATABASE>].sys.data_spaces das LEFT JOIN [<DATABASE>].sys.allocation_units alu
                      ON das.data_space_id = alu.data_space_id
             GROUP BY das.name
          ) USED_SPACE
    WHERE TOTAL_SPACE.FILE_GROUP COLLATE Latin1_General_CI_AS = USED_SPACE.FILE_GROUP COLLATE Latin1_General_CI_AS
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
SELECT database_name + '' ('' + filegroup + '')''
      ,''Le filegroup '' + filegroup + '' est utilisé à '' + CONVERT(varchar,CONVERT(numeric(5,2),ROUND((USED_SPACE / TOTAL_SPACE * 100),2))) + ''% (espace libre : '' + CONVERT(varchar,FLOOR(ROUND((TOTAL_SPACE - USED_SPACE) / 1024 / 1024,2))) + ''M)''
  FROM @TDATSPACE
 WHERE (USED_SPACE / TOTAL_SPACE * 100)           > 90    /* Used space > 90% and */
   AND ((TOTAL_SPACE - USED_SPACE) / 1024 / 1024) < 1536  /* Free space < 1.5GB   */
'
  ,'SYSDATE + 60/1440'
  ,'---'
  ,30
);


-- SPACE_CRITICAL
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
  ,'SPACE_CRITICAL'
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
  ,filegroup      sysname
  ,used_space     numeric
  ,total_space    numeric
)

DECLARE @v_database  sysname
DECLARE @SQLTemplate nvarchar(4000)
DECLARE @SQLString   nvarchar(4000)


SET @SQLTemplate = ''
   -- SPACE
   SELECT ''''<DATABASE>''''           AS "DATABASE"
         ,TOTAL_SPACE.FILE_GROUP   AS "FILE_GROUP"
         ,USED_SPACE.USED_SPACE    AS "USED_SPACE"
         ,TOTAL_SPACE.TOTAL_SPACE  AS "TOTAL_SPACE"
     FROM (
            /* Used space per file with AUTOGROWTH */
            SELECT FILE_SPACE.FILE_GROUP                              AS "FILE_GROUP"
                  ,SUM(CASE
                          WHEN FILE_SPACE.SIZE < FILE_SPACE.MAX_SIZE
                             THEN FILE_SPACE.MAX_SIZE
                             ELSE FILE_SPACE.SIZE
                       END
                      )                                               AS "TOTAL_SPACE"
              FROM (
                      SELECT grp.groupname                                        AS "FILE_GROUP"
                            ,fil.filename                                         AS "DATA_FILE"
                            ,(CONVERT(numeric,fil.size) * 8) * 1024               AS "SIZE"
                            ,(
                                 CASE fil.maxsize
                                    WHEN -1 THEN
                                       CONVERT(numeric,268435456)   * 8 * 1024 /* APPROX. 2T */
                                    ELSE
                                       CONVERT(numeric,fil.maxsize) * 8 * 1024
                                 END
                             )
                             * (CASE fil.growth WHEN 0 THEN 0 ELSE 1 END)         AS "MAX_SIZE"
                        FROM [<DATABASE>].sys.sysfiles fil LEFT JOIN [<DATABASE>].sys.sysfilegroups grp
                          ON fil.groupid = grp.groupid
                   ) FILE_SPACE
             GROUP BY FILE_SPACE.FILE_GROUP
          ) TOTAL_SPACE
         ,(
            SELECT das.name                         AS "FILE_GROUP"
                  ,sum(total_pages) * 8 * 1024      AS "USED_SPACE"
              FROM [<DATABASE>].sys.data_spaces das LEFT JOIN [<DATABASE>].sys.allocation_units alu
                      ON das.data_space_id = alu.data_space_id
             GROUP BY das.name
          ) USED_SPACE
    WHERE TOTAL_SPACE.FILE_GROUP COLLATE Latin1_General_CI_AS = USED_SPACE.FILE_GROUP COLLATE Latin1_General_CI_AS
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
SELECT database_name + '' ('' + filegroup + '')''
      ,''Le filegroup '' + filegroup + '' est utilisé à '' + CONVERT(varchar,CONVERT(numeric(5,2),ROUND((USED_SPACE / TOTAL_SPACE * 100),2))) + ''% (espace libre : '' + CONVERT(varchar,FLOOR(ROUND((TOTAL_SPACE - USED_SPACE) / 1024 / 1024,2))) + ''M)''
  FROM @TDATSPACE
 WHERE (USED_SPACE / TOTAL_SPACE * 100)           > 95    /* Used space > 95% and */
   AND ((TOTAL_SPACE - USED_SPACE) / 1024 / 1024) < 1024  /* Free space < 1GB     */
'
  ,'SYSDATE + 60/1440'
  ,'---'
  ,30
);


-- SPACE(LOG)
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
  ,'SPACE(LOG)'
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
SELECT database_name
      ,''Le transaction log est utilisé à '' + CONVERT(varchar,CONVERT(numeric(5,2),ROUND((USED_SPACE / TOTAL_SPACE * 100),2))) + ''% (espace libre : '' + CONVERT(varchar,FLOOR(ROUND((TOTAL_SPACE - USED_SPACE) / 1024 / 1024,2))) + ''M)''
  FROM @TDATSPACE
 WHERE DATABASEPROPERTYEX(database_name,''RECOVERY'') <> ''SIMPLE''
   AND (USED_SPACE / TOTAL_SPACE * 100) > 50  /* Used space > 50% */
'
  ,'SYSDATE + 10/1440'
  ,'---'
  ,30
);


-- STATUS
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
  ,'STATUS'
  ,'
SELECT name
      ,''Le statut de la base de données est '' + state_desc + '', '' + user_access_desc + ''.''
  FROM master.sys.databases
 WHERE name NOT IN (SELECT secondary_database
                      FROM msdb.dbo.log_shipping_secondary_databases
                   )
   AND (
             state_desc       NOT IN (''ONLINE'',''RESTORING'',''RECOVERING'')
          OR user_access_desc <> ''MULTI_USER''
       )
'
  ,'SYSDATE + 2/1440'
  ,'---'
  ,30
);


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
  ,'TRUNC(SYSDATE + 1) + 15/1440'
  ,'---'
  ,30
);


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
  ,'TRUNC(SYSDATE,''HH24'') + 60/1440 + 15/86400'
  ,'---'
  ,30
);



--
-- Création des événements de base SDBM / MySQL
--


-- ALERT
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




--
-- Création des traductions des événements de base SDBM / Oracle
--

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
  ,'ASM.SPACE'
  ,'''Le diskgroup '' || NAME || '' est utilise a '' || TO_CHAR((ESPACE_TOTAL - ESPACE_LIBRE) / ESPACE_TOTAL * 100,''FM990.00'') || ''% (espace libre : '' || ESPACE_LIBRE || ''M)'''
  ,'''The diskgroup '' || NAME || '' is used at '' || TO_CHAR((ESPACE_TOTAL - ESPACE_LIBRE) / ESPACE_TOTAL * 100,''FM990.00'') || ''% (free space : '' || ESPACE_LIBRE || ''M)'''
  ,'Vérification de l''espace disponible par diskgroup (> 75% et < 10G)'
  ,'Validate available space per diskgroup (> 75% and < 10G)'
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
  ,'ASM.STATUS'
  ,'''Le diskgroup '' || NAME || '' est en probleme (STATE = '' || STATE || '', OFFLINE_DISKS = '' || OFFLINE_DISKS || '')'''
  ,'''The diskgroup '' || NAME || '' is in trouble (STATE = '' || STATE || '', OFFLINE_DISKS = '' || OFFLINE_DISKS || '')'''
  ,'Vérification du statut des diskgroups ASM'
  ,'Validate the status of ASM diskgroups'
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
  ,'ASM.STATUS'
  ,'''Le disque '' || PATH || '' semble etre en probleme (MOUNT_STATUS = '' || MOUNT_STATUS || '', HEADER_STATUS = '' || HEADER_STATUS || '')'''
  ,'''The disk '' || PATH || '' seem to be in trouble (STATE = '' || STATE || '', OFFLINE_DISKS = '' || OFFLINE_DISKS || '')'''
  ,'Vérification du statut des diskgroups ASM'
  ,'Validate the status of ASM diskgroups'
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
  ,'ARCx'
  ,'''Attention : Les processus "ARCx" semblent être en problème (80% des "REDO LOGS" ne sont pas archivés).'''
  ,'''Warning : The "ARCx" processes seem to be in trouble (80% of the REDO are not archived).'''
  ,'Vérification de l''archivage Oracle'
  ,'Validate that Oracle archivers are keeping up'
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
  ,'ARCx'
  ,'''Attention : L''''archivage du log '' || SEQUENCE# || '' (thread# '' || THREAD# || '') semble être en problème.'''
  ,'''Warning : There is a problem with the archiving of the log '' || SEQUENCE# || '' (thread# '' || THREAD# || '').'''
  ,'Vérification de l''archivage Oracle'
  ,'Validate that Oracle archivers are keeping up'
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
  ,'BLOCKING_LOCKS'
  ,(SELECT SUBSTR(COMMANDE,1,INSTR(COMMANDE,'information sur la session qui détient la ressource.''') + 53)
      FROM SDBM.EVENEMENT
     WHERE TYPE_CIBLE = 'BD'
       AND SOUS_TYPE_CIBLE = 'OR'
       AND NOM_EVENEMENT   = 'BLOCKING_LOCKS'
   )
  ,'
SELECT GL1.SID || '' ('' || INS.INSTANCE_NAME || '')''
      ,''The session '' || GL1.SID || '' (SID), '' || INS.INSTANCE_NAME || '' (INSTANCE), ''
       || (SELECT NVL(USERNAME,''NULL'')
             FROM GV$SESSION
            WHERE INST_ID = GL1.INST_ID
              AND SID     = GL1.SID
          )
       || '' (USERNAME) is waiting for the object ''
       || NVL((SELECT OWNER || ''.'' || OBJECT_NAME
                 FROM DBA_OBJECTS      OBJ
                     ,GV$LOCKED_OBJECT LKO
                WHERE OBJ.OBJECT_ID  = LKO.OBJECT_ID
                  AND LKO.INST_ID    = GL1.INST_ID
                  AND LKO.SESSION_ID = GL1.SID
                  AND ROWNUM        <= 1
              )
             ,GL1.ID1
             )
       || '' (mode required : '' || DECODE(GL1.REQUEST
                                      ,0,''None''
                                      ,1,''Null''
                                      ,2,''Row share''
                                      ,3,''Row exclusive''
                                      ,4,''Share''
                                      ,5,''Share + Row exclusive''
                                      ,6,''Exclusive''
                                      ,GL1.REQUEST
                                      )
       || '') since '' || GL1.CTIME || '' seconds.''
       || NVL((SELECT '' The session '' || ML1.SID || '' (SID), ''
                                      || MIN.INSTANCE_NAME || '' (INSTANCE) has the requested resource (mode : '' || DECODE(ML1.LMODE
                                                                                                                         ,0,''None''
                                                                                                                         ,1,''Null''
                                                                                                                         ,2,''Row share''
                                                                                                                         ,3,''Row exclusive''
                                                                                                                         ,4,''Share''
                                                                                                                         ,5,''Share + Row exclusive''
                                                                                                                         ,6,''Exclusive''
                                                                                                                         ,ML1.LMODE
                                                                                                                         )
                      || '') since more than '' || ML1.CTIME || '' seconds.''
                 FROM GV$LOCK     ML1
                     ,GV$INSTANCE MIN
                WHERE ML1.INST_ID = MIN.INST_ID
                  AND ML1.ID1     = GL1.ID1
                  AND ML1.BLOCK  != 0
                  AND ROWNUM     <= 1
              )
             ,'' Unable to get the information on the owner of the required resource.'''
  ,'Vérification des vérouillages'
  ,'Validate that no blocking lock exists'
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
  ,'CORRUPTION'
  ,'''Corruption de la base de données détectée (V$BACKUP_CORRUPTION : '' || COUNT_BBC || '', V$DATABASE_BLOCK_CORRUPTION : '' || COUNT_DBC || '').'''
  ,'''Database corruption has been detected (V$BACKUP_CORRUPTION : '' || COUNT_BBC || '', V$DATABASE_BLOCK_CORRUPTION : '' || COUNT_DBC || '').'''
  ,'Vérification des signalements de corruption'
  ,'Validate that no corruption has been report'
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
  ,'DBA_2PC_PENDING'
  ,'''Attention : transactions dans DBA_2PC_PENDING.'''
  ,'''Warning : There is transactions into DBA_2PC_PENDING.'''
  ,'Vérification qu''il n''existe aucune transaction dans DBA_2PC_PENDING'
  ,'Validate that no transaction exists into DBA_2PC_PENDING'
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
  ,'DEFERROR'
  ,'''Attention : transactions dans DEFERROR.'''
  ,'''Warning : There is transactions into DEFERROR.'''
  ,'Vérification qu''il n''existe aucune transaction dans DEFERROR'
  ,'Validate that no transaction exists into DEFERROR'
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
  ,'FILE_STATUS'
  ,'''Le fichier '' || NAME || '' n''''a pas un statut normal (STATUS = '' || STATUS || '').'''
  ,'''The status of the file '' || NAME || '' is not SYSTEM or ONLINE (STATUS = '' || STATUS || '').'''
  ,'Vérification du statut des fichiers de la base de données'
  ,'Validate the status of the database files'
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
  ,'FILE_UNRECOVERABLE'
  ,'''Le fichier '' || NAME || '' n''''est pas recupérable actuellement via RMAN (UNRECOVERABLE_TIME = '' || TO_CHAR(UNRECOVERABLE_TIME,''YYYY/MM/DD:HH24:MI:SS'') || '').'''
  ,'''The file '' || NAME || '' is no longer recoverable using RMAN (UNRECOVERABLE_TIME = '' || TO_CHAR(UNRECOVERABLE_TIME,''YYYY/MM/DD:HH24:MI:SS'') || '').'''
  ,'Vérification de la capacité de récupérer un fichier'
  ,'Validate that database files are recoverable'
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
  ,'JOB-BROKEN'
  ,'''La tâche '' || JOB || '' ('' || SUBSTR(WHAT,1,75) || '') est ''''BROKEN''''.'''
  ,'''The job '' || JOB || '' ('' || SUBSTR(WHAT,1,75) || '') is ''''BROKEN''''.'''
  ,'Vérification des DBMS_JOB - BROKEN'
  ,'Validate of DBMS_JOB - BROKEN'
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
  ,'JOB-DELAYED'
  ,'''Retard d''''exécution sur la tâche '' || JOB || '' ('' || SUBSTR(WHAT,1,75) || '').'''
  ,'''The execution of job '' || JOB || '' is delayed ('' || SUBSTR(WHAT,1,75) || '').'''
  ,'Vérification des DBMS_JOB - retard d''exécution (ou tâche longue)'
  ,'Validate of DBMS_JOB - delayed (or long running job)'
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
  ,'JOB-FAILURES'
  ,'''La tâche '' || JOB || '' ('' || SUBSTR(WHAT,1,75) || '') à 10 ''''FAILURES'''' ou plus.'''
  ,'''The job '' || JOB || '' ('' || SUBSTR(WHAT,1,75) || '') has 10 ''''FAILURES'''' or more.'''
  ,'Vérification des DBMS_JOB - FAILURES < 10'
  ,'Validate of DBMS_JOB - FAILURES < 10'
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
  ,'LOGSTDBY.APPLY'
  ,'''Attention : Le processus APPLY semble être en retard (voir DBA_LOGSTDBY_PROGRESS, APPLIED_TIME = '' || TO_CHAR(APPLIED_TIME,''YYYY/MM/DD:HH24:MI:SS'') || '').'''
  ,'''Warning : The stream APPLY process seem to be delayed (see DBA_LOGSTDBY_PROGRESS, APPLIED_TIME = '' || TO_CHAR(APPLIED_TIME,''YYYY/MM/DD:HH24:MI:SS'') || '').'''
  ,'Vérification d''un "logical standby" - APPLY'
  ,'Validate of "logical standby" - APPLY'
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
  ,'LOGSTDBY.EVENTS'
  ,'''Attention : '' || COUNT(1) || '' nouveau(x) enregistrement(s) de ce type dans DBA_LOGSTDBY_EVENTS pour les 15 dernières minutes.'''
  ,'''Warning : '' || COUNT(1) || '' new record(s) of this type into DBA_LOGSTDBY_EVENTS in the last 15 minutes.'''
  ,'Vérification d''un "logical standby" - EVENTS'
  ,'Validate of "logical standby" - EVENTS'
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
  ,'LOGSTDBY.RECEPTION'
  ,'''Attention : Aucune réception de REDO depuis plus de 90 minutes (voir DBA_LOGSTDBY_PROGRESS, NEWEST_TIME = '' || TO_CHAR(NEWEST_TIME,''YYYY/MM/DD:HH24:MI:SS'') || '').'''
  ,'''Warning : No REDO has been received since more than 90 minutes (see DBA_LOGSTDBY_PROGRESS, NEWEST_TIME = '' || TO_CHAR(NEWEST_TIME,''YYYY/MM/DD:HH24:MI:SS'') || '').'''
  ,'Vérification d''un "logical standby" - RECEPTION'
  ,'Validate of "logical standby" - RECEPTION'
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
  ,'PHYSTDBY.STATUS'
  ,'''Le standby database ne semble plus suivre la base de données primaire (la différence est de '' || TO_CHAR(TRUNC((SYSDATE - CONTROLFILE_TIME) * 1440)) || '' minutes)'''
  ,'''The standby database does not seem to keep up with the primary database (the difference is now of '' || TO_CHAR(TRUNC((SYSDATE - CONTROLFILE_TIME) * 1440)) || '' minutes)'''
  ,'Vérification du statut du standby database (Data Guard)'
  ,'Validate the status of standby database (Data Guard)'
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
  ,'RMAN_ARCHIVE'
  ,'semble(nt) ne pas avoir été détruit(s) (donc sauvegardé(s)) dans RMAN depuis le'
  ,'seem to not have been deleted (and backup) within RMAN since'
  ,'Vérification de l''exécution des prises de copie RMAN (ARCHIVELOG)'
  ,'Validate that RMAN backup are running (ARCHIVELOG)'
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
  ,'RMAN_DATAFILE'
  ,(SELECT SUBSTR(COMMANDE,54,1081) FROM SDBM.EVENEMENT WHERE NOM_EVENEMENT = 'RMAN_DATAFILE')
  ,       'COUNT(1) || '' file of the database was not backup within RMAN''   || DECODE(MIN(COMPLETION_TIME)
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
  ,'SDBM.CPU_NO_IDLE'
  ,'Le serveur '' || NOM_SERVEUR || '' semble être très solicité (CPU IDLE'
  ,'The server '' || NOM_SERVEUR || '' seem to be heavily loaded (CPU IDLE'
  ,'Vérification qu''il existe des ressources CPU disponible sur les serveurs'
  ,'Validate that there is available CPU resources on all server'
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
  ,'SDBM.ERROR'
  ,'''Attention : '' || COUNT(1) || '' nouveau(x) enregistrement(s) dans le journal SDBM depuis '
  ,'''Warning : '' || COUNT(1) || '' new record(s) in the SDBM events log since '
  ,'Vérification qu''il n''existe pas d''erreur dans je journal d''evénement SDBM (serveur local et distant devrait être enregistrés)'
  ,'Validate that no error exists into SDBM event log (local and remote server should be registered)'
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
  ,'SDBM.JOB'
  ,'''La tâche '' || NOM_TACHE || '' (agent : '' || NOM_SERVEUR || '') aurait du être soumise depuis '' || TO_CHAR(DH_PROCHAINE_EXEC,''YYYY/MM/DD:HH24:MI:SS'') || ''.'''
  ,'''The job '' || NOM_TACHE || '' (agent : '' || NOM_SERVEUR || '') has not been submitted on time. The job should had been started at '' || TO_CHAR(DH_PROCHAINE_EXEC,''YYYY/MM/DD:HH24:MI:SS'') || ''.'''
  ,'Vérification de l''exécution des tâches SDBM'
  ,'Validate that SDBM job are sucessfully submitted'
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
  ,'SDBM.SDBMAGT'
  ,'''L''''agent SDBMAgt - SDBM ne semble pas fonctionnel sur '' || SERVEUR || ''.'''
  ,'''SDBMAgt (SDBM) agent does not seem to be working on '' || SERVEUR || ''.'''
  ,'Vérification que les agents SDBMAgt s''exécutent'
  ,'Validate that SDBMAgt agents are running'
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
  ,'SDBM.SDBMSRV'
  ,'''Le service principal SDBMSrv - SDBM ne semble pas fonctionnel.'''
  ,'''SDBMSrv (SDBM) service does not seem to be working.'''
  ,'Vérification que le serveur SDBMSrv s''exécute (seulement les serveurs distant devrait être enregistrés)'
  ,'Validate that SDBMSrv server is running (only remote server should be registered)'
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
  ,'SELECT'
  ,'SELECT'
  ,'Envoi des messages du journal SDBM (WARNING : Unable to process event ...)'
  ,'Send message from SDBM event log (WARNING : Unable to process event ...)'
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
  ,'SEQUENCE'
  ,'''La séquence '' || SEQUENCE_OWNER || ''.'' || SEQUENCE_NAME || '' est utilisé à '' || TO_CHAR((LAST_NUMBER - MIN_VALUE) / (MAX_VALUE - MIN_VALUE) * 100,''FM990.00'') || ''% (nombre disponible = '' || (MAX_VALUE - LAST_NUMBER) || '')'''
  ,'''The sequence '' || SEQUENCE_OWNER || ''.'' || SEQUENCE_NAME || '' is used at '' || TO_CHAR((LAST_NUMBER - MIN_VALUE) / (MAX_VALUE - MIN_VALUE) * 100,''FM990.00'') || ''% (available number = '' || (MAX_VALUE - LAST_NUMBER) || '')'''
  ,'Vérification de la capacité des séquences'
  ,'Validate the capacity of sequences'
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
  ,'SESSION'
  ,'''Le nombre de session approche de la capacité de l''''instance '' || INST.INSTANCE_NAME || '' ('' || PROC.NB_SESSION || ''/'' || PARA.NB_PROCESS || '' : '' || TO_CHAR(ROUND((PROC.NB_SESSION / PARA.NB_PROCESS) * 100)) || ''%).'''
  ,'''The number of session is reaching the total instance capacity of '' || INST.INSTANCE_NAME || '' ('' || PROC.NB_SESSION || ''/'' || PARA.NB_PROCESS || '' : '' || TO_CHAR(ROUND((PROC.NB_SESSION / PARA.NB_PROCESS) * 100)) || ''%).'''
  ,'Vérification que le nombre de session n''approche pas trop de la capacité de l''instance'
  ,'Validate that the number of session is not reaching the total instance capacity'
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
  ,'SPACE'
  ,'''Le tablespace '' || TABLESPACE_NAME || '' est utilisé à '' || TO_CHAR(POURCENTAGE,''FM990.00'') || ''% (espace libre : '' || LIBRE || ''M)'''
  ,'''The tablespace '' || TABLESPACE_NAME || '' is used at '' || TO_CHAR(POURCENTAGE,''FM990.00'') || ''% (free space : '' || LIBRE || ''M)'''
  ,'Vérification de l''espace disponible par tablespace (> 90% et < 1,5G)'
  ,'Validate available space per tablespace (> 90% and < 1.5G)'
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
  ,'SPACE_CRITICAL'
  ,'''Le tablespace '' || TABLESPACE_NAME || '' est utilisé à '' || TO_CHAR(POURCENTAGE,''FM990.00'') || ''% (espace libre : '' || LIBRE || ''M)'''
  ,'''The tablespace '' || TABLESPACE_NAME || '' is used at '' || TO_CHAR(POURCENTAGE,''FM990.00'') || ''% (free space : '' || LIBRE || ''M)'''
  ,'Vérification de l''espace disponible par tablespace (> 95% and < 1,0G)'
  ,'Validate available space per tablespace (> 95% and < 1.0G)'
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
  ,'STREAM.APPLY'
  ,'''Attention : Le processus stream APPLY n''''a pas le statut ENABLED (DBA_APPLY.STATUS = '' || STATUS || '').'''
  ,'''Warning : The status of the stream APPLY process is not ENABLED (DBA_APPLY.STATUS = '' || STATUS || '').'''
  ,'Vérification du statut du processus "stream" - APPLY'
  ,'Validate the status of the "stream" process - APPLY'
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
  ,'STREAM.APPLY.ERR'
  ,'''Attention : Le processus stream APPLY a généré des erreurs (voir DBA_APPLY_ERROR).'''
  ,'''Warning : The stream APPLY processes has generate errors (see DBA_APPLY_ERROR).'''
  ,'Vérification qu''il n''existe aucune erreur "stream" - APPLY'
  ,'Validate that no error exists for the "stream" - APPLY'
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
  ,'STREAM.CAPTURE'
  ,'''Attention : Le processus stream CAPTURE n''''a pas le statut ENABLED (DBA_CAPTURE.STATUS = '' || STATUS || '').'''
  ,'''Warning : The status of the stream CAPTURE process is not ENABLED (DBA_CAPTURE.STATUS = '' || STATUS || '').'''
  ,'Vérification du statut du processus "stream" - CAPTURE'
  ,'Validate the status of the "stream" process - CAPTURE'
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
  ,'STREAM.PROPAGATION'
  ,'''Attention : Le processus stream PROPAGATION à destination de '' || DESTINATION || '' à un nombre d''''erreur supérieur à zéro (DBA_QUEUE_SCHEDULES.FAILURES = '' || FAILURES || '').'''
  ,'''Warning : The stream PROPAGATE process to the destination '' || DESTINATION || '' has errors (DBA_QUEUE_SCHEDULES.FAILURES = '' || FAILURES || '').'''
  ,'Vérification qu''il n''existe aucune erreur "stream" - PROPAGATION'
  ,'Validate that no error exists for the "stream" - PROPAGATE'
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
  ,'TEST'
  ,'''Ceci est un test.'''
  ,'''This is a test.'''
  ,'Test de notification'
  ,'Notification test'
);


--
-- Création des traduction des événements de base SDBM / Microsoft SQL Server
--

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
  ,'BACKUP-SQL-LOG'
  ,'''Attention : Aucune prise de copie SQL (LOG) depuis plus de 3 heures.'''
  ,'''Warning : No transaction log backup occurs since more than 3 hours.'''
  ,'Vérification des prises de copie de LOG (maximum 3 heures)'
  ,'Validate that SQL transaction log backup are running (report after 3 hours)'
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
  ,'BACKUP-SQL-OPEN'
  ,'''Attention : Aucune prise de copie SQL (OPEN) depuis plus de 36 heures.'''
  ,'''Warning : No full backup occurs since more than 36 hours.'''
  ,'Vérification des prises de copie de DATABASE (maximum 36 heures)'
  ,'Validate that SQL backup are running (report after 36 hours)'
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
  ,'JOB-DELAYED'
  ,'La tâche '' + j.name + '' s''''execute depuis plus de'
  ,'The job '' + j.name + '' is executing for more than'
  ,'Vérification des tâches SQL (tâche longue).  Le privilège suivant est requis : grant select on msdb.dbo.sysjobs to [usager SDBM]'
  ,'Validate the presence of long running job.  The following privilege is required : grant select on msdb.dbo.sysjobs to [SDBM monitoring user]'
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
  ,'LOG_SHIPPING'
  ,'''Le standby database ne semble plus suivre la base de données primaire (la différence est de '' + CONVERT(varchar,DATEDIFF(mi, last_restored_date, GETDATE())) + '' minutes)'''
  ,'''The standby database does not seem to keep up with the primary database (the difference is now of '' + CONVERT(varchar,DATEDIFF(mi, last_restored_date, GETDATE())) + '' minutes)'''
  ,'Vérification du statut du "log shipping"'
  ,'Validate of the status of "log shipping"'
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
  ,'MIRRORING'
  ,'''Attention : Le statut du mirror '' + mi.mirroring_partner_instance + '' de la base de données n''''est plus SYNCHRONIZED (statut actuel : '' + mi.mirroring_state_desc COLLATE Latin1_General_CI_AS + '').'''
  ,'''Warning : The status of the mirror '' + mi.mirroring_partner_instance + '' of the database is no more SYNCHRONIZED (actual status : '' + mi.mirroring_state_desc COLLATE Latin1_General_CI_AS + '').'''
  ,'Vérification du statut des miroirs SQL (SQL Mirroring)'
  ,'Validate of the status of SQL Mirroring'
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

SET SQLTERMINATOR "%"
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
)%
SET SQLTERMINATOR ";"

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
  ,'SPACE'
  ,'''Le filegroup '' + filegroup + '' est utilisé à '' + CONVERT(varchar,CONVERT(numeric(5,2),ROUND((USED_SPACE / TOTAL_SPACE * 100),2))) + ''% (espace libre : '' + CONVERT(varchar,FLOOR(ROUND((TOTAL_SPACE - USED_SPACE) / 1024 / 1024,2))) + ''M)'''
  ,'''The filegroup '' + filegroup + '' is used at '' + CONVERT(varchar,CONVERT(numeric(5,2),ROUND((USED_SPACE / TOTAL_SPACE * 100),2))) + ''% (free space : '' + CONVERT(varchar,FLOOR(ROUND((TOTAL_SPACE - USED_SPACE) / 1024 / 1024,2))) + ''M)'''
  ,'Vérification de l''espace disponible par base de données (> 90% et < 1,5G)'
  ,'Validate available space per database (> 90% and < 1.5G)'
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
  ,'SPACE_CRITICAL'
  ,'''Le filegroup '' + filegroup + '' est utilisé à '' + CONVERT(varchar,CONVERT(numeric(5,2),ROUND((USED_SPACE / TOTAL_SPACE * 100),2))) + ''% (espace libre : '' + CONVERT(varchar,FLOOR(ROUND((TOTAL_SPACE - USED_SPACE) / 1024 / 1024,2))) + ''M)'''
  ,'''The filegroup '' + filegroup + '' is used at '' + CONVERT(varchar,CONVERT(numeric(5,2),ROUND((USED_SPACE / TOTAL_SPACE * 100),2))) + ''% (free space : '' + CONVERT(varchar,FLOOR(ROUND((TOTAL_SPACE - USED_SPACE) / 1024 / 1024,2))) + ''M)'''
  ,'Vérification de l''espace disponible par base de données (> 95% and < 1,0G)'
  ,'Validate available space per database (> 95% and < 1.0G)'
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
  ,'SPACE(LOG)'
  ,'''Le transaction log est utilisé à '' + CONVERT(varchar,CONVERT(numeric(5,2),ROUND((USED_SPACE / TOTAL_SPACE * 100),2))) + ''% (espace libre : '' + CONVERT(varchar,FLOOR(ROUND((TOTAL_SPACE - USED_SPACE) / 1024 / 1024,2))) + ''M)'''
  ,'''The transaction log is used at '' + CONVERT(varchar,CONVERT(numeric(5,2),ROUND((USED_SPACE / TOTAL_SPACE * 100),2))) + ''% (free space : '' + CONVERT(varchar,FLOOR(ROUND((TOTAL_SPACE - USED_SPACE) / 1024 / 1024,2))) + ''M)'''
  ,'Vérification de l''espace disponible par base de données - transaction log (> 50%)'
  ,'Validate available space per database - transaction log (> 50%)'
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
  ,'STATUS'
  ,'''Le statut de la base de données est '' + state_desc + '', '' + user_access_desc + ''.'''
  ,'''The status of the database is '' + state_desc + '', '' + user_access_desc + ''.'''
  ,'Vérification du statut des bases de données'
  ,'Validate the status of databases'
);




-- Création de l'usager de monitoring de l'instance local SDBM
CREATE USER SDBMON
   IDENTIFIED BY "changeme-mon";

GRANT CREATE SESSION      TO SDBMON;
GRANT SELECT_CATALOG_ROLE TO SDBMON;

-- Ajout à la base (monitoring spécifique)
GRANT SELECT ON SDBM.APEX_STATUT_SESSION_SDBM  TO SDBMON;
GRANT SELECT ON SDBM.JOURNAL                   TO SDBMON;

GRANT SELECT ON SDBM.HIST_TACHE_AGT            TO SDBMON;
GRANT SELECT ON SDBM.PARAMETRE                 TO SDBMON;
GRANT SELECT ON SDBM.TACHE_AGT                 TO SDBMON;

GRANT SELECT ON SDBM.CD_INFO_DYNAMIQUE_AGT     TO SDBMON;


DISCONNECT
EXIT
