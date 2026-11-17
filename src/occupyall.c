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

int main(int argc, char **argv) {
    if (argc != 2) { fprintf(stderr, "usage: %s <id fenetre>\n", argv[0]); return 2; }
    Display *d = XOpenDisplay(NULL);
    if (!d) { fprintf(stderr, "occupyall : pas d'affichage X\n"); return 1; }
    Window w = strtoul(argv[1], NULL, 0);
    DtWsmOccupyAllWorkspaces(d, w);
    XSync(d, False);
    XCloseDisplay(d);
    return 0;
}
