#!/bin/bash
#
# Script:
#    clean.sh
#
# Description:
#    Remove all the file that would by obtain by running download.sh, refresh.sh or compile.sh
#

git clean -x -d -f
