#!/bin/sh
# Touches de volume (liees dans ~/.dt/dtwmrc) : up | down | mute | micmute.
# Volume limite a 120 % (au-dela, les haut-parleurs saturent), avec une
# notification qui montre le niveau.
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
        if [ "${v:-0}" -lt 120 ]; then
            n=$((v + 5)); [ $n -gt 120 ] && n=120
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
    notify audio-volume-muted "Son coupé"    # sans barre (voir plus bas)
else
    if [ "$v" -eq 0 ]; then i=audio-volume-muted
    elif [ "$v" -lt 34 ]; then i=audio-volume-low
    elif [ "$v" -lt 67 ]; then i=audio-volume-medium
    else i=audio-volume-high; fi
    # Barre a la meme echelle que le curseur de pavucontrol, qui va jusqu'a
    # 153 % : 100 % tombe aux deux tiers et la barre continue au-dela.
    # Une barre a 0 s'affiche quand meme avec un bout rempli (dessin du theme) :
    # a 0 %, on montre seulement le texte.
    b=$((v * 100 / 153)); [ $b -gt 100 ] && b=100; [ $b -eq 0 ] && b=
    if [ "$v" -gt 100 ]; then
        notify $i "Volume $v % (amplifié)" $b
    else
        notify $i "Volume $v %" "$b"
    fi
fi
