class_name GateHud
extends Control
## De poort opent vanzelf voor jou en je soldaten. Zodra je erbij staat zweeft er een label boven de poort zelf: tik erop
## (of druk E) om hem te vergrendelen (SLUIT) of weer vrij te geven (OPEN). Bij een beschadigde poort staat er een
## knop die je ingedrukt houdt om hem te repareren (updateGateRepair in 05b-gates.js).

var _btn: ActionBtn
var _fix: ActionBtn
var _brug: ActionBtn
var _holding := false
var _snd := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_btn = _mk("poort", "POORT")
	_btn.pressed.connect(_toggle)
	_brug = _mk("brug", "BRUG")
	_brug.pressed.connect(_toggle_bridge)
	_fix = _mk("repair", "REPAREER")
	_fix.button_down.connect(func(): _holding = true)
	_fix.button_up.connect(func(): _holding = false)


func _mk(kind: String, cap: String) -> ActionBtn:
	var b := ActionBtn.make(kind, cap)
	add_child(b)
	return b


## Zet het label boven de poort in de wereld (schermpositie van de poort), binnen het beeld. False als de poort niet in beeld is.
func _place_on_gate(g: Dictionary) -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return false
	var at: Vector3 = Game.gates.pos_of(g) + Vector3(0.0, 3.2, 0.0)
	if cam.is_position_behind(at):
		return false
	var local := get_global_transform_with_canvas().affine_inverse() * cam.unproject_position(at)
	var safe := UI.safe_margins(size)
	var s := ActionBtn.SIZE
	_btn.size = s
	_btn.position = Vector2(
		clampf(local.x - s.x * 0.5, safe.x + 4.0, maxf(safe.x + 4.0, size.x - safe.z - s.x - 4.0)),
		clampf(local.y - s.y * 0.5, safe.y + 4.0, maxf(safe.y + 4.0, size.y - safe.w - s.y - 4.0)))
	return true


func _toggle() -> void:
	var g: Variant = Game.gates.near_player() if Game.gates else null
	if g != null:
		Game.gates.toggle(g)
	else:
		_toggle_bridge()


func _toggle_bridge() -> void:
	if _bridge_ok() and Game.bridge.near_player():
		Game.bridge.toggle()


func _bridge_ok() -> bool:
	return Game.bridge != null and is_instance_valid(Game.bridge)


func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_E and not Game.build_mode:
		_toggle()


func _process(delta: float) -> void:
	var live := (Game.state == "play" or Game.state == "prep") and not Game.build_mode and Game.gates != null
	var g: Variant = Game.gates.near_player() if live else null
	_btn.visible = g != null
	var near_bridge: bool = live and _bridge_ok() and Game.bridge.near_player()
	_brug.visible = near_bridge
	# in een voertuig staan in- en uitstappen en de truckknoppen op plek 0..2: dan schuiven deze knoppen rechts ernaast
	var driving: bool = Game.player != null and Game.player.driving
	if near_bridge:
		var up: bool = Game.bridge.state != Bridge.DOWN
		_brug.open_state = up
		_brug.set_caption("OMLAAG" if up else "OMHOOG")
		_brug.place(4 if driving else 2, size)
		_brug.queue_redraw()
	var fixable: Variant = null
	if live and Game.player:
		for x in Game.gates.list:
			if not x.broken and x.hp < x.max_hp and Game.player.global_position.distance_to(Game.gates.pos_of(x)) < 3.6:
				fixable = x
	_fix.visible = fixable != null
	if g != null:
		_btn.open_state = g.locked
		_btn.set_caption("OPEN" if g.locked else "SLUIT")
		_btn.bar = -1.0 if g.hp >= g.max_hp else g.hp / g.max_hp
		_btn.visible = _place_on_gate(g)
		_btn.queue_redraw()
	if fixable != null:
		_fix.place(0, size)
		if _holding:
			fixable.hp = minf(fixable.max_hp, fixable.hp + 140.0 * delta)
			_snd -= delta
			if _snd <= 0.0:
				_snd = 0.22
				Sfx.play("ping", 0.5, Game.gates.pos_of(fixable))
			Game.changed.emit() if Engine.get_process_frames() % 15 == 0 else null
	else:
		_holding = false
