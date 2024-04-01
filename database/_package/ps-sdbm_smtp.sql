-- *
-- * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
-- * Licensed under the MIT license.
-- * See LICENSE file in the project root for full license information.
-- *


CREATE OR REPLACE PACKAGE SDBM_SMTP
IS
/*********************************************************************
*
* Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
* Licensed under the MIT license.
*
**********************************************************************/
/*********************************************************************
  PACKAGE   : SDBM_SMTP
  AUTEUR    : Benoit Bouthillier 2008-07-23
 ---------------------------------------------------------------------
  BUT : Ce package permet l'implantation de l'interface SMTP.

**********************************************************************/


   -- Version de l'entête PL/SQL
   VERSION_PS CONSTANT VARCHAR2(4 CHAR) := '0.02';


   PROCEDURE VERSION;

   PROCEDURE ENVOYER_SMTP(A_DESTINATAIRE IN VARCHAR2
                         ,A_SUJET        IN VARCHAR2
                         ,A_MESSAGE      IN VARCHAR2
                         ,A_NOM_FICHIER  IN VARCHAR2 DEFAULT NULL
                         ,A_BLB_FICHIER  IN BLOB     DEFAULT NULL
                         );


END SDBM_SMTP;
/
