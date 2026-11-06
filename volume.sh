#!/bin/sh
# Touches de volume (liees dans ~/.dt/dtwmrc) : up | down | mute | micmute.
# Volume limite a 150 %, avec une notification qui montre le niveau.
sink=@DEFAULT_SINK@
case "$1" in
    up)
        v=$(pactl get-sink-volume $sink | sed -n 's/.* \([0-9]*\)% .*/\1/p' | head -1)
        if [ "${v:-0}" -lt 150 ]; then
            n=$((v + 5)); [ $n -gt 150 ] && n=150
            pactl set-sink-volume $sink "$n%"
        fi
        pactl set-sink-mute $sink 0 ;;
    down)    pactl set-sink-volume $sink -5% ;;
    mute)    pactl set-sink-mute $sink toggle ;;
    micmute) pactl set-source-mute @DEFAULT_SOURCE@ toggle
             if pactl get-source-mute @DEFAULT_SOURCE@ | grep -q 'oui\|yes'; then
                 t="Micro coupé"; i=microphone-sensitivity-muted
             else
                 t="Micro actif"; i=microphone-sensitivity-high
             fi
             notify-send -h string:x-canonical-private-synchronous:micro -i $i "$t"
             exit 0 ;;
    *) echo "usage: $0 up|down|mute|micmute" >&2; exit 1 ;;
esac
v=$(pactl get-sink-volume $sink | sed -n 's/.* \([0-9]*\)% .*/\1/p' | head -1)
if pactl get-sink-mute $sink | grep -q 'oui\|yes'; then
    notify-send -h string:x-canonical-private-synchronous:volume -h int:value:0 \
        -i audio-volume-muted "Son coupé"
else
    if [ "$v" -eq 0 ]; then i=audio-volume-muted
    elif [ "$v" -lt 34 ]; then i=audio-volume-low
    elif [ "$v" -lt 67 ]; then i=audio-volume-medium
    else i=audio-volume-high; fi
    notify-send -h string:x-canonical-private-synchronous:volume -h int:value:$v \
        -i $i "Volume $v %"
fi
