@tool
extends Node3D
## Bouwt de wereld: de jungle-bodem, de basis (base_props.gd) en de jungle eromheen (foliage.gd).
## @tool: je ziet het ook in de editor. Maten uit 05-world.js van de web-versie.

const SIZE := 240.0


func _ready() -> void:
	for c in get_children():
		c.free()
	_ground()
	BaseProps.build(self)
	Foliage.plant(self)


func _ground() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Kit.LAYER_GROUND
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(SIZE, 1, SIZE)
	col.shape = shape
	col.position.y = -0.5
	body.add_child(col)
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(SIZE, SIZE)
	mesh.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/ground.gdshader")
	mat.set_shader_parameter("noise_a", Kit.noise_tex(0.02, 3))
	mat.set_shader_parameter("noise_b", Kit.noise_tex(0.045, 8))
	mat.set_shader_parameter("compound", Data.COMPOUND)
	mat.set_shader_parameter("gate_gap", Data.GATE_GAP)
	mesh.material_override = mat
	body.add_child(mesh)
	add_child(body)
