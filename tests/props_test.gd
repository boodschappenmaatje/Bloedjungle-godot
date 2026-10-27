extends SceneTree
## Test: zandzakken en kisten komen uit assets/props.glb (VQ2-materialen), de basis heeft een voorraadhoek met botsing.
## Draaien: godot --headless --path . -s tests/props_test.gd --fixed-fps 60
var main: Node
var frames := 0
var fails := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		push_error("PROPS TEST FAIL: " + msg)


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		main.begin()
	if frames == 60:
		var kit: GDScript = load("res://scripts/kit.gd")
		for n in ["Zandzak1", "Zandzak2", "Zandzak3", "Kist_Hout", "Kist_Munitie"]:
			var m: Mesh = kit.call("prop_mesh", n)
			_check(m != null and m.get_surface_count() >= 1, n + " ontbreekt in props.glb")
			var mat := m.surface_get_material(0) as StandardMaterial3D
			_check(mat != null and mat.resource_name.begins_with("VQ2_") and mat.albedo_texture != null, n + ": geen VQ2-textuur")
		var crates := 0
		var bags := 0
		for mi in main.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == kit.call("prop_mesh", "Kist_Hout") or mi.mesh == kit.call("prop_mesh", "Kist_Munitie"):
				crates += 1
		for mm in main.find_children("*", "MultiMeshInstance3D", true, false):
			for n in ["Zandzak1", "Zandzak2", "Zandzak3"]:
				if mm.multimesh.mesh == kit.call("prop_mesh", n):
					bags += mm.multimesh.instance_count
		_check(crates >= 8, "de voorraadhoek heeft kisten nodig (%d)" % crates)
		_check(bags >= 20, "de zandzakrijen langs de muur gebruiken de nieuwe zakken (%d)" % bags)
		# je loopt er niet doorheen
		var game := root.get_node("Game")
		var p: CharacterBody3D = game.player
		var c: float = (load("res://scripts/data.gd") as GDScript).get("COMPOUND")
		var at := Vector3(-c + 6.5, 0.0, -c + 5.5)
		_check(p.test_move(Transform3D(Basis.IDENTITY, at + Vector3(-3.0, 0.0, 0.0)), Vector3(6.0, 0, 0)), "speler loopt dwars door de kisten")
		print("props: kisten %d zandzakken %d" % [crates, bags])
		print("PROPS TEST ", "OK" if fails == 0 else "FOUT")
		quit(1 if fails > 0 else 0)
	return false
