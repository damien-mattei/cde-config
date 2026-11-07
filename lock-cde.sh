#!/bin/sh
# Verrouille l ecran avec CDE (comme le cadenas du Front Panel).
# Appele par lock-on-sleep.py avant chaque mise en veille, et par xflock4
# (xfconf xfce4-session /general/LockCommand).
# Prevu aussi pour xss-lock -l (descripteur $XSS_SLEEP_LOCK_FD ferme en sortant),
# mais xss-lock ne demarre pas sous CDE.
(
    [ -n "$XSS_SLEEP_LOCK_FD" ] && eval "exec $XSS_SLEEP_LOCK_FD<&-"
    exec /usr/dt/bin/dtaction LockDisplay >/dev/null 2>&1
) &
sleep 1
exit 0
