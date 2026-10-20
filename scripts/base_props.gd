class_name BaseProps
## De basis: betonnen muur met palen, de bunker met zandzakken en antenne, vier wachttorens,
## twee hutten en kratten. Muren, bunker, torens en hutten houden kogels en mensen tegen.
## Maten van muur, poorten en bunker komen uit data.gd (zoals in de web-versie).

const C := Data.COMPOUND
const G := Data.GATE_GAP


static func build(root: Node3D) -> void:
	_wall(root)
	_gates(root)
	_bunker(root)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_tower(root, Vector3(sx * (C - 1.8), 0, sz * (C - 1.8)))
	_hut(root, Vector3(-9.6, 0, 7.5), 0.12)
	_hut(root, Vector3(9.4, 0, -8.0), PI + 0.1)
	_crates(root, Vector3(-6.2, 0, 9.2))
	_crates(root, Vector3(6.4, 0, -9.6))
	Kit.sandbags(root, Vector3(-C + 0.7, 0, 3.0), Vector3(-C + 0.7, 0, 8.0), 2, 3)
	Kit.sandbags(root, Vector3(C - 0.7, 0, -3.0), Vector3(C - 0.7, 0, -8.0), 2, 4)


## Borstwering met een palenrij en een rand erop; open bij de twee poorten.
static func _wall(root: Node3D) -> void:
	var half := (C - G) / 2.0
	var h := Data.WALL_H
	var t := Data.WALL_T
	var segs := [
		[Vector3(-(G + half), 0, -C), Vector2(C - G, t), true], [Vector3(G + half, 0, -C), Vector2(C - G, t), true],
		[Vector3(-(G + half), 0, C), Vector2(C - G, t), true], [Vector3(G + half, 0, C), Vector2(C - G, t), true],
		[Vector3(-C, 0, 0), Vector2(t, C * 2.0 + t), false], [Vector3(C, 0, 0), Vector2(t, C * 2.0 + t), false],
	]
	for s in segs:
		var p: Vector3 = s[0]
		var sz: Vector2 = s[1]
		Kit.box(root, p, Vector3(sz.x, h, sz.y), Kit.concrete(), 0.0, Kit.LAYER_WALL)
		Kit.box(root, p + Vector3.UP * h, Vector3(sz.x + 0.1, 0.14, sz.y + 0.14), Kit.concrete_dark())
		Kit.box(root, p + Vector3.UP * 0.0, Vector3(sz.x + 0.06, 0.28, sz.y + 0.2), Kit.concrete_dark())
		# palen elke 3,5 m
		var along_x: bool = s[2]
		var len := sz.x if along_x else sz.y
		var n := int(len / 3.5)
		for i in range(n + 1):
			var off := -len / 2.0 + i * (len / maxf(n, 1))
			var pp := p + (Vector3(off, 0, 0) if along_x else Vector3(0, 0, off))
			Kit.box(root, pp, Vector3(0.55 if along_x else t + 0.25, h + 0.3, t + 0.25 if along_x else 0.55), Kit.concrete_dark())


## Poortposten met een rood lampje; de stalen poorten komen later weer terug.
static func _gates(root: Node3D) -> void:
	var lamp := Kit.flat(Color(1.0, 0.15, 0.08), 0.4)
	lamp.emission_enabled = true
	lamp.emission = Color(1.0, 0.1, 0.05)
	lamp.emission_energy_multiplier = 2.5
	for sz in [-1.0, 1.0]:
		for sx in [-1.0, 1.0]:
			var p := Vector3(sx * (G + 0.3), 0, sz * C)
			Kit.box(root, p, Vector3(0.7, 2.1, 0.7), Kit.concrete_dark(), 0.0, Kit.LAYER_WALL)
			Kit.box(root, p + Vector3.UP * 2.1, Vector3(0.9, 0.16, 0.9), Kit.concrete())
			var l := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.1
			sm.height = 0.2
			l.mesh = sm
			l.material_override = lamp
			l.position = p + Vector3(0, 2.4, 0)
			root.add_child(l)
		# stalen bovenbalk met geel-zwarte rand
		Kit.box(root, Vector3(0, 2.0, sz * C), Vector3(G * 2.0 + 1.0, 0.18, 0.4), Kit.olive())
		for i in 10:
			var x := -G + 0.25 + i * (G * 2.0 / 9.0)
			Kit.box(root, Vector3(x, 1.84, sz * C), Vector3(0.22, 0.16, 0.44), Kit.flat(Color("c9a227") if i % 2 == 0 else Color("1a1a18")))


static func _bunker(root: Node3D) -> void:
	var b := Kit.box(root, Vector3.ZERO, Vector3(4.6, 2.0, 4.6), Kit.concrete(), 0.0, Kit.LAYER_BUNKER)
	b.set_script(preload("res://scripts/bunker.gd"))
	b.set_process(true)
	Kit.box(root, Vector3(0, 2.0, 0), Vector3(5.2, 0.4, 5.2), Kit.concrete_dark())
	Kit.box(root, Vector3(0, 2.4, 0), Vector3(4.2, 0.18, 4.2), Kit.concrete())
	# schietgleuven rondom en een stalen deur
	var dark := Kit.flat(Color("0b0b0a"), 1.0)
	for yaw in [0.0, PI / 2.0, PI, -PI / 2.0]:
		var d := Vector3(sin(yaw), 0, cos(yaw))
		Kit.box(root, d * 2.3 + Vector3(0, 1.3, 0), Vector3(2.2, 0.3, 0.12), dark, yaw)
	Kit.box(root, Vector3(1.1, 0, 2.31), Vector3(1.0, 1.55, 0.14), Kit.flat(Color("1b1812"), 0.6, 0.5))
	Kit.box(root, Vector3(1.1, 1.55, 2.33), Vector3(1.2, 0.14, 0.3), Kit.concrete_dark())
	# camouflagenet over de rand van het dak
	var net := Kit.box(root, Vector3(-1.2, 2.62, -1.0), Vector3(2.8, 0.06, 2.6), Kit.olive(), 0.15)
	net.rotation.z = 0.06
	# machinegeweernest op het dak: zandzakken en een geweer
	Kit.sandbags(root, Vector3(0.4, 2.6, 1.9), Vector3(2.0, 2.6, 1.9), 2, 7)
	Kit.cylinder(root, Vector3(1.2, 2.6, 1.5), 0.05, 0.6, Kit.flat(Color("1a1a1a"), 0.5, 0.6), 6)
	Kit.box(root, Vector3(1.2, 3.1, 1.4), Vector3(0.1, 0.1, 0.9), Kit.flat(Color("111111"), 0.4, 0.7))
	# antenne en schotel
	Kit.cylinder(root, Vector3(-1.8, 2.6, -1.8), 0.05, 3.4, Kit.flat(Color("8a8a8a"), 0.4, 0.8), 6)
	Kit.cylinder(root, Vector3(-1.2, 2.6, 1.2), 0.04, 1.0, Kit.flat(Color("2a2a2a"), 0.6, 0.5), 6)
	var dish := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 0.5
	sm.is_hemisphere = true
	dish.mesh = sm
	dish.material_override = Kit.flat(Color("9a9a92"), 0.4, 0.6)
	dish.position = Vector3(-1.2, 3.7, 1.2)
	dish.rotation = Vector3(-1.1, 0.6, 0.0)
	root.add_child(dish)
	# vlag
	Kit.cylinder(root, Vector3(1.9, 2.6, -1.9), 0.04, 3.2, Kit.flat(Color("c9c9bd"), 0.4, 0.5), 6)
	Kit.box(root, Vector3(2.4, 5.1, -1.9), Vector3(1.0, 0.65, 0.03), Kit.flat(Color("3d6b2d"), 0.9))
	# zandzakkenring met een opening bij de deur
	var r := 3.05
	Kit.sandbags(root, Vector3(-r, 0, -r), Vector3(r, 0, -r), 2, 21)
	Kit.sandbags(root, Vector3(-r, 0, r), Vector3(-r, 0, -r), 2, 22)
	Kit.sandbags(root, Vector3(r, 0, -r), Vector3(r, 0, r), 2, 23)
	Kit.sandbags(root, Vector3(-r, 0, r), Vector3(0.1, 0, r), 2, 24)


## Houten wachttoren met platform, reling, ladder en golfplaten dak.
static func _tower(root: Node3D, pos: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = 0.0 if pos.x < 0.0 else PI  # de trap loopt naar het midden van de basis
	root.add_child(holder)
	holder.add_to_group("tower")
	Kit.collider(holder, Vector3(0, 2.5, 0), Vector3(1.9, 5.0, 1.9), Kit.LAYER_WALL)
	var model: Node = (load("res://assets/wachttoren.glb") as PackedScene).instantiate()
	Kit.skin(model, "toren")
	holder.add_child(model)


static func _hut(root: Node3D, pos: Vector3, yaw: float) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	holder.scale = Vector3.ONE * 1.15
	root.add_child(holder)
	Kit.box(holder, Vector3.ZERO, Vector3(3.6, 2.3, 2.8), Kit.photo("buildings/plywood", 2.0, Color(0.62, 0.64, 0.5)), 0.0, Kit.LAYER_WALL)
	Kit.box(holder, Vector3(0, 0, 0), Vector3(3.7, 0.3, 2.9), Kit.concrete_dark())
	Kit.gable(holder, Vector3(0, 2.3, 0), Vector3(4.4, 1.0, 3.6), Kit.roof())
	Kit.box(holder, Vector3(-0.6, 0, 1.41), Vector3(0.9, 1.7, 0.1), Kit.wood())
	Kit.box(holder, Vector3(0.9, 1.0, 1.41), Vector3(0.8, 0.7, 0.1), Kit.flat(Color("14130f"), 0.8))
	Kit.box(holder, Vector3(1.8, 0, 0.0), Vector3(0.12, 1.1, 2.6), Kit.canvas())


static func _crates(root: Node3D, pos: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pos.x * 10.0 + pos.z)
	var wood := Kit.wood()
	for i in 5:
		var s := rng.randf_range(0.7, 1.0)
		var p := pos + Vector3(rng.randf_range(-1.0, 1.0), 0, rng.randf_range(-0.8, 0.8))
		Kit.box(root, p, Vector3(s, s * 0.85, s), wood, rng.randf() * PI)
		if i < 2:
			Kit.box(root, p + Vector3(0, s * 0.85, 0), Vector3(s * 0.85, s * 0.7, s * 0.85), wood, rng.randf() * PI)
	for i in 3:
		Kit.cylinder(root, pos + Vector3(1.7 + i * 0.7, 0, 0.9), 0.3, 0.9, Kit.olive() if i != 1 else Kit.rust(), 10)
