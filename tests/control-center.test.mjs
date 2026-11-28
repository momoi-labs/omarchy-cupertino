import { test } from "node:test"
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import vm from "node:vm"

const source = readFileSync(new URL("../control-center/PanelSettings.js", import.meta.url), "utf8")
const panel = {}
vm.runInNewContext(source.replace(/^\.pragma library$/m, ""), panel)

const arestaBar = { aresta: true, wifi: true }
const omarchyBar = {}
const shown = (text, options) => panel.inUse(panel.read(text), options)

test("shows in the Aresta bar while the switch is on", () => {
  assert.equal(shown("", arestaBar), true)
  assert.equal(shown("control_center_enabled = true\n", arestaBar), true)
})

test("hides when the switch is off and comes back when it is on again", () => {
  assert.equal(shown("control_center_enabled = false\n", arestaBar), false)
  assert.equal(shown("control_center_enabled = true\n", arestaBar), true)
})

test("stays out of every other bar", () => {
  assert.equal(shown("control_center_enabled = true\n", omarchyBar), false)
  assert.equal(shown("control_center_enabled = true\n", { wifi: false }), false)
  assert.equal(shown("control_center_enabled = true\n", undefined), false)
})

test("keeps the panel settings it read before", () => {
  const values = panel.read("panels_opacity = 40\npanels_translucent = false\npanels_opacity = wide\nother = 1\n")
  assert.equal(values.panels_opacity, 40)
  assert.equal(values.panels_translucent, false)
  assert.equal(values.panels_align_right, true)
  assert.equal("other" in values, false)
})
