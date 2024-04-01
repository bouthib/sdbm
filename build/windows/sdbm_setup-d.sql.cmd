echo CONNECT / AS SYSDBA
echo alter session set container = XEPDB1;
echo.
echo CREATE TABLESPACE SDBM_DATA
echo    DATAFILE '%SDBM_INSTALL_DIS%:\SDBM\ORACLEXE\oradata\XE\XEPDB1\SDBM_DATA01.DBF' SIZE 129M AUTOEXTEND ON NEXT 128M
echo    EXTENT MANAGEMENT LOCAL UNIFORM SIZE 128K
echo    SEGMENT SPACE MANAGEMENT AUTO;
echo.
echo CREATE USER SDBM IDENTIFIED BY admin
echo    DEFAULT TABLESPACE SDBM_DATA
echo    QUOTA UNLIMITED ON SDBM_DATA;
echo.
echo GRANT READ, WRITE ON DIRECTORY ORACLE_HOME TO SDBM;
echo ALTER USER SDBM IDENTIFIED BY admin ACCOUNT UNLOCK;
echo.
echo GRANT CONNECT                    TO SDBM;
echo GRANT CREATE TABLE               TO SDBM;
echo GRANT CREATE TRIGGER             TO SDBM;
echo GRANT CREATE VIEW                TO SDBM;
echo GRANT CREATE MATERIALIZED VIEW   TO SDBM;
echo GRANT CREATE PROCEDURE           TO SDBM;
echo GRANT CREATE SEQUENCE            TO SDBM;
echo GRANT CREATE JOB                 TO SDBM;
echo GRANT ALTER SYSTEM               TO SDBM;
echo.
echo GRANT EXECUTE ON SYS.DBMS_LOCK   TO SDBM;
echo GRANT EXECUTE ON SYS.UTL_SMTP    TO SDBM;
echo GRANT EXECUTE ON SYS.UTL_TCP     TO SDBM;
echo GRANT EXECUTE ON SYS.DBMS_CRYPTO TO SDBM;
echo.
echo GRANT SELECT ON SYS.V_$MYSTAT  TO SDBM;
echo GRANT SELECT ON SYS.V_$PROCESS TO SDBM WITH GRANT OPTION;
echo GRANT SELECT ON SYS.V_$SESSION TO SDBM WITH GRANT OPTION;
echo.
echo BEGIN
echo.
echo    DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(host =^> '*'
echo                                          ,ace =^> xs$ace_type(privilege_list =^> xs$name_list('connect', 'resolve')
echo                                                             ,principal_name =^> 'SDBM'
echo                                                             ,principal_type =^> xs_acl.ptype_db
echo                                                             )
echo                                          );
echo.
echo END;
echo /
echo.
echo.
echo -- Création de l'usager de SDBMSRV (connexion serveur)
echo CREATE USER SDBMSRV
echo    IDENTIFIED BY "changeme-srv";
echo.
echo GRANT CONNECT                    TO SDBMSRV;
echo.
echo.
echo -- Création de l'usager de SDBMAGT (connexion agent)
echo CREATE USER SDBMAGT
echo    IDENTIFIED BY "changeme-agt";
echo.
echo GRANT CONNECT                    TO SDBMAGT;
echo.
echo.
echo -- Création de l'usager de monitoring de l'instance local SDBM
echo CREATE USER SDBMON
echo    IDENTIFIED BY "changeme-mon";
echo.
echo GRANT CREATE SESSION      TO SDBMON;
echo GRANT SELECT_CATALOG_ROLE TO SDBMON;
echo.
echo DISCONNECT
echo.
echo.
echo exit
