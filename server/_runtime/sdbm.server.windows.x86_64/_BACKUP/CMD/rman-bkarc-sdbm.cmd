@echo off
setlocal
title rman-bkarc-sdbm.cmd

rem
rem Script:
rem
rem    rman-bkarc-sdbm.cmd
rem
rem Description:
rem
rem    SDBM database backup (archivelog backup, nocatalog)
rem
rem Arguments :
rem
rem    None
rem




call RMAN.ExpEnv.cmd


call LibUtilsCMD.Journaliser.exe.cmd "RMAN backup of archivelog - NOCATALOG | COMPRESS"                           %LU_TYPE_MSG_INF%
call LibUtilsCMD.Journaliser.exe.cmd "------------------------------------------------"                           %LU_TYPE_MSG_INF%
call LibUtilsCMD.Journaliser.exe.cmd "Target instance : %ORACLE_SID%"                                             %LU_TYPE_MSG_INF%
echo.
echo.


call LibUtilsCMD.Journaliser.exe.cmd "Generating RMAN command"                                                    %LU_TYPE_MSG_INF%
@(
   echo connect target;
   echo.
   echo run
   echo {
   echo    allocate channel T1 type disk;
   echo.
   echo    # Archivelog backup
   echo    sql 'alter system archive log current';
   echo    backup as compressed backupset archivelog all
   echo       format '%RMAN_FORMAT%.%%U'
   echo       delete input;
   echo.
   echo    release channel T1;
   echo }
   echo.
   echo # Controlfile backup
   echo sql "alter database backup controlfile to ''%RMAN_FORMAT%.control.ctf'' REUSE";
   echo.
   echo exit
) > %TEMP%\rman-bkarc-sdbm.rcv
call LibUtilsCMD.Journaliser.exe.cmd "OK"                                                                         %LU_TYPE_MSG_INF%
echo.
echo.

call LibUtilsCMD.Journaliser.exe.cmd "Execution of RMAN"                                                          %LU_TYPE_MSG_INF%
rman @%TEMP%\rman-bkarc-sdbm.rcv
if not %ERRORLEVEL% == 0 goto RMAN_RC_ERR

echo.
call LibUtilsCMD.Journaliser.exe.cmd "RMAN return code was 0"                                                     %LU_TYPE_MSG_INF%
echo.


rem End of script
goto :END_SCRIPT



:RMAN_RC_ERR
echo.
call LibUtilsCMD.Journaliser.exe.cmd "RMAN return code was not zero"                                              %LU_TYPE_MSG_ERR%
echo.
exit 8
goto :END_SCRIPT


:END_SCRIPT
endlocal
