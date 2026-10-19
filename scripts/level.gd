@tool
extends Node3D
## Bouwt de wereld: jungle-grond, de betonnen borstwering rond de basis met twee poortopeningen,
## de bunker in het midden en bomen buiten de muur. @tool: je ziet het ook in de editor.
## Maten uit 05-world.js van de web-versie.

const CONCRETE := Color("8c897d")
const CAP := Color("9a978a")


func _ready() -> void:
	for c in get_children():
		c.free()
	_ground()
	_wall()
	_bunker()
	_trees()


func _ground() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(160, 1, 160)
	col.shape = shape
	col.position.y = -0.5
	body.add_child(col)
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(160, 160)
	mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	var noise := FastNoiseLite.new()
	noise.frequency = 0.02
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	var ramp := Gradient.new()
	ramp.set_color(0, Color("2c3a18"))
	ramp.set_color(1, Color("55602e"))
	tex.color_ramp = ramp
	mat.albedo_texture = tex
	mat.uv1_scale = Vector3(12, 12, 1)
	mat.roughness = 0.95
	mesh.material_override = mat
	body.add_child(mesh)
	add_child(body)


## Borstwering van 28 x 28 m, op borsthoogte, met openingen in het noorden en zuiden.
func _wall() -> void:
	var c := Data.COMPOUND
	var g := Data.GATE_GAP
	var half := (c - g) / 2.0  # lengte van een stuk naast een poort, gedeeld door 2
	var segs := [
		[Vector3(-(g + half), 0, -c), Vector2(c - g, Data.WALL_T)], [Vector3(g + half, 0, -c), Vector2(c - g, Data.WALL_T)],
		[Vector3(-(g + half), 0, c), Vector2(c - g, Data.WALL_T)], [Vector3(g + half, 0, c), Vector2(c - g, Data.WALL_T)],
		[Vector3(-c, 0, 0), Vector2(Data.WALL_T, c * 2 + Data.WALL_T)], [Vector3(c, 0, 0), Vector2(Data.WALL_T, c * 2 + Data.WALL_T)],
	]
	for s in segs:
		_block(s[0], Vector3(s[1].x, Data.WALL_H, s[1].y), CONCRETE, 2)
		_block(s[0] + Vector3.UP * Data.WALL_H, Vector3(s[1].x + 0.12, 0.12, s[1].y + 0.12), CAP, 0)


func _bunker() -> void:
	var b := _block(Vector3.ZERO, Vector3(4.6, 2.0, 4.6), Color("8a877a"), 16)
	b.add_to_group("bunker")
	b.set_script(preload("res://scripts/bunker.gd"))
	_block(Vector3.UP * 2.0, Vector3(5.1, 0.38, 5.1), Color("6e6b60"), 0)
	_block(Vector3(0, 1.32, 2.3), Vector3(2.2, 0.26, 0.14), Color("0c0c0c"), 0)  # schietgat
	_block(Vector3(1.2, 0, 2.31), Vector3(1.0, 1.5, 0.12), Color("1a1712"), 0)  # deur
	_block(Vector3(-1.8, 2.38, -1.8), Vector3(0.08, 3.2, 0.08), Color("8a8a8a"), 0)  # vlaggenmast
	_block(Vector3(-1.25, 4.9, -1.8), Vector3(1.1, 0.7, 0.03), Color("3d6b2d"), 0)


## Een blok met de onderkant op pos.y. layer 0 = alleen te zien, geen botsing.
func _block(pos: Vector3, size: Vector3, col: Color, layer: int) -> Node3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.9
	box.material = mat
	mesh.mesh = box
	mesh.position.y = size.y / 2.0
	var root: Node3D = mesh
	if layer:
		var body := StaticBody3D.new()
		body.collision_layer = layer
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		shape.shape = bs
		shape.position.y = size.y / 2.0
		body.add_child(shape)
		body.add_child(mesh)
		root = body
	else:
		mesh.position = pos + Vector3.UP * size.y / 2.0
	if layer:
		root.position = pos
	add_child(root)
	return root


## Jungle buiten de muur: alleen om te zien (de vijanden lopen er dwars doorheen).
func _trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.15
	trunk.bottom_radius = 0.25
	trunk.height = 4.0
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color("4a3a26")
	trunk.material = tm
	var crown := SphereMesh.new()
	crown.radius = 1.8
	crown.height = 2.6
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color("2f5a1e")
	crown.material = cm
	for i in 70:
		var a := rng.randf() * TAU
		var r := rng.randf_range(22.0, 70.0)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		var s := rng.randf_range(0.8, 1.4)
		var t := MeshInstance3D.new()
		t.mesh = trunk
		t.position = p + Vector3.UP * 2.0 * s
		t.scale = Vector3.ONE * s
		add_child(t)
		var k := MeshInstance3D.new()
		k.mesh = crown
		k.position = p + Vector3.UP * 4.4 * s
		k.scale = Vector3.ONE * s
		add_child(k)
