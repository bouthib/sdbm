-- *
-- * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
-- * Licensed under the MIT license.
-- * See LICENSE file in the project root for full license information.
-- *


CREATE OR REPLACE FUNCTION SDBM_APEX_AUTHENTIFICATION_EXT
(
   A_USAGER_EXT VARCHAR2
  ,A_MOT_PASSE  VARCHAR2
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
  FUNCTION : SDBM_APEX_AUTHENTIFICATION_EXT
  AUTEUR   : Benoit Bouthillier 2022-01-17
 ------------------------------------------------------------------
  BUT : Cette fonction à pour but de faire l'authentification d'un
        usager SDBM via un système externe.

  MODIFICATION :

  PARAMETRES:  Identifiant de l'usager   (A_USAGER_EXT)
               Mot de passe de l'usager  (A_MOT_PASSE)
******************************************************************/

BEGIN

   -- Par défaut, aucun usager externe n'est authentifié
   RETURN(FALSE);

END SDBM_APEX_AUTHENTIFICATION_EXT;
/
