-- *
-- * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
-- * Licensed under the MIT license.
-- * See LICENSE file in the project root for full license information.
-- *

--
-- Script :
--    sbdm_code_plsql.sql
--
-- Description :
--    Mise en place des tous le code PL/SQL du schéma SDBM.
--


WHENEVER OSERROR  EXIT 8
WHENEVER SQLERROR EXIT SQL.SQLCODE


CONNECT / as sysdba
alter session set container = XEPDB1;


SET ECHO OFF
alter session set current_schema = SDBM;


@_package/ps-apex_show_hide_memory.sql
@_package/ps-sdbm_agent.sql
@_package/ps-sdbm_apex_util.sql
@_package/ps-sdbm_base.sql
@_package/ps-sdbm_collecte.sql
@_package/ps-sdbm_smtp.sql
@_package/ps-sdbm_util.sql
@_package/ps-sdbm_audit_appl.sql

-- Trigger (avec sequence)
@_trigger/sdbm_trigger.sql

@_package/pb-apex_show_hide_memory.sql
@_package/pb-sdbm_agent.sql
@_package/pb-sdbm_apex_util.sql
@_package/pb-sdbm_base.sql
@_package/pb-sdbm_collecte.sql
@_package/pb-sdbm_smtp.sql
@_package/pb-sdbm_util.sql
@_package/pb-sdbm_audit_appl.sql

@_function/sdbm_apex_authentification_ext.sql
@_function/sdbm_apex_authentification.sql
@_function/sdbm_apex_version.sql

@_view/sdbm_apex_vue.sql

DISCONNECT
EXIT
