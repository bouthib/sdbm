-- *
-- * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
-- * Licensed under the MIT license.
-- * See LICENSE file in the project root for full license information.
-- *


---------------------------------------------
---------------------------------------------
---------------------------------------------
--       U P G R A D E   A P E X           --
---------------------------------------------
---------------------------------------------


sqlplus "/ as sysdba"
alter session set container = XEPDB1;
alter user APEX_210200 account unlock;
exit

export NLS_LANG=AMERICAN_AMERICA.AL32UTF8
export TWO_TASK=localhost:1521/xepdb1
sqlplus APEX_210200/admin
@sdbm_apex_f101.release.0.NN.sql
@sdbm_apex_f111.release.0.NN.sql
exit

export TWO_TASK=
sqlplus "/ as sysdba"
alter session set container = XEPDB1;
alter user APEX_210200 account lock;
exit
