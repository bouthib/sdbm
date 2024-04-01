-- *
-- * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
-- * Licensed under the MIT license.
-- * See LICENSE file in the project root for full license information.
-- *

ALTER SESSION SET NLS_LANGUAGE='AMERICAN';

BEGIN DBMS_JOB.ISUBMIT(100,WHAT => 'SYS.DBMS_STATS.GATHER_SCHEMA_STATS(OWNNAME => ''SDBM'',OPTIONS => ''GATHER AUTO'');', NEXT_DATE => SYSDATE, INTERVAL => '/* LUNDI (3:00 AM) */ TRUNC(NEXT_DAY(SYSDATE,''MONDAY'')) + 3/24'); END;
/
BEGIN DBMS_JOB.ISUBMIT(102,'SDBM.SDBM_UTIL.MAINTENANCE;',SYSDATE,'TRUNC(SYSDATE) + 1 + 30/1440'); END;
/
