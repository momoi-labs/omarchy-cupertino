.pragma library

function read(text) {
  var values = { panels_translucent: true, panels_opacity: 70, panels_align_right: true, control_center_enabled: true, control_center_halo: false }
  var lines = String(text).split("\n")
  for (var i = 0; i < lines.length; i++) {
    var match = lines[i].match(/^\s*(\w+)\s*=\s*(.*?)\s*$/)
    if (!match || !(match[1] in values)) continue
    if (typeof values[match[1]] === "boolean") {
      if (match[2] === "true" || match[2] === "false") values[match[1]] = match[2] === "true"
    } else if (match[2] !== "" && !isNaN(Number(match[2]))) {
      values[match[1]] = Number(match[2])
    }
  }
  return values
}

function inUse(values, options) {
  return values.control_center_enabled && !!options && options.aresta === true
}
