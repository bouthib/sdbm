#!/bin/bash

if [ `ps -ef | grep -v grep | grep -c '/ords/ords.war --config /opt/oracle/product/ords.config serve'` != "0" ]; then
   PID=`ps -ef | grep -v grep | grep '/ords/ords.war --config /opt/oracle/product/ords.config serve' | awk '{print $2}'`
   kill $PID

else
   echo "ords is not running"

fi
