class_name VoorraadTruck
extends StaticBody3D
## Een voorraadtruck (Generals-plan stap 4, A1): rijdt vanuit het depot over een vaste route met wegpunten naar een stapel, laadt daar met
## zijn kraan en grijper, rijdt terug en levert af. Hij kan kapot: dan blijft een wrak liggen en de lading is weg.
## 4b: het echte model (bron/voorraad/maak_truck.py): kraan en grijper pakken een kist van de stapel (clip `Laden`) en zetten hem bij het depot
## op de laadplaat (clip `Lossen`, daarna tilt de portaalkraan van het depot hem weg). Wrakmodel apart. Wielen draaien mee met de snelheid.

enum S { WACHT, HEEN, LADEN, TERUG, LOSSEN, WRAK }
const SPEED := 6.0        # m/s
const TURN := 2.4         # rad/s
const MODEL := "res://assets/voorraadtruck.glb"
const MODEL_LOD := "res://assets/voorraadtruck_lod1.glb"
const WRECK_MODEL := "res://assets/voorraadtruck_wrak.glb"
const LOD_SWITCH := 70.0   # m: daarachter het eenvoudige model
const LOAD_T := 4.5       # s laden (lengte van de clip `Laden`)
const UNLOAD_T := 4.5     # s lossen (lengte van de clip `Lossen`)
const LOAD_TAKE := 0.5    # op dit deel van het laden zit de kist in de klauwen: dan gaat de voorraad van de stapel
const UNLOAD_DROP := 0.7  # op dit deel van het lossen staat de kist op de laadplaat: dan komt het geld binnen en pakt de portaalkraan hem
const REACH_UNLOAD := 5.64 # m voor de truck waar de grijper de kist neerzet (clip `Lossen`)
const WHEEL_R := 0.55
const HP_MAX := 400.0
const WRECK_T := 90.0     # s dat het wrak blijft liggen
const BULLET_TAKE := 0.5  # een kogel doet de helft van zijn schade aan het pantser
const NAMES := {S.WACHT: "wacht in het depot", S.HEEN: "onderweg naar de stapel", S.LADEN: "laadt", S.TERUG: "onderweg naar het depot", S.LOSSEN: "lost", S.WRAK: "wrak"}

var sup: Voorraad
var depot: Dictionary = {}
var number := 1
var state := S.WACHT
var hp := HP_MAX
var cargo := 0
var slot := -1
var site_id := ""
var path: Array = []       # nog te rijden punten (Vector2 x,z)
var _back: Array = []      # de route terug (omgekeerd van de heenweg)
var _t := 0.0
var _model: Node3D
var _wreck: Node3D
var _anim: AnimationPlayer # de clips Laden en Lossen
var _lading: Node3D        # de kisten in de bak (de clips schalen ze aan en uit)
var _wheels: Array = []    # {node, base, sign}
var _wheel_ang := 0.0
var _dropped := false
var _dust: CPUParticles3D
var _snd: AudioStreamPlayer3D
var _speed_now := 0.0
var _last_state := -1


func setup(sup_: Voorraad, depot_: Dictionary, number_: int) -> void:
	sup = sup_
	depot = depot_
	number = number_
	name = "Voorraadtruck%d" % number
	add_to_group("voorraadtruck")
	collision_layer = Bullet.MASK_VEHICLE
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.6, 2.4, 6.4)
	cs.shape = bs
	cs.position = Vector3(0, 1.3, 0)
	add_child(cs)
	_build_model()
	_build_wreck()
	_build_dust()
	_build_sound()
	var at: Vector2 = sup.dock_point(depot)
	position = Vector3(at.x, 0.0, at.y)
	rotation.y = float(depot.yaw)
	_set_state(S.WACHT)


func _build_model() -> void:
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	var m := VoorraadModellen.laad(MODEL, _model, 0.0, LOD_SWITCH)
	VoorraadModellen.laad(MODEL_LOD, _model, LOD_SWITCH, 0.0)
	_anim = m.find_child("AnimationPlayer", true, false)
	_lading = m.find_child("Lading", true, false) as Node3D
	for n in ["Wiel_FL", "Wiel_FR", "Wiel_ML", "Wiel_MR", "Wiel_RL", "Wiel_RR"]:
		var w := m.find_child(n, true, false) as Node3D
		if w != null:
			# de linkerwielen staan 180 graden gedraaid (as naar binnen): hun voorwaartse draairichting is omgekeerd
			_wheels.append({"node": w, "base": w.transform.basis, "sign": -1.0 if n.ends_with("L") else 1.0})
	_set_lading(false)


func _build_wreck() -> void:
	_wreck = Node3D.new()
	_wreck.name = "Wrak"
	add_child(_wreck)
	VoorraadModellen.laad(WRECK_MODEL, _wreck)
	_wreck.visible = false


## De kisten in de bak aan of uit (buiten de clips om).
func _set_lading(on: bool) -> void:
	if _lading != null:
		_lading.scale = Vector3.ONE if on else Vector3.ONE * 0.001


func _play(clip: String) -> void:
	if _anim != null and _anim.has_animation(clip):
		_anim.stop()
		_anim.play(clip)


## De wielen draaien met de snelheid mee.
func _spin_wheels(delta: float) -> void:
	if _wheels.is_empty() or _speed_now < 0.05:
		return
	_wheel_ang = fmod(_wheel_ang + _speed_now * delta / WHEEL_R, TAU)
	for w in _wheels:
		(w.node as Node3D).transform.basis = (w.base as Basis) * Basis(Vector3.RIGHT, _wheel_ang * float(w.sign))


func _build_dust() -> void:
	_dust = CPUParticles3D.new()
	_dust.name = "Stof"
	_dust.amount = 14
	_dust.lifetime = 1.5
	_dust.local_coords = false
	_dust.emitting = false
	_dust.direction = Vector3(0, 0.6, -1)
	_dust.spread = 30.0
	_dust.initial_velocity_min = 0.6
	_dust.initial_velocity_max = 1.4
	_dust.gravity = Vector3(0, 0.1, 0)
	_dust.scale_amount_min = 0.7
	_dust.scale_amount_max = 1.5
	var sm := SphereMesh.new()
	sm.radius = 0.45
	sm.height = 0.9
	sm.radial_segments = 6
	sm.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(0.62, 0.55, 0.42, 1.0)
	sm.material = m
	_dust.mesh = sm
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.38))
	g.set_color(1, Color(1, 1, 1, 0.0))
	_dust.color_ramp = g
	_dust.position = Vector3(0, 0.4, -3.2)
	add_child(_dust)


func _build_sound() -> void:
	_snd = AudioStreamPlayer3D.new()
	_snd.name = "Motor"
	_snd.stream = sup.engine_stream()
	_snd.volume_db = -22.0
	_snd.max_distance = 38.0
	_snd.unit_size = 6.0
	_snd.position = Vector3(0, 1.0, 2.0)
	add_child(_snd)


func _set_state(s: int) -> void:
	state = s
	_t = 0.0
	if s != _last_state:
		_last_state = s
		Game.changed.emit()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(sup):
		return
	match state:
		S.WACHT:
			_idle()
		S.HEEN:
			if _drive(delta):
				_set_state(S.LADEN)
		S.LADEN:
			_load_step(delta)
		S.TERUG:
			if _drive(delta):
				_set_state(S.LOSSEN)
		S.LOSSEN:
			_unload_step(delta)
		S.WRAK:
			_t += delta
			if _t > WRECK_T:
				queue_free()
	_spin_wheels(delta)
	var moving := _speed_now > 0.5 and (state == S.HEEN or state == S.TERUG)
	_dust.emitting = moving
	if moving and not _snd.playing:
		_snd.play()
	elif not moving and _snd.playing:
		_snd.stop()
	if moving:
		_snd.pitch_scale = 0.8 + _speed_now / SPEED * 0.35


func _idle() -> void:
	_speed_now = 0.0
	if Game.state != "play" and Game.state != "prep":
		return
	if not Game.buildings.has(depot) or depot.down or Buildings.under_construction(depot):
		return
	var pick := sup.pick_slot(self)
	if pick < 0:
		return
	slot = pick
	site_id = sup.stapels[pick].site.id
	path = sup.route(depot, pick)
	_back = path.duplicate()
	_back.reverse()
	if path.size() > 0:
		path.pop_front()   # de eerste is het depot zelf
	sup.claim(pick, 1)
	_set_state(S.HEEN)


## Rijdt het pad af. Geeft true als het einde bereikt is.
func _drive(delta: float) -> bool:
	if path.is_empty():
		_speed_now = 0.0
		return true
	var target: Vector2 = path[0]
	var here := Vector2(global_position.x, global_position.z)
	var to := target - here
	var arrive := 2.2 if path.size() > 1 else 0.6
	if to.length() < arrive:
		path.pop_front()
		return path.is_empty()
	var want := atan2(to.x, to.y)
	var diff := absf(angle_difference(rotation.y, want))
	rotation.y += clampf(angle_difference(rotation.y, want), -TURN * delta, TURN * delta)
	var v := SPEED * clampf(1.15 - diff / 1.1, 0.12, 1.0)
	if path.size() == 1:
		v = minf(v, maxf(1.5, to.length() * 1.4))   # vlak voor de stop afremmen
	_speed_now = v
	var fwd := Vector3(sin(rotation.y), 0.0, cos(rotation.y))
	global_position += fwd * v * delta
	return false


func _load_step(delta: float) -> void:
	_speed_now = 0.0
	if _t == 0.0:
		if not sup.has_stock(slot, site_id):
			_go_home(0)   # de stapel is intussen leeg: met lege handen terug, daar kiest hij een andere
			return
		_play("Laden")
	_t += delta
	var f := _t / LOAD_T
	if f >= LOAD_TAKE and cargo == 0:
		cargo = sup.take(slot, site_id, sup.trip_value(depot, slot))
		var st = sup.stapels[slot] if slot >= 0 and slot < sup.stapels.size() else null
		if st != null and is_instance_valid(st):
			st.pickup_taken(true)
	if f >= 1.0:
		_go_home(cargo)


func _go_home(amount: int) -> void:
	sup.claim(slot, -1)
	cargo = amount
	_set_lading(cargo > 0)
	if cargo <= 0 and _anim != null:
		_anim.stop()
	var st = sup.stapels[slot] if slot >= 0 and slot < sup.stapels.size() else null
	if st != null and is_instance_valid(st):
		st.pickup_taken(false)
	path = _back.duplicate()
	_set_state(S.TERUG)


func _unload_step(delta: float) -> void:
	_speed_now = 0.0
	if _t == 0.0:
		_dropped = false
		if cargo > 0:
			_play("Lossen")
	_t += delta
	_align_to_dock(delta)
	if cargo <= 0:
		if _t > 0.6:
			_set_state(S.WACHT)
		return
	var f := _t / UNLOAD_T
	if f >= UNLOAD_DROP and not _dropped:
		_dropped = true
		sup.deliver(cargo, to_global(Vector3(0, 0, REACH_UNLOAD)))
		cargo = 0
		var dm = depot.node.get_meta("depot_model", null) if depot.has("node") and is_instance_valid(depot.node) else null
		if dm != null:
			dm.play_unload()
	if f >= 1.0:
		_set_state(S.WACHT)


## Bij het lossen schuift de truck zachtjes precies op zijn plek voor het depot (de grijper zet de kist op de laadplaat).
func _align_to_dock(delta: float) -> void:
	var at: Vector2 = sup.dock_point(depot)
	global_position = global_position.move_toward(Vector3(at.x, 0.0, at.y), 1.5 * delta)
	var want := float(depot.yaw) + PI
	rotation.y += clampf(angle_difference(rotation.y, want), -1.2 * delta, 1.2 * delta)


## Alleen een rijdende truck laat een poort opengaan; een truck die wacht of laadt houdt hem niet open.
func wants_gate() -> bool:
	return state == S.HEEN or state == S.TERUG


# ---------------------------------------------------------------- schade

func hit(dmg: float, _dir: Vector3, _from_player: bool) -> void:
	take(dmg * BULLET_TAKE)


func take(dmg: float) -> void:
	if state == S.WRAK:
		return
	hp -= dmg
	if hp <= 0.0:
		_destroy()


func _destroy() -> void:
	if state == S.WRAK:
		return
	if slot >= 0 and (state == S.HEEN or state == S.LADEN):
		sup.claim(slot, -1)
	cargo = 0
	path.clear()
	if _anim != null:
		_anim.stop()
	_model.visible = false
	_wreck.visible = true
	_dust.emitting = false
	_snd.stop()
	collision_layer = 0
	_speed_now = 0.0
	remove_from_group("voorraadtruck")
	_set_state(S.WRAK)
	Fx.explosion(get_parent(), global_position + Vector3(0, 1.0, 0), 0.9)
	Game.banner.emit("VOORRAADTRUCK VERNIELD", "De lading is weg. Koop een nieuwe in het depot.", 2.5)
	sup.truck_lost(self)


## Een ontploffing vlakbij raakt de trucks (Game.note_blast).
static func catch_blast(at: Vector3, radius: float) -> void:
	for t in (Engine.get_main_loop() as SceneTree).get_nodes_in_group("voorraadtruck"):
		var truck := t as VoorraadTruck
		if truck == null or truck.state == S.WRAK:
			continue
		var d := truck.global_position.distance_to(at)
		if d < radius + 2.5:
			truck.take(260.0 * (1.0 - clampf(d / (radius + 2.5), 0.0, 1.0) * 0.7))


func describe() -> String:
	var s: String = NAMES[state]
	if state == S.HEEN or state == S.LADEN:
		s += " (stapel %d)" % (slot + 1)
	elif state == S.TERUG or state == S.LOSSEN:
		s += " · lading %s" % UI.nl(cargo)
	return s
