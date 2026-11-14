#!/bin/sh
# Alarme de batterie faible : tant que la batterie se decharge sous 30 %, un son
# et une notification chaque minute (urgente sous 10 %). Elle s arrete des que
# le secteur est branche.
# (wmbattery -a ne marche plus : il ecrit dans /dev/audio, qui n existe plus.)
# Lance par sessions/sessionetc.

LOW=30
CRIT=10
PERIOD=60
SOUND=/usr/share/sounds/Yaru/stereo/battery-low.oga
bat=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1)
[ -n "$bat" ] || exit 0
idfile="${XDG_RUNTIME_DIR:-/tmp}/battery-notify.id"

while :; do
    cap=$(cat "$bat/capacity" 2>/dev/null)
    st=$(cat "$bat/status" 2>/dev/null)
    if [ "$st" = Discharging ] && [ -n "$cap" ] && [ "$cap" -lt "$LOW" ]; then
        if [ "$cap" -lt "$CRIT" ]; then urg=critical; else urg=normal; fi
        pw-play "$SOUND" >/dev/null 2>&1 || paplay "$SOUND" >/dev/null 2>&1
        # Une seule bulle, remplacee a chaque minute au lieu de s empiler
        id=$(cat "$idfile" 2>/dev/null)
        notify-send -p ${id:+-r "$id"} -u "$urg" -i battery-caution \
            "Batterie faible : $cap %" "Branche le chargeur." >"$idfile" 2>/dev/null
    fi
    sleep "$PERIOD"
done
