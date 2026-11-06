#!/bin/sh
# Zone de notification integree au Front Panel (controle Tray, ~/.dt/types/Tray.fp) :
# 3x2 emplacements de 28 px (84x56), fond couleur du panneau.
exec /usr/bin/stalonetray --icon-size 24 --slot-size 28 \
    --geometry 3x2 --max-geometry 3x2 --icon-gravity NW \
    --background '#C6B2A8' --decorations none --window-type normal \
    --window-strut none --skip-taskbar --kludges force_icons_size
