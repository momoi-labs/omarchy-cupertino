pragma ComponentBehavior: Bound

// Copyright (c) 2026 Sebastian Webber
// Copyright (c) 2026 Rafael Bertholdo
// Copyright (c) David Heinemeier Hansson
// Licensed under the MIT License. See LICENSE.

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "DockModel.js" as DockModel

PanelWindow {
  id: window

  property var dock: null

  readonly property var monitor: Hyprland.monitorFor(screen)
  readonly property var workspace: monitor ? monitor.activeWorkspace : null
  readonly property int workspaceId: workspace ? workspace.id : -1
  readonly property int fullscreenMode: {
    var mode = 0
    var toplevels = Hyprland.toplevels.values
    for (var i = 0; i < toplevels.length; i++) {
      var toplevel = toplevels[i]
      if (!toplevel.workspace || toplevel.workspace.id !== workspaceId) continue
      var ipc = toplevel.lastIpcObject
      mode = Math.max(mode, ipc && ipc.fullscreen ? ipc.fullscreen : 0)
    }
    return mode
  }
  readonly property bool shown: !!dock && fullscreenMode < 2
  readonly property bool autohide: !!dock && dock.autohide
  property bool revealed: false
  readonly property bool menuOpen: menuItem !== null || trashMenu
  readonly property bool tucked: autohide && !(revealed || menuOpen || dragging)
  readonly property bool contentShown: shown && !tucked

  readonly property bool dark: !!dock && dock.dark
  readonly property color glass: dark ? Qt.rgba(52 / 255, 52 / 255, 56 / 255, 0.5) : Qt.rgba(246 / 255, 246 / 255, 246 / 255, 0.5)
  readonly property color glassBorder: dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.6)
  readonly property color glassEdge: dark ? Qt.rgba(0, 0, 0, 0.5) : Qt.rgba(0, 0, 0, 0.14)
  readonly property color glassShine: dark ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.45)
  readonly property color dotColor: dark ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(0, 0, 0, 0.74)
  readonly property color separatorColor: dark ? Qt.rgba(1, 1, 1, 0.24) : Qt.rgba(0, 0, 0, 0.2)
  readonly property color tipBackground: dark ? Qt.rgba(48 / 255, 48 / 255, 50 / 255, 0.92) : Qt.rgba(240 / 255, 240 / 255, 240 / 255, 0.9)
  readonly property color tipText: dark ? "#dddddd" : "#272727"

  readonly property string cellSignature: dock
    ? DockModel.cellList(dock.pinnedKeys, dock.otherKeys, dock.minimized.map(function(item) { return item.address })).join("\n") : ""
  property var cells: []
  onCellSignatureChanged: cells = cellSignature ? cellSignature.split("\n") : []
  Component.onCompleted: cells = cellSignature ? cellSignature.split("\n") : []

  readonly property int separators: cells.filter(function(cell) { return cell.indexOf("separator:") === 0 }).length
  readonly property int iconSize: DockModel.iconSize(dock ? dock.preferredSize : 58, Math.max(1, cells.length - separators), separators, screen ? screen.width : 1920)
  readonly property int gap: Math.round(iconSize * 0.14)
  readonly property int pitch: iconSize + gap
  readonly property int indicatorHeight: 14
  readonly property int panelHeight: iconSize + 24
  readonly property int panelRadius: Math.min(26, Math.round(panelHeight * 0.32))
  readonly property int edgeGap: 6

  readonly property FontMetrics fontProbe: FontMetrics {}

  function doubleEmboldens(family) {
    fontProbe.font = Qt.font({ family: family, pixelSize: 40, weight: Font.Normal })
    var normalRect = fontProbe.tightBoundingRect("Appearance")
    var normalAdvance = fontProbe.advanceWidth("Appearance")
    fontProbe.font = Qt.font({ family: family, pixelSize: 40, weight: 699 })
    var boldRect = fontProbe.tightBoundingRect("Appearance")
    var boldAdvance = fontProbe.advanceWidth("Appearance")
    fontProbe.font = Qt.font({ family: family, pixelSize: 40, weight: Font.Bold })
    var heavyRect = fontProbe.tightBoundingRect("Appearance")
    var heavyAdvance = fontProbe.advanceWidth("Appearance")
    var hasRealBold = boldRect.width > normalRect.width + 0.5 || boldAdvance > normalAdvance + 0.5
    return hasRealBold
      && Math.abs(heavyAdvance - boldAdvance) < 0.5
      && heavyRect.width > boldRect.width + 0.5
      && heavyRect.height > boldRect.height + 0.5
  }

  readonly property string fontFamily: {
    var families = Qt.fontFamilies()
    var preferred = ["SF Pro Text", "SF Pro", "System Font", "Inter", "Noto Sans"]
    for (var i = 0; i < preferred.length; i++)
      if (families.indexOf(preferred[i]) !== -1 && !doubleEmboldens(preferred[i])) return preferred[i]
    return "sans-serif"
  }
  readonly property real peak: dock && dock.magnify ? (iconSize >= 40 ? 1.5 : 1.9) : 1
  readonly property var centers: DockModel.cellCenters(cells, iconSize)
  readonly property bool magnifying: overZone && !dragging && !menuOpen && contentShown
  property bool overZone: false
  property real pointerX: 0
  onOverZoneChanged: if (!overZone && autohide) hideTimer.restart()
  property real strength: magnifying ? 1 : 0
  Behavior on strength { NumberAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic } }

  property int dragIndex: -1
  property int dropIndex: -1
  property real dragOffset: 0
  readonly property bool dragging: dragIndex >= 0

  property var menuItem: null
  property var menuCell: null
  property var hoveredCell: null
  property bool trashMenu: false
  property bool trashConfirm: false

  onShownChanged: {
    if (shown) return
    closeMenu()
    window.revealed = false
  }
  onAutohideChanged: window.revealed = false

  function openMenu(item, cell) {
    window.trashMenu = false
    window.menuItem = item
    window.menuCell = cell
  }

  function openTrashMenu(cell) {
    window.menuItem = null
    window.trashConfirm = false
    window.trashMenu = true
    window.menuCell = cell
  }

  function closeMenu() {
    window.menuItem = null
    window.trashMenu = false
    window.trashConfirm = false
    window.menuCell = null
    if (window.autohide) hideTimer.restart()
  }

  function endDrag() {
    window.dragIndex = -1
    window.dropIndex = -1
    window.dragOffset = 0
  }

  function origin() {
    var reserved = monitor && monitor.lastIpcObject && monitor.lastIpcObject.reserved ? monitor.lastIpcObject.reserved : [0, 0, 0, 0]
    return Qt.point(reserved[0] || 0, screen.height - (reserved[3] || 0) - window.height)
  }

  function covers(screenX, screenY) {
    var at = window.origin()
    var x = screenX - at.x - body.x
    var y = screenY - at.y - body.y
    return window.shown && x >= -window.pitch && x <= body.width + window.pitch && y >= -window.pitch
  }

  function revealFor(screenX, screenY) {
    if (window.autohide && window.covers(screenX, screenY)) {
      window.revealed = true
      hideTimer.restart()
    }
  }

  visible: !remapGuard.remapping
  color: "transparent"
  WlrLayershell.namespace: "aresta-dock"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  exclusionMode: ExclusionMode.Normal
  exclusiveZone: window.shown && window.dock.configLoaded && !window.autohide ? window.panelHeight + window.edgeGap * 2 : 0
  onExclusiveZoneChanged: window.dock.keepWindowsClear()

  anchors {
    bottom: true
    left: true
    right: true
  }

  implicitHeight: window.edgeGap + window.panelHeight + Math.max(Math.ceil(window.iconSize * 0.9) + 48, Style.spacing.popupRowHeight * 4 + Style.spacing.sm * 2 + 16)

  mask: Region {
    item: window.contentShown ? zone : null

    Region { item: window.shown && window.autohide ? edgeTrigger : null }
    Region { item: menu.visible ? menu : null }
  }

  Timer {
    id: hideTimer
    interval: 150
    onTriggered: {
      if (!window.overZone && !edgeHover.hovered && !window.menuOpen && !window.dragging) window.revealed = false
    }
  }

  Item {
    id: edgeTrigger
    y: window.height - height
    width: window.width
    height: 3

    HoverHandler {
      id: edgeHover
      onHoveredChanged: {
        if (hovered) window.revealed = true
        else hideTimer.restart()
      }
    }
  }

  ScreenMoveRemap {
    id: remapGuard
    window: window
  }

  HyprlandFocusGrab {
    active: window.menuOpen
    windows: [window]
    onCleared: window.closeMenu()
  }

  Item {
    id: zone
    x: body.x
    width: body.width
    y: body.y - (window.magnifying ? Math.ceil(window.iconSize * (window.peak - 1)) : 0)
    height: window.height - y
  }

  HoverHandler {
    onHoveredChanged: if (!hovered) window.overZone = false
    onPointChanged: {
      var at = point.position
      window.overZone = hovered && at.x >= zone.x && at.x <= zone.x + zone.width && at.y >= zone.y
      if (window.overZone) window.pointerX = at.x - window.width / 2
    }
  }

  Item {
    id: body

    readonly property real centered: (window.width - width) / 2
    property real tuck: window.tucked ? window.panelHeight + window.edgeGap + 48 : 0

    Behavior on tuck {
      id: tuckMotion
      enabled: window.shown
      NumberAnimation {
        duration: Style.duration(tuckMotion.targetValue > 0 ? 160 : 220)
        easing.type: Easing.OutCubic
      }
    }

    width: row.width + 20
    height: window.panelHeight
    x: window.strength > 0 ? centered : Math.round(centered)
    y: window.height - height - window.edgeGap + tuck
    opacity: window.shown ? 1 : 0

    Item {
      id: shadowSource
      anchors.fill: parent
      anchors.margins: -48
      visible: false
      layer.enabled: true

      RectangularShadow {
        x: 48
        y: 48
        width: body.width
        height: body.height
        radius: window.panelRadius
        offset.y: 12
        blur: 32
        color: Qt.rgba(0, 0, 0, 0.24)
      }
    }

    Item {
      id: shadowMask
      anchors.fill: shadowSource
      visible: false
      layer.enabled: true

      Rectangle {
        x: 48
        y: 48
        width: body.width
        height: body.height
        radius: window.panelRadius
      }
    }

    MultiEffect {
      anchors.fill: shadowSource
      source: shadowSource
      maskEnabled: true
      maskInverted: true
      maskSource: shadowMask
    }

    Rectangle {
      anchors.fill: parent
      anchors.margins: -1
      radius: window.panelRadius + 1
      color: "transparent"
      border.width: 1
      border.color: Qt.alpha(window.glassEdge, window.glassEdge.a * 0.6)
    }

    Rectangle {
      anchors.fill: parent
      radius: window.panelRadius
      color: window.glass
      border.width: 1
      border.color: window.glassBorder
    }

    Rectangle {
      x: window.panelRadius
      y: 1
      width: parent.width - window.panelRadius * 2
      height: 1
      color: window.glassShine
    }

    Row {
      id: row
      x: 10
      height: parent.height

      Repeater {
        model: window.cells

        delegate: Cell {}
      }
    }
  }

  Rectangle {
    id: tip

    readonly property var cell: window.hoveredCell
    readonly property bool wanted: !!cell && cell.name !== "" && window.contentShown && !window.menuOpen && !window.dragging

    visible: opacity > 0
    opacity: wanted ? 1 : 0
    width: tipLabel.implicitWidth + 24
    height: tipLabel.implicitHeight + 10
    radius: height / 2
    color: window.tipBackground
    border.width: 1
    border.color: Qt.alpha(window.glassEdge, window.glassEdge.a * 0.6)
    x: cell ? Math.max(4, Math.min(window.width - width - 4, Math.round(body.x + row.x + cell.x + cell.width / 2 - width / 2))) : 0
    y: cell ? Math.round(body.y + window.panelHeight - window.indicatorHeight - window.iconSize * cell.factor - 11 - height) : 0

    Behavior on opacity { NumberAnimation { duration: Style.duration(100) } }

    Text {
      id: tipLabel
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: tip.cell ? tip.cell.name : ""
      color: window.tipText
      elide: Text.ElideRight
      width: Math.min(implicitWidth, 320)
      font.family: window.fontFamily
      font.pixelSize: 13
      font.weight: Font.Medium
    }
  }

  component Cell: Item {
    id: cell

    required property int index
    required property string modelData

    readonly property bool separator: modelData.indexOf("separator:") === 0
    readonly property string kind: separator ? "separator" : modelData.split(":")[0]
    readonly property string key: modelData.indexOf(":") >= 0 ? modelData.slice(modelData.indexOf(":") + 1) : ""
    readonly property var item: kind === "app" && window.dock ? window.dock.itemFor(key) : null
    readonly property var minimizedItem: kind === "window" && window.dock ? window.dock.minimizedFor(key) : null
    readonly property var owner: minimizedItem && window.dock ? window.dock.itemFor(minimizedItem.key) : null
    readonly property int windowCount: item ? item.windows.length : 0
    readonly property bool launching: kind === "app" && !!window.dock && window.dock.isLaunching(key)
    readonly property int pinIndex: item && item.pinned ? index - 1 : -1
    readonly property bool lifted: pinIndex >= 0 && window.dragIndex === pinIndex
    readonly property bool hovered: mouse.containsMouse && !window.dragging
    readonly property real factor: separator ? 1
      : 1 + (DockModel.magnification(window.pointerX - (window.centers[index] || 0), window.iconSize, window.peak) - 1) * window.strength
    readonly property real size: window.iconSize * factor
    readonly property string name: kind === "apps" ? "Apps"
      : kind === "downloads" ? "Downloads"
      : kind === "trash" ? "Trash"
      : kind === "app" && window.dock ? window.dock.nameFor(item)
      : minimizedItem ? (minimizedItem.title || window.dock.nameFor(owner))
      : ""
    readonly property string iconSource: !window.dock ? ""
      : kind === "app" ? window.dock.iconFor(item)
      : kind === "window" && owner ? window.dock.iconFor(owner)
      : kind === "downloads" ? Quickshell.iconPath("folder-download", "folder")
      : kind === "trash" ? Quickshell.iconPath(window.dock.trashFull ? "user-trash-full" : "user-trash", "user-trash")
      : ""
    readonly property real shift: pinIndex < 0 || !window.dragging ? 0
      : lifted ? window.dragOffset
      : (window.dragIndex < pinIndex && pinIndex <= window.dropIndex) ? -window.pitch
      : (window.dropIndex <= pinIndex && pinIndex < window.dragIndex) ? window.pitch
      : 0
    property real displayedShift: shift
    property point pressPoint
    property bool dragged: false
    property real pulse: 1

    Behavior on displayedShift {
      enabled: window.dragging && !cell.lifted
      NumberAnimation { duration: Style.duration(150); easing.type: Easing.OutCubic }
    }

    width: separator ? 19 : size + window.gap
    height: window.panelHeight
    z: lifted ? 1 : 0

    onHoveredChanged: {
      if (hovered) window.hoveredCell = cell
      else if (window.hoveredCell === cell) window.hoveredCell = null
    }
    Component.onDestruction: if (window.hoveredCell === cell) window.hoveredCell = null

    Rectangle {
      visible: cell.separator
      x: 9
      y: parent.height - window.indicatorHeight - Math.round(window.iconSize * 0.08) - height
      width: 1
      height: Math.round(window.iconSize * 0.84)
      color: window.separatorColor
    }

    Item {
      id: face
      visible: !cell.separator
      x: (cell.width - width) / 2
      y: cell.height - window.indicatorHeight - height
      width: cell.size
      height: cell.size
      opacity: cell.launching ? cell.pulse : 1
      transform: Translate { x: cell.displayedShift }

      Image {
        visible: cell.kind !== "apps" && cell.kind !== "window"
        anchors.fill: parent
        sourceSize: Qt.size(window.iconSize * 2, window.iconSize * 2)
        source: visible ? cell.iconSource : ""
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        mipmap: true
      }

      Rectangle {
        visible: cell.kind === "apps"
        anchors.fill: parent
        anchors.margins: parent.width * 0.1
        radius: parent.width * 0.2
        gradient: Gradient {
          GradientStop { position: 0; color: "#a3a8ae" }
          GradientStop { position: 1; color: "#6c7177" }
        }

        Grid {
          anchors.centerIn: parent
          columns: 3
          spacing: face.width * 0.09

          Repeater {
            model: cell.kind === "apps" ? 9 : 0

            delegate: Rectangle {
              width: face.width * 0.13
              height: width
              radius: width / 2
              color: "#ffffff"
            }
          }
        }
      }

      Item {
        visible: cell.kind === "window"
        anchors.fill: parent

        Rectangle {
          id: miniature
          opacity: thumb.hasContent ? 0 : 1
          x: parent.width * 0.05
          y: parent.height * 0.17
          width: parent.width * 0.9
          height: parent.height * 0.7
          radius: parent.width * 0.09
          color: window.dark ? "#2c2c2e" : "#ffffff"
          border.width: 1
          border.color: window.dark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.18)
          clip: true

          Rectangle {
            x: 1
            y: 1
            width: parent.width - 2
            height: face.height * 0.13
            topLeftRadius: miniature.radius - 1
            topRightRadius: miniature.radius - 1
            color: window.dark ? "#3a3a3c" : "#e8e8ea"
          }

          Column {
            id: lines
            x: face.width * 0.09
            y: face.height * 0.2
            width: parent.width - x * 2
            spacing: face.height * 0.055

            Repeater {
              model: cell.kind === "window" ? [1, 0.7, 0.45] : []

              delegate: Rectangle {
                required property real modelData
                width: lines.width * modelData
                height: Math.max(1, face.height * 0.04)
                radius: height / 2
                color: window.dark ? "#ffffff" : "#000000"
                opacity: 0.22
              }
            }
          }
        }

        ScreencopyView {
          id: thumb
          anchors.centerIn: miniature
          captureSource: cell.kind === "window" && window.dock ? window.dock.toplevelFor(cell.key) : null
          constraintSize: Qt.size(miniature.width, miniature.height)
          live: false
        }

        Rectangle {
          visible: thumb.hasContent
          anchors.fill: thumb
          anchors.margins: -1
          color: "transparent"
          border.width: 1
          border.color: window.dark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.18)
        }

        Image {
          x: parent.width - width + parent.width * 0.04
          y: parent.height - height - parent.height * 0.02
          width: parent.width * 0.47
          height: width
          sourceSize: Qt.size(window.iconSize, window.iconSize)
          source: cell.kind === "window" ? cell.iconSource : ""
          fillMode: Image.PreserveAspectFit
          asynchronous: true
          smooth: true
          mipmap: true
        }
      }
    }

    Rectangle {
      visible: cell.windowCount > 0 && !cell.lifted && !!window.dock && window.dock.showIndicators
      width: 4
      height: 4
      radius: 2
      color: window.dotColor
      x: (cell.width - width) / 2 + cell.displayedShift
      y: cell.height - window.indicatorHeight / 2 - height / 2
    }

    SequentialAnimation {
      running: cell.launching && !Style.reduceMotion
      loops: Animation.Infinite
      onRunningChanged: if (!running) cell.pulse = 1

      NumberAnimation { target: cell; property: "pulse"; from: 1; to: 0.5; duration: Style.duration(500); easing.type: Easing.InOutSine }
      NumberAnimation { target: cell; property: "pulse"; to: 1; duration: Style.duration(500); easing.type: Easing.InOutSine }
    }

    MouseArea {
      id: mouse
      anchors.fill: parent
      enabled: !cell.separator
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

      onPressed: function(event) {
        cell.dragged = false
        if (event.button === Qt.LeftButton) cell.pressPoint = cell.mapToItem(null, event.x, event.y)
      }

      onPositionChanged: function(event) {
        if (cell.pinIndex < 0 || !(mouse.pressedButtons & Qt.LeftButton)) return
        var delta = cell.mapToItem(null, event.x, event.y).x - cell.pressPoint.x
        if (!window.dragging) {
          if (Math.abs(delta) < 8) return
          window.closeMenu()
          window.dropIndex = cell.pinIndex
          window.dragIndex = cell.pinIndex
        }
        if (!cell.lifted) return
        cell.dragged = true
        window.dragOffset = delta
        window.dropIndex = DockModel.dropIndex(cell.pinIndex, delta, window.pitch, window.dock.pinnedKeys.length)
      }

      onReleased: {
        if (!cell.lifted) return
        var from = window.dragIndex
        var to = window.dropIndex
        window.endDrag()
        window.dock.movePin(from, to)
      }

      onCanceled: if (cell.lifted) window.endDrag()

      onClicked: function(event) {
        if (cell.dragged) {
          cell.dragged = false
          return
        }
        if (event.button === Qt.RightButton) {
          if (cell.kind === "app") window.openMenu(cell.item, cell)
          else if (cell.kind === "trash") window.openTrashMenu(cell)
          return
        }
        window.closeMenu()
        if (cell.kind === "apps") window.dock.openApps()
        else if (cell.kind === "downloads") window.dock.openDownloads()
        else if (cell.kind === "trash") window.dock.openTrash()
        else if (cell.kind === "window") window.dock.restore(cell.key)
        else if (event.button === Qt.MiddleButton) window.dock.launch(cell.item)
        else window.dock.activate(cell.item)
      }
    }
  }

  BorderSurface {
    id: menu

    readonly property var item: window.menuItem
    readonly property bool hasEntry: !!item && !!window.dock && !!window.dock.entryFor(item)
    readonly property bool running: !!item && item.windows.length > 0
    readonly property real center: window.menuCell ? body.x + row.x + window.menuCell.x + window.menuCell.width / 2 : 0

    visible: window.contentShown && (!!item || window.trashMenu)
    width: Math.max(Style.space(140), menuColumn.implicitWidth) + padding * 2
    height: menuColumn.implicitHeight + padding * 2
    x: Math.max(4, Math.min(window.width - menu.width - 4, Math.round(menu.center - menu.width / 2)))
    y: body.y - 8 - height
    radius: Style.cornerRadius
    color: Commons.Color.popups.background
    borderSpec: Border.surfaceSpec("popups", "border", Commons.Color.popups.border, Style.normalBorderWidth)
    padding: Style.spacing.sm

    Column {
      id: menuColumn
      x: menu.contentLeftInset
      y: menu.contentTopInset
      width: menu.width - menu.contentLeftInset - menu.contentRightInset

      MenuRow {
        visible: menu.hasEntry && menu.running
        text: Commons.I18n.t("dock.newWindow")
        onTriggered: window.dock.launch(menu.item)
      }

      MenuRow {
        visible: menu.hasEntry
        text: menu.item && menu.item.pinned ? Commons.I18n.t("dock.removeFromDock") : Commons.I18n.t("dock.keepInDock")
        onTriggered: window.dock.setPinned(menu.item.key, !menu.item.pinned)
      }

      MenuRow {
        visible: menu.running
        text: Commons.I18n.t("dock.quit")
        onTriggered: window.dock.quit(menu.item)
      }

      MenuRow {
        visible: window.trashMenu && !window.trashConfirm
        text: "Open"
        onTriggered: window.dock.openTrash()
      }

      MenuRow {
        visible: window.trashMenu && !window.trashConfirm
        enabled: !!window.dock && window.dock.trashFull
        keepOpen: true
        text: "Empty Trash…"
        onTriggered: window.trashConfirm = true
      }

      MenuRow {
        visible: window.trashMenu && window.trashConfirm
        enabled: false
        text: {
          var count = window.dock ? window.dock.trashCount : 0
          return "Delete " + count + (count === 1 ? " item" : " items") + " for good?"
        }
      }

      MenuRow {
        visible: window.trashMenu && window.trashConfirm
        destructive: true
        text: "Empty Trash"
        onTriggered: window.dock.emptyTrash()
      }

      MenuRow {
        visible: window.trashMenu && window.trashConfirm
        text: "Cancel"
      }
    }
  }

  component MenuRow: Rectangle {
    id: menuRow

    property string text: ""
    property bool keepOpen: false
    property bool destructive: false
    signal triggered()

    width: parent ? parent.width : 0
    height: visible ? Style.spacing.popupRowHeight : 0
    radius: Style.cornerRadius
    color: menuRow.enabled && rowMouse.containsMouse ? Style.hoverFill : "transparent"

    Text {
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: parent.left
      anchors.leftMargin: Style.spacing.controlPaddingX
      textFormat: Text.PlainText
      text: menuRow.text
      color: menuRow.destructive ? Commons.Color.urgent : Commons.Color.popups.text
      opacity: menuRow.enabled ? 1 : 0.5
      font.family: window.fontFamily
      font.pixelSize: Style.font.body
    }

    MouseArea {
      id: rowMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: menuRow.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: {
        if (!menuRow.enabled) return
        menuRow.triggered()
        if (!menuRow.keepOpen) window.closeMenu()
      }
    }
  }
}
