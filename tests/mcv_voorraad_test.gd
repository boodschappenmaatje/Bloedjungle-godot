extends SceneTree
## Test van MCV stap 2: gratis voorraaddepot (zelf neerzetten), eerste truck gratis, stapels zonder vast kamp, vrije route van het depot naar de stapel
## (rechtdoor, bomen weg, stapel draait mee, versperde weg), en een rit die geld oplevert.
## godot --headless --path . --script tests/mcv_voorraad_test.gd --fixed-fps 60

var D: GDScript
var M: GDScript
var F: GDScript
var main: Node
var frames := 0
var fails := 0
var mcv: Node
var depot: Dictionary
var slot := -1
var points0 := 0
var income_seen := false
var phase := 0


func _initialize() -> void:
	D = load("res://scripts/data.gd")
	M = load("res://scripts/mcv.gd")
	F = load("res://scripts/foliage.gd")
	D.set("mcv_mode", true)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


func _process(_d: float) -> bool:
	frames += 1
	var g = root.get_node("Game")
	var p = g.player
	if frames == 2:
		main.get_node("Hud/Sticks").set_process(false)
	if frames == 4:
		main.begin()
	if frames > 4 and g.state == "prep" and g.mcv_deployed:
		g.prep_t = 1e9   # geen vijandelijke groep tijdens deze test
	if frames == 12:
		var sup = g.supply
		var n := 0
		for s in sup.stapels:
			if s != null:
				n += 1
		_check("vier voorraadstapels liggen er al", n == 4)
		_check("nog geen depot of truck voor het uitklappen", sup.depots().is_empty() and get_nodes_in_group("voorraadtruck").is_empty())
		_check("bouwen kan nog niet voor het uitklappen", not g.builds.placement_status("depot", Vector3(60, 0, 40), 0.0).valid)
		mcv = get_nodes_in_group("mcv")[0]
		mcv.global_position = Vector3(40.0, 0.0, 40.0)
		mcv.rotation.y = 0.0
	if frames == 16:
		var st: Dictionary = M.site_status(mcv.global_position, mcv.rotation.y)
		_check("HK-plek (40, 40) is geldig (%s)" % str(st.reason), st.valid)
		mcv.deploy_now()
	if frames == 22:
		_check("na het uitklappen is er één gratis depot", g.free_depot == 1)
		_check("het gratis depot kost niets", g.builds.cost_of("depot") == 0)
		points0 = g.points
		var credit0: int = g.build_credit
		var at := Vector3(78.0, 0.0, 40.0)
		var st2: Dictionary = g.builds.placement_status("depot", at, PI / 2.0)
		_check("depot kan op een vrije plek buiten elk vast kader (%s)" % str(st2.reason), st2.valid)
		var b = g.builds.place("depot", at, PI / 2.0, true)
		_check("depot staat (in aanbouw)", b != null and g.builds.under_construction(b))
		if b != null:
			depot = b
			_check("gratis: geen punten en geen bouwtegoed uitgegeven", g.points == points0 and g.build_credit == credit0)
			_check("het gratis tegoed is op", g.free_depot == 0 and g.builds.cost_of("depot") == 800)
			_check("verkopen van het gratis depot levert niets op", g.builds.sell_value(b) == 0)
			_check("de truck is er nog niet tijdens de bouw", g.supply.alive_trucks_of(b) == 0)
			b.build_t = 0.05
	if frames == 40 and not depot.is_empty():
		_check("klaar: de eerste truck is gratis verschenen", g.supply.alive_trucks_of(depot) == 1 and g.points == points0)
		# bestemming: Oostveld (slot 3, x = 128)
		for i in g.supply.stapels.size():
			if g.supply.stapels[i] != null and g.supply.stapels[i].site.id == "oost":
				slot = i
		_check("stapel Oostveld gevonden", slot >= 0)
		if slot >= 0:
			var pts: Array = g.supply.route(depot, slot)
			_check("de route begint bij het depot en eindigt voor de stapel", pts.size() >= 3 and pts[0].distance_to(g.supply.dock_point(depot)) < 0.01 and absf(pts[pts.size() - 1].distance_to(g.supply.stapels[slot].site.pos) - g.supply.STOP_BEFORE) < 0.05)
			_check("de weg is vrij van gebouwen", g.supply.blocked_by(depot, slot) == "")
			g.supply.set_dest(depot, slot)
			_check("bestemming is ingesteld", int(depot.get("dest", -1)) == slot)
			# een kazerne in de weg: versperd, en de bestemming blijft hoe hij was
			var mid: Vector2 = (pts[2] as Vector2).lerp(pts[pts.size() - 1], 0.5)
			var kz = g.builds.place("kazerne", Vector3(mid.x, 0, mid.y), 0.0, false, true)
			_check("kazerne op de weg gezet", kz != null)
			if kz != null:
				_check("gebouw op de weg versperd hem (%s)" % g.supply.blocked_by(depot, slot), g.supply.blocked_by(depot, slot) == "Kazerne")
				depot["dest"] = -1
				g.supply.set_dest(depot, slot)
				_check("versperde bestemming wordt geweigerd", int(depot.get("dest", -1)) == -1)
				g.builds.remove(kz)
			_check("zonder kazerne is de weg weer vrij", g.supply.blocked_by(depot, slot) == "")
			g.supply.set_dest(depot, slot)
	if frames == 50 and slot >= 0:
		# de stapel in de stad ligt aan de overkant van de rivier: de route gaat over de brug
		var stad := -1
		for i in g.supply.stapels.size():
			if g.supply.stapels[i] != null and g.supply.stapels[i].site.id == "stad":
				stad = i
		_check("stapel Stad gevonden", stad >= 0)
		if stad >= 0:
			var sp: Array = g.supply.route(depot, stad)
			var over_brug := false
			for pt: Vector2 in sp:
				if absf(pt.x - D.get("BRIDGE_X")) < 0.5 and absf(pt.y - D.river_z(0.0)) < 25.0:
					over_brug = true
			_check("de route naar de stad loopt over de brug", over_brug)
			_check("de route naar de stad eindigt voor de stapel", absf(sp[sp.size() - 1].distance_to(g.supply.stapels[stad].site.pos) - g.supply.STOP_BEFORE) < 0.05)
	if frames == 60 and slot >= 0:
		var trucks := get_nodes_in_group("voorraadtruck")
		_check("de truck rijdt naar de stapel", not trucks.is_empty() and trucks[0].state != 0)
		var pts2: Array = g.supply.route(depot, slot)
		var regions: Array = []
		for i in range(0, pts2.size() - 1):
			var a: Vector2 = pts2[i]
			var b: Vector2 = pts2[i + 1]
			if a.distance_to(b) < 0.5:
				continue
			regions.append({"name": "weg", "center": (a + b) * 0.5, "size": Vector2(a.distance_to(b) + 2.0, 6.0), "yaw": -atan2((b - a).y, (b - a).x)})
		_check("langs de weg is alles weggehaald (bomen, struiken, rotsen)", F.count_clearable_in_regions(regions, Vector3.ZERO, 0.0, 0.5) == 0)
		var s = g.supply.stapels[slot]
		var from: Vector2 = pts2[pts2.size() - 2]
		var want: Vector2 = (from - s.site.pos).normalized()
		var have := Vector2(sin(s.rotation.y), cos(s.rotation.y))
		_check("de stapel draait zijn voorkant naar de truck", have.dot(want) > 0.99)
	if frames > 60 and frames < 9000 and not income_seen and slot >= 0:
		if g.points > points0 + 50:
			income_seen = true
			print("rit af na ", frames, " beelden: +", g.points - points0, " punten")
	if frames == 9000:
		_check("een rit levert geld op", income_seen)
		print("klaar, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false
