/* setbg <id fenetre> <couleur> : donne une couleur de fond a une fenetre X
 * existante, pour que le serveur X repeigne lui-meme le fond quand la fenetre
 * est decouverte (xeyes ne le fait pas). */
#include <X11/Xlib.h>
#include <stdio.h>
#include <stdlib.h>
int main(int argc, char **argv) {
    if (argc != 3) { fprintf(stderr, "usage: %s <window id> <colour>\n", argv[0]); return 2; }
    Display *d = XOpenDisplay(NULL);
    if (!d) { fprintf(stderr, "cannot open the X display\n"); return 1; }
    Window w = strtoul(argv[1], NULL, 0);
    XColor c;
    if (!XParseColor(d, DefaultColormap(d, DefaultScreen(d)), argv[2], &c) ||
        !XAllocColor(d, DefaultColormap(d, DefaultScreen(d)), &c)) {
        fprintf(stderr, "unknown colour: %s\n", argv[2]); return 1;
    }
    XSetWindowBackground(d, w, c.pixel);
    XClearArea(d, w, 0, 0, 0, 0, True);   /* repeint le fond et demande un redessin */
    XCloseDisplay(d);
    return 0;
}
