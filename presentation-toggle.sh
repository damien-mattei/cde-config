#!/bin/sh
# Active ou desactive le mode presentation de xfce4-power-manager
# (pas de veille automatique ni d'extinction de l'ecran quand il est actif).
. "$HOME/.dt/lang.sh"
p=/xfce4-power-manager/presentation-mode
if [ "$(xfconf-query -c xfce4-power-manager -p $p 2>/dev/null)" = true ]; then
    xfconf-query -c xfce4-power-manager -p $p -s false
    notify-send -i video-display "$(msg "Mode présentation désactivé" "Presentation mode off")" \
        "$(msg "La veille automatique et l'extinction de l'écran sont rétablies." "Automatic suspend and screen blanking are back.")"
else
    xfconf-query -c xfce4-power-manager -p $p -n -t bool -s true
    notify-send -i video-display "$(msg "Mode présentation activé" "Presentation mode on")" \
        "$(msg "Pas de veille automatique ni d'extinction de l'écran." "No automatic suspend, the screen stays on.")"
fi
