echo CONNECT / AS SYSDBA
echo alter session set container = XEPDB1;
echo.
echo @?\rdbms\admin\utlrp
echo select count(*) from dba_objects where status != 'VALID';
echo.
echo ALTER SESSION SET CURRENT_SCHEMA = %ORACLE_APEX_SCHEMA%;
echo @builder/fr/rt_fr.sql
echo.
echo DISCONNECT
echo.
echo.
echo exit
