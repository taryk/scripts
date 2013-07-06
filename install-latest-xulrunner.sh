#!/bin/bash

if [ $UID -ne 0 ]; then
    echo "This script must be executed as root"
    exit 1
fi

COLOR_NC="\e[0m" # No Color
COLOR_LIGHT_GREEN="\e[1;32m"
COLOR_WHITE="\e[1;37m"
COLOR_LIGHT_PURPLE="\e[1;35m"

function echo_colored {
    MSG="${COLOR_WHITE}$1"
    [ $# -gt 1 ] && [ ! -z $2 ] && MSG="${MSG}: ${COLOR_LIGHT_PURPLE}$2"
    echo -e "${COLOR_LIGHT_GREEN} * ${MSG}${COLOR_NC}"
}

FFVERSION=$(grep -Po "\d{2}\.\d+" /usr/lib/firefox/platform.ini)
ARCH=$(uname -p)
echo_colored "Current Firefox version" $FFVERSION
XURL="https://ftp.mozilla.org/pub/mozilla.org/xulrunner/releases/$FFVERSION/runtimes/xulrunner-$FFVERSION.en-US.linux-$ARCH.tar.bz2"
XULRUNNER_PATH="/opt/xulrunner"

function xulrunner_link {
    FILEPATH="/usr/bin/$1"
    [ -f $FILEPATH ] && rm -f $FILEPATH
    ln -s "${XULRUNNER_PATH}/$1" $FILEPATH
    echo_colored "Created a link" $FILEPATH
}

[ -d $XULRUNNER_PATH ] && rm -rf $XULRUNNER_PATH

CURRENT_DIR=$PWD

cd /opt

DOWNLOAD_FILENAME=$(basename $XURL)
echo_colored "Downloading" $DOWNLOAD_FILENAME
wget -O- $XURL | tar -xj

# for FILE in xulrunner xpcshell ; do
#    xulrunner_link $FILE 
# done
xulrunner_link "xulrunner"

cd $CURRENT_DIR

echo_colored "Done"
