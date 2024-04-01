-- *
-- * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
-- * Licensed under the MIT license.
-- * See LICENSE file in the project root for full license information.
-- *

--
-- Script :
--    sbdm_code_service.sql
--
-- Description :
--    Mise en place des usagers requis par les services Java.
--


WHENEVER OSERROR  EXIT 8
WHENEVER SQLERROR EXIT SQL.SQLCODE


CONNECT / as sysdba
alter session set container = XEPDB1;


-- Requis pour SDBMSrv et SDBMDaC
CREATE USER SDBMSRV IDENTIFIED BY "changeme-srv";

GRANT CONNECT                    TO SDBMSRV;

-- Requis de SDBMDaC
GRANT EXECUTE ON SDBM.SDBM_BASE  TO SDBMSRV;

-- Requis de SDBMDaC
GRANT EXECUTE ON SDBM.SDBM_COLLECTE           TO SDBMSRV;
GRANT INSERT  ON SDBM.CD_ASM_DISKGROUP        TO SDBMSRV;
GRANT INSERT  ON SDBM.CD_DBA_DATA_FILES       TO SDBMSRV;
GRANT INSERT  ON SDBM.CD_ESPACE_ARCHIVED_LOG  TO SDBMSRV;
GRANT INSERT  ON SDBM.CD_FILESTAT             TO SDBMSRV;
GRANT INSERT  ON SDBM.CD_TRANSACTION_LOG      TO SDBMSRV;
GRANT INSERT  ON SDBM.CD_SYSSTAT_CPU          TO SDBMSRV;


-- Requis pour SDBMAgt
CREATE USER SDBMAGT IDENTIFIED BY "changeme-agt";

GRANT CONNECT                     TO SDBMAGT;
GRANT EXECUTE ON SDBM.SDBM_AGENT  TO SDBMAGT;


DISCONNECT
EXIT
