-- *
-- * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
-- * Licensed under the MIT license.
-- * See LICENSE file in the project root for full license information.
-- *


CREATE OR REPLACE PACKAGE SDBM_COLLECTE
IS
/*********************************************************************
*
* Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
* Licensed under the MIT license.
*
**********************************************************************/
/*********************************************************************
  PACKAGE : SDBM_COLLECTE
  AUTEUR  : Benoit Bouthillier 2008-07-23 (2012-05-03)
 ---------------------------------------------------------------------
  BUT : Ce package permet l'implantation des fonctions de collecte.

**********************************************************************/


   -- Version de l'entête PL/SQL
   VERSION_PS CONSTANT VARCHAR2(4 CHAR) := '0.04';


   TYPE T_RC_INFO IS REF CURSOR;

   PROCEDURE VERSION;

   PROCEDURE TRAITEMENT_FIN_COLLECTE_BD;

   PROCEDURE SAUVEGARDE_STATUT_COLLECTE_BD
   (
      A_NOM_CIBLE     IN EVENEMENT_CIBLE.NOM_CIBLE%TYPE
     ,A_NOM_EVENEMENT IN EVENEMENT_CIBLE.NOM_EVENEMENT%TYPE
     ,A_STATUT        IN VARCHAR2
   );

   PROCEDURE TRAITEMENT_COLLECTE_BD
   (
      A_NOM_CIBLE IN  EVENEMENT_CIBLE.NOM_CIBLE%TYPE
     ,A_CUR_INFO  OUT T_RC_INFO
   );

   PROCEDURE TRAITEMENT_CIBLES_BD
   (
      A_VERSION_SERVEUR         IN  VARCHAR2 DEFAULT 'N/D'
     ,A_CUR_INFO                OUT T_RC_INFO
     ,A_DELAI_MAX_CONNEXION_SEC OUT PARAMETRE.DELAI_MAX_CONNEXION_SEC%TYPE
     ,A_NIVEAU_JOURNAL_SERVEUR  OUT PARAMETRE.NIVEAU_JOURNAL_SERVEUR%TYPE
   );


END SDBM_COLLECTE;
/

