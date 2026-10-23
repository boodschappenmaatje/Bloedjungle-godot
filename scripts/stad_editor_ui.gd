class_name StadEditorUI
extends RefCounted
## Alleen de stadseditor: gedeelde stijlen en eenmaal gerasterde lijniconen.

const PANEL := Color(0.065, 0.08, 0.075, 0.89)
const BORDER := Color(0.31, 0.36, 0.31, 0.60)
const GOLD := Color("d8b45d")
const INK := Color("eee8d6")
const MUTED := Color("a7ad9b")
const GREEN := Color("80b768")
static var _styles := {}
static var _icons := {}
static var _fonts := {}


static func font(weight := 600) -> Font:
	if not _fonts.has(weight):
		_fonts[weight] = load("res://assets/fonts/Barlow-%s.ttf" % ("SemiBold" if weight >= 600 else "Medium"))
	return _fonts[weight]


static func panel(margin := 8) -> StyleBoxFlat:
	var key := "panel_%d" % margin
	if not _styles.has(key):
		var sb := UI.box(PANEL, BORDER, 1, 12, margin)
		sb.shadow_color = Color(0, 0, 0, 0.22)
		sb.shadow_size = 8
		sb.shadow_offset = Vector2(0, 3)
		_styles[key] = sb
	return _styles[key]


static func button(b: Button, selected := false, primary := false) -> void:
	var key := "primary" if primary else "selected" if selected else "button"
	if not _styles.has(key):
		var bg := GOLD if primary else Color(0.19, 0.23, 0.16, 0.75) if selected else Color(0.11, 0.135, 0.12, 0.34)
		var sb := UI.box(bg, GOLD if selected or primary else Color(0.30, 0.35, 0.29, 0.30), 1, 8, 6)
		_styles[key] = sb
		var hover := sb.duplicate() as StyleBoxFlat
		hover.bg_color = bg.lightened(0.08)
		_styles[key + "_hover"] = hover
		var pressed := sb.duplicate() as StyleBoxFlat
		pressed.bg_color = bg.darkened(0.12)
		_styles[key + "_pressed"] = pressed
		var disabled := sb.duplicate() as StyleBoxFlat
		disabled.bg_color = Color(0.10, 0.12, 0.10, 0.45)
		disabled.border_color = Color(BORDER, 0.4)
		_styles[key + "_disabled"] = disabled
	b.add_theme_stylebox_override("normal", _styles[key])
	b.add_theme_stylebox_override("hover", _styles[key + "_hover"])
	b.add_theme_stylebox_override("pressed", _styles[key + "_pressed"])
	b.add_theme_stylebox_override("disabled", _styles[key + "_disabled"])
	b.add_theme_stylebox_override("focus", _styles[key + "_hover"])
	b.add_theme_font_override("font", font())
	b.add_theme_font_size_override("font_size", 12)
	var color := Color("20261c") if primary else GOLD if selected else INK
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
		b.add_theme_color_override(state, color)
	b.add_theme_color_override("font_disabled_color", Color(MUTED, 0.45))
	b.add_theme_color_override("icon_disabled_color", Color(MUTED, 0.4))
	b.add_theme_constant_override("h_separation", 5)
	b.focus_mode = Control.FOCUS_NONE


static func icon(kind: String) -> Texture2D:
	if not _icons.has(kind):
		var paths := {
			"view": '<path d="m3 8 9-5 9 5-9 5zM3 12l9 5 9-5M3 16l9 5 9-5"/>',
			"oog": '<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
			"weg": '<path d="M7 3 4 21M17 3l3 18M12 4v3m0 4v3m0 4v3"/>',
			"gebouw": '<path d="m3 11 9-8 9 8M5 10v11h14V10M10 21v-7h4v7"/>',
			"straat": '<path d="M5 21V7a4 4 0 0 1 4-4h5M12 3h7v5h-7zM3 21h5m4-5h8m-7 0v5m6-5v5"/>',
			"gum": '<path d="m3 14 9-10a2 2 0 0 1 3 0l6 6a2 2 0 0 1 0 3l-7 8H9zM8 9l9 9M3 21h18"/>',
			"draai": '<path d="M4 9a8 8 0 1 1 0 7M4 3v6h6"/>',
			"spiegel": '<path d="M12 2v20M8 6 3 18h5zM16 6l5 12h-5z"/>',
			"kopie": '<rect x="8" y="8" width="12" height="13" rx="2"/><path d="M16 8V3H3v13h5"/>',
			"wis": '<path d="M3 6h18M9 6V3h6v3M5 6l1 15h12l1-15M10 10v7m4-7v7"/>',
			"kwast": '<path d="m10 13 8-10 3 3-10 8M10 13a4 4 0 0 0-6 2c0 3-2 5-2 5s6 2 8-1a4 4 0 0 0 0-6z"/>',
			"undo": '<path d="M4 4v6h6M4 10c3-7 16-7 16 3 0 5-5 8-10 7"/>',
			"up": '<path d="m6 15 6-6 6 6"/>',
			"down": '<path d="m6 9 6 6 6-6"/>',
			"grip": '<path d="M5 9h14M5 15h14"/>',
			"plus": '<path d="M12 5v14M5 12h14"/>',
			"minus": '<path d="M5 12h14"/>',
		}
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24"><g fill="none" stroke="white" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">%s</g></svg>' % paths.get(kind, paths.gebouw)
		var image := Image.new()
		if image.load_svg_from_string(svg) == OK:
			_icons[kind] = ImageTexture.create_from_image(image)
	return _icons.get(kind)
