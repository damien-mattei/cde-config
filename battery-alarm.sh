#!/bin/sh
# Alarme de batterie faible : un son et une notification quand la batterie,
# en decharge, passe sous 30 % (puis sous 10 %, niveau critique).
# Une seule alarme par seuil ; elle se rearme quand on rebranche le secteur.
# (wmbattery -a ne marche plus : il ecrit dans /dev/audio, qui n existe plus.)
# Lance par sessions/sessionetc.

LOW=30
CRIT=10
SOUND=/usr/share/sounds/Yaru/stereo/battery-low.oga
bat=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1)
[ -n "$bat" ] || exit 0

alarm() {   # $1 = niveau, $2 = urgence de la notification
    pw-play "$SOUND" >/dev/null 2>&1 || paplay "$SOUND" >/dev/null 2>&1
    notify-send -u "$2" -i battery-caution "Batterie faible : $1 %" \
        "Branche le chargeur."
}

warned=100   # dernier seuil deja signale
while :; do
    cap=$(cat "$bat/capacity" 2>/dev/null)
    st=$(cat "$bat/status" 2>/dev/null)
    if [ "$st" = Discharging ] && [ -n "$cap" ]; then
        if [ "$cap" -lt "$CRIT" ] && [ "$warned" -gt "$CRIT" ]; then
            alarm "$cap" critical; warned=$CRIT
        elif [ "$cap" -lt "$LOW" ] && [ "$warned" -gt "$LOW" ]; then
            alarm "$cap" normal; warned=$LOW
        fi
    else
        warned=100   # secteur branche : on rearme
    fi
    sleep 60
done
