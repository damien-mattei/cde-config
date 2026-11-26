#!/usr/bin/env bash
# Installeur du theme CDE (depot cde-config) dans ~/.dt.
# Usage : cde-config/install.sh [--dry-run]
# - ne contient aucun paquet : liste les manquants et propose apt ;
# - fusionne avec un ~/.dt existant, apres une sauvegarde complete ;
# - n installe une entree du Front Panel ou d un tiroir que si son programme
#   existe sur la machine ;
# - --dry-run : montre tout, ne modifie rien.
# Les messages sont en anglais (depot public), les commentaires en francais.

set -u
shopt -s nullglob

SRC=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
DEST="$HOME/.dt"
AUTHOR_HOME=/home/mattei          # chemin a remplacer dans les .dt et .fp
STAMP=$(date +%Y%m%d-%H%M%S)
DRY=0

for arg in "$@"; do
    case $arg in
        --dry-run) DRY=1 ;;
        -h|--help) echo "Usage: $0 [--dry-run]"; exit 0 ;;
        *) echo "Unknown option: $arg (usage: $0 [--dry-run])" >&2; exit 2 ;;
    esac
done

say()  { printf '%s\n' "$*"; }
step() { printf '\n== %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
# Execute la commande, ou l affiche seulement avec --dry-run.
run()  { if [ "$DRY" = 1 ]; then printf '  [dry-run] %s\n' "$*"; else "$@"; fi; }
# Question oui/non, "non" par defaut (aussi sans reponse possible).
ask() {
    [ "$DRY" = 1 ] && { say "$1 [y/N] (dry-run: not asked)"; return 1; }
    local a=
    printf '%s [y/N] ' "$1"; read -r a || { echo; return 1; }
    case $a in [yY]|[yY][eE][sS]|[oO]|[oO][uU][iI]) return 0 ;; *) return 1 ;; esac
}
has() { command -v "$1" >/dev/null 2>&1; }

# --- 1. Controles --------------------------------------------------------
step "Checks"
[ "$(id -u)" -ne 0 ] || die "do not run this as root: it installs into your own home."
[ -x /usr/dt/bin/dtsession ] || die "CDE not found (/usr/dt/bin/dtsession). Install CDE first."
[ -d "$SRC/types" ] && [ -f "$SRC/sessions/sessionetc" ] || die "run this script from a clone of cde-config."
[ "$SRC" != "$(cd "$DEST" 2>/dev/null && pwd -P)" ] || die "the source is $DEST itself; clone the repository elsewhere."
say "CDE found. Installing from $SRC into $DEST"

# --- 2. Paquets ----------------------------------------------------------
step "Packages"
missing=()
need() { missing+=("$1"); }
for pair in \
    wmclock:wmclock wmcpuload:wmcpuload wmmemload:wmmemload wmbattery:wmbattery \
    xeyes:x11-apps xclock:x11-apps stalonetray:stalonetray nm-applet:network-manager-gnome \
    blueman-applet:blueman xfce4-clipman:xfce4-clipman \
    xfce4-power-manager:xfce4-power-manager xfconf-query:xfconf \
    xfce4-screenshooter:xfce4-screenshooter xfce4-appfinder:xfce4-appfinder \
    xfce4-terminal:xfce4-terminal pavucontrol:pavucontrol pactl:pulseaudio-utils \
    pw-play:pipewire-bin speaker-test:alsa-utils nautilus:nautilus xdotool:xdotool \
    xprop:x11-utils xwininfo:x11-utils xev:x11-utils xrdb:x11-xserver-utils \
    xset:x11-xserver-utils notify-send:libnotify-bin gcc:gcc
do
    has "${pair%%:*}" || need "${pair#*:}"
done
[ -f /usr/include/X11/Xlib.h ] || need libx11-dev
[ -f /usr/include/Xm/Xm.h ] || need libmotif-dev
/usr/bin/python3 -c 'import gi' 2>/dev/null || need python3-gi

if [ ${#missing[@]} -eq 0 ]; then
    say "All packages are present."
else
    mapfile -t missing < <(printf '%s\n' "${missing[@]}" | sort -u)
    say "Missing packages: ${missing[*]}"
    if ! has apt-get; then
        warn "no apt on this system: install the equivalent packages yourself."
    elif ask "Install them with 'sudo apt install'?"; then
        sudo apt-get install "${missing[@]}" || warn "apt failed; continuing."
    else
        say "Not installed. Later: sudo apt install ${missing[*]}"
        say "Entries whose program is missing will be skipped."
    fi
fi

# --- 3. Sauvegarde -------------------------------------------------------
step "Backup"
BACKUP=
if [ -e "$DEST" ]; then
    BACKUP="$DEST.backup-$STAMP"
    run cp -a "$DEST" "$BACKUP" || die "backup failed, nothing installed."
    say "Your current $DEST is saved in $BACKUP"
    for f in dtwmrc sessions/sessionetc; do
        [ -f "$DEST/$f" ] && ! cmp -s "$DEST/$f" "$SRC/$f" &&
            warn "your $f will be replaced (old one in the backup: merge it by hand if needed)."
    done
else
    say "No existing $DEST."
fi

# --- 4. Quels programmes sont disponibles ? ------------------------------
# Nom d action -> EXEC_STRING, lu dans les .dt du depot.
declare -A EXEC
while IFS=$'\t' read -r name cmd; do EXEC[$name]=$cmd; done < <(
    awk '$1=="ACTION"{a=$2}
         $1=="EXEC_STRING"{sub(/^[ \t]*EXEC_STRING[ \t]+/,""); print a "\t" $0}' "$SRC"/types/*.dt)

localize() { printf '%s' "${1//$AUTHOR_HOME/$HOME}"; }

# Chemin du programme d une action : celui prevu, sinon le meme nom dans le PATH.
program_path() {
    local p=$1
    [ -x "$p" ] && { printf '%s' "$p"; return 0; }
    command -v "$(basename "$p")" 2>/dev/null
}

# Vrai si l action peut marcher ici. Les actions absentes du depot sont celles
# de CDE : toujours disponibles.
action_ok() {
    local name=$1 cmd prog
    [ -n "${EXEC[$name]+x}" ] || return 0
    cmd=$(localize "${EXEC[$name]}")
    prog=${cmd%% *}
    case $name in
        ScreenOff)        has xset; return ;;
        DropboxTerm)      [ -x "$HOME/.dropbox-dist/dropboxd" ] && has xfce4-terminal; return ;;
        PresentationMode) has xfconf-query && has xfce4-power-manager; return ;;
        XClock)           has xclock; return ;;
    esac
    case $prog in
        # pas "flatpak info" : il cree des dossiers dans le home au passage
        flatpak) has flatpak && { [ -d "/var/lib/flatpak/app/${cmd##* }" ] ||
                     [ -d "$HOME/.local/share/flatpak/app/${cmd##* }" ]; } ;;
        *)       program_path "$prog" >/dev/null ;;
    esac
}

field() { awk -v k="$2" '$1==k{print $2; exit}' "$1"; }

# Vrai si le controle ou l entree decrit par ce .fp doit etre installe.
fp_ok() {
    local f=$1 client push file
    client=$(field "$f" CLIENT_NAME)
    push=$(field "$f" PUSH_ACTION)
    file=$(field "$f" FILE_NAME)
    [ -n "$client" ] && { has "$client"; return; }
    case $file in
        "$AUTHOR_HOME"/*) action_ok "$(basename "$file")"; return ;;
        /usr/*)           [ -e "$file" ]; return ;;
    esac
    case $push in
        PrinterManagerHP) has system-config-printer; return ;;
        "") return 0 ;;
        *)  action_ok "$push" ;;
    esac
}

# --- 5. Copie ------------------------------------------------------------
step "Copying files"
skipped=()
copied=0
actionfiles=()
while IFS= read -r -d '' src; do
    rel=${src#"$SRC"/}
    case $rel in
        *.fp)
            if ! fp_ok "$src"; then skipped+=("$rel"); continue; fi
            file=$(field "$src" FILE_NAME)
            case $file in "$AUTHOR_HOME"/*) actionfiles+=("$(localize "$file")") ;; esac
            ;;
    esac
    if [ "$DRY" = 0 ]; then
        mkdir -p "$DEST/$(dirname "$rel")" && cp -p "$src" "$DEST/$rel" || die "cannot copy $rel"
        case $rel in
            *.dt|*.fp)
                esc=${HOME//\\/\\\\}; esc=${esc//&/\\&}; esc=${esc//|/\\|}
                sed -i "s|$AUTHOR_HOME|$esc|g" "$DEST/$rel" ;;
        esac
    fi
    copied=$((copied + 1))
done < <(find "$SRC" -type f \
    ! -path "$SRC/.git/*" ! -path "$SRC/doc/*" ! -path "$SRC/bin/*" \
    ! -name README.md ! -name .gitignore ! -name install.sh ! -name '*~' -print0)
say "$copied files$([ "$DRY" = 1 ] && echo ' would be') installed."
if [ ${#skipped[@]} -gt 0 ]; then
    say "Skipped (program not found on this machine):"
    printf '  %s\n' "${skipped[@]}" | sort
fi

# Programmes installes ailleurs que chez l auteur (snap contre apt, etc.).
for name in "${!EXEC[@]}"; do
    prog=${EXEC[$name]%% *}
    case $prog in "$AUTHOR_HOME"/*|[!/]*) continue ;; esac
    [ -x "$prog" ] && continue
    found=$(command -v "$(basename "$prog")" 2>/dev/null) || continue
    say "Action $name: $prog not found, using $found"
    for dt in "$DEST"/types/*.dt; do
        grep -q "EXEC_STRING[[:space:]]*$prog" "$dt" &&
            run sed -i "s|\(EXEC_STRING[[:space:]]*\)$prog|\1$found|" "$dt"
    done
done

# --- 6. Fichiers d action des tiroirs -----------------------------------
# Une entree de type "file" pointe vers un petit fichier executable portant le
# nom de l action ; son contenu ne compte pas.
step "Action files used by the subpanels"
if [ ${#actionfiles[@]} -eq 0 ]; then say "None needed."; fi
for f in "${actionfiles[@]}"; do
    if [ -e "$f" ]; then say "Kept existing $f"; continue; fi
    say "Create $f"
    [ "$DRY" = 1 ] && continue
    cat >"$f" <<'EOF'
#!/bin/sh
# CDE action file: the file name selects the action of the same name
# (see ~/.dt/types/*.dt). Its contents are not used.
echo "Common Desktop Environment Dt action"
EOF
    chmod +x "$f"
done

# --- 7. Outils en C ------------------------------------------------------
step "Compiling the small tools"
run mkdir -p "$DEST/bin"
build() {   # $1 = nom, le reste = options de gcc
    local name=$1; shift
    run gcc -O -o "$DEST/bin/$name" "$DEST/src/$name.c" "$@" ||
        warn "could not build $name (see the packages above)."
}
if has gcc || [ "$DRY" = 1 ]; then
    build setbg -lX11
    build closewin -lX11
    build occupyall -I/usr/dt/include -L/usr/dt/lib -Wl,-rpath,/usr/dt/lib \
        -lDtSvc -ltt -lDtXinerama -lXm -lXt -lX11
else
    warn "gcc is missing: tools not built."
fi

# --- 8. Alimentation et verrou -------------------------------------------
step "Power saving and screen lock"
if has xfconf-query; then
    say "CDE should be the only screen locker. This changes three Xfce settings"
    say "(they also apply to your Xfce sessions)."
    if ask "Apply them?"; then
        run xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/lock-screen-suspend-hibernate -n -t bool -s false
        run xfconf-query -c xfce4-screensaver -p /lock/sleep-activation -n -t bool -s false
        run xfconf-query -c xfce4-session -p /general/LockCommand -n -t string -s "$DEST/lock-cde.sh"
        say "To undo:"
        say "  xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/lock-screen-suspend-hibernate -s true"
        say "  xfconf-query -c xfce4-screensaver -p /lock/sleep-activation -s true"
        say "  xfconf-query -c xfce4-session -p /general/LockCommand -r"
    else
        say "Not changed (see the README, Power saving section)."
    fi
else
    say "xfconf-query not found: nothing to set."
fi

# --- 9. Fin ---------------------------------------------------------------
step "Done"
[ "$DRY" = 1 ] && { say "Dry run: nothing was changed."; exit 0; }
say "1. Right-click the desktop -> Restart Workspace Manager."
say "2. Log out and back in so that sessions/sessionetc starts the applets."
if [ -n "$BACKUP" ]; then
    say "To go back: mv \"$DEST\" \"$DEST.theme\" && mv \"$BACKUP\" \"$DEST\""
else
    say "To remove: delete $DEST"
fi
