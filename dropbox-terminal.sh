#!/bin/sh
# Relance Dropbox dans un terminal pour voir ses messages et ses erreurs.
# Le Dropbox lance en arriere-plan a l'ouverture de session est d'abord arrete.
if pgrep -u "$(id -u)" -x dropbox >/dev/null; then
    pkill -u "$(id -u)" -x dropbox
    for i in 1 2 3 4 5 6 7 8 9 10; do
        pgrep -u "$(id -u)" -x dropbox >/dev/null || break
        sleep 1
    done
fi
exec xfce4-terminal --title Dropbox --hold -x "$HOME/.dt/dropbox-console.sh"
