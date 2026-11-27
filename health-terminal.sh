#!/bin/sh
# Bouton "System Health" (tiroir Style) : le rapport de health.sh dans un terminal.
exec xfce4-terminal --title "Etat du systeme" --geometry 100x34 --hold -x "$HOME/.dt/health.sh"
