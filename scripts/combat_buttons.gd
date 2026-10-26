class_name CombatButtons
extends Control
## Ronde knoppen voor herladen, sprint, granaat en ontwijkrol, rechtsonder binnen bereik van de duim die richt.
## Vaste plekken, zodat ze de sticks, de wapenstrip, de radar en de verdedigingsknoppen niet raken.

var _reload: ActionBtn
var _sprint: ActionBtn
var _grenade: ActionBtn
var _roll: ActionBtn
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


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reload = _make("herlaad", "HERLAAD", func(): _player_call("request_reload"))
	_sprint = _make("sprint", "SPRINT", func(): _player_call("toggle_sprint"))
	_grenade = _make("granaat", "GEBRUIK", _use_equipment)
	_roll = _make("rol", "ROL", func(): _player_call("request_dodge"))
	_air = _make("lucht", "STEUN", func(): pass)  # de aanraking loopt via _input (tik of slepen)
	resized.connect(_layout)
	_layout()


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


func _air_id() -> String:
	if Game.streak_test():
		Game.streak_fill()
	return String(Game.streak_bank.back()) if not Game.streak_bank.is_empty() else ""


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
	if not cancel and id != "" and p != null and is_instance_valid(p):
		var a := air_aim()
		Game.streak_take()
		Streak.use(id, p.get_parent(), a.target, a.dir)
	cancel_air()
	if cancel:
		Sfx.play("click")


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
	_air.position = Vector2(x0, y0 - g)   # boven GEBRUIK: links ervan staat de wapenstrip, erboven de uitrustingskiezer
	for b in [_reload, _sprint, _grenade, _roll, _air]:
		b.size = ActionBtn.SIZE


func _process(_delta: float) -> void:
	var show := (Game.state == "play" or Game.state == "prep") and not Game.build_mode
	visible = show
	var p = Game.player
	if not show or p == null or not is_instance_valid(p):
		if aim_finger != -2:
			cancel_aim()
		return
	if aim_finger != -2:
		_update_aim()  # de speler loopt door tijdens het richten: de boog loopt mee
	if air_finger != -2:
		_update_air()
	var rid := _air_id()
	_air.visible = rid != "" and not p.driving and not p.dead
	if _air.visible:
		_air.reward = rid
		_air.set_caption(String(Streak.reward(rid).kort))
		_air.badge = "∞" if Game.streak_test() else "×%d" % Game.streak_bank.size() if Game.streak_bank.size() > 1 else ""
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
	_grenade.badge = "×%d" % equipment_count
	_grenade.disabled = equipment_count <= 0 or p.driving
	_grenade.queue_redraw()
	_roll.disabled = p.dodge_cd > 0.0 or p.stamina < p.DODGE_COST or p.driving
	_roll.bar = (1.0 - p.dodge_cd / p.DODGE_CD) if p.dodge_cd > 0.0 else -1.0
	_roll.queue_redraw()
	_reload.queue_redraw()
