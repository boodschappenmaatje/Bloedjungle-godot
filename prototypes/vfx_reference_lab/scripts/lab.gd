extends Node3D
## Standalone visual comparison ONLY: no imports from the live game.
## Keys: 1 = wood, 2 = concrete, 3 = metal, SPACE = replay, A = auto fire.
const LABELS := ["WOOD", "CONCRETE", "METAL"]
const COLORS := [Color("755038"), Color("969a93"), Color("565e5b")]
const START := Vector3(-4.5, 1.2, 4.3)
const TARGETS := [Vector3(-3.0, 1.1, -3.0), Vector3(0.0, 1.1, -3.0), Vector3(3.0, 1.1, -3.0)]
const MAX_TRANSIENT := 64
const MAX_MARKS := 24
var selected := 0
var auto_fire := false
var cooldown := 0.0
var transients: Array[Dictionary] = []
var marks: Array[Node3D] = []
var status_label: Label3D

func _ready() -> void:
	_setup_world()
	_update_label()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1: selected = 0
		KEY_2: selected = 1
		KEY_3: selected = 2
		KEY_SPACE: _fire()
		KEY_A: auto_fire = not auto_fire
	_update_label()

func _process(delta: float) -> void:
	if auto_fire:
		cooldown -= delta
		if cooldown <= 0.0:
			_fire()
			cooldown = 0.23
	for i in range(transients.size() - 1, -1, -1):
		var item: Dictionary = transients[i]
		item["age"] += delta
		var node: Node3D = item["node"]
		if not is_instance_valid(node):
			transients.remove_at(i)
			continue
		var t: float = item["age"] / item["life"]
		if t >= 1.0:
			node.queue_free()
			transients.remove_at(i)
		else:
			node.scale = item["scale"] * (1.0 + 0.4 * t)
			if node is MeshInstance3D:
				var mat := node.material_override as StandardMaterial3D
				if mat:
					var c := mat.albedo_color
					c.a = 1.0 - t
					mat.albedo_color = c

func _setup_world() -> void:
	var camera := Camera3D.new()
	camera.position = Vector3(0, 12.5, 15.0)
	camera.look_at(Vector3(0, 0.7, 0), Vector3.UP)
	camera.current = true
	add_child(camera)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("172021")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("858e8a")
	world.environment.ambient_light_energy = 0.55
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-53, -25, 0)
	sun.light_energy = 1.2
	add_child(sun)
	_box(Vector3(0, -0.15, 0), Vector3(14, 0.3, 13), Color("384236"))
	for i in 3:
		_box(TARGETS[i], Vector3(2.2, 2.2, 0.35), COLORS[i])
		var target_name := Label3D.new()
		target_name.text = LABELS[i]
		target_name.position = TARGETS[i] + Vector3(0, 1.65, 0)
		target_name.font_size = 55
		target_name.pixel_size = 0.005
		add_child(target_name)
	var barrel := _box(START, Vector3(0.4, 0.4, 1.3), Color("202827"))
	barrel.rotation.y = 0.12
	status_label = Label3D.new()
	status_label.position = Vector3(0, 4.2, -3.6)
	status_label.font_size = 50
	status_label.pixel_size = 0.006
	add_child(status_label)

func _update_label() -> void:
	if status_label:
		status_label.text = "BLOEDJUNGLE VFX LAB | 1 WOOD  2 CONCRETE  3 METAL | SPACE FIRE | A AUTO\nTARGET: %s   AUTO: %s" % [LABELS[selected], "ON" if auto_fire else "OFF"]

func _fire() -> void:
	var target: Vector3 = TARGETS[selected]
	var direction := (target - START).normalized()
	# White core + amber halo, very short. Both are standalone preview primitives.
	_flash(START + direction * 0.8, Color("fff4c5"), 0.25, 0.055)
	_flash(START + direction * 0.82, Color("ff9e37"), 0.44, 0.085)
	var path := target - START
	_line(START + direction, target, Color("ffd78b"), 0.025, 0.12)
	_line(START + direction, target, Color("ff9a34"), 0.067, 0.065)
	_impact(target, direction, selected)

func _impact(point: Vector3, direction: Vector3, material_index: int) -> void:
	var flash_color := Color("dbac65")
	if material_index == 1:
		flash_color = Color("c9c5b8")
	elif material_index == 2:
		flash_color = Color("ffcc6a")
	_flash(point + Vector3(0, 0, 0.24), flash_color, 0.19, 0.10)
	var count := 4 if material_index == 0 else (7 if material_index == 1 else 9)
	for i in count:
		var spread := Vector3(randf_range(-0.7, 0.7), randf_range(-0.2, 0.9), randf_range(0.12, 0.8))
		var fragment_color := flash_color if material_index == 2 else COLORS[material_index]
		_line(point + Vector3(0, 0, 0.2), point + spread, fragment_color, 0.018, 0.25 + randf() * 0.18)
	# A bounded persistent mark on the impact surface. Not a gameplay decal.
	var mark := _box(point + Vector3(0, 0, 0.19), Vector3(0.14, 0.14, 0.015), Color("151513"))
	marks.append(mark)
	if marks.size() > MAX_MARKS:
		var oldest := marks.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

func _flash(point: Vector3, tint: Color, size: float, duration: float) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = size
	sphere.height = size * 2.0
	var node := MeshInstance3D.new()
	node.mesh = sphere
	node.material_override = _mat(tint, true)
	node.position = point
	add_child(node)
	_track(node, duration)

func _line(a: Vector3, b: Vector3, tint: Color, width: float, duration: float) -> void:
	var span := b - a
	if span.length() < 0.001:
		return
	var tube := CylinderMesh.new()
	tube.top_radius = width
	tube.bottom_radius = width
	tube.height = span.length()
	tube.radial_segments = 6
	var node := MeshInstance3D.new()
	node.mesh = tube
	node.material_override = _mat(tint, true)
	node.position = (a + b) * 0.5
	node.quaternion = Quaternion(Vector3.UP, span.normalized())
	add_child(node)
	_track(node, duration)

func _track(node: Node3D, duration: float) -> void:
	transients.append({"node": node, "age": 0.0, "life": duration, "scale": node.scale})
	if transients.size() > MAX_TRANSIENT:
		var oldest: Dictionary = transients.pop_front()
		if is_instance_valid(oldest["node"]):
			oldest["node"].queue_free()

func _box(pos: Vector3, box_size: Vector3, tint: Color) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = box_size
	var item := MeshInstance3D.new()
	item.mesh = shape
	item.material_override = _mat(tint)
	item.position = pos
	add_child(item)
	return item

func _mat(tint: Color, glow := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if glow else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	if glow:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.emission_enabled = true
		material.emission = tint
		material.emission_energy_multiplier = 2.0
	return material
