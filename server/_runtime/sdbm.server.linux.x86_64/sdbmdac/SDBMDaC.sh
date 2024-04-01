#!/bin/sh
#
# 
# Script :
#    SDBMDaC.sh
#
# Description :
#    HangCheck routine for SDBMDaC.
#


HC_DELAY_BETWEEN_CHK=60
HC_DELAY_BEFORE_KILL=30



statusSDBMDaC()
{
   if [ `ps -ef | grep "SDBMDaC $SDBM_SCH" | grep -v "grep SDBMDaC $SDBM_SCH" | wc -l` -gt 0 ] ; then
      echo "`date` : SDBMDaC is running."
   else
      echo "`date` : SDBMDaC is stopped."
   fi
}


startSDBMDaC()
{
   if [ `ps -ef | grep "SDBMDaC $SDBM_SCH" | grep -v "grep SDBMDaC $SDBM_SCH" | wc -l` -gt 0 ] ; then
      echo "`date` : SDBMDaC is already running."
   else
      cd $SDBM_DIR/sdbmdac;
      nohup $JAVA_DIR/bin/java -server -classpath ".:./SDBMDaC.jar:./../jdbc/{{ jdbc_ora_file }}:./../jdbc/{{ jdbc_mss_file }}:./../jdbc/{{ jdbc_mys_file }}:" SDBMDaC $SDBM_SCH & > /dev/null 2>&1
      sleep 1
      statusSDBMDaC      
  fi
}


stopSDBMDaC()
{
   if [ `ps -ef | grep "SDBMDaC $SDBM_SCH" | grep -v "grep SDBMDaC $SDBM_SCH" | wc -l` -lt 1 ] ; then
      echo "`date` : SDBMDaC is not running."
   else
      pidSDBMDaC=$(ps -ef | grep "SDBMDaC $SDBM_SCH" | grep -v "grep SDBMDaC $SDBM_SCH" | awk '{print $2}')
      kill $pidSDBMDaC
      echo "`date` : PID $pidSDBMDaC has been signal to stop."
      sleep 3
      statusSDBMDaC      
      if [ `ps -ef | grep "SDBMDaC $SDBM_SCH" | grep -v "grep SDBMDaC $SDBM_SCH" | wc -l` -gt 0 ] ; then
         echo "`date` : SDBMDaC has not been stopped... kill -9 $pidSDBMDaC"
         kill -9 $pidSDBMDaC
         statusSDBMDaC
      fi
   fi
}



trapSDBMDaCStop()
{
   stopSDBMDaC
   echo "`date`: SDBMDaC.sh stopped."
   exit 0
}
trap 'trapSDBMDaCStop' SIGTERM



# Start monitoring until stop request is received (see trap)...
echo "`date` : SDBMDaC.sh started."

# Start SDBMDaC
startSDBMDaC

HC_NEXT_CHECK=`date +"%s"`
HC_NEXT_CHECK=`expr $HC_NEXT_CHECK + $HC_DELAY_BETWEEN_CHK`;

while [ 1 == 1 ] ; do

   HC_CUR_TIME=`date +"%s"`;

   # Check if next check has to be performed
   if [ $HC_CUR_TIME -gt $HC_NEXT_CHECK ] ; then

      HC_NEXT_CHECK=`expr $HC_CUR_TIME + $HC_DELAY_BETWEEN_CHK`;

      if [ -e ./log/SDBMDaC.HangCheckInfo ] ; then

         # Multiple read to garantee consistency
         HC_FILE_DATA1=A;
         HC_FILE_DATA2=B;

         while [ $HC_FILE_DATA1 != $HC_FILE_DATA2 ] ; do
            HC_FILE_DATA1=`cat ./log/SDBMDaC.HangCheckInfo`;  
            HC_FILE_DATA2=`cat ./log/SDBMDaC.HangCheckInfo`;

            if [ $HC_FILE_DATA1 != $HC_FILE_DATA2 ] ; then
               sleep 1
            fi
         done           

         HC_REF_TIME=`echo $HC_FILE_DATA1 | cut -f1 -d':'`;  
         HC_REF_DATA=`echo $HC_FILE_DATA1 | cut -f2 -d':'`;
         HC_REF_TIME=`expr $HC_REF_TIME + $HC_DELAY_BEFORE_KILL`;  
      
         if [ $HC_REF_DATA != "--" ] && [ $HC_CUR_TIME -gt $HC_REF_TIME ] ; then
            echo "`date` : SDBMDaC appear to be hang:";
            echo "`date` : Current time          : $HC_CUR_TIME";
            echo "`date` : Delay before kill     : $HC_DELAY_BEFORE_KILL";
            echo "`date` : Reference time        : $HC_REF_TIME";

            echo "`date` : SDBMDaC.HangCheckInfo : `cat ./log/SDBMDaC.HangCheckInfo`";
            stopSDBMDaC
            startSDBMDaC
         else
            echo "`date` : OK";
         fi
      fi   
   fi

   sleep 1
done

# End of script
