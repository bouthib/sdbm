-- *
-- * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
-- * Licensed under the MIT license.
-- * See LICENSE file in the project root for full license information.
-- *


CREATE OR REPLACE FUNCTION SDBM_APEX_AUTHENTIFICATION
(
   P_USERNAME VARCHAR2
  ,P_PASSWORD VARCHAR2
)
RETURN BOOLEAN
IS

/******************************************************************
*
* Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
* Licensed under the MIT license.
*
*******************************************************************/
/******************************************************************
  FUNCTION : SDBM_APEX_AUTHENTIFICATION
  AUTEUR   : Benoit Bouthillier 2022-01-16
 ------------------------------------------------------------------
  BUT : Cette fonction à pour but de faire l'authentification d'un
        usager SDBM.

  MODIFICATION :

  PARAMETRES:  Nom de l'usager           (A_NOM_USAGER)
               Mot de passe de l'usager  (A_MOT_PASSE)
******************************************************************/

   V_AUTH_VALIDE BOOLEAN := FALSE;

   V_USAGER_EXT  USAGER.USAGER_EXT%TYPE;
   V_LANGUE      PARAMETRE.LANGUE%TYPE;

BEGIN

   IF (P_PASSWORD IS NOT NULL) THEN

      -- Vérification si l'authentification externe doit être utilisée
      BEGIN
      
         SELECT NVL(USAGER_EXT,UPPER(P_USERNAME))
	   INTO V_USAGER_EXT
           FROM USAGER
       	  WHERE NOM_USAGER  = UPPER(P_USERNAME)
	    AND AUTH_EXT   != 'VR';
      
         -- Authentification régulière 
         UPDATE USAGER
            SET DH_DERN_CONNEXION = SYSDATE
          WHERE NOM_USAGER = UPPER(P_USERNAME)
            AND MOT_PASSE  = SDBM_APEX_UTIL.ENCRYPTER_MDP_USAGER(UPPER(P_USERNAME),P_PASSWORD);

         IF (SQL%ROWCOUNT = 1) THEN
            V_AUTH_VALIDE := TRUE;
         END IF;

      EXCEPTION

         WHEN NO_DATA_FOUND THEN

            -- Authentification externe
            V_AUTH_VALIDE := SDBM_APEX_AUTHENTIFICATION_EXT(A_USAGER_EXT => V_USAGER_EXT
	                                                   ,A_MOT_PASSE  => P_PASSWORD
						           );

            IF (V_AUTH_VALIDE) THEN

               UPDATE USAGER
                  SET DH_DERN_CONNEXION = SYSDATE
                WHERE NOM_USAGER = UPPER(P_USERNAME);

            END IF;
      END;

   END IF;

   IF (V_AUTH_VALIDE) THEN
      APEX_UTIL.SET_SESSION_STATE('P101_ERROR','');
      COMMIT;
      RETURN(TRUE);

   ELSE

      SELECT LANGUE
        INTO V_LANGUE
        FROM PARAMETRE;

      IF (V_LANGUE = 'FR') THEN
         APEX_UTIL.SET_SESSION_STATE('P101_ERROR','Usager ou mot de passe invalide');
      ELSE
         APEX_UTIL.SET_SESSION_STATE('P101_ERROR','Invalid username or password');
      END IF;
      
      RETURN(FALSE);

   END IF;

END SDBM_APEX_AUTHENTIFICATION;
/
