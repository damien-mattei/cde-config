#!/usr/bin/python3 -I
# Affiche l'etat de Dropbox (texte fourni par Dropbox, dans sa langue)
# en interrogeant le Dropbox qui tourne par ~/.dropbox/command_socket.
import os, socket, sys
lang = os.environ.get("DT_LANG") or os.environ.get("LC_ALL") or os.environ.get("LC_MESSAGES") or os.environ.get("LANG") or ""
def msg(fr, en):
    return fr if lang.startswith("fr") else en
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
    print(msg("Dropbox ne répond pas", "Dropbox is not responding"))
    sys.exit(1)
lines = data.decode(errors="replace").splitlines()
status = [l.split("\t", 1)[1] for l in lines if l.startswith("status\t")]
print(" / ".join(status) or msg("État inconnu", "Unknown status"))
