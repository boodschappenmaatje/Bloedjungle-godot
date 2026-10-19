class_name Fx
## Kleine effecten: bloed, stof bij een inslag en de mondingsflits.

static var _flash_mesh: SphereMesh


static func blood(parent: Node, pos: Vector3, dir: Vector3, amount := 14) -> void:
	_burst(parent, pos, dir, amount, Color(0.42, 0.02, 0.02), 0.07, 5.0)


static func dust(parent: Node, pos: Vector3) -> void:
	_burst(parent, pos, Vector3.UP, 6, Color(0.55, 0.5, 0.42), 0.05, 2.5)


static func _burst(parent: Node, pos: Vector3, dir: Vector3, amount: int, col: Color, size: float, spd: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.6
	p.explosiveness = 1.0
	p.direction = (dir + Vector3.UP * 0.6).normalized()
	p.spread = 35.0
	p.initial_velocity_min = spd * 0.4
	p.initial_velocity_max = spd
	p.gravity = Vector3(0, -14, 0)
	p.scale_amount_min = 0.6
	var m := BoxMesh.new()
	m.size = Vector3.ONE * size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material = mat
	p.mesh = m
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)


## Mondingsflits: een felgele bol die na een paar honderdsten verdwijnt.
static func muzzle(parent: Node, pos: Vector3) -> void:
	if _flash_mesh == null:
		_flash_mesh = SphereMesh.new()
		_flash_mesh.radius = 0.16
		_flash_mesh.height = 0.32
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.8, 0.35)
		_flash_mesh.material = mat
	var f := MeshInstance3D.new()
	f.mesh = _flash_mesh
	parent.add_child(f)
	f.global_position = pos
	parent.get_tree().create_timer(0.05).timeout.connect(f.queue_free)
