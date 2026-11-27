/* setbg <id fenetre> <couleur> : donne une couleur de fond a une fenetre X
 * existante, pour que le serveur X repeigne lui-meme le fond quand la fenetre
 * est decouverte (xeyes ne le fait pas). */
#include <X11/Xlib.h>
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
    if (argc != 3) { fprintf(stderr, tr_("usage: %s <id fenetre> <couleur>\n", "usage: %s <window id> <colour>\n"), argv[0]); return 2; }
    Display *d = XOpenDisplay(NULL);
    if (!d) { fputs(tr_("pas d'affichage X\n", "cannot open the X display\n"), stderr); return 1; }
    Window w = strtoul(argv[1], NULL, 0);
    XColor c;
    if (!XParseColor(d, DefaultColormap(d, DefaultScreen(d)), argv[2], &c) ||
        !XAllocColor(d, DefaultColormap(d, DefaultScreen(d)), &c)) {
        fprintf(stderr, tr_("couleur inconnue : %s\n", "unknown colour: %s\n"), argv[2]); return 1;
    }
    XSetWindowBackground(d, w, c.pixel);
    XClearArea(d, w, 0, 0, 0, 0, True);   /* repeint le fond et demande un redessin */
    XCloseDisplay(d);
    return 0;
}
