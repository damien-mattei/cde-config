#!/bin/sh
# Verrouille l ecran avec CDE (comme le cadenas du Front Panel).
# Appele par xfce4-power-manager avant une mise en veille, a la place de
# xfce4-screensaver :
#   xfconf-query -c xfce4-session -p /general/LockCommand -s /home/mattei/.dt/lock-cde.sh
# Ainsi un seul verrou (celui de CDE), meme si CDE avait deja verrouille l ecran.
/usr/dt/bin/dtaction LockDisplay >/dev/null 2>&1 &
sleep 1
exit 0
