@echo off
setlocal enabledelayedexpansion

echo.
echo.
echo Creation of the SDBM database backup jobs
echo --------------------------------------------------------------------------------
echo.
echo This is an optional step that allow to schedule SDBM database backup job and switch
echo database in archivelog mode (allowing online backup).
echo.
:CONFIRMATION
set CHOIX=EMPTY
set /P CHOIX=Do you want to create the SDBM database backup jobs (YES / NO)? 
if /i "%CHOIX%" == "NO"  goto :FIN
if /i "%CHOIX%" == "YES" goto :DEBUT
goto CONFIRMATION


:DEBUT

if not "%1" == ""                          goto ERR_SYNTAXE
if not exist "SDBMAgtCreateBackupJob.cmd". goto ERR_DIR_PARENT


rem
rem Recherche de l'installation SDBM
rem
set SDBM_INSTALL_DIS=EMPTY
for %%I in (A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z) do @if exist %%I:\SDBM\_INSTALL. set SDBM_INSTALL_DIS=%%I && goto FIN_RECHERCHE
if "%SDBM_INSTALL_DIS%" == "EMPTY" goto :ERR_DISQUE_SDBM
:FIN_RECHERCHE
set SDBM_INSTALL_DIS=%SDBM_INSTALL_DIS:~0,1%



echo.
echo Updating install location in RMAN.ExpEnv.cmd environment file...
fart %SDBM_INSTALL_DIS%:\SDBM\_BACKUP\CMD\RMAN.ExpEnv.cmd "{SDBM install disk}" %SDBM_INSTALL_DIS%
echo Done.


echo.
echo SDBM database backup jobs creation...

sqlplus /nolog @SDBMAgtCreateBackupJob.sql %SDBM_INSTALL_DIS%
if %ERRORLEVEL% NEQ 0 goto ERR_CREATION_TACHE



echo.
echo End of creation of the SDBM database backup jobs.
echo.
echo.

GOTO FIN



:ERR_SYNTAXE
echo.
echo ERROR : SDBMAgtCreateBackupJob.cmd
echo          Ex. SDBMAgtCreateBackupJob.cmd
echo.
pause
GOTO FIN


:ERR_DIR_PARENT
echo.
echo ERROR : SDBMAgtCreateBackupJob.cmd must be execute from his current directory
echo          Ex. CD [directory where SDBMAgtCreateBackupJob.cmd is]
echo              SDBMAgtCreateBackupJob.cmd
echo.
pause
GOTO FIN


:ERR_DISQUE
echo.
echo ERROR : Unable to find SDBM installation (?:\SDBM\_INSTALL does not exists).
echo.
pause
GOTO FIN


:ERR_CREATION_TACHE
echo.
echo ERROR : Error while creating SDBM database backup jobs.
echo.
pause
GOTO FIN


:FIN
endlocal
