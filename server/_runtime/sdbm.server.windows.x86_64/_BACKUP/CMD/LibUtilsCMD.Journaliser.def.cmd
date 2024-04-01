@echo off
rem ###############################################################################
rem #
rem # Librairie:
rem #    LibUtilsCMD.cmd
rem #
rem # Créateur:
rem #    Benoit Bouthillier
rem #
rem # Date:
rem #    25 janvier 2010
rem #
rem # Description:
rem #    Librairie de fonction utilitaire de type CMD (Windows).
rem #
rem ###############################################################################



rem ###############################################################################
rem #
rem # Routine : 
rem #    LibUtilsCMD.Journaliser.def()
rem #
rem # Auteur:
rem #    Benoit Bouthillier
rem #
rem # Date:
rem #    25 janvier 2010
rem #
rem # Description:
rem #    Journalisation d'un message vers les sorties standards.
rem #
rem #
rem # Parametres:
rem #
rem #    Entrees:
rem #       1 : Message
rem #       2 : Type de message
rem #
rem #    Sorties:
rem #       aucun
rem #
rem #
rem # Retour:
rem #    0 : Fin normale                           
rem #    1 : Erreur pendant la jounalisation  
rem #
rem ###############################################################################


rem # Type de message
set LU_TYPE_MSG_INF=Information
set LU_TYPE_MSG_AVE=Warning
set LU_TYPE_MSG_ERR=Error
