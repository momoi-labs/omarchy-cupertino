import { test } from "node:test"
import assert from "node:assert/strict"
import { spawnSync } from "node:child_process"
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { fileURLToPath } from "node:url"

const config = fileURLToPath(new URL("../hypr/aresta.lua", import.meta.url))

const HARNESS = `
local shadow, hidden = {}, {}
local function stub()
  return setmetatable({}, {
    __index = function(self, key)
      local value = stub()
      rawset(self, key, value)
      return value
    end,
    __call = function() return stub() end,
  })
end
hl = stub()
o = stub()
hl.config = function(values)
  for key, value in pairs(values.decoration and values.decoration.shadow or {}) do
    shadow[key] = value
  end
end
hl.window_rule = function(rule)
  if rule.no_shadow ~= nil then
    hidden[#hidden + 1] = rule.match.class .. "=" .. tostring(rule.no_shadow)
  end
end
dofile(arg[1])
print(tostring(shadow.enabled))
print(tostring(shadow.range))
print(tostring(shadow.offset))
print(table.concat(hidden, ","))
`

function load(settings) {
  const home = mkdtempSync(join(tmpdir(), "aresta-shadow-"))
  try {
    mkdirSync(join(home, ".config/aresta"), { recursive: true })
    writeFileSync(join(home, ".config/aresta/settings.toml"), `traffic_lights_enabled = false\n${settings}`)
    const result = spawnSync("lua", ["-", config], { input: HARNESS, env: { ...process.env, HOME: home }, encoding: "utf8" })
    assert.equal(result.status, 0, result.stderr)
    const [enabled, range, offset, hidden] = result.stdout.split("\n")
    return { enabled, range, offset, hidden }
  } finally {
    rmSync(home, { recursive: true, force: true })
  }
}

test("shadows off keeps Hyprland shadows on and hides them on every window", () => {
  assert.deepEqual(load("shadow_enabled = false\n"), { enabled: "true", range: "nil", offset: "nil", hidden: ".*=true" })
})

test("shadows on sets the Aresta shadow and hides it on no window", () => {
  assert.deepEqual(load("shadow_enabled = true\nshadow_range = 30\nshadow_offset = 6\n"), {
    enabled: "true",
    range: "30",
    offset: "0 6",
    hidden: "",
  })
})
