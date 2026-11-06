#!/usr/bin/python3 -I
# Affiche l'etat de Dropbox (ex. "A jour", "Synchronisation de 3 fichiers...")
# en interrogeant le Dropbox qui tourne par ~/.dropbox/command_socket.
import os, socket, sys
try:
    s = socket.socket(socket.AF_UNIX)
    s.settimeout(5)
    s.connect(os.path.expanduser("~/.dropbox/command_socket"))
    s.sendall(b"get_dropbox_status\ndone\n")
    data = b""
    while not data.endswith(b"done\n"):
        chunk = s.recv(4096)
        if not chunk:
            break
        data += chunk
except OSError:
    print("Dropbox ne repond pas")
    sys.exit(1)
lines = data.decode(errors="replace").splitlines()
status = [l.split("\t", 1)[1] for l in lines if l.startswith("status\t")]
print(" / ".join(status) or "Etat inconnu")
