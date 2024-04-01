#!/bin/bash

if [ "$USER" != "oracle" ]; then
   echo "Error : This script must be run as oracle user"

else

   if [ `ps -ef | grep -v grep | grep -c '/ords/ords.war --config /opt/oracle/product/ords.config serve'` == "0" ]; then

      export JAVA_HOME=/opt/java/jre;
      export PATH=$PATH:$JAVA_HOME/bin:/opt/oracle/product/ords/bin
      export _JAVA_OPTIONS="-Xms1126M -Xmx1126M"
      ords --config /opt/oracle/product/ords.config serve

   else
      echo "ords is already running"

   fi

fi
