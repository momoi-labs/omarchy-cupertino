pragma ComponentBehavior: Bound

// Copyright (c) 2026 Sebastian Webber
// Copyright (c) 2026 Rafael Bertholdo
// Copyright (c) David Heinemeier Hansson
// Licensed under the MIT License. See LICENSE.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Qt.labs.folderlistmodel
import qs.Commons
import "DockModel.js" as DockModel
import "file:///usr/share/omarchy/shell/services" as Services

Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property var appLibrary: shell && shell.appLibrary ? shell.appLibrary : ownAppLibrary
  Services.AppLibrary { id: ownAppLibrary }

  property var userShellConfig: ({})
  property var defaultShellConfig: ({})
  property bool configLoaded: false

  function parseConfig(text) {
    try { var parsed = JSON.parse(text || "{}"); return parsed && typeof parsed === "object" ? parsed : ({}) } catch (e) { return ({}) }
  }

  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.userShellConfig = root.parseConfig(text())
  }

  FileView {
    path: "/usr/share/omarchy/config/omarchy/shell.json"
    printErrors: false
    onLoaded: root.defaultShellConfig = root.parseConfig(text())
  }

  FileView {
    id: settingsFile
    path: Quickshell.env("HOME") + "/.config/aresta/settings.toml"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      root.settingsText = text()
      root.configLoaded = true
    }
    onLoadFailed: {
      root.configLoaded = true
      settingsRetry.restart()
    }
  }

  Timer {
    id: settingsRetry
    interval: 2000
    onTriggered: settingsFile.reload()
  }

  property string settingsText: ""
  readonly property var settings: DockModel.parseSettings(settingsText, {
    dock_autohide: false,
    dock_recents: true,
    dock_keep_clear: true,
    dock_indicators: true,
    dock_magnification: true,
    dock_size: 58
  })
  readonly property bool autohide: settings.dock_autohide
  readonly property bool showRecents: settings.dock_recents
  readonly property bool keepClear: settings.dock_keep_clear
  onKeepClearChanged: root.keepWindowsClear()
  property bool leftHeld: false
  property bool rightHeld: false
  readonly property bool buttonHeld: leftHeld || rightHeld
  onButtonHeldChanged: if (buttonHeld) clearSettle.stop()
  readonly property bool showIndicators: settings.dock_indicators
  readonly property bool magnify: settings.dock_magnification
  readonly property int preferredSize: Math.max(32, Math.min(80, Math.round(settings.dock_size)))

  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/aresta"
  property var recents: []
  property bool recentsLoaded: false

  FileView {
    id: recentsFile
    path: root.stateDir + "/dock-recents"
    printErrors: false
    onLoaded: {
      root.recents = DockModel.recentsAfter(text().split("\n"), [], [])
      root.recentsLoaded = true
    }
    onLoadFailed: root.recentsLoaded = true
  }

  readonly property bool dark: (0.2126 * Color.popups.background.r + 0.7152 * Color.popups.background.g + 0.0722 * Color.popups.background.b) < 0.4

  readonly property var dockConfig: shell && shell.shellConfig && shell.shellConfig.dock ? shell.shellConfig.dock
    : (root.userShellConfig.dock || ({}))
  readonly property var defaultDockConfig: shell && shell.defaultsConfig && shell.defaultsConfig.dock ? shell.defaultsConfig.dock
    : (root.defaultShellConfig.dock || ({}))

  property var pendingPins: null
  onDockConfigChanged: pendingPins = null

  readonly property var pinnedKeys: (root.pendingPins || DockModel.pinnedIds(root.dockConfig, root.defaultDockConfig)).filter(function(id) {
    return DesktopEntries.applications.values.length >= 0 && !!DesktopEntries.byId(id)
  })

  readonly property var terminalEntries: {
    var values = DesktopEntries.applications.values
    var out = []
    for (var i = 0; i < values.length; i++) {
      var entry = values[i]
      if (entry.runInTerminal || String(entry.execString || "").indexOf("--app-id=") >= 0)
        out.push({ id: entry.id, execString: entry.execString, command: entry.command, runInTerminal: entry.runInTerminal })
    }
    return out
  }

  function entryForAppId(appId) {
    var entry = DesktopEntries.heuristicLookup(appId)
    if (entry) return entry
    var id = DockModel.claimingEntryId(appId, root.terminalEntries)
    return id ? DesktopEntries.byId(id) : null
  }

  readonly property var windows: {
    var out = []
    var toplevels = Hyprland.toplevels.values
    for (var i = 0; i < toplevels.length; i++) {
      var toplevel = toplevels[i].wayland
      if (!toplevel || !toplevel.appId || toplevel.parent) continue
      var entry = root.entryForAppId(toplevel.appId)
      var workspace = toplevels[i].workspace
      var ipc = toplevels[i].lastIpcObject || ({})
      out.push({
        key: entry ? entry.id : toplevel.appId,
        hasEntry: !!entry && !entry.noDisplay,
        workspaceId: workspace ? workspace.id : -1,
        minimized: !!workspace && DockModel.isMinimizedWorkspace(workspace.name),
        address: toplevels[i].address,
        title: toplevel.title,
        tags: ipc.tags || [],
        toplevel: toplevel
      })
    }
    return out
  }

  readonly property var items: DockModel.buildItems(root.pinnedKeys, root.windows)

  readonly property var itemsByKey: {
    var byKey = {}
    for (var i = 0; i < root.items.length; i++) byKey[root.items[i].key] = root.items[i]
    return byKey
  }

  function itemFor(key) {
    return root.itemsByKey[key] || { key: key, pinned: false, windows: [] }
  }

  readonly property var otherKeys: DockModel.otherKeys(root.items, root.recents.filter(function(key) {
    return DesktopEntries.applications.values.length >= 0 && !!DesktopEntries.byId(key)
  }), root.showRecents)

  readonly property var minimized: DockModel.minimizedItems(root.windows)

  readonly property var windowsByAddress: {
    var byAddress = {}
    for (var i = 0; i < root.windows.length; i++) byAddress[root.windows[i].address] = root.windows[i]
    return byAddress
  }

  function minimizedFor(address) {
    for (var i = 0; i < root.minimized.length; i++) {
      if (root.minimized[i].address === address) return root.minimized[i]
    }
    return null
  }

  function toplevelFor(address) {
    var window = root.windowsByAddress[address]
    return window ? window.toplevel : null
  }

  property var seenRunning: []

  Timer {
    id: startupSettle
    interval: 2000
    running: true
  }

  function trackRecents() {
    var opened = DockModel.openedKeys(root.items, root.seenRunning).filter(function(key) { return !!DesktopEntries.byId(key) })
    root.seenRunning = DockModel.runningKeys(root.items)
    if (!root.recentsLoaded || startupSettle.running) return
    var next = DockModel.recentsAfter(root.recents, opened, root.pinnedKeys)
    if (next.join("\n") === root.recents.join("\n")) return
    root.recents = next
    recentsFile.setText(next.join("\n") + "\n")
  }

  onItemsChanged: {
    trackRecents()
    settleLaunches()
  }

  property var launches: ({})
  readonly property int launchTimeout: 10000

  function isLaunching(key) {
    return root.launches[key] !== undefined
  }

  function settleLaunches() {
    var next = {}
    var changed = false
    var now = Date.now()
    for (var key in root.launches) {
      var launch = root.launches[key]
      var windows = root.itemFor(key).windows.length
      if (windows > launch.windows || now - launch.at > root.launchTimeout) changed = true
      else next[key] = launch
    }
    if (changed) root.launches = next
  }

  Timer {
    interval: 1000
    repeat: true
    running: Object.keys(root.launches).length > 0
    onTriggered: root.settleLaunches()
  }

  property var iconIndex: ({})

  Process {
    id: iconScan
    running: true
    command: ["bash", "-c", [
      'dirs="$HOME/.icons $HOME/.local/share/icons";',
      'IFS=":"; for d in ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do dirs="$dirs $d/icons"; done; unset IFS;',
      'for base in $dirs; do [[ -d $base ]] && find -L "$base" -path "*/apps/*" \\( -name "*.svg" -o -name "*.png" \\) 2>/dev/null; done;',
      'find /usr/share/pixmaps -maxdepth 1 \\( -name "*.svg" -o -name "*.png" \\) 2>/dev/null'
    ].join(" ")]
    stdout: StdioCollector {
      onStreamFinished: root.iconIndex = DockModel.largestIcons(text.split("\n"))
    }
  }

  Connections {
    target: DesktopEntries.applications
    function onValuesChanged() { iconScan.running = true }
  }

  function iconSource(icon) {
    var name = String(icon || "")
    if (!name) return ""
    if (name.charAt(0) === "/") return "file://" + name
    if (root.iconIndex[name]) return "file://" + root.iconIndex[name]
    return Quickshell.iconPath(name, true)
  }

  function entryFor(item) {
    return item ? DesktopEntries.byId(item.key) : null
  }

  function iconFor(item) {
    var entry = entryFor(item)
    var source = root.iconSource(entry && entry.icon ? entry.icon : (item ? item.key : ""))
    return source || Quickshell.iconPath("application-x-executable")
  }

  function nameFor(item) {
    var entry = entryFor(item)
    return entry ? entry.name : (item ? item.key : "")
  }

  function launch(item) {
    var entry = entryFor(item)
    if (!entry) return
    var next = Object.assign({}, root.launches)
    next[item.key] = { at: Date.now(), windows: item.windows.length }
    root.launches = next
    root.launchEntry(entry)
  }

  function launchEntry(entry) {
    if (entry && root.appLibrary) root.appLibrary.launch(entry.id, entry.name)
  }

  function activeWorkspaceId() {
    var monitor = Hyprland.focusedMonitor
    return monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : -1
  }

  function activate(item) {
    if (!item) return
    if (item.windows.length === 0) {
      root.launch(item)
      return
    }
    var index = DockModel.pickWindow(item.windows.map(function(window) {
      return { workspaceId: window.workspaceId, minimized: window.minimized, activated: window.toplevel.activated }
    }), root.activeWorkspaceId())
    root.bringForward(item.windows[index])
  }

  function bringForward(window) {
    var address = String(window.address || "")
    if (!address) {
      window.toplevel.activate()
      return
    }
    if (address.indexOf("0x") !== 0) address = "0x" + address
    var target = "window = \"address:" + address + "\""
    var steps = []
    var after = []
    if (window.minimized) {
      var workspace = DockModel.restoreWorkspace(root.minimizedFor(window.address), root.activeWorkspaceId())
      if (!(workspace >= 1)) return
      steps.push("hl.dsp.window.set_prop({ prop = \"no_anim\", value = \"1\", " + target + " })")
      steps.push("hl.dsp.window.move({ workspace = \"" + workspace + "\", " + target + " })")
      after.push("hl.dsp.window.set_prop({ prop = \"no_anim\", value = \"unset\", " + target + " })")
    }
    steps.push("hl.dsp.focus({ " + target + " })")
    steps.push("hl.dsp.window.alter_zorder({ mode = \"top\", " + target + " })")
    var dispatch = function(step) { return "hyprctl dispatch " + Util.shellQuote(step) }
    var command = steps.map(dispatch).join(" && ")
    if (after.length > 0) command += "; sleep 0.4; " + after.map(dispatch).join("; ")
    Util.execDetached(command)
  }

  function restore(address) {
    var window = root.windowsByAddress[address]
    if (window) root.bringForward(window)
  }

  function quit(item) {
    if (!item) return
    var windows = item.windows.slice()
    for (var i = 0; i < windows.length; i++) windows[i].toplevel.close()
  }

  readonly property string downloadsDir: {
    var dir = String(Quickshell.env("XDG_DOWNLOAD_DIR") || "")
    return dir || Quickshell.env("HOME") + "/Downloads"
  }

  readonly property string trashDir: "file://" + Quickshell.env("HOME") + "/.local/share/Trash/files"
  FolderListModel {
    id: trashFiles
    folder: root.trashDir
    showHidden: true
    showDirs: true
    showDotAndDotDot: false
  }
  readonly property int trashCount: String(trashFiles.folder) === root.trashDir ? trashFiles.count : 0
  readonly property bool trashFull: trashCount > 0

  function openTrash() {
    Util.execDetached("gio open trash:///")
  }

  function emptyTrash() {
    Util.execDetached("gio trash --empty")
  }

  function openDownloads() {
    Util.execDetached("xdg-open " + Util.shellQuote(root.downloadsDir))
  }

  function openApps() {
    appGrid.open()
  }

  function isPinned(key) {
    return root.pinnedKeys.indexOf(key) >= 0
  }

  function savePins(pins) {
    root.pendingPins = pins
    Util.execDetached("omarchy-dock pinned " + pins.map(function(id) { return Util.shellQuote(id) }).join(" "))
  }

  function movePin(fromIndex, toIndex) {
    if (fromIndex === toIndex || !root.pinnedKeys[fromIndex]) return
    root.savePins(DockModel.orderWithKeyAt(root.pinnedKeys, root.pinnedKeys[fromIndex], toIndex))
  }

  function setPinned(key, pinned) {
    if (!key || pinned === root.isPinned(key)) return
    if (pinned) root.savePins(root.pinnedKeys.concat([key]))
    else {
      root.pendingPins = root.pinnedKeys.filter(function(other) { return other !== key })
      Util.execDetached("omarchy-dock unpin " + Util.shellQuote(key))
    }
  }

  function keepWindowsClear() {
    var reserves = docks.instances.some(function(dock) { return dock.exclusiveZone > 0 })
    if (root.keepClear && reserves && !root.buttonHeld) clearSettle.restart()
  }

  function moveClear(text) {
    if (!root.keepClear || root.buttonHeld) return
    var parts = text.split("\n---\n")
    var clients, monitors, gaps
    try {
      clients = JSON.parse(parts[0])
      monitors = JSON.parse(parts[1])
      gaps = DockModel.gapsOut(JSON.parse(parts[2]).css)
    } catch (error) {
      return
    }
    var zones = {}
    docks.instances.forEach(function(dock) { zones[dock.screen.name] = dock.exclusiveZone })
    var steps = []
    clients.forEach(function(client) {
      var spot = DockModel.clearOfDock(client, monitors, zones, gaps)
      if (!spot) return
      var target = "relative = false, window = \"address:" + client.address + "\" })"
      if (spot.height !== client.size[1]) steps.push("hl.dsp.window.resize({ x = " + spot.width + ", y = " + spot.height + ", " + target)
      steps.push("hl.dsp.window.move({ x = " + spot.x + ", y = " + spot.y + ", " + target)
    })
    if (steps.length > 0) Util.execDetached(steps.map(function(step) { return "hyprctl dispatch " + Util.shellQuote(step) }).join("; "))
  }

  Timer {
    id: clearSettle
    interval: 150
    onTriggered: {
      if (clearScan.running) restart()
      else clearScan.running = true
    }
  }

  Process {
    id: clearScan
    command: ["sh", "-c", "hyprctl -j clients; echo ---; hyprctl -j monitors; echo ---; hyprctl -j getoption general:gaps_out"]
    stdout: StdioCollector {
      onStreamFinished: root.moveClear(text)
    }
  }

  GlobalShortcut { appid: "aresta"; name: "dock-mouse-272"; description: "Dock: left mouse button"; onPressed: root.leftHeld = true; onReleased: { root.leftHeld = false; root.keepWindowsClear() } }
  GlobalShortcut { appid: "aresta"; name: "dock-mouse-273"; description: "Dock: right mouse button"; onPressed: root.rightHeld = true; onReleased: { root.rightHeld = false; root.keepWindowsClear() } }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = event ? String(event.name) : ""
      if (name === "fullscreen" || name === "movewindowv2") {
        Hyprland.refreshWorkspaces()
        Hyprland.refreshToplevels()
      }
      if (name === "openwindow" || name === "changefloatingmode") root.keepWindowsClear()
    }
  }

  ShellIpc {
    target: "omarchy.dock"

    function refresh(): void { Hyprland.refreshToplevels() }
    function apps(): void { appGrid.toggle() }
  }

  function dockOn(screen) {
    var windows = docks.instances
    for (var i = 0; i < windows.length; i++) {
      if (windows[i].screen === screen) return windows[i]
    }
    return null
  }

  function moveExternalDrag(screen, x, y) {
    var target = root.dockOn(screen)
    if (target) target.revealFor(x, y)
  }

  function dropExternalDrag(screen, x, y, key) {
    var target = root.dockOn(screen)
    if (target && key && target.covers(x, y)) root.setPinned(key, true)
  }

  Variants {
    id: docks
    model: Quickshell.screens

    delegate: Component {
      DockWindow {
        required property var modelData

        screen: modelData
        dock: root
      }
    }
  }

  AppGrid {
    id: appGrid
    appLibrary: root.appLibrary
    dock: root
  }
}
