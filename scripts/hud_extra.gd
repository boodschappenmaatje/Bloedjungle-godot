class_name HudExtra
extends Control
## De rest van de web-interface (23-hud.js): golf, punten en overgebleven vijanden bovenin, grotere
## munitie met rood bij bijna leeg, wapennaam bij wisselen, rode rand bij schade en de kant waar de
## aanval vandaan komt (N/O/Z/W). Alles tekent mee met de schermgrootte.

var _wave: Label
var _enemies: Label
var _points: Label
var _weapon: Label
var _weapon_t := 0.0
var _last_weapon := ""
var _hurt: ColorRect
var _hurt_a := 0.0
var _last_hp := -1.0
var _edges := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hurt = ColorRect.new()
	_hurt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hurt.material = _vignette_material()
	_hurt.color = Color.WHITE
	add_child(_hurt)
	for d in ["N", "O", "Z", "W"]:
		var l := Label.new()
		l.text = d
		l.add_theme_font_size_override("font_size", 22)
		l.add_theme_color_override("font_color", Color(1, 0.35, 0.25))
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		l.add_theme_constant_override("outline_size", 6)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.modulate.a = 0.0
		match d:
			"N":
				l.set_anchors_preset(Control.PRESET_CENTER_TOP)
				l.offset_top = 150
				l.offset_left = -10
			"Z":
				l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
				l.offset_top = -90
				l.offset_left = -10
			"O":
				l.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
				l.offset_left = -40
				l.offset_top = -14
			"W":
				l.set_anchors_preset(Control.PRESET_CENTER_LEFT)
				l.offset_left = 14
				l.offset_top = -14
		add_child(l)
		_edges[d] = l
	_wave = _top_label(Control.PRESET_CENTER_TOP, 12, 26)
	_enemies = _top_label(Control.PRESET_CENTER_TOP, 44, 17)
	_points = _top_label(Control.PRESET_CENTER_TOP, 70, 17)
	_points.add_theme_color_override("font_color", Color(1, 0.86, 0.5))
	_weapon = _top_label(Control.PRESET_CENTER_BOTTOM, -120, 24)
	_weapon.modulate.a = 0.0
	Game.changed.connect(_sync)
	_sync()


func _top_label(preset: int, y: float, size: int) -> Label:
	var l := Label.new()
	l.set_anchors_preset(preset)
	l.offset_left = -200
	l.offset_right = 200
	l.offset_top = y
	l.offset_bottom = y + size + 8
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _vignette_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float amount = 0.0;
void fragment() {
	float d = distance(UV, vec2(0.5)) * 1.45;
	COLOR = vec4(0.75, 0.04, 0.02, smoothstep(0.35, 1.0, d) * amount);
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _sync() -> void:
	_wave.text = "GOLF %d" % maxi(Game.wave, 1)
	var main := get_parent().get_parent()
	var left: int = Game.enemies.size() + (main.queue.size() if "queue" in main else 0)
	_enemies.text = "–" if Game.state != "play" else "%d vijanden" % left
	_points.text = "%d pt   ★ %d" % [Game.points, Game.score]
	var p = Game.player
	if p:
		if _last_hp >= 0.0 and p.hp < _last_hp:
			_hurt_a = 0.5
		_last_hp = p.hp
		if p.weapon != _last_weapon:
			if _last_weapon != "":
				_weapon.text = Data.WEAPONS[p.weapon].name.to_upper()
				_weapon_t = 0.9
			_last_weapon = p.weapon


func _process(delta: float) -> void:
	_sync()
	if _weapon_t > 0.0:
		_weapon_t -= delta
	_weapon.modulate.a = clampf(_weapon_t / 0.3, 0.0, 1.0)
	_hurt_a = maxf(0.0, _hurt_a - delta)
	var low := 0.0
	if Game.player and Game.state == "play":
		var f: float = Game.player.hp / Game.max_hp()
		if f < 0.3:
			low = (0.3 - f) * 2.0 * (0.6 + 0.4 * sin(Time.get_ticks_msec() / 180.0))
	(_hurt.material as ShaderMaterial).set_shader_parameter("amount", clampf(maxf(_hurt_a * 2.0, low), 0.0, 1.0))
	for d in _edges:
		Game.attack[d] = maxf(0.0, Game.attack[d] - delta)
		var on: bool = Game.attack[d] > 0.0 and Game.state == "play"
		_edges[d].modulate.a = move_toward(_edges[d].modulate.a, 1.0 if on else 0.0, delta * 6.0)
