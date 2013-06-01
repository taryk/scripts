#!/bin/bash
# notify-send -u critical "$(xsel -o)" "$(wget -U "Mozilla/5.0" -qO - "http://translate.google.com/translate_a/t?client=t&text=$(xsel -o | sed "s/[\"'<>]//g")&sl=en&tl=ru" | sed 's/\[\[\[\"//' | cut -d \" -f 1)"
# notify-send "$(xsel -o)" "$(wget -U "Mozilla/5.0" -qO - "http://translate.google.com/translate_a/t?client=t&text=$(xsel -o | sed "s/[\"'<>]//g")&sl=en&tl=uk" | sed 's/\[\[\[\"//' | cut -d \" -f 1)"

SELECTED=`xsel -o`
notify-send "$SELECTED" "$(python ~/bin/tran.py "$(echo $SELECTED | sed "s/([\"'])/\\\1/g")" 2>&1)"
