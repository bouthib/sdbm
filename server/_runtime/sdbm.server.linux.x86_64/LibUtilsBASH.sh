#!/bin/bash
###############################################################################
#
# Librairie:
#    LibUtilsBASH.sh         
#
# Créateur:
#    Benoit Bouthillier
#
# Date:
#    25 janvier 2010
#
# Description:
#    Librairie de fonction utilitaire de type BASH.
#
###############################################################################



###############################################################################
#
# Routine : 
#    journaliser()
#
# Auteur:
#    Benoit Bouthillier
#
# Date:
#    25 janvier 2010
#
# Description:
#    Journalisation d'un message vers les sorties standards.
#
#
# Parametres:
#
#    Entrees:
#       1 : Message
#       2 : Type de message
#       3 : Niveau de journalisation
#
#    Sorties:
#       aucun
#
#
# Retour:
#    0 : Fin normale                           
#    1 : Erreur pendant la jounalisation  
#
###############################################################################

# Type de message
export LU_TYPE_MSG_INF="Informational";
export LU_TYPE_MSG_AVE="Warning";
export LU_TYPE_MSG_ERR="Error";


journaliser()
{
   #
   # Verification des parametres recus
   #
   
   
   # Verification du nombre de parametre
   if [ "$#" != "2" ] ; then
      echo " ";
      echo " - journaliser()  :  \\LibUtilsKSH.sh\\"$0
      echo "   Erreur : Parametres invalides.";
      echo " ";
      return 1;
   fi
   
   # Verification du type de message
   if [ "$2" != $LU_TYPE_MSG_INF ] &&
      [ "$2" != $LU_TYPE_MSG_AVE ] &&
      [ "$2" != $LU_TYPE_MSG_ERR ] ; then
      echo " ";
      echo " - journaliser()  :  \\LibUtilsKSH.sh\\"$0
      echo "   Erreur : Parametres invalides.";
      echo "        \$LU_TYPE_MSG_INF";
      echo "        \$LU_TYPE_MSG_AVE";
      echo "        \$LU_TYPE_MSG_ERR";
      echo " ";
      return 1;
   fi


   # Affichage à l'ecran
   export LU_JRN_TIMESTAMP=`date +%Y/%m/%d:%H:%M:%S`;
   awk 'BEGIN { printf("%18s  SEV: %-13s  %s\n", ARGV[1], ARGV[2], ARGV[3]) }' "$LU_JRN_TIMESTAMP" "$2" "$1";
   

   # Fin normale
   return 0;
}
