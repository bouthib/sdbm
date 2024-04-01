#! /bin/bash
#
# Script:
#    /etc/init.d/update-ip.sh
#
# Description:
#    Rebuild the /etc/issue and the /etc/issue.net base on the current
#    network configuration.  This script should be call from the
#    /etc/init.d/network script at the end of the start section (case).
#
#    The script will also regenerate the nginx SSL certificate if the
#    ip address has been updated.
#

VERSION=`cat /etc/*elease | grep VERSION_ID | sed 's/VERSION_ID="//' | sed 's/"//'`

echo " "                                                       > /etc/issue
echo "SDBM Appliance"                                         >> /etc/issue
echo "Simple Database Monitoring"                             >> /etc/issue
echo "Version - {{ build_date }}"                             >> /etc/issue
echo " "                                                      >> /etc/issue
echo "Powered by:"                                            >> /etc/issue
echo " "                                                      >> /etc/issue
echo "   Oracle Linux ${VERSION} - Kernel \r on an \m (\l)"   >> /etc/issue
echo "   Oracle Express Edition {{ oraclexe_version }}"       >> /etc/issue
echo "   Oracle Application Express {{ oracleapex_version }}" >> /etc/issue
echo " "                                                      >> /etc/issue


# Fix for netcount = 0 or startup
sleep 3

touch /opt/sdbm-update-ip/sdbm-update-ip.last   
netcount=$(/sbin/ifconfig | grep -c "inet ")
if [[ $netcount > 1 ]] ; then
   NEW_IP=`/sbin/ifconfig | grep "inet " | grep -v "127.0.0.1" | awk '{ print $2 }' | awk -F: '{ print ""$1"" }'`

   echo " "                                                          >> /etc/issue
   echo "To use this appliance, please use a web browser"            >> /etc/issue
   echo "from another system to navigate to "                        >> /etc/issue
   echo " "                                                          >> /etc/issue
   echo "https://$NEW_IP"                                            >> /etc/issue
   echo " "                                                          >> /etc/issue

   if [ "`echo $NEW_IP`" != "`cat /opt/sdbm-update-ip/sdbm-update-ip.last`" ] ; then  

      # Generate new self issued certificate
      cp -a /etc/nginx/conf.d/sdbm.key /etc/nginx/conf.d/sdbm.key.`date +%Y%m%d%H%M%S`
      cp -a /etc/nginx/conf.d/sdbm.crt /etc/nginx/conf.d/sdbm.crt.`date +%Y%m%d%H%M%S`

      mkdir -p /etc/nginx/conf.d/ssl
      chmod 700 /etc/nginx/conf.d/ssl

      openssl req -new -x509 -days 9125 -newkey rsa:2048 -nodes -keyout /etc/nginx/conf.d/ssl/sdbm.key -out /etc/nginx/conf.d/ssl/sdbm.crt -subj '/O=Simple Database Monitoring - SDBM/OU=Simple Database Monitoring - SDBM/CN=sdbm'
      chmod 600 /etc/nginx/conf.d/ssl/sdbm.key
      
      systemctl restart nginx

   fi

   # Keep the last configured ip
   echo $NEW_IP > /opt/sdbm-update-ip/sdbm-update-ip.last

else
   echo " "                                                          >> /etc/issue
   echo "This appliance does not have networking configured."        >> /etc/issue
   echo "Please log in to configure networking."                     >> /etc/issue
   echo " "                                                          >> /etc/issue
fi

cp -a /etc/issue /etc/issue.net
