.pragma library

var MINIMIZED_WORKSPACE = "special:minimized"
var RECENTS_LIMIT = 3

function normalizeId(value) {
  var id = String(value || "").trim()
  if (id.slice(-8) === ".desktop") id = id.slice(0, -8)
  return id
}

function pinnedIds(dockConfig, defaultsConfig) {
  var source = dockConfig && Array.isArray(dockConfig.pinned) ? dockConfig.pinned
    : (defaultsConfig && Array.isArray(defaultsConfig.pinned) ? defaultsConfig.pinned : [])
  var ids = []
  for (var i = 0; i < source.length; i++) {
    var id = normalizeId(source[i])
    if (id && ids.indexOf(id) === -1) ids.push(id)
  }
  return ids
}

function isDockWindow(window) {
  if (!window || !window.key) return false
  if (window.minimized === true) return true
  return window.hasEntry === true && window.workspaceId >= 1
}

function isMinimizedWorkspace(name) {
  return String(name || "") === MINIMIZED_WORKSPACE
}

function claimingEntryId(appId, entries) {
  var id = String(appId || "")
  if (!id) return ""
  var list = entries || []
  var flag = "--app-id=" + id
  for (var i = 0; i < list.length; i++) {
    var words = String(list[i].execString || "").split(/\s+/)
    if (words.indexOf(flag) >= 0) return list[i].id
  }
  if (id.indexOf("org.omarchy.") !== 0) return ""
  var command = id.slice("org.omarchy.".length)
  for (var j = 0; j < list.length; j++) {
    var program = String((list[j].command || [])[0] || "")
    if (list[j].runInTerminal && program.slice(program.lastIndexOf("/") + 1) === command) return list[j].id
  }
  return ""
}

function buildItems(pinned, windows) {
  var items = []
  var byKey = {}

  function itemFor(key, isPinned) {
    if (!byKey[key]) {
      byKey[key] = { key: key, pinned: isPinned, windows: [] }
      items.push(byKey[key])
    }
    return byKey[key]
  }

  for (var i = 0; i < (pinned || []).length; i++) {
    if (pinned[i]) itemFor(pinned[i], true)
  }

  for (var j = 0; j < (windows || []).length; j++) {
    var window = windows[j]
    if (isDockWindow(window)) itemFor(window.key, false).windows.push(window)
  }

  return items
}

function orderWithKeyAt(order, key, index) {
  var keys = (order || []).filter(function(other) { return other !== key })
  keys.splice(Math.max(0, Math.min(keys.length, index)), 0, key)
  return keys
}

function dropIndex(fromIndex, offset, slotSize, count) {
  if (count <= 0 || !(slotSize > 0)) return fromIndex
  var target = fromIndex + Math.round(offset / slotSize)
  return Math.max(0, Math.min(count - 1, target))
}

function pickWindow(windows, workspaceId) {
  var list = windows || []
  if (list.length === 0) return -1

  function rank(window) {
    if (window.minimized) return 1
    return window.workspaceId === workspaceId ? 0 : 2
  }

  var order = list.map(function(window, index) { return index })
  order.sort(function(a, b) { return rank(list[a]) - rank(list[b]) || a - b })

  for (var i = 0; i < order.length; i++) {
    if (list[order[i]].activated) return order[(i + 1) % order.length]
  }
  return order[0]
}

function recentsAfter(recents, opened, pinned) {
  var result = []
  var candidates = (opened || []).slice().reverse().concat(recents || [])
  for (var i = 0; i < candidates.length && result.length < RECENTS_LIMIT; i++) {
    var key = candidates[i]
    if (key && (pinned || []).indexOf(key) === -1 && result.indexOf(key) === -1) result.push(key)
  }
  return result
}

function openedKeys(items, seen) {
  var keys = []
  for (var i = 0; i < (items || []).length; i++) {
    var item = items[i]
    if (!item.pinned && item.windows.length > 0 && (seen || []).indexOf(item.key) === -1) keys.push(item.key)
  }
  return keys
}

function runningKeys(items) {
  return (items || []).filter(function(item) { return item.windows.length > 0 }).map(function(item) { return item.key })
}

function otherKeys(items, recents, showRecents) {
  var keys = []
  for (var i = 0; i < (items || []).length; i++) {
    if (!items[i].pinned && items[i].windows.length > 0) keys.push(items[i].key)
  }
  if (!showRecents) return keys
  var pinned = (items || []).filter(function(item) { return item.pinned }).map(function(item) { return item.key })
  var shown = recentsAfter(recents, [], pinned)
  for (var j = 0; j < shown.length; j++) {
    if (keys.indexOf(shown[j]) === -1) keys.push(shown[j])
  }
  return keys
}

function minimizedFrom(tags) {
  var list = tags || []
  for (var i = 0; i < list.length; i++) {
    var match = String(list[i]).match(/^omarchy-minimized-from-(\d+)\*?$/)
    if (match) return Number(match[1])
  }
  return -1
}

function minimizedItems(windows) {
  var items = []
  for (var i = 0; i < (windows || []).length; i++) {
    var window = windows[i]
    if (!window || window.minimized !== true || !window.address) continue
    items.push({
      address: window.address,
      key: window.key,
      title: String(window.title || ""),
      workspace: minimizedFrom(window.tags)
    })
  }
  return items
}

function restoreWorkspace(item, activeWorkspaceId) {
  return item && item.workspace >= 1 ? item.workspace : activeWorkspaceId
}

function iconScore(path) {
  var own = /\/(hicolor|pixmaps)\//.test(path)
  var match = String(path).match(/\/(\d+)x\d+(?:@(\d+)x?)?\//)
  var size = match ? Number(match[1]) * (match[2] ? Number(match[2]) : 1) : 0
  var score = size
  if (/\.svg$/.test(path)) score = own ? 1100000 : 100000
  else if (!match) score = own ? 64 : 1
  else if (own && size >= 256) score = 1000000 + size
  return /\/HighContrast\//.test(path) ? score / 1000000 : score
}

function largestIcons(paths) {
  var best = {}
  for (var i = 0; i < (paths || []).length; i++) {
    var path = String(paths[i] || "").trim()
    if (!path) continue
    var name = path.slice(path.lastIndexOf("/") + 1).replace(/\.(svg|png)$/, "")
    var score = iconScore(path)
    if (!best[name] || score > best[name].score) best[name] = { path: path, score: score }
  }
  var index = {}
  for (var key in best) index[key] = best[key].path
  return index
}

function parseSettings(text, defaults) {
  var values = {}
  for (var key in defaults) values[key] = defaults[key]
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var match = lines[i].match(/^\s*(\w+)\s*=\s*(.*?)\s*$/)
    if (!match || !(match[1] in values)) continue
    var current = values[match[1]]
    if (typeof current === "boolean") {
      if (match[2] === "true" || match[2] === "false") values[match[1]] = match[2] === "true"
    } else if (match[2] !== "" && !isNaN(Number(match[2]))) {
      values[match[1]] = Number(match[2])
    }
  }
  return values
}

function iconSize(preferred, slots, separators, screenWidth) {
  var available = screenWidth - 124 - separators * 19
  if (slots * (preferred + 8) <= available) return preferred
  return Math.max(20, Math.floor(available / slots / 1.14))
}

function magnification(distance, size, peak) {
  var reach = size * 1.14 * 2.7
  var offset = Math.abs(distance)
  if (!(peak > 1) || offset >= reach) return 1
  var wave = Math.cos(offset / reach * Math.PI / 2)
  return 1 + (peak - 1) * wave * wave
}

function cellList(pinned, others, minimized) {
  var cells = ["apps"]
  var i
  for (i = 0; i < (pinned || []).length; i++) cells.push("app:" + pinned[i])
  if ((others || []).length > 0) cells.push("separator:others")
  for (i = 0; i < (others || []).length; i++) cells.push("app:" + others[i])
  cells.push("separator:places")
  for (i = 0; i < (minimized || []).length; i++) cells.push("window:" + minimized[i])
  cells.push("downloads", "trash")
  return cells
}

function cellCenters(cells, size) {
  var pitch = size + Math.round(size * 0.14)
  var widths = (cells || []).map(function(cell) { return cell.indexOf("separator:") === 0 ? 19 : pitch })
  var total = widths.reduce(function(sum, width) { return sum + width }, 0)
  var centers = []
  var at = -total / 2
  for (var i = 0; i < widths.length; i++) {
    centers.push(at + widths[i] / 2)
    at += widths[i]
  }
  return centers
}
