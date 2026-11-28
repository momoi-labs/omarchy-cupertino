// Copyright (c) 2026 Sebastian Webber
// Licensed under the MIT License. See LICENSE.

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Item {
  id: root

  property string omarchyPath: ""
  property var shell: null
  property var manifest: null
  property var barWidgetRegistry: null
  property var pluginRegistry: null
  property var barConfig: ({})

  readonly property string position: "top"
  readonly property bool vertical: false
  readonly property var settings: {
    var values = { bar_height: 29, bar_opacity: 50, clock_format: "ddd d MMM  HH:mm", status_icon_scale: 120, status_item_width: 38, bar_desktops: false, bar_desktops_position: "menus", bar_desktops_style: "numbers", bar_desktops_occupied_only: false, panels_align_right: true, control_center_enabled: true, cc_wifi: true, cc_bluetooth: true, cc_focus: true, cc_display: true, cc_sound: true, cc_media: true, cc_bar_network: false, cc_bar_bluetooth: false, cc_bar_audio: false, cc_bar_monitor: false, cc_bar_power: true }
    var lines = settingsFile.text().split("\n")
    for (var i = 0; i < lines.length; i++) {
      var match = lines[i].match(/^\s*(\w+)\s*=\s*(.*?)\s*$/)
      if (!match || !(match[1] in values)) continue
      if (typeof values[match[1]] === "boolean") {
        if (match[2] === "true" || match[2] === "false") values[match[1]] = match[2] === "true"
      } else if (typeof values[match[1]] === "string") {
        var text = match[2].match(/^"(.*)"$/)
        if (text) values[match[1]] = text[1]
      } else if (match[2] !== "" && !isNaN(Number(match[2]))) {
        values[match[1]] = Number(match[2])
      }
    }
    return values
  }
  readonly property int barSize: Math.round(settings.bar_height)
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
  readonly property string clockFormat: settings.clock_format
  readonly property color foreground: Commons.Color.bar.text
  readonly property color accentForeground: {
    function channel(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
    var accent = Commons.Color.accent
    return 0.2126 * channel(accent.r) + 0.7152 * channel(accent.g) + 0.0722 * channel(accent.b) > 0.3 ? "#000000" : "#ffffff"
  }
  readonly property color background: Commons.Color.bar.background
  readonly property color urgent: Commons.Color.bar.active

  readonly property string menuWidgetId: barWidgetRegistry && barWidgetRegistry.widgets && barWidgetRegistry.widgets["dev.momoi-labs.aresta.menu"] ? "dev.momoi-labs.aresta.menu" : "omarchy.menu"
  readonly property var leftOnlyIds: ["omarchy.menu", "dev.momoi-labs.aresta.menu", "omarchy.workspaces", "omarchy.active-window", "omarchy.spacer", "omarchy.clock"]
  readonly property string controlCenterId: "dev.momoi-labs.aresta.control-center"
  readonly property bool controlCenter: settings.control_center_enabled && !!barWidgetRegistry && !!barWidgetRegistry.widgets && !!barWidgetRegistry.widgets[controlCenterId]
  readonly property var controlCenterEntry: ({ id: controlCenterId, aresta: true, wifi: settings.cc_wifi, bluetooth: settings.cc_bluetooth, focus: settings.cc_focus, display: settings.cc_display, sound: settings.cc_sound, media: settings.cc_media })
  readonly property var controlCenterIcons: ({ "omarchy.network": "cc_bar_network", "omarchy.bluetooth": "cc_bar_bluetooth", "omarchy.audio": "cc_bar_audio", "omarchy.monitor": "cc_bar_monitor", "omarchy.power": "cc_bar_power" })
  readonly property var sectionOrder: ["left", "centerBegin", "center", "centerEnd", "right", "tray"]

  readonly property var layout: barConfig && barConfig.layout ? barConfig.layout : ({})

  readonly property var statusEntries: {
    var out = {}
    var keys = []
    for (var s = 0; s < sectionOrder.length; s++) {
      var list = layout[sectionOrder[s]]
      if (!Array.isArray(list)) continue
      for (var i = 0; i < list.length; i++) {
        var entry = typeof list[i] === "string" ? { id: list[i] } : list[i]
        if (!entry || !entry.id || entry.type) continue
        if (leftOnlyIds.indexOf(String(entry.id)) !== -1) continue
        if (String(entry.id) === controlCenterId) continue
        var key = String(entry.id)
        while (out[key]) key += "+"
        out[key] = entry
        keys.push(key)
      }
    }
    return { keys: keys, entries: out }
  }

  readonly property var clockEntry: {
    for (var s = 0; s < sectionOrder.length; s++) {
      var list = layout[sectionOrder[s]]
      if (!Array.isArray(list)) continue
      for (var i = 0; i < list.length; i++)
        if (list[i] && list[i].id === "omarchy.clock") return list[i]
    }
    return { id: "omarchy.clock" }
  }

  FileView {
    id: settingsFile
    path: Quickshell.env("HOME") + "/.config/aresta/settings.toml"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoadFailed: settingsRetry.restart()
  }

  Timer {
    id: settingsRetry
    interval: 2000
    onTriggered: settingsFile.reload()
  }

  property var activePopout: null
  property var clickTargets: []
  property var widgetSlots: []
  property var barApis: ({})
  property var tooltipTarget: null
  property string tooltipText: ""

  function settingsFor(entry) {
    var copy = {}
    for (var key in entry) if (key !== "id") copy[key] = entry[key]
    if (entry.id === "omarchy.clock") copy.format = root.clockFormat
    return copy
  }

  function registerClickTarget(target) {
    if (!target || clickTargets.indexOf(target) !== -1) return
    clickTargets = clickTargets.concat([target])
  }

  function unregisterClickTarget(target) {
    clickTargets = clickTargets.filter(function(item) { return item !== target })
  }

  function requestPopout(owner) {
    if (activePopout === owner) return
    if (activePopout) {
      if ("closeForPopoutSwitch" in activePopout) activePopout.closeForPopoutSwitch()
      else if ("close" in activePopout) activePopout.close()
    }
    activePopout = owner
  }

  function releasePopout(owner) {
    if (activePopout === owner) activePopout = null
  }

  function targetBelongsToWindow(target, window) {
    return !!target && !!window && !!target.QsWindow && target.QsWindow.window === window
  }

  function moduleWidgets(id) {
    var items = []
    for (var i = 0; i < widgetSlots.length; i++) {
      var slot = widgetSlots[i]
      if (slot && slot.activeItem && slot.moduleName === id) items.push(slot.activeItem)
    }
    return items
  }

  function findPanelWidget(id) {
    var focused = Hyprland.focusedMonitor ? String(Hyprland.focusedMonitor.name || "") : ""
    var best = null
    var bestRank = -1
    for (var i = 0; i < widgetSlots.length; i++) {
      var slot = widgetSlots[i]
      var item = slot ? slot.activeItem : null
      if (!item || slot.moduleName !== id) continue
      if (typeof item.open !== "function" || typeof item.close !== "function" || item.opened === undefined) continue
      var window = slot.QsWindow ? slot.QsWindow.window : null
      var onFocused = !!window && !!window.screen && window.screen.name === focused
      var rank = (item.opened === true ? 2 : 0) + (onFocused ? 1 : 0)
      if (rank > bestRank) {
        best = item
        bestRank = rank
      }
    }
    return best
  }

  function summonBarWidget(id) {
    var item = findPanelWidget(id)
    if (!item) return false
    item.open()
    return true
  }

  function hideBarWidget(id) {
    var item = findPanelWidget(id)
    if (!item) return false
    item.close()
    return true
  }

  function isBarWidgetOpen(id) {
    var item = findPanelWidget(id)
    return !!item && item.opened === true
  }

  function showTooltip(target, text) {
    tooltipTarget = target
    tooltipText = String(text || "")
    tooltipTimer.restart()
  }

  function hideTooltip(target) {
    if (tooltipTarget !== target) return
    tooltipTimer.stop()
    tooltipTarget = null
    tooltipText = ""
  }

  function run(command) {
    if (command) Util.execDetached(command)
  }

  function entryShellFor(moduleName, firstParty) {
    var facade = root.shell && typeof root.shell.pluginShellForBarEntry === "function"
      ? root.shell.pluginShellForBarEntry(moduleName, moduleName) : null
    if (!firstParty || !facade) return facade
    return entryShellComponent.createObject(root, { facade: facade, host: root.shell })
  }

  function barApiFor(moduleName, firstParty) {
    if (barApis[moduleName]) return barApis[moduleName]
    var api = barApiComponent.createObject(root, {
      pluginId: moduleName,
      moduleName: moduleName,
      shell: root.entryShellFor(moduleName, firstParty),
      _showTooltip: root.showTooltip,
      _hideTooltip: root.hideTooltip,
      _registerClickTarget: root.registerClickTarget,
      _unregisterClickTarget: root.unregisterClickTarget,
      _requestPopout: root.requestPopout,
      _releasePopout: root.releasePopout,
      _targetBelongsToWindow: root.targetBelongsToWindow,
      _moduleWidgets: root.moduleWidgets,
      _run: root.run
    })
    var next = {}
    for (var id in barApis) next[id] = barApis[id]
    next[moduleName] = api
    barApis = next
    return api
  }

  Component {
    id: barApiComponent

    PluginBarApi {
      foreground: root.foreground
      barForeground: root.foreground
      background: root.background
      urgent: root.urgent
      fontFamily: root.fontFamily
      position: root.position
      vertical: root.vertical
      barSize: root.barSize
      activePopout: root.activePopout
      clickTargets: root.clickTargets
      layoutConfig: root.layout
    }
  }

  Component {
    id: entryShellComponent

    QtObject {
      property var facade: null
      property var host: null
      readonly property var barConfig: facade ? facade.barConfig : ({})

      function serviceFor(id) { return facade.serviceFor(id) }
      function firstPartyServiceFor(id) { return host ? host.firstPartyServiceFor(id) : null }
      function summon(id, payloadJson) { return host.summon(id, payloadJson) }
      function hide(id) { return facade.hide(id) }
      function toggle(id, payloadJson) { return facade.toggle(id, payloadJson) }
      function isPluginOpen(id) { return facade.isPluginOpen(id) }
      function updateEntryInline(id, settings) { return facade.updateEntryInline(id, settings) }
    }
  }

  Timer {
    id: tooltipTimer
    interval: 400
  }

  component Desktops: Row {
    id: desktops

    required property var screen
    readonly property var monitor: screen ? Hyprland.monitorFor(screen) : Hyprland.focusedMonitor
    readonly property string monitorName: monitor ? String(monitor.name || "") : ""
    readonly property int activeId: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : -1
    readonly property int base: activeId > 0 ? Math.floor((activeId - 1) / 10) * 10 : 0
    readonly property bool dots: root.settings.bar_desktops_style === "dots"
    readonly property var items: {
      var ids = [base + 1, base + 2, base + 3, base + 4, base + 5]
      var occupied = {}
      var values = Hyprland.workspaces.values
      for (var i = 0; i < values.length; i++) {
        var id = values[i].id
        if (id <= base || id > base + 10) continue
        occupied[id] = values[i].toplevels.values.length > 0
        if (ids.indexOf(id) === -1) ids.push(id)
      }
      ids.sort(function(left, right) { return left - right })
      var out = []
      for (var j = 0; j < ids.length; j++) {
        var item = { id: ids[j], slot: ids[j] - base, current: ids[j] === activeId, occupied: !!occupied[ids[j]] }
        if (root.settings.bar_desktops_occupied_only && !item.occupied && !item.current) continue
        out.push(item)
      }
      return out
    }

    property real wheelAccumulator: 0

    function show(item) {
      if (!item.current) root.run("hyprctl dispatch " + Util.shellQuote("o.workspaces.focus(" + item.slot + ", \"" + monitorName + "\")"))
    }

    function step(delta) {
      var wheel = Util.wheelSteps(wheelAccumulator, delta)
      wheelAccumulator = wheel.remainder
      if (wheel.steps === 0) return
      var index = -1
      for (var i = 0; i < items.length; i++) if (items[i].current) index = i
      if (index === -1) return
      show(items[Math.max(0, Math.min(items.length - 1, index - wheel.steps))])
    }

    visible: root.settings.bar_desktops
    spacing: dots ? 7 : 3
    height: root.barSize

    Connections {
      target: Hyprland
      function onRawEvent(event) {
        var name = event ? String(event.name) : ""
        if (name === "openwindow" || name === "closewindow" || name === "movewindowv2" || name === "workspacev2") Hyprland.refreshWorkspaces()
      }
    }

    Repeater {
      model: desktops.items

      Item {
        id: desktop

        required property var modelData

        width: desktops.dots ? (modelData.current ? 18 : 7) : 20
        height: root.barSize

        Rectangle {
          visible: !desktops.dots && desktop.modelData.current
          anchors.horizontalCenter: parent.horizontalCenter
          y: (parent.height - height) / 2
          width: parent.width
          height: 18
          radius: 5
          color: Commons.Color.accent
        }

        Text {
          visible: !desktops.dots
          anchors.horizontalCenter: parent.horizontalCenter
          y: (parent.height - height) / 2
          text: desktop.modelData.slot === 10 ? "0" : desktop.modelData.slot
          color: desktop.modelData.current ? root.accentForeground : desktop.modelData.occupied ? root.foreground : Qt.alpha(root.foreground, 0.45)
          font.family: root.fontFamily
          font.pixelSize: 12
          font.weight: desktop.modelData.current ? Font.Bold : Font.Medium
        }

        Rectangle {
          visible: desktops.dots
          anchors.horizontalCenter: parent.horizontalCenter
          y: (parent.height - height) / 2
          width: parent.width
          height: 7
          radius: 3.5
          color: desktop.modelData.current ? root.foreground : desktop.modelData.occupied ? Qt.alpha(root.foreground, 0.7) : "transparent"
          border.width: desktop.modelData.current || desktop.modelData.occupied ? 0 : 1.2
          border.color: Qt.alpha(root.foreground, 0.6)
        }

        MouseArea {
          anchors.fill: parent
          anchors.leftMargin: -2
          anchors.rightMargin: -2
          cursorShape: Qt.PointingHandCursor
          onClicked: desktops.show(desktop.modelData)
          onWheel: function(wheel) { desktops.step(wheel.angleDelta.y) }
        }
      }
    }
  }

  component WidgetSlot: Item {
    id: slot

    required property var entry
    readonly property string moduleName: String(entry.id || "")
    readonly property var registered: {
      var widgets = root.barWidgetRegistry ? root.barWidgetRegistry.widgets : null
      return widgets ? widgets[moduleName] || null : null
    }
    readonly property bool firstParty: !!registered && !!registered.metadata && registered.metadata.firstParty === true
    readonly property var settings: root.settingsFor(entry)
    readonly property var activeItem: loader.item

    property real itemScale: 1
    property real cellWidth: 0
    readonly property bool tucked: root.controlCenter && !!root.controlCenterIcons[moduleName] && !root.settings[root.controlCenterIcons[moduleName]]
    readonly property bool alignRight: tucked && root.settings.panels_align_right
    readonly property real scaledWidth: activeItem ? activeItem.implicitWidth * itemScale : 0
    property var labelButton: null
    readonly property bool paddedFigures: labelMetrics.tightBoundingRect("0").height > labelMetrics.capitalHeight
    readonly property bool textLabel: !!labelButton && paddedFigures && labelButton.labelVisible && !labelButton.iconLabel && labelButton.text.indexOf("\n") === -1

    opacity: tucked ? 0 : 1
    enabled: !tucked
    implicitWidth: !tucked && activeItem && activeItem.visible ? Math.max(cellWidth, Math.ceil(scaledWidth)) : 0
    implicitHeight: root.barSize

    function inject() {
      var target = loader.item
      if (!target) return
      if ("fixedEdge" in target) target.fixedEdge = "end"
      if ("bar" in target) target.bar = root.barApiFor(slot.moduleName, slot.firstParty)
      if ("moduleName" in target) target.moduleName = slot.moduleName
      if ("settings" in target) target.settings = slot.settings
      var items = target.children
      for (var i = 0; i < items.length; i++)
        if (items[i].centerFigures) labelButton = items[i]
    }

    onSettingsChanged: inject()
    Component.onCompleted: root.widgetSlots = root.widgetSlots.concat([slot])
    Component.onDestruction: root.widgetSlots = root.widgetSlots.filter(function(item) { return item !== slot })

    FontMetrics {
      id: labelMetrics

      font.family: slot.labelButton ? slot.labelButton.fontFamily : root.fontFamily
      font.pixelSize: slot.labelButton ? slot.labelButton.fontSize : Style.font.body
    }

    Binding {
      target: slot.labelButton
      property: "centerFigures"
      value: false
      when: slot.textLabel
    }

    Loader {
      id: loader

      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: slot.textLabel ? (Math.ceil(labelMetrics.height) / 2 - labelMetrics.ascent + labelMetrics.capitalHeight / 2) * scale : 0
      x: slot.alignRight ? 100000 : Math.round((slot.width - slot.scaledWidth) / 2)
      width: item ? item.implicitWidth : 0
      scale: slot.tucked ? 1 : slot.itemScale
      transformOrigin: Item.Left
      height: item ? item.implicitHeight : 0
      sourceComponent: slot.registered ? slot.registered.component : null
      onItemChanged: slot.labelButton = null
      onLoaded: {
        slot.inject()
        Qt.callLater(slot.inject)
      }
    }
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      PanelWindow {
        id: barWindow

        required property var modelData

        screen: modelData
        anchors { top: true; left: true; right: true }
        implicitHeight: root.barSize
        exclusiveZone: root.barSize
        color: "transparent"
        WlrLayershell.namespace: "aresta-bar"
        WlrLayershell.layer: WlrLayer.Top

        Rectangle {
          anchors.fill: parent
          color: Qt.rgba(root.background.r, root.background.g, root.background.b, root.settings.bar_opacity / 100)
        }

        RowLayout {
          anchors.left: parent.left
          anchors.leftMargin: 12
          anchors.verticalCenter: parent.verticalCenter
          spacing: 10

          WidgetSlot { entry: ({ id: root.menuWidgetId }) }

          Text {
            readonly property var toplevel: ToplevelManager.activeToplevel
            readonly property string appId: toplevel ? String(toplevel.appId || "") : ""
            readonly property var desktopEntry: {
              var revision = DesktopEntries.applications.values.length
              return appId ? DesktopEntries.heuristicLookup(appId) : null
            }

            text: desktopEntry && desktopEntry.name ? desktopEntry.name : appId
            textFormat: Text.PlainText
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: 13
            font.letterSpacing: 0.15
            font.weight: Font.DemiBold
          }

          Desktops {
            screen: barWindow.modelData
            Layout.leftMargin: 6
            visible: root.settings.bar_desktops && root.settings.bar_desktops_position === "menus"
          }
        }

        Desktops {
          anchors.centerIn: parent
          screen: barWindow.modelData
          visible: root.settings.bar_desktops && root.settings.bar_desktops_position === "center"
        }

        RowLayout {
          anchors.right: parent.right
          anchors.rightMargin: 5
          anchors.verticalCenter: parent.verticalCenter
          spacing: 0

          Desktops {
            screen: barWindow.modelData
            Layout.rightMargin: 10
            visible: root.settings.bar_desktops && root.settings.bar_desktops_position === "status"
          }

          Repeater {
            model: ScriptModel { values: root.statusEntries.keys }
            delegate: WidgetSlot {
              required property string modelData
              entry: root.statusEntries.entries[modelData] || ({ id: "" })
              itemScale: root.settings.status_icon_scale / 100
              cellWidth: root.settings.status_item_width
            }
          }

          WidgetSlot {
            visible: root.controlCenter
            entry: root.controlCenter ? root.controlCenterEntry : ({ id: "" })
            itemScale: root.settings.status_icon_scale / 100
            cellWidth: root.settings.status_item_width
          }

          WidgetSlot {
            Layout.leftMargin: 3
            entry: root.clockEntry
          }
        }

        PopupWindow {
          id: tooltipWindow

          visible: !tooltipTimer.running && root.tooltipText !== "" && root.targetBelongsToWindow(root.tooltipTarget, barWindow)
          color: "transparent"
          implicitWidth: Math.ceil(tooltipLabel.implicitWidth + 20)
          implicitHeight: Math.ceil(tooltipLabel.implicitHeight + 12)

          anchor {
            id: tooltipAnchor
            window: barWindow
            adjustment: PopupAdjustment.Slide
            edges: Edges.Top | Edges.Left
            gravity: Edges.Bottom | Edges.Right
            rect.width: 1
            rect.height: 1
            onAnchoring: {
              var target = root.tooltipTarget
              if (!root.targetBelongsToWindow(target, barWindow)) return
              var point = barWindow.contentItem.mapFromItem(target, target.width / 2 - tooltipWindow.implicitWidth / 2, target.height + 6)
              tooltipAnchor.rect.x = Math.round(point.x)
              tooltipAnchor.rect.y = Math.round(point.y)
            }
          }

          Rectangle {
            anchors.fill: parent
            radius: Style.cornerRadius
            color: Commons.Color.tooltip.background
            border.color: Commons.Color.tooltip.border
            border.width: 1

            Text {
              id: tooltipLabel
              anchors.centerIn: parent
              text: root.tooltipText
              textFormat: Text.PlainText
              color: Commons.Color.tooltip.text
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }
        }
      }
    }
  }
}
