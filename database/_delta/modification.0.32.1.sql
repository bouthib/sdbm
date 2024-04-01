-- *
-- * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
-- * Licensed under the MIT license.
-- * See LICENSE file in the project root for full license information.
-- *



---------------------------------------------
---------------------------------------------
---------------------------------------------
--      V E R S I O N   0 . 3 2 . 1        --
---------------------------------------------
---------------------------------------------


ALTER TABLE PARAMETRE
   ADD ( 
	  STARTTLS_SMTP                  CHAR(2 CHAR)        DEFAULT 'FA'     NOT NULL
         ,CHEMIN_WALLET_SMTP             VARCHAR2(512 CHAR)
         ,MDP_WALLET_SMTP                VARCHAR2(512 CHAR)
       )
CACHE;

@../_package/ps-sdbm_util.sql
@../_package/pb-sdbm_util.sql
@../_package/pb-sdbm_smtp.sql
@../_trigger/sdbm_trigger.sql

ALTER TABLE USAGER
   ADD (
	  AUTH_EXT          CHAR(2 CHAR)        DEFAULT 'FA'      NOT NULL
	 ,USAGER_EXT        VARCHAR2(100 CHAR)
       );

@../_function/sdbm_apex_authentification_ext.sql
@../_function/sdbm_apex_authentification.sql


ALTER TABLE INFO_AGT
   MODIFY NOM_OS VARCHAR2(100 CHAR);


-- Requis pour version 21c
GRANT CREATE JOB                 TO SDBM;
