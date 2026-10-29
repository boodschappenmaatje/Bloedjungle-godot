class_name CombatButtons
extends Control
## Ronde knoppen voor herladen, sprint, granaat en ontwijkrol, rechtsonder binnen bereik van de duim die richt.
## Vaste plekken, zodat ze de sticks, de wapenstrip, de radar en de verdedigingsknoppen niet raken.

var _reload: ActionBtn
var _sprint: ActionBtn
var _grenade: ActionBtn
var _roll: ActionBtn
var _air2: ActionBtn         # kiezer: de andere beloning die klaarstaat (tik om te wisselen)
var _air: ActionBtn          # luchtsteun (killstreak): staat naast GEBRUIK en verschijnt alleen als er een beloning klaarstaat
var _state := ""

## Granaat richten: knop vasthouden en slepen zet de landingscirkel neer (2-12 m), loslaten gooit.
## Terug naar de knop slepen breekt de worp af; alleen tikken gooit 7 m recht vooruit.
const AIM_DEAD := 16.0    # px: binnen deze afstand van het beginpunt telt het als tikken
const AIM_FULL := 120.0   # px: zo ver slepen = maximaal bereik
var aim_finger := -2      # vinger die de granaatknop vasthoudt (-1 = muis), -2 = niet aan het richten
var aim_drag := Vector2.ZERO
var _aim_start := Vector2.ZERO
var _aim_out := false     # de duim is al buiten de knop geweest: terugkomen = afbreken
var _aim_vis: GrenadeAim

## Luchtsteun gebruiken: tikken voert een beloning meteen uit; bij napalm zet vasthouden en slepen de strook neer (8-30 m).
var air_finger := -2
var air_drag := Vector2.ZERO
var _air_start := Vector2.ZERO
var _air_out := false
var _air_vis: NapalmAim
var _place: NapalmPlace       # napalm staat neergezet en wacht op START

## A held support/equipment button promotes to a four-way selector. The pointer remains owned here,
## so opening a wheel can never send its release through to the weapon/fire controls.
const WHEEL_HOLD := 0.42
var _held_action := ""
var _held_pointer := -2
var _held_time := 0.0
var _hold_origin := Vector2.ZERO
var _wheel_kind := ""
var _wheel_sector := -1
var _wheel_sticky := false  # wiel geopend met een tik: blijft open, daarna tik je op een optie
var _wheel_ui: Control      # tekent het wiel boven alle andere HUD-knoppen
const WHEEL_EXIT := 150.0   # px van het midden: verder slepen sluit het wiel en begint met richten


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().size_changed.connect(_cancel_gesture)
	_reload = _make("herlaad", "HERLAAD", func(): _player_call("request_reload"))
	_sprint = _make("sprint", "SPRINT", func(): _player_call("toggle_sprint"))
	_grenade = _make("granaat", "GEBRUIK", func(): pass) # release chooses tap-use or a long-press wheel
	_roll = _make("rol", "ROL", func(): _player_call("request_dodge"))
	_air2 = _make("lucht2", "WISSEL", func():
		Game.streak_sel = String(_air2.reward)
		Sfx.play("click")
		Game.changed.emit())
	_air = _make("lucht", "STEUN", func(): pass)  # de aanraking loopt via _input (tik of slepen)
	_wheel_ui = Control.new()
	_wheel_ui.name = "WheelLayer"
	_wheel_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wheel_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wheel_ui.z_index = 100
	_wheel_ui.draw.connect(_draw_wheel)
	add_child(_wheel_ui)
	resized.connect(_layout)
	_layout()


func _cancel_gesture() -> void:
	_held_pointer = -2
	_held_action = ""
	_held_time = 0.0
	_wheel_kind = ""
	_wheel_sector = -1
	cancel_aim()
	cancel_air()
	queue_redraw()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		_cancel_gesture()


func _make(kind: String, caption: String, action: Callable) -> ActionBtn:
	var b := ActionBtn.make(kind, caption)
	b.focus_mode = Control.FOCUS_NONE
	b.visible = true  # ActionBtn.make verbergt nieuwe knoppen; deze zijn er altijd, de container bepaalt of ze getoond worden
	b.button_down.connect(action)  # reageert meteen bij aanraking, niet pas bij loslaten
	add_child(b)
	return b


func _player_call(method: String) -> void:
	var p = Game.player
	if p != null and is_instance_valid(p):
		p.call(method)


func _use_equipment() -> void:
	match Game.equipment_sel:
		"grenade":
			pass  # gooien gaat via slepen en loslaten (_input)
		"mine":
			if Game.defs != null and is_instance_valid(Game.defs):
				Game.defs.place_kind("mine")


func _input(event: InputEvent) -> void:
	if get_tree().paused:
		_cancel_gesture()
		return
	if _wheel_kind != "" and ((event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT)):
		_wheel_kind = ""
		_held_pointer = -2
		_held_action = ""
		_wheel_sector = -1
		queue_redraw()
		get_viewport().set_input_as_handled()
		return
	if _wheel_input(event):
		return
	_track_wheel_press(event)
	_air_input(event)
	if Game.equipment_sel != "grenade" or not is_visible_in_tree():
		if aim_finger != -2:
			cancel_aim()
		return
	if event is InputEventScreenTouch:
		if event.pressed and aim_finger == -2 and _grenade.get_global_rect().has_point(event.position):
			_begin_aim(event.index, event.position)
		elif not event.pressed and event.index == aim_finger:
			release_aim()
	elif event is InputEventScreenDrag and event.index == aim_finger:
		drag_aim(event.position - _aim_start)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and aim_finger == -2 and _grenade.get_global_rect().has_point(event.position):
			_begin_aim(-1, event.position)
		elif not event.pressed and aim_finger == -1:
			release_aim()
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION and aim_finger == -1:
		drag_aim(event.position - _aim_start)


func _air_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not _air.visible:
		if air_finger != -2:
			cancel_air()
		return
	if event is InputEventScreenTouch:
		if event.pressed and air_finger == -2 and _air.get_global_rect().has_point(event.position):
			_begin_air(event.index, event.position)
		elif not event.pressed and event.index == air_finger:
			release_air()
	elif event is InputEventScreenDrag and event.index == air_finger:
		drag_air(event.position - _air_start)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and air_finger == -2 and _air.get_global_rect().has_point(event.position):
			_begin_air(-1, event.position)
		elif not event.pressed and air_finger == -1:
			release_air()
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION and air_finger == -1:
		drag_air(event.position - _air_start)


func _track_wheel_press(event: InputEvent) -> void:
	if _held_pointer != -2 or _wheel_kind != "":
		return
	var pos := Vector2.ZERO
	var pointer := -2
	var pressed := false
	if event is InputEventScreenTouch:
		pos = event.position
		pointer = event.index
		pressed = event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		pos = event.position
		pointer = -1
		pressed = event.pressed
	if not pressed:
		return
	if _grenade.visible and _grenade.get_global_rect().has_point(pos):
		_held_action = "equipment"
	elif _air.visible and _air.get_global_rect().has_point(pos):
		_held_action = "support"
	else:
		return
	_held_pointer = pointer
	_held_time = 0.0
	_hold_origin = pos


func _wheel_input(event: InputEvent) -> bool:
	if _wheel_kind == "":
		if _held_pointer == -2:
			return false
		var pointer := -2
		var pos := Vector2.ZERO
		var released := false
		if event is InputEventScreenTouch:
			pointer = event.index
			pos = event.position
			released = not event.pressed
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
			pointer = -1
			pos = event.position
			released = not event.pressed
		if pointer == _held_pointer and released:
			var tap_equipment := _held_action == "equipment" and _held_time < WHEEL_HOLD and Game.equipment_sel == "mine"
			_held_pointer = -2
			_held_action = ""
			if tap_equipment:
				_use_equipment()
		return false
	if _wheel_sticky:
		return _sticky_input(event)
	var pointer := -2
	var pos := Vector2.ZERO
	var released := false
	if event is InputEventScreenTouch:
		pointer = event.index
		pos = event.position
		released = not event.pressed
	elif event is InputEventScreenDrag:
		pointer = event.index
		pos = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		pointer = -1
		pos = event.position
		released = not event.pressed
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		pointer = -1
		pos = event.position
	if pointer != _held_pointer:
		if event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton or event is InputEventMouseMotion:
			get_viewport().set_input_as_handled()
			return true
		return false
	if not released:
		_wheel_sector = _sector(pos - _hold_origin)
		if _wheel_sector >= 0 and (pos - _hold_origin).length() > WHEEL_EXIT and _exit_aim(pointer, pos):
			return true
		queue_redraw()
		get_viewport().set_input_as_handled()
		return true
	var kind := _wheel_kind
	var selected := _wheel_sector
	_wheel_kind = ""
	_wheel_sector = -1
	_held_pointer = -2
	_held_action = ""
	if selected >= 0:
		_select_wheel(kind, selected)
	get_viewport().set_input_as_handled()
	queue_redraw()
	return true


func _wheel_center() -> Vector2:
	var safe := UI.safe_margins(size)
	var r := WheelArt.OUTER + 6.0
	return Vector2(clampf(_hold_origin.x, safe.x + r, size.x - safe.z - r), clampf(_hold_origin.y, safe.y + r, size.y - safe.w - r))


## Een tik op de knop opent het wiel als er iets te kiezen valt; het blijft open tot je een optie tikt.
func _multiple_choices(kind: String) -> bool:
	if kind == "support":
		return not Game.streak_others().is_empty()
	return Game.grenades > 0 and int(Game.inv.get("mine", 0)) > 0


func _open_sticky(kind: String, button: ActionBtn) -> void:
	_wheel_kind = kind
	_wheel_sticky = true
	_wheel_sector = -1
	_hold_origin = button.global_position + button.size * 0.5
	Sfx.play("click")
	queue_redraw()


func _close_wheel() -> void:
	_wheel_kind = ""
	_wheel_sticky = false
	_wheel_sector = -1
	queue_redraw()


func _sticky_input(event: InputEvent) -> bool:
	var pos := Vector2.ZERO
	var pressed := false
	if event is InputEventScreenTouch:
		pos = event.position
		pressed = event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		pos = event.position
		pressed = event.pressed
	elif event is InputEventScreenDrag or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
		return true
	else:
		return false
	get_viewport().set_input_as_handled()
	if not pressed:
		return true
	var delta := pos - _wheel_center()
	if delta.length() < WheelArt.INNER or delta.length() > WheelArt.OUTER + 12.0:
		_close_wheel()
		return true
	var kind := _wheel_kind
	var sector := _sector(delta)
	_close_wheel()
	if sector >= 0:
		_sticky_pick(kind, sector)
	return true


## Tikken op een andere optie kiest die; tikken op de gekozen optie gebruikt hem meteen (kort, zonder richten).
func _sticky_pick(kind: String, sector: int) -> void:
	var p = Game.player
	if p == null or not is_instance_valid(p):
		return
	if kind == "equipment":
		var item: String = ["grenade", "c4", "smoke", "mine"][sector]
		if item == Game.equipment_sel and item == "grenade" and p.can_throw_grenade():
			aim_drag = Vector2.ZERO
			p.throw_grenade_at(aim_target())
		elif item == Game.equipment_sel and item == "mine":
			_use_equipment()
		else:
			_select_wheel(kind, sector)
		return
	var reward: String = ["truck", "airstrike", "reinforcement", "napalm"][sector]
	if reward == _air_id() and not p.dead and not p.driving:
		air_drag = Vector2.ZERO
		_use_air(reward, air_aim())
	else:
		_select_wheel(kind, sector)


## Ver buiten het wiel slepen op napalm of granaat: kiezen, het wiel sluit en dezelfde vinger richt meteen verder.
func _exit_aim(pointer: int, pos: Vector2) -> bool:
	var napalm := _wheel_kind == "support" and _wheel_sector == 3 and Game.streak_bank.has("napalm")
	var grenade := _wheel_kind == "equipment" and _wheel_sector == 0 and Game.grenades > 0
	if not napalm and not grenade:
		return false
	_select_wheel(_wheel_kind, _wheel_sector)
	_wheel_kind = ""
	_wheel_sector = -1
	_held_pointer = -2
	_held_action = ""
	queue_redraw()
	if napalm:
		_begin_air(pointer, pos)
	else:
		_begin_aim(pointer, pos)
	get_viewport().set_input_as_handled()
	return true


func _sector(delta: Vector2) -> int:
	if delta.length() < 28.0:
		return -1
	if absf(delta.x) > absf(delta.y):
		return 1 if delta.x > 0.0 else 3
	return 2 if delta.y > 0.0 else 0


func _select_wheel(kind: String, sector: int) -> void:
	if kind == "equipment":
		var choices := ["grenade", "c4", "smoke", "mine"]   # boven, rechts, onder, links (zoals het HUD 3.0-plaatje)
		var item: String = choices[sector]
		if item == "grenade" and Game.grenades > 0 or item == "mine" and int(Game.inv.get("mine", 0)) > 0:
			Game.equipment_sel = item
			Game.changed.emit()
			Sfx.play("click")
		return
	var choices := ["truck", "airstrike", "reinforcement", "napalm"]
	var reward: String = choices[sector]
	if reward in ["truck", "napalm"] and Game.streak_bank.has(reward):
		Game.streak_sel = reward
		Game.changed.emit()
		Sfx.play("click")


func _draw() -> void:
	if _wheel_ui == null:
		return
	# zolang een wiel open is, verdwijnen de knoppen eronder: geen door elkaar lopende pictogrammen
	var open := _wheel_kind != ""
	for b in [_reload, _sprint, _grenade, _roll, _air, _air2]:
		b.modulate.a = 0.0 if open else 1.0
	_wheel_ui.queue_redraw()


func _draw_wheel() -> void:
	var ci := _wheel_ui
	if _wheel_kind == "":
		_wheel_sticky = false
		return
	ci.draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.5))
	var r := WheelArt.OUTER + 6.0
	var center := _wheel_center()
	var items: Array
	if _wheel_kind == "equipment":
		items = [
			{"label": "GRANAAT", "icon": "granaat", "active": Game.grenades > 0, "current": Game.equipment_sel == "grenade"},
			{"label": "C4", "icon": "c4", "active": false},
			{"label": "ROOK", "icon": "rook", "active": false},
			{"label": "MIJN", "icon": "mijn", "active": int(Game.inv.get("mine", 0)) > 0, "current": Game.equipment_sel == "mine"},
		]
	else:
		var now: String = Game.streak_current()
		items = [
			{"label": "TRUCK", "icon": "truck", "active": Game.streak_bank.has("truck"), "current": now == "truck"},
			{"label": "LUCHTAANVAL", "icon": "luchtaanval", "active": false},
			{"label": "VERSTERKING", "icon": "versterking", "active": false},
			{"label": "NAPALM", "icon": "napalm", "active": Game.streak_bank.has("napalm"), "current": now == "napalm"},
		]
	WheelArt.draw(ci, center, items, -PI * 0.5, _wheel_sector)
	var aimable := (_wheel_kind == "support" and _wheel_sector == 3) or (_wheel_kind == "equipment" and _wheel_sector == 0)
	if _wheel_sticky or (aimable and items[_wheel_sector].get("active", false)):
		var f: Font = UI.body(700)
		var t := "Sleep verder om te richten" if not _wheel_sticky else "Tik op de gekozen optie om te gebruiken"
		var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		ci.draw_string(f, Vector2(clampf(center.x - tw * 0.5, 8.0, size.x - tw - 8.0), center.y - r - 8.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.BRASS)


func _air_id() -> String:
	return Game.streak_current()


func _begin_air(finger: int, at: Vector2) -> void:
	var p = Game.player
	if _air_id() == "" or p == null or not is_instance_valid(p) or p.dead or p.driving:
		return
	air_finger = finger
	_air_start = at
	air_drag = Vector2.ZERO
	_air_out = false
	_update_air()


func drag_air(d: Vector2) -> void:
	air_drag = d
	if d.length() > AIM_DEAD:
		_air_out = true
	_update_air()


func release_air() -> void:
	var id := _air_id()
	var cancel := _air_out and air_drag.length() <= AIM_DEAD
	var p = Game.player
	if not _air_out and air_drag.length() <= AIM_DEAD and _multiple_choices("support") and _wheel_kind == "":
		cancel_air()
		_open_sticky("support", _air)
		return
	if not cancel and id != "" and p != null and is_instance_valid(p):
		var a := air_aim()
		_use_air(id, a)
	cancel_air()
	if cancel:
		Sfx.play("click")


## Truck gaat meteen; napalm blijft eerst staan: plek en richting kunnen nog worden verzet en je bevestigt met START.
func _use_air(id: String, a: Dictionary) -> void:
	var p = Game.player
	if id == "napalm":
		if _place == null or not is_instance_valid(_place):
			_place = NapalmPlace.open(self, a.target, a.dir)
		return
	Game.streak_take()
	Streak.use(id, p.get_parent(), a.target, a.dir)


func cancel_air() -> void:
	air_finger = -2
	_air_out = false
	if _air_vis != null and is_instance_valid(_air_vis):
		_air_vis.queue_free()
	_air_vis = null


## Midden en vliegrichting van de napalmstrook: schermrichting = wereldrichting, net als bij de granaat.
func air_aim() -> Dictionary:
	var p = Game.player
	var base: Vector3 = p.global_position
	var l := air_drag.length()
	if l <= AIM_DEAD:
		var f := Vector3(sin(p.face), 0.0, cos(p.face))
		return {"target": base + f * Streak.NAPALM_TAP, "dir": f}
	var d := Vector3(air_drag.x, 0.0, air_drag.y).normalized()
	var k := clampf((l - AIM_DEAD) / (AIM_FULL - AIM_DEAD), 0.0, 1.0)
	return {"target": base + d * lerpf(Streak.NAPALM_RANGE_MIN, Streak.NAPALM_RANGE_MAX, k), "dir": d}


func _update_air() -> void:
	var p = Game.player
	if air_finger == -2 or _air_id() == "" or p == null or not is_instance_valid(p):
		cancel_air()
		return
	if _air_id() != "napalm":
		return   # de truck heeft geen richtcirkel: loslaten gebruikt hem meteen
	if _air_out and air_drag.length() <= AIM_DEAD:
		if _air_vis != null:
			_air_vis.visible = false
		return
	if _air_vis == null or not is_instance_valid(_air_vis):
		_air_vis = NapalmAim.new()
		p.get_parent().add_child(_air_vis)
	_air_vis.visible = true
	var a := air_aim()
	_air_vis.show_strip(a.target, a.dir)


func _begin_aim(finger: int, at: Vector2) -> void:
	var p = Game.player
	if _grenade.disabled or p == null or not is_instance_valid(p) or not p.can_throw_grenade():
		return
	aim_finger = finger
	_aim_start = at
	aim_drag = Vector2.ZERO
	_aim_out = false
	_update_aim()


func drag_aim(d: Vector2) -> void:
	aim_drag = d
	if d.length() > AIM_DEAD:
		_aim_out = true
	_update_aim()


func release_aim() -> void:
	var p = Game.player
	var cancel := _aim_out and aim_drag.length() <= AIM_DEAD
	var tap := not _aim_out and aim_drag.length() <= AIM_DEAD
	if tap and _multiple_choices("equipment") and _wheel_kind == "":
		cancel_aim()
		_open_sticky("equipment", _grenade)
		return
	if not cancel and p != null and is_instance_valid(p):
		p.throw_grenade_at(aim_target())
	cancel_aim()
	if cancel:
		Sfx.play("click")


func cancel_aim() -> void:
	aim_finger = -2
	_aim_out = false
	if _aim_vis != null and is_instance_valid(_aim_vis):
		_aim_vis.queue_free()
	_aim_vis = null


## Doelpunt op de grond: schermrichting = wereldrichting (de camera kijkt naar het noorden, net als de richtstick).
func aim_target() -> Vector3:
	var p = Game.player
	var base: Vector3 = p.global_position
	var l := aim_drag.length()
	if l <= AIM_DEAD:
		return base + Vector3(sin(p.face), 0.0, cos(p.face)) * Grenade.TAP_RANGE
	var dir := Vector3(aim_drag.x, 0.0, aim_drag.y).normalized()
	var k := clampf((l - AIM_DEAD) / (AIM_FULL - AIM_DEAD), 0.0, 1.0)
	return base + dir * lerpf(Grenade.MIN_RANGE, Grenade.MAX_RANGE, k)


func _update_aim() -> void:
	var p = Game.player
	if aim_finger == -2 or p == null or not is_instance_valid(p) or not p.can_throw_grenade():
		cancel_aim()
		return
	if _aim_out and aim_drag.length() <= AIM_DEAD:
		if _aim_vis != null:
			_aim_vis.visible = false  # terug op de knop: loslaten breekt af
		return
	if _aim_vis == null or not is_instance_valid(_aim_vis):
		_aim_vis = GrenadeAim.new()
		p.get_parent().add_child(_aim_vis)
	var a: Dictionary = p.grenade_aim(aim_target())
	_aim_vis.show_throw(a.from, a.target, Grenade.RADIUS * float(Progress.bonus().grenade))


## Alles rechts, binnen bereik van de duim die richt: 2x2 raster in de rechteronderhoek, plus de luchtsteun-knop boven GEBRUIK.
## Onder: sprint + rol, boven: granaat + herlaad. De wisselknop (shop.gd) staat links van het raster.
func _layout() -> void:
	var safe := UI.safe_margins(size)
	var g := ActionBtn.SIZE.x + 8.0
	var x1 := size.x - safe.z - 4.0 - ActionBtn.SIZE.x
	var x0 := x1 - g
	var y1 := size.y - safe.w - 4.0 - ActionBtn.SIZE.y
	if UI.is_touch_platform():
		var stick_center_x := size.x - safe.z - (76.0 if size.x < 880.0 else 86.0)
		var stick_edge_x := stick_center_x - 76.0
		x1 = stick_edge_x - 10.0 - ActionBtn.SIZE.x
		x0 = x1 - g
		if size.x < size.y:
			y1 = size.y - 360.0 - maxf(0.0, safe.w - 12.0)
		else:
			y1 = size.y - safe.w - 4.0 - ActionBtn.SIZE.y
	elif size.x < size.y:
		y1 = size.y - 222.0 - 8.0 - ActionBtn.SIZE.y - maxf(0.0, safe.w - 12.0)  # staand: boven de wapenstrip
	var y0 := y1 - g
	_sprint.position = Vector2(x0, y1)
	_roll.position = Vector2(x1, y1)
	_grenade.position = Vector2(x0, y0)
	_reload.position = Vector2(x1, y0)
	_air2.position = Vector2(x1, y0 - g)   # rechts van de luchtsteun-knop
	_air.position = Vector2(x0, y0 - g)   # boven GEBRUIK: links ervan staat de wapenstrip, erboven de uitrustingskiezer
	for b in [_reload, _sprint, _grenade, _roll, _air, _air2]:
		b.size = ActionBtn.SIZE


func _process(_delta: float) -> void:
	var show := (Game.state == "play" or Game.state == "prep") and not Game.build_mode and not get_tree().paused
	var p = Game.player
	var driving: bool = p != null and is_instance_valid(p) and p.driving
	visible = show and not driving  # in een voertuig: alleen de voertuigknoppen (UIT e.d.), geen granaat/herlaad/sprint/rol
	if not show or p == null or not is_instance_valid(p) or driving:
		if aim_finger != -2:
			cancel_aim()
		if air_finger != -2:
			cancel_air()
		_wheel_kind = ""
		_held_pointer = -2
		_held_action = ""
		_held_time = 0.0
		queue_redraw()
		return
	if _held_pointer != -2 and _wheel_kind == "":
		_held_time += _delta
		if _held_time >= WHEEL_HOLD:
			_wheel_kind = _held_action
			_wheel_sticky = false
			_wheel_sector = -1
			if _held_action == "equipment":
				cancel_aim()
			else:
				cancel_air()
			queue_redraw()
	if aim_finger != -2:
		_update_aim()  # de speler loopt door tijdens het richten: de boog loopt mee
	if air_finger != -2:
		_update_air()
	var rid := _air_id()
	_air.visible = rid != "" and not p.driving and not p.dead
	var others: Array = Game.streak_others()
	_air2.visible = _air.visible and not others.is_empty() and air_finger == -2
	_air2.visible = false # support switching is handled by the support wheel
	if _air2.visible:
		_air2.reward = others[0]
		_air2.set_caption(String(Streak.reward(others[0]).kort))
		_air2.queue_redraw()
	if _air.visible:
		_air.reward = rid
		_air.set_caption(String(Streak.reward(rid).kort))
		var n := Game.streak_bank.count(rid)
		_air.badge = "∞" if Game.streak_test() else "×%d" % n if n > 1 else ""
		_air.queue_redraw()  # de gloeiende ring pulseert
	var w: Dictionary = Game.wstat(p.weapon)
	var reloading: bool = p.reload_t > 0.0
	var equipment_count: int = Game.grenades if Game.equipment_sel == "grenade" else int(Game.inv.get("mine", 0)) if Game.equipment_sel == "mine" else 0
	var key := "%s|%s|%d|%s|%.2f|%.2f|%s|%s|%d" % [str(p.sprint_on), str(p.sprinting), Game.grenades, str(reloading), p.stamina, p.dodge_cd, str(p.ammo >= w.mag), Game.equipment_sel, equipment_count]
	if key == _state:
		return
	_state = key
	_reload.disabled = p.ammo >= w.mag or reloading or p.driving
	_sprint.open_state = p.sprint_on
	_sprint.bar = p.stamina
	_sprint.disabled = p.driving
	_sprint.queue_redraw()
	_grenade.equipment_kind = Game.equipment_sel
	_grenade.set_caption("GRANAAT" if Game.equipment_sel == "grenade" else "MIJN" if Game.equipment_sel == "mine" else "UITRUSTING")
	_grenade.badge = "×%d" % equipment_count
	_grenade.disabled = equipment_count <= 0 or p.driving
	_grenade.queue_redraw()
	_roll.disabled = p.dodge_cd > 0.0 or p.stamina < p.DODGE_COST or p.driving
	_roll.bar = (1.0 - p.dodge_cd / p.DODGE_CD) if p.dodge_cd > 0.0 else -1.0
	_roll.queue_redraw()
	_reload.queue_redraw()
