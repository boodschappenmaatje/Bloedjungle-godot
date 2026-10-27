extends SceneTree
## Voor/na-foto's van de mannetjes met de echte spelcamera en spelbelichting: bovenste rij het oude model (v1), onderste rij
## VQ2, elke kolom dezelfde rol (eigen, speler bloot/vest, vijand mes/geweer/raket/zwaar). Daarna een tweede foto met
## de spelcamera dichterbij (zoals bij inzoomen) en een foto terwijl ze lopen.
## xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path . -s tests/soldaat_foto.gd --fixed-fps 60
## Uitvoer: OUT/soldaat_*.png (OUT = omgevingsvariabele SOLDAAT_OUT, standaard /tmp/soldaatfoto)

var main: Node
var game: Node
var frames := 0
var out := "/tmp/soldaatfoto"
var models: Array[SoldierModel] = []
const ROLES := [
	["eigen", "4b5a2c", "garand"], ["speler:bloot", "4b5a2c", "garand"], ["speler:vest", "4b5a2c", "thompson"],
	["vijand:knife", "4c5056", ""], ["vijand:rifle", "8c7b52", "rifle"], ["vijand:rocket", "5a4a3a", "rocket"],
	["vijand:heavy", "3e4a2b", "heavy"],
]


func _initialize() -> void:
	if OS.get_environment("SOLDAAT_OUT") != "":
		out = OS.get_environment("SOLDAAT_OUT")
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("%s/soldaat_%s.png" % [out, name])
	print("foto ", name)


func _spawn() -> void:
	var player: Node3D = game.get("player")
	player.global_position += Vector3(0, 0, 12)     # weg van de bunker, op open grond; de camera volgt
	var base := player.global_position
	player.visible = false
	for row in 2:
		GameSettings.values["soldaat"] = "v1" if row == 0 else "vq2"
		for i in ROLES.size():
			var r: Array = ROLES[i]
			var m := SoldierModel.new()
			game.add_child(m)
			m.setup(Color(r[1]), r[2], r[0])
			if r[0].begins_with("speler"):
				m.set_band(Color("c0140f"))
			m.scale = Vector3.ONE * Data.SOLDIER_SCALE * (1.28 if r[0] == "vijand:heavy" else 1.0)
			m.global_position = base + Vector3((i - 3) * 1.9, 0.0, -1.7 + row * 3.4)
			m.rotation.y = PI + 0.5
			models.append(m)
	GameSettings.values["soldaat"] = "vq2"


func _process(_d: float) -> bool:
	frames += 1
	game = root.get_node("Game")
	if frames == 3:
		main.begin()
		for n in root.find_children("*", "", true, false):
			if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
				n.set_process(false)
		for m in get_nodes_in_group("menus"):
			m._show("")
		GameSettings.set_value("time", "day")
		for a in get_nodes_in_group("atmosphere"):
			a.apply_settings()
	if frames == 12:
		_spawn()
	if frames == 70:
		_shot("spelcamera")
	if frames == 72:
		var cam := root.get_viewport().get_camera_3d()
		cam.fov = cam.fov * 0.45
	if frames == 80:
		_shot("ingezoomd")
	if frames == 82:
		for m in models:
			m.play("lopen", 0.0)
	if frames == 91:
		_shot("lopen")
	if frames == 92:
		for m in models:
			m.play("schieten", 0.0)
			m.set_shoot_pose(true, "garand", 0.3)
	if frames == 100:
		_shot("schieten")
		quit(0)
	return false
