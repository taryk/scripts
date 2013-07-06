#!/bin/bash

set -u

COLOR_NC="\e[0m" # No Color
COLOR_WHITE="\e[1;37m"
COLOR_BLACK="\e[0;30m"
COLOR_BLUE="\e[0;34m"
COLOR_LIGHT_BLUE="\e[1;34m"
COLOR_GREEN="\e[0;32m"
COLOR_LIGHT_GREEN="\e[1;32m"
COLOR_CYAN="\e[0;36m"
COLOR_LIGHT_CYAN="\e[1;36m"
COLOR_RED="\e[0;31m"
COLOR_LIGHT_RED="\e[1;31m"
COLOR_PURPLE="\e[0;35m"
COLOR_LIGHT_PURPLE="\e[1;35m"
COLOR_BROWN="\e[0;33m"
COLOR_YELLOW="\e[1;33m"
COLOR_GRAY="\e[0;30m"
COLOR_LIGHT_GRAY="\e[0;37m"

CHANGED_FILES=$(git diff --name-only master | grep -e '\.p[lm]$')

GIT_ROOT=$(git rev-parse --show-toplevel)
CURRENT_DIR=$PWD

[ "x$CURRENT_DIR" != "x$GIT_ROOT" ] && cd $GIT_ROOT

MAXLENGTH=0
for FILE in $CHANGED_FILES; do
    [ ${#FILE} -gt $MAXLENGTH ] && MAXLENGTH=${#FILE}
done

# add extra 11 of length to compensate espace characters
# (7 of 'color' + 4 of 'no color')
MAXLENGTH=$(($MAXLENGTH+11))

EXITCODE=0
for FILE in $CHANGED_FILES; do
    perl -Ilib -c $FILE > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        FILE="${COLOR_WHITE}${FILE}${COLOR_NC}"
        RESULT="${COLOR_LIGHT_GREEN}OK${COLOR_NC}"
    else
        EXITCODE=1
        FILE="${COLOR_LIGHT_RED}${FILE}${COLOR_NC}"
        RESULT="${COLOR_RED}FAIL${COLOR_NC}"
    fi
    printf "%-*b %-40b\n" $MAXLENGTH $FILE $RESULT
done

cd $CURRENT_DIR
exit $EXITCODE
