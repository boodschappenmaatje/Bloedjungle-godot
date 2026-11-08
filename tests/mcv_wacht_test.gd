extends SceneTree
## Test van MCV stap 4a: wachten bij de kazerne (250, hooguit 4), ronde langs de binnenkant van de muur, bij een aanval naar de poort aan de kant van de aanval.
## godot --headless --path . --script tests/mcv_wacht_test.gd --fixed-fps 60

var D: GDScript
var M: GDScript
var K: GDScript
var W: GDScript
var main: Node
var frames := 0
var fails := 0
var mcv: Node
var ring := []
var kz: Dictionary
var guards: Array = []
var gate_n: Dictionary
var gate_s: Dictionary
var enemy: Node
var spawn_pos: Array = []


func _initialize() -> void:
	D = load("res://scripts/data.gd")
	M = load("res://scripts/mcv.gd")
	K = load("res://scripts/kampmuur.gd")
	W = load("res://scripts/wachten.gd")
	D.set("mcv_mode", true)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


func _bm() -> Node:
	for c in main.get_node("Hud").get_children():
		if c.has_method("_enter") and c.has_method("_exit") and c.get("_ui") != null:
			return c
	return null


func _buttons(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Button:
			out.append(c)
		_buttons(c, out)


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
		# zonder omheining: een cirkel van 14 m rond het hoofdkwartier
		var r: Array = W.patrol_route()
		var ok := r.size() == 8
		for p in r:
			if absf(Vector2(p.x - 40.0, p.z - 40.0).length() - 14.0) > 0.01:
				ok = false
		_check("zonder omheining loopt de ronde een cirkel van 14 m rond het hoofdkwartier", ok)
		# omheining rond het hoofdkwartier (kies er een zonder vat in de weg)
		var rings := [[5, 5, 19, 19], [4, 5, 19, 19], [5, 4, 19, 19], [5, 5, 20, 19], [5, 5, 19, 20], [4, 4, 20, 20]]
		var path: Array = []
		for rg in rings:
			var cand: Array = [Vector2i(rg[0], rg[1])]
			for v in [Vector2i(rg[2], rg[1]), Vector2i(rg[2], rg[3]), Vector2i(rg[0], rg[3]), Vector2i(rg[0], rg[1])]:
				K.extend(cand, v)
			if int(K.plan(cand).built) == K.path_edges(cand).size():
				path = cand
				ring = rg
				break
		_check("een vrije omheining gevonden", not path.is_empty())
		var res: Dictionary = K.build(path)
		_check("omheining gebouwd", int(res.skipped) == 0 and K.enclosed())
		# twee poorten: noord (rij ring[1]) en zuid (rij ring[3])
		var rn: Dictionary = K.place_gate(K.edge_key(Vector2i(11, ring[1]), Vector2i(12, ring[1])), K.vertex(Vector2i(12, ring[1])))
		var rs: Dictionary = K.place_gate(K.edge_key(Vector2i(11, ring[3]), Vector2i(12, ring[3])), K.vertex(Vector2i(12, ring[3])))
		_check("noordpoort en zuidpoort geplaatst", rn.ok and rs.ok and g.gates.list.size() == 2)
		for gt in g.gates.list:
			if gt.at.z < 40.0:
				gate_n = gt
			else:
				gate_s = gt
		_check("de omheining blijft compleet met twee poorten", K.enclosed())
		# een kazerne binnen de omheining (gratis geplaatst), deur naar het zuiden, klaar
		var kspot := Vector3(26.0, 0.0, 40.0)
		for cs in [Vector3(26, 0, 40), Vector3(26, 0, 30), Vector3(26, 0, 50), Vector3(28, 0, 56), Vector3(54, 0, 30), Vector3(56, 0, 52)]:   # een vat of dergelijks kan een plek blokkeren
			if g.builds.placement_status("kazerne", cs, 0.0).valid:
				kspot = cs
				break
		var kst: Dictionary = g.builds.placement_status("kazerne", kspot, 0.0)
		_check("kazerne-plek is vrij (%s)" % str(kst.reason), kst.valid)
		var b: Variant = g.builds.place("kazerne", kspot, 0.0, false, true)
		_check("kazerne binnen de omheining", b != null)
		if b != null:
			kz = b
	if frames == 24 and not kz.is_empty():
		var pts0: int = g.points
		var first = g.builds.buy_wacht(kz)
		_check("een wacht kopen kost 250", first != null and pts0 - g.points == 250)
		_check("hij hoort niet bij je team (niet in Game.allies) en staat in de groep 'wacht'", not g.allies.has(first) and get_nodes_in_group("wacht").size() == 1)
		guards.append(first)
		for i in 3:
			var w = g.builds.buy_wacht(kz)
			if w != null:
				guards.append(w)
		_check("vier wachten", guards.size() == 4 and g.builds.wachten_of(kz).size() == 4)
		var pts1: int = g.points
		_check("een vijfde wordt geweigerd en kost niets", g.builds.buy_wacht(kz) == null and g.points == pts1 and not g.builds.can_buy_wacht(kz))
		var slots := {}
		for w in guards:
			slots[w.wacht_slot] = true
		_check("vier verschillende plekken in de ronde", slots.size() == 4)
		# het kazernepaneel heeft de knop Wacht (en hij is nu uit: 4 van 4)
		var bm := _bm()
		bm._enter()
		bm._sel = kz
		bm._fill_panel()
		var btns: Array = []
		_buttons(bm.get("_panel"), btns)
		var wacht_btn = null
		for bt in btns:
			if bt.text.begins_with("Wacht"):
				wacht_btn = bt
		_check("het kazernepaneel heeft de knop Wacht (%s)" % (wacht_btn.text.replace("\n", " ") if wacht_btn != null else "ontbreekt"), wacht_btn != null and wacht_btn.text.contains("4/4"))
		_check("en hij is uit bij 4 van 4", wacht_btn != null and wacht_btn.disabled)
		bm._exit()
		var route: Array = W.patrol_route()
		print("ronde: ", route.size(), " punten")
		# de ronde ligt binnen de omheining en dicht bij de muur
		var minx: float = ring[0] * 3.5
		var maxx: float = ring[2] * 3.5
		var minz: float = ring[1] * 3.5
		var maxz: float = ring[3] * 3.5
		var inside := route.size() >= 8
		var near_wall := true
		for p in route:
			if p.x <= minx or p.x >= maxx or p.z <= minz or p.z >= maxz:
				inside = false
			var edge_d := minf(minf(p.x - minx, maxx - p.x), minf(p.z - minz, maxz - p.z))
			if edge_d > 2.6:
				near_wall = false
		_check("de ronde ligt binnen de muur", inside)
		_check("en dicht langs de binnenkant ervan (binnen 2,6 m)", near_wall)
		for w in guards:
			spawn_pos.append(w.global_position)
	if frames == 330:
		# ze lopen hun ronde (rustig, in de pauze) en blijven binnen de muur
		var minx: float = ring[0] * 3.5
		var maxx: float = ring[2] * 3.5
		var minz: float = ring[1] * 3.5
		var maxz: float = ring[3] * 3.5
		var moved := 0
		var inside := true
		for i in guards.size():
			var w = guards[i]
			if w.global_position.distance_to(spawn_pos[i]) > 3.0:
				moved += 1
			var p: Vector3 = w.global_position
			if p.x < minx or p.x > maxx or p.z < minz or p.z > maxz:
				inside = false
		_check("de wachten lopen hun ronde (%d van 4 zijn van hun plek)" % moved, moved >= 3)
		_check("en blijven binnen de muur", inside)
		# aanval vanuit het noorden: naar de noordpoort, aan de binnenkant
		g.state = "play"
		enemy = load("res://scenes/enemy.tscn").instantiate()
		enemy.setup("knife", 1)
		main.add_child(enemy)
		enemy.global_position = Vector3(42.0, 0.0, 0.0)
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		var np: Vector3 = W.alarm_post(guards[0])
		_check("aanval uit het noorden: de post ligt bij de noordpoort (%.1f van de poort)" % np.distance_to(gate_n.at), np.distance_to(gate_n.at) < 7.0 and np.z > gate_n.at.z)
		_check("en niet bij de zuidpoort", np.distance_to(gate_s.at) > 30.0)
		var posts := {}
		for w in guards:
			posts[snappedf(W.alarm_post(w).x, 0.1)] = true
		_check("de vier wachten staan naast elkaar, niet op één punt", posts.size() == 4)
		# aanval uit het zuiden
		enemy.global_position = Vector3(42.0, 0.0, 90.0)
		var sp: Vector3 = W.alarm_post(guards[0])
		_check("aanval uit het zuiden: de post ligt bij de zuidpoort, aan de binnenkant", sp.distance_to(gate_s.at) < 7.0 and sp.z < gate_s.at.z)
		# zonder poort aan die kant: aan de binnenkant van de muur aan de kant van de aanval
		g.gates.remove_gate(gate_s)
		var wp: Vector3 = W.alarm_post(guards[0])
		var d_n: float = wp.distance_to(gate_n.at)
		_check("zonder zuidpoort: nog altijd een post, binnen de omheining (%s)" % str(wp), wp.z < ring[3] * 3.5 and wp.z > ring[1] * 3.5)
		print("post zonder zuidpoort: ", wp, " afstand tot noordpoort ", d_n)
		# een verkochte kazerne neemt zijn wachten mee
		g.builds.remove(kz)
	if frames == 336:
		var alive := 0
		for w in guards:
			if is_instance_valid(w) and not w.is_queued_for_deletion():
				alive += 1
		_check("een verkochte kazerne neemt zijn wachten mee", alive == 0)
		print("klaar, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false
