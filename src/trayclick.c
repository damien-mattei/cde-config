/* trayclick : clic droit sur les icones de la zone de notification du Front Panel.
 *
 * dtwm prend le bouton 3 (avec toutes les touches de modification) sur le
 * controle qui contient stalonetray : un clic droit sur une icone ouvre le menu
 * du Front Panel ("Add Subpanel"...) au lieu du menu de l application.
 * trayclick prend le clic du milieu et Ctrl + clic gauche sur stalonetray et
 * envoie a la place un clic droit (XSendEvent) a l icone sous la souris.
 *
 * Marche avec les applications Qt (Telegram...). Les applets GTK 3 (nm-applet,
 * blueman...) ignorent les clics envoyes ainsi : utiliser leur clic gauche.
 *
 * Lance par sessions/sessionetc ; retrouve stalonetray s il est relance.
 * Compilation : gcc -O -o ~/.dt/bin/trayclick ~/.dt/src/trayclick.c -lX11
 */
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <string.h>
#include <unistd.h>

static int x_error(Display *d, XErrorEvent *e) { (void)d; (void)e; return 0; }

/* Fenetre dont le WM_CLASS (nom) est "stalonetray", cherchee dans tout l arbre. */
static Window find_tray(Display *d, Window w) {
    XClassHint ch;
    if (XGetClassHint(d, w, &ch)) {
        int ok = ch.res_name && strcmp(ch.res_name, "stalonetray") == 0;
        if (ch.res_name) XFree(ch.res_name);
        if (ch.res_class) XFree(ch.res_class);
        if (ok) return w;
    }
    Window root, parent, *kids = NULL; unsigned int n;
    if (!XQueryTree(d, w, &root, &parent, &kids, &n)) return None;
    Window found = None;
    for (unsigned int i = 0; i < n && found == None; i++) found = find_tray(d, kids[i]);
    if (kids) XFree(kids);
    return found;
}

/* Icone de l application : premier enfant du support de stalonetray. */
static Window icon_of(Display *d, Window holder) {
    Window root, parent, *kids = NULL; unsigned int n;
    if (!XQueryTree(d, holder, &root, &parent, &kids, &n) || n == 0) return None;
    Window w = kids[n - 1];
    XFree(kids);
    return w;
}

static void send_right_click(Display *d, Window w, XButtonEvent *src) {
    XWindowAttributes a;
    if (!XGetWindowAttributes(d, w, &a)) return;
    int x, y; Window child;
    XTranslateCoordinates(d, a.root, w, src->x_root, src->y_root, &x, &y, &child);
    XEvent e; memset(&e, 0, sizeof e);
    e.xbutton.type = ButtonPress;
    e.xbutton.window = w;
    e.xbutton.root = a.root;
    e.xbutton.time = src->time;
    e.xbutton.x = x; e.xbutton.y = y;
    e.xbutton.x_root = src->x_root; e.xbutton.y_root = src->y_root;
    e.xbutton.button = Button3;
    e.xbutton.same_screen = True;
    XSendEvent(d, w, True, ButtonPressMask, &e);
    e.xbutton.type = ButtonRelease;
    e.xbutton.state = Button3Mask;
    XSendEvent(d, w, True, ButtonReleaseMask, &e);
    XFlush(d);
}

int main(void) {
    Display *d = XOpenDisplay(NULL);
    if (!d) return 1;
    XSetErrorHandler(x_error);
    Window root = DefaultRootWindow(d);
    unsigned int locks[] = { 0, LockMask, Mod2Mask, LockMask | Mod2Mask };

    for (;;) {
        Window tray = find_tray(d, root);
        if (tray == None) { sleep(5); continue; }
        XSelectInput(d, tray, StructureNotifyMask);
        XGrabButton(d, Button2, AnyModifier, tray, False, ButtonPressMask | ButtonReleaseMask,
                    GrabModeAsync, GrabModeAsync, None, None);
        for (int i = 0; i < 4; i++)
            XGrabButton(d, Button1, ControlMask | locks[i], tray, False,
                        ButtonPressMask | ButtonReleaseMask, GrabModeAsync, GrabModeAsync, None, None);
        XSync(d, False);

        Window target = None; int gone = 0;
        while (!gone) {
            XEvent ev; XNextEvent(d, &ev);
            if (ev.type == DestroyNotify && ev.xdestroywindow.window == tray) gone = 1;
            else if (ev.type == ButtonPress && ev.xbutton.window == tray)
                target = ev.xbutton.subwindow != None ? icon_of(d, ev.xbutton.subwindow) : None;
            else if (ev.type == ButtonRelease && ev.xbutton.window == tray && target != None) {
                send_right_click(d, target, &ev.xbutton);   /* bouton relache : le menu peut prendre la souris */
                target = None;
            }
        }
        sleep(2);
    }
}
