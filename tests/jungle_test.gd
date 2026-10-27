extends SceneTree
## Test: palmen en rotsen komen uit assets/jungle.glb (3 vormen + verre palmen), met schors, blad en steen.
## Draaien: godot --headless --path . -s tests/jungle_test.gd --fixed-fps 60

var main: Node
var frames := 0
var fails := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		push_error("JUNGLE TEST FAIL: " + msg)


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		main.begin()
	if frames == 200:
		var fol: GDScript = load("res://scripts/foliage.gd")
		for n in ["Palm1", "Palm2", "Palm3", "Palm1_far", "Palm2_far", "Palm3_far", "Rots1", "Rots2", "Rots3"]:
			var m: Mesh = fol.call("jungle_mesh", n)
			_check(m != null, n + " ontbreekt in jungle.glb")
			if n.begins_with("Palm") and m:
				_check(m.get_surface_count() == 2, n + ": stam en kroon als twee oppervlakken")
				_check(m.surface_get_material(0) is ShaderMaterial and m.surface_get_material(1) is ShaderMaterial, n + ": schors- en bladmateriaal")
		var used := {}
		for g in ["foliage_palm", "foliage_rock"]:
			for mi in get_nodes_in_group(g):
				if mi is MultiMeshInstance3D and mi.multimesh.instance_count > 0:
					used[mi.multimesh.mesh.get_aabb().size.snapped(Vector3(0.001, 0.001, 0.001))] = true
		_check(used.size() >= 9, "alle 9 vormen (3 palmen, 3 verre palmen, 3 rotsen) staan in de jungle, nu %d" % used.size())
		var bark: ShaderMaterial = fol.call("material", "bark")
		_check(bark.get_shader_parameter("tile") == true, "schors herhaalt zich")
		# stammen en rotsen houden speler, kogels en voertuigen tegen
		var game := root.get_node("Game")
		var space := main.get_viewport().world_3d.direct_space_state
		for imp in ["wood", "concrete"]:
			var o := Vector3.ZERO
			for b in root.find_children("*", "StaticBody3D", true, false):
				if b.collision_layer == 128 and b.get_meta("impact_material", "") == imp and b.get_child_count() > 0:
					o = (b.get_child(0) as Node3D).position
					break
			_check(o != Vector3.ZERO, imp + ": geen botsvormen in de jungle")
			var from := Vector3(o.x - 4.0, 1.0, o.z)
			var q := PhysicsRayQueryParameters3D.create(from, Vector3(o.x, 1.0, o.z), 128)
			_check(not space.intersect_ray(q).is_empty(), imp + ": kogel gaat dwars door de stam of rots")
			var p: CharacterBody3D = game.player
			_check(p.test_move(Transform3D(Basis.IDENTITY, Vector3(o.x - 4.0, 0.0, o.z)), Vector3(8.0, 0, 0)), imp + ": speler loopt dwars door de stam of rots")
			_check((p.collision_mask & 128) != 0, "speler botst niet op laag natuur")
		for sc in ["res://scenes/enemy.tscn", "res://scenes/tank.tscn", "res://scenes/jeep.tscn"]:
			var inst := (load(sc) as PackedScene).instantiate()
			_check((inst.collision_mask & 128) != 0, sc + " botst niet op laag natuur")
			inst.free()
		print("jungle vormen in gebruik: ", used.size())
		if fails == 0:
			print("JUNGLE TEST OK")
		quit(1 if fails > 0 else 0)
	return false
