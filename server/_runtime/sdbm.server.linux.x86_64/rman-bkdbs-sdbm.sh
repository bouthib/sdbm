#!/bin/bash
#
# Script:
#
#    rman-bkdbs-sdbm.sh
#
# Description:
#
#    SDBM database backup (full database backup, nocatalog)
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
   echo "Syntax : rman-bkdbs-sdbm.sh";
   echo " ";
   exit 8
fi


# RMAN environment variables
. ${INIT_REPERTOIRE}/RMAN.ExpEnv.sh


journaliser " "                                                                $LU_TYPE_MSG_INF;
journaliser "RMAN backup of database - NOCATALOG | COMPRESS"                   $LU_TYPE_MSG_INF;
journaliser "----------------------------------------------"                   $LU_TYPE_MSG_INF;
journaliser "Target instance : $ORACLE_SID"                                    $LU_TYPE_MSG_INF;
journaliser " "                                                                $LU_TYPE_MSG_INF;
echo ""
echo ""


journaliser " "                                                                $LU_TYPE_MSG_INF;
journaliser "Execution of RMAN"                                                $LU_TYPE_MSG_INF;
journaliser " "                                                                $LU_TYPE_MSG_INF;

rman << EOF
connect target;

run
{
   allocate channel T1 type disk;
   set limit channel T1 readrate $RMAN_READRATE_M;

   # Database backup
   sql 'alter system checkpoint';
   backup as compressed backupset full check logical database
      include current controlfile
      format '$RMAN_FORMAT.%U';

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


# Maintenance RMAN
run
{
   allocate channel T1 device type disk;

   delete force noprompt obsolete
      until time 'SYSDATE - $CLBKP_NB_JOURS';

   release channel T1;
}

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
