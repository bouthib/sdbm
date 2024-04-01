#!/bin/bash
#
# Script:
#    refresh.sh
#
# Description:
#    Get updated runtime componement into the runtine structure.
#

unzip -jo download/jdbc/sqljdbc_12.6.0.0_enu.zip         -d _runtime/sdbm.server.linux.x86_64/jdbc sqljdbc_12.6/enu/jars/mssql-jdbc-12.6.0.jre8.jar
unzip -jo download/jdbc/mysql-connector-j-8.3.0.zip      -d _runtime/sdbm.server.linux.x86_64/jdbc mysql-connector-j-8.3.0/mysql-connector-j-8.3.0.jar
cp -a download/jdbc/ojdbc8.jar                              _runtime/sdbm.server.linux.x86_64/jdbc
unzip -jo download/hyperic-sigar/hyperic-sigar-1.6.4.zip -d _runtime/sdbm.server.linux.x86_64/sdbmagt/sigar hyperic-sigar-1.6.4/sigar-bin/lib/libsigar-amd64-linux.so hyperic-sigar-1.6.4/sigar-bin/lib/sigar.jar

unzip -jo download/jdbc/sqljdbc_12.6.0.0_enu.zip         -d _runtime/sdbm.server.windows.x86_64/jdbc sqljdbc_12.6/enu/jars/mssql-jdbc-12.6.0.jre8.jar
unzip -jo download/jdbc/mysql-connector-j-8.3.0.zip      -d _runtime/sdbm.server.windows.x86_64/jdbc mysql-connector-j-8.3.0/mysql-connector-j-8.3.0.jar
cp -a download/jdbc/ojdbc8.jar                              _runtime/sdbm.server.windows.x86_64/jdbc
unzip -jo download/hyperic-sigar/hyperic-sigar-1.6.4.zip -d _runtime/sdbm.server.windows.x86_64/sdbmagt/sigar hyperic-sigar-1.6.4/sigar-bin/lib/sigar-x86-winnt.dll hyperic-sigar-1.6.4/sigar-bin/lib/sigar.jar

cp -a download/jdbc/ojdbc8.jar _runtime/sdbm.unix/jdbc
unzip -jo download/hyperic-sigar/hyperic-sigar-1.6.4.zip -d _runtime/sdbm.unix/sdbmagt/sigar hyperic-sigar-1.6.4/sigar-bin/lib/*.so hyperic-sigar-1.6.4/sigar-bin/lib/*.sl hyperic-sigar-1.6.4/sigar-bin/lib/*.dylib hyperic-sigar-1.6.4/sigar-bin/lib/sigar.jar

cp -a download/jdbc/ojdbc8.jar                              _runtime/sdbm.windows.x86/jdbc
unzip -jo download/hyperic-sigar/hyperic-sigar-1.6.4.zip -d _runtime/sdbm.windows.x86/sdbmagt/sigar hyperic-sigar-1.6.4/sigar-bin/lib/sigar-x86-winnt.dll hyperic-sigar-1.6.4/sigar-bin/lib/sigar.jar
