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

# Zone de notification (tray-panel.sh) : la garder dans le coin en bas a droite
# du bureau quand sa taille change (ecran HDMI branche ou debranche).
tray_root=
tray_corner() {
    r=$(xwininfo -root 2>/dev/null | awk '/^  Width/{w=$2}/^  Height/{h=$2}END{print w"x"h}')
    [ "$r" = "$tray_root" ] && return
    t=$(xdotool search --classname '^stalonetray$' 2>/dev/null | head -1)
    [ -n "$t" ] || return
    eval "$(xdotool getwindowgeometry --shell "$t")"   # WIDTH HEIGHT
    xdotool windowmove "$t" $(( ${r%x*} - WIDTH )) $(( ${r#*x} - HEIGHT ))
    tray_root=$r
}
# La zone de notification est mise sur tous les bureaux au lancement (occupyall) :
# si on ajoute des bureaux ensuite, elle n y est pas. Le Front Panel est present sur
# tous les bureaux, on compare avec lui et on refait occupyall si besoin.
tray_workspaces() {
    t=$(xdotool search --classname '^stalonetray$' 2>/dev/null | head -1)
    [ -n "$t" ] || return
    f=$(xwininfo -root -tree 2>/dev/null | awk '/"FrontPanel"/{print $1; exit}')
    [ -n "$f" ] || return
    nt=$(xprop -id "$t" _DT_WORKSPACE_PRESENCE 2>/dev/null | tr ',' '\n' | wc -l)
    nf=$(xprop -id "$f" _DT_WORKSPACE_PRESENCE 2>/dev/null | tr ',' '\n' | wc -l)
    [ "$nf" -gt "$nt" ] && "$HOME/.dt/bin/occupyall" "$t"
}
xeyes_down=0
health_day=     # jour de la derniere mesure pour health.sh
last=$(date +%s)
while xprop -root _NET_SUPPORTED >/dev/null 2>&1 || xdpyinfo >/dev/null 2>&1; do
    # Sortie de veille : l'horloge a fait un bond bien plus grand que la pause de 5 s.
    now=$(date +%s)
    if [ $((now - last)) -gt 30 ]; then
        sleep 20   # laisse l'affichage se retablir (a 7 s, xeyes restait noir)
        xeyes_relaunch
    fi
    last=$now
    # Une mesure par jour pour l historique de health.sh (detection des fuites)
    d=$(date +%F)
    if [ "$d" != "$health_day" ]; then health_day=$d; "$HOME/.dt/health.sh" --record & fi
    tray_corner
    tray_workspaces
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
    # Apres un changement du nombre de bureaux (ou du panneau), dtwm retire parfois
    # le calendrier et la batterie du panneau : les remettre (comme ci-dessus).
    for c in wmclock wmbattery; do
        for w in $(xdotool search --classname "^$c\$" 2>/dev/null); do
            xwininfo -id "$w" 2>/dev/null | grep -q 'IsUnMapped' && xdotool windowmap "$w"
        done
    done
    # xeyes demappe de la meme facon : le relancer s il reste ainsi 2 passages (10 s),
    # le temps que dtwm l integre apres un lancement normal.
    if xdotool search --classname '^xeyes$' 2>/dev/null | head -1 | xargs -r xwininfo -id 2>/dev/null | grep -q 'IsUnMapped'; then
        xeyes_down=$((xeyes_down + 1))
        if [ "$xeyes_down" -ge 2 ]; then xeyes_down=0; xeyes_relaunch; fi
    else
        xeyes_down=0
    fi
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
