class_name CombatButtons
extends Control
## Ronde knoppen voor herladen, sprint, granaat en ontwijkrol, rechtsonder binnen bereik van de duim die richt.
## Vaste plekken, zodat ze de sticks, de wapenstrip, de radar en de verdedigingsknoppen niet raken.

var _reload: ActionBtn
var _sprint: ActionBtn
var _grenade: ActionBtn
var _roll: ActionBtn
var _stance: ActionBtn        # houding: staan, hurken, liggen (alleen de Meshy-speler)
var _stance_down_ms := 0
var _sprint_down_ms := 0
var _air2: ActionBtn         # kiezer: de andere beloning die klaarstaat (tik om te wisselen)
var _air: ActionBtn          # luchtsteun (killstreak): staat naast GEBRUIK en verschijnt alleen als er een beloning klaarstaat
var _arty: ActionBtn         # artilleriecommando (hoofdkwartier niveau 3): boven de luchtsteun-knop, 90 s afkoeling
var _state := ""

## Uitrusting kiezen en granaat werpen zijn op iPhone gescheiden: rechterstick richt, loslaten gooit.
## Terug naar de knop slepen breekt de worp af; alleen tikken gooit 7 m recht vooruit.
const AIM_DEAD := 16.0    # px: binnen deze afstand van het beginpunt telt het als tikken
const AIM_FULL := 120.0   # px: zo ver slepen = maximaal bereik
var aim_finger := -2      # vinger die de granaatknop vasthoudt (-1 = muis), -2 = niet aan het richten
var aim_drag := Vector2.ZERO
var _aim_start := Vector2.ZERO
var _aim_out := false     # de duim is al buiten de knop geweest: terugkomen = afbreken
var _aim_vis: GrenadeAim
var grenade_stick_armed := false  # pending one deliberate right-stick throw

## Luchtsteun gebruiken: tikken voert een beloning meteen uit; bij napalm zet vasthouden en slepen de strook neer (8-30 m).
var air_finger := -2
var air_drag := Vector2.ZERO
var _air_start := Vector2.ZERO
var _air_out := false
var _air_vis: NapalmAim
var _place: NapalmPlace       # napalm staat neergezet en wacht op START

## Artilleriecommando: knop vasthouden en slepen richt de ring (14-60 m), loslaten roept de granaten, tikken richt op de dichtstbijzijnde vijand.
var arty_finger := -2
var arty_drag := Vector2.ZERO
var _arty_start := Vector2.ZERO
var _arty_out := false
var _arty_vis: ArtillerieAim

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
	add_to_group("combat_buttons")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().size_changed.connect(_cancel_gesture)
	_reload = _make("herlaad", "HERLAAD", func(): _player_call("request_reload"))
	_sprint = _make("sprint", "SPRINT", func(): _sprint_down_ms = Time.get_ticks_msec())
	_sprint.button_up.connect(func():
		if Time.get_ticks_msec() - _sprint_down_ms >= 420 and UI.is_touch_platform():
			_player_call("request_dodge")
		else:
			_player_call("toggle_sprint"))
	_sprint.tooltip_text = "Tik: sprint · ingedrukt houden: ontwijkrol"
	_grenade = _make("granaat", "UITRUSTING", func(): pass) # only equipment wheel, never release-to-throw
	_grenade.tooltip_text = "Uitrusting kiezen · GRANAAT daarna richten met de rechterstick"
	_roll = _make("rol", "ROL", func(): _player_call("request_dodge"))
	_roll.visible = not UI.is_touch_platform()
	_stance = _make("houding", "HOUDING", func(): _stance_down_ms = Time.get_ticks_msec())
	_stance.button_up.connect(func(): _player_call_args("cycle_stance", [Time.get_ticks_msec() - _stance_down_ms >= 420]))   # tik: doorschakelen, lang: plat/opstaan
	_air2 = _make("lucht2", "WISSEL", func():
		Game.streak_sel = String(_air2.reward)
		Sfx.play("click")
		Game.changed.emit())
	_air = _make("lucht", "STEUN", func(): pass)  # de aanraking loopt via _input (tik of slepen)
	_arty = _make("artillerie", "ARTILLERIE", func(): pass)  # de aanraking loopt via _input (tik of slepen)
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
	cancel_grenade_stick()
	cancel_aim()
	cancel_air()
	cancel_arty()
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


func _player_call_args(method: String, args: Array) -> void:
	var p = Game.player
	if p != null and is_instance_valid(p):
		p.callv(method, args)


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
	_arty_input(event)
	# Mobile grenade selection is NOT a dragging gesture on this button.
	# Desktop mouse keeps the existing hold/drag behavior.
	if UI.is_touch_platform():
		return
	if Game.equipment_sel != "grenade" or not is_visible_in_tree():
		if aim_finger != -2:
			cancel_aim()
		return
	if event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
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


func _arty_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not _arty.visible:
		if arty_finger != -2:
			cancel_arty()
		return
	if event is InputEventScreenTouch:
		if event.pressed and arty_finger == -2 and _arty.get_global_rect().has_point(event.position):
			_begin_arty(event.index, event.position)
		elif not event.pressed and event.index == arty_finger:
			release_arty()
	elif event is InputEventScreenDrag and event.index == arty_finger:
		drag_arty(event.position - _arty_start)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and arty_finger == -2 and _arty.get_global_rect().has_point(event.position):
			_begin_arty(-1, event.position)
		elif not event.pressed and arty_finger == -1:
			release_arty()
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION and arty_finger == -1:
		drag_arty(event.position - _arty_start)


func _begin_arty(finger: int, at: Vector2) -> void:
	var p = Game.player
	if _arty.disabled or p == null or not is_instance_valid(p) or p.dead or p.driving:
		return
	arty_finger = finger
	_arty_start = at
	arty_drag = Vector2.ZERO
	_arty_out = false
	_update_arty()


func drag_arty(d: Vector2) -> void:
	arty_drag = d
	if d.length() > AIM_DEAD:
		_arty_out = true
	_update_arty()


func release_arty() -> void:
	var cancel := _arty_out and arty_drag.length() <= AIM_DEAD   # terug naar de knop slepen breekt af
	var p = Game.player
	if not cancel and p != null and is_instance_valid(p) and not p.dead and Artillerie.ready_now():
		Artillerie.call_in(p.get_parent(), arty_target())
	cancel_arty()
	if cancel:
		Sfx.play("click")


func cancel_arty() -> void:
	arty_finger = -2
	_arty_out = false
	if _arty_vis != null and is_instance_valid(_arty_vis):
		_arty_vis.queue_free()
	_arty_vis = null


## Doelpunt van het artilleriecommando: schermrichting = wereldrichting, net als bij granaat en napalm.
func arty_target() -> Vector3:
	var p = Game.player
	var l := arty_drag.length()
	if l <= AIM_DEAD:
		return Artillerie.tap_target(p.global_position, Vector3(sin(p.face), 0.0, cos(p.face)))
	var d := Vector3(arty_drag.x, 0.0, arty_drag.y).normalized()
	return Artillerie.drag_target(p.global_position, d, (l - AIM_DEAD) / (AIM_FULL - AIM_DEAD))


func _update_arty() -> void:
	var p = Game.player
	if arty_finger == -2 or p == null or not is_instance_valid(p):
		cancel_arty()
		return
	if _arty_out and arty_drag.length() <= AIM_DEAD:
		if _arty_vis != null:
			_arty_vis.visible = false
		return
	if _arty_vis == null or not is_instance_valid(_arty_vis):
		_arty_vis = ArtillerieAim.new()
		p.get_parent().add_child(_arty_vis)
	_arty_vis.visible = true
	_arty_vis.show_at(arty_target())


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
			var open_equipment := _held_action == "equipment" and _held_time < WHEEL_HOLD
			_held_pointer = -2
			_held_action = ""
			if open_equipment:
				_open_sticky("equipment", _grenade)
				get_viewport().set_input_as_handled()
				return true
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
	cancel_grenade_stick()  # re-opening equipment picker cancels pending throw
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
		if item == Game.equipment_sel and item == "mine":
			_use_equipment()
		else:
			# Selecting GRANAAT *never* throws; it arms the next right-stick release.
			_select_wheel(kind, sector)
		return
	var reward: String = ["truck", "airstrike", "reinforcement", "napalm"][sector]
	if reward == _air_id() and not p.dead and not p.driving:
		air_drag = Vector2.ZERO
		_use_air(reward, air_aim())
	else:
		_select_wheel(kind, sector)


## Buiten het wiel slepen kiest het item. Alleen NAPALM gebruikt dezelfde vinger; GRANAAT vereist een NIEUWE rechterstick-aanraking.
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
	# Grenade requires a NEW touch on the right stick, never inheriting
	# the finger used to drag out of the equipment wheel.
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
			if item == "grenade" and UI.is_touch_platform():
				arm_grenade_stick()
			else:
				cancel_grenade_stick()
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
	for b in [_reload, _sprint, _grenade, _roll, _air, _air2, _stance, _arty]:
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
		var t := ("Kies GRANAAT · daarna rechterstick" if _wheel_sticky else "GRANAAT kiezen, daarna stick") if _wheel_kind == "equipment" else ("Sleep verder om te richten" if not _wheel_sticky else "Tik op de optie om te gebruiken")
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


## A selected grenade becomes a one-shot touch-mode, not a HUD button drag.
## A throw can ONLY be committed by release of the exact right-stick finger
## that acquired the gesture; returning to center cancels without inventory use.
func wheel_is_open() -> bool:
	return _wheel_kind != ""


func arm_grenade_stick() -> void:
	var p = Game.player
	if not UI.is_touch_platform() or p == null or not is_instance_valid(p) or not p.can_throw_grenade():
		return
	cancel_grenade_stick()
	grenade_stick_armed = true
	Game.fire = false
	var sticks := get_tree().get_first_node_in_group("touch_sticks")
	if sticks != null:
		sticks.clear_right_for_grenade()
	queue_redraw()


func grenade_stick_begin(pointer: int) -> void:
	if not grenade_stick_armed or aim_finger != -2 or wheel_is_open():
		return
	var p = Game.player
	if p == null or not is_instance_valid(p) or not p.can_throw_grenade():
		cancel_grenade_stick()
		return
	aim_finger = pointer
	aim_drag = Vector2.ZERO
	_aim_out = false
	# Do not display the default 7m tap target until the player actually aims.


func grenade_stick_drag(pointer: int, stick_direction: Vector2) -> void:
	if not grenade_stick_armed or pointer != aim_finger:
		return
	# Reuse the exact existing 2..12m trajectory/target calculation.
	aim_drag = stick_direction.limit_length(1.0) * AIM_FULL
	if aim_drag.length() > AIM_DEAD:
		_aim_out = true
	_update_aim()


func grenade_stick_release(pointer: int) -> void:
	if not grenade_stick_armed or pointer != aim_finger:
		return
	var p = Game.player
	var should_throw: bool = aim_drag.length() > AIM_DEAD and _aim_out and not wheel_is_open() \
		and p != null and is_instance_valid(p) and p.can_throw_grenade()
	var target := aim_target() if should_throw else Vector3.ZERO
	cancel_grenade_stick()  # disarm BEFORE throwing to prevent double release
	if should_throw:
		p.throw_grenade_at(target)


func cancel_grenade_stick() -> void:
	grenade_stick_armed = false
	cancel_aim()
	queue_redraw()


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
	if (grenade_stick_armed or _aim_out) and aim_drag.length() <= AIM_DEAD:
		if _aim_vis != null:
			_aim_vis.visible = false  # terug in stickmidden annuleert de worp
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
	# Separate equipment picker sits just ABOVE/LEFT of the actual weapon bar.
	# Use the rendered bar anchor so portrait/landscape and safe areas agree.
	var weapon_strip := get_tree().get_first_node_in_group("weapon_strip")
	var weapon_bar_start := Vector2(maxf(safe.x + 152.0, size.x * 0.5 - 110.0),
		size.y - (252.0 if size.x < size.y else 82.0) - maxf(0.0, safe.w - 12.0))
	if weapon_strip != null:
		var bar_prev := weapon_strip.get("_prev") as Control
		if bar_prev != null:
			weapon_bar_start = bar_prev.position
	_grenade.position = Vector2(maxf(safe.x + 4.0, weapon_bar_start.x - ActionBtn.SIZE.x - 12.0),
		weapon_bar_start.y - ActionBtn.SIZE.y - 9.0)
	_reload.position = Vector2(x1, y0)
	_air2.position = Vector2(x1, y0 - g)   # rechts van de luchtsteun-knop
	_stance.position = Vector2(x1, y0 - 2.0 * g)   # vrij van plaatsingsvakken en de rechter joystick
	_air.position = Vector2(x0, y0 - g)   # boven GEBRUIK: links ervan staat de wapenstrip, erboven de uitrustingskiezer
	_arty.position = Vector2(x0, y0 - 2.0 * g)   # boven de luchtsteun-knop (alleen met hoofdkwartier niveau 3)
	for b in [_reload, _sprint, _grenade, _roll, _air, _air2, _stance, _arty]:
		b.size = ActionBtn.SIZE


## Artillerieknop: alleen met hoofdkwartier niveau 3; tijdens de afkoeling grijs met een ring en de seconden erbij.
func _update_arty_button(p) -> void:
	_arty.visible = Game.hq_level >= 3 and not p.driving and not p.dead
	if not _arty.visible:
		return
	var cd: float = Game.artillery_cd
	var ready_ := cd <= 0.0
	var key := "%s|%d" % [str(ready_), ceili(cd)]
	if ready_:
		_arty.queue_redraw()   # de ring pulseert zolang het commando klaarstaat
	if key == _arty.get_meta("ak", ""):
		return
	_arty.set_meta("ak", key)
	_arty.disabled = not ready_
	_arty.bar = -1.0 if ready_ else 1.0 - cd / Artillerie.COOLDOWN
	_arty.badge = "" if ready_ else "%ds" % ceili(cd)
	_arty.queue_redraw()


func _process(_delta: float) -> void:
	var show := (Game.state == "play" or Game.state == "prep") and not Game.build_mode and not get_tree().paused
	var p = Game.player
	var driving: bool = p != null and is_instance_valid(p) and p.driving
	visible = show and not driving  # in een voertuig: alleen de voertuigknoppen (UIT e.d.), geen granaat/herlaad/sprint/rol
	if not show or p == null or not is_instance_valid(p) or driving or p.dead:
		cancel_grenade_stick()
		if aim_finger != -2:
			cancel_aim()
		if air_finger != -2:
			cancel_air()
		if arty_finger != -2:
			cancel_arty()
		_wheel_kind = ""
		_held_pointer = -2
		_held_action = ""
		_held_time = 0.0
		queue_redraw()
		return
	if grenade_stick_armed and not p.can_throw_grenade():
		cancel_grenade_stick()  # no phantom grenade mode after ammo/death/airborne
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
	if arty_finger != -2:
		_update_arty()
	_update_arty_button(p)
	var rid := _air_id()
	_air.visible = rid != "" and not p.driving and not p.dead
	var others: Array = Game.streak_others()
	_air2.visible = _air.visible and not others.is_empty() and air_finger == -2
	_air2.visible = false # support switching is handled by the support wheel
	_stance.visible = p.model.meshy_player and not Game.place_armed
	_roll.visible = not UI.is_touch_platform()
	if _stance.stance != p.stance:
		_stance.stance = p.stance
		_stance.queue_redraw()
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
	_reload.disabled = not p.can_reload() or reloading or p.driving
	_sprint.open_state = p.sprint_on
	_sprint.bar = p.stamina
	_sprint.disabled = p.driving
	_sprint.queue_redraw()
	_grenade.equipment_kind = Game.equipment_sel
	_grenade.set_caption("UITRUSTING")
	_grenade.badge = "×%d" % equipment_count
	_grenade.disabled = (Game.grenades <= 0 and int(Game.inv.get("mine", 0)) <= 0) or p.driving
	_grenade.queue_redraw()
	_roll.disabled = p.dodge_cd > 0.0 or p.stamina < p.DODGE_COST or p.driving
	_roll.bar = (1.0 - p.dodge_cd / p.DODGE_CD) if p.dodge_cd > 0.0 else -1.0
	_roll.queue_redraw()
	_reload.queue_redraw()
