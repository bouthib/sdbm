-- *
-- * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
-- * Licensed under the MIT license.
-- * See LICENSE file in the project root for full license information.
-- *


CREATE OR REPLACE FUNCTION SDBM_APEX_VERSION
RETURN VARCHAR2
IS

/******************************************************************
*
* Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
* Licensed under the MIT license.
*
*******************************************************************/
/******************************************************************
  FUNCTION : SDBM_APEX_VERSION
  AUTEUR   : Benoit Bouthillier 2009-02-10
 ------------------------------------------------------------------
  BUT : Cette fonction à pour but de faire l'affichage des PL/SQL
        dans l'application SDBM.

******************************************************************/

   V_STATUS INTEGER;
   V_LIGNE  VARCHAR2(256 CHAR);
   V_TAMPON VARCHAR2(4096 CHAR);

BEGIN

   DBMS_OUTPUT.ENABLE;


   -- SDBM_BASE
   SDBM_BASE.VERSION;

   V_STATUS := 0;
   WHILE (V_STATUS = 0) LOOP
   
      DBMS_OUTPUT.GET_LINE
      (
         LINE   => V_LIGNE
        ,STATUS => V_STATUS
      );
      
      IF (V_STATUS = 0) THEN
         IF (V_LIGNE = 'Version') THEN
            V_TAMPON := V_TAMPON || CHR(10) || CHR(10) || 'SDBM_BASE version is:';
         ELSE
            V_TAMPON := V_TAMPON || CHR(10) || V_LIGNE;
         END IF;
      END IF;

   END LOOP;


   -- SDBM_AGENT
   SDBM_AGENT.VERSION;
   
   V_STATUS := 0;
   WHILE (V_STATUS = 0) LOOP
   
      DBMS_OUTPUT.GET_LINE
      (
         LINE   => V_LIGNE
        ,STATUS => V_STATUS
      );
      
      IF (V_STATUS = 0) THEN
         IF (V_LIGNE = 'Version') THEN
            V_TAMPON := V_TAMPON || CHR(10) || CHR(10) || 'SDBM_AGENT version is:';
         ELSE
            V_TAMPON := V_TAMPON || CHR(10) || V_LIGNE;
         END IF;
      END IF;

   END LOOP;


   -- SDBM_COLLECTE
   SDBM_COLLECTE.VERSION;
   
   V_STATUS := 0;
   WHILE (V_STATUS = 0) LOOP
   
      DBMS_OUTPUT.GET_LINE
      (
         LINE   => V_LIGNE
        ,STATUS => V_STATUS
      );
      
      IF (V_STATUS = 0) THEN
         IF (V_LIGNE = 'Version') THEN
            V_TAMPON := V_TAMPON || CHR(10) || CHR(10) || 'SDBM_COLLECTE version is:';
         ELSE
            V_TAMPON := V_TAMPON || CHR(10) || V_LIGNE;
         END IF;
      END IF;

   END LOOP;


   RETURN(V_TAMPON);

END SDBM_APEX_VERSION;
/
