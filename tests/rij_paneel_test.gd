extends SceneTree
## Opent het bouwscherm met een kazerne geselecteerd en controleert dat het paneel (rij, vlag) opbouwt.
## godot --headless --path . -s tests/rij_paneel_test.gd --fixed-fps 60
var main: Node
var _build_mode: Script
var frames := 0
var kz: Variant


func _initialize() -> void:
	_build_mode = load("res://scripts/build_mode.gd")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frames += 1
	var g = root.get_node("Game")
	if frames == 2:
		main.get_node("Hud/Sticks").set_process(false)
	if frames == 4:
		main.begin()
	if frames == 8:
		var bm = main.get_node("Hud").get_children().filter(func(n): return n.get_script() == _build_mode)[0]
		bm._enter()
		g.points = 5000
		kz = g.builds.place("kazerne", Vector3(-6, 0, -8), PI)
		kz.lv = 2
		g.builds.recruit(kz)
		g.builds.recruit(kz)
		bm._sel = kz
		bm._fill_panel()
		var knoppen: Array = bm.find_children("*", "Button", true, false).map(func(b): return b.text)
		print("knoppen: ", knoppen)
		var ok: bool = knoppen.any(func(t): return t.begins_with("Vlag")) and knoppen.any(func(t): return t.begins_with("Nieuwe:")) and knoppen.count("■") == 2
		print("PANEEL ", "OK" if ok else "FOUT")
		quit(0 if ok else 1)
	return false
