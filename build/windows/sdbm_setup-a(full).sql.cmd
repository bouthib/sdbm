echo CONNECT / AS SYSDBA
echo alter session set container = XEPDB1;
echo.
echo @apexins.sql SYSAUX SYSAUX TEMP /i/
echo.
echo BEGIN
echo   APEX_UTIL.set_security_group_id(10);
echo   APEX_UTIL.create_user(p_user_name       =^> 'ADMIN'
echo                        ,p_email_address   =^> 'admin'
echo                        ,p_web_password    =^> '%apex_password%'
echo                        ,p_developer_privs =^> 'ADMIN'
echo                        );
echo.                                                
echo   APEX_UTIL.set_security_group_id(null);
echo   COMMIT;
echo.
echo END;
echo /
echo.
echo @apex_rest_config_core.sql @ %apex_service_password% %apex_service_password%
echo.
echo DISCONNECT
echo.
echo.
echo exit
