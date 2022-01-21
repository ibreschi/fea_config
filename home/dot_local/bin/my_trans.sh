#!/bin/bash
# Requires trans installed




function lookup() {
    short=${2:-y}
    if [[ $short = y ]]; then
        ans=$(trans -s eng -t fr "$1")
    else
        ans=$(trans -s eng -t fr "$1")
    fi
    echo "$ans"
}

QUERY=$(rofi -dmenu -p 'Translate:')

while [[ -n $QUERY ]]; do
    trans=$(lookup "$QUERY" 'y')
    # get new search
    QUERY=$(echo "$trans" | sed 's/\x1b\[[0-9;]*m//g' |  rofi -dmenu -config ~/.config/rofi/config.rasi)
done
