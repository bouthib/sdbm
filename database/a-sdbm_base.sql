-- *
-- * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
-- * Licensed under the MIT license.
-- * See LICENSE file in the project root for full license information.
-- *

--
-- Script :
--    sbdm_base.sql
--
-- Description :
--    Mise en place du tablespace et du schéma SDBM.
--


WHENEVER OSERROR  EXIT 8
WHENEVER SQLERROR EXIT SQL.SQLCODE


CONNECT / as sysdba

-- Fix : Errors in file /opt/oracle/diag/rdbms/xe/XE/trace/XE_j000_?????.trc: ORA-20001: Statistics Advisor: Invalid task name for the current user
execute dbms_stats.init_package();


alter session set container = XEPDB1;

CREATE TABLESPACE SDBM_DATA
   DATAFILE '/opt/oracle/oradata/XE/XEPDB1/sdbm_data01.dbf' SIZE 16M AUTOEXTEND ON NEXT 16M
   EXTENT MANAGEMENT LOCAL UNIFORM SIZE 128K
   SEGMENT SPACE MANAGEMENT AUTO;

CREATE USER SDBM IDENTIFIED BY admin
   DEFAULT TABLESPACE SDBM_DATA
   QUOTA UNLIMITED ON SDBM_DATA;

GRANT CONNECT                    TO SDBM;
GRANT CREATE TABLE               TO SDBM;
GRANT CREATE TRIGGER             TO SDBM;
GRANT CREATE VIEW                TO SDBM;
GRANT CREATE MATERIALIZED VIEW   TO SDBM;
GRANT CREATE PROCEDURE           TO SDBM;
GRANT CREATE SEQUENCE            TO SDBM;
GRANT CREATE JOB                 TO SDBM;
GRANT ALTER SYSTEM               TO SDBM;

GRANT EXECUTE ON SYS.DBMS_LOCK   TO SDBM;
GRANT EXECUTE ON SYS.UTL_SMTP    TO SDBM;
GRANT EXECUTE ON SYS.UTL_TCP     TO SDBM;
GRANT EXECUTE ON SYS.DBMS_CRYPTO TO SDBM;


GRANT SELECT ON SYS.V_$MYSTAT    TO SDBM;
GRANT SELECT ON SYS.V_$PROCESS   TO SDBM WITH GRANT OPTION;
GRANT SELECT ON SYS.V_$SESSION   TO SDBM WITH GRANT OPTION;

BEGIN
   DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(host => '*'
                                         ,ace  =>  xs$ace_type(privilege_list => xs$name_list('connect', 'resolve')
                                                              ,principal_name => 'SDBM'
                                                              ,principal_type => xs_acl.ptype_db
                                                              )
                                         );
END;
/

DISCONNECT
EXIT
