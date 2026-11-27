#!/bin/sh
# Lance dans le terminal : dropboxd, puis son etat a chaque changement,
# et un message clair s'il s'arrete ou plante.
. "$HOME/.dt/lang.sh"
"$HOME/.dropbox-dist/dropboxd" &
pid=$!
echo "$(date +%H:%M:%S)  $(msg "Dropbox démarré" "Dropbox started") (pid $pid)"
old=
while kill -0 $pid 2>/dev/null; do
    sleep 5
    st=$("$HOME/.dt/dropbox-status.py" 2>/dev/null)
    [ "$st" != "$old" ] && echo "$(date +%H:%M:%S)  $st" && old=$st
done
wait $pid; code=$?
echo
echo "$(date +%H:%M:%S)  *** $(msg "Dropbox s'est arrêté (code de sortie $code)" "Dropbox stopped (exit code $code)") ***"
echo "$(msg "Journaux détaillés" "Detailed logs"): ~/.dropbox/logs"
