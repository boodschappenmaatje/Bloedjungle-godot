extends SceneTree
## Schermafbeeldingen van de slimme vijandaanval (v230): de groep gehurkt in een waaier op het verzamelpunt, het rookgordijn en de rode lichtkogel bij het begin
## van de aanval (met de melding CONTACT en de lijn op de radar), vuur en beweging, en een groep die door de smalle Backdoor de rivier oversteekt.
## FOTO_DIR=/pad xvfb-run -a -s "-screen 0 932x430x24" godot --rendering-driver opengl3 --path . -s tests/aanval_ai_foto.gd --resolution 932x430 --fixed-fps 60

var main: Node
var frames := 0
var game: Node
var ai: Node
var AI: GDScript
var dir := OS.get_environment("FOTO_DIR") if OS.get_environment("FOTO_DIR") != "" else "/tmp"
var g: Dictionary
var leden: Array = []
var bd: Dictionary
var bd_leden: Array = []
var kijk := Vector3.ZERO
const KANT := "W"
const A := 200   # begin van de opnames


func _initialize() -> void:
	load("res://scripts/data.gd").set("mcv_autodeploy", true)
	AI = load("res://scripts/aanval_ai.gd")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(func(): if frames > 3 and game != null: game.move = Vector2.ZERO)


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/na_%s.png" % [dir, name])
	print("foto ", name)


func _process(_d: float) -> bool:
	frames += 1
	game = root.get_node("Game")
	var p = game.player
	if frames == 3:
		main.begin()
		for n in root.find_children("*", "", true, false):
			if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
				n.set_process(false)
		for m in get_nodes_in_group("menus"):
			m._show("")
		GameSettings.set_value("time", "day")
	if frames > 3 and game.state == "prep":
		game.prep_t = 540.0
	if p != null and frames > 10:
		p.hp = 1000.0
	for o in get_nodes_in_group("mcv_opbouw"):
		o.remove_from_group("mcv_opbouw")
	if frames == 6:
		ai = get_first_node_in_group("aanval_ai")
		AI.set("aan", false)   # eerst stilzetten: de groep staat klaar voor de foto
		ai.fase = 2
		g = ai._maak_groep(3, "hoofd", KANT)
		var kinds := ["assault", "assault", "heavy", "assault", "rocket", "assault", "assault", "knife", "assault", "assault"]
		for k in kinds:
			main._spawn({"kind": k, "n": 3, "groep": g})
		leden = g.leden.duplicate()
		for i in leden.size():
			var e = leden[i]
			e.global_position = e.ai_hold
			e.path_i = 99
		g.staat = "verzamelen"
		g.wacht_t = 0.0
		# een tweede groep bij de Backdoor
		bd = ai._maak_groep(4, "hoofd", "W")
		bd.oversteek = "achterdeur"
		for i in 6:
			main._spawn({"kind": "assault", "n": 4, "groep": bd})
		bd_leden = bd.leden.duplicate()
		var dt := load("res://scripts/data.gd") as GDScript
		var rz: float = dt.river_z(dt.BACKDOOR_X)
		for i in bd_leden.size():
			var e = bd_leden[i]
			e.global_position = Vector3(dt.BACKDOOR_X + randf_range(-0.8, 0.8), 0, rz - 4.0 - i * 2.4)
			e.path = [Vector3(dt.BACKDOOR_X, 0, rz), Vector3(dt.BACKDOOR_X, 0, rz + 8.0), Vector3(dt.BACKDOOR_X + 20.0, 0, rz + 30.0)]
			e.path_i = 0
			e.set_physics_process(false)
	# 1: gehurkt in een waaier op het verzamelpunt
	var rally: Vector3 = ai.rally_van(KANT) if ai != null else Vector3.ZERO
	var naar_hk: Vector3 = (game.base_pos - rally).normalized() if ai != null else Vector3.ZERO
	if frames >= 8 and frames < A + 260:
		var afst := 14.0 if frames < A + 90 else (30.0 if frames >= A + 150 else 22.0)
		p.global_position = rally + naar_hk * afst + Vector3(0, 0, 2.0)
		p.face = atan2(-naar_hk.x, -naar_hk.z)
	if frames == A:
		_shot("verzamelen")
	# 2: de aanval begint: rookgranaat, lichtkogel, CONTACT
	if frames == A + 5:
		AI.set("aan", true)
	if frames == A + 75:
		_shot("rook_lichtkogel")
	if frames == A + 190:
		_shot("rookgordijn")
	if frames == A + 205:
		_shot("vuur_en_beweging")
	if frames == A + 245:
		var hud := get_first_node_in_group("hud_extra")
		if hud != null:
			hud.open_map(false)
	if frames == A + 270:
		_shot("kaart_contact")
		var hud := get_first_node_in_group("hud_extra")
		if hud != null and hud._map != null:
			hud._map.close_map()
	# 3: de Backdoor
	if frames == A + 280:
		var dt := load("res://scripts/data.gd") as GDScript
		var rz: float = dt.river_z(dt.BACKDOOR_X)
		for e in bd_leden:
			if is_instance_valid(e):
				e.set_physics_process(true)
		kijk = Vector3(dt.BACKDOOR_X + 6.0, 0, rz + 12.0)
	if frames > A + 280:
		p.global_position = kijk
		p.face = PI
	if frames == A + 420:
		_shot("backdoor")
	return frames > A + 425
