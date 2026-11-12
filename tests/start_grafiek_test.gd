extends SceneTree
## Na het starten van een spel staat de grafiek zoals gekozen, ook voor het gras dat pas bij "Start" gebouwd wordt (v226).
## Dennis zag bij het opstarten minder gras dan nadat hij in Instellingen wisselde: Atmosphere paste de instellingen alleen toe
## toen de jungle er nog niet stond.
## godot --headless --path . --script tests/start_grafiek_test.gd --fixed-fps 60

var main: Node
var frames := 0
var fails := 0


func _initialize() -> void:
	load("res://scripts/data.gd").set("mcv_autodeploy", true)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		# op het toestel bouwt "Start" de jungle pas ná het opstarten van Atmosphere: bouw het gras hier dus opnieuw
		for f in get_nodes_in_group("grass_fields"):
			f.remove_from_group("grass_fields")
			for n in f.find_children("*", "MultiMeshInstance3D", true, false):
				n.remove_from_group("foliage_grass")
			f.queue_free()
		var nieuw: Node3D = load("res://scripts/grass_field.gd").spawn(main.get_node("Level"), [])
		nieuw.name = "GrasNaOpstart"
		var echt := 0
		for n in get_nodes_in_group("foliage_grass"):
			if int(n.get_meta("full")) != (n as MultiMeshInstance3D).multimesh.visible_instance_count:
				echt += 1
		print("voor Start: %d gras-knopen met minder dan de volle hoeveelheid" % echt)
		main.begin()
		return false
	if frames == 4:
		return false
	var grass := get_nodes_in_group("foliage_grass")
	if frames < 5:
		return false
	print("gras gebouwd op beeld %d" % frames)
	_check("er is gras gebouwd", grass.size() > 0)
	var af := 0
	var te_weinig := 0
	for n in grass:
		var mm: MultiMesh = (n as MultiMeshInstance3D).multimesh
		af += 1
		if mm.visible_instance_count != int(n.get_meta("full")):
			te_weinig += 1
	_check("alle gras toont de volle hoeveelheid van Graphics 2.0 direct na Start (%d van %d wijkt af)" % [te_weinig, af], te_weinig == 0)
	print("klaar, fouten: %d" % fails)
	quit(1 if fails > 0 else 0)
	return true
