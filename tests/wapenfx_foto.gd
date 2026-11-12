extends SceneTree
## Wapeneffecten AAA: opnames van een schot met shotgun en pistool, met identieke camera, licht en seed.
## BJ_WFX=nieuw|klassiek, BJ_OUT=/map (standaard /tmp/wapenfx), BJ_WAPEN=trench|m1911|beide
## xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver vulkan --path . -s tests/wapenfx_foto.gd --fixed-fps 60

var main: Node
var game: Node
var frames := 0
var out := "/tmp/wapenfx"
var stand := "nieuw"
var wapens: Array = []
var step_t := 0   # frame waarop het huidige wapen schoot
var idx := 0
const NA := [2, 4, 7, 12, 24, 50]   # frames na het schot waarop een foto gemaakt wordt


func _initialize() -> void:
	OS.set_environment("BJ_TOUCH", "1")
	OS.set_environment("BJ_INSTANT", "1")
	out = OS.get_environment("BJ_OUT") if OS.get_environment("BJ_OUT") != "" else out
	stand = OS.get_environment("BJ_WFX") if OS.get_environment("BJ_WFX") != "" else stand
	var w := OS.get_environment("BJ_WAPEN")
	wapens = ["trench", "m1911"] if w in ["", "beide"] else [w]
	DirAccess.make_dir_recursive_absolute(out)
	GameSettings.set_value("wapenfx", stand)
	GameSettings.set_value("time", "day")
	GameSettings.set_value("weather", "clear")
	load("res://scripts/data.gd").set("mcv_autodeploy", true)   # niet in de bouwwagen beginnen
	seed(1897)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(func(): if frames > 3 and game != null: game.move = Vector2.ZERO)


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	var s := img.get_size()
	var crop := img.get_region(Rect2i(int(s.x * 0.18), int(s.y * 0.18), int(s.x * 0.64), int(s.y * 0.64)))
	crop.save_png("%s/%s_%s.png" % [out, stand, name])
	print("foto ", stand, " ", name)


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
	if frames >= 4:
		# bouwwagen en opbouw houden de camera bij het hoofdkwartier: weg ermee, de camera volgt dan de speler
		for n in get_nodes_in_group("mcv_opbouw"):
			n.queue_free()
		for g in ["mcv", "mcv_wagen"]:
			for n in get_nodes_in_group(g):
				n.queue_free()
		for n in root.find_children("*", "CanvasLayer", true, false):
			if (n as CanvasLayer).layer >= 0:
				(n as CanvasLayer).visible = false
		var cam := root.get_viewport().get_camera_3d()
		if cam != null:
			cam.set("_opbouw_weight", 0.0)
		if game.state == "prep":
			game.prep_t = 1e9
	if frames == 8:
		for a in get_nodes_in_group("atmosphere"):
			a.apply_settings()
		game.owned["trench"] = {"up": {"dmg": 0, "rate": 0, "mag": 0, "rel": 0}, "ammo": 60}
		game.loadout.append("trench")
	if frames == 60:
		var p = game.player
		p.global_position = Vector3(0.0, 0.0, -40.0)
		p.face = PI * 0.5
	if frames >= 100:
		var p = game.player
		if idx >= wapens.size():
			quit()
			return false
		var id: String = wapens[idx]
		if step_t == 0:
			p.equip(id)
			p.fire_t = 0.0
			p.reload_t = 0.0
			p.ammo = 50
			p.m1911_chambered = true
			p.m1911_mag_rounds = 7
			p.face = PI * 0.5
			step_t = frames + 40   # even laten bijkomen na het wisselen
			if id == "trench":
				var e = load("res://scenes/enemy.tscn").instantiate()
				e.setup("knife", 1)
				main.add_child(e)
				e.global_position = p.global_position + Vector3(7.0, 0.0, 0.0)
		elif frames == step_t:
			p.fire_t = 0.0
			p.reload_t = 0.0
			p.face = PI * 0.5
			p._shoot(Data.WEAPONS[id])
		elif frames > step_t:
			var k := frames - step_t
			if k in NA:
				_shot("%s_%02d" % [id, k])
			if k > NA[NA.size() - 1]:
				idx += 1
				step_t = 0
	return false
