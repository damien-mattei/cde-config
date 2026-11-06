#!/bin/sh
# Touches de luminosite (liees dans ~/.dt/dtwmrc) : up | down.
# - Ecriture directe par logind (SetBrightness) : environ 0,01 s par cran, au
#   lieu de 0,25 s avec xfce4-power-manager qui passe par pkexec.
# - Echelle progressive : niveau L de 0 a 100 par crans de 5, et luminosite
#   = max * (L/100)^2, pour que chaque cran se voie autant en bas qu'en haut.
#   Au niveau 0, le retroeclairage est eteint (ecran noir) : la touche de
#   luminosite + le rallume.
dev=/sys/class/backlight/intel_backlight
max=$(cat $dev/max_brightness); cur=$(cat $dev/brightness)
new=$(awk -v c="$cur" -v m="$max" -v d="$1" 'BEGIN {
    l = int(sqrt(c / m) * 100 / 5 + 0.5) * 5          # niveau actuel arrondi a 5
    if (d == "up") l += 5; else if (d == "down") l -= 5
    if (l < 0) l = 0; if (l > 100) l = 100
    printf "%d %d\n", l, int(m * (l / 100) ^ 2 + 0.5) }')
level=${new% *}; raw=${new#* }
busctl call org.freedesktop.login1 /org/freedesktop/login1/session/auto \
    org.freedesktop.login1.Session SetBrightness ssu backlight "${dev##*/}" "$raw"
# Une seule bulle, remplacee a chaque appui (comme volume.sh).
idf="${XDG_RUNTIME_DIR:-/tmp}/brightness-notify.id"
id=$(cat "$idf" 2>/dev/null)
bar=$level; [ "$level" -eq 0 ] && bar=     # une barre a 0 garde un bout rempli
notify-send -t 1500 -p ${id:+-r "$id"} -i display-brightness ${bar:+-h int:value:$bar} \
    "Luminosité $level %" >"$idf.new" 2>/dev/null && mv "$idf.new" "$idf"
