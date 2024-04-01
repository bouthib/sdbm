echo CONNECT / AS SYSDBA
echo alter session set container = XEPDB1;
echo.
echo @apxrtins SYSAUX SYSAUX TEMP /i/
echo.
echo @apex_rest_config_core.sql @ %apex_service_password% %apex_service_password%
echo.
echo DISCONNECT
echo.
echo.
echo exit
