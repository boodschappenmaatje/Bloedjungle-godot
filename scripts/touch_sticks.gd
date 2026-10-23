class_name TouchSticks
extends Control
## Twee zwevende sticks (20-input.js): waar je duim neerkomt verschijnt de stick.
## Linker helft = lopen. Rechter helft = richten; half duwen richt alleen, tot de rand duwen schiet.
## Op een computer: WASD of pijltjes lopen, muis richten, linkermuisknop schieten.

const STICK_R := 56.0
const AIM_FIRE := 0.8

var _sticks := {}  # vinger-index -> {"aim": bool, "origin": Vector2, "d": Vector2}
var _mouse_used := false
var _mouse_down := false
var _events := 0
static var info := ""  # voor de fps-teller: wat de sticks nu zien (om te kijken waarom ze niet reageren)


func _ready() -> void:
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
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_events += 1
	if Game.build_mode:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _on_button(event.position):
				return
			var aim: bool = event.position.x > get_viewport_rect().size.x * 0.5
			# een nieuwe vinger op deze kant wint: de oude is waarschijnlijk al weg (loslaten gemist), anders
			# blijft de stick "vast" en doet de nieuwe aanraking niets
			for k in _sticks.keys():
				if _sticks[k].aim == aim:
					_sticks.erase(k)
			_sticks[event.index] = {"aim": aim, "origin": event.position, "d": Vector2.ZERO}
			_mouse_used = false
		else:
			_sticks.erase(event.index)
		queue_redraw()
	elif event is InputEventScreenDrag and _sticks.has(event.index):
		var s: Dictionary = _sticks[event.index]
		var d: Vector2 = event.position - s.origin
		if d.length() > STICK_R:
			# de stick schuift mee met je duim
			s.origin += d.normalized() * (d.length() - STICK_R)
			d = d.normalized() * STICK_R
		s.d = d / STICK_R
		queue_redraw()
	elif event is InputEventMouse and event.device != InputEvent.DEVICE_ID_EMULATION:
		_mouse_used = true
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			_mouse_down = event.pressed and not _on_button(event.position)


func _on_button(p: Vector2) -> bool:
	for b: Control in get_tree().get_nodes_in_group("hud_button"):
		if b.is_visible_in_tree() and b.get_global_rect().has_point(p):
			return true
	return false


func _process(_delta: float) -> void:
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
	for s in _sticks.values():
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
	info = "touch %d · sticks %d · %dx%d" % [_events, _sticks.size(), get_viewport_rect().size.x, get_viewport_rect().size.y]
	Game.move = mv.limit_length(1.0)
	Game.aim = aim
	Game.fire = fire and Game.state != "over" and Game.state != "shop" and Game.state != "menu"


func _draw() -> void:
	for s in _sticks.values():
		var fire: bool = s.aim and s.d.length() > AIM_FIRE
		draw_circle(s.origin, STICK_R, Color(0.015, 0.03, 0.025, 0.2))
		draw_arc(s.origin, STICK_R, 0, TAU, 40, Color(1, 0.3, 0.2, 0.8) if fire else Color(UI.BRASS, 0.38), 1.6)
		if s.aim:
			draw_arc(s.origin, STICK_R * AIM_FIRE, 0, TAU, 40, Color(UI.INK, 0.22), 1.2)  # vanaf hier schiet hij
		var knob: Vector2 = s.origin + s.d * STICK_R
		draw_circle(knob, 24.0, Color(0.07, 0.09, 0.075, 0.92))
		draw_arc(knob, 24.0, 0, TAU, 32, Color(UI.INK, 0.5), 1.4)
