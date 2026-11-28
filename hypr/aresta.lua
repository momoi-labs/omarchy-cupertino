-- Copyright (c) 2026 Sebastian Webber
-- Copyright (c) 2026 Rafael Bertholdo
-- Copyright (c) 2026 Renan Tonheiro
-- Licensed under the MIT License. See LICENSE.

local TITLEBARS = "/usr/lib/omarchy-hyprland-titlebars/titlebars.so"

local LIGHTS = {
  ["×"] = { order = 1, bg = "rgb(ff5f57)" },
  ["−"] = { order = 2, bg = "rgb(febc2e)" },
  ["□"] = { order = 3, bg = "rgb(28c840)" },
}
local LIGHT_COUNT = 3

local settings = {
  corners_enabled = true,
  border_enabled = true,
  traffic_lights_enabled = true,
  switcher_enabled = true,
  quit_enabled = true,
  cycle_enabled = true,
  quake_enabled = true,
  window_rounding = 16,
  window_rounding_power = 3.4,
  border_size = 1,
  border_active_opacity = 20,
  border_inactive_opacity = 10,
  shadow_enabled = true,
  shadow_range = 28,
  shadow_offset = 8,
  shadow_active_opacity = 35,
  shadow_inactive_opacity = 19,
  traffic_light_size = 14,
  traffic_lights_position = "left",
  traffic_lights_grey_inactive = true,
  traffic_light_icons_on_hover = true,
  title_align = "center",
  title_bars_always = false,
  shortcut_quit = "SUPER + Q",
  shortcut_cycle = "SUPER + code:49",
  shortcut_switcher_next = "SUPER + code:23",
  shortcut_switcher_previous = "SUPER + SHIFT + code:23",
  shortcut_quake_toggle = "SUPER + ALT + code:49",
  shortcut_quake_move = "SUPER + SHIFT + code:49",
}

local settings_file = io.open(os.getenv("HOME") .. "/.config/aresta/settings.toml", "r")
if settings_file then
  for line in settings_file:lines() do
    local key, raw = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
    local current = key and settings[key]
    if current ~= nil then
      local value
      if type(current) == "string" then
        value = raw:match('^"(.*)"$')
      elseif type(current) == "boolean" then
        if raw == "true" then value = true elseif raw == "false" then value = false end
      else
        value = tonumber(raw)
      end
      if value ~= nil then
        settings[key] = value
      end
    end
  end
  settings_file:close()
end

local function bind(key, description, action, options)
  if settings[key] ~= "" then
    o.bind(settings[key], description, action, options)
  end
end

local function alpha(percent)
  return string.format("%02x", math.floor(math.max(0, math.min(100, percent)) * 255 / 100 + 0.5))
end

local BUTTON_SIZE = math.floor(settings.traffic_light_size)

if settings.border_enabled then
  hl.config({
    general = {
      border_size = math.floor(settings.border_size),
      col = {
        active_border = "rgba(ffffff" .. alpha(settings.border_active_opacity) .. ")",
        inactive_border = "rgba(ffffff" .. alpha(settings.border_inactive_opacity) .. ")",
      },
    },
  })
end

if settings.corners_enabled then
  hl.config({
    decoration = {
      rounding = math.floor(settings.window_rounding),
      rounding_power = settings.window_rounding_power,
    },
  })
end

if settings.shadow_enabled then
  hl.config({
    decoration = {
      shadow = {
        enabled = true,
        range = math.floor(settings.shadow_range),
        render_power = 3,
        offset = "0 " .. math.floor(settings.shadow_offset),
        color = "rgba(000000" .. alpha(settings.shadow_active_opacity) .. ")",
        color_inactive = "rgba(000000" .. alpha(settings.shadow_inactive_opacity) .. ")",
      },
    },
  })
end

local MINIMIZED = "special:minimized"

local function target(window)
  return "address:" .. tostring(window.address)
end

hl.on("window.open", function(window)
  if window.class == "aresta-settings" and window.floating then
    hl.dispatch(hl.dsp.window.resize({ x = 1040, y = 690, relative = false, window = target(window) }))
    hl.dispatch(hl.dsp.window.center({ window = target(window) }))
  end
end)

local function app_windows(class, visible_only)
  local windows = {}
  for _, window in ipairs(hl.get_windows()) do
    local workspace = window.workspace and window.workspace.name
    if window.class == class and window.mapped
        and not (visible_only and workspace == MINIMIZED) then
      windows[#windows + 1] = window
    end
  end
  return windows
end

local apps = {}

function apps.quit()
  local active = hl.get_active_window()
  if not active then
    return
  end
  for _, window in ipairs(app_windows(active.class)) do
    hl.dispatch(hl.dsp.window.close({ window = target(window) }))
  end
end

function apps.cycle()
  local active = hl.get_active_window()
  if not active then
    return
  end
  local windows = app_windows(active.class, true)
  if #windows < 2 then
    return
  end
  table.sort(windows, function(a, b)
    return tostring(a.address) < tostring(b.address)
  end)
  for index, window in ipairs(windows) do
    if tostring(window.address) == tostring(active.address) then
      local next_window = windows[index % #windows + 1]
      hl.dispatch(hl.dsp.focus({ window = target(next_window) }))
      return
    end
  end
end

package.loaded["aresta.apps"] = apps

local SWITCHER = "aresta-switcher"
local RECORDER = "aresta-record"
local MODIFIER_KEYS = {
  SUPER = { codes = { [133] = true, [134] = true }, names = { "Super_L", "Super_R" } },
  ALT = { codes = { [64] = true, [108] = true }, names = { "Alt_L", "Alt_R" } },
  CTRL = { codes = { [37] = true, [105] = true }, names = { "Control_L", "Control_R" } },
}
local switcher = { open = false, hold = MODIFIER_KEYS.SUPER }

local function emit(name)
  hl.dispatch(hl.dsp.global("aresta:" .. name))
end

local function switcher_step(name, key)
  local hold = MODIFIER_KEYS[settings[key]:match("^(%u+) %+")] or MODIFIER_KEYS.SUPER
  return function()
    if not switcher.open then
      switcher.open = true
      switcher.hold = hold
      hl.dispatch(hl.dsp.submap(SWITCHER))
    end
    emit(name)
  end
end

local function switcher_finish(name)
  if not switcher.open then
    return
  end
  switcher.open = false
  hl.dispatch(hl.dsp.submap("reset"))
  emit(name)
end

function switcher.activate(address)
  local window = hl.get_window("address:" .. address)
  if not window then
    return
  end
  local workspace = window.workspace and window.workspace.name
  if workspace == MINIMIZED then
    local active = hl.get_active_workspace()
    if not active or active.id < 1 then
      return
    end
    hl.dispatch(hl.dsp.window.move({ workspace = tostring(active.id), window = target(window) }))
  end
  hl.dispatch(hl.dsp.focus({ window = target(window) }))
  hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top", window = target(window) }))
end

switcher.finish = switcher_finish

package.loaded["aresta.switcher"] = switcher

hl.define_submap(SWITCHER, function()
  if settings.shortcut_switcher_next ~= "" then
    hl.bind(settings.shortcut_switcher_next, switcher_step("next", "shortcut_switcher_next"), { repeating = true })
  end
  if settings.shortcut_switcher_previous ~= "" then
    hl.bind(settings.shortcut_switcher_previous, switcher_step("previous", "shortcut_switcher_previous"), { repeating = true })
  end
  hl.bind("code:9", function() switcher_finish("cancel") end, { ignore_mods = true })
end)

hl.define_submap(RECORDER, function()
  hl.bind("SUPER + CTRL + ALT + code:9", hl.dsp.submap("reset"))
end)

hl.on("input.keyboard.key", function(keycode, _, value)
  if not switcher.open or value ~= 0 or not switcher.hold.codes[keycode] then
    return
  end
  hl.timer(function()
    if not hl.is_key_down(switcher.hold.names[1]) and not hl.is_key_down(switcher.hold.names[2]) then
      switcher_finish("commit")
    end
  end, { timeout = 1, type = "oneshot" })
end)

hl.layer_rule({ match = { namespace = "^" .. SWITCHER .. "$" }, no_anim = true, animation = "none" })

for _, button in ipairs({ "272", "273" }) do
  hl.bind("mouse:" .. button, function() emit("dock-mouse-" .. button) end, { non_consuming = true, ignore_mods = true })
  hl.bind("mouse:" .. button, function() emit("dock-mouse-" .. button) end, { release = true, non_consuming = true, ignore_mods = true })
end

if settings.switcher_enabled then
  hl.unbind("SUPER + TAB")
  hl.unbind("SUPER + SHIFT + TAB")
  bind("shortcut_switcher_next", "Switch apps", switcher_step("next", "shortcut_switcher_next"), { repeating = true })
  bind("shortcut_switcher_previous", "Switch apps backwards", switcher_step("previous", "shortcut_switcher_previous"), { repeating = true })
end

if settings.quit_enabled then
  hl.unbind("SUPER + Q")
  bind("shortcut_quit", "Quit app (close all its windows)", apps.quit)
end

if settings.cycle_enabled then
  hl.unbind("SUPER + grave")
  bind("shortcut_cycle", "Cycle windows of the same app", apps.cycle)
end

if settings.quake_enabled then
  hl.unbind("SUPER + SHIFT + grave")
  bind("shortcut_quake_toggle", "Toggle Quake console", hl.dsp.workspace.toggle_special("qconsole"))
  bind("shortcut_quake_move", "Move window to Quake console", hl.dsp.window.move({ workspace = "special:qconsole", follow = false }))
end

hl.layer_rule({ match = { namespace = "^aresta-bar$" }, no_anim = true, animation = "none" })
hl.layer_rule({ match = { namespace = "^(aresta-dock|aresta-dock-apps)$" }, no_anim = true, animation = "none" })

if not settings.traffic_lights_enabled or package.loaded["hypr.titlebars"] then
  return
end

local BUTTON_POSITION = settings.traffic_lights_position == "right" and "right" or "left"

local config = hl.config
hl.config = function(values)
  local bars = values and values.plugin and values.plugin.hyprbars
  if bars then
    bars.bar_buttons_alignment = BUTTON_POSITION
    bars.bar_text_align = settings.title_align
    bars.button_rounding = BUTTON_SIZE // 2
    bars.icon_on_hover = settings.traffic_light_icons_on_hover
    bars.inactive_button_color = settings.traffic_lights_grey_inactive and "rgba(8e8e9399)" or "rgba(00000000)"
    bars.bar_button_padding = 8
    if settings.title_bars_always then
      bars.workspace_tag = ""
    end
  end
  return config(values)
end

local function wrap_add_button(hyprbars)
  if not hyprbars or hyprbars.__traffic_lights then
    return
  end
  local add_button = hyprbars.add_button
  local pending = {}
  local lights_added = false

  hyprbars.add_button = function(button)
    local light = button and LIGHTS[button.icon]
    if not light then
      return add_button(button)
    end
    if lights_added then
      return
    end

    button.bg_color = light.bg
    button.fg_color = "rgba(00000099)"
    button.size = BUTTON_SIZE
    pending[light.order] = button

    local count = 0
    for _ in pairs(pending) do
      count = count + 1
    end
    if count == LIGHT_COUNT then
      lights_added = true
      for i = 1, LIGHT_COUNT do
        add_button(pending[i])
      end
      pending = {}
    end
  end
  hyprbars.__traffic_lights = true
end

local load = hl.plugin.load
hl.plugin.load = function(path, ...)
  local result = load(path, ...)
  if path == TITLEBARS then
    wrap_add_button(hl.plugin.hyprbars)
  end
  return result
end

local function titlebars_installed()
  local file = io.open(TITLEBARS, "r")
  if not file then
    return false
  end
  file:close()
  return true
end

local function theme_colors()
  local colors = {}
  local file = io.open(os.getenv("HOME") .. "/.local/state/omarchy/current/theme/colors.toml", "r")
  if file then
    for line in file:lines() do
      local key, value = line:match('^%s*([%w_]+)%s*=%s*"#(%x%x%x%x%x%x)"')
      if key then
        colors[key] = "rgb(" .. value .. ")"
      end
    end
    file:close()
  end

  local background = colors.background or "rgb(1a1b26)"
  local titlebar = colors.lighter_background
  if not titlebar or titlebar == background then
    titlebar = colors.selection or background
  end

  return {
    foreground = colors.foreground or "rgb(c0caf5)",
    titlebar = titlebar,
  }
end

if settings.title_bars_always and titlebars_installed() then
  hl.plugin.load(TITLEBARS)
  if hl.plugin.hyprbars then
    local colors = theme_colors()
    local window = [[window = "address:%WINDOW%"]]
    hl.config({
      plugin = {
        hyprbars = {
          enabled = true,
          workspace_tag = "",
          bar_height = 30,
          bar_color = colors.titlebar,
          col = { text = colors.foreground },
          bar_text_font = "monospace",
          bar_text_size = 12,
          bar_text_weight = "normal",
          bar_text_align = "left",
          bar_buttons_alignment = "right",
          bar_part_of_window = true,
          bar_precedence_over_border = true,
          bar_padding = 10,
          bar_button_padding = 8,
          button_rounding = 0,
          icon_on_hover = false,
          inactive_button_color = colors.titlebar,
          on_double_click = "hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"toggle\", " .. window .. " })'",
        },
      },
    })
    for _, button in ipairs({
      { icon = "×", action = "hyprctl dispatch 'hl.dsp.window.close({ " .. window .. " })'" },
      { icon = "□", action = "hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"toggle\", " .. window .. " })'" },
      { icon = "−", action = "omarchy-hyprland-window-minimize %WINDOW%" },
    }) do
      hl.plugin.hyprbars.add_button({
        bg_color = colors.titlebar,
        fg_color = colors.foreground,
        size = 20,
        icon = button.icon,
        action = button.action,
      })
    end
  end
end
