class_name Buildings
extends Node3D
## Gebouwen en bouwstukken die je in de bouwmodus neerzet (BUILD_DEFS in 16d-base.js): de kazerne die
## rekruten opleidt, betonmuren en zandzakken. Verplaatsen, draaien, repareren en verkopen kan ook.
## De rekruten zelf zijn Ally (ally.gd); het bouwscherm staat in build_mode.gd.

const DEFS := {
	"kazerne": {"name": "Kazerne", "cost": 1000, "size": Vector3(4.4, 2.2, 3.2), "max": 1, "hp": 600.0},
	"garage": {"name": "Garage", "cost": 800, "size": Vector3(7.8, 3.4, 8.6), "max": 1, "hp": 900.0},
	"zandzak": {"name": "Zandzakken", "cost": 150, "size": Vector3(3.1, 0.95, 0.8), "max": 40, "hp": 380.0, "piece": true},
	"muur": {"name": "Betonmuur", "cost": 300, "size": Vector3(3.0, 1.55, 0.7), "max": 30, "hp": 1100.0, "piece": true},
}
# kaartjes die in de lijst staan maar nog geen model hebben (komen later)
const SOON := ["Ziekenboeg", "Munitiedepot", "Werkplaats", "Radiopost"]
const VEHICLES := {
	"jeep": {"name": "Jeep", "cost": 400, "scene": "res://scenes/jeep.tscn"},
	"tank": {"name": "Tank", "cost": 1200, "scene": "res://scenes/tank.tscn"},
}
const INFO := {
	"zandzak": "Lage dekking: kogels stoppen erop, jij schiet eroverheen.",
	"muur": "Hoge betonblokken: niemand schiet of loopt erdoorheen.",
}
# per niveau: soldaten tegelijk, seconden per rekruut, gezondheid, schade en wat het niveau kost
const LEVELS := [null,
	{"max": 2, "time": 10.0, "hp": 100.0, "dmg": 16.0},
	{"max": 4, "time": 7.0, "hp": 115.0, "dmg": 18.0, "cost": 1200},
	{"max": 6, "time": 5.0, "hp": 130.0, "dmg": 21.0, "cost": 1800}]
const TRAIN_COST := 250
const DOOR := 2.5  # afstand van het midden tot het punt voor de deur
const DOOR_U := -0.7  # de garagedeur zit niet in het midden maar 0,7 m naar links
const C := Data.COMPOUND


func _ready() -> void:
	add_to_group("buildings")


func count(kind: String) -> int:
	var n := 0
	for b in Game.buildings:
		if b.kind == kind:
			n += 1
	return n


func is_piece(kind: String) -> bool:
	return DEFS[kind].get("piece", false)


func full(kind: String) -> bool:
	return count(kind) >= DEFS[kind].max


# ---------------------------------------------------------------- neerzetten

## Wereldpunt van een plek (u, v) in het bouwstuk dat op `at` staat met draaiing `yaw`.
static func _pt(at: Vector3, yaw: float, u: float, v: float) -> Vector3:
	return at + Vector3(cos(yaw), 0, -sin(yaw)) * u + Vector3(sin(yaw), 0, cos(yaw)) * v


func _tower_feet() -> Array:
	var out: Array = []
	for t: Node3D in get_tree().get_nodes_in_group("tower"):
		out.append([t.to_global(Vector3(1.8, 0, 0)), t.global_position])
	return out


## Kan dit hier staan? Gebouwen binnen de muur, stukken overal behalve op de muur en in de poorten.
func can_place(kind: String, at: Vector3, yaw: float, me: Variant = null) -> bool:
	var d: Dictionary = DEFS[kind]
	var sz: Vector3 = d.size
	var piece := is_piece(kind)
	if Vector2(at.x, at.z).length() > Data.WORLD_R - 3.0:
		return false
	var feet := _tower_feet()
	for iu in 3:
		for iv in 3:
			var p := _pt(at, yaw, (iu - 1) * sz.x * 0.5, (iv - 1) * sz.z * 0.5)
			if piece:
				if absf(maxf(absf(p.x), absf(p.z)) - C) < 0.7:
					return false
				if absf(p.x) < Data.GATE_GAP + 1.0 and absf(absf(p.z) - C) < 3.4:
					return false
				for f in feet:
					if p.distance_to(f[0]) < 1.2 or p.distance_to(f[1]) < 1.7:
						return false
			else:
				if maxf(absf(p.x), absf(p.z)) > C - 0.5:
					return false
				if Vector2(p.x, p.z).distance_to(Vector2(0, signf(p.z) * C)) < 4.0:
					return false
				for f in feet:
					if p.distance_to(f[0]) < 1.4 or p.distance_to(f[1]) < 1.9:
						return false
	var ex: Array[RID] = []
	if me != null:
		ex.append(me.node.get_rid())
	if _hits(Vector3(sz.x - 0.2, 1.0, sz.z - 0.2) if piece else Vector3(sz.x + 0.4, 1.0, sz.z + 0.4), at, yaw, ex):
		return false
	if piece:
		return true
	# de deur moet op vrij terrein uitkomen
	var door := _pt(at, yaw, 0.0, sz.z / 2.0 + 0.9)
	if maxf(absf(door.x), absf(door.z)) > C - 0.6:
		return false
	var q2 := PhysicsShapeQueryParameters3D.new()
	var s2 := SphereShape3D.new()
	s2.radius = 0.5
	q2.shape = s2
	q2.collision_mask = Kit.LAYER_WALL | Kit.LAYER_BUNKER
	q2.exclude = ex
	q2.transform = Transform3D(Basis.IDENTITY, door + Vector3(0, 0.8, 0))
	return get_world_3d().direct_space_state.intersect_shape(q2, 1).is_empty()


func _hits(size: Vector3, at: Vector3, yaw: float, ex: Array[RID]) -> bool:
	var shape := BoxShape3D.new()
	shape.size = size
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = Kit.LAYER_WALL | Kit.LAYER_BUNKER
	q.exclude = ex
	q.transform = Transform3D(Basis(Vector3.UP, yaw), at + Vector3(0, 0.8, 0))
	return not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## Het gebouw zelf: een StaticBody die kogels en mensen tegenhoudt, met het model eronder.
func make_node(kind: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Kit.LAYER_WALL
	body.collision_mask = 0
	var sz: Vector3 = DEFS[kind].size
	if kind != "garage":
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = sz
		cs.shape = bs
		cs.position = Vector3(0, sz.y / 2.0, 0)
		body.add_child(cs)
	match kind:
		"garage":
			_garage_node(body)
		"kazerne":
			var model: Node = (load("res://assets/kazerne.glb") as PackedScene).instantiate()
			Kit.skin(model, "kazerne")
			body.add_child(model)
		"muur":
			Kit.box(body, Vector3.ZERO, Vector3(sz.x, sz.y, sz.z), Kit.concrete())
			Kit.box(body, Vector3(0, sz.y, 0), Vector3(sz.x + 0.1, 0.14, sz.z + 0.14), Kit.concrete_dark())
			Kit.box(body, Vector3.ZERO, Vector3(sz.x + 0.06, 0.28, sz.z + 0.2), Kit.concrete_dark())
		"zandzak":
			_bags(body, sz)
	return body


func _bags(root: Node3D, sz: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(root.position.x * 13.0 + root.position.z * 7.0) + 11
	var mat: StandardMaterial3D = Kit.canvas()
	var bag := SphereMesh.new()
	bag.radius = 0.5
	bag.height = 1.0
	bag.radial_segments = 8
	bag.rings = 4
	for layer in 3:
		for i in 4 - (layer % 2):
			var mi := MeshInstance3D.new()
			mi.mesh = bag
			mi.material_override = mat
			mi.position = Vector3(-1.2 + i * 0.82 + (layer % 2) * 0.41, 0.17 + layer * 0.27, rng.randf_range(-0.04, 0.04))
			mi.scale = Vector3(0.88, 0.34, 0.52)
			mi.rotation.y = rng.randf_range(-0.1, 0.1)
			root.add_child(mi)


func place(kind: String, at: Vector3, yaw: float) -> Variant:
	if full(kind) or not can_place(kind, at, yaw) or not Game.pay_build(DEFS[kind].cost):
		return null
	var node := make_node(kind)
	node.position = at
	node.rotation.y = yaw
	add_child(node)
	var b := {"kind": kind, "node": node, "at": at, "yaw": yaw, "lv": 1, "queue": 0, "train_t": 0.0,
		"hp": DEFS[kind].hp, "max_hp": DEFS[kind].hp}
	if kind == "garage":
		b.merge({"has": {"jeep": false, "tank": false}, "order": [], "phase": "idle", "t": 0.0, "veh": null, "spin": 0.0, "sway": 0.0})
		_garage_init(b)
	Game.buildings.append(b)
	_push_out(b)
	Sfx.play("thud")
	Game.changed.emit()
	return b


func move_to(b: Dictionary, at: Vector3, yaw: float) -> void:
	b.at = at
	b.yaw = yaw
	b.node.position = at
	b.node.rotation.y = yaw
	_push_out(b)
	Sfx.play("thud", 0.6)


## Wie in het nieuwe bouwstuk staat, wordt er netjes naast gezet.
func _push_out(b: Dictionary) -> void:
	var sz: Vector3 = DEFS[b.kind].size
	var who: Array = [Game.player]
	who.append_array(Game.allies)
	for w in who:
		if w == null or not is_instance_valid(w):
			continue
		var rel: Vector3 = w.global_position - b.at
		var u := rel.dot(Vector3(cos(b.yaw), 0, -sin(b.yaw)))
		var v := rel.dot(Vector3(sin(b.yaw), 0, cos(b.yaw)))
		var hu := sz.x / 2.0 + 0.7
		var hv := sz.z / 2.0 + 0.7
		if absf(u) < hu and absf(v) < hv:
			if hu - absf(u) < hv - absf(v):
				u = signf(u if u != 0.0 else 1.0) * hu
			else:
				v = signf(v if v != 0.0 else 1.0) * hv
			var p := _pt(b.at, b.yaw, u, v)
			w.global_position = Vector3(p.x, w.global_position.y, p.z)


func remove(b: Dictionary) -> void:
	b.node.queue_free()
	Game.buildings.erase(b)
	Game.changed.emit()


# ---------------------------------------------------------------- waarde en herstel

func fix_cost(b: Dictionary) -> int:
	if b.hp >= b.max_hp:
		return 0
	return roundi(DEFS[b.kind].cost * 0.4) if is_piece(b.kind) else 100


func repair(b: Dictionary) -> void:
	var c := fix_cost(b)
	if c > 0 and Game.pay_build(c):
		b.hp = b.max_hp
		Sfx.play("reload")


## Verkopen geeft de helft van wat erin zit terug als bouwtegoed.
func sell_value(b: Dictionary) -> int:
	var spent: int = DEFS[b.kind].cost
	if b.kind == "kazerne":
		for l in range(2, b.lv + 1):
			spent += LEVELS[l].cost
	return roundi(spent * 0.5) + b.queue * TRAIN_COST


func sell(b: Dictionary) -> void:
	Game.build_credit += sell_value(b)
	remove(b)
	Sfx.play("buy")


func turn(b: Dictionary) -> bool:
	var ny: float = fposmod(b.yaw + PI / 2.0, TAU)
	if not can_place(b.kind, b.at, ny, b):
		return false
	move_to(b, b.at, ny)
	return true


# ---------------------------------------------------------------- kazerne

func door_of(b: Dictionary) -> Vector3:
	return b.at + Vector3(sin(b.yaw), 0, cos(b.yaw)) * DOOR


func soldiers_alive() -> int:
	var n := 0
	for a in Game.allies:
		if is_instance_valid(a):
			n += 1
	return n


func queued() -> int:
	var n := 0
	for b in Game.buildings:
		n += b.queue
	return n


func room(b: Dictionary) -> int:
	return LEVELS[b.lv].max - soldiers_alive() - queued()


func recruit(b: Dictionary) -> void:
	if room(b) <= 0 or not Game.pay_points(TRAIN_COST):
		return
	if b.queue == 0:
		b.train_t = LEVELS[b.lv].time
	b.queue += 1
	Game.changed.emit()


func upgrade(b: Dictionary) -> void:
	var nx: Variant = LEVELS[b.lv + 1] if b.lv + 1 < LEVELS.size() else null
	if nx == null or not Game.pay_build(nx.cost):
		return
	b.lv += 1
	for a in Game.allies:
		if is_instance_valid(a):
			a.set_level(nx.hp, nx.dmg)
	Sfx.play("reload")
	Game.changed.emit()


func _spawn(b: Dictionary) -> void:
	var lv: Dictionary = LEVELS[b.lv]
	var a := Ally.new()
	add_child(a)
	a.global_position = door_of(b)
	a.face = b.yaw
	a.setup(lv.hp, lv.dmg, Game.allies.size())
	Game.allies.append(a)
	Sfx.play("reload")
	Game.banner.emit("NIEUWE REKRUUT", "", 1.0)
	Game.changed.emit()


func _physics_process(delta: float) -> void:
	# tijdens het bouwen staat de opleiding stil (updateStructures in 16d-base.js)
	if (Game.state != "play" and Game.state != "prep") or Game.build_mode:
		return
	for b in Game.buildings:
		if b.kind == "garage":
			_garage_step(b, delta)
		if b.kind == "kazerne" and b.queue > 0:
			b.train_t -= delta
			if b.train_t <= 0.0:
				b.queue -= 1
				_spawn(b)
				b.train_t = LEVELS[b.lv].time


# ---------------------------------------------------------------- garage

## Gebouw van assets/garage.glb. Muren zijn losse kasten, zodat de ingang open blijft; de poort is een kast die uitgaat als hij open is.
func _garage_node(body: StaticBody3D) -> void:
	var model: Node = (load("res://assets/garage.glb") as PackedScene).instantiate()
	body.add_child(model)
	body.set_meta("model", model)
	var parts := [
		[Vector3(-3.85, 1.6, 0.0), Vector3(0.2, 3.2, 8.6)],    # linkerwand
		[Vector3(2.45, 1.6, 0.0), Vector3(0.2, 3.2, 8.6)],     # rechterwand
		[Vector3(-0.7, 1.6, -4.15), Vector3(6.4, 3.2, 0.2)],   # achterwand
		[Vector3(-3.45, 1.6, 4.15), Vector3(0.9, 3.2, 0.2)],   # pilaar links van de deur
		[Vector3(2.05, 1.6, 4.15), Vector3(0.9, 3.2, 0.2)],    # pilaar rechts van de deur
		[Vector3(-0.7, 2.95, 4.15), Vector3(4.6, 0.5, 0.2)],   # latei
		[Vector3(-0.7, 3.3, 0.0), Vector3(6.6, 0.2, 8.6)],     # dak
	]
	for pt in parts:
		body.add_child(_box_shape(pt[0], pt[1]))
	var door := _box_shape(Vector3(-0.7, 1.35, 4.1), Vector3(4.6, 2.7, 0.3))
	door.name = "Poortkast"
	body.add_child(door)
	var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	# Open en Dicht bewegen alleen de poort; de rest (zwaailicht, takel) doet de code
	for clip in ["Open", "Dicht"]:
		var a := ap.get_animation(clip)
		for i in range(a.get_track_count() - 1, -1, -1):
			if not String(a.track_get_path(i)).get_slice(":", 0).ends_with("Deur"):
				a.remove_track(i)
	var night := GameSettings.get_value("time") != "day"
	for n in ["DeurLampL", "DeurLampR", "BinnenLamp"]:
		var l := model.find_child(n, true, false)
		if l:
			l.visible = night
	var z := model.find_child("ZwaaiLicht", true, false)
	if z:
		z.visible = false


func _box_shape(pos: Vector3, size: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	return cs


func _garage_init(b: Dictionary) -> void:
	var model: Node = b.node.get_meta("model")
	b.anim = model.find_child("AnimationPlayer", true, false)
	b.zwaai = model.find_child("Zwaai", true, false)
	b.light = model.find_child("ZwaaiLicht", true, false)
	b.arm = model.find_child("Arm", true, false)
	b.haak = model.find_child("Haak", true, false)
	b.door_shape = b.node.get_node("Poortkast")


func vehicle_cost(kind: String) -> int:
	return VEHICLES[kind].cost


func can_buy_vehicle(b: Dictionary, kind: String) -> bool:
	return b.kind == "garage" and not b.has[kind] and Game.points >= VEHICLES[kind].cost


## Koop een jeep of tank; hij rijdt uit zodra je het bouwscherm verlaat.
func buy_vehicle(b: Dictionary, kind: String) -> void:
	if not can_buy_vehicle(b, kind) or not Game.pay_points(VEHICLES[kind].cost):
		return
	b.has[kind] = true
	b.order.append(kind)
	Sfx.play("buy")
	Game.changed.emit()


func _front(b: Dictionary) -> Vector3:
	return Vector3(sin(b.yaw), 0, cos(b.yaw))


## Hoeveel vrije meters er vóór de deur zijn (binnen de muur, zonder bunker of gebouwen).
func _free_run(b: Dictionary) -> float:
	var shape := SphereShape3D.new()
	shape.radius = 1.0
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = Kit.LAYER_WALL | Kit.LAYER_BUNKER
	var ex: Array[RID] = [b.node.get_rid()]
	q.exclude = ex
	var run := 0.0
	for i in range(1, 25):
		var d := i * 0.5
		var p := _pt(b.at, b.yaw, DOOR_U, 4.2 + d)
		if maxf(absf(p.x), absf(p.z)) > C - 1.2:
			break
		q.transform = Transform3D(Basis.IDENTITY, p + Vector3(0, 1.0, 0))
		if not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty():
			break
		run = d
	return run


func _spawn_vehicle(b: Dictionary, kind: String) -> void:
	var v: Node3D = (load(VEHICLES[kind].scene) as PackedScene).instantiate()
	add_child(v)
	var inside := _pt(b.at, b.yaw, DOOR_U, 0.8)
	v.global_position = Vector3(inside.x, 0.0, inside.z)
	v.rotation.y = b.yaw + PI
	var run := _free_run(b)
	var goals: Array = []
	if kind == "jeep":
		goals.append(_pt(b.at, b.yaw, DOOR_U, 4.2 + minf(3.0, run * 0.5)))
		goals.append(_pt(b.at, b.yaw, DOOR_U - 3.3, 4.2 + maxf(2.5, run * 0.75)))
	else:
		goals.append(_pt(b.at, b.yaw, DOOR_U, 4.2 + minf(4.0, run * 0.5)))
		goals.append(_pt(b.at, b.yaw, DOOR_U + 2.2, 4.2 + maxf(3.5, run * 0.85)))
	v.goals = goals
	b.veh = v
	Sfx.play("thud", 0.8, v.global_position)


func _garage_step(b: Dictionary, delta: float) -> void:
	match b.phase:
		"idle":
			if not b.order.is_empty():
				b.phase = "opening"
				b.t = 2.0
				b.anim.play("Open")
				b.light.visible = true
				Sfx.play("thud", 0.5, b.node.global_position)
		"opening":
			b.t -= delta
			if b.t <= 0.0:
				b.door_shape.disabled = true
				_spawn_vehicle(b, b.order.pop_front())
				b.phase = "rolling"
		"rolling":
			var v: Node3D = b.veh
			# de poort gaat dicht zodra de wagen er helemaal uit is
			var out: Vector3 = v.global_position - b.at
			if not is_instance_valid(v) or out.dot(_front(b)) > 4.2 + 2.6 or v.goals.is_empty():
				b.phase = "closing"
				b.t = 2.0
				b.anim.play("Dicht")
		"closing":
			b.t -= delta
			if b.t <= 0.0:
				b.door_shape.disabled = false
				b.light.visible = false
				b.phase = "wait"
				b.t = 1.5
		"wait":
			# de volgende wagen pas als de vorige is aangekomen
			b.t -= delta
			if b.t <= 0.0 and (b.veh == null or not is_instance_valid(b.veh) or b.veh.goals.is_empty()):
				b.phase = "idle"
	# zwaailicht draait zolang de poort in beweging is; de takel wiegt altijd een beetje
	var moving: bool = b.phase == "opening" or b.phase == "closing" or b.phase == "rolling"
	if moving:
		b.spin += delta * 6.0
		b.zwaai.rotation.y = b.spin
	b.sway += delta
	b.arm.rotation.y = deg_to_rad(14.0) * sin(b.sway * TAU / 8.0)
	b.haak.rotation.x = deg_to_rad(4.0) * sin(b.sway * TAU / 2.0 + 1.0)
	b.haak.rotation.z = deg_to_rad(3.0) * sin(b.sway * TAU / 3.0)
