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

printf "%-*b %6b %6b %6b\n" $MAXLENGTH "Filename" "Syntax" "Critic" "POD"

# add extra 11 of length to compensate espace characters
# (7 of 'color' + 4 of 'no color')
MAXLENGTH=$(($MAXLENGTH+11))

EXITCODE=0

for FILE in $CHANGED_FILES; do
    FILE_OK=1
    perl -Ilib -c $FILE > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        SYN_RESULT="${COLOR_LIGHT_GREEN}OK${COLOR_NC}"
    else
        FILE_OK=0
        SYN_RESULT="${COLOR_RED}FAIL${COLOR_NC}"
    fi
    perlcritic $FILE > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        CRITIC_RESULT="${COLOR_LIGHT_GREEN}OK${COLOR_NC}"
    else
        FILE_OK=0
        CRITIC_RESULT="${COLOR_RED}FAIL${COLOR_NC}"
    fi
    podchecker $FILE > /dev/null 2>&1
    PODCHECKER_EXITCODE=$?
    if [ $PODCHECKER_EXITCODE -eq 0 ]; then
        POD_RESULT="${COLOR_LIGHT_GREEN}OK${COLOR_NC}"
    elif [ $PODCHECKER_EXITCODE -eq 2 ]; then
        POD_RESULT="${COLOR_YELLOW}N/A${COLOR_NC}"
    else
        FILE_OK=0
        POD_RESULT="${COLOR_RED}FAIL${COLOR_NC}"
    fi
    if [ $FILE_OK -eq 1 ]; then
        FILE="${COLOR_WHITE}${FILE}${COLOR_NC}"
    else
        FILE="${COLOR_LIGHT_RED}${FILE}${COLOR_NC}"
    fi
    printf "%-*b %17b %17b %17b\n" $MAXLENGTH $FILE $SYN_RESULT $CRITIC_RESULT $POD_RESULT
    [ $FILE_OK -eq 0 ] && EXITCODE=1
done

cd $CURRENT_DIR
exit $EXITCODE
