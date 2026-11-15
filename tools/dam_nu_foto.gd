extends SceneTree
## Opnames voor de dambreuk-keuzekaart: de huidige rivier en brug (spelcamera), een overzicht van de vallei vanaf
## grotere hoogte, en dezelfde blik met een proef-overstromingsvlak op de huidige vlakke grond (0,5 m water).
var main: Node
var game: Node
var lvl: Node3D
var out := "/tmp/claude-0/dam"
var frames := 0
var cam: Camera3D
var flood: MeshInstance3D

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _shot(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(out + "/" + n)
	print("opname ", n)

func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		Data.mcv_autodeploy = true
		main.begin()
		game = root.get_node("Game")
		lvl = main.get_node("Level")
		for m in get_nodes_in_group("menus"):
			m._show("")
		for n in root.find_children("*", "", true, false):
			if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
				n.set_process(false)
	if frames == 20:
		Data.world_seed = Data.WORLD_SEED_DEFAULT
		Data._randomize_river()
		lvl.build_now()
	if frames >= 21 and game.player != null and is_instance_valid(game.player):
		game.player.global_position = Vector3(-6.0, 0.0, Data.river_z(0.0) + 7.0)
		game.player.rotation.y = PI
	if frames == 200:
		pass
		cam = Camera3D.new()
		cam.fov = 50
		cam.far = 900
		root.add_child(cam)
		cam.global_position = Vector3(-75, 38, -30)
		cam.look_at(Vector3(5, 0, -112))
		cam.make_current()
	if frames == 9001:
		_shot("nu_overzicht_vallei.png")
		cam.global_position = Vector3(-30, 2.2, -78)
		cam.look_at(Vector3(10, 1.0, -160))
	if frames == 210:
		pass
		cam.global_position = Vector3(-75, 38, -30)
		cam.look_at(Vector3(5, 0, -112))
		flood = MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(380, 70)
		flood.mesh = pm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.36, 0.29, 0.18, 0.82)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.15
		flood.material_override = m
		root.add_child(flood)
		flood.global_position = Vector3(0, 0.5, -100)
	if frames == 290:
		_shot("proef_vlak_overstroomd.png")
	return frames > 295
