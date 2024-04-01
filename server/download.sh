#!/bin/bash
#
# Script:
#    download.sh
#
# Description:
#    Get the required files to be able to deploy SDBM.
#

# hyperic-sigar-1.6.4-src.zip  2010-12-20  1.8 MB
# SHA1 : a03d2d99262887c20b7139d7878bddd18b805a0b
# MD5  : 752a786c8da562765ccaafc0663234f1
curl -L https://sourceforge.net/projects/sigar/files/sigar/1.6/hyperic-sigar-1.6.4-src.zip/download --output download/hyperic-sigar/hyperic-sigar-1.6.4-src.zip

# hyperic-sigar-1.6.4.zip      2010-12-20  3.5 MB
# SHA1 : 8f79d4039ca3ec6c88039d5897a80a268213e6b7
# MD5  : b0d39f0ea30051755bd4bfc1370de3ae
curl -L https://sourceforge.net/projects/sigar/files/sigar/1.6/hyperic-sigar-1.6.4.zip/download     --output download/hyperic-sigar/hyperic-sigar-1.6.4.zip

curl -L https://download.oracle.com/otn-pub/otn_software/jdbc/1922/ojdbc8.jar                       --output download/jdbc/ojdbc8.jar
curl -L https://go.microsoft.com/fwlink/?linkid=2259203\&clcid=0x409                                --output download/jdbc/sqljdbc_12.6.0.0_enu.zip
curl -L https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-j-8.3.0.zip                 --output download/jdbc/mysql-connector-j-8.3.0.zip
