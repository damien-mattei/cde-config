/* occupyall <id fenetre> : met une fenetre sur tous les bureaux virtuels de CDE
 * (comme "Occupy All Workspaces" du menu de fenetre de dtwm).
 * dtwm ignore la demande standard EWMH (_NET_WM_DESKTOP, option --sticky de
 * stalonetray) : on passe par l API de CDE.
 *
 * Compilation :
 *   gcc -O -o ~/.dt/bin/occupyall ~/.dt/src/occupyall.c -I/usr/dt/include \
 *       -L/usr/dt/lib -Wl,-rpath,/usr/dt/lib -lDtSvc -ltt -lDtXinerama -lXm -lXt -lX11
 */
#include <X11/Xlib.h>
#include <Dt/Wsm.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Message en francais si le systeme est en francais, en anglais sinon. */
static const char *tr_(const char *fr, const char *en) {
    const char *l = getenv("LC_ALL");
    if (!l || !*l) l = getenv("LC_MESSAGES");
    if (!l || !*l) l = getenv("LANG");
    return l && strncmp(l, "fr", 2) == 0 ? fr : en;
}

int main(int argc, char **argv) {
    if (argc != 2) { fprintf(stderr, tr_("usage: %s <id fenetre>\n", "usage: %s <window id>\n"), argv[0]); return 2; }
    Display *d = XOpenDisplay(NULL);
    if (!d) { fputs(tr_("occupyall : pas d'affichage X\n", "occupyall: cannot open the X display\n"), stderr); return 1; }
    Window w = strtoul(argv[1], NULL, 0);
    DtWsmOccupyAllWorkspaces(d, w);
    XSync(d, False);
    XCloseDisplay(d);
    return 0;
}
