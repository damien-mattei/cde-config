#!/bin/sh
# Alarme de batterie faible : tant que la batterie se decharge sous 30 %, un son
# et une notification chaque minute ; sous 10 %, un bip strident et une
# notification urgente. Elle s arrete des que
# le secteur est branche.
# (wmbattery -a ne marche plus : il ecrit dans /dev/audio, qui n existe plus.)
# Lance par sessions/sessionetc.

LOW=30
CRIT=10
PERIOD=60
SOUND=/usr/share/sounds/Yaru/stereo/battery-low.oga
# Son de repli si le theme sonore d Ubuntu n est pas installe
[ -r "$SOUND" ] || SOUND=/usr/share/sounds/freedesktop/stereo/dialog-warning.oga
bat=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1)
[ -n "$bat" ] || exit 0
idfile="${XDG_RUNTIME_DIR:-/tmp}/battery-notify.id"

while :; do
    cap=$(cat "$bat/capacity" 2>/dev/null)
    st=$(cat "$bat/status" 2>/dev/null)
    if [ "$st" = Discharging ] && [ -n "$cap" ] && [ "$cap" -lt "$LOW" ]; then
        if [ "$cap" -lt "$CRIT" ]; then
            urg=critical
            # Bip strident (repris de ~/bin/battery-alert.sh) : 2000 Hz, 0,5 s
            timeout -k 0.75s 0.5s speaker-test --frequency 2000 --test sine >/dev/null 2>&1
        else
            urg=normal
            pw-play "$SOUND" >/dev/null 2>&1 || paplay "$SOUND" >/dev/null 2>&1
        fi
        # Une seule bulle, remplacee a chaque minute au lieu de s empiler
        id=$(cat "$idfile" 2>/dev/null)
        notify-send -p ${id:+-r "$id"} -u "$urg" -i battery-caution \
            "Batterie faible : $cap %" "Branche le chargeur." >"$idfile" 2>/dev/null
    fi
    sleep "$PERIOD"
done
