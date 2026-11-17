#!/bin/sh
# Zone de notification (stalonetray) dans une fenetre a part, en bas a droite
# du bureau (ecran du portable), en colonne qui s allonge vers le haut, sur
# tous les bureaux virtuels. Hors du Front Panel, le clic droit arrive aux
# icones (dans le panneau, dtwm le garde pour son propre menu).
# dtwm laisse le haut de la fenetre fixe quand stalonetray s agrandit : on la
# recale dans le coin a chaque changement de taille (et panel-applets-watch.sh
# le fait si l ecran change).
/usr/bin/stalonetray --vertical --geometry 1x1-0-0 \
    --icon-gravity SE \
    --icon-size 24 --slot-size 28 --background '#C6B2A8' \
    --decorations none --window-type normal --window-strut none \
    --skip-taskbar --kludges force_icons_size &
pid=$!

# Une fois la fenetre geree par dtwm : sur tous les bureaux virtuels.
for i in 1 2 3 4 5 6 7 8 9 10; do
    sleep 1
    w=$(xdotool search --classname '^stalonetray$' 2>/dev/null | head -1)
    [ -n "$w" ] && xprop -id "$w" WM_STATE 2>/dev/null | grep -q Normal && {
        "$HOME/.dt/bin/occupyall" "$w"; break; }
done
[ -n "$w" ] || { wait $pid; exit; }

corner() {
    eval "$(xdotool getwindowgeometry --shell "$w" 2>/dev/null)" || return
    r=$(xwininfo -root | awk '/^  Width/{a=$2}/^  Height/{b=$2}END{print a" "b}')
    set -- $r
    [ "$X" -eq $(($1 - WIDTH)) ] && [ "$Y" -eq $(($2 - HEIGHT)) ] ||
        xdotool windowmove "$w" $(($1 - WIDTH)) $(($2 - HEIGHT))
}
corner
stdbuf -oL xev -id "$w" -event structure 2>/dev/null | while read -r l; do
    case $l in ConfigureNotify*) corner ;; esac
done
wait $pid
