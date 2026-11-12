extends SceneTree
## Het wegdek van een depot in een omheining: de weg loopt van het depot door de poort (en erbuiten verder), en "Draai" slaat een stand over waar de uitrit
## tegen een muur zou komen (anders bleef je steken op dezelfde geweigerde stand).
## godot --headless --path . --script tests/voorraad_weg_test.gd --fixed-fps 60
var main: Node
var frames := 0
var fails := 0
var depot: Dictionary
var gate_at := Vector2.ZERO


func _initialize() -> void:
	root.size = Vector2i(932, 430)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


func _process(_d: float) -> bool:
	frames += 1
	var g = root.get_node("Game")
	var K = load("res://scripts/kampmuur.gd")
	if frames == 2:
		main.get_node("Hud/Sticks").set_process(false)
	if frames == 4:
		main.begin()
	if frames > 4 and g.state == "prep":
		g.prep_t = 1e9
	if frames == 20:
		g.points = 9000
		g.build_credit = 9000
		var r: Dictionary = K.build(K.rect_path(Vector2i(-12, -12), Vector2i(12, 12)))
		_check("omheining gebouwd (%d)" % int(r.built), int(r.built) > 0 and K.enclosed())
		var res: Dictionary = K.place_gate(K.edge_key(Vector2i(0, -12), Vector2i(1, -12)), K.vertex(Vector2i(1, -12)))
		_check("poort in de noordmuur", res.ok)
		gate_at = Vector2(g.gates.list[0].at.x, g.gates.list[0].at.z)
		# een depot in de noordoosthoek met de voorkant naar het zuiden: de stapels liggen in het noorden, buiten de poort
		var b = g.builds.place("depot", Vector3(30.0, 0.0, -34.0), 0.0, true)
		_check("depot staat", b != null)
		if b == null:
			quit(1)
			return false
		depot = b
		b.build_t = 0.05
	if frames == 60:
		var sup = g.supply
		var branches: Array = sup.road_branches(depot)
		_check("er is minstens één weg", not branches.is_empty())
		var through := false
		for br: Array in branches:
			for q: Vector2 in br:
				if q.distance_to(gate_at) < 1.5:
					through = true
		_check("de weg loopt door de poort", through)
		var starts_ok := true
		for br: Array in branches:
			if (br[0] as Vector2).distance_to(sup.dock_point(depot)) > 0.01:
				starts_ok = false
		_check("elke weg begint bij het dock", starts_ok)
		# het wegdek zelf (de vlakken) komt tot in de poort
		var near_gate := false
		var tris := 0
		for n in get_nodes_in_group("uitrit"):
			var arr = ((n as MeshInstance3D).mesh as ArrayMesh).surface_get_arrays(0)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			tris += v.size() / 3
			for p in v:
				if Vector2(p.x, p.z).distance_to(gate_at) < 3.0:
					near_gate = true
		_check("het wegdek heeft vlakken (%d)" % tris, tris > 100)
		_check("het wegdek komt tot in de poort", near_gate)
		# draaien: de stand naar het oosten (muur 5 m ervoor) en naar het noorden (muur 1 m ervoor) kunnen niet; hij gaat door naar het westen
		var seen: Array = []
		for i in 4:
			var ok: bool = g.builds.turn(depot)
			seen.append(snappedf(rad_to_deg(depot.yaw), 1.0))
			_check("draaien lukt (stand %d, %s graden)" % [i + 1, str(seen[i])], ok)
		print("  standen: ", seen)
		_check("de eerste draai slaat de geblokkeerde standen over (naar 270 graden)", is_equal_approx(float(seen[0]), 270.0))
		_check("hij blijft niet steken op dezelfde stand", float(seen[0]) != float(seen[1]) and float(seen[1]) != float(seen[2]))
		print("klaar, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false
