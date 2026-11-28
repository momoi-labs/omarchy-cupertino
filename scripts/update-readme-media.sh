#!/bin/bash
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MEDIA="$REPO/docs/media"
OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}"
PLUGIN=dev.momoi-labs.aresta
GIFS=(menu-bar control-center search title-bars)
PNGS=(themes switcher settings dock)
WIDTH=1280
HEIGHT=720
SCALE=1.25
FRAME_MICROSECONDS=80000
GIF_LIMIT=$((4 * 1024 * 1024))
HOST_RUNTIME="${XDG_RUNTIME_DIR:-/run/user/$UID}"
DEMO_APPS=(org.gnome.Nautilus omacalc omawrite org.gnome.Evince imv mpv libreoffice-calc libreoffice-writer libreoffice-impress)
FILES=org.gnome.Nautilus
SETTINGS=aresta-settings
CALCULATOR=omacalc

WORK=""
RECORDER=""
SANDBOX=()
NESTED_DISPLAY=""
NESTED_SIGNATURE=""

fail() {
  echo "update-readme-media.sh: $*" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage: scripts/update-readme-media.sh [--list] [--gifs] [--pngs] [target...]

Regenerates the README media in docs/media inside a sandboxed, nested
Hyprland session. Without a target it regenerates every asset.

Targets: ${GIFS[*]} ${PNGS[*]}
EOF
}

in_session() {
  timeout 20 "${SANDBOX[@]}" \
    --setenv WAYLAND_DISPLAY "$NESTED_DISPLAY" \
    --setenv HYPRLAND_INSTANCE_SIGNATURE "$NESTED_SIGNATURE" \
    "$@"
}

hypr() {
  in_session hyprctl dispatch "$1" >/dev/null
}

shell() {
  in_session omarchy-shell "$@" >/dev/null
}

keys() {
  in_session wtype "$@"
}

write_home() {
  local mode=$1 cursor=$2 bar=$3 dock=$4
  local home="$WORK/home" repo="$WORK/repo"
  local plugins="$home/.config/omarchy/plugins" state="$home/.local/state/omarchy"
  local next next_dark=false invisible=true app dock_plugin=""

  mkdir -p "$WORK"/{runtime,apps,repo} "$plugins" "$home/.config/aresta" "$home/.config/hypr" \
    "$state/current" "$state/toggles/hypr" "$state/workspace-layouts" "$home/.local/state/aresta" \
    "$home/.cache" "$home/.local/share/icons/hicolor/scalable/apps" "$home"/{Documents,Downloads,Music,Pictures,Videos}
  chmod 700 "$WORK/runtime"

  ln -s "$repo" "$plugins/$PLUGIN"
  ln -s "$repo/menu" "$plugins/$PLUGIN.menu"
  ln -s "$repo/switcher" "$plugins/$PLUGIN.switcher"
  ln -s "$repo/dock" "$plugins/$PLUGIN.dock"
  ln -s "$repo/hypr/aresta.lua" "$home/.config/hypr/aresta.lua"
  cp -r "$REPO/control-center" "$plugins/$PLUGIN.control-center"
  cat >"$plugins/$PLUGIN.control-center/data.sh" <<'EOF'
#!/bin/bash
cat <<'JSON'
{"wifi":{"on":true,"ssid":"Home Wi-Fi","signal":82},"bt":{"on":true,"devices":["Keyboard","Headphones"]},"focus":{"on":false},"nightlight":{"on":false},"display":{"percent":70},"sound":{"percent":45,"muted":false,"sink":"Speakers"},"media":{"bus":"org.mpris.MediaPlayer2.demo","player":"Music","status":"Playing","title":"Morning Light","artist":"Sample Artist","art":""}}
JSON
EOF
  printf '#!/bin/bash\nexit 0\n' >"$plugins/$PLUGIN.control-center/act.sh"
  chmod +x "$plugins/$PLUGIN.control-center/data.sh" "$plugins/$PLUGIN.control-center/act.sh"

  cp "$REPO/assets/brand/icon.svg" "$home/.local/share/icons/hicolor/scalable/apps/$PLUGIN.svg"
  cp -r "$REPO/themes" "$home/.config/omarchy/themes"
  write_theme aresta-light

  echo 'o.workspace_mode({ workspace = "9", mode = "floating" })' >"$state/workspace-layouts/9.lua"
  if [[ $mode == floating ]]; then
    echo 'o.workspace_mode({ workspace = "1", mode = "floating" })' >"$state/workspace-layouts/1.lua"
  fi

  for app in "${DEMO_APPS[@]}"; do
    [[ -f /usr/share/applications/$app.desktop ]] && cp "/usr/share/applications/$app.desktop" "$WORK/apps/"
  done
  cat >"$WORK/apps/$SETTINGS.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Aresta Settings
Exec=$repo/app/target/release/aresta-settings
Icon=$PLUGIN
Categories=Settings;
StartupWMClass=$SETTINGS
EOF

  [[ $dock == on ]] && dock_plugin=", { \"id\": \"$PLUGIN.dock\" }"
  cat >"$home/.config/omarchy/shell.json" <<EOF
{
  "version": 1,
  "idle": { "screensaver": 0, "lock": 0 },
  "bar": {
    "id": "$bar",
    "position": "top",
    "background": "opaque",
    "layout": {
      "left": [{ "id": "$PLUGIN.menu" }, { "id": "omarchy.workspaces" }],
      "center": [{ "id": "omarchy.clock", "format": "ddd d MMM  HH:mm" }],
      "centerEnd": [{ "id": "$PLUGIN.control-center" }],
      "right": [{ "id": "omarchy.bluetooth" }, { "id": "omarchy.network" }, { "id": "omarchy.audio" }, { "id": "omarchy.monitor" }, { "id": "omarchy.power" }],
      "tray": []
    }
  },
  "disabledPlugins": ["omarchy.dock", "omarchy.polkit", "omarchy.menu"],
  "dock": { "pinned": ["$FILES", "$CALCULATOR", "omawrite", "$SETTINGS", "mpv"] },
  "plugins": [{ "id": "$PLUGIN.switcher" }$dock_plugin]
}
EOF

  cat >"$home/.config/aresta/settings.toml" <<'EOF'
appearance_auto = true
appearance_auto_schedule = "custom"
appearance_auto_light = "07:00"
appearance_auto_dark = "19:00"
light_theme = "aresta-light"
dark_theme = "aresta-dark"
panels_translucent = true
panels_align_right = true
control_center_enabled = true
EOF

  next=$(date -d 07:00 +%s)
  if (( $(date +%s) >= next )); then
    next=$(date -d 19:00 +%s)
    next_dark=true
  fi
  if (( $(date +%s) >= next )); then
    next=$(date -d "tomorrow 07:00" +%s)
    next_dark=false
  fi
  printf 'next=%s\nnext_dark=%s\nschedule=custom\n' "$next" "$next_dark" \
    >"$home/.local/state/aresta/auto-status"

  [[ $cursor == shown ]] && invisible=false
  cat >"$WORK/hyprland.lua" <<EOF
dofile(os.getenv("OMARCHY_PATH") .. "/default/hypr/bootstrap.lua")
package.loaded["default.hypr.autostart"] = true
require("default.hypr.omarchy")
require("hypr.aresta")
require("default.hypr.toggles")
hl.env("XCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_SIZE", "48")
hl.env("HYPRCURSOR_SIZE", "48")
hl.config({
  misc = { disable_hyprland_logo = true, disable_splash_rendering = true, disable_watchdog_warning = true },
  debug = { suppress_errors = true },
  ecosystem = { no_update_news = true, no_donation_nag = true },
  cursor = { no_hardware_cursors = 1, invisible = $invisible },
})
hl.monitor({ output = "", mode = "${WIDTH}x${HEIGHT}@60", position = "0x0", scale = $SCALE })
EOF
}

write_theme() {
  local theme=$1 current="$WORK/home/.local/state/omarchy/current"
  local themes="$WORK/home/.config/omarchy/themes"

  rm -rf "$current/theme" "$current/background"
  cp -r "$themes/$theme" "$current/theme"
  ln -s "$(find "$themes/$theme/backgrounds" -type f | sort | head -n1)" "$current/background"
  printf '%s\n' "$theme" >"$current/theme.name"
}

write_sandbox() {
  local path wayland_socket=$WAYLAND_DISPLAY

  [[ $wayland_socket == /* ]] || wayland_socket="$HOST_RUNTIME/$WAYLAND_DISPLAY"
  SANDBOX=(
    bwrap --die-with-parent --unshare-pid --unshare-net --clearenv --dev-bind / / --proc /proc
    --tmpfs /dev/snd
    --tmpfs /run/dbus
    --bind "$WORK/runtime" "$HOST_RUNTIME"
    --bind "$WORK/home" "$HOME"
    --ro-bind "$REPO" "$WORK/repo"
    --ro-bind "$WORK/apps" /usr/share/applications
    --setenv HOME "$HOME"
    --setenv USER "${USER:-$(id -un)}"
    --setenv LOGNAME "${LOGNAME:-${USER:-$(id -un)}}"
    --setenv LANG "${LANG:-C.UTF-8}"
    --setenv XDG_RUNTIME_DIR "$HOST_RUNTIME"
    --setenv XDG_DATA_DIRS /usr/share
    --setenv XDG_CURRENT_DESKTOP Hyprland
    --setenv XDG_SESSION_DESKTOP Hyprland
    --setenv XDG_SESSION_TYPE wayland
    --setenv QT_QPA_PLATFORM wayland
    --setenv GDK_BACKEND wayland
    --setenv XCURSOR_THEME Adwaita
    --setenv XCURSOR_SIZE 48
    --setenv HYPRCURSOR_SIZE 48
    --setenv OMARCHY_PATH "$OMARCHY_PATH"
    --setenv PATH "$OMARCHY_PATH/bin:/usr/local/bin:/usr/bin"
    --setenv PULSE_SERVER /dev/null
    --setenv PIPEWIRE_REMOTE /dev/null
    --setenv DBUS_SESSION_BUS_ADDRESS "unix:path=$HOST_RUNTIME/bus"
    --setenv QS_DISABLE_FILE_WATCHER 1
    --setenv QS_NO_RELOAD_POPUP 1
    --setenv NO_AT_BRIDGE 1
  )
  [[ -n ${LC_ALL:-} ]] && SANDBOX+=(--setenv LC_ALL "$LC_ALL")
  for path in /dev/v4l /dev/media "$OMARCHY_PATH/applications" /usr/local/share/applications; do
    [[ -d $path ]] && SANDBOX+=(--tmpfs "$path")
  done
  for path in /dev/video* /dev/media*; do
    [[ -c $path ]] && SANDBOX+=(--bind /dev/null "$path")
  done
  for path in /usr/bin/pipewire /usr/bin/pipewire-pulse /usr/bin/wireplumber /usr/bin/pulseaudio; do
    [[ -f $path && ! -L $path ]] && SANDBOX+=(--ro-bind /dev/null "$path")
  done
  for path in .local/share/fonts .config/fontconfig; do
    [[ -d $HOME/$path ]] && SANDBOX+=(--ro-bind "$HOME/$path" "$HOME/$path")
  done
  SANDBOX+=(--ro-bind "$wayland_socket" "$HOST_RUNTIME/host-wayland")

  {
    printf '#!/bin/bash\necho $$ >%q\nexec ' "$WORK/pid"
    printf '%q ' "${SANDBOX[@]}" --setenv WAYLAND_DISPLAY host-wayland --unsetenv HYPRLAND_INSTANCE_SIGNATURE \
      bash -c 'dbus-daemon --session --address="$DBUS_SESSION_BUS_ADDRESS" --fork --nopidfile; exec Hyprland -c "$1"' \
      _ "$WORK/hyprland.lua"
    printf '>%q 2>&1\n' "$WORK/hyprland.log"
  } >"$WORK/launch.sh"
  chmod +x "$WORK/launch.sh"
}

launch() {
  local rules="{ workspace = 'name:aresta-media silent', float = true, size = { $WIDTH, $HEIGHT }, render_unfocused = true }"

  if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] &&
    hyprctl eval "hl.exec_cmd('$WORK/launch.sh', $rules)" >/dev/null 2>&1; then
    return
  fi
  "$WORK/launch.sh" &
}

is_descendant() {
  local pid=$1 ancestor=$2 ppid

  while [[ $pid =~ ^[0-9]+$ ]] && (( pid > 1 )); do
    [[ $pid == "$ancestor" ]] && return 0
    ppid=$(awk '/^PPid:/ { print $2 }' "/proc/$pid/status" 2>/dev/null) || return 1
    [[ -n $ppid && $ppid != "$pid" ]] || return 1
    pid=$ppid
  done
  return 1
}

place_host_window() {
  local bpid candidate pid addr ws floating w h

  [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] || return 0
  [[ -s $WORK/pid ]] || return 1
  bpid=$(<"$WORK/pid")
  addr=""
  while IFS=$'\t' read -r candidate pid ws floating w h; do
    if [[ -n $candidate ]] && is_descendant "$pid" "$bpid"; then
      addr=$candidate
      break
    fi
  done < <(hyprctl clients -j 2>/dev/null | jq -r '.[] | select(.class == "aquamarine") | [.address, (.pid|tostring), .workspace.name, (.floating|tostring), (.size[0]|tostring), (.size[1]|tostring)] | @tsv' 2>/dev/null)
  [[ -n $addr ]] || return 1
  hyprctl dispatch "hl.dsp.window.set_prop({ prop = 'render_unfocused', value = '1', window = 'address:$addr' })" >/dev/null 2>&1 || true
  if [[ $ws == aresta-media && $floating == true && $w == "$WIDTH" && $h == "$HEIGHT" ]]; then
    return 0
  fi
  [[ $ws == aresta-media ]] || hyprctl dispatch "hl.dsp.window.move({ workspace = 'name:aresta-media', follow = false, window = 'address:$addr' })" >/dev/null 2>&1 || true
  [[ $floating == true ]] || hyprctl dispatch "hl.dsp.window.float({ action = 'on', window = 'address:$addr' })" >/dev/null 2>&1 || true
  [[ $w == "$WIDTH" && $h == "$HEIGHT" ]] || hyprctl dispatch "hl.dsp.window.resize({ x = $WIDTH, y = $HEIGHT, relative = false, window = 'address:$addr' })" >/dev/null 2>&1 || true
  return 1
}

wait_for_session() {
  local _ stable=0

  for _ in $(seq 1 120); do
    NESTED_DISPLAY="$(find "$WORK/runtime" -maxdepth 1 -name 'wayland-[0-9]*' ! -name '*.lock' -printf '%f\n' | head -n1)"
    NESTED_SIGNATURE="$(find "$WORK/runtime/hypr" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | head -n1 || true)"
    if place_host_window &&
      [[ -n $NESTED_DISPLAY && -n $NESTED_SIGNATURE ]] &&
      in_session hyprctl monitors -j 2>/dev/null | jq -e --argjson w "$WIDTH" --argjson h "$HEIGHT" 'any(.[]; .width == $w and .height == $h)' >/dev/null 2>&1; then
      stable=$((stable + 1))
      (( stable >= 2 )) && break
    else
      stable=0
    fi
    sleep 0.25
  done
  if (( stable < 2 )); then
    tail -n 20 "$WORK/hyprland.log" >&2 || true
    fail "the nested session did not start"
  fi

  in_session hyprctl eval 'hl.exec_cmd("env QT_QPA_PLATFORMTHEME=gtk3 quickshell -n -p " .. os.getenv("OMARCHY_PATH") .. "/shell")' >/dev/null
  for _ in $(seq 1 80); do
    if [[ $(in_session omarchy-shell shell ping 2>/dev/null) == ok ]]; then
      sleep 2
      return
    fi
    sleep 0.25
  done
  tail -n 20 "$WORK/hyprland.log" >&2 || true
  fail "omarchy-shell did not start"
}

start_session() {
  local mode=${1:-tiled} cursor=${2:-hidden} bar=${3:-$PLUGIN} dock=${4:-off}

  WORK="$(mktemp -d /tmp/aresta-media.XXXXXX)"
  write_home "$mode" "$cursor" "$bar" "$dock"
  write_sandbox
  launch
  wait_for_session
  in_session gsettings set org.gnome.desktop.interface color-scheme prefer-light
  in_session gsettings set org.gnome.desktop.interface icon-theme "$(<"$REPO/themes/aresta-light/icons.theme")"
  if [[ $cursor == shown ]]; then
    in_session gsettings set org.gnome.desktop.interface cursor-theme Adwaita
    in_session gsettings set org.gnome.desktop.interface cursor-size 48
    in_session hyprctl setcursor Adwaita 48 >/dev/null 2>&1 || true
  fi
  hypr "hl.dsp.cursor.move({ x = 620, y = 540 })"
}

restart_shell() {
  local _

  in_session quickshell kill -p "$OMARCHY_PATH/shell" --any-display >/dev/null 2>&1 || true
  for _ in $(seq 1 40); do
    [[ $(in_session omarchy-shell shell ping 2>/dev/null) != ok ]] && break
    sleep 0.1
  done
  in_session hyprctl eval 'hl.exec_cmd("env QT_QPA_PLATFORMTHEME=gtk3 quickshell -n -p " .. os.getenv("OMARCHY_PATH") .. "/shell")' >/dev/null
  for _ in $(seq 1 80); do
    if [[ $(in_session omarchy-shell shell ping 2>/dev/null) == ok ]]; then
      sleep 0.6
      return
    fi
    sleep 0.2
  done
  fail "omarchy-shell did not restart"
}

stop_session() {
  local pid _

  [[ -n $WORK ]] || return 0
  if [[ -n $RECORDER ]]; then
    touch "$WORK/stop"
  fi
  if [[ ! -s $WORK/pid && -x $WORK/launch.sh ]]; then
    for _ in $(seq 1 10); do
      [[ -s $WORK/pid ]] && break
      sleep 0.05
    done
  fi
  if [[ -s $WORK/pid ]]; then
    pid=$(<"$WORK/pid")
    kill "$pid" 2>/dev/null || true
    for _ in $(seq 1 40); do
      kill -0 "$pid" 2>/dev/null || break
      sleep 0.1
    done
    kill -KILL "$pid" 2>/dev/null || true
  fi
  if [[ -n $RECORDER ]]; then
    for _ in $(seq 1 30); do
      kill -0 "$RECORDER" 2>/dev/null || break
      sleep 0.1
    done
    kill "$RECORDER" 2>/dev/null || true
    wait "$RECORDER" 2>/dev/null || true
    RECORDER=""
  fi
  rm -rf "$WORK"
  WORK=""
}

set_theme() {
  local theme=$1 scheme=prefer-light background colors

  [[ $theme == *dark* ]] && scheme=prefer-dark
  write_theme "$theme"
  background="$(readlink "$WORK/home/.local/state/omarchy/current/background")"
  colors="$(base64 -w 0 "$REPO/themes/$theme/colors.toml")"
  shell background themeTransition "" "$background" "$background" "$colors" "" ||
    shell shell applyTheme "$colors" ""
  in_session gsettings set org.gnome.desktop.interface color-scheme "$scheme"
  in_session gsettings set org.gnome.desktop.interface icon-theme "$(<"$REPO/themes/$theme/icons.theme")"
  in_session hyprctl reload >/dev/null
}

open_app() {
  local class=$1 command=$2 rules=${3:-} _

  hypr "hl.dsp.exec_cmd('$command'${rules:+, $rules})"
  for _ in $(seq 1 60); do
    if in_session hyprctl clients -j | jq -e --arg class "$class" 'any(.[]; .class == $class)' >/dev/null; then
      sleep 0.3
      return
    fi
    sleep 0.25
  done
  fail "$class did not open"
}

open_files() {
  open_app "$FILES" "nautilus --new-window"
}

open_settings() {
  open_app "$SETTINGS" "$WORK/repo/app/target/release/aresta-settings"
}

open_calculator() {
  open_app "$CALCULATOR" omacalc "{ move = { 690, 120 }, size = { 300, 430 } }"
}

place() {
  local class=$1 x=$2 y=$3 width=$4 height=$5

  hypr "hl.dsp.window.resize({ x = $width, y = $height, relative = false, window = 'class:$class' })"
  hypr "hl.dsp.window.move({ x = $x, y = $y, relative = false, window = 'class:$class' })"
}

focus() {
  hypr "hl.dsp.focus({ window = 'class:$1' })"
  hypr "hl.dsp.window.alter_zorder({ mode = 'top', window = 'class:$1' })"
}

glide() {
  local x1=$1 y1=$2 x2=$3 y2=$4 steps=8 i x y

  for (( i = 1; i <= steps; i++ )); do
    x=$((x1 + (x2 - x1) * i / steps))
    y=$((y1 + (y2 - y1) * i / steps))
    hypr "hl.dsp.cursor.move({ x = $x, y = $y })"
    sleep 0.04
  done
}

click() {
  hypr "hl.dsp.cursor.move({ x = $1, y = $2 })"
  sleep 0.4
  hypr "hl.dsp.send_shortcut({ mods = '', key = 'mouse:272' })"
  hypr "hl.dsp.cursor.move({ x = $(($1 + 1)), y = $2 })"
}

record() {
  rm -f "$WORK/stop"
  "${SANDBOX[@]}" \
    --setenv WAYLAND_DISPLAY "$NESTED_DISPLAY" \
    --setenv HYPRLAND_INSTANCE_SIGNATURE "$NESTED_SIGNATURE" \
    bash -c '
      next=${EPOCHREALTIME/[.,]/}
      while [[ ! -e $1 ]]; do
        grim -t ppm - || break
        next=$((next + $2))
        now=${EPOCHREALTIME/[.,]/}
        if (( next > now )); then
          sleep "0.$(printf %06d $((next - now)))"
        else
          next=$now
        fi
      done' _ "$WORK/stop" "$FRAME_MICROSECONDS" |
    ffmpeg -loglevel error -y -f image2pipe -c:v ppm -framerate "1000000/$FRAME_MICROSECONDS" -i - \
      -c:v ffv1 "$WORK/frames.mkv" &
  RECORDER=$!
}

encode_gif() {
  local width=$1 height=$2
  local frame="scale=$width:$height:force_original_aspect_ratio=increase:flags=lanczos,crop=$width:$height"

  ffmpeg -loglevel error -y -i "$WORK/frames.mkv" -vf "$frame,palettegen=stats_mode=diff" "$WORK/palette.png"
  ffmpeg -loglevel error -y -i "$WORK/frames.mkv" -i "$WORK/palette.png" \
    -lavfi "${frame}[frames];[frames][1:v]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" "$WORK/out.gif"
}

write_gif() {
  touch "$WORK/stop"
  wait "$RECORDER"
  RECORDER=""
  encode_gif "$WIDTH" "$HEIGHT"
  if (( $(stat -c %s "$WORK/out.gif") > GIF_LIMIT )); then
    encode_gif 960 540
  fi
  mv "$WORK/out.gif" "$MEDIA/$1.gif"
}

shot() {
  sleep 0.4
  in_session grim -t ppm "$1"
}

write_png() {
  local source=$1 out="$WORK/out.png"

  magick "$source" -resize "${WIDTH}x${HEIGHT}^" -gravity center -extent "${WIDTH}x${HEIGHT}" \
    -strip -define png:compression-level=9 "$out"
  if command -v pngquant >/dev/null; then
    pngquant --force --skip-if-larger --quality 85-100 --output "$out" "$out" || true
  elif command -v optipng >/dev/null; then
    optipng -quiet "$out"
  fi
  mv "$out" "$MEDIA/$2.png"
}

target_menu_bar() {
  start_session floating shown omarchy.bar
  open_files
  open_settings
  place "$FILES" 60 80 600 420
  place "$SETTINGS" 232 68 760 480
  focus "$SETTINGS"
  click 316 215
  hypr "hl.dsp.cursor.move({ x = 620, y = 290 })"
  sleep 1
  record
  sleep 1.4
  glide 620 290 935 148
  click 935 148
  restart_shell
  sleep 1.8
  glide 935 148 120 440
  sleep 0.25
  focus "$FILES"
  sleep 1.6
  glide 360 290 760 115
  sleep 0.25
  focus "$SETTINGS"
  sleep 1.8
  write_gif menu-bar
}

target_control_center() {
  start_session floating shown
  open_files
  place "$FILES" 60 90 600 420
  hypr "hl.dsp.cursor.move({ x = 680, y = 260 })"
  sleep 1
  record
  sleep 0.9
  glide 680 260 877 14
  sleep 0.35
  shell aresta-control-center reveal
  sleep 1.4
  glide 877 14 832 72
  sleep 0.6
  shell aresta-control-center dismiss
  shell shell toggle omarchy.network
  sleep 2
  glide 832 72 877 14
  sleep 0.35
  shell shell toggle omarchy.network
  shell aresta-control-center reveal
  sleep 0.8
  glide 877 14 995 390
  sleep 0.6
  shell aresta-control-center dismiss
  shell shell toggle omarchy.audio
  sleep 2
  glide 995 390 680 260
  sleep 0.3
  shell shell toggle omarchy.audio
  sleep 0.8
  write_gif control-center
}

target_search() {
  start_session
  record
  sleep 1
  shell shell toggle omarchy.menu '{"menu":"root"}'
  sleep 1.6
  keys -d 150 calc
  sleep 2
  keys -d 90 -k BackSpace -k BackSpace -k BackSpace -k BackSpace
  sleep 0.4
  keys -d 170 '2^10'
  sleep 2.4
  keys -k Escape
  sleep 0.6
  keys -k Escape
  sleep 1
  write_gif search
}

target_title_bars() {
  start_session
  in_session hyprctl eval 'hl.config({ dwindle = { default_split_ratio = 0.5 } })' >/dev/null
  open_files
  open_settings
  sleep 1
  record
  sleep 1.2
  in_session hyprctl eval 'o.workspace_mode({ workspace = "1", mode = "floating" })' >/dev/null
  sleep 1.2
  place "$FILES" 36 70 500 360
  place "$SETTINGS" 250 86 760 480
  sleep 1.4
  open_calculator
  sleep 1.6
  focus "$FILES"
  sleep 1.4
  focus "$SETTINGS"
  sleep 1.4
  focus "$CALCULATOR"
  sleep 1.6
  write_gif title-bars
}

target_themes() {
  start_session floating
  open_files
  open_settings
  place "$FILES" 60 80 600 420
  place "$SETTINGS" 232 68 760 480
  focus "$SETTINGS"
  sleep 1
  shot "$WORK/light.ppm"
  set_theme aresta-dark
  sleep 2.5
  shot "$WORK/dark.ppm"
  magick "$WORK/light.ppm" \
    \( "$WORK/dark.ppm" \( -size "${WIDTH}x${HEIGHT}" xc:black -fill white \
      -draw "polygon $((WIDTH * 65 / 100)),0 $WIDTH,0 $WIDTH,$HEIGHT $((WIDTH * 35 / 100)),$HEIGHT" \) \
      -alpha off -compose CopyOpacity -composite \) \
    -compose Over -composite "$WORK/themes.ppm"
  write_png "$WORK/themes.ppm" themes
}

target_switcher() {
  start_session floating
  open_files
  open_settings
  place "$FILES" 36 70 500 360
  place "$SETTINGS" 250 86 760 480
  open_calculator
  sleep 1
  hypr "hl.dsp.global('aresta:next')"
  sleep 1.2
  shot "$WORK/switcher.ppm"
  hypr "hl.dsp.global('aresta:cancel')"
  write_png "$WORK/switcher.ppm" switcher
}

target_settings() {
  start_session floating
  open_settings
  place "$SETTINGS" 82 68 860 488
  focus "$SETTINGS"
  sleep 1
  shot "$WORK/settings.ppm"
  write_png "$WORK/settings.ppm" settings
}

target_dock() {
  local reader=org.gnome.Evince address

  start_session floating hidden "$PLUGIN" on
  restart_shell
  sleep 2
  open_files
  open_calculator
  open_app "$reader" evince
  place "$FILES" 60 50 600 400
  place "$CALCULATOR" 690 50 300 400
  address="$(in_session hyprctl clients -j | jq -r --arg class "$reader" '.[] | select(.class == $class) | .address')"
  in_session omarchy-hyprland-window-minimize "$address"
  focus "$FILES"
  sleep 2
  shot "$WORK/dock.ppm"
  write_png "$WORK/dock.ppm" dock
}

main() {
  local targets=() argument target

  for argument in "$@"; do
    case $argument in
      --list)
        printf '%s\n' "${GIFS[@]}" "${PNGS[@]}"
        exit 0
        ;;
      --gifs) targets+=("${GIFS[@]}") ;;
      --pngs) targets+=("${PNGS[@]}") ;;
      -h | --help)
        usage
        exit 0
        ;;
      menu-bar | control-center | search | title-bars | themes | switcher | settings | dock)
        targets+=("$argument")
        ;;
      *)
        fail "unknown target: $argument (see --list)"
        ;;
    esac
  done
  (( ${#targets[@]} )) || targets=("${GIFS[@]}" "${PNGS[@]}")

  for target in bwrap Hyprland hyprctl quickshell dbus-daemon gsettings grim wtype ffmpeg magick jq cargo nautilus omacalc; do
    command -v "$target" >/dev/null || fail "$target not found"
  done
  [[ -x $OMARCHY_PATH/bin/omarchy-shell ]] || command -v omarchy-shell >/dev/null || fail "omarchy-shell not found"
  [[ -n ${WAYLAND_DISPLAY:-} ]] || fail "no Wayland session to host the nested Hyprland"
  [[ -d $OMARCHY_PATH/shell ]] || fail "$OMARCHY_PATH/shell not found"

  cargo build --release --locked --manifest-path "$REPO/app/Cargo.toml"
  mkdir -p "$MEDIA"

  trap stop_session EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM

  for target in "${targets[@]}"; do
    echo "==> $target"
    "target_${target//-/_}"
    stop_session
  done
}

main "$@"
