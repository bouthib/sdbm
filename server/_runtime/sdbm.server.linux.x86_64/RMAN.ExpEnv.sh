#!/bin/bash


# Utilities
. ${INIT_REPERTOIRE}/LibUtilsBASH.sh


# Oracle environment variables
export NLS_DATE_FORMAT='YYYYMMDD:HH24:MI:SS';
export NLS_LANG=AMERICAN_AMERICA.WE8ISO8859P1;


#######################################
# RMAN specific variables
#######################################

# RMAN backup format
export RMAN_FORMAT=/backup/XE.`hostname`;

# RMAN readrate
export RMAN_READRATE_M=25;

# Number of backup to keep (in days - 0 = last copy)
export CLBKP_NB_JOURS=0;
