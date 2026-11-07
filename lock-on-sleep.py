#!/usr/bin/python3 -I
# Verrouille l ecran avec CDE juste avant chaque mise en veille
# (capot, bouton, inactivite, menu...), quel que soit le programme qui la demande.
#
# Comme xfce4-screensaver : on prend un verrou "delay" de logind, qui retarde la
# veille ; au signal PrepareForSleep(true) on lance le verrou de CDE
# (lock-cde.sh), puis on rend le verrou pour que la veille continue.
# Lance par sessions/sessionetc.
import os, subprocess
from gi.repository import Gio, GLib

LOCK = os.path.expanduser("~/.dt/lock-cde.sh")
bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
fd = None

def inhibit():
    global fd
    if fd is not None:
        return
    res, fds = bus.call_with_unix_fd_list_sync(
        "org.freedesktop.login1", "/org/freedesktop/login1",
        "org.freedesktop.login1.Manager", "Inhibit",
        GLib.Variant("(ssss)", ("sleep", "CDE lock", "Verrouiller CDE avant la veille", "delay")),
        GLib.VariantType("(h)"), Gio.DBusCallFlags.NONE, -1, None, None)
    fd = fds.get(res.unpack()[0])

def release():
    global fd
    if fd is not None:
        os.close(fd)
        fd = None

def on_signal(conn, sender, path, iface, signal, params):
    if params.unpack()[0]:           # avant la veille
        subprocess.run([LOCK])       # lance dtaction puis attend 1 s
        release()
    else:                            # au reveil
        inhibit()

bus.signal_subscribe("org.freedesktop.login1", "org.freedesktop.login1.Manager",
                     "PrepareForSleep", "/org/freedesktop/login1", None,
                     Gio.DBusSignalFlags.NONE, on_signal)
inhibit()
GLib.MainLoop().run()
