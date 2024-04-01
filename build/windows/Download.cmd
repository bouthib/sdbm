@echo off

rem unzip : https://zenlayer.dl.sourceforge.net/project/gnuwin32/unzip/5.51-1/unzip-5.51-1-bin.zip

set FART_FILE=fart199b_win32.zip
set FART_URL="https://sourceforge.net/projects/fart-it/files/latest/download"

set NSSM_DIR=nssm-2.24
set NSSM_FILE=%NSSM_DIR%.zip
set NSSM_URL="https://nssm.cc/release/%NSSM_FILE%"

rem NTRIGHTS.EXE (ressource kit, windows 2000)
rem Not available anymore via download
rem Available in ./download

set ORACLE_XE_FILE=OracleXE213_Win64.zip
set ORACLE_XE_URL="https://download.oracle.com/otn-pub/otn_software/db-express/%ORACLE_XE_FILE%"

set ORACLE_APEX_FILE=apex_23.2.zip
set ORACLE_APEX_URL="https://download.oracle.com/otn_software/apex/%ORACLE_APEX_FILE%"

rem Attention au % -> %%
set ORDS_JAVA_FILE=OpenJDK17U-jre_x64_windows_hotspot_17.0.10_7.zip
set ORDS_JAVA_URL="https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.10%%2B7/%ORDS_JAVA_FILE%"

set ORACLE_ORDS_FILE=ords-23.4.0.346.1619.zip
set ORACLE_ORDS_URL="https://download.oracle.com/otn_software/java/ords/%ORACLE_ORDS_FILE%"

set SDBM_JAVA_FILE=OpenJDK8U-jre_x86-32_windows_hotspot_8u402b06.zip
set SDBM_JAVA_URL="https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u402-b06/%SDBM_JAVA_FILE%"

set APACHE_FILE=httpd-2.4.55-o111s-x64-vs17.zip
set APACHE_URL="https://www.apachehaus.com/downloads/%APACHE_FILE%"

echo.
echo.
echo Download of what is required to run SDBM Monitoring
echo --------------------------------------------------------------------------------
echo.
echo The following products will be downloaded:
echo.
echo  - Oracle Database Express Edition (XE)
echo  - Oracle APEX
echo  - Java (ORDS and SDBM)
echo  - Oracle ORDS
echo  - fart-it : https://github.com/lionello/fart-it
echo  - NSSM - the Non-Sucking Service Manager : https://nssm.cc/
echo  - Apache (optional installation via InstallHTTPSOption.cmd)
echo.
:CONFIRMATION
set CHOIX=EMPTY
set /P CHOIX=Do you want to download (YES / NO)? 
if /i "%CHOIX%" == "NO"  goto :FIN
if /i "%CHOIX%" == "YES" goto :DEBUT
goto CONFIRMATION


:DEBUT

if not "%2" == ""                              goto ERR_SYNTAXE
if not exist "Download.cmd".                   goto ERR_DIR_PARENT

if not "%1" == ""                              goto FIN_DEMANDE


set SDBM_INSTALL_REP_SRC=%CD%

echo.
if not exist download (mkdir download)

rem Unzip
rem curl -L -o download/unzip-5.51-1-bin.zip https://zenlayer.dl.sourceforge.net/project/gnuwin32/unzip/5.51-1/unzip-5.51-1-bin.zip
copy %SDBM_INSTALL_REP_SRC%\download\unzip.exe %SDBM_INSTALL_REP_SRC%

rem Fart
curl -L -o download/%FART_FILE% %FART_URL%
unzip -n -q -d %SDBM_INSTALL_REP_SRC% %SDBM_INSTALL_REP_SRC%\download\%FART_FILE%

rem NSSM
curl -L -o download/%NSSM_FILE% %NSSM_URL%
unzip -n -q -d %SDBM_INSTALL_REP_SRC%\download %SDBM_INSTALL_REP_SRC%\download\%NSSM_FILE%
copy %SDBM_INSTALL_REP_SRC%\download\%NSSM_DIR%\win64\nssm.exe %SDBM_INSTALL_REP_SRC%\download

rem NTRights
copy %SDBM_INSTALL_REP_SRC%\download\ntrights.exe %SDBM_INSTALL_REP_SRC%

rem Oracle XE
curl -L -o download/%ORACLE_XE_FILE% %ORACLE_XE_URL%

rem Oracle Apex
curl -L -o download/%ORACLE_APEX_FILE% %ORACLE_APEX_URL%

rem Java ORDS
curl -L -o download/%ORDS_JAVA_FILE% %ORDS_JAVA_URL%

rem Oracle ORDS
curl -L -o download/%ORACLE_ORDS_FILE% %ORACLE_ORDS_URL%

rem Apache
curl -L -o download/%APACHE_FILE% %APACHE_URL%

rem Java SDBM
curl -L -o download/%SDBM_JAVA_FILE% %SDBM_JAVA_URL%

GOTO FIN



:ERR_SYNTAXE
echo.
echo ERROR : DOWNLOAD.CMD
echo          Ex. DOWNLOAD.CMD
echo.
pause
GOTO FIN


:ERR_DIR_PARENT
echo.
echo ERROR : DOWNLOAD.CMD must be execute from his current directory
echo          Ex. CD [directory where DOWNLOAD.CMD is]
echo              DOWNLOAD.CMD
echo.
pause
GOTO FIN


:FIN
endlocal
