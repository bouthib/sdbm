-- *
-- * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
-- * Licensed under the MIT license.
-- * See LICENSE file in the project root for full license information.
-- *

--
-- Script :
--    sbdm_post_install.sql
--
-- Description :
--    Fin de l'installation.
--


WHENEVER OSERROR  EXIT 8
WHENEVER SQLERROR EXIT SQL.SQLCODE


CONNECT SDBM/admin@localhost/XEPDB1

@_dbms_job/dbms_job.sql
commit;

DISCONNECT


CONNECT / as sysdba

shutdown immediate;
startup mount;
alter database archivelog;
alter database open;
     
DISCONNECT


EXIT
