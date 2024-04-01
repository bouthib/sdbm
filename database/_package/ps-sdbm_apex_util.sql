-- *
-- * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
-- * Licensed under the MIT license.
-- * See LICENSE file in the project root for full license information.
-- *


CREATE OR REPLACE PACKAGE SDBM.SDBM_APEX_UTIL
IS
/*********************************************************************
*
* Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
* Licensed under the MIT license.
*
**********************************************************************/
/*********************************************************************
  PACKAGE : SDBM_APEX_UTIL
  AUTEUR  : Benoit Bouthillier 2009-10-03 (2012-05-18)
 ---------------------------------------------------------------------
  BUT : Ce package permet l'implantation des procédures utilitaire
        APEX pour SDBM.

**********************************************************************/


   FUNCTION INFOENV
   RETURN VARCHAR2;
   PRAGMA RESTRICT_REFERENCES(INFOENV,WNDS,WNPS,TRUST); 

   FUNCTION INFOSCHEMA
   RETURN VARCHAR2;
   PRAGMA RESTRICT_REFERENCES(INFOSCHEMA,WNDS,WNPS,TRUST); 

   FUNCTION ENCRYPTER_MDP_USAGER
   (
      A_NOM_USAGER IN USAGER.NOM_USAGER%TYPE
     ,A_MOT_PASSE  IN USAGER.MOT_PASSE%TYPE
   )
   RETURN VARCHAR2;
   PRAGMA RESTRICT_REFERENCES(ENCRYPTER_MDP_USAGER,WNDS,WNPS,TRUST); 

   PROCEDURE VIDER_JOURNAL;

   PROCEDURE TELECHARGER_JOURNAL_TACHE
   (
      A_ID_SOUMISSION HIST_TACHE_AGT.ID_SOUMISSION%TYPE
   );

   PROCEDURE INSERER_EVENEMENT_DEFAUT
   (
      A_TYPE_CIBLE      CIBLE.TYPE_CIBLE%TYPE
     ,A_SOUS_TYPE_CIBLE CIBLE.SOUS_TYPE_CIBLE%TYPE
     ,A_NOM_CIBLE       CIBLE.NOM_CIBLE%TYPE
     ,A_TYPE_BD         CIBLE.TYPE_BD%TYPE
   );

   PROCEDURE AJUSTER_EVENEMENT_REF_TYPE
   (
      A_NOM_CIBLE CIBLE.NOM_CIBLE%TYPE
   );

   PROCEDURE TRADUIRE_EVENEMENT;


END SDBM_APEX_UTIL;
/
