#!/bin/bash
#
# Script:
#    compile.sh
#

JDK_URL=https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u402-b06/OpenJDK8U-jdk_x64_linux_hotspot_8u402b06.tar.gz
JDK_FILE=OpenJDK8U-jdk_x64_linux_hotspot_8u402b06.tar.gz
JDK=java/jdk/jdk8u402-b06

if [ -d "$JDK" ]; then
   echo "$JDK already exists."
else
   echo "$JDK will be downloaded..."
   mkdir -p java/jdk
   cd java/jdk
   curl -L ${JDK_URL} --output ${JDK_FILE}
   tar xf ${JDK_FILE}
   rm -f ${JDK_FILE}
   cd ../..
   echo "Done."
fi

echo .
echo "Compiling sdbmagt..."
cd java/sdbmagt/classes
../../../$JDK/bin/javac -cp "../../../_runtime/sdbm.server.linux.x86_64/jdbc/*:../../../_runtime/sdbm.server.linux.x86_64/sdbmagt/sigar/sigar.jar" -d ./ -source 8 -target 8 ../src/IApp.java ../src/ShutdownInterceptor.java ../src/SDBMAgt.java
echo "Building SDBMAgt.jar..."
../../../$JDK/bin/jar cf ../SDBMAgt.jar *
cd ../../..
echo "Done."

echo .
echo "Compiling sdbmdac..."
cd java/sdbmdac/classes
../../../$JDK/bin/javac -cp "../../../_runtime/sdbm.server.linux.x86_64/jdbc/*" -d ./ -source 8 -target 8 ../src/IApp.java ../src/ShutdownInterceptor.java ../src/SDBMDaC.java
echo "Building SDBMDaC.jar..."
../../../$JDK/bin/jar cf ../SDBMDaC.jar *
cd ../../..
echo "Done."

echo .
echo "Compiling sdbmsrv..."
cd java/sdbmsrv/classes
../../../$JDK/bin/javac -cp "../../../_runtime/sdbm.server.linux.x86_64/jdbc/*" -d ./ -source 8 -target 8 ../src/IApp.java ../src/ShutdownInterceptor.java ../src/SDBMSrv.java
echo "Building SDBMSrv.jar..."
../../../$JDK/bin/jar cf ../SDBMSrv.jar *
cd ../../..
echo "Done."
echo .
echo .


echo "Copying jar into _runtime dirctory..."

echo .
echo "sdbm.server.linux.x86_64..."
cp -av java/sdbmagt/SDBMAgt.jar _runtime/sdbm.server.linux.x86_64/sdbmagt/SDBMAgt.jar
cp -av java/sdbmdac/SDBMDaC.jar _runtime/sdbm.server.linux.x86_64/sdbmdac/SDBMDaC.jar
cp -av java/sdbmsrv/SDBMSrv.jar _runtime/sdbm.server.linux.x86_64/sdbmsrv/SDBMSrv.jar

echo .
echo "sdbm.server.windows.x86_64..."
cp -av java/sdbmagt/SDBMAgt.jar _runtime/sdbm.server.windows.x86_64/sdbmagt/SDBMAgt.jar
cp -av java/sdbmdac/SDBMDaC.jar _runtime/sdbm.server.windows.x86_64/sdbmdac/SDBMDaC.jar
cp -av java/sdbmsrv/SDBMSrv.jar _runtime/sdbm.server.windows.x86_64/sdbmsrv/SDBMSrv.jar

echo .
echo "sdbm.unix..."
cp -av java/sdbmagt/SDBMAgt.jar _runtime/sdbm.unix/sdbmagt/SDBMAgt.jar

echo .
echo "sdbm.windows.x86..."
cp -av java/sdbmagt/SDBMAgt.jar _runtime/sdbm.windows.x86/sdbmagt/SDBMAgt.jar
echo .

echo "Done."

# End of script
