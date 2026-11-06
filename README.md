# cde-config

Configuration personnelle de **CDE** (Common Desktop Environment) sous Ubuntu : le
contenu de `~/.dt` avec un Front Panel modernisé mais fidèle au style CDE.

![Front Panel](doc/front-panel.png)

## Ce qu'il y a dedans

**Front Panel** (`types/*.fp`)
- Applets « dockapps » intégrés au panneau (contrôles `TYPE client`) : `wmclock`
  (un clic ouvre Google Agenda), `wmcpuload`, `wmmemload`, `wmbattery`, et `xeyes`.
- Une zone de notification `stalonetray` 3×2 dans le panneau (réseau, Bluetooth,
  presse-papiers, IBus, Psensor…).
- Boutons Firefox, HP-15C, Emacs, Gmail (dans Firefox), imprimante HP ; la corbeille
  CDE à l'extrême droite.

**Menus déroulants** (`types/fp_dynamic/*.fp`) : Nautilus, corbeille Nautilus,
répertoire d'applications, `xfce4-appfinder`, calendrier CDE, Dropbox (dans un
terminal qui affiche son état), réglages d'alimentation, mode présentation,
connexions réseau, extinction de l'écran, capture d'écran, qps, Psensor, gkrellm…

**Clavier** (`dtwmrc`, copie de `sys.dtwmrc` + liaisons)
- Volume, coupure du son et du micro → `volume.sh` (une seule bulle de notification,
  maximum 120 %).
- Luminosité → `brightness.sh` (logind `SetBrightness`, crans progressifs, jusqu'à
  l'écran éteint).
- Impr écran → `xfce4-screenshooter`.

**Scripts**
- `sessions/sessionetc` : lancé par CDE à l'ouverture de session ; démarre les applets,
  la zone de notification, `nm-applet`, `blueman-applet`, `xfce4-clipman`, Dropbox.
- `panel-applets-watch.sh` : après un « Restart workspace manager », réaffiche
  `wmcpuload`/`wmmemload` et relance `xeyes` (aussi après une sortie de veille).
- `wmmemload-panel.sh`, `tray-panel.sh`, `xclock-toggle.sh`, `presentation-toggle.sh`,
  `dropbox-*.sh`.

## Installation

1. Copier les fichiers dans `~/.dt` (en gardant une copie de l'ancien).
2. Remplacer `/home/mattei` par votre dossier personnel dans les fichiers qui le
   contiennent : `grep -rl /home/mattei ~/.dt`.
3. Clic droit sur le bureau → **Restart workspace manager**, puis fermer et rouvrir la
   session pour que `sessionetc` s'exécute.

Programmes utilisés (paquets Ubuntu) : `wmclock wmcpuload wmmemload wmbattery
x11-apps stalonetray network-manager-gnome blueman xfce4-clipman
xfce4-power-manager xfce4-screenshooter pavucontrol nautilus xdotool x11-utils
libnotify-bin papirus-icon-theme`.

## Astuces CDE apprises en route

- Plusieurs contrôles avec le même `POSITION_HINTS` sont rangés par **ordre
  alphabétique inverse** de leur nom (d'où `ZFirefoxPanel`, `GCpuLoad`…).
- Un contrôle `TYPE client` intègre une fenêtre X par la première chaîne de son
  `WM_CLASS` (`CLIENT_NAME`) ; pas de sous-menu sur un tel contrôle.
- **Pas d'apostrophe dans les commentaires de `dtwmrc`** : dtwm ignore alors
  silencieusement les liaisons qui suivent.
- dtwm ne peut réserver une touche que si aucun autre programme ne l'a déjà prise.
- `xeyes` doit être lancé avec `+present`, sinon son fond reste noir dans le panneau.

## Crédits

Les icônes ajoutées (`icons/*.pm`) sont pour la plupart converties depuis le thème
[Papirus](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme) (GPL-3.0).
Configuration réalisée avec l'aide de Claude (Anthropic).
