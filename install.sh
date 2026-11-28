#!/bin/bash

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HYPR_DIR="$HOME/.config/hypr"
CONFIG="$HYPR_DIR/hyprland.lua"
SOURCE="$REPO/hypr/aresta.lua"
TARGET="$HYPR_DIR/aresta.lua"
REQUIRE='require("hypr.aresta")'
TOGGLES='require("default.hypr.toggles")'
BACKUP_DIR="${ARESTA_BACKUP_DIR:-${TMPDIR:-/tmp}/aresta}"
PLUGIN_ID="$(jq -r .id "$REPO/manifest.json")"
PLUGIN_LINK="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
MENU_ID="$(jq -r .id "$REPO/menu/manifest.json")"
MENU_LINK="$HOME/.config/omarchy/plugins/$MENU_ID"
SWITCHER_ID="$(jq -r .id "$REPO/switcher/manifest.json")"
SWITCHER_LINK="$HOME/.config/omarchy/plugins/$SWITCHER_ID"
CONTROL_CENTER_ID="$(jq -r .id "$REPO/control-center/manifest.json")"
CONTROL_CENTER_LINK="$HOME/.config/omarchy/plugins/$CONTROL_CENTER_ID"
DOCK_ID="$(jq -r .id "$REPO/dock/manifest.json")"
DOCK_LINK="$HOME/.config/omarchy/plugins/$DOCK_ID"
OLD_DOCK_ID="io.github.rafabertholdo.macos-dock"
SHELL_CONFIG="$HOME/.config/omarchy/shell.json"
THEMES_DIR="$HOME/.config/omarchy/themes"
HOOK_SOURCE="$REPO/hooks/aresta-wallpaper"
HOOK_LINK="$HOME/.config/omarchy/hooks/theme-set.d/aresta-wallpaper"
LAST_THEME_FILE="$HOME/.local/state/omarchy/aresta-last-theme"
APP_BIN="$HOME/.local/bin/aresta-settings"
APP_DESKTOP="$HOME/.local/share/applications/aresta-settings.desktop"
ICON_THEME="$HOME/.local/share/icons/hicolor"
APP_ICON="$ICON_THEME/scalable/apps/$PLUGIN_ID.svg"
UNIT_DIR="$HOME/.config/systemd/user"

say() { echo -e "\e[32m==>\e[0m $*"; }
fail() { echo -e "install.sh: $*" >&2; exit 1; }

[[ -f $CONFIG ]] || fail "$CONFIG not found"
grep -qxF "$TOGGLES" "$CONFIG" || grep -qxF "$REQUIRE" "$CONFIG" ||
  fail "can't find $TOGGLES in $CONFIG; add $REQUIRE before it by hand"
command -v cargo >/dev/null || fail "cargo not found; it builds Aresta Settings"

say "Building Aresta Settings"
cargo build --release --locked --manifest-path "$REPO/app/Cargo.toml"

if [[ -L $TARGET && $(readlink -f "$TARGET") == "$(readlink -f "$SOURCE")" ]]; then
  :
elif [[ -e $TARGET || -L $TARGET ]]; then
  fail "$TARGET already exists and is not a link to $SOURCE"
else
  say "Linking $TARGET"
  ln -s "$SOURCE" "$TARGET"
fi

if ! grep -qxF "$REQUIRE" "$CONFIG"; then
  mkdir -p "$BACKUP_DIR"
  cp "$CONFIG" "$BACKUP_DIR/hyprland.lua.orig"
  say "Backed up $CONFIG to $BACKUP_DIR/hyprland.lua.orig"
  say "Adding $REQUIRE to $CONFIG"
  sed -i "s/^require(\"default\.hypr\.toggles\")\$/require(\"hypr.aresta\")\n&/" "$CONFIG"
fi

say "Reloading Hyprland"
hyprctl reload >/dev/null
sleep 1
errors="$(hyprctl configerrors)"
[[ -z ${errors//[[:space:]]/} ]] || fail "Hyprland reported config errors:\n$errors"

if [[ -L $PLUGIN_LINK && $(readlink -f "$PLUGIN_LINK") == "$REPO" ]]; then
  :
elif [[ -e $PLUGIN_LINK || -L $PLUGIN_LINK ]]; then
  fail "$PLUGIN_LINK already exists and is not a link to $REPO"
else
  say "Linking $PLUGIN_LINK"
  mkdir -p "$(dirname "$PLUGIN_LINK")"
  ln -s "$REPO" "$PLUGIN_LINK"
  omarchy-shell shell rescanPlugins >/dev/null
fi

if [[ -L $MENU_LINK && $(readlink -f "$MENU_LINK") == "$REPO/menu" ]]; then
  :
elif [[ -e $MENU_LINK || -L $MENU_LINK ]]; then
  fail "$MENU_LINK already exists and is not a link to $REPO/menu"
else
  say "Linking $MENU_LINK"
  ln -s "$REPO/menu" "$MENU_LINK"
  omarchy-shell shell rescanPlugins >/dev/null
fi

if ! omarchy-plugin-list | grep -qE "^$MENU_ID +enabled "; then
  say "Enabling Aresta Search"
  omarchy-plugin-enable "$MENU_ID" >/dev/null
fi

if [[ -L $SWITCHER_LINK && $(readlink -f "$SWITCHER_LINK") == "$REPO/switcher" ]]; then
  :
elif [[ -e $SWITCHER_LINK || -L $SWITCHER_LINK ]]; then
  fail "$SWITCHER_LINK already exists and is not a link to $REPO/switcher"
else
  say "Linking $SWITCHER_LINK"
  ln -s "$REPO/switcher" "$SWITCHER_LINK"
  omarchy-shell shell rescanPlugins >/dev/null
fi

if ! omarchy-plugin-list | grep -qE "^$SWITCHER_ID +enabled "; then
  say "Enabling the app switcher"
  omarchy-plugin-enable "$SWITCHER_ID" >/dev/null
fi

if [[ -L $CONTROL_CENTER_LINK && $(readlink -f "$CONTROL_CENTER_LINK") == "$REPO/control-center" ]]; then
  :
elif [[ -e $CONTROL_CENTER_LINK || -L $CONTROL_CENTER_LINK ]]; then
  fail "$CONTROL_CENTER_LINK already exists and is not a link to $REPO/control-center"
else
  say "Linking $CONTROL_CENTER_LINK"
  ln -s "$REPO/control-center" "$CONTROL_CENTER_LINK"
  omarchy-shell shell rescanPlugins >/dev/null
fi

if ! omarchy-plugin-list | grep -qE "^$CONTROL_CENTER_ID +enabled "; then
  say "Enabling the Control Center"
  omarchy-plugin-enable "$CONTROL_CENTER_ID" >/dev/null
fi

if [[ -L $DOCK_LINK && $(readlink -f "$DOCK_LINK") == "$REPO/dock" ]]; then
  :
elif [[ -e $DOCK_LINK || -L $DOCK_LINK ]]; then
  fail "$DOCK_LINK already exists and is not a link to $REPO/dock"
else
  say "Linking $DOCK_LINK"
  ln -s "$REPO/dock" "$DOCK_LINK"
  omarchy-shell shell rescanPlugins >/dev/null
fi

if omarchy-plugin-list | grep -qE "^$OLD_DOCK_ID +enabled "; then
  say "Disabling the macOS Dock plugin, which the Aresta Dock replaces"
  omarchy-plugin-disable "$OLD_DOCK_ID" >/dev/null
fi

if ! omarchy-plugin-list | grep -qE "^$DOCK_ID +enabled "; then
  say "Enabling the dock"
  omarchy-plugin-enable "$DOCK_ID" >/dev/null
fi

if [[ $(jq -r '.bar.id // ""' "$SHELL_CONFIG" 2>/dev/null) != "$PLUGIN_ID" ]]; then
  if [[ -f $SHELL_CONFIG ]]; then
    mkdir -p "$BACKUP_DIR"
    cp "$SHELL_CONFIG" "$BACKUP_DIR/shell.json.orig"
    say "Backed up $SHELL_CONFIG to $BACKUP_DIR/shell.json.orig"
  fi
  say "Selecting the Aresta bar"
  omarchy-bar use "$PLUGIN_ID" >/dev/null
fi

for theme in "$REPO"/themes/*/; do
  theme="${theme%/}"
  link="$THEMES_DIR/$(basename "$theme")"
  if [[ -L $link && $(readlink -f "$link") == "$theme" ]]; then
    :
  elif [[ -e $link || -L $link ]]; then
    fail "$link already exists and is not a link to $theme"
  else
    say "Linking $link"
    mkdir -p "$THEMES_DIR"
    ln -s "$theme" "$link"
  fi
done

if [[ -L $HOOK_LINK && $(readlink -f "$HOOK_LINK") == "$(readlink -f "$HOOK_SOURCE")" ]]; then
  :
elif [[ -e $HOOK_LINK || -L $HOOK_LINK ]]; then
  fail "$HOOK_LINK already exists and is not a link to $HOOK_SOURCE"
else
  say "Linking $HOOK_LINK"
  mkdir -p "$(dirname "$HOOK_LINK")"
  ln -s "$HOOK_SOURCE" "$HOOK_LINK"
fi

if [[ ! -f $LAST_THEME_FILE && -f $HOME/.local/state/omarchy/current/theme.name ]]; then
  cp "$HOME/.local/state/omarchy/current/theme.name" "$LAST_THEME_FILE"
fi

say "Installing $APP_BIN"
install -Dm755 "$REPO/app/target/release/aresta-settings" "$APP_BIN"
install -Dm644 "$REPO/assets/brand/icon.svg" "$APP_ICON"
if command -v gtk-update-icon-cache >/dev/null; then
  gtk-update-icon-cache -q -t -f "$ICON_THEME" || true
fi
mkdir -p "$(dirname "$APP_DESKTOP")"
cat >"$APP_DESKTOP" <<EOF
[Desktop Entry]
Type=Application
Name=Aresta Settings
Comment=Settings for Aresta
Exec=$APP_BIN
Icon=$PLUGIN_ID
Categories=Settings;
StartupWMClass=aresta-settings
EOF

say "Installing the Auto appearance timer"
mkdir -p "$UNIT_DIR"
cat >"$UNIT_DIR/aresta-auto.service" <<EOF
[Unit]
Description=Aresta Settings Auto appearance

[Service]
Type=oneshot
KillMode=process
ExecStart=$APP_BIN --auto
EOF
cat >"$UNIT_DIR/aresta-auto.timer" <<EOF
[Unit]
Description=Aresta Settings Auto appearance

[Timer]
OnCalendar=minutely
OnStartupSec=15
AccuracySec=1s
Persistent=true

[Install]
WantedBy=timers.target
EOF
systemctl --user daemon-reload
systemctl --user enable --now aresta-auto.timer >/dev/null 2>&1

say "Restarting the Omarchy shell"
omarchy-restart-shell ||
  fail "Aresta is installed, but omarchy-restart-shell failed with the error above; run it again to load the new version"

say "Done."
