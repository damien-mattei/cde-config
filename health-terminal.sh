#!/bin/sh
# Bouton "System Health" (tiroir Style) : le rapport de health.sh dans un terminal.
exec xfce4-terminal --title "System health" --geometry 100x34 --hold -x "$HOME/.dt/health.sh"
