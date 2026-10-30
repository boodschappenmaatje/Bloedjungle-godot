class_name HudExtra
extends Control
## De HUD van de web-versie (23-hud.js, styles.css): balken met icoontjes linksboven, golf, vijanden,
## punten en score met pauzeknop rechtsboven, munitie rechtsonder, rode rand bij schade en
## aanvalspijltjes aan de kant waar de aanval vandaan komt.

const HUD_SCRIPT := preload("res://scripts/hud.gd")  # voor het versienummer achter de fps-teller

var _hp_bar: ProgressBar
var _base_bar: ProgressBar
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
var _status_panel: PanelContainer
var _top_right: HBoxContainer
var _menu: PauseMenu
var _menu_button: Button
var _fps: Label
var _camera_controls: Control
var _camera_button: Button
var _zoom_in_button: Button
var _zoom_out_button: Button
var _radar: Control
var _streak: StreakHud
var _radar_refresh := 0.0
## Contacten op de radar: alleen vijanden die je zelf, je torens, je soldaten of de basis kunnen zien.
## Een gezien contact blijft nog even (vervagend) staan.
const RADAR_SIGHT := 38.0  # m rond de speler
const RADAR_POST_SIGHT := 26.0  # m rond torens, soldaten en gebouwen
const RADAR_BASE_MARGIN := 8.0  # m buiten de muur die de basis overziet
const RADAR_MEMORY := 2.5  # s
var _seen := {}  # instance-id -> laatste keer gezien (s)
var _pinch_points := {} # only touches that start outside sticks, buttons, and modal team targeting
var _pinch_distance := 0.0
var _pinch_accum := 0.0
const PINCH_STEP := 24.0


class MenuGlyph:
	extends Control
	func _draw() -> void:
		var c := size * 0.5
		for y in [-6.0, 0.0, 6.0]:
			draw_line(c + Vector2(-8.0, y), c + Vector2(8.0, y), UI.BRASS, 2.0, true)


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
	_streak = StreakHud.new()
	_streak.name = "StreakHud"
	add_child(_streak)
	_menu = PauseMenu.new()
	add_child(_menu)
	_fps = _shadowed(UI.label("", UI.body(700, 0), 13, UI.GOOD))
	_fps.position = Vector2(12, 84)
	add_child(_fps)
	resized.connect(_layout)
	get_viewport().size_changed.connect(_cancel_pinch)
	_layout()


func _cancel_pinch() -> void:
	_pinch_points.clear()
	_pinch_distance = 0.0
	_pinch_accum = 0.0


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		_cancel_pinch()


func _input(event: InputEvent) -> void:
	if not UI.is_touch_platform() or Game.state not in ["play", "prep"] or Game.build_mode or get_tree().paused:
		_cancel_pinch()
		return
	var team := get_tree().get_first_node_in_group("team_commands")
	if team != null and team.is_modal():
		_cancel_pinch()
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _is_touch_control(event.position):
				return
			_pinch_points[event.index] = event.position
			if _pinch_points.size() > 2:
				_cancel_pinch()
				return
			if _pinch_points.size() == 2:
				_pinch_distance = _two_touch_distance()
				_pinch_accum = 0.0
		else:
			_pinch_points.erase(event.index)
			if _pinch_points.size() < 2:
				_pinch_distance = 0.0
				_pinch_accum = 0.0
	elif event is InputEventScreenDrag and _pinch_points.has(event.index):
		if _is_touch_control(event.position):
			_cancel_pinch()
			return
		_pinch_points[event.index] = event.position
		if _pinch_points.size() == 2:
			var distance := _two_touch_distance()
			_pinch_accum += distance - _pinch_distance
			_pinch_distance = distance
			while absf(_pinch_accum) >= PINCH_STEP:
				var camera := get_viewport().get_camera_3d()
				if camera != null and camera.has_method("zoom"):
					camera.call("zoom", -1 if _pinch_accum > 0.0 else 1)
				_pinch_accum -= signf(_pinch_accum) * PINCH_STEP


func _two_touch_distance() -> float:
	var keys: Array = _pinch_points.keys()
	if keys.size() != 2:
		return 0.0
	var first: Vector2 = _pinch_points[keys[0]]
	var second: Vector2 = _pinch_points[keys[1]]
	return first.distance_to(second)


func _is_touch_control(position: Vector2) -> bool:
	if _radar != null and _radar.is_visible_in_tree() and _radar.get_global_rect().has_point(position):
		return true
	var sticks := get_tree().get_first_node_in_group("touch_sticks")
	if sticks != null:
		for aim in [false, true]:
			var anchor: Vector2 = sticks.call("_anchor", aim)
			if position.distance_to(anchor) <= 76.0:
				return true
	for item in get_tree().get_nodes_in_group("hud_button"):
		if item is Control and item.is_visible_in_tree() and item.get_global_rect().has_point(position):
			return true
	return false


func _shadowed(l: Label) -> Label:
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.add_theme_constant_override("shadow_outline_size", 2)
	return l


func _build_bars() -> void:
	_status_panel = PanelContainer.new()
	_status_panel.name = "StatusPanel"
	_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_panel.custom_minimum_size = Vector2(0, 48)
	var status_style := UI.box(Color(0.015, 0.025, 0.02, 0.88), Color(UI.PANEL_LINE, 0.82), 1, 6, 6)
	status_style.border_width_top = 2
	_status_panel.add_theme_stylebox_override("panel", status_style)
	add_child(_status_panel)
	_bars = VBoxContainer.new()
	_bars.add_theme_constant_override("separation", 5)
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_panel.add_child(_bars)
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
	ic.tooltip_text = "Spelergezondheid" if icon == "heart" else "Gezondheid van de basis"
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
	pb.tooltip_text = "Spelergezondheid" if icon == "heart" else "Gezondheid van de basis"
	pb.add_theme_stylebox_override("background", UI.box(Color(0, 0, 0, 0.55), Color(UI.INK, 0.25), 1, 2, 0))
	pb.add_theme_stylebox_override("fill", UI.box(fill, Color(0, 0, 0, 0), 0, 1, 0))
	row.add_child(pb)
	return pb


func _build_top_right() -> void:
	_top_right = HBoxContainer.new()
	_top_right.add_theme_constant_override("separation", 10)
	_top_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top_right)
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
	_menu_button = Button.new()
	_menu_button.name = "MenuButton"
	_menu_button.tooltip_text = "Pauzemenu"
	_menu_button.custom_minimum_size = Vector2(38, 34)
	_menu_button.add_to_group("hud_button")
	_menu_button.process_mode = Node.PROCESS_MODE_ALWAYS
	UI.style_button(_menu_button, "pause")
	var glyph := MenuGlyph.new()
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_button.add_child(glyph)
	_menu_button.pressed.connect(func(): _set_paused(true))


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
	# De munitie staat nu alleen nog onder het actieve wapen in de wapenstrip (geen dubbele weergave);
	# de naam van een nieuw wapen verschijnt kort als toast.
	_ammo.visible = false


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
	if UI.is_touch_platform():
		_zoom_in_button.hide()
		_zoom_out_button.hide()


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
	_radar.custom_minimum_size = Vector2(120, 128)
	_radar.size = _radar.custom_minimum_size
	_radar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radar.draw.connect(_draw_radar)
	add_child(_radar)
	_menu_button.size = Vector2(36, 34)
	_menu_button.position = Vector2(_radar.size.x - 38.0, 4.0)
	_radar.add_child(_menu_button)


func _radar_point(world_pos: Vector3, area: Rect2) -> Vector2:
	var fx := clampf((world_pos.x + Data.WORLD_X) / (2.0 * Data.WORLD_X), 0.0, 1.0)
	var fz := clampf((world_pos.z + Data.WORLD_Z_N) / (Data.WORLD_Z_N + Data.WORLD_Z_S), 0.0, 1.0)
	return area.position + Vector2(fx * area.size.x, fz * area.size.y)


func _draw_radar() -> void:
	if _radar == null or not _radar.visible:
		return
	var bounds := Rect2(Vector2.ZERO, _radar.size)
	_radar.draw_style_box(UI.box(Color(0.025, 0.045, 0.035, 0.9), Color(UI.PANEL_LINE, 0.82), 1, 6, 0), bounds)
	var head := 22.0 if _radar.size.x >= 110.0 else 16.0
	if head > 6.0:
		_radar.draw_string(UI.body(700, 0), Vector2(7, 14), "CONTACTEN" if _radar.size.x >= 110.0 else "RADAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UI.INK_DIM)
	if _radar.size.x >= 88.0:
		var north_x := _radar.size.x * 0.5
		_radar.draw_string(UI.body(700, 0), Vector2(north_x - 4.0, 13.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UI.INK)
		_radar.draw_colored_polygon(PackedVector2Array([Vector2(north_x, 15.0), Vector2(north_x - 3.5, 21.0), Vector2(north_x + 3.5, 21.0)]), UI.BRASS)
	var map := Rect2(5.0, head, _radar.size.x - 10.0, _radar.size.y - head - 5.0)
	# kruislijnen als schaalreferentie, geen extra scene of viewport
	var mid_x: float = map.position.x + map.size.x * 0.5
	var mid_y: float = map.position.y + map.size.y * 0.5
	_radar.draw_line(Vector2(mid_x, map.position.y), Vector2(mid_x, map.end.y), Color(0.42, 0.52, 0.38, 0.2), 1.0)
	_radar.draw_line(Vector2(map.position.x, mid_y), Vector2(map.end.x, mid_y), Color(0.42, 0.52, 0.38, 0.2), 1.0)
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
			var tp := _radar_point(tower.global_position, map)
			_radar.draw_colored_polygon(PackedVector2Array([tp + Vector2(0, -4), tp + Vector2(4, 0), tp + Vector2(0, 4), tp + Vector2(-4, 0)]), Color(0.38, 0.75, 0.48))
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
		var vis := _enemy_vis(enemy)
		if vis <= 0.0:
			continue
		var point := _radar_point(enemy.global_position, map)
		_radar.draw_circle(point, 2.5, Color(1.0, 0.24, 0.16, 0.95 * vis))
	if _seen.size() > 64:  # oude contacten opruimen
		var alive := {}
		for e in Game.enemies:
			if is_instance_valid(e):
				alive[e.get_instance_id()] = true
		for id in _seen.keys():
			if not alive.has(id):
				_seen.erase(id)
	var player: Node3D = Game.player
	if player != null and is_instance_valid(player):
		var center := _radar_point(player.global_position, map)
		var direction := Vector2(sin(player.face), cos(player.face)).normalized()
		var side := Vector2(direction.y, -direction.x) * 3.2
		_radar.draw_colored_polygon(PackedVector2Array([center + direction * 5.0, center - direction * 3.0 + side, center - direction * 3.0 - side]), Color(0.27, 0.86, 1.0))
	_draw_radar_attacks(map)


## Wie ziet dit punt: de speler, de basis, een toren, een soldaat of een eigen gebouw.
func _in_friendly_sight(pos: Vector3) -> bool:
	var player: Node3D = Game.player
	if player != null and is_instance_valid(player) and Vector2(pos.x - player.global_position.x, pos.z - player.global_position.z).length() <= RADAR_SIGHT:
		return true
	var edge := Data.COMPOUND + RADAR_BASE_MARGIN
	if absf(pos.x) <= edge and absf(pos.z) <= edge:
		return true
	for tower in get_tree().get_nodes_in_group("tower"):
		if is_instance_valid(tower) and tower is Node3D and Vector2(pos.x - tower.global_position.x, pos.z - tower.global_position.z).length() <= RADAR_POST_SIGHT:
			return true
	for ally in Game.allies:
		if is_instance_valid(ally) and ally is Node3D and Vector2(pos.x - ally.global_position.x, pos.z - ally.global_position.z).length() <= RADAR_POST_SIGHT:
			return true
	for building in Game.buildings:
		if building is Dictionary:
			var at: Vector3 = building.get("at", Vector3.ZERO)
			if Vector2(pos.x - at.x, pos.z - at.z).length() <= RADAR_POST_SIGHT:
				return true
	return false


## 1 = nu in zicht, tussen 0 en 1 = kort geleden gezien (vervagend), 0 = onbekend.
func _enemy_vis(enemy: Node3D) -> float:
	var now := Time.get_ticks_msec() / 1000.0
	var id := enemy.get_instance_id()
	if _in_friendly_sight(enemy.global_position):
		_seen[id] = now
		return 1.0
	var last: float = _seen.get(id, -999.0)
	return clampf(1.0 - (now - last) / RADAR_MEMORY, 0.0, 1.0)


## Tijdens de pauze en zolang er nog vijanden komen: de vaste aanvalsroutes van deze golf.
func _routes_shown() -> bool:
	if Game.routes.is_empty() or Game.build_mode or Game.editing:
		return false
	if Game.state == "prep":
		return true
	var main := get_parent().get_parent()
	return Game.state == "play" and "queue" in main and not main.queue.is_empty()


## Grote rode pijl per route: op de plek waar ze bij de basis aankomen, of aan de schermrand als die plek buiten beeld ligt.
func _draw_route_arrows() -> void:
	if not _routes_shown():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var pulse := 0.85 + 0.15 * sin(Time.get_ticks_msec() / 260.0)
	var red := Color(1.0, 0.2, 0.1, pulse)
	var safe := Rect2(Vector2(70.0, 120.0), size - Vector2(140.0, 270.0))  # buiten de banner, radar en knoppen
	var font := UI.body(700, 0)
	for id in Game.routes:
		var r: Dictionary = AanvalRoutes.LIST[id]
		var at: Vector3 = r.show
		var travel := -Vector3(at.x, 0.0, at.z).normalized()  # ze lopen van hier naar de bunker
		var behind := cam.is_position_behind(at)
		var p := cam.unproject_position(at)
		var tip: Vector2
		var dir: Vector2
		if not behind and safe.has_point(p):
			# in beeld: de pijl ligt op de grond en wijst in de looprichting
			dir = (cam.unproject_position(at + travel * 4.0) - p).normalized()
			tip = p + dir * 30.0
		else:
			var c := size * 0.5
			var v := (p - c) * (-1.0 if behind else 1.0)
			if v.length() < 1.0:
				v = Vector2.UP
			var k := minf(absf(safe.size.x * 0.5 / v.x) if absf(v.x) > 0.001 else INF, absf(safe.size.y * 0.5 / v.y) if absf(v.y) > 0.001 else INF)
			dir = v.normalized()
			tip = c + v * k  # aan de rand: de punt wijst naar buiten, naar waar ze vandaan komen
		var side := Vector2(-dir.y, dir.x)
		var base := tip - dir * 40.0
		_arrows.draw_colored_polygon(PackedVector2Array([tip, base + side * 24.0, base + dir * 10.0, base - side * 24.0]), red)
		_arrows.draw_line(base + dir * 4.0, base - dir * 22.0, red, 10.0, true)
		var label: String = r.naam
		var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var lp := base - dir * 44.0 - Vector2(lw * 0.5, -5.0)
		lp.x = clampf(lp.x, 6.0, size.x - lw - 6.0)
		lp.y = clampf(lp.y, 20.0, size.y - 8.0)
		_arrows.draw_string_outline(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, Color(0, 0, 0, 0.75))
		_arrows.draw_string(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.86, 0.8, pulse))


## Op de radar: de routes als rode lijnen, met een stip waar ze beginnen.
func _draw_radar_routes(map: Rect2) -> void:
	if not _routes_shown():
		return
	var col := Color(1.0, 0.25, 0.12, 0.55 + 0.25 * sin(Time.get_ticks_msec() / 260.0))
	for id in Game.routes:
		var r: Dictionary = AanvalRoutes.LIST[id]
		var line := PackedVector2Array()
		for q in r.pts:
			line.append(_radar_point(q, map))
		line.append(_radar_point(r.show, map))
		_radar.draw_polyline(line, col, 2.0, true)
		_radar.draw_circle(line[0], 2.5, col)


func _draw_radar_attacks(map: Rect2) -> void:
	_draw_radar_routes(map)
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


func _radar_size() -> Vector2:
	if size.x < size.y:
		return Vector2(88, 100)  # staand: smal, anders overlapt hij de knoppen onder de golf-titel
	if size.y < 420.0:
		return Vector2(104, 112)  # klein liggend scherm: blijft boven de wisselknop
	return Vector2(120, 128)


func _layout() -> void:
	var safe := UI.safe_margins(size)
	_radar.custom_minimum_size = _radar_size()
	_radar.size = _radar.custom_minimum_size
	_status_panel.position = Vector2(safe.x, safe.y)
	_status_panel.size = Vector2(minf(size.x * 0.42, 232.0), 52.0)
	_top_right.reset_size()
	_camera_controls.position = Vector2(safe.x, safe.y + _status_panel.size.y + 7.0)
	# killstreak-teller: liggend rechts naast de balken, staand eronder (daar staan de TACTISCH-knoppen niet)
	if size.x < size.y:
		_streak.position = Vector2(safe.x + 2.0, safe.y + _status_panel.size.y + 5.0)
	else:
		_streak.position = Vector2(safe.x + _status_panel.size.x + 8.0, safe.y + 8.0)
	_radar.position = Vector2(size.x - safe.z - _radar.size.x, safe.y + 8.0)
	_menu_button.position = Vector2(_radar.size.x - 38.0, 4.0)
	if size.x < size.y:
		# staand: rechts, onder de radar (x volgt in _process uit de breedte van de tekst)
		_top_right.position = Vector2(safe.x, _radar.position.y + _radar.size.y + 4.0)
	else:
		_top_right.position = Vector2(size.x - safe.z - _radar.size.x - _top_right.size.x, safe.y + 4.0)
	# onder de TACTISCH-knoppen (liggend) of onder de punten (staand), zodat hij niets afdekt
	var below := _top_right.position.y + _top_right.size.y if size.x < size.y else _camera_controls.position.y + 34.0
	_fps.position = Vector2(safe.x + 4.0, below + 6.0)
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
	_bars.visible = not Game.editing
	_status_panel.visible = not Game.editing
	_top_right.visible = not Game.editing
	_weapon.visible = not Game.editing
	var active_hud := Game.state == "play" or Game.state == "prep"
	_camera_controls.visible = active_hud and not Game.build_mode and size.x >= size.y
	_radar.visible = active_hud
	if active_hud:
		_update_camera_controls()
		_radar_refresh -= delta
		if _radar_refresh <= 0.0:
			_radar_refresh = 0.12
			_radar.queue_redraw()
	# alleen de instelling telt; vroeger ook StadEditor.debug_enabled (F3), en die kun je op de iPhone niet aanzetten
	_fps.visible = GameSettings.get_value("fps") == "on" and not Game.editing
	if _fps.visible:
		_fps.text = "%d FPS · %d%%%s · %s" % [Engine.get_frames_per_second(), roundi(get_viewport().scaling_3d_scale * 100.0), (" · T%d" % Atmosphere.tier) if Atmosphere.tier > 0 else "", HUD_SCRIPT.VERSION]
	var main := get_parent().get_parent()
	var left: int = Game.enemies.size() + (main.queue.size() if "queue" in main else 0)
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
	if size.x < size.y:
		_top_right.position.x = size.x - 12.0 - _top_right.size.x
	else:
		# liggend: links van de radar, anders staat de radar over de punten
		_top_right.position.x = size.x - UI.safe_margins(size).z - _radar.size.x - 6.0 - _top_right.size.x
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
