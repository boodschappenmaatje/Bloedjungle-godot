extends Node3D
## Godot-demo van de personenauto (scenes/auto_demo.tscn): links een auto waar je de schade en de ontploffing mee uitprobeert, rechts
## het kale Blender-model met alle zes echte GLB-clips. Knoppen onderin; tik/sleep op het scherm draait de camera niet (vaste gamecamera).
## Draaien: godot --path . scenes/auto_demo.tscn  (of open de scène in de editor / Xogot en start hem).

const MODEL := preload("res://assets/auto.glb")

var car: Auto
var raw: Node3D
var raw_anim: AnimationPlayer
var cam: Camera3D
var label: Label


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.36, 0.42, 0.34)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.75, 0.8)
	env.environment.ambient_light_energy = 0.6
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.22, 0.26, 0.17)
	gm.roughness = 1.0
	ground.material_override = gm
	add_child(ground)
	cam = Camera3D.new()
	cam.fov = 45.0
	add_child(cam)
	cam.position = Vector3(0, sin(deg_to_rad(58.0)) * 16.0, cos(deg_to_rad(58.0)) * 16.0 + 0.5)
	cam.look_at(Vector3(0.5, 0, 0.5))
	_spawn()
	raw = MODEL.instantiate()
	add_child(raw)
	raw.position = Vector3(5.2, 0, 0)
	raw_anim = raw.find_child("AnimationPlayer", true, false)
	var layer := CanvasLayer.new()
	add_child(layer)
	var box := HFlowContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	box.offset_top = -150.0
	box.offset_left = 8.0
	box.offset_right = -8.0
	box.offset_bottom = -8.0
	layer.add_child(box)
	for e in [["10 kogels", _shoot], ["Rocket", _rocket], ["Brand", _fire], ["Ontplof", _boom], ["Nieuwe auto", _spawn]]:
		_button(box, e[0], e[1])
	for clip in ["DeurenOpen", "KapOpen", "KofferOpen", "Ruitenwissers", "Knipperen", "Alarm"]:
		_button(box, clip, _clip.bind(clip))
	label = Label.new()
	label.position = Vector2(12, 8)
	label.add_theme_font_size_override("font_size", 18)
	layer.add_child(label)


func _button(parent: Control, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(120, 44)
	b.pressed.connect(cb)
	parent.add_child(b)


func _spawn() -> void:
	if car != null and is_instance_valid(car):
		car.queue_free()
	car = Auto.make("auto", randi())
	car.position = Vector3(-2.6, 0, 0)
	add_child(car)


func _process(_d: float) -> void:
	if car != null and is_instance_valid(car):
		label.text = "hp %d / %d · fase %d%s%s" % [maxf(car.hp, 0.0), Auto.HP, car.stage, " · brandt" if car.burning else "", " · wrak" if car.wreck else ""]


func _shoot() -> void:
	for i in 10:
		car.hit(26.0, Vector3.RIGHT, true)


func _rocket() -> void:
	Game.note_blast(car.global_position + Vector3(1.5, 0.5, 0), 4.8)


func _fire() -> void:
	car.take(maxf(car.hp - Auto.HP * 0.25, 1.0))


func _boom() -> void:
	car.explode()


func _clip(n: String) -> void:
	if raw_anim != null and raw_anim.has_animation(n):
		raw_anim.play(n)
