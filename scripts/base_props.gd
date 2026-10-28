class_name BaseProps
## De basis: betonnen muur met palen, de bunker met zandzakken en antenne, vier wachttorens,
## (hutten en kratten zijn weg). Muren, bunker en torens houden kogels en mensen tegen.
## Maten van muur, poorten en bunker komen uit data.gd (zoals in de web-versie).

const C := Data.COMPOUND
const G := Data.GATE_GAP
const BUNKER_GAME_ASSET := preload("res://assets/tests/bunker/bloedjungle_bunker_hq.glb")
const BUNKER_COLLISION_SIZE := Vector3(4.6, 2.0, 4.6)


static func build(root: Node3D) -> void:
	_wall(root)
	_gates(root)
	_bunker(root)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_tower(root, Vector3(sx * (C - 1.8), 0, sz * (C - 1.8)))
	Kit.sandbags(root, Vector3(-C + 0.7, 0, 3.0), Vector3(-C + 0.7, 0, 8.0), 2, 3)
	Kit.sandbags(root, Vector3(C - 0.7, 0, -3.0), Vector3(C - 0.7, 0, -8.0), 2, 4)
	_crates(root, Vector3(-C + 6.5, 0, -C + 5.5))  # voorraadhoek bij de noordwesthoek


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


## Poortposten; de stalen schuifpoorten en de zwaailichten erop staan in gates.gd.
static func _gates(root: Node3D) -> void:
	for sz in [-1.0, 1.0]:
		for sx in [-1.0, 1.0]:
			var p := Vector3(sx * (G + 0.3), 0, sz * C)
			Kit.box(root, p, Vector3(0.7, 2.1, 0.7), Kit.concrete_dark(), 0.0, Kit.LAYER_WALL)
			Kit.box(root, p + Vector3.UP * 2.1, Vector3(0.9, 0.16, 0.9), Kit.concrete())
		# stalen bovenbalk met geel-zwarte rand
		Kit.box(root, Vector3(0, 2.0, sz * C), Vector3(G * 2.0 + 1.0, 0.18, 0.4), Kit.olive())
		for i in 10:
			var x := -G + 0.25 + i * (G * 2.0 / 9.0)
			Kit.box(root, Vector3(x, 1.84, sz * C), Vector3(0.22, 0.16, 0.44), Kit.flat(Color("c9a227") if i % 2 == 0 else Color("1a1a18")))


static func _bunker(root: Node3D) -> void:
	# Keep the original gameplay body exactly: same layer, 4.6 × 2 × 4.6 m box,
	# position, damage script and FX anchors. Only the visual child is replaced.
	var b := StaticBody3D.new()
	b.name = "Bunker"
	b.collision_layer = Kit.LAYER_BUNKER
	b.collision_mask = 0
	b.set_script(preload("res://scripts/bunker.gd"))
	b.set_process(true)
	var collision := CollisionShape3D.new()
	collision.name = "BunkerCollision"
	var shape := BoxShape3D.new()
	shape.size = BUNKER_COLLISION_SIZE
	collision.shape = shape
	collision.position.y = BUNKER_COLLISION_SIZE.y / 2.0
	b.add_child(collision)
	var visual := BUNKER_GAME_ASSET.instantiate() as Node3D
	visual.name = "Bunker_High_Quality_Showcase"
	# Fit the 8.4 × 7.2 m source footprint to the existing 4.6 m gameplay
	# footprint while retaining the authored vertical silhouette and door.
	visual.scale = Vector3(0.547619, 0.55, 0.638889)
	b.add_child(visual)
	root.add_child(b)
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
	for i in 5:
		var s := rng.randf_range(0.7, 1.0)
		var p := pos + Vector3(rng.randf_range(-1.0, 1.0), 0, rng.randf_range(-0.8, 0.8))
		var yaw := rng.randf() * PI
		Kit.prop(root, "Kist_Hout", p, s, yaw)
		Kit.collider(root, p + Vector3(0, s * 0.45, 0), Vector3(s, s * 0.9, s) * 1.1, Kit.LAYER_WALL)
		if i < 2:
			Kit.prop(root, "Kist_Hout", p + Vector3(0, s * 0.91, 0), s * 0.85, rng.randf() * PI)
		elif i == 2:
			Kit.prop(root, "Kist_Munitie", p + Vector3(0, s * 0.91, 0), 1.5, rng.randf() * PI)
	Kit.collider(root, pos + Vector3(0.15, 0.3, 1.5), Vector3(1.4, 0.6, 0.7), Kit.LAYER_WALL)
	Kit.prop(root, "Kist_Munitie", pos + Vector3(-0.2, 0, 1.4), 1.5, 0.4)
	Kit.prop(root, "Kist_Munitie", pos + Vector3(0.5, 0, 1.55), 1.5, -0.2)
	Kit.prop(root, "Kist_Munitie", pos + Vector3(0.5, 0.45, 1.55), 1.5, -0.1)
	Kit.collider(root, pos + Vector3(2.4, 0.45, 0.9), Vector3(2.0, 0.9, 0.7), Kit.LAYER_WALL)
	for i in 3:
		Kit.cylinder(root, pos + Vector3(1.7 + i * 0.7, 0, 0.9), 0.3, 0.9, Kit.olive() if i != 1 else Kit.rust(), 10)
