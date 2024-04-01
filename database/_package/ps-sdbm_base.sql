-- *
-- * Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
-- * Licensed under the MIT license.
-- * See LICENSE file in the project root for full license information.
-- *


CREATE OR REPLACE PACKAGE SDBM_BASE
IS
/*********************************************************************
*
* Copyright (c) 2008-2024 Benoit Bouthillier. All rights reserved.
* Licensed under the MIT license.
*
**********************************************************************/
/*********************************************************************
  PACKAGE : SDBM_BASE
  AUTEUR  : Benoit Bouthillier 2008-07-23
 ---------------------------------------------------------------------
  BUT : Ce package permet l'implantation des fonctions de base SDBM.

**********************************************************************/


   -- Version de l'entête PL/SQL
   VERSION_PS CONSTANT VARCHAR2(4 CHAR) := '0.02';


   TYPE T_RC_INFO IS REF CURSOR;

   PROCEDURE VERSION;

   PROCEDURE JOURNALISER
   (
      A_SOURCE IN JOURNAL.SOURCE%TYPE -- Source du message
     ,A_NIVEAU IN JOURNAL.NIVEAU%TYPE -- Niveau du message
     ,A_TEXTE  IN JOURNAL.TEXTE%TYPE  -- Texte du message
   );

   PROCEDURE TRAITEMENT_CIBLES_BD
   (
      A_VERSION_SERVEUR         IN  VARCHAR2 DEFAULT 'N/D'
     ,A_CUR_INFO                OUT T_RC_INFO
     ,A_DELAI_MAX_CONNEXION_SEC OUT PARAMETRE.DELAI_MAX_CONNEXION_SEC%TYPE
     ,A_FREQU_VERIF_CIBLE_SEC   OUT PARAMETRE.FREQU_VERIF_CIBLE_SEC%TYPE
     ,A_NIVEAU_JOURNAL_SERVEUR  OUT PARAMETRE.NIVEAU_JOURNAL_SERVEUR%TYPE
   );

   PROCEDURE SAUVEGARDE_STATUT_CIBLE
   (
      A_TYPE_CIBLE     IN CIBLE.TYPE_CIBLE%TYPE                  -- Type de cible
     ,A_NOM_CIBLE      IN CIBLE.NOM_CIBLE%TYPE                   -- Nom de la cible
     ,A_STATUT         IN CIBLE.STATUT%TYPE                      -- Statut de la cible
     ,A_STARTUP_TIME   IN CIBLE.STARTUP_TIME%TYPE   DEFAULT NULL -- STARTUP_TIME (V$INSTANCE)
     ,A_NOM_SERVEUR    IN CIBLE.NOM_SERVEUR%TYPE    DEFAULT NULL -- HOST_NAME (V$INSTANCE)
     ,A_NOM_INSTANCE   IN CIBLE.NOM_INSTANCE%TYPE   DEFAULT NULL -- INSTANCE_NAME (V$INSTANCE)
     ,A_VERSION        IN CIBLE.VERSION%TYPE        DEFAULT NULL -- VERSION (V$INSTANCE)
     ,A_FICHIER_ALERTE IN CIBLE.FICHIER_ALERTE%TYPE DEFAULT NULL -- FICHIER_ALERTE (V$PARAMETER)
   );

   PROCEDURE TRAITEMENT_EVENEMENTS_BD
   (
      A_NOM_CIBLE               IN  EVENEMENT_CIBLE.NOM_CIBLE%TYPE    -- Nom de la cible
     ,A_CUR_INFO                OUT T_RC_INFO                         -- Curseur
   );

   PROCEDURE SAUVEGARDE_STATUT_EVENEMENT_BD
   (
      A_NOM_CIBLE     IN HIST_EVENEMENT_CIBLE.NOM_CIBLE%TYPE                   -- Nom de la cible
     ,A_NOM_EVENEMENT IN HIST_EVENEMENT_CIBLE.NOM_EVENEMENT%TYPE               -- Nom de l'événement
     ,A_NOM_OBJET     IN HIST_EVENEMENT_CIBLE.NOM_OBJET%TYPE     DEFAULT '?'   -- Nom de l'objet
     ,A_RESULTAT      IN HIST_EVENEMENT_CIBLE.RESULTAT%TYPE      DEFAULT '?'   -- Résultat obtenu
   );

   PROCEDURE TRAITER_STATUT_EVENEMENT_BD
   (
      A_NOM_CIBLE IN EVENEMENT_CIBLE.NOM_CIBLE%TYPE -- Nom de la cible
   );

   PROCEDURE TRAITEMENT_REPARATIONS_BD
   (
      A_NOM_CIBLE IN  REPARATION_EVEN_CIBLE.NOM_CIBLE%TYPE -- Nom de la cible
     ,A_CUR_INFO  OUT T_RC_INFO                            -- Curseur
   );

   PROCEDURE SAUVEGARDE_REPARATION_BD
   (
      A_NOM_CIBLE      IN HIST_REPARATION_EVEN_CIBLE.NOM_CIBLE%TYPE      -- Nom de la cible
     ,A_NOM_EVENEMENT  IN HIST_REPARATION_EVEN_CIBLE.NOM_EVENEMENT%TYPE  -- Nom de l'événement
     ,A_NOM_REPARATION IN HIST_REPARATION_EVEN_CIBLE.NOM_REPARATION%TYPE -- Nom de la réparation
     ,A_STATUT         IN HIST_REPARATION_EVEN_CIBLE.STATUT%TYPE         -- Statut de la réparation
   );


END SDBM_BASE;
/
