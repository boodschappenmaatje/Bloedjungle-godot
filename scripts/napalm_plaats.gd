class_name NapalmPlace
extends Control
## Napalm plaatsen met tikken en bevestigen: na het kiezen blijft de strook staan. Tik op het veld waar hij moet komen, sleep vanaf die plek
## om de vliegrichting te draaien, en druk daarna op START (of op de kruisknop om te annuleren). Er gaat niets af voor je bevestigt.

const REACH_MIN := 6.0
const REACH_MAX := 42.0     # m van de speler: verder dan het gewone slepen (30 m), want je tikt nu rechtstreeks
const TURN_MIN := 22.0      # px slepen voor de richting verandert
const BTN_GO := Vector2(190, 52)
const BTN_X := Vector2(52, 52)

var center := Vector3.ZERO
var dir := Vector3.FORWARD
var _vis: NapalmAim
var _finger := -2           # vinger die het veld vasthoudt (-1 = muis)
var _press := Vector2.ZERO
var _turned := false
var _hint_t := 0.0


## target/dir: de strook zoals hij na het richten stond; hij verschijnt direct en kan nog worden verzet.
static func open(parent: Control, target: Vector3, d: Vector3) -> NapalmPlace:
	var n := NapalmPlace.new()
	n.center = target
	n.dir = d
	parent.add_child(n)
	return n


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 90
	var p = Game.player
	if p != null and is_instance_valid(p):
		_vis = NapalmAim.new()
		p.get_parent().add_child(_vis)
	_update()
	Sfx.play("click")


func _exit_tree() -> void:
	if _vis != null and is_instance_valid(_vis):
		_vis.queue_free()
	_vis = null


func _go_rect() -> Rect2:
	return Rect2(Vector2(size.x * 0.5 - BTN_GO.x * 0.5 + 40.0, size.y * 0.66), BTN_GO)


func _x_rect() -> Rect2:
	return Rect2(Vector2(size.x * 0.5 - BTN_GO.x * 0.5 - BTN_X.x - 6.0 + 40.0, size.y * 0.66), BTN_X)


## Het deel van het scherm waar je de strook neer kunt zetten: niet op de sticks links en rechts, niet op de knoppen onderaan.
func _field() -> Rect2:
	return Rect2(Vector2(size.x * 0.26, size.y * 0.1), Vector2(size.x * 0.48, size.y * 0.6))


func _process(delta: float) -> void:
	var p = Game.player
	if p == null or not is_instance_valid(p) or p.dead or p.driving or (Game.state != "play" and Game.state != "prep") or not Game.streak_bank.has("napalm"):
		queue_free()
		return
	_hint_t += delta
	queue_redraw()


func _input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	var pointer := -2
	var kind := ""
	if event is InputEventScreenTouch:
		pos = event.position
		pointer = event.index
		kind = "down" if event.pressed else "up"
	elif event is InputEventScreenDrag:
		pos = event.position
		pointer = event.index
		kind = "move"
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		pointer = -1
		kind = "down" if event.pressed else "up"
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION and _finger == -1:
		pos = event.position
		pointer = -1
		kind = "move"
	else:
		return
	if kind == "down":
		if _go_rect().has_point(pos):
			_confirm()
			get_viewport().set_input_as_handled()
		elif _x_rect().has_point(pos):
			_cancel()
			get_viewport().set_input_as_handled()
		elif _finger == -2 and _field().has_point(pos):
			_finger = pointer
			_press = pos
			_turned = false
			_set_center(pos)
			get_viewport().set_input_as_handled()
	elif pointer == _finger:
		if kind == "move":
			var d := pos - _press
			if d.length() > TURN_MIN:
				_turned = true
				dir = Vector3(d.x, 0.0, d.y).normalized()   # schermrichting = wereldrichting, net als bij de granaat
				_update()
		elif kind == "up":
			_finger = -2
		get_viewport().set_input_as_handled()


## Tikplek op het scherm -> punt op de grond (de camera kijkt schuin naar beneden), begrensd rond de speler.
func _set_center(at: Vector2) -> void:
	var p = Game.player
	var cam := p.get_parent().get_node_or_null("Camera") as Camera3D
	if cam == null:
		return
	var o := cam.project_ray_origin(at)
	var n := cam.project_ray_normal(at)
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(o, n)
	if hit == null:
		return
	var base: Vector3 = p.global_position
	var off: Vector3 = Vector3(hit.x - base.x, 0.0, hit.z - base.z)
	var l := clampf(off.length(), REACH_MIN, REACH_MAX)
	center = base + (off.normalized() if off.length() > 0.01 else dir) * l
	center.y = 0.0
	_update()


func _update() -> void:
	if _vis != null and is_instance_valid(_vis):
		_vis.show_strip(center, dir)


func _confirm() -> void:
	var p = Game.player
	if p != null and is_instance_valid(p) and Game.streak_bank.has("napalm"):
		Game.streak_take()
		Streak.use("napalm", p.get_parent(), center, dir)
	queue_free()


func _cancel() -> void:
	Sfx.play("click")
	queue_free()


func _draw() -> void:
	var f: Font = UI.body(700)
	var go := _go_rect()
	var x := _x_rect()
	var warn := _vis != null and is_instance_valid(_vis) and _vis.self_in_strip
	var col := Color(1.0, 0.5, 0.1) if warn else UI.BRASS
	draw_rect(go, Color(0.08, 0.06, 0.03, 0.88))
	draw_rect(go, col, false, 2.0)
	var t := "START NAPALM"
	var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	draw_string(f, go.position + Vector2((go.size.x - tw) * 0.5, go.size.y * 0.5 + 7.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)
	draw_rect(x, Color(0.08, 0.06, 0.03, 0.88))
	draw_rect(x, UI.BRASS, false, 2.0)
	var c := x.get_center()
	draw_line(c + Vector2(-9, -9), c + Vector2(9, 9), UI.BRASS, 3.0)
	draw_line(c + Vector2(-9, 9), c + Vector2(9, -9), UI.BRASS, 3.0)
	var hint := "Je staat zelf in de strook!" if warn else "Tik waar het moet · sleep om te draaien"
	var hw := f.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(f, Vector2(size.x * 0.5 - hw * 0.5 + 40.0, go.position.y - 12.0), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)
