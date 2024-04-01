@echo off
setlocal enabledelayedexpansion

echo.
echo.
echo Uninstall of Simple Database Monitoring 0.32 - Beta
echo --------------------------------------------------------------------------------
echo.
echo As part of this action, the following products
echo will be removed:
echo.
echo  - Oracle Database Express Edition 21.3 (XE)
echo  - SDBMAgt (windows service)
echo  - SDBMDac (windows service)
echo  - SDBMSrv (windows service)
echo.
echo.
echo Requirements: 
echo.
echo  - You must execute this script with administators privileges
echo  - Apache Web server must NOT be installed on the system
echo    (if the SSL option was enabled)
echo.
echo Warning: 
echo.
echo  The uninstallation of Oracle XE could result in a reboot. Please execute
echo  this script again if a reboot occurs.
echo.
:CONFIRMATION
set CHOIX=EMPTY
set /P CHOIX=Do you want to uninstall Simple Database Monitoring (YES / NO)? 
if /i "%CHOIX%" == "NO"  goto :FIN
if /i "%CHOIX%" == "YES" goto :DEBUT
goto CONFIRMATION


:DEBUT

if not "%1" == ""                  goto ERR_SYNTAXE
if not exist "Uninstall.cmd".      goto ERR_DIR_PARENT


rem
rem Recherche de l'installation SDBM
rem
set SDBM_INSTALL_DIS=EMPTY
for %%I in (A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z) do @if exist %%I:\SDBM\_INSTALL. set SDBM_INSTALL_DIS=%%I && goto FIN_RECHERCHE
if "%SDBM_INSTALL_DIS%" == "EMPTY" goto :ERR_DISQUE_SDBM
:FIN_RECHERCHE
set SDBM_INSTALL_DIS=%SDBM_INSTALL_DIS:~0,1%



if exist "%SDBM_INSTALL_DIS%:\SDBM\apache". goto ERR_APACHE_EXISTE


set SDBM_INSTALL_REP_SRC=%CD%
set SDBM_INSTALL_REP_LOG=%SDBM_INSTALL_DIS%:\SDBM\_INSTALL


echo.
echo Uninstall of SDBM services...
echo.
echo *** CTRL-C to cancel ***
pause

echo.
net stop SDBMAgt
net stop SDBMDac
net stop SDBMSrv
echo.

for /F "tokens=3" %%I in ('reg QUERY HKLM\SYSTEM\CurrentControlSet\Services\SDBMAgt /v ImagePath') do @if not "%%I" == "VERSION" %%I -UNINSTALL
for /F "tokens=3" %%I in ('reg QUERY HKLM\SYSTEM\CurrentControlSet\Services\SDBMDac /v ImagePath') do @if not "%%I" == "VERSION" %%I -UNINSTALL
for /F "tokens=3" %%I in ('reg QUERY HKLM\SYSTEM\CurrentControlSet\Services\SDBMSrv /v ImagePath') do @if not "%%I" == "VERSION" %%I -UNINSTALL

net user SDBMAgt > nul 2>&1
if %ERRORLEVEL% NEQ 0 goto USAGER_INEXISTANT

:CONFIRMATION_USER
set /P CHOIX=Do you want to remove SDBMAgt user (YES / NO)? 
if /i "%CHOIX%" == "NO"  goto USAGER_INEXISTANT
if /i "%CHOIX%" == "YES" goto RETRAIT_USAGER
goto CONFIRMATION_USER

:RETRAIT_USAGER
net user SDBMAgt /del

:USAGER_INEXISTANT


echo.
echo End of uninstall of SDBM services.
echo.
echo.


echo.
echo Uninstall of SDBMORDS service...
echo.
echo *** CTRL-C to cancel ***
pause

echo.
net stop SDBMORDS
echo.

%SDBM_INSTALL_DIS%:\SDBM\nssm remove SDBMORDS confirm

echo.
echo End of uninstall of SDBMORDS service.
echo.
echo.


echo.
echo Uninstall of Oracle XE...
echo.
echo *** CTRL-C to cancel ***
pause

REG QUERY "HKLM\SOFTWARE\Oracle\KEY_OraDB21Home1" /V ORACLE_BUNDLE_NAME | find "Express" > NUL 2>&1
if %ERRORLEVEL% EQU 1 goto ERR_XE_EXISTE

echo.
echo Uninstalling Oracle XE...
msiexec /promptrestart /qn /x {C220B7FD-3095-47FC-A0C0-AE49DE6E320A}

echo.
echo End of uninstall of Oracle XE.
echo.
echo.


echo.
echo Removal of SDBM directory...
echo.
echo *** CTRL-C to cancel ***
pause

rmdir /S /Q %SDBM_INSTALL_DIS%:\SDBM

echo.
echo End of removal of SDBM directory.
echo.
echo.

pause
GOTO FIN



:ERR_SYNTAXE
echo.
echo ERROR : UNINSTALL.CMD
echo          Ex. UNINSTALL.CMD
echo.
pause
GOTO FIN


:ERR_DIR_PARENT
echo.
echo ERROR : UNINSTALL.CMD must be execute from his current directory
echo          Ex. CD [directory where UNINSTALL.CMD is]
echo              UNINSTALL.CMD
echo.
pause
GOTO FIN


:ERR_DISQUE_SDBM
echo.
echo ERROR : Unable to find SDBM installation (?:\SDBM\_INSTALL does not exists).
echo.
pause
GOTO FIN


:ERR_APACHE_EXISTE
echo.
echo ERROR : Apache seem to still be installed (UninstallHTTPSOption.cmd must be execute before proceding).
echo.
pause
GOTO FIN


:ERR_XE_EXISTE
echo.
echo ERROR : Oracle Express is not installed on this system.
echo.
pause
GOTO FIN


:FIN
endlocal
