@echo off
setlocal enabledelayedexpansion

rem https://www.apachehaus.com/cgi-bin/download.plx?dli=wUFFjUVVUQ41EVJVjSIB3dhNlVUNlVSZ0SqtWNSZUR
set APACHE=httpd-2.4.55-o111s-x64-vs17
set APACHE_DIR=Apache24


echo.
echo.
echo Installation of HTTPS option
echo --------------------------------------------------------------------------------
echo.
echo This is an optional step that allow to client to communicate with SDBM web site
echo with the HTTPS protocol.
echo.
echo The following products will be installed:
echo.
echo  - Apache Web server - %APACHE%.zip must be available in ./download
echo.
echo Requirements: 
echo.
echo  - You must execute this script with administators privileges
echo  - Apache Web server must NOT be installed on the system
echo  - You must provide the DNS hostname for web access
echo.
:CONFIRMATION
set CHOIX=EMPTY
set /P CHOIX=Do you want to install HTTPS option (YES / NO)? 
if /i "%CHOIX%" == "NO"  goto :FIN
if /i "%CHOIX%" == "YES" goto :DEBUT
goto CONFIRMATION


:DEBUT

if not "%2" == ""                       goto ERR_SYNTAXE
if not exist "InstallHTTPSOption.cmd".  goto ERR_DIR_PARENT


rem
rem Recherche de l'installation SDBM
rem
set SDBM_INSTALL_DIS=EMPTY
for %%I in (A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z) do @if exist %%I:\SDBM\_INSTALL. set SDBM_INSTALL_DIS=%%I && goto FIN_RECHERCHE
if "%SDBM_INSTALL_DIS%" == "EMPTY" goto :ERR_DISQUE_SDBM
:FIN_RECHERCHE
set SDBM_INSTALL_DIS=%SDBM_INSTALL_DIS:~0,1%



if not "%1" == "" goto FIN_DEMANDE

rem
rem Mode INTERACTIF
rem

:DEMANDE
set SDBM_HOST_DOMAIN=EMPTY
set /P SDBM_HOST_DOMAIN=Enter the DNS hostname for web access (could be your current host FQDN)? 
if "%SDBM_HOST_DOMAIN%" == "EMPTY" goto :DEMANDE
goto FIN_PARAMETRE
:FIN_DEMANDE


rem
rem Mode BATCH
rem
set SDBM_ADRESSE_HTTP=%2
:FIN_PARAMETRE


set SDBM_INSTALL_REP_SRC=%CD%
set SDBM_INSTALL_REP_LOG=%SDBM_INSTALL_DIS%:\SDBM\_INSTALL
set SDBM_HTTP_PORT=0



echo.
echo Checking if SDBM is installed...
echo.
echo.
if not exist %SDBM_INSTALL_REP_LOG%\http.port. goto ERR_DISQUE_SDBM
for /F %%I in (%SDBM_INSTALL_REP_LOG%\http.port) do if %SDBM_HTTP_PORT% EQU 0 set SDBM_HTTP_PORT=%%I
echo The HTTP SDBM port is : %SDBM_HTTP_PORT%

echo OK.
echo.



echo.
echo Apache installation...
echo.
echo.


echo Checking if Apache is already installed...
REG QUERY HKLM\SYSTEM\CurrentControlSet\Services\SDBMApache > NUL 2>&1
if %ERRORLEVEL% EQU 0 goto ERR_APACHE_EXISTANT
echo OK.


echo Checking availability of HTTP port...

netstat -an | find "0.0.0.0:80 " | find "LISTENING"
if %ERRORLEVEL% EQU 0 goto ERR_PORT_HTTP

echo OK.
echo.


echo Checking availability of HTTPS port...

netstat -an | find "0.0.0.0:443 " | find "LISTENING"
if %ERRORLEVEL% EQU 0 goto ERR_PORT_HTTPS

echo OK.
echo.


echo.
echo Installation of Apache software...

mkdir %SDBM_INSTALL_DIS%:\SDBM\apache
unzip -n -q -d %SDBM_INSTALL_DIS%:\SDBM\apache %SDBM_INSTALL_REP_SRC%\download\%APACHE%.zip
fart %SDBM_INSTALL_DIS%:\SDBM\apache\%APACHE_DIR%\conf\httpd.conf "Define SRVROOT \"/Apache24\""                            "Define SRVROOT \"%SDBM_INSTALL_DIS%:\SDBM\apache\%APACHE_DIR%\""
fart %SDBM_INSTALL_DIS%:\SDBM\apache\%APACHE_DIR%\conf\httpd.conf "#LoadModule proxy_module modules/mod_proxy.so"           "LoadModule proxy_module modules/mod_proxy.so"
fart %SDBM_INSTALL_DIS%:\SDBM\apache\%APACHE_DIR%\conf\httpd.conf "#LoadModule proxy_http_module modules/mod_proxy_http.so" "LoadModule proxy_http_module modules/mod_proxy_http.so"


rem Ajout de la configuration SDBM...
echo.>>                                                               %SDBM_INSTALL_DIS%:\SDBM\apache\%APACHE_DIR%\conf\httpd.conf
echo # SDBM>>                                                         %SDBM_INSTALL_DIS%:\SDBM\apache\%APACHE_DIR%\conf\httpd.conf
echo ProxyPass        /ords  http://localhost:%SDBM_HTTP_PORT%/ords>> %SDBM_INSTALL_DIS%:\SDBM\apache\%APACHE_DIR%\conf\httpd.conf
echo ProxyPassReverse /ords  http://localhost:%SDBM_HTTP_PORT%/ords>> %SDBM_INSTALL_DIS%:\SDBM\apache\%APACHE_DIR%\conf\httpd.conf
echo ProxyPass        /i     http://localhost:%SDBM_HTTP_PORT%/i>>    %SDBM_INSTALL_DIS%:\SDBM\apache\%APACHE_DIR%\conf\httpd.conf
echo ProxyPassReverse /i     http://localhost:%SDBM_HTTP_PORT%/i>>    %SDBM_INSTALL_DIS%:\SDBM\apache\%APACHE_DIR%\conf\httpd.conf
echo Redirect 302 / https://%SDBM_HOST_DOMAIN%/ords/f?p=SDBM>>        %SDBM_INSTALL_DIS%:\SDBM\apache\%APACHE_DIR%\conf\httpd.conf

pushd %CD%
cd /d %SDBM_INSTALL_DIS%:\SDBM\apache\%APACHE_DIR%\bin
httpd -k install -n "SDBMApache"
popd
if %ERRORLEVEL% NEQ 0 goto ERR_APACHE_ERR_INSTALL
echo OK.

echo.
echo Generation of self-signed certificate...
pushd %CD%
cd /d %SDBM_INSTALL_DIS%:\SDBM\apache\%APACHE_DIR%\bin
openssl req -config ../conf/openssl.cnf -new -x509 -days 9125 -sha1 -newkey rsa:1024 -nodes -keyout ../conf/ssl/server.key -out ../conf/ssl/server.crt -subj "/O=Simple Database Monitoring - SDBM/OU=Simple Database Monitoring - SDBM/CN=%SDBM_HOST_DOMAIN%"
popd
echo OK.

echo.
echo Starting Apache service...
net start SDBMApache

echo.
echo.
echo End of installation of Apache.
echo.
echo.



echo.                                                                 > %SDBM_INSTALL_DIS%:\SDBM\ReadMeHTTPS.txt
echo.                                                                >> %SDBM_INSTALL_DIS%:\SDBM\ReadMeHTTPS.txt
echo **************************************************              >> %SDBM_INSTALL_DIS%:\SDBM\ReadMeHTTPS.txt
echo *                                                               >> %SDBM_INSTALL_DIS%:\SDBM\ReadMeHTTPS.txt
echo * IMPORTANT INFORMATION:                                        >> %SDBM_INSTALL_DIS%:\SDBM\ReadMeHTTPS.txt
echo *                                                               >> %SDBM_INSTALL_DIS%:\SDBM\ReadMeHTTPS.txt
echo *    SDBM HTTPS address:                                        >> %SDBM_INSTALL_DIS%:\SDBM\ReadMeHTTPS.txt
echo *        https://%SDBM_HOST_DOMAIN%                             >> %SDBM_INSTALL_DIS%:\SDBM\ReadMeHTTPS.txt
echo *                                                               >> %SDBM_INSTALL_DIS%:\SDBM\ReadMeHTTPS.txt
echo **************************************************              >> %SDBM_INSTALL_DIS%:\SDBM\ReadMeHTTPS.txt
echo.                                                                >> %SDBM_INSTALL_DIS%:\SDBM\ReadMeHTTPS.txt
echo.                                                                >> %SDBM_INSTALL_DIS%:\SDBM\ReadMeHTTPS.txt
type %SDBM_INSTALL_DIS%:\SDBM\ReadMeHTTPS.txt
pause

start https://%SDBM_HOST_DOMAIN%

GOTO FIN



:ERR_SYNTAXE
echo.
echo ERROR : InstallHTTPSOption.cmd [DNS hostname for web access]
echo          Ex. InstallHTTPSOption.cmd myhost.mydomain
echo.
pause
GOTO FIN


:ERR_DIR_PARENT
echo.
echo ERROR : InstallHTTPSOption.cmd must be execute from his current directory
echo          Ex. CD [directory where INSTALL.CMD is]
echo              InstallHTTPSOption.cmd myhost.mydomain
echo.
pause
GOTO FIN


:ERR_DISQUE_SDBM
echo.
echo ERROR : Unable to find SDBM installation (?:\SDBM\_INSTALL does not exists).
echo.
pause
GOTO FIN

:ERR_APACHE_EXISTANT
echo.
echo ERROR : Apache is already installed on this system.
echo.
pause
GOTO FIN

:ERR_PORT_HTTP
echo.
echo ERROR : Port 80 is not available.
echo.
pause
GOTO FIN

:ERR_PORT_HTTPS
echo.
echo ERROR : Port 443 is not available.
echo.
pause
GOTO FIN

:ERR_APACHE_ERR_INSTALL
echo.
echo ERROR : Apache installation has aborted.
echo.
pause
GOTO FIN


:FIN
endlocal
