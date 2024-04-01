@echo off
setlocal enabledelayedexpansion

rem Oracle XE install password
set ORACLE_PASSWORD=My0raclePwd00#

rem Apex installation type : runtime | full
set APEX_PASSWORD=MyApexPwd00#
set APEX_INSTA_TYPE=runtime

rem Apex ORDS service accounts password
set APEX_SERVICE_PASSWORD=MyInternalPwd00#

set ORACLE_XE=OracleXE213_Win64
set ORACLE_XE_MSI="Oracle Database 21c Express Edition.msi"
set ORACLE_APEX=apex_23.2
set ORACLE_APEX_SCHEMA=APEX_230200
set ORDS_JAVA=OpenJDK17U-jre_x64_windows_hotspot_17.0.10_7
set ORDS_JAVA_DIR=jdk-17.0.10+7-jre
set ORACLE_ORDS=ords-23.4.0.346.1619

set SDBM_JAVA=OpenJDK8U-jre_x86-32_windows_hotspot_8u402b06
set SDBM_JAVA_DIR=jdk8u402-b06-jre


echo.
echo.
echo Installation of Simple Database Monitoring
echo --------------------------------------------------------------------------------
echo.
echo As part of this installation, the following products
echo will be installed:
echo.
echo  - Oracle Database Express Edition 21.3 (XE) - %ORACLE_XE%.zip must be available in ./download
echo  - Oracle APEX                               - %ORACLE_APEX%.zip must be available in ./download
echo  - Java                                      - %ORDS_JAVA%.zip must be available in ./download
echo  - Oracle ORDS                               - %ORACLE_ORDS%.zip must be available in ./download
echo  - SDBM server         (windows service)
echo  - SDBM data collector (windows service)
echo  - SDBM agent          (windows service)
echo.
echo.
echo Optionally, you will be asked if you want to lunch
echo others installations scripts.
echo.
echo Thoses scripts are:
echo.
echo  - SDBMAgtSecurityContext (creation of SDBMAgt security context)
echo  - SDBMAgtCreateBackupJob (creation of SDBM database RMAN backup job)
echo.
echo.
echo Requirements: 
echo.
echo  - Download.cmd must have run successfully 
echo  - You must execute this script with administators privileges
echo  - You must have at least 12GB of free disk space on the installation drive
echo  - Oracle Database Express Edition (XE) must NOT be installed on the system
echo  - The hostname length must be 16 or lower (Error : 1053 on Oracle XE installation)
echo  - Visual C++ Redistributable packages for Visual Studio 2013 must be available on the system
echo    (see https://aka.ms/highdpimfc2013x86enu)
echo.
:CONFIRMATION
set CHOIX=EMPTY
set /P CHOIX=Do you want to install Simple Database Monitoring (YES / NO)? 
if /i "%CHOIX%" == "NO"  goto :FIN
if /i "%CHOIX%" == "YES" goto :DEBUT
goto CONFIRMATION


:DEBUT

if not "%2" == ""                              goto ERR_SYNTAXE
if not exist "Install.cmd".                    goto ERR_DIR_PARENT

if not "%1" == ""                              goto FIN_DEMANDE


rem
rem Recherche des disques disponible
rem
set LDISQUE=
for %%I in (A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z) do @if exist %%I:\. set LDISQUE=!LDISQUE!,%%I
SET LDISQUE=%LDISQUE:~1%


rem
rem Mode INTERACTIF
rem
:DEMANDE

set SDBM_INSTALL_DIS=EMPTY
set /P SDBM_INSTALL_DIS=Enter the drive letter where you want to install (%LDISQUE%)? 
set SDBM_INSTALL_DIS=%SDBM_INSTALL_DIS:~0,1%
if not exist %SDBM_INSTALL_DIS%:\ echo Invalid drive letter, please try again && echo. && goto :DEMANDE
goto FIN_PARAMETRE
:FIN_DEMANDE


rem
rem Mode BATCH
rem
if not exist %1:\ goto ERR_DISQUE
set SDBM_INSTALL_DIS=%1
set SDBM_INSTALL_DIS=%SDBM_INSTALL_DIS:~0,1%
:FIN_PARAMETRE


set SDBM_INSTALL_REP_SRC=%CD%
set SDBM_INSTALL_REP_LOG=%SDBM_INSTALL_DIS%:\SDBM\_INSTALL
mkdir %SDBM_INSTALL_REP_LOG%


echo.
echo Oracle XE installation...
echo.
echo.

echo Checking if Oracle XE is already installed...
REG QUERY HKLM\SOFTWARE\Oracle\KEY_XE > NUL 2>&1
if %ERRORLEVEL% EQU 0 goto ERR_XE_EXISTE
echo OK.
echo.


echo Checking availability of TNS port...

set SDBM_TNS_PORT=1521
netstat -an | find ":%SDBM_TNS_PORT% " | find "LISTENING"
if %ERRORLEVEL% EQU 1 goto PORT_TNS_OK

set SDBM_TNS_PORT=1522
netstat -an | find ":%SDBM_TNS_PORT% " | find "LISTENING"
if %ERRORLEVEL% EQU 1 goto PORT_TNS_OK

set SDBM_TNS_PORT=1523
netstat -an | find ":%SDBM_TNS_PORT% " | find "LISTENING"
if %ERRORLEVEL% EQU 1 goto PORT_TNS_OK

set SDBM_TNS_PORT=1524
netstat -an | find ":%SDBM_TNS_PORT% " | find "LISTENING"
if %ERRORLEVEL% EQU 1 goto PORT_TNS_OK

set SDBM_TNS_PORT=1525
netstat -an | find ":%SDBM_TNS_PORT% " | find "LISTENING"
if %ERRORLEVEL% EQU 1 goto PORT_TNS_OK

set SDBM_TNS_PORT=1526
netstat -an | find ":%SDBM_TNS_PORT% " | find "LISTENING"
if %ERRORLEVEL% EQU 1 goto PORT_TNS_OK


GOTO ERR_PORT_TNS

:PORT_TNS_OK
echo OK.
echo.


echo Checking availability of HTTP port...

set SDBM_HTTP_PORT=8080
netstat -an | find ":%SDBM_HTTP_PORT% " | find "LISTENING"
if %ERRORLEVEL% EQU 1 goto PORT_HTTP_OK

set SDBM_HTTP_PORT=8081
netstat -an | find ":%SDBM_HTTP_PORT% " | find "LISTENING"
if %ERRORLEVEL% EQU 1 goto PORT_HTTP_OK

set SDBM_HTTP_PORT=8082
netstat -an | find ":%SDBM_HTTP_PORT% " | find "LISTENING"
if %ERRORLEVEL% EQU 1 goto PORT_HTTP_OK

set SDBM_HTTP_PORT=8083
netstat -an | find ":%SDBM_HTTP_PORT% " | find "LISTENING"
if %ERRORLEVEL% EQU 1 goto PORT_HTTP_OK

set SDBM_HTTP_PORT=8084
netstat -an | find ":%SDBM_HTTP_PORT% " | find "LISTENING"
if %ERRORLEVEL% EQU 1 goto PORT_HTTP_OK

set SDBM_HTTP_PORT=8085
netstat -an | find ":%SDBM_HTTP_PORT% " | find "LISTENING"
if %ERRORLEVEL% EQU 1 goto PORT_HTTP_OK


GOTO ERR_PORT_HTTP

:PORT_HTTP_OK
echo OK.
echo.


echo Saving HTTP port...
echo %SDBM_HTTP_PORT% > %SDBM_INSTALL_REP_LOG%\http.port
echo OK.
echo.

mkdir %SDBM_INSTALL_REP_SRC%\download\%ORACLE_XE%
unzip -n -q -d %SDBM_INSTALL_REP_SRC%\download\%ORACLE_XE% %SDBM_INSTALL_REP_SRC%\download\%ORACLE_XE%.zip


echo.
echo Installation of Oracle XE....

set ORACLE_HOME=
call "%SDBM_INSTALL_REP_SRC%\OracleXE-Install.iss.cmd" > "%SDBM_INSTALL_REP_LOG%\OracleXE-Install.iss"

%SDBM_INSTALL_REP_SRC%\download\%ORACLE_XE%\setup.exe /s /v"RSP_FILE=%SDBM_INSTALL_REP_LOG%\OracleXE-Install.iss" /v"/L*v %SDBM_INSTALL_REP_LOG%\OracleXE-Install.log" /v"/qn"
if %ERRORLEVEL% NEQ 0 goto ERR_XE_ERR_INSTALL

echo End of installation of Oracle XE.
echo.


echo.
echo Installation of wallet-smtp in %SDBM_INSTALL_DIS%:\SDBM\oraclexe\admin\XE...

mkdir %SDBM_INSTALL_DIS%:\SDBM\oraclexe\admin\XE\wallet-smtp
unzip -q -d %SDBM_INSTALL_DIS%:\SDBM\oraclexe\admin\XE\wallet-smtp %SDBM_INSTALL_REP_SRC%\download\wallet-smtp.zip

echo End of installation of wallet-smtp.
echo.


echo.
echo Installation of APEX...
echo.

unzip -n -q -d %SDBM_INSTALL_DIS%:\SDBM\oraclexe %SDBM_INSTALL_REP_SRC%\download\%ORACLE_APEX%.zip

if "%apex_insta_type%" == "full"    call "%SDBM_INSTALL_REP_SRC%\sdbm_setup-a(full).sql.cmd"    > "%SDBM_INSTALL_REP_LOG%\sdbm_setup-a.sql"
if "%apex_insta_type%" == "runtime" call "%SDBM_INSTALL_REP_SRC%\sdbm_setup-a(runtime).sql.cmd" > "%SDBM_INSTALL_REP_LOG%\sdbm_setup-a.sql"
call "%SDBM_INSTALL_REP_SRC%\sdbm_setup-b.sql.cmd" > "%SDBM_INSTALL_REP_LOG%\sdbm_setup-b.sql"
call "%SDBM_INSTALL_REP_SRC%\sdbm_setup-c.sql.cmd" > "%SDBM_INSTALL_REP_LOG%\sdbm_setup-c.sql"
call "%SDBM_INSTALL_REP_SRC%\sdbm_setup-d.sql.cmd" > "%SDBM_INSTALL_REP_LOG%\sdbm_setup-d.sql"
if "%apex_insta_type%" == "full"    call "%SDBM_INSTALL_REP_SRC%\sdbm_setup-e(full).sql.cmd"    > "%SDBM_INSTALL_REP_LOG%\sdbm_setup-e.sql"
if "%apex_insta_type%" == "runtime" call "%SDBM_INSTALL_REP_SRC%\sdbm_setup-e(runtime).sql.cmd" > "%SDBM_INSTALL_REP_LOG%\sdbm_setup-e.sql"
copy "%SDBM_INSTALL_REP_SRC%\sdbm_setup-f.sql"       "%SDBM_INSTALL_REP_LOG%\sdbm_setup-f.sql"
echo.

set PATH=%SDBM_INSTALL_DIS%:\SDBM\oraclexe\dbhomeXE\bin;%PATH%
set ORACLE_SID=XE
set NLS_LANG=AMERICAN_AMERICA.AL32UTF8

pushd "%SDBM_INSTALL_DIS%:\SDBM\oraclexe\apex"
echo %SDBM_INSTALL_REP_LOG%\sdbm_setup-a.sql will be executed... Output is "%SDBM_INSTALL_REP_LOG%\sdbm_setup-a.log"
sqlplus -s /nolog @"%SDBM_INSTALL_REP_LOG%\sdbm_setup-a.sql" > "%SDBM_INSTALL_REP_LOG%\sdbm_setup-a.log" 2>&1

echo %SDBM_INSTALL_REP_LOG%\sdbm_setup-b.sql will be executed... Output is "%SDBM_INSTALL_REP_LOG%\sdbm_setup-b.log"
sqlplus -s /nolog @"%SDBM_INSTALL_REP_LOG%\sdbm_setup-b.sql" > "%SDBM_INSTALL_REP_LOG%\sdbm_setup-b.log" 2>&1

echo %SDBM_INSTALL_REP_LOG%\sdbm_setup-c.sql will be executed... Output is "%SDBM_INSTALL_REP_LOG%\sdbm_setup-c.log"
sqlplus -s /nolog @"%SDBM_INSTALL_REP_LOG%\sdbm_setup-c.sql" > "%SDBM_INSTALL_REP_LOG%\sdbm_setup-c.log" 2>&1
del "%SDBM_INSTALL_REP_LOG%\sdbm_setup-c.sql"
popd

echo.
echo End of APEX installation
echo.


echo.
echo Installation of Java - ORDS...

if not exist %SDBM_INSTALL_DIS%:\SDBM\java (mkdir %SDBM_INSTALL_DIS%:\SDBM\java)
unzip -n -q -d %SDBM_INSTALL_DIS%:\SDBM\java %SDBM_INSTALL_REP_SRC%\download\%ORDS_JAVA%.zip

echo End of installation of Java
echo.


echo.
echo Installation of Oracle ORDS...
echo.

if not exist %SDBM_INSTALL_DIS%:\SDBM\ords (mkdir %SDBM_INSTALL_DIS%:\SDBM\ords)
unzip -n -q -d %SDBM_INSTALL_DIS%:\SDBM\ords %SDBM_INSTALL_REP_SRC%\download\%ORACLE_ORDS%.zip

if not exist %SDBM_INSTALL_DIS%:\SDBM\ords.config (mkdir %SDBM_INSTALL_DIS%:\SDBM\ords.config)

SET JAVA_HOME="%SDBM_INSTALL_DIS%:\SDBM\java\%ORDS_JAVA_DIR%"
SET PATH=%SDBM_INSTALL_DIS%:\SDBM\ords\bin;%PATH%

echo "%ORACLE_PASSWORD%"        > %SDBM_INSTALL_DIS%:\SDBM\ords.config\password
echo "%APEX_SERVICE_PASSWORD%" >> %SDBM_INSTALL_DIS%:\SDBM\ords.config\password
echo "%APEX_SERVICE_PASSWORD%" >> %SDBM_INSTALL_DIS%:\SDBM\ords.config\password

ords --config %SDBM_INSTALL_DIS%:\SDBM\ords.config install --admin-user SYS --proxy-user --proxy-user-tablespace SYSAUX --schema-tablespace SYSAUX --feature-rest-enabled-sql false --feature-sdw false --db-hostname %COMPUTERNAME% --db-port 1521 --db-servicename XEPDB1.sdbm.ca --log-folder %SDBM_INSTALL_DIS%:\SDBM\ords.config --password-stdin < %SDBM_INSTALL_DIS%:\SDBM\ords.config\password > %SDBM_INSTALL_DIS%:\SDBM\ords.config\ords-config.log
del %SDBM_INSTALL_DIS%:\SDBM\ords.config\password
ords --config %SDBM_INSTALL_DIS%:\SDBM\ords.config config set standalone.http.port                   %SDBM_HTTP_PORT%                               >> %SDBM_INSTALL_DIS%:\SDBM\ords.config/ords-config.log
ords --config %SDBM_INSTALL_DIS%:\SDBM\ords.config config set standalone.static.context.path         /i                                             >> %SDBM_INSTALL_DIS%:\SDBM\ords.config/ords-config.log
ords --config %SDBM_INSTALL_DIS%:\SDBM\ords.config config set standalone.static.path                 %SDBM_INSTALL_DIS%:\SDBM\oraclexe\apex\images\ >> %SDBM_INSTALL_DIS%:\SDBM\ords.config/ords-config.log
ords --config %SDBM_INSTALL_DIS%:\SDBM\ords.config config set standalone.context.path                /ords                                          >> %SDBM_INSTALL_DIS%:\SDBM\ords.config/ords-config.log
rem Allow to workarroud the 403 Forbidden within ORDS - could be restrict base on the real domain name web acces - required for HTTPS option
ords --config %SDBM_INSTALL_DIS%:\SDBM\ords.config config set security.externalSessionTrustedOrigins "*"                                            >> %SDBM_INSTALL_DIS%:\SDBM\ords.config/ords-config.log


copy %SDBM_INSTALL_REP_SRC%\download\nssm.exe %SDBM_INSTALL_DIS%:\SDBM
%SDBM_INSTALL_DIS%:\SDBM\nssm install SDBMORDS %SDBM_INSTALL_DIS%:\SDBM\ords\bin\ords.exe --config %SDBM_INSTALL_DIS%:\SDBM\ords.config serve
%SDBM_INSTALL_DIS%:\SDBM\nssm set SDBMORDS AppEnvironmentExtra JAVA_HOME="%JAVA_HOME%" PATH="%SDBM_INSTALL_DIS%:\SDBM\ords\bin;%PATH%"
%SDBM_INSTALL_DIS%:\SDBM\nssm set SDBMORDS AppStdout "%SDBM_INSTALL_DIS%:\SDBM\ords.config\stdout.log"
%SDBM_INSTALL_DIS%:\SDBM\nssm set SDBMORDS AppStderr "%SDBM_INSTALL_DIS%:\SDBM\ords.config\stderr.log"
net start SDBMORDS
echo.
echo End of installation of Oracle ORDS
echo.


echo.
echo Creation of SDBM schema...
echo.

echo %SDBM_INSTALL_REP_LOG%\sdbm_setup-d.sql will be executed... Output is "%SDBM_INSTALL_REP_LOG%\sdbm_setup-d.log"
sqlplus -s /nolog @"%SDBM_INSTALL_REP_LOG%\sdbm_setup-d.sql" > "%SDBM_INSTALL_REP_LOG%\sdbm_setup-d.log" 2>&1

echo.
echo End of creation of SDBM schema
echo.


echo.
echo Installation of SDBM...
echo.

copy "%SDBM_INSTALL_REP_SRC%\exp-sdbm.dpdmp" %SDBM_INSTALL_DIS%:\SDBM\oraclexe\dbhomeXE
echo.

set LOCAL=(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=%COMPUTERNAME%)(PORT=1521))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=XEPDB1.sdbm.ca)))
echo impdp will be executed... Output is "%SDBM_INSTALL_REP_LOG%\imp-sdbm.log"
impdp SDBM/admin directory=ORACLE_HOME dumpfile=exp-sdbm.dpdmp exclude=STATISTICS > "%SDBM_INSTALL_REP_LOG%\imp-sdbm.log" 2>&1

echo %SDBM_INSTALL_REP_LOG%\sdbm_setup-e.sql will be executed... Output is "%SDBM_INSTALL_REP_LOG%\sdbm_setup-e.log"
sqlplus -s /nolog @"%SDBM_INSTALL_REP_LOG%\sdbm_setup-e.sql" > "%SDBM_INSTALL_REP_LOG%\sdbm_setup-e.log" 2>&1
del "%SDBM_INSTALL_REP_LOG%\sdbm_setup-e.sql"

echo %SDBM_INSTALL_REP_LOG%\sdbm_setup-f.sql will be executed... Output is "%SDBM_INSTALL_REP_LOG%\sdbm_setup-f.log"
fart "%SDBM_INSTALL_REP_LOG%\sdbm_setup-f.sql" "localhost" "%COMPUTERNAME%"
sqlplus -s /nolog @"%SDBM_INSTALL_REP_LOG%\sdbm_setup-f.sql" > "%SDBM_INSTALL_REP_LOG%\sdbm_setup-f.log" 2>&1
set LOCAL=


echo.
echo Installation of Java - SDBM...

unzip -n -q -d %SDBM_INSTALL_DIS%:\SDBM\java %SDBM_INSTALL_REP_SRC%\download\%SDBM_JAVA%.zip


echo.
echo Installation of services - SDBM...

unzip -n -q -d %SDBM_INSTALL_DIS%:\SDBM sdbm.zip
fart %SDBM_INSTALL_DIS%:\SDBM\sdbmsrv\InstallSDBMSrv.cmd "{SDBM_JAVA_DIR}" "%SDBM_JAVA_DIR%"
fart %SDBM_INSTALL_DIS%:\SDBM\sdbmdac\InstallSDBMDac.cmd "{SDBM_JAVA_DIR}" "%SDBM_JAVA_DIR%"
fart %SDBM_INSTALL_DIS%:\SDBM\sdbmagt\InstallSDBMAgt.cmd "{SDBM_JAVA_DIR}" "%SDBM_JAVA_DIR%"

fart %SDBM_INSTALL_DIS%:\SDBM\sdbmsrv\SDBMSrv.properties "localhost:1521/XEPDB1" "%COMPUTERNAME%:1521/XEPDB1.sdbm.ca"
fart %SDBM_INSTALL_DIS%:\SDBM\sdbmdac\SDBMDac.properties "localhost:1521/XEPDB1" "%COMPUTERNAME%:1521/XEPDB1.sdbm.ca"
fart %SDBM_INSTALL_DIS%:\SDBM\sdbmagt\SDBMAgt.properties "localhost:1521/XEPDB1" "%COMPUTERNAME%:1521/XEPDB1.sdbm.ca"

pushd %SDBM_INSTALL_DIS%:\SDBM\sdbmagt
call InstallSDBMAgt.cmd
popd

pushd %SDBM_INSTALL_DIS%:\SDBM\sdbmdac
call InstallSDBMDaC.cmd
popd

pushd %SDBM_INSTALL_DIS%:\SDBM\sdbmsrv
call InstallSDBMSrv.cmd
popd

echo.
net start SDBMAgt
net start SDBMDaC
net start SDBMSrv
echo.

call SDBMAgtSecurityContext.cmd
call SDBMAgtCreateBackupJob.cmd


echo.
echo End of installation of SDBM.
echo.



echo.                                                                                     > %SDBM_INSTALL_DIS%:\SDBM\ReadMe.txt
echo.                                                                                    >> %SDBM_INSTALL_DIS%:\SDBM\ReadMe.txt
echo *********************************************************************************** >> %SDBM_INSTALL_DIS%:\SDBM\ReadMe.txt
echo *                                                                                   >> %SDBM_INSTALL_DIS%:\SDBM\ReadMe.txt
echo * IMPORTANT INFORMATION:                                                            >> %SDBM_INSTALL_DIS%:\SDBM\ReadMe.txt
echo *                                                                                   >> %SDBM_INSTALL_DIS%:\SDBM\ReadMe.txt
echo *    SDBM HTTP address:                                                             >> %SDBM_INSTALL_DIS%:\SDBM\ReadMe.txt
echo *      http://%COMPUTERNAME%:%SDBM_HTTP_PORT%/ords/f?p=SDBM                         >> %SDBM_INSTALL_DIS%:\SDBM\ReadMe.txt
echo *      (If you want to use HTTPS security, please execute InstallHTTPSOption.cmd)   >> %SDBM_INSTALL_DIS%:\SDBM\ReadMe.txt
echo *                                                                                   >> %SDBM_INSTALL_DIS%:\SDBM\ReadMe.txt
echo *    SDBM user / password:                                                          >> %SDBM_INSTALL_DIS%:\SDBM\ReadMe.txt
echo *       admin / admin                                                               >> %SDBM_INSTALL_DIS%:\SDBM\ReadMe.txt
echo *                                                                                   >> %SDBM_INSTALL_DIS%:\SDBM\ReadMe.txt
echo *********************************************************************************** >> %SDBM_INSTALL_DIS%:\SDBM\ReadMe.txt
echo.                                                                                    >> %SDBM_INSTALL_DIS%:\SDBM\ReadMe.txt
echo.                                                                                    >> %SDBM_INSTALL_DIS%:\SDBM\ReadMe.txt
type %SDBM_INSTALL_DIS%:\SDBM\ReadMe.txt
pause

start http://%COMPUTERNAME%:%SDBM_HTTP_PORT%/ords/f?p=SDBM

GOTO FIN



:ERR_SYNTAXE
echo.
echo ERROR : INSTALL.CMD [drive letter for installation]
echo          Ex. INSTALL.CMD C
echo.
pause
GOTO FIN


:ERR_DIR_PARENT
echo.
echo ERROR : INSTALL.CMD must be execute from his current directory
echo          Ex. CD [directory where INSTALL.CMD is]
echo              INSTALL.CMD C
echo.
pause
GOTO FIN


:ERR_DISQUE
echo.
echo ERROR : Disk %1:\ is not available.
echo.
pause
GOTO FIN


:ERR_XE_EXISTE
echo.
echo ERROR : Oracle Express is already installed on this system.
echo.
pause
GOTO FIN

:ERR_PORT_TNS
echo.
echo ERROR : Unable to find an available TNS port (range from 1521 to 1526).
echo.
pause
GOTO FIN

:ERR_PORT_MTS
echo.
echo ERROR : Unable to find an available MTS port (range from 2030 to 2035).
echo.
pause
GOTO FIN

:ERR_PORT_HTTP
echo.
echo ERROR : Unable to find an available HTTP port (range from 8080 to 8085).
echo.
pause
GOTO FIN

:ERR_XE_ERR_INSTALL
echo.
echo ERROR : Oracle XE installation has aborted.
echo.
pause
GOTO FIN


:FIN
endlocal
