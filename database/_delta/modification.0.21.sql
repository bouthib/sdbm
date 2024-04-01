-- *
-- * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
-- * Licensed under the MIT license.
-- * See LICENSE file in the project root for full license information.
-- *



---------------------------------------------
---------------------------------------------
---------------------------------------------
--  V E R S I O N   0 . 2 1  -   B e t a   --
---------------------------------------------
---------------------------------------------


execute DBMS_XDB.SETLISTENERLOCALACCESS(FALSE);


CREATE TABLE CD_INFO_DYNAMIQUE_AGT
(
   DH_COLLECTE_DONNEE      DATE
  ,NOM_SERVEUR             VARCHAR2(64)
  ,TYPE_INFO               CHAR(2)
  ,CPU_USER_TIME           NUMBER
  ,CPU_SYS_TIME            NUMBER
  ,CPU_NICE_TIME           NUMBER
  ,CPU_WAIT_TIME           NUMBER
  ,CPU_TOTAL_TIME          NUMBER
  ,CPU_IDLE_TIME           NUMBER
  ,MEM_TOTAL               NUMBER
  ,MEM_ACTUAL_USED         NUMBER
  ,MEM_ACTUAL_FREE         NUMBER
  ,MEM_USED                NUMBER
  ,MEM_FREE                NUMBER
  ,SWP_TOTAL               NUMBER
  ,SWP_USED                NUMBER
  ,SWP_FREE                NUMBER
  ,SWP_PAGE_IN             NUMBER
  ,SWP_PAGE_OUT            NUMBER
  ,SWP_DELTA_PAGE_IN       NUMBER
  ,SWP_DELTA_PAGE_OUT      NUMBER
  ,SYS_LOAD_AVG            NUMBER
  ,MAX_CPU_USER_TIME       NUMBER
  ,MAX_CPU_SYS_TIME        NUMBER
  ,MAX_CPU_NICE_TIME       NUMBER
  ,MAX_CPU_WAIT_TIME       NUMBER
  ,MAX_CPU_TOTAL_TIME      NUMBER
  ,MAX_MEM_ACTUAL_USED     NUMBER
  ,MAX_MEM_USED            NUMBER
  ,MAX_SWP_USED            NUMBER
  ,MAX_SWP_DELTA_PAGE_IN   NUMBER
  ,MAX_SWP_DELTA_PAGE_OUT  NUMBER
  ,MAX_SYS_LOAD_AVG        NUMBER
)
TABLESPACE SDBM_DATA
MONITORING;
  
ALTER TABLE CD_INFO_DYNAMIQUE_AGT
   ADD CONSTRAINT IDA_PK_INFO_DYNAMIQUE_AGT PRIMARY KEY (DH_COLLECTE_DONNEE, NOM_SERVEUR, TYPE_INFO)
      USING INDEX
      TABLESPACE SDBM_DATA;


CREATE TABLE CD_INFO_DYNAMIQUE_CPU_AGT
(
   DH_COLLECTE_DONNEE  DATE
  ,NOM_SERVEUR         VARCHAR2(64)
  ,ID                  NUMBER(4)
  ,USER_TIME           NUMBER
  ,SYS_TIME            NUMBER
  ,NICE_TIME           NUMBER
  ,WAIT_TIME           NUMBER
  ,TOTAL_TIME          NUMBER
  ,IDLE_TIME           NUMBER
)
TABLESPACE SDBM_DATA
MONITORING;
  
ALTER TABLE CD_INFO_DYNAMIQUE_CPU_AGT
   ADD CONSTRAINT IDDA_PK_INFO_DYNAMIQUE_CPU_AGT PRIMARY KEY (DH_COLLECTE_DONNEE, NOM_SERVEUR, ID)
      USING INDEX
      TABLESPACE SDBM_DATA;


DROP VIEW SDBM.APEX_INFO_AGENT;
APEX 0.21


@../_package/ps-sdbm_agent.sql
@../_package/pb-sdbm_agent.sql
@../_package/pb-sdbm_util.sql
@../_package/pb-sdbm_collecte.sql


- Vérification si les tâches ont été soumises par SDBM...


ALTER USER SDBM ACCOUNT LOCK;
+ processes dans XE = 100


SDBMSrv version = "0.05 - Beta";
SDBMAgt version = "0.11 - Beta";
