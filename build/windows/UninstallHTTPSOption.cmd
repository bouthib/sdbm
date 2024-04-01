@echo off
setlocal enabledelayedexpansion

set APACHE_DIR=Apache24


echo.
echo.
echo Uninstall of HTTPS option (Apache Web server)
echo --------------------------------------------------------------------------------
echo.
echo The following products will be removed:
echo.
echo  - Apache Web server
echo.
echo Requirements: 
echo.
echo  - You must execute this script with administators privileges
echo  - Apache Web server must be installed on the system
echo.
:CONFIRMATION
set CHOIX=EMPTY
set /P CHOIX=Do you want to uninstall SSL option (YES / NO)? 
if /i "%CHOIX%" == "NO"  goto :FIN
if /i "%CHOIX%" == "YES" goto :DEBUT
goto CONFIRMATION


:DEBUT

if not "%1" == ""                         goto ERR_SYNTAXE
if not exist "UninstallHTTPSOption.cmd".  goto ERR_DIR_PARENT


rem
rem Recherche de l'installation Apache (SDBM)
rem
set SDBM_INSTALL_DIS=EMPTY
for %%I in (A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z) do @if exist %%I:\SDBM\apache. set SDBM_INSTALL_DIS=%%I && goto FIN_RECHERCHE
if "%SDBM_INSTALL_DIS%" == "EMPTY" goto :ERR_DISQUE_SDBM
:FIN_RECHERCHE
set SDBM_INSTALL_DIS=%SDBM_INSTALL_DIS:~0,1%



set SDBM_INSTALL_REP_SRC=%CD%


echo.
echo Uninstall of Apache...
echo.
echo *** CTRL-C to cancel ***
pause

echo.
echo Uninstalling Apache...
net stop SDBMApache

pushd %CD%
cd /d %SDBM_INSTALL_DIS%:\SDBM\apache\%APACHE_DIR%\bin
httpd -k uninstall -n "SDBMApache"
popd
echo OK.

echo.
echo End of uninstall of Apache.
echo.
echo.


echo.
echo Removal of Apache directory (SDBM)...
echo.
echo *** CTRL-C to cancel ***
pause

rmdir /S /Q %SDBM_INSTALL_DIS%:\SDBM\apache
del /F /Q %SDBM_INSTALL_DIS%:\SDBM\ReadMeHTTPS.txt

echo.
echo End of removal of Apache directory (SDBM).
echo.
echo.

pause
GOTO FIN



:ERR_SYNTAXE
echo.
echo ERROR : UninstallSSLOption.cmd
echo          Ex. UninstallSSLOption.cmd
echo.
pause
GOTO FIN


:ERR_DIR_PARENT
echo.
echo ERROR : UninstallSSLOption.cmd must be execute from his current directory
echo          Ex. CD [directory where UNINSTALL.CMD is]
echo              UninstallSSLOption.cmd
echo.
pause
GOTO FIN


:ERR_DISQUE_SDBM
echo.
echo ERROR : Unable to find SDBM installation (?:\SDBM\_INSTALL\apache does not exists).
echo.
pause
GOTO FIN


:FIN
endlocal
