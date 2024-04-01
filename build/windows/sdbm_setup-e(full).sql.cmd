echo CONNECT / AS SYSDBA
echo alter session set container = XEPDB1;
echo.
echo @@?\rdbms\admin\utlrp
echo select count(*) from dba_objects where status != 'VALID';
echo.
echo execute DBMS_XDB.SETLISTENERLOCALACCESS(FALSE);
echo execute APEX_INSTANCE_ADMIN.ADD_WORKSPACE(P_WORKSPACE_ID =^> 1934305315547664, P_WORKSPACE =^> 'SDBM', P_SOURCE_IDENTIFIER =^> 'SDBM', P_PRIMARY_SCHEMA =^> 'SDBM', P_ADDITIONAL_SCHEMAS =^> NULL);
echo execute APEX_INSTANCE_ADMIN.ENABLE_WORKSPACE('SDBM');
echo.
echo BEGIN
echo.
echo    APEX_UTIL.set_security_group_id(P_SECURITY_GROUP_ID =^> 1934305315547664);
echo    APEX_UTIL.create_user(p_user_name       =^> 'ADMIN'
echo                         ,p_email_address   =^> 'admin'
echo                         ,p_web_password    =^> '%apex_password%'
echo                         ,p_developer_privs =^> 'ADMIN'
echo                         );
echo.
echo END;
echo /
echo.
echo alter user %ORACLE_APEX_SCHEMA% account unlock;
echo alter user %ORACLE_APEX_SCHEMA% identified by admin;
echo.
echo CONNECT %ORACLE_APEX_SCHEMA%/admin
echo @download\sdbm_apex_f101.release.0.32.1.sql
echo @download\sdbm_apex_f111.release.0.32.1.sql
echo @download\sdbm_apex_f101.static_file.sql
echo DISCONNECT
echo.
echo.
echo alter user %ORACLE_APEX_SCHEMA% account lock;
echo alter user SDBM        account lock;
echo REVOKE READ, WRITE ON DIRECTORY ORACLE_HOME FROM SDBM;
echo.
echo DISCONNECT
echo.
echo.
echo exit
