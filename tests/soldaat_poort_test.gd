extends SceneTree
## Soldaten vinden zelf de poort in jouw muur (11 nov 2026): een bevel naar binnen (of naar buiten) loopt door de poort in plaats van tegen de muur.
## godot --headless --path . --script tests/soldaat_poort_test.gd --fixed-fps 60

var D: GDScript
var M: GDScript
var K: GDScript
var main: Node
var frames := 0
var fails := 0
var mcv: Node
var depot: Dictionary
var slot := -1
var points0 := 0
var gate_opened := false
var income_seen := false
var zrow := 19   # rij van de zuidmuur van de gekozen omheining


func _initialize() -> void:
	D = load("res://scripts/data.gd")
	M = load("res://scripts/mcv.gd")
	K = load("res://scripts/kampmuur.gd")
	D.set("mcv_autodeploy", false)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


var al: Array = []


func _process(_d: float) -> bool:
	frames += 1
	var g = root.get_node("Game")
	if frames == 2:
		main.get_node("Hud/Sticks").set_process(false)
	if frames == 4:
		main.begin()
	if frames > 4 and g.state == "prep" and g.mcv_deployed:
		g.prep_t = 1e9
	if frames == 12:
		mcv = get_nodes_in_group("mcv")[0]
		mcv.global_position = Vector3(40.0, 0.0, 40.0)
		mcv.rotation.y = 0.0
	if frames == 16:
		mcv.deploy_now()
	if frames == 20:
		var rings := [[5, 5, 19, 19], [4, 5, 19, 19], [5, 4, 19, 19], [5, 5, 20, 19], [5, 5, 19, 20], [4, 4, 20, 20]]
		var path: Array = []
		var chosen := []
		for rg in rings:
			var cand: Array = [Vector2i(rg[0], rg[1])]
			for v in [Vector2i(rg[2], rg[1]), Vector2i(rg[2], rg[3]), Vector2i(rg[0], rg[3]), Vector2i(rg[0], rg[1])]:
				K.extend(cand, v)
			var pl: Dictionary = K.plan(cand)
			if int(pl.built) == K.path_edges(cand).size():
				path = cand
				chosen = rg
				break
		zrow = chosen[3] if not chosen.is_empty() else 19
		_check("een vrije omheining gevonden", not path.is_empty())
		K.build(path)
		_check("de omheining is compleet", K.enclosed())
	if frames == 24:
		var k = K.edge_key(Vector2i(11, zrow), Vector2i(12, zrow))
		var res: Dictionary = K.place_gate(k, K.vertex(Vector2i(12, zrow)))
		_check("poort geplaatst (%s)" % str(res.reason), res.ok)
		var gz: float = float(zrow) * 3.5
		_check("binnen is binnen en buiten is buiten", K.inside(Vector3(40, 0, 40)) and not K.inside(Vector3(40, 0, gz + 12.0)))
		var wp: Variant = K.gate_waypoint(Vector3(55, 0, gz + 12.0), Vector3(40, 0, 40))
		_check("van buiten naar binnen is het eerste punt buiten de poort", wp != null and wp.z > gz and absf(wp.x - 42.0) < 0.5)
		_check("zelfde kant: rechtdoor", K.gate_waypoint(Vector3(40, 0, 30), Vector3(50, 0, 45)) == null)
		var script: GDScript = load("res://scripts/ally.gd")
		for i in 4:
			var a = script.new()
			a.kind = "geweer"
			g.player.get_parent().add_child(a)
			a.setup(100.0, 16.0, i)
			g.allies.append(a)
			al.append(a)
		# twee buiten de muur (één recht voor de poort, één ernaast) willen naar binnen, twee binnen willen naar buiten
		al[0].global_position = Vector3(42.0, 0.0, gz + 10.0)
		al[1].global_position = Vector3(58.0, 0.0, gz + 10.0)
		al[2].global_position = Vector3(30.0, 0.0, 45.0)
		al[3].global_position = Vector3(52.0, 0.0, 40.0)
		al[0].set_command("move", Vector3(40, 0, 45))
		al[1].set_command("move", Vector3(46, 0, 42))
		al[2].set_command("move", Vector3(44, 0, gz + 14.0))
		al[3].set_command("move", Vector3(60, 0, gz + 14.0))
	if frames > 24 and frames % 120 == 0 and not al.is_empty():
		print(frames, " poort open=", g.gates.list[0].open, " ", al.map(func(a): return a.global_position.snapped(Vector3(0.1,0.1,0.1))), " ", g.state)
	if frames == 700:
		var gz2: float = float(zrow) * 3.5
		for i in 2:
			_check("soldier %d is door de poort naar binnen gelopen (%s)" % [i, str(al[i].global_position)], K.inside(al[i].global_position))
		for i in range(2, 4):
			_check("soldier %d is door de poort naar buiten gelopen (%s)" % [i, str(al[i].global_position)], al[i].global_position.z > gz2 + 3.0)
		print("klaar, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false
