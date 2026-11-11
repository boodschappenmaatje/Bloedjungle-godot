extends SceneTree
## Jeep en tank vinden zelf de poort in jouw muur (voertuigbevel, 11 nov 2026): een bevel naar binnen (of naar buiten) rijdt om de muur heen en door de poort, en de poort opent voor het voertuig
## (Gates, 16 m). Opstelling zoals tests/soldaat_poort_test.gd.
## godot --headless --path . --script tests/voertuig_poort_test.gd --fixed-fps 60

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


var jeep: Node
var tank: Node
var bj: Node
var bt: Node
var gz := 66.5
var opened := false


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
		gz = float(zrow) * 3.5
		jeep = load("res://scenes/jeep.tscn").instantiate()
		g.player.get_parent().add_child(jeep)
		tank = load("res://scenes/tank.tscn").instantiate()
		g.player.get_parent().add_child(tank)
		# de jeep staat buiten de muur (zuid) en wil naar binnen, de tank staat binnen en wil naar buiten
		jeep.global_position = Vector3(46.0, 0.0, gz + 14.0)
		tank.global_position = Vector3(34.0, 0.0, 46.0)
		tank.rotation.y = 0.0
		g.player.global_position = Vector3(10.0, 0.0, 10.0)
	if frames == 28:
		bj = jeep.get_node("Bestuurder")
		bt = tank.get_node("Bestuurder")
		bj.set_command("move", Vector3(40, 0, 44))
		bt.set_command("move", Vector3(44, 0, gz + 16.0))
	if frames > 28 and g.gates.list.size() > 0 and g.gates.list[0].open > 0.5:
		opened = true
	if frames > 28 and frames % 180 == 0:
		print(frames, " poort open=", g.gates.list[0].open, " jeep ", jeep.global_position.snapped(Vector3(0.1, 0.1, 0.1)), " tank ", tank.global_position.snapped(Vector3(0.1, 0.1, 0.1)))
	if frames == 2400:
		_check("de poort is opengegaan voor een voertuig", opened)
		_check("de jeep is door de poort naar binnen gereden (%s)" % str(jeep.global_position), jeep.global_position.z < gz - 3.0 and jeep.global_position.z > 20.0 and not bj.vast)
		# de tank steekt de poort over en zoekt buiten de muur zelf een weg tussen bomen, stammen en rotsen door (de routezoeker): hij komt aan en meldt niet VAST
		_check("de tank is door de poort naar buiten gereden (%s)" % str(tank.global_position), tank.global_position.z > gz + 3.0)
		_check("de tank staat bij zijn doel buiten de muur (%.1f m) en is niet vast" % Vector2(tank.global_position.x - 44.0, tank.global_position.z - (gz + 16.0)).length(), Vector2(tank.global_position.x - 44.0, tank.global_position.z - (gz + 16.0)).length() < 8.0 and not bt.vast)
		print("klaar, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false
