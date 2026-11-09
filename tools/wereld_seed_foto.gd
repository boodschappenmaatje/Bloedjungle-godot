extends SceneTree
## Voor/na-opnames van de jungle-strook (tussen basismuur en rivier), in de echte spelcamera op dezelfde plek:
## eerst de vaste standaard-seed (het huidige, onveranderde spel), daarna twee willekeurige wereld-seeds, zodat
## Dennis het verschil ziet (open plekken, bosjes, stammen, rotsen, munitiekisten). WERELD_OUT = uitvoermap.
## BJ_TOUCH=1 xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver vulkan --path . -s tools/wereld_seed_foto.gd --resolution 1280x720 --fixed-fps 60

var main: Node
var game: Node
var lvl: Node3D
var out := "/tmp/wereldfoto"
var frames := 0
var spot := Vector3(14.0, 0.0, -52.0)   # vaste plek middenin de jungle-strook (tussen muur en rivier), voor elke opname gelijk
# [opnamemoment (frame), seed (-1 = vaste standaard, dus geen rebuild nodig), bestandsnaam]
var shots := [[90, -1, "voor_standaard.png"], [190, 4242, "na_seed_4242.png"], [290, 99001, "na_seed_99001.png"]]


func _initialize() -> void:
	if OS.get_environment("WERELD_OUT") != "":
		out = OS.get_environment("WERELD_OUT")
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		Data.mcv_autodeploy = true   # meteen uitgeklapt hoofdkwartier, speler loopt meteen (geen MCV-intro in de opname)
		main.begin()
		game = root.get_node("Game")
		lvl = main.get_node("Level")
		for m in get_nodes_in_group("menus"):
			m._show("")
		for n in root.find_children("*", "", true, false):
			if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
				n.set_process(false)
	if frames == 15:
		# de bouwwagen houdt de camera tijdens het wegrijden/uitklappen ver uitgezoomd op het voorterrein (OPBOUW_DISTANCE/
		# MCV_DISTANCE, zie camera_rig.gd); voor deze opnamen van de jungle zelf laten we de camera meteen normaal inzoomen
		# op de speler, net zoals na afloop van die opbouw-animatie vanzelf gebeurt.
		for g in ["mcv", "mcv_opbouw"]:
			for n in get_nodes_in_group(g):
				n.remove_from_group(g)
	for s in shots:
		var at: int = s[0]
		var seed_: int = s[1]
		var name: String = s[2]
		if frames == at - 90 and seed_ != -1:
			Data.world_seed = seed_
			lvl.build_now()
		if frames >= at - 60 and frames < at and game.player != null and is_instance_valid(game.player):
			game.player.global_position = spot   # elk beeld opnieuw zetten: voorkomt een race met het uitklappen van de wagen
			game.player.rotation.y = PI   # richting noord, de jungle in
		if frames == at:
			root.get_viewport().get_texture().get_image().save_png(out + "/" + name)
			print("opname ", name, " (seed ", (seed_ if seed_ != -1 else Data.WORLD_SEED_DEFAULT), ")")
	return frames > (shots[-1][0] as int) + 5
