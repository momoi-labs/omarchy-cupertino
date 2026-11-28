import { test } from "node:test"
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import vm from "node:vm"

const source = readFileSync(new URL("../dock/DockModel.js", import.meta.url), "utf8")
const model = {}
vm.runInNewContext(source.replace(/^\.pragma library$/m, ""), model)

const plain = value => JSON.parse(JSON.stringify(value))

const open = (key, extra = {}) => ({ key, hasEntry: true, workspaceId: 1, address: "0x" + key, title: key, tags: [], ...extra })

test("pins keep the stored order without duplicates", () => {
  assert.deepEqual(plain(model.pinnedIds({ pinned: ["firefox.desktop", "kitty", "firefox", ""] }, null)), ["firefox", "kitty"])
  assert.deepEqual(plain(model.pinnedIds(null, { pinned: ["nautilus"] })), ["nautilus"])
  assert.deepEqual(plain(model.pinnedIds({}, {})), [])
})

test("a pin moves to the dropped position", () => {
  assert.deepEqual(plain(model.orderWithKeyAt(["a", "b", "c"], "c", 0)), ["c", "a", "b"])
  assert.deepEqual(plain(model.orderWithKeyAt(["a", "b", "c"], "a", 9)), ["b", "c", "a"])
  assert.equal(model.dropIndex(0, 130, 66, 3), 2)
  assert.equal(model.dropIndex(2, -500, 66, 3), 0)
})

test("items list pins first and attach windows to their app", () => {
  const items = plain(model.buildItems(["firefox", "kitty"], [open("kitty"), open("gimp"), open("kitty", { address: "0x2" })]))
  assert.deepEqual(items.map(item => [item.key, item.pinned, item.windows.length]), [["firefox", true, 0], ["kitty", true, 2], ["gimp", false, 1]])
  assert.deepEqual(plain(model.runningKeys(items)), ["kitty", "gimp"])
})

test("recents keep the last 3 unpinned apps, newest first, without duplicates", () => {
  assert.deepEqual(plain(model.recentsAfter(["a", "b", "c"], ["d"], [])), ["d", "a", "b"])
  assert.deepEqual(plain(model.recentsAfter(["a", "b"], ["b"], [])), ["b", "a"])
  assert.deepEqual(plain(model.recentsAfter(["a", "b", "c"], ["x", "y"], ["a"])), ["y", "x", "b"])
  assert.deepEqual(plain(model.recentsAfter(["a", "a", "b", "c", "d"], [], [])), ["a", "b", "c"])
})

test("only newly opened unpinned apps count as opened", () => {
  const items = model.buildItems(["firefox"], [open("firefox"), open("gimp"), open("mpv")])
  assert.deepEqual(plain(model.openedKeys(items, ["gimp"])), ["mpv"])
})

test("the second zone shows running apps, then recents that are not shown yet", () => {
  const items = model.buildItems(["firefox"], [open("gimp")])
  assert.deepEqual(plain(model.otherKeys(items, ["gimp", "mpv", "firefox"], true)), ["gimp", "mpv"])
  assert.deepEqual(plain(model.otherKeys(items, ["gimp", "mpv"], false)), ["gimp"])
})

test("each minimized window is its own item with the workspace it came from", () => {
  const windows = [
    open("kitty", { address: "0xa", title: "one", minimized: true, tags: ["omarchy-minimized-from-3*"] }),
    open("kitty", { address: "0xb", title: "two", minimized: true, tags: ["other", "omarchy-minimized-from-5"] }),
    open("gimp"),
  ]
  assert.deepEqual(plain(model.minimizedItems(windows)), [
    { address: "0xa", key: "kitty", title: "one", workspace: 3 },
    { address: "0xb", key: "kitty", title: "two", workspace: 5 },
  ])
})

test("a minimized window goes back to its workspace, or to the active one", () => {
  assert.equal(model.restoreWorkspace({ workspace: 4 }, 2), 4)
  assert.equal(model.restoreWorkspace({ workspace: -1 }, 2), 2)
  assert.equal(model.minimizedFrom(["omarchy-minimized-from-x"]), -1)
})

test("the largest icon wins", () => {
  const icons = plain(model.largestIcons([
    "/usr/share/icons/hicolor/16x16/apps/firefox.png",
    "/usr/share/icons/hicolor/256x256/apps/firefox.png",
    "/usr/share/icons/hicolor/48x48/apps/firefox.png",
    "/usr/share/icons/hicolor/64x64@2x/apps/gimp.png",
    "/usr/share/icons/hicolor/96x96/apps/gimp.png",
    "/usr/share/icons/hicolor/512x512/apps/mpv.png",
    "/usr/share/icons/hicolor/scalable/apps/mpv.svg",
    "/usr/share/icons/HighContrast/256x256/apps/kitty.png",
    "/usr/share/icons/hicolor/128x128/apps/kitty.png",
    "/usr/share/icons/HighContrast/16x16/apps/contrast.png",
    "/usr/share/icons/HighContrast/256x256/apps/contrast.png",
    "/usr/share/icons/hicolor/128x128/apps/medium.png",
    "/usr/share/icons/Papirus/256x256/apps/medium.png",
    "/usr/share/icons/Adwaita/scalable/apps/only-themed.svg",
    "/usr/share/icons/hicolor/64x64/apps/small.png",
    "/usr/share/icons/Papirus/256x256/apps/small.png",
    "/usr/share/icons/hicolor/32x32/apps/legacy.png",
    "/usr/share/pixmaps/legacy.png",
  ]))
  assert.equal(icons.small, "/usr/share/icons/Papirus/256x256/apps/small.png")
  assert.equal(icons.legacy, "/usr/share/pixmaps/legacy.png")
  assert.equal(icons.kitty, "/usr/share/icons/hicolor/128x128/apps/kitty.png")
  assert.equal(icons.contrast, "/usr/share/icons/HighContrast/256x256/apps/contrast.png")
  assert.equal(icons.medium, "/usr/share/icons/Papirus/256x256/apps/medium.png")
  assert.equal(icons["only-themed"], "/usr/share/icons/Adwaita/scalable/apps/only-themed.svg")
  assert.equal(icons.firefox, "/usr/share/icons/hicolor/256x256/apps/firefox.png")
  assert.equal(icons.gimp, "/usr/share/icons/hicolor/64x64@2x/apps/gimp.png")
  assert.equal(icons.mpv, "/usr/share/icons/hicolor/scalable/apps/mpv.svg")
})

test("settings read from the file and fall back to the defaults", () => {
  const defaults = { dock_autohide: false, dock_size: 58 }
  const text = "bar_opacity = 50\ndock_autohide = true\ndock_size = 44\n"
  assert.deepEqual(plain(model.parseSettings(text, defaults)), { dock_autohide: true, dock_size: 44 })
  assert.deepEqual(plain(model.parseSettings("dock_size = big\n", defaults)), defaults)
})

test("cells follow the dock order and drop the first separator without a second zone", () => {
  assert.deepEqual(plain(model.cellList(["firefox"], ["gimp"], ["0xa"])), ["apps", "app:firefox", "separator:others", "app:gimp", "separator:places", "window:0xa", "downloads", "trash"])
  assert.deepEqual(plain(model.cellList(["firefox"], [], [])), ["apps", "app:firefox", "separator:places", "downloads", "trash"])
})

test("icons shrink when the dock does not fit the screen", () => {
  assert.equal(model.iconSize(58, 10, 1, 1920), 58)
  assert.ok(model.iconSize(58, 40, 2, 1280) < 58)
  assert.equal(model.iconSize(58, 400, 2, 1280), 20)
})

test("magnification peaks under the pointer and fades with distance", () => {
  assert.equal(model.magnification(0, 58, 1.5), 1.5)
  assert.ok(model.magnification(60, 58, 1.5) < 1.5)
  assert.equal(model.magnification(1000, 58, 1.5), 1)
  assert.equal(model.magnification(0, 58, 1), 1)
})
