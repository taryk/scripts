#!/bin/bash

# DIMENSIONS=$(xdpyinfo | grep 'dimensions:'|awk '{print $2}')
DIMENSIONS=$(xrandr | grep "Screen 0" | awk '{ print $8 "x" $10 }' | sed 's/,.*//')

if [ -z "$1" ]; then
    OUTPUTFILE=$HOME/tmp/out.mpg
else
    OUTPUTFILE=$1
fi

OUTPUTDIR=$(dirname $OUTPUTFILE)

[ -d "$OUTPUTDIR" ] || mkdir "$OUTPUTDIR"

ffmpeg -f x11grab -s $DIMENSIONS -r 25 -i :0.0 -sameq $OUTPUTFILE

