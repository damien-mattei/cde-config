/* closewin : choisir une fenetre a la souris et lui demander de se fermer.
 *
 * Fait la meme chose que "Close" du menu de fenetre de dtwm (WM_DELETE_WINDOW),
 * mais depuis le menu du bureau : le curseur devient une croix, un clic gauche
 * sur une fenetre la ferme, un clic droit ou Echap annule.
 * Contrairement a xkill, seule la fenetre choisie est fermee : les autres
 * fenetres du meme programme (tous les terminaux xfce4-terminal, par exemple)
 * restent ouvertes. Une fenetre qui ne sait pas se fermer ainsi n'est pas tuee.
 * Le Front Panel et les fenetres de dtwm sont ignores.
 *
 * Compilation : gcc -O -o ~/.dt/bin/closewin ~/.dt/src/closewin.c -lX11
 */
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/cursorfont.h>
#include <stdio.h>
#include <string.h>

static Atom WM_STATE, WM_PROTOCOLS, WM_DELETE_WINDOW;

static int has_wm_state(Display *d, Window w) {
    Atom type; int fmt; unsigned long n, after; unsigned char *data = NULL;
    int ok = XGetWindowProperty(d, w, WM_STATE, 0, 0, False, AnyPropertyType,
                                &type, &fmt, &n, &after, &data) == Success && type != None;
    if (data) XFree(data);
    return ok;
}

/* Fenetre de l'application sous le cadre de dtwm : la premiere qui a WM_STATE. */
static Window client_window(Display *d, Window w) {
    if (has_wm_state(d, w)) return w;
    Window root, parent, *kids = NULL; unsigned int n;
    if (!XQueryTree(d, w, &root, &parent, &kids, &n)) return None;
    Window found = None;
    for (unsigned int i = 0; i < n && found == None; i++)
        if (has_wm_state(d, kids[i])) found = kids[i];
    for (unsigned int i = 0; i < n && found == None; i++)
        found = client_window(d, kids[i]);
    if (kids) XFree(kids);
    return found;
}

static int supports_delete(Display *d, Window w) {
    Atom *protos; int n, ok = 0;
    if (XGetWMProtocols(d, w, &protos, &n)) {
        for (int i = 0; i < n; i++) if (protos[i] == WM_DELETE_WINDOW) ok = 1;
        XFree(protos);
    }
    return ok;
}

int main(void) {
    Display *d = XOpenDisplay(NULL);
    if (!d) { fprintf(stderr, "closewin : pas d'affichage X\n"); return 1; }
    Window root = DefaultRootWindow(d);
    WM_STATE = XInternAtom(d, "WM_STATE", False);
    WM_PROTOCOLS = XInternAtom(d, "WM_PROTOCOLS", False);
    WM_DELETE_WINDOW = XInternAtom(d, "WM_DELETE_WINDOW", False);

    Cursor cross = XCreateFontCursor(d, XC_crosshair);
    if (XGrabPointer(d, root, False, ButtonPressMask, GrabModeAsync, GrabModeAsync,
                     root, cross, CurrentTime) != GrabSuccess) {
        fprintf(stderr, "closewin : souris deja prise par un autre programme\n"); return 1;
    }
    XGrabKeyboard(d, root, False, GrabModeAsync, GrabModeAsync, CurrentTime);

    Window target = None; int cancel = 0;
    while (target == None && !cancel) {
        XEvent ev; XNextEvent(d, &ev);
        if (ev.type == ButtonPress) {
            if (ev.xbutton.button == Button1) target = ev.xbutton.subwindow;
            else cancel = 1;
            if (ev.xbutton.button == Button1 && target == None) cancel = 1;  /* clic sur le bureau */
        } else if (ev.type == KeyPress && XLookupKeysym(&ev.xkey, 0) == XK_Escape) {
            cancel = 1;
        }
    }
    XUngrabKeyboard(d, CurrentTime);
    XUngrabPointer(d, CurrentTime);
    XFlush(d);
    if (cancel) { XCloseDisplay(d); return 0; }

    Window w = client_window(d, target);
    if (w == None) { XCloseDisplay(d); return 0; }

    XClassHint ch;
    if (XGetClassHint(d, w, &ch)) {
        int is_dtwm = ch.res_class && strcmp(ch.res_class, "Dtwm") == 0;
        if (ch.res_name) XFree(ch.res_name);
        if (ch.res_class) XFree(ch.res_class);
        if (is_dtwm) { XCloseDisplay(d); return 0; }   /* Front Panel, sous-panneaux */
    }

    if (!supports_delete(d, w)) {
        fprintf(stderr, "closewin : cette fenetre ne sait pas se fermer ainsi, rien n'est fait\n");
        XCloseDisplay(d); return 2;
    }
    XEvent msg; memset(&msg, 0, sizeof msg);
    msg.xclient.type = ClientMessage;
    msg.xclient.window = w;
    msg.xclient.message_type = WM_PROTOCOLS;
    msg.xclient.format = 32;
    msg.xclient.data.l[0] = WM_DELETE_WINDOW;
    msg.xclient.data.l[1] = CurrentTime;
    XSendEvent(d, w, False, NoEventMask, &msg);
    XCloseDisplay(d);
    return 0;
}
