#!/bin/bash
#
# Script:
#    getSQLResult.sh
#
# Description:
#    Run SQL within a container (use with ansible)
#

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
source /home/oracle/.bash_profile >/dev/null

sqlplus -s / as sysdba<<EOF > /dev/null
set echo      off
set feedback  off
set heading   off
set trimspool on

alter session set container = xepdb1;

spool /tmp/.getSQLResult.$$.log
${1}
exit
EOF

sed '/^$/d' /tmp/.getSQLResult.$$.log
rm -f /tmp/.getSQLResult.$$.log

# End of script
