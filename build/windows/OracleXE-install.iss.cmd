echo #Do not leave any parameter with empty value
echo #Install Directory location, username can be replaced with current user
echo INSTALLDIR=%SDBM_INSTALL_DIS%:\SDBM\oraclexe\
echo #Database password, All users are set with this password, Remove the value once installation is complete
echo PASSWORD=%oracle_password%
echo #If listener port is set to 0, available port will be allocated starting from 1521 automatically
echo LISTENER_PORT=%SDBM_TNS_PORT%
echo #If EM express port is set to 0, available port will be used starting from 5550 automatically
echo EMEXPRESS_PORT=0
echo #Specify char set of the database
echo CHAR_SET=AL32UTF8
echo #Specify the database comain for the db unique name specification
echo DB_DOMAIN=sdbm.ca