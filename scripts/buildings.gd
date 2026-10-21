class_name Buildings
extends Node3D
## Gebouwen en bouwstukken die je in de bouwmodus neerzet (BUILD_DEFS in 16d-base.js): de kazerne die
## rekruten opleidt, betonmuren en zandzakken. Verplaatsen, draaien, repareren en verkopen kan ook.
## De rekruten zelf zijn Ally (ally.gd); het bouwscherm staat in build_mode.gd.

const DEFS := {
	"kazerne": {"name": "Kazerne", "cost": 1000, "size": Vector3(4.4, 2.2, 3.2), "max": 1, "hp": 600.0},
	"garage": {"name": "Garage", "cost": 800, "size": Vector3(5.15, 3.1, 5.7), "max": 1, "hp": 900.0},
	"helipad": {"name": "Heliplatform", "cost": 1000, "size": Vector3(12.8, 2.0, 12.8), "max": 1, "hp": 1200.0},
	"zandzak": {"name": "Zandzakken", "cost": 150, "size": Vector3(3.1, 0.95, 0.8), "max": 40, "hp": 380.0, "piece": true},
	"muur": {"name": "Betonmuur", "cost": 300, "size": Vector3(3.0, 1.55, 0.7), "max": 30, "hp": 1100.0, "piece": true},
}
# kaartjes die in de lijst staan maar nog geen model hebben (komen later)
const SOON := ["Ziekenboeg", "Munitiedepot", "Werkplaats", "Radiopost"]
const VEHICLES := {
	"jeep": {"name": "Jeep", "cost": 400, "scene": "res://scenes/jeep.tscn"},
	"tank": {"name": "Tank", "cost": 1200, "scene": "res://scenes/tank.tscn"},
}
const HELI_COST := 500
const PAD_T := 4.5  # seconden dat de luiken en de lift nodig hebben (de clips Open en Dicht)
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
const GS := 0.66      # schaal van het garagemodel (breedte en diepte); in de hoogte GSH
const GSH := 0.92
const DOOR_U := -0.7 * GS  # de garagedeur zit niet in het midden maar iets naar links
const FRONT := 4.2 * GS    # afstand van het midden tot de deur
const C := Data.COMPOUND


func _ready() -> void:
	add_to_group("buildings")
	add_child(GarageMenu.new())


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
	if Data.river_off(at.x, at.z) < Data.RIVER_HALF + 3.0:
		return false  # niet in de rivier
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
	if piece or kind == "helipad":
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
	var body := BuildingBody.new()
	body.collision_layer = Kit.LAYER_WALL
	body.collision_mask = 0
	var sz: Vector3 = DEFS[kind].size
	if kind != "garage" and kind != "helipad":
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = sz
		cs.shape = bs
		cs.position = Vector3(0, sz.y / 2.0, 0)
		body.add_child(cs)
	match kind:
		"garage":
			_garage_node(body)
		"helipad":
			_pad_node(body)
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
		"hp": DEFS[kind].hp, "max_hp": DEFS[kind].hp, "down": false, "cracked": false, "fx": null, "bar": null}
	node.ref = b
	b.bar = HpBar.new()
	add_child(b.bar)
	if kind == "garage":
		b.merge({"has": {"jeep": false, "tank": false}, "order": [], "phase": "idle", "t": 0.0, "veh": null, "spin": 0.0, "sway": 0.0})
		_garage_init(b)
	elif kind == "helipad":
		b.merge({"has_heli": false, "hs": "closed", "t": 0.0, "want": false, "heli": null, "spin": 0.0})
		_pad_init(b)
	Game.buildings.append(b)
	_push_out(b)
	_cut_pad()
	Sfx.play("thud")
	Game.changed.emit()
	return b


func move_to(b: Dictionary, at: Vector3, yaw: float) -> void:
	b.at = at
	b.yaw = yaw
	b.node.position = at
	b.node.rotation.y = yaw
	_push_out(b)
	_cut_pad()
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
	_clear_fx(b)
	if b.bar != null:
		b.bar.queue_free()
	if b.kind == "helipad":
		var player = Game.player
		if b.heli != null and is_instance_valid(b.heli):
			if b.heli.driven and player != null:
				b.heli._leave(player)
			b.heli.queue_free()
	b.node.queue_free()
	Game.buildings.erase(b)
	_cut_pad()
	Game.changed.emit()


# ---------------------------------------------------------------- schade (damageStructure in 16f-buildings.js)

## Schade aan een bouwstuk. Muren en zandzakken vallen uit elkaar, een gebouw wordt een rokend wrak dat je herbouwt.
func damage(b: Dictionary, dmg: float) -> void:
	if b.down or dmg <= 0.0 or (Game.state != "play" and Game.state != "prep") or not Game.buildings.has(b):
		return
	b.hp -= dmg
	var node: Node3D = b.node
	if randf() < 0.5:
		Fx.dust(self, node.global_position + Vector3(randf_range(-1, 1), 0.8, randf_range(-1, 1)))
	if not b.cracked and b.hp > 0.0 and b.hp < b.max_hp * 0.5:
		b.cracked = true
		if is_piece(b.kind):
			node.scale.y = 0.75
		else:
			b.fx = Fx.burning(self, node.global_position, false)
			Game.banner.emit("%s BESCHADIGD" % DEFS[b.kind].name.to_upper(), "", 1.2)
	if b.hp <= 0.0:
		_break(b)
	Game.changed.emit()


func _break(b: Dictionary) -> void:
	var at: Vector3 = b.node.global_position
	if is_piece(b.kind):
		Fx.explosion(self, at + Vector3.UP * 0.4, 0.5)
		remove(b)
		return
	b.down = true
	b.hp = 0.0
	b.queue = 0
	b.node.scale = Vector3(1, 0.32, 1)
	b.node.collision_layer = 0
	_clear_fx(b)
	b.fx = Fx.burning(self, at, true)
	Fx.explosion(self, at + Vector3.UP * 1.0, 1.2)
	Game.banner.emit("%s VERWOEST" % DEFS[b.kind].name.to_upper(), "Herbouw hem in de bouwmodus.", 2.2)


func _clear_fx(b: Dictionary) -> void:
	if b.fx != null and is_instance_valid(b.fx):
		b.fx.queue_free()
	b.fx = null


## Ontploffing (explode() in 15-combat.js): muren en zandzakken de helft, een gebouw van een vijand de volle schade en van jezelf 15%.
func blast(at: Vector3, radius: float, dmg: float, own := false) -> void:
	for b in Game.buildings.duplicate():
		var sz: Vector3 = DEFS[b.kind].size
		var d: float = maxf(0.0, Vector2(b.at.x - at.x, b.at.z - at.z).length() - maxf(sz.x, sz.z) * 0.5)
		if d < radius:
			var mult := 0.5 if is_piece(b.kind) else (0.15 if own else 1.0)
			damage(b, dmg * mult * (1.0 - d / radius))


# ---------------------------------------------------------------- waarde en herstel

func fix_cost(b: Dictionary) -> int:
	if b.down:
		return roundi(DEFS[b.kind].cost / 2.0)
	if b.hp >= b.max_hp:
		return 0
	return roundi(DEFS[b.kind].cost * 0.4) if is_piece(b.kind) else 100


func repair(b: Dictionary) -> void:
	var c := fix_cost(b)
	if c > 0 and Game.pay_build(c):
		b.hp = b.max_hp
		b.cracked = false
		if b.down:
			b.down = false
			b.node.scale = Vector3.ONE
			b.node.collision_layer = Kit.LAYER_WALL
		_clear_fx(b)
		Sfx.play("reload")


## Verkopen geeft de helft van wat erin zit terug als bouwtegoed.
func sell_value(b: Dictionary) -> int:
	var spent: int = DEFS[b.kind].cost
	if b.kind == "kazerne":
		for l in range(2, b.lv + 1):
			spent += LEVELS[l].cost
	return roundi(spent * (0.25 if b.down else 0.5)) + b.queue * TRAIN_COST


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
	if b.down or room(b) <= 0 or not Game.pay_points(TRAIN_COST):
		return
	if b.queue == 0:
		b.train_t = LEVELS[b.lv].time
	b.queue += 1
	Game.changed.emit()


func upgrade(b: Dictionary) -> void:
	if b.down:
		return
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
	if Game.state != "play" and Game.state != "prep":
		return
	for b in Game.buildings:
		var bar: HpBar = b.bar
		if bar == null:
			continue
		var hurt: bool = b.hp < b.max_hp
		bar.set_value(b.hp / b.max_hp, (hurt or Game.build_mode) and not b.down)
		bar.global_position = b.at + Vector3(0, DEFS[b.kind].size.y + 1.0, 0)
	for b in Game.buildings:
		if b.down:
			continue  # een wrak doet niets
		if b.kind == "garage":
			_garage_step(b, delta)
		elif b.kind == "helipad":
			_pad_step(b, delta)
	# tijdens het bouwen staat de opleiding stil (updateStructures in 16d-base.js)
	if Game.build_mode:
		return
	for b in Game.buildings:
		if b.kind == "kazerne" and not b.down and b.queue > 0:
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
		[Vector3(-3.85, 1.6, 0.0), Vector3(0.2, 3.2, 8.6)],      # linkerwand
		[Vector3(2.45, 1.6, 0.0), Vector3(0.2, 3.2, 8.6)],       # rechterwand
		[Vector3(-0.7, 1.6, -4.15), Vector3(6.4, 3.2, 0.2)],     # achterwand
		[Vector3(-3.775, 1.6, 4.15), Vector3(0.25, 3.2, 0.2)],   # pilaar links van de deur
		[Vector3(2.375, 1.6, 4.15), Vector3(0.25, 3.2, 0.2)],    # pilaar rechts van de deur
		[Vector3(-0.7, 2.95, 4.15), Vector3(5.9, 0.5, 0.2)],     # latei
		[Vector3(-0.7, 3.3, 0.0), Vector3(6.6, 0.2, 8.6)],       # dak
	]
	for pt in parts:
		body.add_child(_box_shape(_gs(pt[0]), _gs(pt[1])))
	var door := _box_shape(_gs(Vector3(-0.7, 1.35, 4.1)), _gs(Vector3(5.9, 2.7, 0.3)))
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


## Maten van het model (Blender-meters) omzetten naar het kleinere model in het spel.
func _gs(v: Vector3) -> Vector3:
	return Vector3(v.x * GS, v.y * GSH, v.z * GS)


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
		var p := _pt(b.at, b.yaw, DOOR_U, FRONT + d)
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
	var inside := _pt(b.at, b.yaw, DOOR_U, 0.5)
	v.global_transform = Transform3D(Basis(Vector3.UP, b.yaw + PI), Vector3(inside.x, 0.0, inside.z))
	var run := _free_run(b)
	var goals: Array = []
	# eerst kaarsrecht de poort uit tot de hele wagen buiten staat, dan pas opzij naar de parkeerplek
	if kind == "jeep":
		goals.append(_pt(b.at, b.yaw, DOOR_U, FRONT + minf(6.0, run * 0.7)))
		goals.append(_pt(b.at, b.yaw, DOOR_U - 3.3, FRONT + minf(8.0, run * 0.9)))
	else:
		goals.append(_pt(b.at, b.yaw, DOOR_U, FRONT + minf(7.5, run * 0.8)))
		goals.append(_pt(b.at, b.yaw, DOOR_U + 2.2, FRONT + minf(9.0, run * 0.95)))
	v.goals = goals
	b.veh = v
	Sfx.play("thud", 0.8, v.global_position)


const DOOR_T := 0.7  # seconden dat de poort open of dicht gaat (de clip duurt 2 s en wordt sneller afgespeeld)


func _garage_step(b: Dictionary, delta: float) -> void:
	match b.phase:
		"idle":
			if not b.order.is_empty():
				b.phase = "opening"
				b.t = DOOR_T
				b.anim.speed_scale = 2.0 / DOOR_T
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
			# zodra de wagen buiten is en opzij draait, volgt de volgende of gaat de poort dicht
			var v: Node3D = b.veh
			if not is_instance_valid(v) or v.goals.size() <= 1:
				if not b.order.is_empty():
					_spawn_vehicle(b, b.order.pop_front())
				else:
					b.phase = "closing"
					b.t = DOOR_T
					b.anim.play("Dicht")
		"closing":
			b.t -= delta
			if b.t <= 0.0:
				b.door_shape.disabled = false
				b.light.visible = false
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


# ---------------------------------------------------------------- helikopterplatform

## Platform uit assets/helipad.glb: betonplaat met een schacht van 9 x 9 m, twee luiken en een lift. De schacht
## is een kast (niemand loopt erin); Open en Dicht bewegen luiken, zuigers en lift, de zwaailampen doet de code.
func _pad_node(body: StaticBody3D) -> void:
	var model: Node = (load("res://assets/helipad.glb") as PackedScene).instantiate()
	model.position.y = 0.03  # net boven de grond, anders knippert de plaat
	body.add_child(model)
	body.set_meta("model", model)
	body.add_child(_box_shape(Vector3(0, 1.0, 0), Vector3(9.0, 2.0, 9.0)))
	var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	for clip in ["Open", "Dicht"]:
		var a := ap.get_animation(clip)
		for i in range(a.get_track_count() - 1, -1, -1):
			if String(a.track_get_path(i)).contains("Zwaai"):
				a.remove_track(i)
	var night := GameSettings.get_value("time") != "day"
	for n in ["SchachtLicht0", "SchachtLicht1", "MastSchijnwerper"]:
		var l := model.find_child(n, true, false)
		if l:
			l.visible = night
	for n in ["ZwaaiALicht", "ZwaaiBLicht"]:
		var l := model.find_child(n, true, false)
		if l:
			l.visible = false


func _pad_init(b: Dictionary) -> void:
	var model: Node = b.node.get_meta("model")
	b.anim = model.find_child("AnimationPlayer", true, false)
	b.lift = model.find_child("Lift", true, false)
	b.zwa = model.find_child("ZwaaiA", true, false)
	b.zwb = model.find_child("ZwaaiB", true, false)
	b.lamps = [model.find_child("ZwaaiALicht", true, false), model.find_child("ZwaaiBLicht", true, false)]


## De schacht is echt uitgegraven: de grondschil krijgt een gat van 9 x 9 m op de plek van het platform.
func _cut_pad() -> void:
	var g := get_tree().get_first_node_in_group("ground")
	if g == null or not g.has_meta("mat"):
		return
	var mat: ShaderMaterial = g.get_meta("mat")
	mat.set_shader_parameter("pad_half", 0.0)
	for b in Game.buildings:
		if b.kind == "helipad":
			mat.set_shader_parameter("pad", Vector4(b.at.x, b.at.z, cos(b.yaw), sin(b.yaw)))
			mat.set_shader_parameter("pad_half", 4.5)


func can_buy_heli(b: Dictionary) -> bool:
	return b.kind == "helipad" and not b.has_heli and Game.points >= HELI_COST


## Koop de Apache: de luiken gaan open en de lift tilt hem omhoog.
func buy_heli(b: Dictionary) -> void:
	if not can_buy_heli(b) or not Game.pay_points(HELI_COST):
		return
	b.has_heli = true
	var h := Apache.new()
	h.setup(b)
	add_child(h)
	b.heli = h
	b.want = true
	Sfx.play("buy")
	Game.changed.emit()


## Zet de helikopter weer klaar als hij beneden staat.
func call_heli(b: Dictionary) -> void:
	if b.kind == "helipad" and b.has_heli and b.hs != "open":
		b.want = true
		Sfx.play("click")
		Game.changed.emit()


func _pad_play(b: Dictionary, clip: String, state: String) -> void:
	b.hs = state
	b.t = PAD_T
	b.anim.speed_scale = 1.0
	b.anim.play(clip)
	Sfx.play("gate", 0.9, b.node.global_position)


func _pad_step(b: Dictionary, delta: float) -> void:
	var heli = b.heli
	var player = Game.player
	match b.hs:
		"closed":
			if b.want and b.has_heli:
				b.want = false
				_pad_play(b, "Open", "opening")
		"opening":
			b.t -= delta
			if b.t <= 0.0:
				b.hs = "open"
		"open":
			if heli != null and is_instance_valid(heli):
				var d: float = Vector2(b.at.x - player.global_position.x, b.at.z - player.global_position.z).length() if player else 0.0
				var away: bool = heli.mode == Apache.Mode.LIFT and not heli.driven and d > 14.0
				var gone: bool = (heli.mode == Apache.Mode.FLY or heli.mode == Apache.Mode.GROUND) and Vector2(heli.global_position.x - b.at.x, heli.global_position.z - b.at.z).length() > 16.0
				if (away or gone) and not b.want:
					_pad_play(b, "Dicht", "closing")
		"closing":
			b.t -= delta
			if b.t <= 0.0:
				b.hs = "closed"
	var moving: bool = b.hs == "opening" or b.hs == "closing"
	if moving:
		b.spin += delta * 5.0
		b.zwa.rotation.y = b.spin
		b.zwb.rotation.y = -b.spin + 1.0
	for l in b.lamps:
		if l:
			l.visible = moving
