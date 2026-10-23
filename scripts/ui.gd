class_name UI
## Kleuren, lettertypes en knopstijlen van de web-versie (styles.css): Black Ops One voor koppen en
## Barlow Condensed voor de rest, donkere veldhandboek-panelen met olijf, brons en bloedrood.

const INK := Color("ebe3cc")
const INK_DIM := Color("a39d86")
const PANEL := Color(18.0 / 255.0, 22.0 / 255.0, 12.0 / 255.0, 0.94)
const PANEL_LINE := Color("3b4426")
const OLIVE := Color("56602f")
const OLIVE_HI := Color("7a8743")
const BLOOD := Color("a3100f")
const BLOOD_HI := Color("d42a1f")
const BRASS := Color("d6ad4f")
const GOOD := Color("7fae4a")

static var _fonts := {}


## Kopletter (Black Ops One); spacing in pixels tussen de letters.
static func display(spacing := 0) -> Font:
	return _font("res://assets/fonts/BlackOpsOne.woff2", spacing)


## Tekstletter (Barlow Condensed) in gewicht 500, 600 of 700.
static func body(weight := 600, spacing := 0) -> Font:
	return _font("res://assets/fonts/BarlowCondensed-%d.woff2" % weight, spacing)


static func _font(path: String, spacing: int) -> Font:
	var key := "%s|%d" % [path, spacing]
	if not _fonts.has(key):
		var fv := FontVariation.new()
		fv.base_font = load(path)
		fv.spacing_glyph = spacing
		_fonts[key] = fv
	return _fonts[key]


static func box(bg: Color, border := Color(0, 0, 0, 0), border_w := 0, radius := 4, margin := -1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	if margin >= 0:
		sb.set_content_margin_all(margin)
	return sb


## Geeft een knop diepte: een donkere rand eronder (de "dikte"), een lichte rand bovenin;
## ingedrukt zakt de knop erin.
static func bevel(sb: StyleBoxFlat, depth := 4, pressed := false) -> StyleBoxFlat:
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 0
	sb.shadow_offset = Vector2(0, 1 if pressed else depth)
	sb.set_corner_radius_all(maxi(sb.corner_radius_top_left, 8))
	sb.anti_aliasing = true
	sb.expand_margin_bottom = 0
	if pressed:
		sb.content_margin_top = maxf(sb.content_margin_top, 0.0) + depth - 1
	return sb


static func seg_state(b: Button, on: bool) -> void:
	var n := box(OLIVE if on else Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 6)
	n.content_margin_left = 8
	n.content_margin_right = 8
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, n)
	var c := INK if on else INK_DIM
	for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(cn, c)


static func label(text: String, font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Zet de web-stijl op een knop. kind: "buy", "primary", "gold", "tab", "round", "pause".
static func style_button(b: Button, kind: String) -> void:
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): Sfx.play("click"))
	var normal: StyleBoxFlat
	var pressed: StyleBoxFlat
	var disabled: StyleBoxFlat
	var font: Font = body(700, 1)
	var size := 15
	var col := INK
	match kind:
		"buy":
			normal = box(OLIVE, OLIVE_HI, 1, 4, 4)
			pressed = box(OLIVE_HI, OLIVE_HI, 1, 4, 4)
			disabled = box(Color(0, 0, 0, 0), PANEL_LINE, 1, 4, 4)
			b.custom_minimum_size.y = maxf(b.custom_minimum_size.y, 40.0)
		"primary":
			normal = box(BLOOD, BLOOD, 0, 4, 4)
			pressed = box(BLOOD_HI, BLOOD_HI, 0, 4, 4)
			disabled = normal
			font = display(1)
			size = 22
			b.custom_minimum_size.y = 52.0
		"gold":
			normal = box(Color(0, 0, 0, 0.5), BRASS, 1, 4, 4)
			pressed = box(Color(0.3, 0.2, 0.05, 0.7), BRASS, 1, 4, 4)
			disabled = normal
			size = 14
			col = BRASS
			font = body(700, 1)
			b.custom_minimum_size.y = 40.0
		"round":
			normal = box(Color(14.0 / 255.0, 17.0 / 255.0, 10.0 / 255.0, 0.62), Color(INK, 0.35), 2, 30, 0)
			pressed = box(Color(163.0 / 255.0, 16.0 / 255.0, 15.0 / 255.0, 0.6), Color(INK, 0.35), 2, 30, 0)
			disabled = normal
		"secondary":
			normal = box(Color(0, 0, 0, 0), PANEL_LINE, 1, 4, 4)
			pressed = box(Color(1, 1, 1, 0.06), PANEL_LINE, 1, 4, 4)
			disabled = normal
			b.custom_minimum_size.y = 44.0
			font = body(700, 2)
		"pause":
			normal = box(Color(0, 0, 0, 0.45), Color(INK, 0.3), 1, 4, 0)
			pressed = box(Color(163.0 / 255.0, 16.0 / 255.0, 15.0 / 255.0, 0.6), Color(INK, 0.3), 1, 4, 0)
			disabled = normal
			size = 13
		"seg":
			normal = box(Color(0, 0, 0, 0.35), PANEL_LINE, 1, 6, 6)
			pressed = normal
			disabled = normal
			size = 15
			font = body(700, 1)
		"tab":
			normal = box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 4)
			normal.border_width_bottom = 3
			pressed = normal
			disabled = normal
			size = 15
			col = INK_DIM
			font = body(700, 2)
	# 3D-look: hogere kleuren en een dikke onderrand voor de knoppen die je indrukt
	if kind in ["buy", "primary", "gold", "round", "secondary", "pause"]:
		var depth := 5 if kind == "primary" else 4
		bevel(normal, depth)
		bevel(pressed, depth, true)
		if kind != "round":
			normal.bg_color = normal.bg_color.lightened(0.07)
			normal.border_width_top = maxi(normal.border_width_top, 2)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", normal)
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", size)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, col)
	b.add_theme_color_override("font_disabled_color", Color(col, 0.4))


## Nederlandse duizendtallen: 5000 wordt "5.000".
static func nl(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += "."
		out += s[i]
	return ("-" if n < 0 else "") + out
