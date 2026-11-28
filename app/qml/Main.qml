pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Dialogs
import QtQuick.Shapes
import QtQuick.Window
import Aresta as App

Window {
  id: window

  width: 1040
  height: 690
  minimumWidth: 760
  minimumHeight: 480
  visible: true
  title: qsTr("Aresta Settings")
  color: look.window

  property string panel: "appearance"
  property var back: []
  property var forward: []
  property string query: ""
  property string target: ""

  readonly property var titleAlignOptions: [
    { value: "left", label: qsTr("Left") },
    { value: "center", label: qsTr("Center") },
    { value: "right", label: qsTr("Right") }
  ]

  readonly property var buttonPositionOptions: [
    { value: "left", label: qsTr("Left") },
    { value: "right", label: qsTr("Right") }
  ]

  readonly property var desktopPositions: [
    { value: "menus", label: qsTr("After the menus") },
    { value: "center", label: qsTr("Center") },
    { value: "status", label: qsTr("Before the status icons") }
  ]

  readonly property var desktopStyles: [
    { value: "numbers", label: qsTr("Numbers") },
    { value: "dots", label: qsTr("Dots") }
  ]

  readonly property var selectionColors: [
    { value: "gray", label: qsTr("Gray") },
    { value: "accent", label: qsTr("Theme accent") }
  ]

  readonly property var scheduleOptions: [
    { value: "solar", label: qsTr("Sunset to Sunrise") },
    { value: "custom", label: qsTr("Custom") }
  ]

  function customSchedule() {
    return store.flag("appearance_auto") && store.text("appearance_auto_schedule") === "custom"
  }

  readonly property string searchPlugin: "dev.momoi-labs.aresta.menu"
  readonly property string dockPlugin: "dev.momoi-labs.aresta.dock"

  readonly property var previewMenu: [
    { icon: "\u{f003b}", label: qsTr("Apps"), menu: false, provider: true },
    { icon: "\u{f09d1}", label: qsTr("Learn"), menu: true },
    { icon: "\u{f03d8}", label: qsTr("Appearance"), menu: true },
    { icon: "\u{f14de}", label: qsTr("Trigger"), menu: true },
    { icon: "\ue615", label: qsTr("Setup"), menu: true },
    { icon: "\u{f0249}", label: qsTr("Install"), menu: true },
    { icon: "\u{f0b4c}", label: qsTr("Remove"), menu: true },
    { icon: "\uf021", label: qsTr("Update"), menu: true },
    { icon: "\uea74", label: qsTr("About"), menu: false },
    { icon: "\uf011", label: qsTr("System"), menu: true }
  ]

  readonly property var previewApps: [
    { name: qsTr("Files"), glyph: "\uf07b", top: "#4aa8ff", bottom: "#0a6cf0" },
    { name: qsTr("Terminal"), glyph: "\uf120", top: "#48484a", bottom: "#1c1c1e" },
    { name: qsTr("Music"), glyph: "\uf001", top: "#ff6b78", bottom: "#fa233b" },
    { name: qsTr("Calculator"), glyph: "\uf1ec", top: "#ffb340", bottom: "#ff9500" },
    { name: qsTr("Settings"), glyph: "\uf013", top: "#aeaeb2", bottom: "#7c7c80" }
  ]

  readonly property var previewDesktops: [
    { id: 1, occupied: true, current: false },
    { id: 2, occupied: true, current: true },
    { id: 3, occupied: false, current: false },
    { id: 4, occupied: true, current: false },
    { id: 5, occupied: false, current: false }
  ]

  component Desktops: Row {
    id: desktops
    required property Theme ui
    required property color ink
    property var items: []
    property string style: "numbers"
    property bool occupiedOnly: false
    spacing: style === "dots" ? 7 : 3

    Repeater {
      model: desktops.items.filter(function(item) { return !desktops.occupiedOnly || item.occupied || item.current })

      Item {
        id: desktop
        required property var modelData
        width: desktops.style === "dots" ? (modelData.current ? 18 : 7) : 20
        height: 18

        Rectangle {
          visible: desktops.style === "numbers" && desktop.modelData.current
          anchors.fill: parent
          radius: 5
          color: desktops.ui.accent
        }

        Text {
          visible: desktops.style === "numbers"
          anchors.horizontalCenter: parent.horizontalCenter
          y: Math.round((parent.height - height) / 2)
          text: desktop.modelData.id
          color: desktop.modelData.current ? desktops.ui.accentText : desktop.modelData.occupied ? desktops.ink : Qt.alpha(desktops.ink, 0.4)
          font.family: desktops.ui.fontFamily
          font.pixelSize: 12
          font.weight: desktop.modelData.current ? Font.Bold : Font.Medium
        }

        Rectangle {
          visible: desktops.style === "dots"
          anchors.horizontalCenter: parent.horizontalCenter
          y: Math.round((parent.height - height) / 2)
          width: parent.width
          height: 7
          radius: 3.5
          color: desktop.modelData.current ? desktops.ui.accent : desktop.modelData.occupied ? Qt.alpha(desktops.ink, 0.7) : "transparent"
          border.width: desktop.modelData.current || desktop.modelData.occupied ? 0 : 1.2
          border.color: Qt.alpha(desktops.ink, 0.6)
        }
      }
    }
  }

  readonly property string themeTitle: store.revision >= 0 ? store.themeTitle(store.themeName) : ""

  function fileUrl(path) {
    return path === "" ? "" : "file://" + path.split("/").map(encodeURIComponent).join("/")
  }

  function localPath(url) {
    return decodeURIComponent(url.toString().replace(/^file:\/\//, ""))
  }

  function pictureName(path) {
    var base = path.split("/").pop().replace(/\.[^.]*$/, "")
    return base.split(/[-_ ]+/).filter(function(word) { return word !== "" })
      .map(function(word) { return word.charAt(0).toUpperCase() + word.slice(1) }).join(" ")
  }

  readonly property bool battery: store.hasBattery()

  readonly property var sections: [
    { id: "appearance", name: qsTr("Appearance"), block: 1, groups: [
      { title: qsTr("Appearance"), rows: [
        { type: "appearance_preview", label: qsTr("Appearance preview") },
        { type: "appearance", label: qsTr("Appearance"), hint: qsTr("Auto follows sunrise and sunset, or your own times") },
        { type: "segment", key: "appearance_auto_schedule", shown: () => store.flag("appearance_auto"), label: qsTr("Schedule"), options: scheduleOptions, otherwise: "solar" },
        { type: "time", key: "appearance_auto_light", shown: customSchedule, label: qsTr("Light at") },
        { type: "time", key: "appearance_auto_dark", shown: customSchedule, label: qsTr("Dark at") },
        { type: "theme", key: "light_theme", dark: false, label: qsTr("Light theme") },
        { type: "theme", key: "dark_theme", dark: true, label: qsTr("Dark theme") }
      ], note: qsTr("Each list shows only themes of its mode. \"Aresta Light\" and \"Aresta Dark\" are the defaults.") },
      { title: qsTr("Windows"), rows: [{ type: "toggle", key: "shadow_enabled", label: qsTr("Show window shadows") }] },
      { title: qsTr("Panels"), rows: [
        { type: "toggle", key: "panels_translucent", label: qsTr("Translucent panels"), hint: qsTr("Translucent background for Control Center, Aresta Search and the app switcher") },
        { type: "slider", key: "panels_opacity", requires: "panels_translucent", label: qsTr("Panel background opacity"), min: 30, max: 100, step: 5, unit: "%" },
        { type: "toggle", key: "panels_align_right", label: qsTr("Align panels to right corner"), hint: qsTr("Open Control Center and hidden status panels in the top-right corner") }
      ] }
    ] },
    { id: "wallpaper", name: qsTr("Wallpaper"), block: 1, groups: [
      { rows: [
        { type: "wallpaper", label: qsTr("Current wallpaper") },
        { type: "toggle", key: "wallpaper_keep", label: qsTr("Keep this wallpaper when the theme changes"), hint: qsTr("Off: your light and dark themes show the matching wallpaper. Other themes show their own.") }
      ] },
      { kind: "sources", rows: [{ label: qsTr("Add Photo"), hint: qsTr("Add Folder") }] }
    ] },
    { id: "menubar", name: qsTr("Menu Bar"), block: 1, groups: [
      { rows: [
        { type: "plugin", plugin: "dev.momoi-labs.aresta", fallback: "omarchy.bar", label: qsTr("Use the Aresta menu bar"), hint: qsTr("Off brings back the Omarchy bar") }
      ] },
      { title: qsTr("Desktops"), rows: [
        { type: "bar", label: qsTr("Menu bar preview") },
        { type: "toggle", key: "bar_desktops", label: qsTr("Show desktops in the menu bar"), hint: qsTr("Click a desktop to go there. Scroll over the row to move to the next one.") },
        { type: "segment", key: "bar_desktops_position", label: qsTr("Position"), options: desktopPositions },
        { type: "segment", key: "bar_desktops_style", label: qsTr("Style"), options: desktopStyles },
        { type: "toggle", key: "bar_desktops_occupied_only", label: qsTr("Only desktops with windows"), hint: qsTr("The current desktop always shows") }
      ], note: qsTr("Desktops are the Hyprland workspaces of this monitor. In the preview: desktop 2 is current, 1 and 4 have windows, 3 and 5 are empty.") },
      { rows: [
        { type: "slider", key: "bar_opacity", label: qsTr("Menu bar background opacity"), hint: qsTr("Uses your theme background color"), min: 0, max: 100, step: 5, unit: "%" }
      ] },
      { title: qsTr("Clock"), rows: [
        { type: "text", key: "clock_format", label: qsTr("Clock format"), hint: qsTr("Qt date format, like ddd d MMM  HH:mm") }
      ] }
    ] },
    { id: "dock", name: qsTr("Dock"), block: 1, groups: [
      { rows: [
        { type: "plugin", plugin: dockPlugin, label: qsTr("Use the Aresta Dock"), hint: qsTr("Off brings back the Omarchy dock") },
        { type: "dock", label: qsTr("Dock preview") },
        { type: "slider", requires: { plugin: dockPlugin }, key: "dock_size", label: qsTr("Size"), min: 32, max: 80, step: 2, unit: "px" },
        { type: "toggle", requires: { plugin: dockPlugin }, key: "dock_magnification", label: qsTr("Magnification"), hint: qsTr("Icons grow under the pointer") },
        { type: "toggle", requires: { plugin: dockPlugin }, key: "dock_autohide", label: qsTr("Automatically hide and show the Dock"), hint: qsTr("Move the pointer to the bottom edge to show it") },
        { type: "toggle", requires: { plugin: dockPlugin }, key: "dock_indicators", label: qsTr("Show indicators for open applications") },
        { type: "toggle", requires: { plugin: dockPlugin }, key: "dock_recents", label: qsTr("Show recent apps in Dock"), hint: qsTr("The last 3 apps that are not pinned") }
      ], note: qsTr("Drag a pinned app to reorder it. Right-click an app to keep it in the Dock or remove it. Minimized windows show next to the Trash.") }
    ] },
    { id: "search", name: qsTr("Search"), block: 1, groups: [
      { rows: [
        { type: "plugin", plugin: searchPlugin, label: qsTr("Use Aresta Search") },
        { type: "search", label: qsTr("Search preview") },
        { type: "slider", requires: { plugin: searchPlugin }, key: "search_size", label: qsTr("Size"), min: 80, max: 150, step: 10, unit: "%" },
        { type: "segment", requires: { plugin: searchPlugin }, key: "search_selection", label: qsTr("Selection color"), options: selectionColors },
        { type: "toggle", requires: { plugin: searchPlugin }, key: "search_filters", label: qsTr("Show filters"), hint: qsTr("Buttons under the search field. Ctrl+1 to Ctrl+9 work either way.") },
        { type: "toggle", requires: { plugin: searchPlugin }, key: "search_menu_on_open", label: qsTr("Show menu on open"), hint: qsTr("Off opens only the search field until you type") },
        { type: "toggle", requires: { plugin: searchPlugin }, key: "search_shortcuts", label: qsTr("Show shortcuts"), hint: qsTr("Keyboard hints at the bottom of the card") },
        { type: "toggle", requires: { plugin: searchPlugin }, key: "search_movable", label: qsTr("Movable"), hint: qsTr("Drag the card to move it, or its top or bottom edge to change its height. It opens that way next time.") },
        { type: "clear", requires: { plugin: searchPlugin }, keys: ["search_position", "search_height"], label: qsTr("Position"), hint: qsTr("Saved for each display"), button: qsTr("Reset position") }
      ] }
    ] },
    { id: "titlebars", name: qsTr("Title Bars"), block: 1, groups: [
      { rows: [
        { type: "toggle", key: "traffic_lights_enabled", label: qsTr("Use the Aresta title bars") },
        { type: "titlebars", label: qsTr("Title bar preview") }
      ] },
      { title: qsTr("Windows"), rows: [
        { type: "toggle", key: "title_bars_always", requires: "traffic_lights_enabled", label: qsTr("Always show title bars"), hint: qsTr("Show on tiled windows too, not only on floating workspaces") },
        { type: "segment", key: "traffic_lights_position", requires: "traffic_lights_enabled", label: qsTr("Button position"), options: buttonPositionOptions },
        { type: "toggle", key: "traffic_lights_grey_inactive", requires: "traffic_lights_enabled", label: qsTr("Grey traffic lights on unfocused windows") },
        { type: "toggle", key: "traffic_light_icons_on_hover", requires: "traffic_lights_enabled", label: qsTr("Show icons in traffic lights on hover") },
        { type: "select", key: "title_align", requires: "traffic_lights_enabled", label: qsTr("Window title alignment"), options: titleAlignOptions },
        { type: "stepper", key: "traffic_light_size", requires: "traffic_lights_enabled", label: qsTr("Traffic light size"), min: 8, max: 24, unit: "px" }
      ] }
    ] },
    { id: "controlcenter", name: qsTr("Control Center"), block: 1, groups: [
      { rows: [
        { type: "toggle", key: "control_center_enabled", label: qsTr("Use Control Center") }
      ] },
      { title: qsTr("Panel"), rows: [
        { type: "cc", label: qsTr("Control Center preview") },
        { type: "toggle", key: "control_center_halo", requires: "control_center_enabled", label: qsTr("Show panel frame"), hint: qsTr("Subtle backdrop frame around the floating controls") },
        { type: "toggle", key: "cc_wifi", requires: "control_center_enabled", label: qsTr("Wi-Fi") },
        { type: "toggle", key: "cc_bluetooth", requires: "control_center_enabled", label: qsTr("Bluetooth") },
        { type: "toggle", key: "cc_focus", requires: "control_center_enabled", label: qsTr("Focus") },
        { type: "toggle", key: "cc_display", requires: "control_center_enabled", label: qsTr("Display") },
        { type: "toggle", key: "cc_sound", requires: "control_center_enabled", label: qsTr("Sound") },
        { type: "toggle", key: "cc_media", requires: "control_center_enabled", label: qsTr("Now Playing") }
      ] },
      { title: qsTr("Also show in the menu bar"), rows: [
        { type: "toggle", key: "cc_bar_network", requires: "control_center_enabled", label: qsTr("Wi-Fi in the menu bar") },
        { type: "toggle", key: "cc_bar_bluetooth", requires: "control_center_enabled", label: qsTr("Bluetooth in the menu bar") },
        { type: "toggle", key: "cc_bar_audio", requires: "control_center_enabled", label: qsTr("Sound in the menu bar") },
        { type: "toggle", key: "cc_bar_monitor", requires: "control_center_enabled", label: qsTr("System monitor in the menu bar") },
        { type: "toggle", key: "cc_bar_power", requires: "control_center_enabled", locked: !battery, label: qsTr("Battery in the menu bar"), hint: battery ? "" : qsTr("This computer has no battery") }
      ] }
    ] },
    { id: "switcher", name: qsTr("App Switcher"), block: 1, groups: [
      { rows: [
        { type: "toggle", key: "switcher_enabled", label: qsTr("Use the Aresta app switcher"), hint: qsTr("Off brings back Omarchy's Super+Tab and Super+Shift+Tab, which go to the next and previous workspace") },
        { type: "switcher", label: qsTr("App switcher preview") }
      ] },
      { title: qsTr("Shortcuts"), rows: [
        { type: "shortcut", key: "shortcut_switcher_next", label: qsTr("Switch apps"), hint: qsTr("Hold the first modifier to keep the switcher open") },
        { type: "shortcut", key: "shortcut_switcher_previous", label: qsTr("Switch apps backwards") }
      ] }
    ] },
    { id: "keyboard", name: qsTr("Shortcuts"), block: 2, groups: [
      { title: qsTr("Keyboard Shortcuts"), rows: [
        { type: "toggle", key: "quit_enabled", label: qsTr("Use Quit app"), hint: qsTr("Off brings back Omarchy's Super+Q, which closes only the window") },
        { type: "shortcut", key: "shortcut_quit", label: qsTr("Quit app"), hint: qsTr("Closes every window of the app, on all workspaces") },
        { type: "toggle", key: "cycle_enabled", label: qsTr("Use Cycle windows"), hint: qsTr("Off brings back Omarchy's Super+`, which toggles the Quake console") },
        { type: "shortcut", key: "shortcut_cycle", label: qsTr("Cycle windows of the same app"), hint: qsTr("Skips minimized windows") }
      ] },
      { title: qsTr("Windows"), rows: [
        { type: "omarchy", label: qsTr("Close window"), keys: ["Super", "W"] },
        { type: "omarchy", label: qsTr("Minimize to the Dock"), keys: ["Super", "M"] }
      ], note: qsTr("Omarchy owns these two. Change them in the Omarchy keybindings.") },
      { title: qsTr("Quake Console"), rows: [
        { type: "toggle", key: "quake_enabled", label: qsTr("Use Aresta Quake console keys"), hint: qsTr("Off brings back Omarchy's Super+Shift+`. Super+` toggles the console while Cycle windows is off.") },
        { type: "shortcut", key: "shortcut_quake_toggle", label: qsTr("Toggle Quake console") },
        { type: "shortcut", key: "shortcut_quake_move", label: qsTr("Move window to Quake console") }
      ] }
    ] },
    { id: "aresta", name: qsTr("Aresta"), block: 2, lead: qsTr("Options for window corners, the border, the shadow and the bar size."), groups: [
      { title: qsTr("Window Corners"), rows: [
        { type: "toggle", key: "corners_enabled", label: qsTr("Rounded corners"), hint: qsTr("Off brings back Omarchy's square corners") },
        { type: "slider", key: "window_rounding", label: qsTr("Window corner radius"), min: 0, max: 24, step: 1, unit: "px" },
        { type: "slider", key: "window_rounding_power", label: qsTr("Window corner shape"), hint: qsTr("2 is a circle arc, 4 is a squircle"), min: 2, max: 5, step: 0.1 }
      ] },
      { title: qsTr("Window Border"), rows: [
        { type: "toggle", key: "border_enabled", label: qsTr("Thin neutral border"), hint: qsTr("Off brings back Omarchy's colored border") },
        { type: "stepper", key: "border_size", label: qsTr("Window border width"), min: 0, max: 8, unit: "px" },
        { type: "slider", key: "border_active_opacity", label: qsTr("Border opacity, focused window"), min: 0, max: 100, step: 5, unit: "%" },
        { type: "slider", key: "border_inactive_opacity", label: qsTr("Border opacity, unfocused window"), min: 0, max: 100, step: 5, unit: "%" }
      ] },
      { title: qsTr("Window Shadow"), rows: [
        { type: "slider", key: "shadow_range", label: qsTr("Shadow size"), min: 0, max: 60, step: 1, unit: "px" },
        { type: "stepper", key: "shadow_offset", label: qsTr("Shadow vertical offset"), min: 0, max: 40, unit: "px" },
        { type: "slider", key: "shadow_active_opacity", label: qsTr("Shadow strength, focused window"), min: 0, max: 100, step: 1, unit: "%" },
        { type: "slider", key: "shadow_inactive_opacity", label: qsTr("Shadow strength, unfocused window"), min: 0, max: 100, step: 1, unit: "%" }
      ] },
      { title: qsTr("Menu Bar"), rows: [
        { type: "stepper", key: "bar_height", label: qsTr("Menu bar height"), min: 20, max: 48, unit: "px" },
        { type: "slider", key: "status_icon_scale", label: qsTr("Status icon size"), min: 100, max: 150, step: 5, unit: "%" },
        { type: "stepper", key: "status_item_width", label: qsTr("Space per status item"), min: 20, max: 60, unit: "px" }
      ] }
    ] }
  ]

  readonly property var currentSection: {
    for (var i = 0; i < sections.length; i++)
      if (sections[i].id === panel) return sections[i]
    return sections[0]
  }

  readonly property var results: {
    var needle = query.trim().toLowerCase()
    var hits = []
    if (!needle || store.revision < 0) return hits
    for (var s = 0; s < sections.length; s++) {
      var section = sections[s]
      for (var g = 0; g < section.groups.length; g++) {
        var group = section.groups[g]
        for (var r = 0; r < group.rows.length; r++) {
          var item = group.rows[r]
          if (item.shown && !item.shown()) continue
          var haystack = [item.label, item.hint || "", group.title || "", section.name].join(" ").toLowerCase()
          if (haystack.indexOf(needle) !== -1) hits.push({ section: section.id, sectionName: section.name, label: item.label })
        }
      }
    }
    return hits
  }

  function open(id) {
    store.stopRecording()
    if (id !== panel) {
      back = back.concat([panel])
      forward = []
      panel = id
      content.contentY = 0
    }
  }

  function reveal(row) {
    target = ""
    var top = row.mapToItem(page, 0, 0).y - 40
    content.contentY = Math.max(0, Math.min(top, content.contentHeight - content.height))
  }

  function goBack() {
    if (back.length === 0) return
    store.stopRecording()
    forward = forward.concat([panel])
    panel = back[back.length - 1]
    back = back.slice(0, -1)
    content.contentY = 0
  }

  function goForward() {
    if (forward.length === 0) return
    store.stopRecording()
    back = back.concat([panel])
    panel = forward[forward.length - 1]
    forward = forward.slice(0, -1)
    content.contentY = 0
  }

  App.Backend { id: store }

  Theme {
    id: look
    background: store.background
    foreground: store.foreground
    accent: store.accent
  }

  Timer {
    interval: 250
    running: true
    repeat: true
    onTriggered: store.tick()
  }

  onActiveChanged: {
    if (active) store.refreshThemes()
    else store.stopRecording()
  }
  Component.onDestruction: store.stopRecording()

  Shortcut { enabled: store.recording === ""; sequences: [StandardKey.Find]; onActivated: search.forceActiveFocus() }
  Shortcut { enabled: store.recording === ""; sequences: [StandardKey.Quit, StandardKey.Close]; onActivated: Qt.quit() }
  Shortcut { enabled: store.recording === ""; sequence: "Alt+Left"; onActivated: window.goBack() }
  Shortcut { enabled: store.recording === ""; sequence: "Alt+Right"; onActivated: window.goForward() }

  Item {
    id: recorder
    focus: store.recording !== ""
    onFocusChanged: if (focus) forceActiveFocus()
    Keys.onPressed: event => {
      event.accepted = true
      var plain = (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier | Qt.ShiftModifier)) === 0
      if (plain && event.key === Qt.Key_Escape) store.stopRecording()
      else if (plain && event.key === Qt.Key_Backspace) store.clearShortcut()
      else store.record(event.modifiers, event.nativeScanCode)
    }
  }

  Rectangle {
    id: sidebar

    x: 8
    y: 8
    width: Math.max(232, window.width * 0.276)
    height: parent.height - 16
    radius: 15
    color: look.sidebar
    border.width: 1
    border.color: look.separator

    Rectangle {
      id: searchBox
      x: 10
      y: 12
      width: parent.width - 20
      height: 30
      radius: 15
      color: look.control
      border.width: 1
      border.color: search.activeFocus ? look.accent : look.controlBorder

      Shape {
        x: 10
        y: 8
        width: 14
        height: 14
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          strokeColor: look.textSecondary
          strokeWidth: 1.7
          fillColor: "transparent"
          capStyle: ShapePath.RoundCap
          PathSvg { path: "M6 2 A4 4 0 1 1 6 10 A4 4 0 1 1 6 2 M9.2 9.2 L12.5 12.5" }
        }
      }

      TextInput {
        id: search
        x: 30
        width: parent.width - 40
        height: parent.height
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        color: look.text
        selectionColor: look.accent
        selectedTextColor: look.accentText
        font.family: look.fontFamily
        font.pixelSize: 13
        onTextChanged: window.query = text
        Keys.onEscapePressed: { text = ""; focus = false }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: search.text === ""
          text: qsTr("Search")
          color: look.textSecondary
          font: search.font
        }
      }
    }

    ListView {
      id: navigation
      x: 10
      y: searchBox.y + searchBox.height + 12
      width: parent.width - 20
      height: parent.height - y - 10
      visible: window.query.trim() === "" || window.results.length > 0
      clip: true
      spacing: 0
      model: window.query.trim() === "" ? window.sections : window.results

      delegate: Item {
        id: entry
        required property var modelData
        required property int index

        readonly property bool searching: window.query.trim() !== ""
        readonly property string sectionId: searching ? modelData.section : modelData.id
        readonly property bool selected: !searching && window.panel === sectionId
        readonly property bool gap: !searching && index > 0 && window.sections[index - 1].block !== modelData.block

        width: ListView.view.width
        height: item.height + (gap ? 16 : 0)

        Rectangle {
          id: item
          y: entry.gap ? 16 : 0
          width: parent.width
          height: entry.searching ? 40 : 34
          radius: 10
          color: entry.selected ? look.accent : area.containsMouse ? look.hover : "transparent"

          SectionIcon {
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            kind: entry.sectionId
          }

          Column {
            x: 39
            width: parent.width - 47
            anchors.verticalCenter: parent.verticalCenter

            Text {
              width: parent.width
              elide: Text.ElideRight
              text: entry.searching ? entry.modelData.label : entry.modelData.name
              color: entry.selected ? look.accentText : look.text
              font.family: look.fontFamily
              font.pixelSize: 13
            }

            Text {
              visible: entry.searching
              text: entry.searching ? entry.modelData.sectionName : ""
              color: look.textSecondary
              font.family: look.fontFamily
              font.pixelSize: 11
            }
          }

          MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
              var label = entry.modelData ? (entry.modelData.label || "") : ""
              window.open(entry.sectionId)
              search.text = ""
              window.target = label
            }
          }
        }
      }
    }

    Column {
      visible: !navigation.visible
      width: parent.width - 24
      x: 12
      anchors.verticalCenter: parent.verticalCenter
      spacing: 4

      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: qsTr("No Results")
        color: look.text
        font.family: look.fontFamily
        font.pixelSize: 15
        font.weight: Font.Bold
      }

      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: qsTr("Nothing matches \"%1\". Check the spelling, or search for a section name.").arg(window.query.trim())
        color: look.textSecondary
        font.family: look.fontFamily
        font.pixelSize: 13
      }
    }
  }

  Item {
    id: main
    anchors.left: sidebar.right
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom

    Rectangle {
      id: navPill
      x: 8
      y: 11
      width: 72
      height: 32
      radius: 16
      color: look.box
      border.width: 1
      border.color: look.separator

      Repeater {
        model: [-1, 1]

        Item {
          id: navButton
          required property int modelData
          readonly property bool active: modelData < 0 ? window.back.length > 0 : window.forward.length > 0
          x: modelData < 0 ? 0 : 36
          width: 36
          height: 32

          Shape {
            anchors.centerIn: parent
            width: 8
            height: 13
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
              strokeColor: navButton.active ? look.text : look.textTertiary
              strokeWidth: 1.9
              fillColor: "transparent"
              capStyle: ShapePath.RoundCap
              joinStyle: ShapePath.RoundJoin
              PathSvg { path: navButton.modelData < 0 ? "M6.5 1.5 L1.5 6.5 L6.5 11.5" : "M1.5 1.5 L6.5 6.5 L1.5 11.5" }
            }
          }

          MouseArea {
            anchors.fill: parent
            enabled: navButton.active
            onClicked: navButton.modelData < 0 ? window.goBack() : window.goForward()
          }
        }
      }
    }

    Text {
      anchors.left: navPill.right
      anchors.leftMargin: 12
      anchors.right: errorText.left
      anchors.verticalCenter: navPill.verticalCenter
      text: window.currentSection.name
      color: look.text
      font.family: look.fontFamily
      font.pixelSize: 15
      font.weight: Font.Bold
      elide: Text.ElideRight
    }

    Text {
      id: errorText
      anchors.right: parent.right
      anchors.rightMargin: 24
      anchors.verticalCenter: navPill.verticalCenter
      width: Math.min(implicitWidth, parent.width / 2)
      text: store.error
      color: look.record
      font.family: look.fontFamily
      font.pixelSize: 12
      elide: Text.ElideRight
    }

    Flickable {
      id: content
      anchors.fill: parent
      anchors.topMargin: 54
      anchors.leftMargin: 8
      anchors.rightMargin: 24
      contentHeight: page.implicitHeight + 24
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: page
        width: Math.min(content.width, 720)
        spacing: 20
        topPadding: 2

        Text {
          visible: !!window.currentSection.lead
          leftPadding: 10
          text: window.currentSection.lead || ""
          color: look.textSecondary
          font.family: look.fontFamily
          font.pixelSize: 12
        }

        Repeater {
          model: window.currentSection.groups

          Column {
            id: group
            required property var modelData
            width: page.width
            spacing: 8

            readonly property bool sources: group.modelData.kind === "sources"

            Text {
              visible: !!group.modelData.title
              leftPadding: 10
              text: group.modelData.title || ""
              color: look.text
              font.family: look.fontFamily
              font.pixelSize: 13
              font.weight: Font.Bold
            }

            Loader {
              active: group.sources
              visible: active
              width: parent.width
              sourceComponent: sourcesView
            }

            Rectangle {
              visible: !group.sources
              width: parent.width
              height: rows.implicitHeight
              radius: 12
              color: look.box

              Column {
                id: rows
                width: parent.width

                Repeater {
                  model: group.modelData.rows

                  Loader {
                    id: rowLoader
                    required property var modelData
                    required property int index
                    readonly property bool targeted: window.target !== "" && window.target === modelData.label
                    width: rows.width
                    visible: !modelData.shown || (store.revision >= 0 && modelData.shown())
                    onTargetedChanged: if (targeted) Qt.callLater(window.reveal, rowLoader)
                    sourceComponent: group.sources ? null
                      : modelData.type === "appearance_preview" ? appearancePreviewRow
                      : modelData.type === "wallpaper" ? wallpaperRow
                      : modelData.type === "bar" ? barRow
                      : modelData.type === "dock" ? dockRow
                      : modelData.type === "titlebars" ? titleBarsRow
                      : modelData.type === "search" ? searchRow
                      : modelData.type === "switcher" ? switcherRow
                      : modelData.type === "cc" ? ccRow : settingRow

                    Component {
                      id: settingRow
                      SettingRow {
                        ui: look
                        backend: store
                        setting: rowLoader.modelData
                        first: rowLoader.index === 0
                      }
                    }
                  }
                }
              }
            }

            Text {
              visible: !!group.modelData.note
              width: parent.width
              leftPadding: 10
              rightPadding: 10
              text: group.modelData.note || ""
              color: look.textSecondary
              font.family: look.fontFamily
              font.pixelSize: 12
              wrapMode: Text.Wrap
            }
          }
        }
      }
    }
  }

  FileDialog {
    id: photoDialog
    title: qsTr("Add Photo")
    nameFilters: [qsTr("Pictures (*.jpg *.jpeg *.png *.gif *.bmp *.webp)")]
    onAccepted: store.addPhoto(window.localPath(selectedFile))
  }

  FolderDialog {
    id: folderDialog
    title: qsTr("Add Folder")
    onAccepted: store.addFolder(window.localPath(selectedFolder))
  }

  Component {
    id: appearancePreviewRow

    AppearancePreview {
      ui: look
      backend: store
      themeTitle: window.themeTitle
      wallpaperUrl: window.fileUrl(store.currentWallpaper)
    }
  }

  Component {
    id: wallpaperRow

    Item {
      implicitHeight: 158

      Rectangle {
        id: picture
        x: 14
        y: 14
        width: 208
        height: 130
        radius: 8
        color: look.controlSoft
        clip: true

        RoundedImage {
          radius: 8
          anchors.fill: parent
          source: store.thumbnails >= 0 ? store.thumbnail(store.currentWallpaper, 512) : ""
          sourceSize.width: 416
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
        }
      }

      Column {
        anchors.left: picture.right
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: picture.verticalCenter
        spacing: 4

        Text {
          width: parent.width
          elide: Text.ElideRight
          text: store.currentWallpaper === "" ? qsTr("No wallpaper") : window.pictureName(store.currentWallpaper)
          color: look.text
          font.family: look.fontFamily
          font.pixelSize: 15
          font.weight: Font.DemiBold
        }

        Text {
          width: parent.width
          elide: Text.ElideMiddle
          text: store.shortPath(store.currentWallpaper)
          color: look.textSecondary
          font.family: look.fontFamily
          font.pixelSize: 12
        }

        Text {
          topPadding: 6
          text: store.revision >= 0 && store.flag("wallpaper_keep") ? qsTr("Stays when you change the theme.") : qsTr("Light and dark show the matching wallpaper.")
          color: look.textSecondary
          font.family: look.fontFamily
          font.pixelSize: 12
        }
      }
    }
  }

  Component {
    id: sourcesView

    Column {
      id: sources
      spacing: 20
      readonly property int perRow: Math.max(1, Math.floor((width - 20 + 10) / 138))

      Repeater {
        model: store.wallpapers >= 0 && store.themeName !== "-" ? store.wallpaperSources() : []

        Column {
          id: source
          required property string modelData
          readonly property var parts: modelData.split("\t")
          readonly property var images: store.wallpapers >= 0 ? store.wallpaperImages(parts[2]) : []
          property bool expanded: false
          width: sources.width
          spacing: 8

          Item {
            width: parent.width
            height: 18

            Row {
              x: 10
              spacing: 8
              anchors.verticalCenter: parent.verticalCenter

              Text {
                text: source.parts[0]
                color: look.text
                font.family: look.fontFamily
                font.pixelSize: 13
                font.weight: Font.Bold
              }

              Text {
                text: source.parts[1] !== "" ? source.parts[1] : store.shortPath(source.parts[2]) + "/"
                color: look.textSecondary
                font.family: look.fontFamily
                font.pixelSize: 12
              }
            }

            Text {
              visible: source.images.length > sources.perRow
              anchors.right: parent.right
              anchors.rightMargin: 10
              anchors.verticalCenter: parent.verticalCenter
              text: source.expanded ? qsTr("Show Less") : qsTr("Show All (%1)").arg(source.images.length)
              color: look.accent
              font.family: look.fontFamily
              font.pixelSize: 12

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: source.expanded = !source.expanded
              }
            }
          }

          Rectangle {
            width: parent.width
            height: source.images.length > 0 ? thumbs.implicitHeight + 20 : empty.implicitHeight + 32
            radius: 12
            color: look.box

            Text {
              id: empty
              visible: source.images.length === 0
              x: 14
              width: parent.width - 28
              anchors.verticalCenter: parent.verticalCenter
              wrapMode: Text.Wrap
              textFormat: Text.StyledText
              text: qsTr("Nothing here yet. Add Photo copies a picture into <tt>%1/</tt>.").arg(store.shortPath(source.parts[2]))
              color: look.textSecondary
              font.family: look.fontFamily
              font.pixelSize: 12
            }

            Flow {
              id: thumbs
              x: 10
              y: 10
              width: parent.width - 20
              spacing: 10

              Repeater {
                model: source.expanded ? source.images : source.images.slice(0, sources.perRow)

                Item {
                  id: thumb
                  required property string modelData
                  readonly property bool current: modelData === store.currentWallpaper
                  width: 128
                  height: 100

                  Rectangle {
                    x: -3
                    y: -3
                    width: 134
                    height: 86
                    radius: 10
                    color: "transparent"
                    border.width: 3
                    border.color: thumb.current ? look.accent : "transparent"
                  }

                  Rectangle {
                    width: 128
                    height: 80
                    radius: 7
                    color: look.controlSoft
                    border.width: 1
                    border.color: look.separator
                    clip: true

                    RoundedImage {
                      radius: 6
                      anchors.fill: parent
                      anchors.margins: 1
                      source: store.thumbnails >= 0 ? store.thumbnail(thumb.modelData, 256) : ""
                      sourceSize.width: 256
                      fillMode: Image.PreserveAspectCrop
                      asynchronous: true
                    }
                  }

                  Text {
                    y: 84
                    width: parent.width
                    horizontalAlignment: thumb.current ? Text.AlignHCenter : Text.AlignLeft
                    elide: Text.ElideRight
                    text: window.pictureName(thumb.modelData)
                    color: thumb.current ? look.text : look.textSecondary
                    font.family: look.fontFamily
                    font.pixelSize: 11
                    font.weight: thumb.current ? Font.Bold : Font.Normal
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: store.setWallpaper(thumb.modelData)
                  }
                }
              }
            }
          }
        }
      }

      Row {
        anchors.right: parent.right
        spacing: 8

        Repeater {
          model: [
            { label: qsTr("Add Folder…"), dialog: folderDialog },
            { label: qsTr("Add Photo…"), dialog: photoDialog }
          ]

          Rectangle {
            id: button
            required property var modelData
            width: buttonLabel.implicitWidth + 24
            height: 26
            radius: 7
            color: buttonArea.pressed ? look.control : look.controlSoft
            border.width: 1
            border.color: look.controlBorder

            Text {
              id: buttonLabel
              anchors.centerIn: parent
              text: button.modelData.label
              color: look.text
              font.family: look.fontFamily
              font.pixelSize: 13
            }

            MouseArea {
              id: buttonArea
              anchors.fill: parent
              onClicked: button.modelData.dialog.open()
            }
          }
        }
      }
    }
  }

  Component {
    id: barRow

    Item {
      id: preview
      readonly property bool shown: store.revision >= 0 && store.flag("bar_desktops")
      readonly property string position: store.revision >= 0 ? store.text("bar_desktops_position") : ""
      readonly property string style: store.revision >= 0 ? store.text("bar_desktops_style") : ""
      readonly property bool occupiedOnly: store.revision >= 0 && store.flag("bar_desktops_occupied_only")
      readonly property color ink: look.text
      implicitHeight: 174

      Timer {
        id: minute
        property date now: new Date()
        interval: 1000
        running: true
        repeat: true
        onTriggered: now = new Date()
      }

      Rectangle {
        x: 12
        y: 12
        width: parent.width - 24
        height: 150
        radius: 10
        color: look.controlSoft
        border.width: 1
        border.color: look.separator
        clip: true

        RoundedImage {
          radius: 9
          anchors.fill: parent
          anchors.margins: 1
          source: store.thumbnails >= 0 ? store.thumbnail(store.currentWallpaper, 512) : ""
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
        }

        Rectangle {
          id: strip
          x: 1
          y: 1
          width: parent.width - 2
          height: 29
          topLeftRadius: 9
          topRightRadius: 9
          color: Qt.alpha(look.background, (store.revision >= 0 ? store.number("bar_opacity") : 50) / 100)

          Row {
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14

            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              width: 13
              height: 13
              radius: 3
              color: "transparent"
              border.width: 1.3
              border.color: preview.ink
            }

            Repeater {
              model: strip.width >= 560 ? [qsTr("Ghostty"), qsTr("File"), qsTr("Edit"), qsTr("View")] : [qsTr("Ghostty")]
              Text {
                required property string modelData
                required property int index
                anchors.verticalCenter: parent.verticalCenter
                text: modelData
                color: preview.ink
                font.family: look.fontFamily
                font.pixelSize: 12
                font.letterSpacing: index === 0 ? 0.15 : 0
                font.weight: index === 0 ? Font.DemiBold : Font.Normal
              }
            }

            Desktops {
              visible: preview.shown && preview.position === "menus"
              anchors.verticalCenter: parent.verticalCenter
              ui: look
              ink: preview.ink
              items: window.previewDesktops
              style: preview.style
              occupiedOnly: preview.occupiedOnly
            }
          }

          Desktops {
            visible: preview.shown && preview.position === "center"
            anchors.centerIn: parent
            ui: look
            ink: preview.ink
            items: window.previewDesktops
            style: preview.style
            occupiedOnly: preview.occupiedOnly
          }

          Row {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 16

            Desktops {
              visible: preview.shown && preview.position === "status"
              anchors.verticalCenter: parent.verticalCenter
              ui: look
              ink: preview.ink
              items: window.previewDesktops
              style: preview.style
              occupiedOnly: preview.occupiedOnly
            }

            Shape {
              anchors.verticalCenter: parent.verticalCenter
              width: 16
              height: 12
              preferredRendererType: Shape.CurveRenderer
              ShapePath {
                strokeColor: preview.ink
                strokeWidth: 1.5
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathSvg { path: "M1 4.5 Q8 -1.5 15 4.5 M3.5 7 Q8 3.5 12.5 7 M6 9.5 Q8 8 10 9.5" }
              }
            }

            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              width: 18
              height: 9
              radius: 2.5
              color: "transparent"
              border.width: 1.2
              border.color: preview.ink

              Rectangle { x: 2; y: 2; width: 10; height: 5; radius: 1; color: preview.ink }
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: Qt.formatDateTime(minute.now, store.revision >= 0 ? store.text("clock_format") : "")
              color: preview.ink
              font.family: look.fontFamily
              font.pixelSize: 12
            }
          }
        }
      }
    }
  }

  Component {
    id: dockRow

    Item {
      id: dockPreview
      readonly property bool on: store.revision >= 0 && store.pluginEnabled(window.dockPlugin)
      readonly property bool autohide: store.revision >= 0 && store.flag("dock_autohide")
      readonly property bool indicators: store.revision >= 0 && store.flag("dock_indicators")
      readonly property bool recents: store.revision >= 0 && store.flag("dock_recents")
      readonly property bool magnify: store.revision >= 0 && store.flag("dock_magnification")
      readonly property real tile: (store.revision >= 0 ? store.number("dock_size") : 58) * 0.5
      readonly property bool darkBg: look.background.hslLightness < 0.5
      readonly property var tiles: ["#8e8e93", "#0a7aff", "#30a8c8", "#34c759", "#ff9f0a"].concat(recents ? ["", "#af52de", "#ff375f"] : []).concat(["", "#d1d1d6", "#aeaeb2"])
      implicitHeight: 174

      Rectangle {
        x: 12
        y: 12
        width: parent.width - 24
        height: 150
        radius: 10
        color: look.controlSoft
        border.width: 1
        border.color: look.separator
        clip: true

        RoundedImage {
          radius: 9
          anchors.fill: parent
          anchors.margins: 1
          source: store.thumbnails >= 0 ? store.thumbnail(store.currentWallpaper, 512) : ""
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
        }

        Rectangle {
          id: dockPanel
          anchors.horizontalCenter: parent.horizontalCenter
          y: parent.height - height - 4 + (dockPreview.autohide ? height - 5 : 0)
          width: dockTiles.width + 10
          height: dockPreview.tile + 12
          radius: Math.min(13, Math.round(height * 0.32))
          color: dockPreview.darkBg ? Qt.rgba(52 / 255, 52 / 255, 56 / 255, 0.5) : Qt.rgba(246 / 255, 246 / 255, 246 / 255, 0.5)
          border.width: 1
          border.color: dockPreview.darkBg ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.6)
          opacity: dockPreview.on ? 1 : 0.35

          Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

          Row {
            id: dockTiles
            x: 5
            y: 3
            spacing: Math.round(dockPreview.tile * 0.14)

            Repeater {
              model: dockPreview.tiles

              Item {
                id: dockTile
                required property string modelData
                required property int index
                readonly property real grow: dockPreview.magnify ? ([1, 1.15, 1.4, 1.15][index] || 1) : 1
                width: modelData === "" ? 1 : dockPreview.tile * grow
                height: dockPreview.tile + 7

                Rectangle {
                  width: parent.width
                  height: dockTile.modelData === "" ? dockPreview.tile * 0.84 : parent.width
                  y: dockTile.modelData === "" ? dockPreview.tile * 0.08 : dockPreview.tile - height
                  radius: dockTile.modelData === "" ? 0 : width * 0.22
                  color: dockTile.modelData === "" ? (dockPreview.darkBg ? Qt.rgba(1, 1, 1, 0.24) : Qt.rgba(0, 0, 0, 0.2)) : dockTile.modelData
                }

                Rectangle {
                  visible: dockPreview.indicators && (dockTile.index === 1 || dockTile.index === 3)
                  anchors.horizontalCenter: parent.horizontalCenter
                  y: dockPreview.tile + 2
                  width: 3
                  height: 3
                  radius: 1.5
                  color: dockPreview.darkBg ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(0, 0, 0, 0.74)
                }
              }
            }
          }
        }
      }
    }
  }

  Component {
    id: titleBarsRow

    Item {
      id: bars
      readonly property bool aresta: store.revision >= 0 && store.flag("traffic_lights_enabled")
      readonly property bool grey: store.revision >= 0 && store.flag("traffic_lights_grey_inactive")
      readonly property bool hoverIcons: store.revision >= 0 && store.flag("traffic_light_icons_on_hover")
      readonly property string align: store.revision >= 0 ? store.text("title_align") : "center"
      readonly property bool buttonsRight: store.revision >= 0 && store.text("traffic_lights_position") === "right"
      readonly property real lightSize: store.revision >= 0 ? Math.floor(store.number("traffic_light_size")) : 14
      readonly property var themeColors: {
        var map = {}
        var list = store.themePalette(store.themeName)
        for (var i = 0; i < list.length; i++) {
          var parts = list[i].split("|")
          map[parts[0]] = parts[1]
        }
        return map
      }
      readonly property color background: themeColors.background || look.background
      readonly property color foreground: themeColors.foreground || look.foreground
      readonly property color barColor: themeColors.lighter_background && themeColors.lighter_background !== themeColors.background
        ? themeColors.lighter_background : themeColors.selection || background
      readonly property var lights: [
        { icon: "×", color: "#ff5f57" },
        { icon: "−", color: "#febc2e" },
        { icon: "□", color: "#28c840" }
      ]
      implicitHeight: 254

      Rectangle {
        id: desk
        x: 12
        y: 12
        width: parent.width - 24
        height: 230
        radius: 10
        color: look.controlSoft
        border.width: 1
        border.color: look.separator
        clip: true

        RoundedImage {
          radius: 9
          anchors.fill: parent
          anchors.margins: 1
          source: window.fileUrl(store.currentWallpaper)
          sourceSize.width: 1400
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
        }

        Repeater {
          model: [
            { focused: false, title: qsTr("Files"), x: 0.06, y: 22, width: 0.5, height: 140 },
            { focused: true, title: qsTr("Terminal"), x: 0.4, y: 66, width: 0.54, height: 144 }
          ]

          Rectangle {
            id: frame
            required property var modelData
            readonly property bool focused: modelData.focused
            readonly property real lightsWidth: 3 * bars.lightSize + 2 * 8
            readonly property real omarchyWidth: 3 * 20 + 2 * 8
            x: desk.width * modelData.x
            y: modelData.y
            width: desk.width * modelData.width
            height: modelData.height
            radius: 10
            color: bars.barColor
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.18)

            Rectangle {
              x: 1
              y: 30
              width: parent.width - 2
              height: parent.height - 31
              bottomLeftRadius: 9
              bottomRightRadius: 9
              color: bars.background
            }

            Text {
              readonly property bool centered: bars.aresta && bars.align === "center"
              readonly property bool rightAligned: bars.aresta && bars.align === "right"
              x: !bars.aresta ? 10 : centered ? (parent.width - width) / 2 : bars.buttonsRight ? 10 : 26 + frame.lightsWidth
              width: !bars.aresta ? parent.width - 36 - frame.omarchyWidth
                : centered ? parent.width - 52 - 2 * frame.lightsWidth : parent.width - 36 - frame.lightsWidth
              height: 30
              verticalAlignment: Text.AlignVCenter
              horizontalAlignment: centered ? Text.AlignHCenter : rightAligned ? Text.AlignRight : Text.AlignLeft
              elide: Text.ElideRight
              text: frame.modelData.title
              color: bars.foreground
              font.family: "monospace"
              font.pixelSize: 12
            }

            Row {
              id: lights
              visible: bars.aresta
              x: bars.buttonsRight ? parent.width - width - 10 : 10
              y: (30 - bars.lightSize) / 2
              spacing: 8

              HoverHandler { id: lightsHover }

              Repeater {
                model: bars.buttonsRight ? bars.lights.slice().reverse() : bars.lights

                Rectangle {
                  id: light
                  required property var modelData
                  width: bars.lightSize
                  height: bars.lightSize
                  radius: Math.floor(bars.lightSize / 2)
                  color: frame.focused || !bars.grey ? modelData.color : "#998e8e93"

                  Text {
                    anchors.centerIn: parent
                    visible: !bars.hoverIcons || lightsHover.hovered
                    text: light.modelData.icon
                    color: "#99000000"
                    font.family: "sans"
                    font.pixelSize: Math.round(bars.lightSize * 0.62)
                  }
                }
              }
            }

            Row {
              visible: !bars.aresta
              anchors.right: parent.right
              anchors.rightMargin: 10
              y: 5
              spacing: 8

              Repeater {
                model: ["−", "□", "×"]

                Rectangle {
                  id: button
                  required property string modelData
                  width: 20
                  height: 20
                  color: bars.barColor

                  Text {
                    anchors.centerIn: parent
                    text: button.modelData
                    color: bars.foreground
                    font.family: "sans"
                    font.pixelSize: 12
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  Component {
    id: searchRow

    Item {
      id: spot
      readonly property bool aresta: store.revision >= 0 && store.pluginEnabled(window.searchPlugin)
      readonly property real size: store.revision >= 0 ? Math.max(80, Math.min(150, store.number("search_size"))) / 100 : 1
      readonly property bool accentRows: store.revision >= 0 && store.text("search_selection") === "accent"
      readonly property bool filters: store.revision >= 0 && store.flag("search_filters")
      readonly property bool list: store.revision >= 0 && store.flag("search_menu_on_open")
      readonly property bool footer: store.revision >= 0 && store.flag("search_shortcuts")
      readonly property bool translucent: store.revision >= 0 && store.flag("panels_translucent")
      readonly property real panelAlpha: Math.max(0.3, Math.min(1, (store.revision >= 0 ? store.number("panels_opacity") : 70) / 100))
      readonly property real rounding: store.revision >= 0 && store.flag("corners_enabled") ? store.number("window_rounding") : 0
      readonly property real zoom: 0.5
      readonly property real gaps: 5
      readonly property real screenHeight: desk.height / zoom
      readonly property var items: window.previewMenu
      readonly property color activeBorder: {
        var list = store.themePalette(store.themeName)
        for (var i = 0; i < list.length; i++) {
          var parts = list[i].split("|")
          if (parts[0] === "hyprland_active_border") return parts[1]
        }
        return look.foreground
      }
      implicitHeight: 304

      function fold(count, row, gap, peek, available) {
        function total(rows) { return rows * row + (rows - 1) * gap }
        if (total(count) <= available) return total(count)
        var full = 0
        while (full < count && total(full + 1) <= available) full++
        while (full > 1 && total(full) + gap + peek > available) full--
        return full < 1 ? Math.max(available, row) : total(full) + gap + peek
      }

      Rectangle {
        id: desk
        x: 12
        y: 12
        width: parent.width - 24
        height: 280
        radius: 10
        color: look.controlSoft
        border.width: 1
        border.color: look.separator
        clip: true

        RoundedImage {
          radius: 9
          anchors.fill: parent
          anchors.margins: 1
          source: window.fileUrl(store.currentWallpaper)
          sourceSize.width: 1400
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
        }

        Item {
          id: card
          visible: spot.aresta
          readonly property real unit: spot.size * spot.zoom
          readonly property bool light: look.background.hslLightness > 0.5
          readonly property color ink: look.foreground
          readonly property color line: Qt.alpha(ink, light ? 0.1 : 0.12)
          readonly property color accentInk: look.accent.hslLightness > 0.6 ? "#000000" : "#ffffff"
          readonly property color rowFill: spot.accentRows ? look.accent : Qt.alpha(light ? "#000000" : "#ffffff", light ? 0.12 : 0.15)
          readonly property color rowInk: spot.accentRows ? accentInk : ink
          readonly property bool divider: spot.filters || spot.list
          readonly property real header: 56 * spot.size
          readonly property real filterBar: spot.filters ? 46 * spot.size : 0
          readonly property real footerBar: spot.footer ? 32 * spot.size : 0
          readonly property real margin: 8 * spot.size
          readonly property real row: 56 * spot.size
          readonly property real peek: Math.round(row * 0.55)
          readonly property real chrome: header + filterBar + footerBar + (spot.footer ? 1 : 0) + (divider ? 1 : 0) + (spot.list ? margin * 2 : 0)
          readonly property real offset: Math.max(spot.gaps, Math.round(spot.screenHeight * 0.2))
          readonly property real rowsHeight: spot.fold(spot.items.length, row, 0, peek,
            Math.min(spot.screenHeight - spot.gaps - offset - chrome, row * 7 + peek, Math.round(spot.screenHeight * 0.7)))
          x: (desk.width - width) / 2
          y: offset * spot.zoom
          width: Math.min(640 * unit, desk.width - 2 * spot.gaps * spot.zoom)
          height: Math.min(chrome + (spot.list ? rowsHeight : 0), spot.screenHeight - 2 * spot.gaps) * spot.zoom

          function px(points) { return points * unit }

          Rectangle {
            anchors.fill: parent
            radius: card.px(25)
            color: spot.translucent ? Qt.alpha(look.background, spot.panelAlpha) : look.background
            border.width: 1
            border.color: spot.translucent ? (card.light ? Qt.rgba(0, 0, 0, 0.14) : Qt.rgba(1, 1, 1, 0.22)) : card.line
          }

          Column {
            anchors.fill: parent

            Item {
              width: parent.width
              height: card.header * spot.zoom

              Text {
                id: glyph
                x: card.px(16)
                anchors.verticalCenter: parent.verticalCenter
                text: ""
                color: card.ink
                opacity: 0.55
                font.family: look.fontFamily
                font.pixelSize: card.px(22)
              }

              Text {
                anchors.left: glyph.right
                anchors.leftMargin: 10 * spot.zoom
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Search...")
                color: card.ink
                opacity: 0.4
                font.family: look.fontFamily
                font.pixelSize: card.px(26)
              }
            }

            Rectangle {
              visible: card.divider
              x: card.px(16)
              width: parent.width - 2 * x
              height: 1
              color: card.line
            }

            Item {
              visible: spot.filters
              width: parent.width
              height: card.filterBar * spot.zoom

              Row {
                x: card.px(14)
                anchors.verticalCenter: parent.verticalCenter
                spacing: card.px(8)

                Repeater {
                  model: spot.items.filter(function(item) { return item.menu || item.provider })

                  Rectangle {
                    id: filter
                    required property var modelData
                    width: card.px(32)
                    height: width
                    radius: width / 2
                    color: Qt.alpha(card.ink, 0.08)

                    Text {
                      anchors.centerIn: parent
                      text: filter.modelData.icon
                      color: card.ink
                      font.family: look.fontFamily
                      font.pixelSize: card.px(16)
                    }
                  }
                }
              }
            }

            Item {
              visible: spot.list
              width: parent.width
              height: (card.rowsHeight + card.margin * 2) * spot.zoom

              Item {
                id: cardRows
                anchors.fill: parent
                anchors.margins: card.margin * spot.zoom
                clip: true

                Column {
                  width: parent.width

                  Repeater {
                    model: spot.items

                    Rectangle {
                      id: cardEntry
                      required property var modelData
                      required property int index
                      readonly property bool current: index === 0
                      readonly property color ink: current ? card.rowInk : card.ink
                      width: cardRows.width
                      height: card.row * spot.zoom
                      radius: card.px(14)
                      color: current ? card.rowFill : "transparent"

                      Text {
                        id: entryIcon
                        x: card.px(10)
                        width: card.px(32)
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: cardEntry.modelData.icon
                        color: cardEntry.ink
                        font.family: look.fontFamily
                        font.pixelSize: card.px(20)
                      }

                      Text {
                        anchors.left: entryIcon.right
                        anchors.leftMargin: card.px(10)
                        anchors.verticalCenter: parent.verticalCenter
                        text: cardEntry.modelData.label
                        color: cardEntry.ink
                        font.family: look.fontFamily
                        font.pixelSize: card.px(18)
                      }

                      Row {
                        visible: cardEntry.current
                        anchors.right: parent.right
                        anchors.rightMargin: card.px(12)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: card.px(6)

                        Text {
                          anchors.verticalCenter: parent.verticalCenter
                          text: cardEntry.modelData.menu || cardEntry.modelData.provider ? qsTr("Open") : qsTr("Run")
                          color: cardEntry.ink
                          opacity: 0.7
                          font.family: look.fontFamily
                          font.pixelSize: card.px(13)
                        }

                        Rectangle {
                          anchors.verticalCenter: parent.verticalCenter
                          width: card.px(20)
                          height: width
                          radius: card.px(5)
                          color: spot.accentRows ? Qt.alpha(cardEntry.ink, 0.14) : card.light ? "#ffffff" : Qt.alpha("#ffffff", 0.12)

                          Text {
                            anchors.centerIn: parent
                            text: "↵"
                            color: cardEntry.ink
                            opacity: !spot.accentRows && card.light ? 0.6 : 1
                            font.family: look.fontFamily
                            font.pixelSize: card.px(13)
                          }
                        }
                      }

                      Text {
                        visible: !cardEntry.current && cardEntry.modelData.menu
                        anchors.right: parent.right
                        anchors.rightMargin: card.px(10)
                        anchors.verticalCenter: parent.verticalCenter
                        text: "›"
                        color: cardEntry.ink
                        opacity: 0.45
                        font.family: look.fontFamily
                        font.pixelSize: card.px(18)
                      }
                    }
                  }
                }
              }

              Rectangle {
                visible: spot.items.length * card.row > card.rowsHeight + 1
                x: cardRows.x + cardRows.width + (cardRows.x - width) / 2
                y: cardRows.y
                width: card.px(3)
                height: cardRows.height * card.rowsHeight / (spot.items.length * card.row)
                radius: width / 2
                color: Qt.alpha(card.ink, 0.3)
              }
            }

            Rectangle {
              visible: spot.footer
              width: parent.width
              height: 1
              color: card.line
            }

            Item {
              visible: spot.footer
              width: parent.width
              height: card.footerBar * spot.zoom

              Row {
                anchors.right: parent.right
                anchors.rightMargin: card.px(16)
                anchors.verticalCenter: parent.verticalCenter
                spacing: card.px(16)

                Repeater {
                  model: spot.list ? ["⌃1–9 filter", "esc close", "↵ open"] : ["⌃1–9 filter", "esc close"]

                  Text {
                    required property string modelData
                    text: modelData
                    color: card.ink
                    opacity: 0.5
                    font.family: look.fontFamily
                    font.pixelSize: card.px(13)
                  }
                }
              }
            }
          }
        }

        Rectangle {
          visible: !spot.aresta
          anchors.fill: parent
          anchors.margins: 1
          radius: 9
          color: Qt.alpha(look.background, 0.5)
        }

        Rectangle {
          id: stock
          visible: !spot.aresta
          readonly property real padding: 18
          readonly property real header: 34
          readonly property real row: 50
          readonly property real gap: 3
          readonly property real rowsHeight: spot.fold(spot.items.length, row, gap, Math.round(row * 0.55),
            Math.min(spot.screenHeight - 2 * spot.gaps - 2 * padding - header - 6, Math.round(spot.screenHeight * 0.7)))
          anchors.centerIn: parent
          width: 300 * spot.zoom
          height: Math.min(2 * padding + header + 6 + rowsHeight, spot.screenHeight - 2 * spot.gaps) * spot.zoom
          radius: spot.rounding * spot.zoom
          color: look.background
          border.width: 1
          border.color: spot.activeBorder

          Column {
            x: stock.padding * spot.zoom
            y: x
            width: parent.width - 2 * x
            spacing: 6 * spot.zoom

            Text {
              height: stock.header * spot.zoom
              verticalAlignment: Text.AlignVCenter
              text: qsTr("Go…")
              color: look.foreground
              opacity: 0.58
              font.family: "monospace"
              font.pixelSize: 16 * spot.zoom
            }

            Item {
              width: parent.width
              height: stock.rowsHeight * spot.zoom
              clip: true

              Column {
                width: parent.width
                spacing: stock.gap * spot.zoom

                Repeater {
                  model: spot.items

                  Rectangle {
                    id: line
                    required property var modelData
                    required property int index
                    readonly property color ink: index === 0 ? look.accent : look.foreground
                    width: parent.width
                    height: stock.row * spot.zoom
                    radius: spot.rounding * spot.zoom
                    color: index === 0 ? Qt.alpha(look.foreground, 0.08) : "transparent"

                    Text {
                      id: lineIcon
                      x: 8 * spot.zoom
                      width: 36 * spot.zoom
                      anchors.verticalCenter: parent.verticalCenter
                      horizontalAlignment: Text.AlignHCenter
                      text: line.modelData.icon
                      color: line.ink
                      font.family: "monospace"
                      font.pixelSize: 18 * spot.zoom
                    }

                    Text {
                      anchors.left: lineIcon.right
                      anchors.leftMargin: 6 * spot.zoom
                      anchors.verticalCenter: parent.verticalCenter
                      text: line.modelData.label
                      color: line.ink
                      font.family: "monospace"
                      font.pixelSize: 16 * spot.zoom
                      font.weight: Font.Medium
                    }

                    Text {
                      visible: line.modelData.menu
                      anchors.right: parent.right
                      anchors.rightMargin: 8 * spot.zoom
                      anchors.verticalCenter: parent.verticalCenter
                      text: "›"
                      color: line.ink
                      opacity: 0.36
                      font.family: "monospace"
                      font.pixelSize: 16 * spot.zoom
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  Component {
    id: switcherRow

    Item {
      id: switcher
      readonly property bool aresta: store.revision >= 0 && store.flag("switcher_enabled")
      readonly property bool translucent: store.revision >= 0 && store.flag("panels_translucent")
      readonly property real panelAlpha: Math.max(0.3, Math.min(1, (store.revision >= 0 ? store.number("panels_opacity") : 70) / 100))
      readonly property bool darkBg: look.background.hslLightness < 0.5
      readonly property color surface: look.mix(0.1)
      readonly property var apps: window.previewApps
      readonly property int selected: 1
      readonly property real padding: 26
      readonly property real paddingTop: 27
      readonly property real cell: 102
      readonly property real gap: 14
      readonly property real naturalWidth: padding * 2 + apps.length * cell + (apps.length - 1) * gap
      readonly property real zoom: Math.min(0.7, (desk.width - 40) / naturalWidth)
      implicitHeight: 214

      function px(points) { return points * zoom }

      Rectangle {
        id: desk
        x: 12
        y: 12
        width: parent.width - 24
        height: 190
        radius: 10
        color: look.controlSoft
        border.width: 1
        border.color: look.separator
        clip: true

        RoundedImage {
          radius: 9
          anchors.fill: parent
          anchors.margins: 1
          source: window.fileUrl(store.currentWallpaper)
          sourceSize.width: 1400
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
        }

        Rectangle {
          id: strip
          anchors.centerIn: parent
          width: switcher.px(switcher.naturalWidth)
          height: switcher.px(156)
          radius: switcher.px(47)
          color: switcher.translucent ? Qt.alpha(switcher.surface, switcher.panelAlpha) : switcher.surface
          border.width: 1
          border.color: switcher.translucent ? (switcher.darkBg ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.14)) : Qt.alpha(look.text, 0.12)

          Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            visible: switcher.translucent
            gradient: Gradient {
              GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, switcher.darkBg ? 0.07 : 0.22) }
              GradientStop { position: 0.45; color: "transparent" }
            }
          }

          Repeater {
            model: switcher.apps

            Item {
              id: slot
              required property var modelData
              required property int index
              x: switcher.px(switcher.padding + index * (switcher.cell + switcher.gap))
              y: switcher.px(switcher.paddingTop)
              width: switcher.px(switcher.cell)
              height: width

              Rectangle {
                anchors.fill: parent
                radius: switcher.px(27)
                visible: slot.index === switcher.selected
                color: Qt.alpha(look.text, 0.28)
              }

              Rectangle {
                anchors.centerIn: parent
                width: switcher.px(78)
                height: width
                radius: switcher.px(18)
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.12)
                gradient: Gradient {
                  GradientStop { position: 0.0; color: slot.modelData.top }
                  GradientStop { position: 1.0; color: slot.modelData.bottom }
                }

                Text {
                  anchors.centerIn: parent
                  text: slot.modelData.glyph
                  color: "#ffffff"
                  font.family: look.fontFamily
                  font.pixelSize: switcher.px(40)
                }
              }
            }
          }

          Text {
            readonly property real center: switcher.px(switcher.padding + switcher.selected * (switcher.cell + switcher.gap) + switcher.cell / 2)
            x: center - width / 2
            y: switcher.px(switcher.paddingTop + switcher.cell + 17) - baselineOffset
            text: switcher.apps[switcher.selected].name
            color: look.text
            font.family: look.fontFamily
            font.pixelSize: switcher.px(13)
            font.weight: Font.DemiBold
          }
        }

        Rectangle {
          visible: !switcher.aresta
          anchors.fill: parent
          anchors.margins: 1
          radius: 9
          color: Qt.alpha(look.background, 0.5)
        }
      }
    }
  }

  Component {
    id: ccRow

    Item {
      id: ccPreview
      readonly property int tick: store.revision
      readonly property bool on: tick >= 0 && store.flag("control_center_enabled")
      readonly property bool halo: tick >= 0 && store.flag("control_center_halo")
      readonly property bool translucent: tick >= 0 && store.flag("panels_translucent")
      readonly property real panelAlpha: Math.max(0.3, Math.min(1, (tick >= 0 ? store.number("panels_opacity") : 70) / 100))
      readonly property bool darkBg: look.background.hslLightness < 0.5
      readonly property real effectiveAlpha: {
        var t = Math.max(0, Math.min(1, (panelAlpha - 0.3) / 0.7))
        return 0.84 + t * 0.15
      }
      readonly property color pillBg: translucent
        ? Qt.alpha(darkBg ? Qt.lighter(look.background, 1.35) : look.background, effectiveAlpha)
        : (halo ? (darkBg ? Qt.lighter(look.background, 1.35) : Qt.darker(look.background, 1.04)) : look.background)
      readonly property color pillBorder: darkBg ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.12)
      readonly property color ink: look.text
      readonly property var barIcons: {
        var all = [
          { key: "cc_bar_network", path: "M1 4.5 Q8 -1.5 15 4.5 M3.5 7 Q8 3.5 12.5 7 M6 9.5 Q8 8 10 9.5" },
          { key: "cc_bar_bluetooth", path: "M5 3 L11 9 L8 11.5 V0.5 L11 3 L5 9" },
          { key: "cc_bar_audio", path: "M2 4.5 H4.5 L8 1.5 V10.5 L4.5 7.5 H2 Z M10.5 4 Q12 6 10.5 8 M12.5 2.5 Q15 6 12.5 9.5" },
          { key: "cc_bar_monitor", path: "M1 6.5 H4.5 L6.5 2 L9.5 10.5 L11.5 6.5 H15" },
          { key: "cc_bar_power", path: "M2.5 2.5 H11.5 Q13 2.5 13 4 V8 Q13 9.5 11.5 9.5 H2.5 Q1 9.5 1 8 V4 Q1 2.5 2.5 2.5 Z M15 5 V7 M3.5 5 H9 V7 H3.5 Z" }
        ]
        return all.filter(function(item) {
          if (item.key === "cc_bar_power" && !window.battery) return false
          return ccPreview.tick >= 0 && (!ccPreview.on || store.flag(item.key))
        })
      }
      function has(key) { return tick >= 0 && store.flag(key) }
      implicitHeight: 278

      Timer {
        id: ccMinute
        property date now: new Date()
        interval: 1000
        running: true
        repeat: true
        onTriggered: now = new Date()
      }

      Rectangle {
        x: 12
        y: 12
        width: parent.width - 24
        height: 254
        radius: 10
        color: look.controlSoft
        border.width: 1
        border.color: look.separator
        clip: true

        RoundedImage {
          radius: 9
          anchors.fill: parent
          anchors.margins: 1
          source: window.fileUrl(store.currentWallpaper)
          sourceSize.width: 1400
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
        }

        Rectangle {
          x: 1
          y: 1
          width: parent.width - 2
          height: 29
          color: Qt.alpha(look.background, (ccPreview.tick >= 0 ? store.number("bar_opacity") : 50) / 100)

          Text {
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Ghostty")
            color: ccPreview.ink
            font.family: look.fontFamily
            font.pixelSize: 12
            font.letterSpacing: 0.15
            font.weight: Font.DemiBold
          }

          Row {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14

            Repeater {
              model: ccPreview.barIcons
              Shape {
                id: ccIcon
                required property var modelData
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 12
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                  strokeColor: ccPreview.ink
                  strokeWidth: 1.4
                  fillColor: "transparent"
                  capStyle: ShapePath.RoundCap
                  joinStyle: ShapePath.RoundJoin
                  PathSvg { path: ccIcon.modelData.path }
                }
              }
            }

            Item {
              visible: ccPreview.on
              anchors.verticalCenter: parent.verticalCenter
              width: 16
              height: 13

              Repeater {
                model: 2
                Rectangle {
                  required property int index
                  y: index * 7
                  width: 16
                  height: 6
                  radius: 3
                  color: "transparent"
                  border.width: 1.2
                  border.color: ccPreview.ink
                  Rectangle { x: parent.index === 0 ? 10.5 : 2.5; y: 1.5; width: 3; height: 3; radius: 1.5; color: ccPreview.ink }
                }
              }
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: Qt.formatDateTime(ccMinute.now, ccPreview.tick >= 0 ? store.text("clock_format") : "")
              color: ccPreview.ink
              font.family: look.fontFamily
              font.pixelSize: 12
            }
          }
        }

        Rectangle {
          visible: ccPreview.on
          anchors.right: parent.right
          anchors.rightMargin: 10
          y: 35
          width: 166 + (ccPreview.halo ? 12 : 0)
          height: Math.min(parent.height - 43, ccBody.implicitHeight + (ccPreview.halo ? 12 : 0))
          radius: ccPreview.halo ? 18 : 0
          color: !ccPreview.halo
            ? "transparent"
            : ccPreview.translucent
              ? Qt.alpha(look.background, Math.max(0.24, Math.min(0.55, ccPreview.panelAlpha * 0.48)))
              : look.background
          border.width: ccPreview.halo ? 1 : 0
          border.color: ccPreview.translucent ? (ccPreview.darkBg ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.12)) : look.separator

          Column {
            id: ccBody
            x: ccPreview.halo ? 6 : 0
            y: ccPreview.halo ? 6 : 0
            width: 166
            spacing: 5

            Row {
              visible: ccPreview.has("cc_wifi") || ccPreview.has("cc_bluetooth") || ccPreview.has("cc_media")
              width: ccBody.width
              spacing: 6

              Column {
                id: ccLinkStack
                readonly property int linkCount: (ccPreview.has("cc_wifi") ? 1 : 0) + (ccPreview.has("cc_bluetooth") ? 1 : 0)
                visible: linkCount > 0
                width: ccPreview.has("cc_media") ? 80 : ccBody.width
                spacing: 6

                Repeater {
                  model: [
                    { key: "cc_wifi", name: qsTr("Wi-Fi"), on: true },
                    { key: "cc_bluetooth", name: qsTr("Bluetooth"), on: true }
                  ].filter(function(item) { return ccPreview.has(item.key) })

                  Rectangle {
                    id: ccLinkPill
                    required property var modelData
                    width: ccLinkStack.width
                    height: ccPreview.has("cc_media") ? (ccLinkStack.linkCount === 1 ? 80 : 37) : 28
                    radius: Math.min(height / 2, 18)
                    color: ccPreview.pillBg
                    border.width: 1
                    border.color: ccPreview.pillBorder

                    Rectangle {
                      id: ccLinkDot
                      x: 5
                      anchors.verticalCenter: parent.verticalCenter
                      width: 18
                      height: 18
                      radius: 9
                      color: ccLinkPill.modelData.on ? (ccPreview.darkBg ? "#ffffff" : look.accent) : look.control
                    }

                    Text {
                      anchors.left: ccLinkDot.right
                      anchors.leftMargin: 5
                      anchors.right: parent.right
                      anchors.rightMargin: 6
                      anchors.verticalCenter: parent.verticalCenter
                      elide: Text.ElideRight
                      text: ccLinkPill.modelData.name
                      color: look.text
                      font.family: look.fontFamily
                      font.pixelSize: 9
                      font.weight: Font.DemiBold
                    }
                  }
                }
              }

              Rectangle {
                visible: ccPreview.has("cc_media")
                width: 80
                height: 80
                radius: 13
                color: ccPreview.pillBg
                border.width: 1
                border.color: ccPreview.pillBorder

                Rectangle {
                  x: 7
                  y: 7
                  width: 20
                  height: 20
                  radius: 5
                  gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: look.accent }
                    GradientStop { position: 0.6; color: "#db34f2" }
                    GradientStop { position: 1.0; color: "#ff9230" }
                  }
                }

                Text {
                  x: 7
                  y: 31
                  width: parent.width - 14
                  elide: Text.ElideRight
                  text: qsTr("Now Playing")
                  color: look.text
                  font.family: look.fontFamily
                  font.pixelSize: 9
                  font.weight: Font.DemiBold
                }

                Row {
                  anchors.horizontalCenter: parent.horizontalCenter
                  anchors.bottom: parent.bottom
                  anchors.bottomMargin: 7
                  spacing: 8

                  Repeater {
                    model: 3
                    Rectangle {
                      width: 5
                      height: 5
                      radius: 2.5
                      color: look.text
                      opacity: 0.72
                    }
                  }
                }
              }
            }

            Row {
              width: ccBody.width
              spacing: 5

              Rectangle {
                visible: ccPreview.has("cc_focus")
                width: ccBody.width - 66
                height: 28
                radius: 14
                color: ccPreview.pillBg
                border.width: 1
                border.color: ccPreview.pillBorder

                Rectangle {
                  id: ccFocusDot
                  x: 5
                  anchors.verticalCenter: parent.verticalCenter
                  width: 18
                  height: 18
                  radius: 9
                  color: look.control
                }

                Text {
                  anchors.left: ccFocusDot.right
                  anchors.leftMargin: 5
                  anchors.right: parent.right
                  anchors.rightMargin: 6
                  anchors.verticalCenter: parent.verticalCenter
                  elide: Text.ElideRight
                  text: qsTr("Focus")
                  color: look.text
                  font.family: look.fontFamily
                  font.pixelSize: 9
                  font.weight: Font.DemiBold
                }
              }

              Item {
                visible: !ccPreview.has("cc_focus")
                width: ccBody.width - 66
                height: 28
              }

              Rectangle {
                width: 28
                height: 28
                radius: 14
                color: ccPreview.darkBg ? "#ffffff" : ccPreview.pillBg
                border.width: 1
                border.color: ccPreview.darkBg ? Qt.rgba(1, 1, 1, 0.95) : ccPreview.pillBorder

                Item {
                  anchors.centerIn: parent
                  width: 10
                  height: 10
                  Rectangle {
                    anchors.fill: parent
                    radius: 5
                    color: "transparent"
                    border.width: 1.2
                    border.color: ccPreview.darkBg ? "#16181c" : look.text
                  }
                  Item {
                    x: 5
                    width: 5
                    height: 10
                    clip: true
                    Rectangle {
                      x: -5
                      width: 10
                      height: 10
                      radius: 5
                      color: ccPreview.darkBg ? "#16181c" : look.text
                    }
                  }
                }
              }

              Rectangle {
                width: 28
                height: 28
                radius: 14
                color: ccPreview.pillBg
                border.width: 1
                border.color: ccPreview.pillBorder

                Rectangle {
                  anchors.centerIn: parent
                  width: 8
                  height: 8
                  radius: 4
                  color: look.text
                  opacity: 0.78
                }
              }
            }

            Repeater {
              model: [
                { key: "cc_display", name: qsTr("Display"), level: 0.72 },
                { key: "cc_sound", name: qsTr("Sound"), level: 0.56 }
              ].filter(function(item) { return ccPreview.has(item.key) })

              Rectangle {
                id: ccSlide
                required property var modelData
                width: ccBody.width
                height: 31
                radius: 14
                color: ccPreview.pillBg
                border.width: 1
                border.color: ccPreview.pillBorder

                Text {
                  x: 9
                  y: 5
                  text: ccSlide.modelData.name
                  color: look.text
                  font.family: look.fontFamily
                  font.pixelSize: 9
                  font.weight: Font.DemiBold
                }

                Rectangle {
                  x: 9
                  y: 20
                  width: parent.width - 18
                  height: 4
                  radius: 2
                  color: Qt.alpha(look.text, 0.18)

                  Rectangle {
                    width: parent.width * ccSlide.modelData.level
                    height: 4
                    radius: 2
                    color: ccPreview.darkBg ? "#ffffff" : "#1f2328"
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
