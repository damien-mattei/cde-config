#!/bin/sh
# Touches de volume (liees dans ~/.dt/dtwmrc) : up | down | mute | micmute.
# Volume limite a 150 %, avec une notification qui montre le niveau.
sink=@DEFAULT_SINK@
# Une seule bulle de notification, remplacee a chaque appui (son identifiant
# est garde ici) au lieu d'en empiler une par appui.
idf="${XDG_RUNTIME_DIR:-/tmp}/volume-notify.id"
notify() {    # notify <icone> <texte> [valeur de la barre 0-100]
    id=$(cat "$idf" 2>/dev/null)
    set -- -i "$1" ${3:+-h int:value:$3} "$2"
    notify-send -t 1500 -p ${id:+-r "$id"} "$@" >"$idf.new" 2>/dev/null &&
        mv "$idf.new" "$idf"
}
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
             notify $i "$t"
             exit 0 ;;
    *) echo "usage: $0 up|down|mute|micmute" >&2; exit 1 ;;
esac
v=$(pactl get-sink-volume $sink | sed -n 's/.* \([0-9]*\)% .*/\1/p' | head -1)
if pactl get-sink-mute $sink | grep -q 'oui\|yes'; then
    notify audio-volume-muted "Son coupé" 0
else
    if [ "$v" -eq 0 ]; then i=audio-volume-muted
    elif [ "$v" -lt 34 ]; then i=audio-volume-low
    elif [ "$v" -lt 67 ]; then i=audio-volume-medium
    else i=audio-volume-high; fi
    # La barre ne va que jusqu'a 100 : au-dela, elle reste pleine et le texte
    # indique que le son est amplifie.
    if [ "$v" -gt 100 ]; then
        notify $i "Volume $v % (amplifié)" 100
    else
        notify $i "Volume $v %" "$v"
    fi
fi
