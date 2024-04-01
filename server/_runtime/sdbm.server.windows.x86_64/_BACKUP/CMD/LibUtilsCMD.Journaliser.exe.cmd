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
rem #    LibUtilsCMD.Journaliser.exe()
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



rem #
rem # Verification des parametres recus
rem #


rem # Verification du nombre de parametre
if "%2" EQU "" goto ERREUR_SYNTAXE
if "%3" NEQ "" goto ERREUR_SYNTAXE


rem # Verification du type de message
set LU_T_PAR_TYP_OK=FAUX
if "%2" EQU "%LU_TYPE_MSG_INF%" set LU_T_PAR_TYP_OK=VRAI
if "%2" EQU "%LU_TYPE_MSG_AVE%" set LU_T_PAR_TYP_OK=VRAI
if "%2" EQU "%LU_TYPE_MSG_ERR%" set LU_T_PAR_TYP_OK=VRAI
if "%LU_T_PAR_TYP_OK%" EQU "FAUX" goto ERREUR_PAR_INV_TYP


rem # Affichage à l'ecran
echo %DATE%:%TIME%  SEV: %2  %1


goto FIN_NORMALE



:ERREUR_PAR_INV_TYP
echo.
echo  - journaliser()  :  LibUtilsCMD.Journaliser.exe
echo    Erreur : Parametres #2 invalides.
echo         %%LU_TYPE_MSG_INF%%
echo         %%LU_TYPE_MSG_AVE%%
echo         %%LU_TYPE_MSG_ERR%%
echo.
exit 1


:ERREUR_SYNTAXE
echo.
echo  - journaliser()  :  LibUtilsCMD.Journaliser.exe
echo    Erreur : Nombre de parametre invalide.
echo.
exit 1


:FIN_NORMALE
