#!/bin/sh
# Ouvre l'horloge numerique sans bord, ou la ferme si elle est deja ouverte.
pat='^/usr/bin/xclock .*-name panelclock'
if pgrep -u "$(id -u)" -f "$pat" >/dev/null; then
    exec pkill -u "$(id -u)" -f "$pat"
fi
exec /usr/bin/xclock -name panelclock -digital -strftime '%H:%M:%S' -update 1 \
    -bg white -fg black -padding 4 -geometry +361-85 \
    -xrm '*overrideRedirect: true'
