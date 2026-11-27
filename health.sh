#!/usr/bin/env bash
# Faut-il redemarrer ? Mesure la machine et la session CDE et dit s il vaut mieux
# relancer un programme, la session ou la machine, avec les raisons.
# La duree de fonctionnement n est pas un critere.
#
# Usage : health.sh            rapport (bouton "System Health", tiroir Style)
#         health.sh --record   ajoute la mesure du jour a l historique
#                              (appele par panel-applets-watch.sh)
# Les seuils sont des regles d experience ; ils se changent par variables
# d environnement (utile aussi pour les essais).

: "${HEALTH_REBOOT_FILE:=/var/run/reboot-required}"
: "${HEALTH_DIR:=${XDG_STATE_HOME:-$HOME/.local/state}}"
: "${MEM_MIN_PCT:=10}"      # memoire disponible, en % de la RAM
: "${SWAP_MAX_PCT:=75}"
: "${DISK_MAX_PCT:=90}"
: "${PSI_MAX:=10}"          # % de temps d attente, moyenne sur 5 min
: "${BIG_PCT:=25}"          # un programme seul au-dela de ce % de la RAM
: "${XORG_MAX_MB:=1000}"
: "${DTWM_MAX_MB:=150}"
: "${DTSESSION_MAX_MB:=150}"
: "${TTSESSION_MAX_MB:=100}"
: "${FD_MAX:=800}"
: "${XCLIENTS_MAX:=200}"    # le serveur X en accepte 256 par defaut
HISTORY="$HEALTH_DIR/cde-health.csv"
export LC_NUMERIC=C

# --- Mesures ---------------------------------------------------------------
meminfo() { awk -v k="$1:" '$1==k{print int($2/1024)}' /proc/meminfo; }
mem_total=$(meminfo MemTotal)
mem_avail=$(meminfo MemAvailable)
swap_total=$(meminfo SwapTotal)
swap_used=$((swap_total - $(meminfo SwapFree)))

pid_of() { pgrep -u "$(id -u)" -x "$1" | head -1; }
rss_mb() { [ -n "$1" ] && awk '/^VmRSS/{print int($2/1024)}' "/proc/$1/status" 2>/dev/null; }
nfd()    { [ -n "$1" ] && [ -r "/proc/$1/fd" ] && ls "/proc/$1/fd" 2>/dev/null | wc -l; }

xorg=$(pgrep -x Xorg | head -1); dtwm=$(pid_of dtwm)
dtsession=$(pid_of dtsession);   ttsession=$(pid_of ttsession)
rss_xorg=$(rss_mb "$xorg");      rss_dtwm=$(rss_mb "$dtwm")
rss_dtsession=$(rss_mb "$dtsession"); rss_ttsession=$(rss_mb "$ttsession")
fd_xorg=$(nfd "$xorg")
xclients=$(xlsclients 2>/dev/null | wc -l)
boot=$(cut -c1-8 /proc/sys/kernel/random/boot_id)
# La session est identifiee par le demarrage et le numero de dtsession.
session="$boot-${dtsession:-0}"
up_days=$(awk '{printf "%d", $1/86400}' /proc/uptime)
today=$(date +%F)

record() {
    mkdir -p "$HEALTH_DIR" || return
    [ -f "$HISTORY" ] || echo "date,session,uptime_d,mem_avail,swap,xorg,dtwm,dtsession,ttsession,fd_xorg,x_clients" >"$HISTORY"
    # une seule mesure par jour et par session
    grep -q "^$today,$session," "$HISTORY" && return
    echo "$today,$session,$up_days,$mem_avail,$swap_used,$rss_xorg,$rss_dtwm,$rss_dtsession,$rss_ttsession,$fd_xorg,$xclients" >>"$HISTORY"
}
if [ "${1:-}" = --record ]; then record; exit 0; fi

# --- Jugement ----------------------------------------------------------------
level=0                     # 0 bon, 1 programme, 2 session, 3 machine
machine=(); sess=(); prog=()
reason_machine() { machine+=("$1"); [ $level -lt 3 ] && level=3; }
reason_session() { sess+=("$1");    [ $level -lt 2 ] && level=2; }
reason_program() { prog+=("$1");    [ $level -lt 1 ] && level=1; }
over() { awk -v a="$1" -v b="$2" 'BEGIN{exit !(a > b)}'; }

# Machine
klog=$(journalctl -k -b --no-pager -o cat 2>/dev/null)
count() { printf '%s\n' "$klog" | grep -ciE "$1"; }
oom=$(count 'out of memory: killed')
[ "$oom" -gt 0 ] && reason_machine "$oom process(es) killed for lack of memory since boot"
serious=$(count 'kernel BUG at|Oops:|I/O error|GPU HANG|nvme.*(I/O.*timeout|controller is down)|soft lockup|hard LOCKUP')
[ "$serious" -gt 0 ] && reason_machine "$serious serious kernel error(s) (journalctl -k -b -p err)"
wifi=$(count 'Start IWL Error Log Dump')
d1=$(ps -eo pid=,stat= | awk '$2 ~ /^D/{print $1}'); sleep 3
d2=$(ps -eo pid=,stat= | awk '$2 ~ /^D/{print $1}')
stuck=$(comm -12 <(sort <<<"$d1") <(sort <<<"$d2") | grep -c .)
[ "$stuck" -gt 0 ] && reason_machine "$stuck process(es) stuck (D state)"
for r in memory io; do
    v=$(awk '$1=="some"{split($4,a,"="); print a[2]}' /proc/pressure/$r 2>/dev/null)
    over "${v:-0}" "$PSI_MAX" && reason_program "waiting on $([ $r = io ] && echo disk I/O || echo memory) $v % of the time"
done
mem_pct=$((mem_avail * 100 / mem_total))
[ "$mem_pct" -lt "$MEM_MIN_PCT" ] && reason_program "only $mem_pct % of memory available"
swap_pct=0; [ "$swap_total" -gt 0 ] && swap_pct=$((swap_used * 100 / swap_total))
[ "$swap_pct" -gt "$SWAP_MAX_PCT" ] && reason_program "swap $swap_pct % used"
disks=$(df -P / "$HOME" /tmp 2>/dev/null | awk 'NR>1 && !seen[$6]++{sub(/%/,"",$5); print $5, $6}')
while read -r pct mnt; do
    [ "$pct" -gt "$DISK_MAX_PCT" ] && reason_program "disk $mnt is $pct % full (free some space)"
done <<<"$disks"

# Session CDE
too_big() {  # $1 = nom, $2 = Mo, $3 = seuil
    [ -n "$2" ] && [ "$2" -gt "$3" ] && reason_session "$1 uses $2 MB (threshold $3)"
}
too_big Xorg "$rss_xorg" "$XORG_MAX_MB"
too_big dtwm "$rss_dtwm" "$DTWM_MAX_MB"
too_big dtsession "$rss_dtsession" "$DTSESSION_MAX_MB"
too_big ttsession "$rss_ttsession" "$TTSESSION_MAX_MB"
[ -n "$fd_xorg" ] && [ "$fd_xorg" -gt "$FD_MAX" ] && reason_session "Xorg has $fd_xorg open files"
[ "$xclients" -gt "$XCLIENTS_MAX" ] && reason_session "$xclients X clients (limit 256)"

# Fuites : comparaison avec la premiere mesure de cette session
first=$(grep -m1 ",$session," "$HISTORY" 2>/dev/null)
growth=()
if [ -n "$first" ]; then
    IFS=, read -r f_date _ _ _ _ f_xorg f_dtwm f_dtsession f_ttsession _ _ <<<"$first"
    grown() {  # double et +50 Mo depuis la premiere mesure
        [ -n "$2" ] && [ -n "$3" ] && [ "$2" -gt $((2 * $3)) ] && [ $(($2 - $3)) -gt 50 ] &&
            reason_session "$1 grew from $3 to $2 MB since $f_date (leak?)"
        [ -n "$3" ] && growth+=("$1 $3 -> $2 MB")
    }
    if [ "$f_date" != "$today" ]; then
        grown Xorg "$rss_xorg" "$f_xorg"
        grown dtwm "$rss_dtwm" "$f_dtwm"
        grown dtsession "$rss_dtsession" "$f_dtsession"
        grown ttsession "$rss_ttsession" "$f_ttsession"
    fi
fi
record

# Programmes les plus gourmands (processus de meme nom additionnes)
top=$(ps -eo rss=,comm= | awk '{r=$1; $1=""; sub(/^ /,""); sum[$0]+=r}
    END{for (n in sum) printf "%d\t%s\n", sum[n]/1024, n}' | sort -rn | head -4)
while IFS=$'\t' read -r mb name; do
    [ $((mb * 100 / mem_total)) -gt "$BIG_PCT" ] &&
        reason_program "$name uses $((mb * 100 / mem_total)) % of memory: restart it"
done <<<"$top"

# --- Rapport -----------------------------------------------------------------
if [ -t 1 ]; then B=$'\e[1m' G=$'\e[32m' Y=$'\e[33m' R=$'\e[31m' N=$'\e[0m'; else B= G= Y= R= N=; fi
list() { local x; for x in "$@"; do printf '  - %s\n' "$x"; done; }

echo "${B}System health${N}  (up $up_days day(s))"
echo
case $level in
    0) echo "${G}${B}ALL IS WELL${N}: nothing to restart." ;;
    1) echo "${Y}${B}WATCH ONE PROGRAM${N}: no need to reboot." ;;
    2) echo "${Y}${B}RESTART THE CDE SESSION${N} (try Restart Workspace Manager first)." ;;
    3) echo "${R}${B}REBOOT THE MACHINE${N} is advised." ;;
esac
[ ${#machine[@]} -gt 0 ] && { echo; echo "Machine:"; list "${machine[@]}"; }
[ ${#sess[@]} -gt 0 ]    && { echo; echo "Session:"; list "${sess[@]}"; }
[ ${#prog[@]} -gt 0 ]    && { echo; echo "Programs and resources:"; list "${prog[@]}"; }

if [ -f "$HEALTH_REBOOT_FILE" ]; then
    pkgs=$(sort -u "$HEALTH_REBOOT_FILE.pkgs" 2>/dev/null | paste -sd' ')
    echo
    echo "${Y}Updates waiting for a reboot${N} (security, not urgent):"
    echo "  ${pkgs:-see $HEALTH_REBOOT_FILE}"
fi
[ "$wifi" -gt 0 ] && { echo; echo "Note: $wifi Wi-Fi firmware crash(es) (iwlwifi) since boot."; }

echo
echo "${B}Measurements${N}"
echo "  available memory: $mem_avail MB of $mem_total ($mem_pct %), swap: $swap_used MB ($swap_pct %)"
echo "  disks: $(awk '{printf "%s %s%%  ", $2, $1}' <<<"$disks")"
echo "  CDE: Xorg ${rss_xorg:-?} MB, dtwm ${rss_dtwm:-?}, dtsession ${rss_dtsession:-?}, ttsession ${rss_ttsession:-?}; $xclients X clients"
if [ ${#growth[@]} -gt 0 ]; then
    echo "  since $f_date: $(printf '%s; ' "${growth[@]}")"
else
    echo "  history: no older measurement for this session yet"
fi
echo "  largest programs:"
awk -F'\t' '{printf "    %6d MB  %s\n", $1, $2}' <<<"$top"
