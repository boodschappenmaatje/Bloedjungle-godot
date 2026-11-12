extends SceneTree
## Voor/na-opnames van de rivier (kronkel + doorwaadplaats), in de echte spelcamera op dezelfde plek, recht op de rivier
## kijkend: eerst de vaste standaard-seed (het huidige, onveranderde spel), daarna twee willekeurige wereld-seeds, zodat
## Dennis het verschil ziet (andere kronkel, doorwaadplaats op een andere plek). WERELD_OUT = uitvoermap.
## BJ_TOUCH=1 xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver vulkan --path . -s tools/rivier_seed_foto.gd --resolution 1280x720 --fixed-fps 60

var main: Node
var game: Node
var lvl: Node3D
var out := "/tmp/rivierfoto"
var frames := 0
const SOUTH_OF_RIVER := 3.0   # altijd dit ver ten zuiden van Data.river_z(0.0), welke kronkel het ook is
# [opnamemoment (frame), seed (-1 = vaste standaard, dus geen rebuild nodig), bestandsnaam]
var shots := [[400, -1, "voor_standaard.png"], [650, 4242, "na_seed_4242.png"], [900, 99001, "na_seed_99001.png"]]


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
		for g in ["mcv_opbouw"]:   # "mcv" blijft expres staan: forceert een bredere camera (MCV_DISTANCE) zodat de rivier goed in beeld komt
			for n in get_nodes_in_group(g):
				n.remove_from_group(g)
	if frames == 20:
		# main.begin() koos hierboven zelf al een willekeurige seed (niet-headless draait altijd dat pad); voor
		# "voor_standaard" moeten we dus net zo goed expliciet terug naar de vaste standaard en herbouwen.
		Data.world_seed = Data.WORLD_SEED_DEFAULT
		Data._randomize_river()
		lvl.build_now()
	# vanaf frame 21 de speler elk beeld opnieuw bij de brug zetten, ruim vóór elke opname: geeft de camera
	# (die geleidelijk naar de speler toe beweegt) alle tijd om daadwerkelijk bij de rivier aan te komen.
	if frames >= 21 and game.player != null and is_instance_valid(game.player):
		game.player.global_position = Vector3(0.0, 0.0, Data.river_z(0.0) + SOUTH_OF_RIVER)
		game.player.rotation.y = PI   # richting noord, de rivier in
	for s in shots:
		var at: int = s[0]
		var seed_: int = s[1]
		var name: String = s[2]
		if frames == at - 150 and seed_ != -1:
			Data.world_seed = seed_
			Data._randomize_river()
			lvl.build_now()
		if frames == at:
			root.get_viewport().get_texture().get_image().save_png(out + "/" + name)
			print("opname ", name, " (seed ", (seed_ if seed_ != -1 else Data.WORLD_SEED_DEFAULT), ", FORD_X=", Data.FORD_X, ")")
	return frames > (shots[-1][0] as int) + 5
