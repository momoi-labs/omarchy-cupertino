use std::fs;
use std::io;
use std::path::PathBuf;

use crate::keys;

#[derive(Clone, Debug, PartialEq)]
pub enum Value {
    Number(f64),
    Flag(bool),
    Text(String),
    List(Vec<String>),
}

pub struct Entry {
    pub key: &'static str,
    pub value: Value,
    pub hyprland: bool,
}

fn defaults() -> Vec<Entry> {
    use Value::{Flag, List, Number, Text};
    let hyprland = [
        ("corners_enabled", Flag(true)),
        ("border_enabled", Flag(true)),
        ("traffic_lights_enabled", Flag(true)),
        ("switcher_enabled", Flag(true)),
        ("quit_enabled", Flag(true)),
        ("cycle_enabled", Flag(true)),
        ("quake_enabled", Flag(true)),
        ("window_rounding", Number(16.0)),
        ("window_rounding_power", Number(3.4)),
        ("border_size", Number(1.0)),
        ("border_active_opacity", Number(20.0)),
        ("border_inactive_opacity", Number(10.0)),
        ("shadow_enabled", Flag(true)),
        ("shadow_range", Number(28.0)),
        ("shadow_offset", Number(8.0)),
        ("shadow_active_opacity", Number(35.0)),
        ("shadow_inactive_opacity", Number(19.0)),
        ("traffic_light_size", Number(14.0)),
        ("traffic_lights_position", Text("left".into())),
        ("traffic_lights_grey_inactive", Flag(true)),
        ("traffic_light_icons_on_hover", Flag(true)),
        ("title_align", Text("center".into())),
        ("title_bars_always", Flag(false)),
        ("shortcut_quit", Text("SUPER + Q".into())),
        ("shortcut_cycle", Text("SUPER + code:49".into())),
        ("shortcut_switcher_next", Text("SUPER + code:23".into())),
        (
            "shortcut_switcher_previous",
            Text("SUPER + SHIFT + code:23".into()),
        ),
        (
            "shortcut_quake_toggle",
            Text("SUPER + ALT + code:49".into()),
        ),
        (
            "shortcut_quake_move",
            Text("SUPER + SHIFT + code:49".into()),
        ),
    ];
    let bar = [
        ("bar_height", Number(29.0)),
        ("bar_opacity", Number(50.0)),
        ("clock_format", Text("ddd d MMM  HH:mm".into())),
        ("status_icon_scale", Number(120.0)),
        ("status_item_width", Number(38.0)),
        ("bar_desktops", Flag(false)),
        ("bar_desktops_position", Text("menus".into())),
        ("bar_desktops_style", Text("numbers".into())),
        ("bar_desktops_occupied_only", Flag(false)),
        ("search_size", Number(100.0)),
        ("search_selection", Text("gray".into())),
        ("search_filters", Flag(false)),
        ("search_menu_on_open", Flag(true)),
        ("search_shortcuts", Flag(false)),
        ("search_movable", Flag(true)),
        ("search_position", List(Vec::new())),
        ("search_height", List(Vec::new())),
        ("dock_autohide", Flag(false)),
        ("dock_recents", Flag(true)),
        ("dock_indicators", Flag(true)),
        ("dock_magnification", Flag(true)),
        ("dock_size", Number(58.0)),
        ("light_theme", Text("aresta-light".into())),
        ("dark_theme", Text("aresta-dark".into())),
        ("appearance_auto", Flag(false)),
        ("appearance_auto_schedule", Text("solar".into())),
        ("appearance_auto_light", Text("07:00".into())),
        ("appearance_auto_dark", Text("19:00".into())),
        ("panels_translucent", Flag(true)),
        ("panels_opacity", Number(70.0)),
        ("panels_align_right", Flag(true)),
        ("wallpaper_keep", Flag(true)),
        ("wallpaper_folders", List(Vec::new())),
        ("control_center_enabled", Flag(true)),
        ("control_center_halo", Flag(false)),
        ("cc_wifi", Flag(true)),
        ("cc_bluetooth", Flag(true)),
        ("cc_focus", Flag(true)),
        ("cc_display", Flag(true)),
        ("cc_sound", Flag(true)),
        ("cc_media", Flag(true)),
        ("cc_bar_network", Flag(false)),
        ("cc_bar_bluetooth", Flag(false)),
        ("cc_bar_audio", Flag(false)),
        ("cc_bar_monitor", Flag(false)),
        ("cc_bar_power", Flag(true)),
    ];
    hyprland
        .into_iter()
        .map(|(key, value)| Entry {
            key,
            value,
            hyprland: true,
        })
        .chain(bar.into_iter().map(|(key, value)| Entry {
            key,
            value,
            hyprland: false,
        }))
        .collect()
}

pub struct Settings {
    path: PathBuf,
    entries: Vec<Entry>,
}

impl Settings {
    pub fn path() -> PathBuf {
        let home = std::env::var_os("HOME").unwrap_or_default();
        PathBuf::from(home).join(".config/aresta/settings.toml")
    }

    pub fn load() -> Self {
        let mut settings = Self {
            path: Self::path(),
            entries: defaults(),
        };
        settings.reload();
        settings
    }

    pub fn reload(&mut self) {
        let mut entries = defaults();
        if let Ok(text) = fs::read_to_string(&self.path) {
            for line in text.lines() {
                let Some((key, raw)) = line.split_once('=') else {
                    continue;
                };
                let (key, raw) = (key.trim(), raw.trim());
                if let Some(entry) = entries.iter_mut().find(|entry| entry.key == key)
                    && let Some(value) = parse(&entry.value, raw)
                {
                    entry.value = value;
                }
            }
        }
        self.entries = entries;
    }

    pub fn get(&self, key: &str) -> Option<&Value> {
        self.entries
            .iter()
            .find(|entry| entry.key == key)
            .map(|entry| &entry.value)
    }

    pub fn set(&mut self, key: &str, value: Value) -> Option<bool> {
        let entry = self.entries.iter_mut().find(|entry| entry.key == key)?;
        if std::mem::discriminant(&entry.value) != std::mem::discriminant(&value) {
            return None;
        }
        if entry.value == value {
            return Some(false);
        }
        entry.value = value;
        Some(entry.hyprland)
    }

    pub fn shortcut_in_use(&self, binding: &str, except: &str) -> bool {
        let binding = keys::normalize(binding);
        self.entries.iter().any(|entry| {
            entry.key.starts_with("shortcut_")
                && entry.key != except
                && matches!(&entry.value, Value::Text(text) if keys::normalize(text) == binding)
        })
    }

    pub fn save(&self) -> io::Result<()> {
        let mut text = String::new();
        for entry in &self.entries {
            let value = match &entry.value {
                Value::Number(number) => format!("{number}"),
                Value::Flag(flag) => flag.to_string(),
                Value::Text(text) => quote(text),
                Value::List(items) => {
                    let items: Vec<String> = items.iter().map(|item| quote(item)).collect();
                    format!("[{}]", items.join(", "))
                }
            };
            text.push_str(&format!("{} = {}\n", entry.key, value));
        }
        if let Some(parent) = self.path.parent() {
            fs::create_dir_all(parent)?;
        }
        let temporary = self.path.with_extension("toml.tmp");
        fs::write(&temporary, text)?;
        fs::rename(&temporary, &self.path)
    }
}

fn quote(text: &str) -> String {
    format!("\"{}\"", text.replace('"', ""))
}

fn parse(default: &Value, raw: &str) -> Option<Value> {
    match default {
        Value::Number(_) => raw.parse().ok().map(Value::Number),
        Value::Flag(_) => raw.parse().ok().map(Value::Flag),
        Value::Text(_) => raw
            .strip_prefix('"')
            .and_then(|rest| rest.strip_suffix('"'))
            .map(|text| Value::Text(text.into())),
        Value::List(_) => raw
            .strip_prefix('[')
            .and_then(|rest| rest.strip_suffix(']'))
            .map(|inner| {
                Value::List(
                    inner
                        .split('"')
                        .skip(1)
                        .step_by(2)
                        .map(String::from)
                        .collect(),
                )
            }),
    }
}
