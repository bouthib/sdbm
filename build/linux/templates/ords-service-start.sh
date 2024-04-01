#!/bin/bash

touch /var/log/ords.log
chown oracle /var/log/ords.log

sudo su -l oracle -c 'nohup /opt/oracle/product/ords.script/ords-start.sh >> /var/log/ords.log 2>&1 </dev/null &'
