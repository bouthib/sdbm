-- *
-- * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
-- * Licensed under the MIT license.
-- * See LICENSE file in the project root for full license information.
-- *

--
-- Script :
--    z-sbdm_unlock.sql
--
-- Description :
--    Fermeture du propriétaire
-


WHENEVER OSERROR  EXIT 8
WHENEVER SQLERROR EXIT SQL.SQLCODE


CONNECT / as sysdba
alter session set container = XEPDB1;

GRANT READ, WRITE ON DIRECTORY ORACLE_HOME TO SDBM;
ALTER USER SDBM ACCOUNT UNLOCK;


EXIT
