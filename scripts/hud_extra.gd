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
var _camera_controls: Control
var _camera_button: Button
var _zoom_in_button: Button
var _zoom_out_button: Button
var _radar: Control
var _radar_refresh := 0.0


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
	_build_camera_controls()
	_build_radar()
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


func _build_camera_controls() -> void:
	_camera_controls = Control.new()
	_camera_controls.name = "CameraControls"
	_camera_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_camera_controls)
	_camera_button = _camera_button_new("TACTISCH", Vector2(104, 30))
	_camera_button.pressed.connect(_toggle_camera)
	_camera_controls.add_child(_camera_button)
	_zoom_out_button = _camera_button_new("−", Vector2(34, 30))
	_zoom_out_button.position.x = 108.0
	_zoom_out_button.pressed.connect(_zoom_camera.bind(1))
	_camera_controls.add_child(_zoom_out_button)
	_zoom_in_button = _camera_button_new("+", Vector2(34, 30))
	_zoom_in_button.position.x = 146.0
	_zoom_in_button.pressed.connect(_zoom_camera.bind(-1))
	_camera_controls.add_child(_zoom_in_button)


func _camera_button_new(text_: String, button_size: Vector2) -> Button:
	var b := Button.new()
	b.name = {"TACTISCH": "CameraViewButton", "−": "CameraZoomOutButton", "+": "CameraZoomInButton"}.get(text_, "CameraButton")
	b.text = text_
	b.size = button_size
	b.add_to_group("hud_button")
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 11 if text_ == "TACTISCH" else 18)
	UI.style_button(b, "pause")
	return b


func _toggle_camera() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam != null and cam.has_method("toggle_view"):
		cam.call("toggle_view")
		_update_camera_controls()


func _zoom_camera(direction: int) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam != null and cam.has_method("zoom"):
		cam.call("zoom", direction)


func _update_camera_controls() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var combat: bool = bool(cam.get("combat_view"))
	_camera_button.text = "GEVECHT" if combat else "TACTISCH"
	_camera_button.tooltip_text = "Schakel tussen tactische en gevechtscamera"
	_zoom_in_button.tooltip_text = "Camera dichterbij"
	_zoom_out_button.tooltip_text = "Camera verder weg"
	var step: int = int(cam.get("zoom_step"))
	_zoom_out_button.disabled = step >= 4
	_zoom_in_button.disabled = step <= -3


func _build_radar() -> void:
	_radar = Control.new()
	_radar.name = "TacticalRadar"
	_radar.custom_minimum_size = Vector2(132, 144)
	_radar.size = _radar.custom_minimum_size
	_radar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radar.draw.connect(_draw_radar)
	add_child(_radar)


func _radar_point(world_pos: Vector3, area: Rect2) -> Vector2:
	var fx := clampf((world_pos.x + Data.WORLD_X) / (2.0 * Data.WORLD_X), 0.0, 1.0)
	var fz := clampf((world_pos.z + Data.WORLD_Z_N) / (Data.WORLD_Z_N + Data.WORLD_Z_S), 0.0, 1.0)
	return area.position + Vector2(fx * area.size.x, fz * area.size.y)


func _draw_radar() -> void:
	if _radar == null or not _radar.visible:
		return
	var bounds := Rect2(Vector2.ZERO, _radar.size)
	_radar.draw_rect(bounds, Color(0.025, 0.055, 0.045, 0.9), true)
	_radar.draw_rect(bounds, Color(0.58, 0.66, 0.43, 0.85), false, 1.5)
	_radar.draw_string(UI.body(700, 0), Vector2(7, 13), "RADAR  ·  CONTACTEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UI.INK_DIM)
	var map := Rect2(5.0, 18.0, _radar.size.x - 10.0, _radar.size.y - 23.0)
	for i in 1: # kruislijnen als schaalreferentie, geen extra scene of viewport
		var x: float = map.position.x + map.size.x * 0.5
		var y: float = map.position.y + map.size.y * 0.5
		_radar.draw_line(Vector2(x, map.position.y), Vector2(x, map.end.y), Color(0.42, 0.52, 0.38, 0.2), 1.0)
		_radar.draw_line(Vector2(map.position.x, y), Vector2(map.end.x, y), Color(0.42, 0.52, 0.38, 0.2), 1.0)
	var wall_color := Color(0.56, 0.64, 0.42, 0.8)
	for side in [-1.0, 1.0]:
		_radar.draw_line(_radar_point(Vector3(side * Data.COMPOUND, 0, -Data.COMPOUND), map), _radar_point(Vector3(side * Data.COMPOUND, 0, Data.COMPOUND), map), wall_color, 1.4)
		for span in [[-Data.COMPOUND, -Data.GATE_GAP], [Data.GATE_GAP, Data.COMPOUND]]:
			_radar.draw_line(_radar_point(Vector3(span[0], 0, side * Data.COMPOUND), map), _radar_point(Vector3(span[1], 0, side * Data.COMPOUND), map), wall_color, 1.4)
	var river := PackedVector2Array()
	for i in 33:
		var xw: float = lerpf(-Data.WORLD_X, Data.WORLD_X, float(i) / 32.0)
		river.append(_radar_point(Vector3(xw, 0.0, Data.river_z(xw)), map))
	_radar.draw_polyline(river, Color(0.2, 0.55, 0.65, 0.65), 1.5, true)
	# De bunker staat op het echte wereldnulpunt; overige markers volgen de huidige bouwdata.
	var base := _radar_point(Vector3.ZERO, map)
	_radar.draw_rect(Rect2(base - Vector2(3.5, 3.5), Vector2(7, 7)), Color(1.0, 0.74, 0.28), true)
	for tower in get_tree().get_nodes_in_group("tower"):
		if is_instance_valid(tower) and tower is Node3D:
			_radar.draw_rect(Rect2(_radar_point(tower.global_position, map) - Vector2(2.5, 2.5), Vector2(5, 5)), Color(0.38, 0.75, 0.48), true)
	if Game.gates != null and is_instance_valid(Game.gates):
		for gate in Game.gates.list:
			var root: Variant = gate.get("root")
			if root != null and is_instance_valid(root):
				var gate_color := Color(0.24, 0.82, 0.42) if float(gate.get("open", 0.0)) > 0.8 else Color(0.92, 0.25, 0.16)
				_radar.draw_circle(_radar_point(root.global_position, map), 2.0, gate_color)
	for building in Game.buildings:
		if not building is Dictionary:
			continue
		var node: Variant = building.get("node")
		if node != null and not is_instance_valid(node):
			continue
		var at: Vector3 = building.get("at", Vector3.ZERO)
		var kind: String = str(building.get("kind", ""))
		var point := _radar_point(at, map)
		var col := Color(0.78, 0.84, 0.42) if kind in ["muur", "zandzak"] else Color(0.38, 0.75, 0.48)
		_radar.draw_rect(Rect2(point - Vector2(2, 2), Vector2(4, 4)), col, true)
	for enemy in Game.enemies:
		if not is_instance_valid(enemy) or not enemy is Node3D or bool(enemy.get("dead")):
			continue
		var point := _radar_point(enemy.global_position, map)
		_radar.draw_circle(point, 2.2, Color(1.0, 0.24, 0.16, 0.95))
	var player: Node3D = Game.player
	if player != null and is_instance_valid(player):
		var center := _radar_point(player.global_position, map)
		var direction := Vector2(sin(player.face), cos(player.face)).normalized()
		var side := Vector2(direction.y, -direction.x) * 3.2
		_radar.draw_colored_polygon(PackedVector2Array([center + direction * 5.0, center - direction * 3.0 + side, center - direction * 3.0 - side]), Color(0.27, 0.86, 1.0))
	_draw_radar_attacks(map)


func _draw_radar_attacks(map: Rect2) -> void:
	var cx := map.position.x + map.size.x * 0.5
	var cy := map.position.y + map.size.y * 0.5
	var pulse := 0.65 + 0.35 * sin(Time.get_ticks_msec() / 180.0)
	var arrows := {
		"N": [Vector2(cx, map.position.y + 2), Vector2(cx - 5, map.position.y + 9), Vector2(cx + 5, map.position.y + 9)],
		"Z": [Vector2(cx, map.end.y - 2), Vector2(cx - 5, map.end.y - 9), Vector2(cx + 5, map.end.y - 9)],
		"W": [Vector2(map.position.x + 2, cy), Vector2(map.position.x + 9, cy - 5), Vector2(map.position.x + 9, cy + 5)],
		"O": [Vector2(map.end.x - 2, cy), Vector2(map.end.x - 9, cy - 5), Vector2(map.end.x - 9, cy + 5)],
	}
	for direction in arrows:
		if Game.attack.get(direction, 0.0) > 0.0:
			_radar.draw_colored_polygon(PackedVector2Array(arrows[direction]), Color(1.0, 0.25, 0.12, pulse))


func _set_paused(on: bool) -> void:
	_menu.set_paused(on)


func _layout() -> void:
	_bars.position = Vector2(12, 10)
	_bars.size = Vector2(minf(size.x * 0.3, 150.0), 0)
	_top_right.reset_size()
	_top_right.position = Vector2(size.x - 12.0 - _top_right.size.x, 10)
	_camera_controls.position = Vector2(12.0, 48.0)
	_radar.position = Vector2(size.x - _radar.size.x - 12.0, 48.0)
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
	var play_hud := (Game.state == "play" or Game.state == "prep") and not Game.build_mode
	_camera_controls.visible = play_hud
	_radar.visible = play_hud
	if play_hud:
		_update_camera_controls()
		_radar_refresh -= delta
		if _radar_refresh <= 0.0:
			_radar_refresh = 0.12
			_radar.queue_redraw()
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
