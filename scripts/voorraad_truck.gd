class_name VoorraadTruck
extends StaticBody3D
## Een voorraadtruck (Generals-plan stap 4, A1): rijdt vanuit het depot over een vaste route met wegpunten naar een stapel, laadt daar met
## zijn kraan en grijper, rijdt terug en levert af. Hij kan kapot: dan blijft een wrak liggen en de lading is weg.
## 4a: eenvoudige blokken en een eenvoudige kraan; het echte model met kraan, grijper en geanimeerd laden komt in 4b.

enum S { WACHT, HEEN, LADEN, TERUG, LOSSEN, WRAK }
const SPEED := 6.0        # m/s
const TURN := 2.4         # rad/s
const LOAD_T := 3.0       # s laden
const UNLOAD_T := 2.2     # s lossen
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
var _arm: Node3D
var _grab: Node3D
var _load: Node3D          # de lading in de bak
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
	var olive := Kit.flat(Color("55603a"), 0.8, 0.1)
	var dark := Kit.flat(Color("2b2f22"), 0.9)
	var steel := Kit.flat(Color("6b6f68"), 0.6, 0.5)
	var gold := Kit.flat(Color("c9a227"), 0.7)
	var glass := Kit.flat(Color("1b2420"), 0.2, 0.3)
	Kit.box(_model, Vector3(0, 0.75, -0.2), Vector3(2.3, 0.45, 5.8), dark)          # chassis
	Kit.box(_model, Vector3(0, 1.75, 2.0), Vector3(2.3, 1.5, 1.9), olive)            # cabine
	Kit.box(_model, Vector3(0, 2.0, 2.97), Vector3(2.0, 0.7, 0.05), glass)           # voorruit
	Kit.box(_model, Vector3(0, 1.45, -1.2), Vector3(2.4, 0.3, 3.9), olive)          # laadbak
	for sx in [-1.1, 1.1]:
		Kit.box(_model, Vector3(sx, 1.95, -1.2), Vector3(0.08, 0.7, 3.9), olive)     # zijborden
	Kit.box(_model, Vector3(0, 1.95, -3.15), Vector3(2.3, 0.7, 0.08), olive)         # achterbord
	for z in [-2.4, -0.4, 2.0]:
		for sx in [-1.2, 1.2]:
			Kit.box(_model, Vector3(sx, 0.45, z), Vector3(0.35, 0.9, 0.9), dark)     # wielen
	Kit.box(_model, Vector3(0, 0.95, 3.05), Vector3(2.3, 0.2, 0.15), gold)           # gele bumper
	# de kraan staat achter de cabine, de grijper hangt aan de arm
	Kit.box(_model, Vector3(0, 2.0, 0.55), Vector3(0.5, 1.0, 0.5), steel)
	_arm = Node3D.new()
	_arm.name = "Arm"
	_arm.position = Vector3(0, 2.6, 0.55)
	_model.add_child(_arm)
	Kit.box(_arm, Vector3(0, 0, 1.6), Vector3(0.28, 0.28, 3.4), steel)
	_grab = Node3D.new()
	_grab.name = "Grijper"
	_grab.position = Vector3(0, -0.3, 3.2)
	_arm.add_child(_grab)
	Kit.box(_grab, Vector3(0, -0.4, 0), Vector3(0.9, 0.12, 0.9), steel)
	Kit.box(_grab, Vector3(-0.42, -0.65, 0), Vector3(0.08, 0.5, 0.9), steel)
	Kit.box(_grab, Vector3(0.42, -0.65, 0), Vector3(0.08, 0.5, 0.9), steel)
	# de lading: twee kisten in de bak
	_load = Node3D.new()
	_load.name = "Lading"
	_model.add_child(_load)
	Kit.box(_load, Vector3(-0.5, 2.05, -1.9), Vector3(1.1, 0.7, 1.3), Kit.flat(Color("6e5a3c"), 0.9))
	Kit.box(_load, Vector3(0.55, 2.05, -1.5), Vector3(1.1, 0.7, 1.3), olive)
	Kit.box(_load, Vector3(0.0, 2.75, -1.7), Vector3(1.1, 0.7, 1.3), Kit.flat(Color("3a4128"), 0.9))
	_load.visible = false
	_crane(0.0)


func _build_wreck() -> void:
	_wreck = Node3D.new()
	_wreck.name = "Wrak"
	add_child(_wreck)
	var burnt := Kit.flat(Color("1c1b18"), 0.95)
	var rust := Kit.flat(Color("4a3322"), 0.95)
	Kit.box(_wreck, Vector3(0, 0.6, 0), Vector3(2.3, 0.7, 5.6), burnt, 0.05)
	Kit.box(_wreck, Vector3(0.2, 1.3, 2.0), Vector3(2.1, 1.1, 1.8), rust, -0.12)
	Kit.box(_wreck, Vector3(-0.3, 1.1, -1.4), Vector3(2.0, 0.5, 3.0), burnt, 0.1)
	_wreck.visible = false


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


## Kraan: f = 0 in rust (arm omhoog), 1 = grijper bij de kist. Een eenvoudige stand zonder echte clip.
func _crane(f: float) -> void:
	_arm.rotation.x = lerpf(-0.35, 0.55, f)
	_grab.position.y = lerpf(-0.3, -1.1, f)


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
	if _t == 0.0 and not sup.has_stock(slot, site_id):
		_go_home(0)   # de stapel is intussen leeg: met lege handen terug, daar kiest hij een andere
		return
	_t += delta
	var f := _t / LOAD_T
	_crane(sin(clampf(f, 0.0, 1.0) * PI))
	if f >= 0.5 and cargo == 0:
		cargo = sup.take(slot, site_id, sup.trip_value(depot, slot))
		_load.visible = cargo > 0
	if f >= 1.0:
		_crane(0.0)
		_go_home(cargo)


func _go_home(amount: int) -> void:
	sup.claim(slot, -1)
	cargo = amount
	_load.visible = cargo > 0
	path = _back.duplicate()
	_set_state(S.TERUG)


func _unload_step(delta: float) -> void:
	_speed_now = 0.0
	_t += delta
	var f := _t / UNLOAD_T
	if cargo > 0:
		_crane(sin(clampf(f, 0.0, 1.0) * PI))
	if f >= 0.5 and _load.visible:
		_load.visible = false
		sup.deliver(cargo, global_position)
		cargo = 0
	if f >= 1.0:
		_crane(0.0)
		_set_state(S.WACHT)


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
