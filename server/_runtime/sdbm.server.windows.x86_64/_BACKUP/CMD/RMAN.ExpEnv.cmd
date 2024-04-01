rem ###############################################################################
rem # Utilities
rem ###############################################################################
call LibUtilsCMD.Journaliser.def.cmd


rem ###############################################################################
rem # Oracle environment variables
rem ###############################################################################
set TEMP={SDBM install disk}:\SDBM\_BACKUP\TMP
set ORACLE_HOME={SDBM install disk}:\SDBM\oraclexe\dbhomeXE
set PATH=%ORACLE_HOME%\BIN;%PATH%
set ORACLE_SID=XE
set NLS_DATE_FORMAT=YYYY/MM/DD:HH24:MI:SS
set NLS_LANG=AMERICAN_AMERICA.AL32UTF8


rem ###############################################################################
rem # RMAN specific variables
rem ###############################################################################

rem RMAN backup format
set RMAN_FORMAT={SDBM install disk}:\SDBM\_BACKUP\_DATA\XE.%COMPUTERNAME%

rem RMAN readrate
set RMAN_READRATE_M=5

rem Number of backup to keep (in days - 0 = last copy)
set CLBKP_NB_JOURS=0
