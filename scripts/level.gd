@tool
extends Node3D
## Bouwt de wereld: de jungle-bodem, de basis (base_props.gd) en de jungle eromheen (foliage.gd).
## @tool: je ziet het ook in de editor. Maten uit 05-world.js van de web-versie.

const SIZE := 440.0


var built := false


func _ready() -> void:
	# in de editor, bij tests en met BJ_INSTANT meteen bouwen; in het spel doet main dat achter het laadscherm
	if Engine.is_editor_hint() or DisplayServer.get_name() == "headless" or OS.has_environment("BJ_INSTANT"):
		build_now()


func build_now() -> void:
	for c in get_children():
		c.free()
	_ground()
	BaseProps.build(self)
	River.build(self)
	Stad.build(self)
	Foliage.plant(self)
	built = true


## Bouwt de wereld in stappen, met een beeld tussen elke stap, zodat het laadscherm blijft bewegen.
## progress(fractie, tekst) wordt na elke stap aangeroepen.
func build_stepped(progress: Callable) -> void:
	for c in get_children():
		c.free()
	var tick := func(frac: float, text: String) -> void:
		progress.call(frac, text)
		await get_tree().process_frame
	await tick.call(0.02, "Grond leggen...")
	_ground()
	await tick.call(0.1, "Basis bouwen...")
	BaseProps.build(self)
	await tick.call(0.2, "Rivier en brug...")
	River.build(self)
	Stad.build(self)
	var names := {"palm": "Palmen planten...", "bush": "Struiken planten...", "fern": "Varens planten...", "grass": "Gras laten groeien...", "rock": "Rotsen neerleggen..."}
	var order := ["palm", "bush", "fern", "grass", "rock"]
	var step := func(kind: String) -> void:
		await tick.call(0.3 + 0.12 * order.find(kind), names[kind])
	await Foliage.plant(self, 11, step)
	built = true


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
	mat.set_shader_parameter("grass_tex", load("res://assets/textures/terrain/grass/base_color.jpg"))
	mat.set_shader_parameter("jungle_tex", load("res://assets/textures/terrain/jungle_ground/base_color.jpg"))
	mat.set_shader_parameter("dirt_tex", load("res://assets/textures/terrain/dry_earth/base_color.jpg"))
	mat.set_shader_parameter("mud_tex", load("res://assets/textures/terrain/gravel_rock/base_color.jpg"))
	mat.set_shader_parameter("dirt_height", load("res://assets/textures/terrain/dry_earth/roughness.jpg"))
	mat.set_shader_parameter("dirt_normal", load("res://assets/textures/terrain/dry_earth/normal_gl.jpg"))
	mat.set_shader_parameter("compound", Data.COMPOUND)
	mat.set_shader_parameter("gate_gap", Data.GATE_GAP)
	mesh.material_override = mat
	body.add_child(mesh)
	body.add_to_group("ground")
	body.set_meta("mat", mat)
	add_child(body)
