class_name TouchSticks
extends Control
## Op mobiel: vaste thumb-zones links en rechts; op desktop blijven toetsenbord en muis actief.
## Linker helft = lopen. Rechter helft = richten; half duwen richt alleen, tot de rand duwen schiet.
## Op een computer: WASD of pijltjes lopen, muis richten, linkermuisknop schieten.

const STICK_R := 56.0
const ANCHOR_R := 76.0
const AIM_FIRE := 0.8

var _sticks := {}  # vinger-index -> {"aim": bool, "origin": Vector2, "d": Vector2}
var _mouse_used := false
var _mouse_down := false
var _events := 0
var _last_touch_hud_visible := false
static var aim_d := Vector2.ZERO   # uitwijking van de rechterstick (-1..1), ook als hij niet schiet; napalm_plaats.gd gebruikt dit
static var info := ""  # voor de fps-teller: wat de sticks nu zien (om te kijken waarom ze niet reageren)


func _ready() -> void:
	add_to_group("touch_sticks")
	get_viewport().size_changed.connect(_clear)  # bij draaien van het scherm zijn alle vingers weg
	# ook tijdens pauze of een menu loslaten van je vinger zien, anders blijft er een "spook-stick" hangen
	process_mode = Node.PROCESS_MODE_ALWAYS


func _notification(what: int) -> void:
	# app naar de achtergrond, meldingscentrum, schermopname-knop: de vinger kan weg zijn zonder dat wij het horen
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_clear()


func _clear() -> void:
	_sticks.clear()
	_mouse_down = false
	Game.move = Vector2.ZERO
	Game.aim = NAN
	Game.fire = false
	var team := get_tree().get_first_node_in_group("team_commands")
	if team != null:
		team.cancel_input()
	queue_redraw()


func _anchor(aim: bool) -> Vector2:
	var safe := UI.safe_margins(get_viewport_rect().size)
	var compact := size.x < 880.0
	var left_inset := 0.0 if compact else 14.0
	var right_inset := 0.0 if compact else 10.0
	var x := size.x - safe.z - ANCHOR_R - right_inset if aim else safe.x + ANCHOR_R + left_inset
	return Vector2(x, size.y - safe.w - ANCHOR_R)


func _input(event: InputEvent) -> void:
	var team := get_tree().get_first_node_in_group("team_commands")
	if team != null and team.handle_pointer_event(event):
		return
	if team != null and team.is_modal() and (event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton or event is InputEventMouseMotion):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_events += 1
	if Game.build_mode:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _on_button(event.position):
				return
			var aim: bool = event.position.x > get_viewport_rect().size.x * 0.5
			var origin: Vector2 = event.position
			if UI.is_touch_platform():
				var left_anchor := _anchor(false)
				var right_anchor := _anchor(true)
				var left_d: float = event.position.distance_to(left_anchor)
				var right_d: float = event.position.distance_to(right_anchor)
				if minf(left_d, right_d) > ANCHOR_R:
					return  # gameplay-touch buiten de twee thumb-zones blijft vrij
				aim = right_d < left_d
				origin = right_anchor if aim else left_anchor
			# Een nieuwe aanraking in dezelfde vaste zone vervangt een gemiste release.
			# De andere stick behoudt zijn eigen vinger-ID.
			for held_id in _sticks.keys():
				if _sticks[held_id].aim == aim:
					_sticks.erase(held_id)
			var d: Vector2 = event.position - origin
			if d.length() > STICK_R:
				d = d.normalized() * STICK_R
			_sticks[event.index] = {"aim": aim, "origin": origin, "d": d / STICK_R}
			_mouse_used = false
		else:
			_sticks.erase(event.index)
		queue_redraw()
	elif event is InputEventScreenDrag and _sticks.has(event.index):
		var s: Dictionary = _sticks[event.index]
		var d: Vector2 = event.position - s.origin
		if d.length() > STICK_R:
			d = d.normalized() * STICK_R
		s.d = d / STICK_R
		queue_redraw()
	elif event is InputEventMouse and event.device != InputEvent.DEVICE_ID_EMULATION:
		_mouse_used = true
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			_mouse_down = event.pressed and not _on_button(event.position)


func _on_button(p: Vector2) -> bool:
	for b: Control in get_tree().get_nodes_in_group("hud_button"):
		if not b.is_visible_in_tree():
			continue
		var rect := b.get_global_rect()
		# The pause/shop scrim fills the whole screen and belongs to the same group as buttons.
		# It captures touches only while that overlay is actually active.
		if rect.size.x >= size.x * 0.9 and rect.size.y >= size.y * 0.9 \
			and Game.state != "menu" and Game.state != "shop" and not get_tree().paused and not Game.editing:
			continue
		if rect.has_point(p):
			return true
	return false


func blocks_team_target_hud(p: Vector2) -> bool:
	return _on_button(p)


func blocks_team_target_joystick(p: Vector2) -> bool:
	if not UI.is_touch_platform():
		return false
	return p.distance_to(_anchor(false)) <= ANCHOR_R or p.distance_to(_anchor(true)) <= ANCHOR_R


func _process(_delta: float) -> void:
	var touch_hud_visible := UI.is_touch_platform() and not Game.build_mode and (Game.state == "play" or Game.state == "prep")
	if touch_hud_visible != _last_touch_hud_visible:
		_last_touch_hud_visible = touch_hud_visible
		queue_redraw()
	if get_tree().paused or Game.state == "menu" or Game.state == "shop":
		if not _sticks.is_empty():
			_clear()  # menu of pauze open: sticks weg, de volgende aanraking begint schoon
		return
	if Game.build_mode:
		_sticks.clear()
		Game.move = Vector2.ZERO
		Game.aim = NAN
		Game.fire = false
		queue_redraw()
		return
	var mv := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	var aim := NAN
	var fire := false
	aim_d = Vector2.ZERO
	for s in _sticks.values():
		if s.aim:
			aim_d = s.d
		var l: float = s.d.length()
		if not s.aim and l > 0.12:
			mv = s.d
		elif s.aim and l > 0.18:
			# scherm-rechts = +x en scherm-omlaag = +z, want de camera kijkt naar het noorden
			aim = atan2(s.d.x, s.d.y)
			fire = l > AIM_FIRE
	if is_nan(aim) and _mouse_used and Game.player:
		var cam := get_viewport().get_camera_3d()
		var mp := get_viewport().get_mouse_position()
		var hit = Plane(Vector3.UP, 1.3).intersects_ray(cam.project_ray_origin(mp), cam.project_ray_normal(mp))
		if hit != null:
			var p: Vector3 = Game.player.global_position
			aim = atan2(hit.x - p.x, hit.z - p.z)
		fire = _mouse_down
	if Streak.armed:
		aim = NAN   # napalm staat klaar: de rechterstick richt de strook en schiet niet
		fire = false
	info = "touch %d · sticks %d · %dx%d" % [_events, _sticks.size(), get_viewport_rect().size.x, get_viewport_rect().size.y]
	Game.move = mv.limit_length(1.0)
	Game.aim = aim
	Game.fire = fire and Game.state != "over" and Game.state != "shop" and Game.state != "menu"


func _draw() -> void:
	var touch_hud := UI.is_touch_platform() and not Game.build_mode and (Game.state == "play" or Game.state == "prep")
	if touch_hud:
		for aim in [false, true]:
			var active := false
			for s in _sticks.values():
				if s.aim == aim:
					active = true
			if not active:
				_draw_stick(_anchor(aim), Vector2.ZERO, aim, 0.5)
	for s in _sticks.values():
		_draw_stick(s.origin, s.d, s.aim, 1.0)


func _draw_stick(origin: Vector2, direction: Vector2, aim: bool, alpha: float) -> void:
	var firing := aim and direction.length() > AIM_FIRE
	# De bedienbare zone blijft 76 punten; alleen de getekende ring neemt minder speelbeeld in.
	draw_circle(origin, 64.0, Color(0.015, 0.03, 0.025, 0.12 * alpha))
	draw_arc(origin, 64.0, 0, TAU, 48, Color(1, 0.3, 0.2, 0.72 * alpha) if firing else Color(UI.INK, 0.36 * alpha), 1.5)
	if aim:
		draw_arc(origin, STICK_R * AIM_FIRE, 0, TAU, 40, Color(UI.BRASS, 0.28 * alpha), 1.1)
	var arrow_color := Color(UI.INK, 0.78 * alpha)
	for d in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		_draw_arrow(origin + d * 59.0, d, arrow_color)
	var knob := origin + direction * STICK_R
	draw_circle(knob, 24.0, Color(0.04, 0.055, 0.045, 0.9 * alpha))
	draw_arc(knob, 24.0, 0, TAU, 32, Color(UI.INK, 0.6 * alpha), 1.5)


func _draw_arrow(center: Vector2, direction: Vector2, color: Color) -> void:
	var side := Vector2(-direction.y, direction.x)
	draw_line(center - direction * 3.0, center + direction * 5.0, color, 2.0, true)
	draw_line(center + direction * 5.0, center + direction * 1.0 + side * 4.0, color, 2.0, true)
	draw_line(center + direction * 5.0, center + direction * 1.0 - side * 4.0, color, 2.0, true)
