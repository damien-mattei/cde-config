#!/bin/sh
# Lance xeyes pour le Front Panel (controle XEyes), puis donne au serveur X la
# couleur de fond de sa fenetre de dessin : xeyes ne repeint pas son fond quand
# une fenetre passe dessus, le serveur X le fait alors a sa place.
# (outil ~/.dt/bin/setbg, source dans ~/.dt/src/setbg.c)
bg='#C6B2A8'
setsid /usr/bin/xeyes -bg "$bg" +shape +present >/dev/null 2>&1 &
for i in 1 2 3 4 5 6 7 8 9 10; do
    sleep 1
    w=$(xdotool search --classname '^xeyes$' 2>/dev/null | head -1)
    [ -n "$w" ] || continue
    c=$(xwininfo -id "$w" -children 2>/dev/null | awk '/^     0x/{print $1; exit}')
    "$HOME/.dt/bin/setbg" "$w" "$bg"
    [ -n "$c" ] && "$HOME/.dt/bin/setbg" "$c" "$bg"
    exit 0
done
