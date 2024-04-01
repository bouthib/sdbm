echo CONNECT / AS SYSDBA
echo alter session set container = XEPDB1;
echo.
echo ALTER PROFILE DEFAULT LIMIT PASSWORD_LIFE_TIME UNLIMITED;
echo ALTER USER APEX_LISTENER     IDENTIFIED BY "%apex_service_password%" ACCOUNT UNLOCK;
echo ALTER USER APEX_PUBLIC_USER   IDENTIFIED BY "%apex_service_password%" ACCOUNT UNLOCK;
echo ALTER USER APEX_REST_PUBLIC_USER IDENTIFIED BY "%apex_service_password%" ACCOUNT UNLOCK;
echo.
echo DISCONNECT
echo.
echo.
echo exit
