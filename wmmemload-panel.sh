#!/bin/sh
# Integre wmmemload au Front Panel (controle WmMemLoad) sans son cadre.
# La fenetre "icone" (64x64, avec cadre) est masquee au profit de la fenetre
# principale (58x58, sans cadre), a laquelle il manque WM_CLASS : on le pose,
# puis on l'affiche pour que dtwm la reconnaisse.
/usr/bin/wmmemload -b -c &
i=0
while [ $i -lt 20 ]; do
    MAIN=""; ICON=""
    for w in $(xdotool search --name '^wmmemload$' 2>/dev/null); do
        if xprop -id "$w" WM_CLASS 2>/dev/null | grep -q DockApp; then
            xwininfo -id "$w" | grep -q 'Width: 1$' || ICON=$w
        else
            MAIN=$w
        fi
    done
    [ -n "$MAIN" ] && [ -n "$ICON" ] && break
    sleep 0.5
    i=$((i + 1))
done
[ -n "$MAIN" ] && [ -n "$ICON" ] || exit 1
xdotool windowunmap --sync "$ICON"
xprop -id "$MAIN" -f WM_CLASS 8s -set WM_CLASS wmmemload
xdotool windowmap --sync "$MAIN"
