#!/bin/bash
#
# Script:
#
#    rman-bkarc-sdbm.sh
#
# Description:
#
#    SDBM database backup (archivelog backup, nocatalog)
#
# Arguments:
#
#    None
#


# Initial path
export INIT_REPERTOIRE=/opt/sdbm;


# Syntax validation
if [ "${1}" != "" ] ; then
   echo " ";
   echo "Syntax : rman-bkarc-sdbm.sh";
   echo " ";
   exit 8
fi


# RMAN environment variables
. ${INIT_REPERTOIRE}/RMAN.ExpEnv.sh


journaliser " "                                                                $LU_TYPE_MSG_INF;
journaliser "RMAN backup of archivelog - NOCATALOG | COMPRESS"                 $LU_TYPE_MSG_INF;
journaliser "------------------------------------------------"                 $LU_TYPE_MSG_INF;
journaliser "Target instance : $ORACLE_SID"                                    $LU_TYPE_MSG_INF;
journaliser " "                                                                $LU_TYPE_MSG_INF;
echo ""
echo ""


journaliser "Checking for ongoing RMAN full database backup..."                $LU_TYPE_MSG_INF;
if [ `ps -ef | grep rman-bkdbs-sdbm.sh | grep -v grep | wc -l` = 0 ] ; then
   journaliser "OK."                                                           $LU_TYPE_MSG_INF;
else
   journaliser "RMAN full database backup is running."                         $LU_TYPE_MSG_INF;
   journaliser " "                                                             $LU_TYPE_MSG_INF;
   journaliser "Script completed succesfully $0 ($0 $*)"                       $LU_TYPE_MSG_INF;

   # Fin normale
   exit 0
fi


journaliser " "                                                                $LU_TYPE_MSG_INF;
journaliser "Execution of RMAN"                                                $LU_TYPE_MSG_INF;
journaliser " "                                                                $LU_TYPE_MSG_INF;

rman << EOF
connect target;

run
{
   allocate channel T1 type disk;

   # Archivelog backup
   sql 'alter system archive log current';
   backup as compressed backupset archivelog all
      format '$RMAN_FORMAT.%U'
      delete input;

   release channel T1;
}

# Controlfile backup
sql "alter database backup controlfile to ''/tmp/control.ctf'' REUSE";
host "cp -f /tmp/control.ctf ${RMAN_FORMAT}.control.ctf";

exit
EOF

# RMAN RC
RMAN_CODE_RETOUR=$?;
journaliser " "                                                                $LU_TYPE_MSG_INF;

# Checking RMAN RC
if [ "$RMAN_CODE_RETOUR" != "0" ] ; then

   journaliser "Script completed with errors (CR=$RMAN_CODE_RETOUR) ($0 $*)"   $LU_TYPE_MSG_ERR;

   # End with error
   exit 8
fi


# End of script
