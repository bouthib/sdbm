#!/bin/sh
#
# 
# Script :
#    SDBMSrv.sh
#
# Description :
#    HangCheck routine for SDBMSrv.
#


HC_DELAY_BETWEEN_CHK=60
HC_DELAY_BEFORE_KILL=30



statusSDBMSrv()
{
   if [ `ps -ef | grep "SDBMSrv $SDBM_SCH" | grep -v "grep SDBMSrv $SDBM_SCH" | wc -l` -gt 0 ] ; then
      echo "`date` : SDBMSrv is running."
   else
      echo "`date` : SDBMSrv is stopped."
   fi
}


startSDBMSrv()
{
   if [ `ps -ef | grep "SDBMSrv $SDBM_SCH" | grep -v "grep SDBMSrv $SDBM_SCH" | wc -l` -gt 0 ] ; then
      echo "`date` : SDBMSrv is already running."
   else
      cd $SDBM_DIR/sdbmsrv;
      nohup $JAVA_DIR/bin/java -server -classpath ".:./SDBMSrv.jar:./../jdbc/{{ jdbc_ora_file }}:./../jdbc/{{ jdbc_mss_file }}:./../jdbc/{{ jdbc_mys_file }}:" SDBMSrv $SDBM_SCH & > /dev/null 2>&1
      sleep 1
      statusSDBMSrv      
  fi
}


stopSDBMSrv()
{
   if [ `ps -ef | grep "SDBMSrv $SDBM_SCH" | grep -v "grep SDBMSrv $SDBM_SCH" | wc -l` -lt 1 ] ; then
      echo "`date` : SDBMSrv is not running."
   else
      pidSDBMSrv=$(ps -ef | grep "SDBMSrv $SDBM_SCH" | grep -v "grep SDBMSrv $SDBM_SCH" | awk '{print $2}')
      kill $pidSDBMSrv
      echo "`date` : PID $pidSDBMSrv has been signal to stop."
      sleep 3
      statusSDBMSrv      
   fi
}



trapSDBMSrvStop()
{
   stopSDBMSrv
   echo "`date`: SDBMSrv.sh stopped."
   exit 0
}
trap 'trapSDBMSrvStop' SIGTERM



# Start monitoring until stop request is received (see trap)...
echo "`date` : SDBMSrv.sh started."

# Start SDBMSrv
startSDBMSrv

HC_NEXT_CHECK=`date +"%s"`
HC_NEXT_CHECK=`expr $HC_NEXT_CHECK + $HC_DELAY_BETWEEN_CHK`;

while [ 1 == 1 ] ; do

   HC_CUR_TIME=`date +"%s"`;

   # Check if next check has to be performed
   if [ $HC_CUR_TIME -gt $HC_NEXT_CHECK ] ; then

      HC_NEXT_CHECK=`expr $HC_CUR_TIME + $HC_DELAY_BETWEEN_CHK`;

      if [ -s ./log/SDBMSrv.HangCheckInfo ] ; then

         # Multiple read to garantee consistency
         HC_FILE_DATA1=A;
         HC_FILE_DATA2=B;

         while [ $HC_FILE_DATA1 != $HC_FILE_DATA2 ] ; do
            HC_FILE_DATA1=`cat ./log/SDBMSrv.HangCheckInfo`;  
            HC_FILE_DATA2=`cat ./log/SDBMSrv.HangCheckInfo`;

            if [ $HC_FILE_DATA1 != $HC_FILE_DATA2 ] ; then
               sleep 1
            fi
         done           

         HC_REF_TIME=`echo $HC_FILE_DATA1 | cut -f1 -d':'`;  
         HC_REF_DATA=`echo $HC_FILE_DATA1 | cut -f2 -d':'`;
         HC_REF_TIME=`expr $HC_REF_TIME + $HC_DELAY_BEFORE_KILL`;  
      
         if [ $HC_REF_DATA != "--" ] && [ $HC_CUR_TIME -gt $HC_REF_TIME ] ; then
            echo "`date` : SDBMSrv appear to be hang:";
            echo "`date` : Current time          : $HC_CUR_TIME";
            echo "`date` : Delay before kill     : $HC_DELAY_BEFORE_KILL";
            echo "`date` : Reference time        : $HC_REF_TIME";

            echo "`date` : SDBMSrv.HangCheckInfo : `cat ./log/SDBMSrv.HangCheckInfo`";
            stopSDBMSrv
            startSDBMSrv
         else
            echo "`date` : OK";
         fi
      fi   
   fi

   sleep 1
done

# End of script
