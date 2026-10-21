class_name HudExtra
extends Control
## De HUD van de web-versie (23-hud.js, styles.css): balken met icoontjes linksboven, golf, vijanden,
## punten en score met pauzeknop rechtsboven, munitie rechtsonder, rode rand bij schade en
## aanvalspijltjes aan de kant waar de aanval vandaan komt.

var _hp_bar: ProgressBar
var _base_bar: ProgressBar
var _wave: Label
var _enemies: Label
var _points: Label
var _score: Label
var _weapon: Label
var _ammo: Label
var _weapon_t := 0.0
var _last_weapon := ""
var _hurt: ColorRect
var _hurt_a := 0.0
var _last_hp := -1.0
var _arrows: Control
var _bars: VBoxContainer
var _top_right: HBoxContainer
var _menu: PauseMenu
var _fps: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hurt = ColorRect.new()
	_hurt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hurt.material = _vignette_material()
	_hurt.color = Color.WHITE
	add_child(_hurt)
	_arrows = Control.new()
	_arrows.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_arrows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrows.draw.connect(_draw_arrows)
	add_child(_arrows)
	_build_bars()
	_build_top_right()
	_build_ammo()
	_menu = PauseMenu.new()
	add_child(_menu)
	_fps = _shadowed(UI.label("", UI.body(700, 0), 13, UI.GOOD))
	_fps.position = Vector2(12, 84)
	add_child(_fps)
	resized.connect(_layout)
	_layout()


func _shadowed(l: Label) -> Label:
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.add_theme_constant_override("shadow_outline_size", 2)
	return l


func _build_bars() -> void:
	_bars = VBoxContainer.new()
	_bars.add_theme_constant_override("separation", 5)
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bars)
	_hp_bar = _bar_row("heart", Color8(224, 71, 58), UI.BLOOD_HI)
	_base_bar = _bar_row("base", UI.OLIVE_HI, UI.OLIVE_HI)


func _bar_row(icon: String, icon_col: Color, fill: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars.add_child(row)
	var ic := TextureRect.new()
	ic.texture = load("res://assets/ui/icons/icon_%s.png" % icon)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(14, 14)
	ic.modulate = icon_col
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ic)
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.min_value = 0.0
	pb.max_value = 1.0
	pb.value = 1.0
	pb.custom_minimum_size = Vector2(0, 8)
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pb.add_theme_stylebox_override("background", UI.box(Color(0, 0, 0, 0.55), Color(UI.INK, 0.25), 1, 2, 0))
	pb.add_theme_stylebox_override("fill", UI.box(fill, Color(0, 0, 0, 0), 0, 1, 0))
	row.add_child(pb)
	return pb


func _build_top_right() -> void:
	_top_right = HBoxContainer.new()
	_top_right.add_theme_constant_override("separation", 10)
	_top_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top_right)
	_wave = _shadowed(UI.label("GOLF 1", UI.display(1), 16, UI.INK))
	_wave.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_top_right.add_child(_wave)
	var en := HBoxContainer.new()
	en.add_theme_constant_override("separation", 3)
	en.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	en.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_right.add_child(en)
	var sk := TextureRect.new()
	sk.texture = load("res://assets/ui/icons/icon_skull.png")
	sk.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sk.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sk.custom_minimum_size = Vector2(14, 14)
	sk.modulate = UI.INK_DIM
	sk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	en.add_child(sk)
	_enemies = _shadowed(UI.label("–", UI.body(700, 0), 13, UI.INK_DIM))
	en.add_child(_enemies)
	_points = _shadowed(UI.label("0 pt", UI.display(0), 16, UI.BRASS))
	_points.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_top_right.add_child(_points)
	_score = _shadowed(UI.label("★ 0", UI.body(700, 0), 12, UI.INK_DIM))
	_score.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_top_right.add_child(_score)
	var pb := Button.new()
	pb.text = "II"
	pb.custom_minimum_size = Vector2(34, 30)
	pb.add_to_group("hud_button")
	pb.process_mode = Node.PROCESS_MODE_ALWAYS
	UI.style_button(pb, "pause")
	pb.pressed.connect(func(): _set_paused(true))
	_top_right.add_child(pb)


func _build_ammo() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_right = -30
	box.offset_bottom = -30
	add_child(box)
	_weapon = _shadowed(UI.label("", UI.display(1), 14, UI.INK))
	_weapon.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_weapon.modulate.a = 0.0
	box.add_child(_weapon)
	_ammo = _shadowed(UI.label("8 | 8", UI.body(700, 0), 15, UI.BRASS))
	_ammo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_ammo)


func _set_paused(on: bool) -> void:
	_menu.set_paused(on)


func _layout() -> void:
	_bars.position = Vector2(12, 10)
	_bars.size = Vector2(minf(size.x * 0.3, 150.0), 0)
	_top_right.reset_size()
	_top_right.position = Vector2(size.x - 12.0 - _top_right.size.x, 10)
	_arrows.queue_redraw()


func _vignette_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float amount = 0.0;
void fragment() {
	float d = length(UV - vec2(0.5)) / 0.7071;
	COLOR = vec4(0.59, 0.0, 0.0, smoothstep(0.45, 1.0, d) * 0.85 * amount);
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _process(delta: float) -> void:
	visible = Game.state != "menu"
	_fps.visible = GameSettings.get_value("fps") == "on"
	if _fps.visible:
		_fps.text = "%d FPS · %d%%" % [Engine.get_frames_per_second(), roundi(get_viewport().scaling_3d_scale * 100.0)]
		var screen_hz := DisplayServer.screen_get_refresh_rate()
		_fps.text += "\nKeuze %s Hz · limiet %d · scherm %.0f Hz" % [GameSettings.get_value("hz"), Engine.max_fps, screen_hz]
		_fps.text += "\n" + TouchSticks.info + " · st " + Game.state + (" · pauze" if get_tree().paused else "")
	var main := get_parent().get_parent()
	var left: int = Game.enemies.size() + (main.queue.size() if "queue" in main else 0)
	_wave.text = "GOLF %d" % maxi(Game.wave, 1)
	_enemies.text = "–" if Game.state != "play" else str(left)
	_points.text = "%s pt" % UI.nl(Game.points)
	_score.text = "★ %s" % UI.nl(Game.score)
	_base_bar.value = Game.base_hp / Game.base_max
	var p = Game.player
	if p:
		_hp_bar.value = p.hp / Game.max_hp()
		if _last_hp >= 0.0 and p.hp < _last_hp:
			_hurt_a = 0.5
		_last_hp = p.hp
		if p.weapon != _last_weapon:
			if _last_weapon != "":
				_weapon.text = Data.WEAPONS[p.weapon].name.to_upper()
				_weapon_t = 0.9
			_last_weapon = p.weapon
		var w: Dictionary = Game.wstat(p.weapon)
		_ammo.text = "…" if p.reload_t > 0.0 else "%d | %d" % [p.ammo, w.mag]
		var low: bool = p.reload_t <= 0.0 and p.ammo <= w.mag * 0.25
		_ammo.add_theme_color_override("font_color", Color8(255, 90, 58) if low else (UI.INK_DIM if p.reload_t > 0.0 else UI.BRASS))
	_top_right.reset_size()
	_top_right.position.x = size.x - 12.0 - _top_right.size.x
	_weapon_t = maxf(0.0, _weapon_t - delta)
	_weapon.modulate.a = clampf(_weapon_t / 0.3, 0.0, 1.0)
	_hurt_a = maxf(0.0, _hurt_a - delta)
	var low_hp := 0.0
	if p and Game.state == "play":
		var f: float = p.hp / Game.max_hp()
		if f < 0.3:
			low_hp = (0.3 - f) * 2.0 * (0.6 + 0.4 * sin(Time.get_ticks_msec() / 180.0))
	(_hurt.material as ShaderMaterial).set_shader_parameter("amount", clampf(maxf(_hurt_a * 2.0, low_hp), 0.0, 1.0))
	for d in Game.attack:
		Game.attack[d] = maxf(0.0, Game.attack[d] - delta)
	_arrows.queue_redraw()


## Rode pijltjes aan de rand, knipperend, zoals .atk in styles.css.
func _draw_arrows() -> void:
	if Game.state != "play":
		return
	var a := 0.675 + 0.325 * cos(Time.get_ticks_msec() / 400.0 * PI)
	var w := size.x
	var h := size.y
	var shapes := {
		"N": PackedVector2Array([Vector2(w / 2.0, 50), Vector2(w / 2.0 + 15, 72), Vector2(w / 2.0 - 15, 72)]),
		"Z": PackedVector2Array([Vector2(w / 2.0, h - 8), Vector2(w / 2.0 + 15, h - 30), Vector2(w / 2.0 - 15, h - 30)]),
		"W": PackedVector2Array([Vector2(2, h / 2.0), Vector2(24, h / 2.0 - 15), Vector2(24, h / 2.0 + 15)]),
		"O": PackedVector2Array([Vector2(w - 2, h / 2.0), Vector2(w - 24, h / 2.0 - 15), Vector2(w - 24, h / 2.0 + 15)]),
	}
	for d in shapes:
		if Game.attack[d] > 0.0:
			_arrows.draw_colored_polygon(shapes[d], Color(1.0, 0.23, 0.12, a))
