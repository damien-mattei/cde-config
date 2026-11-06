#!/bin/sh
# Lance dans le terminal : dropboxd, puis son etat a chaque changement,
# et un message clair s'il s'arrete ou plante.
"$HOME/.dropbox-dist/dropboxd" &
pid=$!
echo "$(date +%H:%M:%S)  Dropbox demarre (pid $pid)"
old=
while kill -0 $pid 2>/dev/null; do
    sleep 5
    st=$("$HOME/.dt/dropbox-status.py" 2>/dev/null)
    [ "$st" != "$old" ] && echo "$(date +%H:%M:%S)  $st" && old=$st
done
wait $pid; code=$?
echo
echo "$(date +%H:%M:%S)  *** Dropbox s'est arrete (code de sortie $code) ***"
echo "Journaux detailles : ~/.dropbox/logs"
