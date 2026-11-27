#!/bin/sh
# Bouton "System Health" (tiroir Style) : le rapport de health.sh dans un terminal.
. "$HOME/.dt/lang.sh"
exec xfce4-terminal --title "$(msg "État du système" "System health")" --geometry 100x34 --hold -x "$HOME/.dt/health.sh"
