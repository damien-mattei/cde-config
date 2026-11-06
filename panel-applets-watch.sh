#!/bin/sh
# Apres un "Restart workspace manager", dtwm laisse wmcpuload et wmmemload masques,
# et xeyes avec des traces noires.
# Ce script les reaffiche pour qu'ils reprennent leur place dans le Front Panel.
sleep 10    # laisse wmmemload-panel.sh finir au demarrage de la session

# xeyes garde des traces noires quand dtwm le reprend apres un redemarrage, ou
# apres une mise en veille, et rien ne les efface. Un xeyes neuf, integre par
# un dtwm deja pret, est propre : on le relance (seulement s'il tournait deja).
xeyes_relaunch() {
    pkill -u "$(id -u)" -x xeyes || return
    sleep 1
    "$HOME/.dt/xeyes-panel.sh"
}

# Un redemarrage de dtwm donne deux changements de parent : dtwm relache la
# fenetre, puis la reprend une fois relance. Apres le second, on relance xeyes.
xeyes_watch() {
    fifo=$(mktemp -u "${XDG_RUNTIME_DIR:-/tmp}/xeyes-watch.XXXXXX")
    mkfifo "$fifo" || return
    trap 'rm -f "$fifo"' EXIT
    while xdpyinfo >/dev/null 2>&1; do
        w=$(xdotool search --classname '^xeyes$' 2>/dev/null | head -1)
        if [ -z "$w" ]; then sleep 5; continue; fi
        stdbuf -oL xev -id "$w" -event structure >"$fifo" 2>/dev/null &
        xp=$!
        n=0; fin=
        while read -r l; do
            case $l in
                ReparentNotify*) n=$((n + 1)); [ $n -ge 2 ] && { fin=restart; break; } ;;
                DestroyNotify*) fin=closed; break ;;
            esac
        done <"$fifo"
        kill $xp 2>/dev/null; wait $xp 2>/dev/null
        if [ "$fin" = restart ]; then
            sleep 2
            xeyes_relaunch
        fi
        sleep 5    # laisse dtwm integrer le nouveau xeyes avant de surveiller
    done
}
xeyes_watch &
last=$(date +%s)
while xprop -root _NET_SUPPORTED >/dev/null 2>&1 || xdpyinfo >/dev/null 2>&1; do
    # Sortie de veille : l'horloge a fait un bond bien plus grand que la pause de 5 s.
    now=$(date +%s)
    if [ $((now - last)) -gt 30 ]; then
        sleep 20   # laisse l'affichage se retablir (a 7 s, xeyes restait noir)
        xeyes_relaunch
    fi
    last=$now
    for w in $(xdotool search --name '^wmcpuload$' 2>/dev/null); do
        info=$(xwininfo -id "$w" 2>/dev/null) || continue
        echo "$info" | grep -q 'Width: 1$' && continue    # fenetre de groupe
        echo "$info" | grep -q 'IsUnMapped' && xdotool windowmap "$w"
    done
    for w in $(xdotool search --name '^wmmemload$' 2>/dev/null); do
        # Les fenetres de classe DockApp doivent rester masquees (icone avec cadre).
        xprop -id "$w" WM_CLASS 2>/dev/null | grep -q DockApp && continue
        xwininfo -id "$w" 2>/dev/null | grep -q 'IsUnMapped' && xdotool windowmap "$w"
    done
    # Les applets du panneau sont lances par sessionetc. Sans WM_COMMAND, CDE ne
    # les enregistre pas dans la session et ne les relance pas en double (une
    # copie de wmmemload restait alors avec son cadre sur le bureau).
    for c in wmclock wmcpuload wmmemload wmbattery xeyes stalonetray; do
        for w in $(xdotool search --classname "^$c\$" 2>/dev/null); do
            xprop -id "$w" WM_COMMAND 2>/dev/null | grep -q '{' &&
                xprop -id "$w" -remove WM_COMMAND
        done
    done
    sleep 5
done
