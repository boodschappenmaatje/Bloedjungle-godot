extends SceneTree
## Props in de echte spelcamera: de zandzakrijen langs de muur, een zandzakmuur van de verdediging en de voorraadhoek met kisten.
## BJ_TOUCH=1 PROPS_OUT=/tmp/propsfoto xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver vulkan --path . -s tests/props_foto.gd --resolution 1280x590 --fixed-fps 60
var main: Node
var game: Node
var frames := 0
var out := "/tmp/propsfoto"
# naam, speler, kijkrichting
const SPOTS := [["zandzakken", Vector3(-24.0, 0, 5.5), PI / 2.0], ["voorraad", Vector3(-20.5, 0, -19.0), PI], ["verdediging", Vector3(-12.0, 0, 6.0), PI]]


func _initialize() -> void:
	if OS.get_environment("PROPS_OUT") != "":
		out = OS.get_environment("PROPS_OUT")
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	game = root.get_node("Game")


func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		main.begin()
		for m in get_nodes_in_group("menus"):
			m._show("")
		for n in root.find_children("*", "", true, false):
			if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
				n.set_process(false)
		var wall := Node3D.new()
		wall.position = Vector3(-12.0, 0, 2.5)
		main.add_child(wall)
		(load("res://scripts/defenses.gd") as GDScript).new()._bag_wall(wall)
	var k := frames - 60
	if k >= 0 and k % 80 == 0 and k / 80 < SPOTS.size():
		var s: Array = SPOTS[k / 80]
		game.player.global_position = s[1]
		game.player.face = s[2]
	if k >= 60 and (k - 60) % 80 == 0 and (k - 60) / 80 < SPOTS.size():
		root.get_viewport().get_texture().get_image().save_png("%s/props_%s.png" % [out, SPOTS[(k - 60) / 80][0]])
	return frames > 60 + 80 * 3 + 5
