@echo off
setlocal

echo.
echo.
echo Modification of the SDBMAgt service configuration
echo --------------------------------------------------------------------------------
echo.
echo This is an optional step that allow the agent to connect to the local SDBM database
echo as sysdba to be able to perform job like database backup.
echo.
echo That step can be run later. However, if you choose not to continue, and choose to
echo configure SDBM database backup job (next step), job won't complete successfully until
echo you configure the SDBMAgt service properly.
echo.
echo If you continue, a new local user call SDBMAgt will be created. This new user will
echo be add to the local admninistrators group, the ORA_DBA group, and be granted
echo LogOnAsService right.
echo.
echo You can downgrade the privilege (administrators group) of this user as needed by your
echo environment but remember that it must be able to read the trace you want to monitor
echo and write to log directory.
echo.
echo Requirements: 
echo.
echo  - You must execute this script with administators privileges
echo.
:CONFIRMATION
set CHOIX=EMPTY
set /P CHOIX=Do you want to create the security context for SDBMAgt service (YES / NO)? 
if /i "%CHOIX%" == "NO"  goto :FIN
if /i "%CHOIX%" == "YES" goto :DEBUT
goto CONFIRMATION


:DEBUT

if not "%1" == ""                          goto ERR_SYNTAXE
if not exist "SDBMAgtSecurityContext.cmd". goto ERR_DIR_PARENT


echo.
echo SDBMAgt user creation...
set SDBMAgtPassword=Ag!%TIME: =%

net user SDBMAgt > nul 2>&1
if %ERRORLEVEL% EQU 0 echo User already exists (OK). && echo. && goto USAGER_EXISTE

net user SDBMAgt %SDBMAgtPassword% /add
if %ERRORLEVEL% NEQ 0 goto ERR_CREATION_USAGER

:USAGER_EXISTE
echo.


echo Updating password of user SDBMAgt...
net user SDBMAgt %SDBMAgtPassword%
if %ERRORLEVEL% NEQ 0 goto ERR_MODIF_PASSWORD

echo.


echo Adding user SDBMAgt to administrators group...

net localgroup Administrators > nul 2>&1
if %ERRORLEVEL% NEQ 0 goto ADM_FR

net localgroup Administrators | find "SDBMAgt" > nul 2>&1
if %ERRORLEVEL% EQU 0 echo User is already a member of Administrators group. && echo. && goto ORA_DBA

net localgroup Administrators SDBMAgt /add
if %ERRORLEVEL% NEQ 0 goto ERR_AJOUT_ADM

goto ORA_DBA


:ADM_FR

net localgroup Administrateurs > nul 2>&1
if %ERRORLEVEL% NEQ 0 goto ERR_INTROUVABLE_ADM

net localgroup Administrateurs | find "SDBMAgt" > nul 2>&1
if %ERRORLEVEL% EQU 0 echo User is already a member of Administrateurs group. && echo. && goto ORA_DBA

net localgroup Administrateurs SDBMAgt /add
if %ERRORLEVEL% NEQ 0 goto ERR_AJOUT_ADM


:ORA_DBA

echo.


echo Adding user SDBMAgt to ORA_DBA group...

net localgroup ORA_DBA > nul 2>&1
if %ERRORLEVEL% NEQ 0 goto ERR_INTROUVABLE_ORA

net localgroup ORA_DBA | find "SDBMAgt" > nul 2>&1
if %ERRORLEVEL% EQU 0 echo User is already a member of ORA_DBA group. && echo. && goto DROIT_SERVICE

net localgroup ORA_DBA SDBMAgt /add
if %ERRORLEVEL% NEQ 0 goto ERR_AJOUT_ORA


:DROIT_SERVICE
echo.

echo Adding ServiceLogonRight right to user SDBMAgt...
ntrights -u SDBMAgt +r SeServiceLogonRight
if %ERRORLEVEL% NEQ 0 goto ERR_AJOUT_PRIV

echo.
echo.


echo Update SDBMAgt service configuration...
sc config SDBMAgt obj= %COMPUTERNAME%\SDBMAgt password= %SDBMAgtPassword%
net stop SDBMAgt
net start SDBMAgt
if %ERRORLEVEL% NEQ 0 goto ERR_MODIF_SERVICE



echo.
echo.
echo End of SDBMAgt user creation (and service modification).
echo.
echo.

GOTO FIN



:ERR_SYNTAXE
echo.
echo ERROR : SDBMAgtSecurityContext.cmd [drive letter for installation]
echo          Ex. SDBMAgtSecurityContext.cmd
echo.
pause
GOTO FIN


:ERR_DIR_PARENT
echo.
echo ERROR : SDBMAgtSecurityContext.cmd must be execute from his current directory
echo          Ex. CD [directory where SDBMAgtSecurityContext.cmd is]
echo              SDBMAgtSecurityContext.cmd
echo.
pause
GOTO FIN


:ERR_CREATION_USAGER
echo.
echo ERROR : Unable to create the SDBMAgt user.
echo.
pause
GOTO FIN


:ERR_MODIF_PASSWORD
echo.
echo ERROR : Unable to change password for SDBMAgt user.
echo.
pause
GOTO FIN


:ERR_INTROUVABLE_ADM
echo.
echo ERROR : Unable to find Administrators group (or Administrateurs).
echo.
pause
GOTO FIN


:ERR_AJOUT_ADM
echo.
echo ERROR : Unable to add SDBMAgt to administrators group.
echo.
pause
GOTO FIN


:ERR_INTROUVABLE_ORA
echo.
echo ERROR : Unable to find ORA_DBA group
echo.
pause
GOTO FIN


:ERR_AJOUT_ORA
echo.
echo ERROR : Unable to add SDBMAgt to ORA_DBA group.
echo.
pause
GOTO FIN


:ERR_AJOUT_PRIV
echo.
echo ERROR : Unable to add ServiceLogonRight right to user SDBMAgt.
echo.
pause
GOTO FIN


:ERR_MODIF_SERVICE
echo.
echo ERROR : Unable to modify the SDBMAgt service configuration.
echo.
pause
GOTO FIN


:FIN
endlocal
