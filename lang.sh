# Langue des messages : francais si le systeme est en francais, anglais sinon.
# Charge par les scripts qui affichent quelque chose :  . "$HOME/.dt/lang.sh"
# puis :  msg "texte francais" "English text"
# Pour essayer une langue : DT_LANG=fr ou DT_LANG=en.
case ${DT_LANG:-${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}} in
    fr*) DT_FR=1 ;;
    *)   DT_FR= ;;
esac
msg() { if [ -n "$DT_FR" ]; then printf '%s' "$1"; else printf '%s' "$2"; fi; }
