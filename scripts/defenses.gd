class_name Defenses
extends Node3D
## Verdediging van de web-versie (16-defenses.js en 16c-towers.js): zandzakken, loopgraaf, landmijn,
## prikkeldraad en MG-nest die je zelf neerzet, plus een MG en een wacht op elke wachttoren.

const KINDS := ["bags", "trench", "mine", "wire", "sentry"]
const NAMES := {"bags": "Zandzakken", "trench": "Loopgraaf", "mine": "Landmijn", "wire": "Prikkeldraad", "sentry": "MG-nest"}
const COSTS := {"bags": 180, "trench": 300, "mine": 150, "wire": 220, "sentry": 900}
const SENTRY_MAX := 6
const TOWER_MG_COST := 1000
const TOWER_MG_AMMO := 260
const GUARD_COST := 600
const GUARD_HP := 220.0
const TOWER_TOP := 5.36  # hoogte van het platform van een wachttoren

var items: Array = []  # neergezette dingen: {kind, node, ...}
var towers: Array = []  # {node, pos, mg, ammo, fire_t, aim, gun, guard}


func _ready() -> void:
	add_to_group("defenses")
	for n in get_tree().get_nodes_in_group("tower"):
		towers.append({"node": n, "pos": n.global_position, "mg": false, "ammo": 0, "fire_t": 0.0, "aim": 0.0, "gun": null, "guard": null, "guard_hp": 0.0, "guard_t": 0.0})


# ---------------------------------------------------------------- aantallen (voor de winkel)

func sentry_total() -> int:
	return items.filter(func(d): return d.kind == "sentry").size() + Game.inv.sentry


func towers_with_mg() -> int:
	return towers.filter(func(t): return t.mg).size()


func towers_with_guard() -> int:
	return towers.filter(func(t): return t.guard != null).size()


func sentry_ammo() -> int:
	return 160 + Game.upg.sentry * 70


func tower_ammo() -> int:
	return TOWER_MG_AMMO + Game.upg.sentry * 70


# ---------------------------------------------------------------- kopen op torens

func buy_tower_mg() -> void:
	for t in towers:
		if not t.mg:
			t.mg = true
			t.ammo = tower_ammo()
			var gun := Node3D.new()
			_sentry_gun(gun)
			gun.position = t.pos + Vector3(0, TOWER_TOP + 0.1, 0)
			add_child(gun)
			t.gun = gun
			return


func buy_guard() -> void:
	for t in towers:
		if t.guard == null:
			var m := SoldierModel.new()
			add_child(m)
			m.setup(Color("5a6a36"))
			m.scale = Vector3.ONE * Data.SOLDIER_SCALE
			m.position = t.pos + Vector3(0, TOWER_TOP, 0)
			t.guard = m
			t.guard_hp = GUARD_HP
			t.guard_t = randf_range(0.3, 1.0)
			return


## Begin van een golf: alle MG's weer vol en de wachten genezen.
func refill() -> void:
	for t in towers:
		if t.mg:
			t.ammo = tower_ammo()
		if t.guard:
			t.guard_hp = GUARD_HP
	for d in items:
		if d.kind == "sentry":
			d.ammo = sentry_ammo()


# ---------------------------------------------------------------- neerzetten

func cycle() -> void:
	var i := KINDS.find(Game.place_sel)
	for n in KINDS.size():
		i = (i + 1) % KINDS.size()
		if Game.inv[KINDS[i]] > 0:
			Game.place_sel = KINDS[i]
			break
	Game.changed.emit()


func place() -> void:
	if Game.state != "play" and Game.state != "prep":
		return
	var k: String = Game.place_sel
	if Game.inv[k] <= 0 or Game.player == null:
		return
	var p: Node3D = Game.player
	var a: float = p.face
	var fwd := Vector3(sin(a), 0, cos(a))
	var at: Vector3 = p.global_position + fwd * (2.3 if k == "trench" else 1.7)
	at.y = 0.0
	if Vector2(at.x, at.z).length() > Data.WORLD_R:
		return
	var d := {"kind": k, "pos": at, "a": a}
	var node := Node3D.new()
	node.position = at
	node.rotation.y = a
	add_child(node)
	d.node = node
	match k:
		"bags":
			_bag_wall(node)
		"trench":
			_trench(node)
			node.rotation.y = a + PI
		"mine":
			_mine(node)
			d.arm = 0.8
		"wire":
			_wire(node)
		"sentry":
			var base := Node3D.new()
			node.add_child(base)
			_sentry_base(base)
			var gun := Node3D.new()
			gun.position.y = 0.95
			_sentry_gun(gun)
			node.add_child(gun)
			d.gun = gun
			d.ammo = sentry_ammo()
			d.fire_t = 0.0
			d.aim = a
			gun.rotation.y = a
	items.append(d)
	Sfx.play("thud" if k == "trench" or k == "sentry" else "click")
	Game.inv[k] -= 1
	if Game.inv[k] <= 0:
		cycle()
	Game.changed.emit()


# ---------------------------------------------------------------- vormen

func _bag_wall(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(root.position.x * 13.0 + root.position.z * 7.0)
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
	Kit.collider(root, Vector3(0, 0.4, 0), Vector3(3.0, 0.8, 0.6), Kit.LAYER_WALL)


func _trench(root: Node3D) -> void:
	var dirt := Kit.flat(Color("2c2014"), 1.0)
	Kit.box(root, Vector3(0, 0.0, 0), Vector3(4.8, 0.04, 1.4), dirt)
	var berm := Kit.flat(Color("5b4630"), 1.0)
	for s in [-1.0, 1.0]:
		Kit.box(root, Vector3(0, 0.0, s * 0.8), Vector3(4.9, 0.28, 0.3), berm)
	for s in [-1.0, 1.0]:
		Kit.box(root, Vector3(s * 2.45, 0.0, 0), Vector3(0.3, 0.28, 1.4), berm)


func _mine(root: Node3D) -> void:
	Kit.cylinder(root, Vector3.ZERO, 0.34, 0.12, Kit.flat(Color("3f4524"), 0.8), 14)
	Kit.cylinder(root, Vector3(0, 0.12, 0), 0.06, 0.08, Kit.flat(Color("777777"), 0.4, 0.6), 6)


func _wire(root: Node3D) -> void:
	var wood := Kit.wood()
	for x in [-2.0, 0.0, 2.0]:
		Kit.box(root, Vector3(x, 0, 0), Vector3(0.08, 1.0, 0.08), wood)
	var tm := TorusMesh.new()
	tm.inner_radius = 0.38
	tm.outer_radius = 0.42
	tm.rings = 10
	tm.ring_segments = 3
	var mat := Kit.flat(Color("8a8478"), 0.5, 0.6)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for i in 11:
		var mi := MeshInstance3D.new()
		mi.mesh = tm
		mi.material_override = mat
		mi.position = Vector3(-2.0 + i * 0.4, 0.42, 0)
		mi.rotation = Vector3(PI / 2.0 + rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))
		root.add_child(mi)


func _sentry_base(root: Node3D) -> void:
	var metal := Kit.flat(Color("3a3a36"), 0.5, 0.6)
	for a in [0.0, 2.1, 4.2]:
		var leg := Kit.box(root, Vector3(cos(a) * 0.3, 0, sin(a) * 0.3), Vector3(0.08, 0.9, 0.08), metal)
		leg.rotation.z = 0.2
	var canvas: StandardMaterial3D = Kit.canvas()
	var bag := SphereMesh.new()
	bag.radius = 0.5
	bag.height = 1.0
	bag.radial_segments = 8
	bag.rings = 4
	for i in 9:
		var a := TAU * i / 9.0
		var mi := MeshInstance3D.new()
		mi.mesh = bag
		mi.material_override = canvas
		mi.position = Vector3(cos(a) * 0.95, 0.16, sin(a) * 0.95)
		mi.rotation.y = -a
		mi.scale = Vector3(0.75, 0.34, 0.45)
		root.add_child(mi)


func _sentry_gun(root: Node3D) -> void:
	var metal := Kit.flat(Color("2e2e2a"), 0.5, 0.6)
	Kit.box(root, Vector3(0, -0.1, 0.15), Vector3(0.16, 0.2, 0.75), metal)
	var barrel := Kit.cylinder(root, Vector3(0, -0.08, 0.75), 0.05, 0.6, Kit.flat(Color("1a1a1a"), 0.4, 0.7), 8)
	barrel.rotation.x = PI / 2.0
	Kit.box(root, Vector3(0.15, -0.18, 0.05), Vector3(0.14, 0.2, 0.2), Kit.flat(Color("3a3a30"), 0.7))
	Kit.box(root, Vector3(0, 0.02, 0.42), Vector3(0.35, 0.3, 0.04), Kit.flat(Color("4a5228"), 0.8))


# ---------------------------------------------------------------- werking

func _nearest(from: Vector3, range_: float):
	var best = null
	var bd := range_
	for e in Game.enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var d: float = Vector2(e.global_position.x - from.x, e.global_position.z - from.z).length()
		if d < bd:
			bd = d
			best = e
	return best


func _shoot(from: Vector3, ang: float, dmg: float, spd: float, life: float, high: float, dist := 18.0) -> void:
	var fwd := Vector3(sin(ang), 0, cos(ang))
	var muzzle := from + fwd * 1.1
	muzzle.y = high
	Bullet.fire(self, muzzle, ang, spd, dmg, life, true, true, 0, 0.0, maxf(0.0, (high - 1.3) / maxf(4.0, dist - 1.1)))
	Fx.muzzle(self, muzzle)


func _physics_process(delta: float) -> void:
	if Game.state != "play" and Game.state != "prep":
		return
	var up: float = Game.upg.sentry
	for i in range(items.size() - 1, -1, -1):
		var d: Dictionary = items[i]
		match d.kind:
			"sentry":
				d.fire_t -= delta
				var e = _nearest(d.pos, 16.0 + up)
				if e:
					var ta := atan2(e.global_position.x - d.pos.x, e.global_position.z - d.pos.z)
					d.aim += angle_difference(d.aim, ta) * minf(1.0, delta * 10.0)
					d.gun.rotation.y = d.aim
					if d.ammo > 0 and d.fire_t <= 0.0 and absf(angle_difference(d.aim, ta)) < 0.2:
						d.fire_t = 0.13
						d.ammo -= 1
						_shoot(d.pos, d.aim + randf_range(-0.05, 0.05), 14.0 * (1.0 + up * 0.25), 80.0, 0.5, 1.0)
						Sfx.play("sentry", 1.0, d.pos)
			"mine":
				d.arm -= delta
				if d.arm <= 0.0:
					for e in Game.enemies:
						if is_instance_valid(e) and not e.dead and Vector2(e.global_position.x - d.pos.x, e.global_position.z - d.pos.z).length() < 1.1 + e.t.r:
							_detonate(d.pos)
							d.node.queue_free()
							items.remove_at(i)
							break
			"wire":
				var ca := cos(d.a)
				var sa := sin(d.a)
				for e in Game.enemies:
					if not is_instance_valid(e) or e.dead:
						continue
					var rx: float = e.global_position.x - d.pos.x
					var rz: float = e.global_position.z - d.pos.z
					var lx := rx * ca - rz * sa
					var lz := rx * sa + rz * ca
					if absf(lx) < 2.2 and absf(lz) < 0.7 + e.t.r:
						e.slow_t = 0.2
						e.wire_dmg += 16.0 * delta
						if e.wire_dmg > 4.0:
							var w: float = e.wire_dmg
							e.wire_dmg = 0.0
							e.hit(w, Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)), true)
	for t in towers:
		t.fire_t -= delta
		if t.mg and t.gun:
			var e = _nearest(t.pos, 26.0)
			if e:
				var ta := atan2(e.global_position.x - t.pos.x, e.global_position.z - t.pos.z)
				t.aim += angle_difference(t.aim, ta) * minf(1.0, delta * 10.0)
				t.gun.rotation.y = t.aim
				if t.ammo > 0 and t.fire_t <= 0.0 and absf(angle_difference(t.aim, ta)) < 0.2:
					t.fire_t = 0.14
					t.ammo -= 1
					_shoot(t.pos, t.aim + randf_range(-0.04, 0.04), 16.0 * (1.0 + up * 0.25), 85.0, 0.55, TOWER_TOP + 1.2, Vector2(e.global_position.x - t.pos.x, e.global_position.z - t.pos.z).length())
					Sfx.play("sentry", 1.0, t.pos)
		if t.guard:
			t.guard_t -= delta
			var e = _nearest(t.pos, 24.0)
			var m: SoldierModel = t.guard
			if e:
				var fa := atan2(e.global_position.x - t.pos.x, e.global_position.z - t.pos.z)
				m.rotation.y += angle_difference(m.rotation.y, fa) * minf(1.0, delta * 7.0)
				m.play("schieten")
				if t.guard_t <= 0.0 and absf(angle_difference(m.rotation.y, fa)) < 0.15:
					t.guard_t = randf_range(0.42, 0.6)
					_shoot(t.pos, m.rotation.y + randf_range(-0.05, 0.05), 15.0, 70.0, 0.5, TOWER_TOP + 1.4, Vector2(e.global_position.x - t.pos.x, e.global_position.z - t.pos.z).length())
					Sfx.play("enemy", 0.8, t.pos)
			else:
				m.play("stil")


func _detonate(at: Vector3) -> void:
	Fx.explosion(self, at, 1.2)
	for e in Game.enemies.duplicate():
		if is_instance_valid(e) and not e.dead:
			var d: float = e.global_position.distance_to(at)
			if d < 4.6:
				e.hit(240.0 * (1.0 - d / 4.6 * 0.7), (e.global_position - at).normalized(), true)


## Staat de speler in een loopgraaf? Dan missen vijanden ruim de helft van hun schoten.
func in_trench(p: Vector3) -> bool:
	for d in items:
		if d.kind == "trench":
			var rel: Vector3 = p - d.pos
			var ca := cos(d.a)
			var sa := sin(d.a)
			if absf(rel.x * ca - rel.z * sa) < 2.3 and absf(rel.x * sa + rel.z * ca) < 0.65:
				return true
	return false
