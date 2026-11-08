extends SceneTree
## De vaste uitrit van een depot en de botsing van de trucks: een rechte weg van 20 m voor het depot waar alle routes beginnen en eindigen (korter als er een muur
## voor staat), een depot dat tegen het hoofdkwartier aan kijkt kan niet (geen ruimte voor de uitrit), de uitrit krijgt wegdek dat met het depot verdwijnt, en
## een truck is een vast object: je loopt er niet doorheen.
## godot --headless --path . --script tests/voorraad_uitrit_test.gd --fixed-fps 60
var main: Node
var frames := 0
var fails := 0
var depot: Dictionary
var sup


func _initialize() -> void:
	root.size = Vector2i(932, 430)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


func _stem_nodes() -> int:
	var n := 0
	for c in get_nodes_in_group("uitrit"):
		if not c.is_queued_for_deletion():
			n += 1
	return n


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
		sup = g.supply
		g.points = 5000
		g.build_credit = 5000
		# 1. plaatsen: tegen het hoofdkwartier aan kijken kan niet, van het hoofdkwartier af wel
		var st_bad: Dictionary = g.builds.placement_status("depot", Vector3(0.0, 0.0, -24.0), 0.0)
		_check("een depot dat naar het hoofdkwartier kijkt kan niet (%s)" % str(st_bad.reason), not st_bad.valid and str(st_bad.reason).begins_with("Uitrit geblokkeerd"))
		var st_ok: Dictionary = g.builds.placement_status("depot", Vector3(-24.0, 0.0, -24.0), PI)
		_check("een depot dat van het hoofdkwartier af kijkt kan wel (%s)" % str(st_ok.reason), st_ok.valid)
		var b = g.builds.place("depot", Vector3(-24.0, 0.0, -24.0), PI, true)
		_check("depot staat", b != null)
		if b == null:
			quit(1)
			return false
		depot = b
		b.build_t = 0.05
		# 2. de uitrit: recht voor het depot, 20 m
		var dock: Vector2 = sup.dock_point(depot)
		var k: Vector2 = sup.pre_dock_point(depot)
		_check("de uitrit is 20 m lang (%.1f)" % dock.distance_to(k), absf(dock.distance_to(k) - 20.0) < 0.01)
		_check("de uitrit loopt recht voor het depot uit", absf((k - dock).normalized().dot(Vector2(sin(PI), cos(PI))) - 1.0) < 0.001)
		var ok_routes := true
		for i in sup.stapels.size():
			if sup.stapels[i] == null:
				continue
			var r: Array = sup.route(depot, i)
			if r.size() < 3 or (r[0] as Vector2).distance_to(dock) > 0.01 or (r[1] as Vector2).distance_to(k) > 0.01:
				ok_routes = false
		_check("alle routes beginnen met de uitrit", ok_routes)
		# 3. een truck is een vast object
		sup.buy_truck(depot)
	if frames == 60:
		var trucks: Array = sup.trucks_of(depot)
		_check("er is een truck", not trucks.is_empty())
		if not trucks.is_empty():
			var t = trucks[0]
			_check("de truck heeft de muurlaag (je loopt er niet doorheen)", (t.collision_layer & 2) != 0)
			var shape := BoxShape3D.new()
			shape.size = Vector3(0.6, 1.0, 0.6)
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = shape
			q.collision_mask = 2
			q.transform = Transform3D(Basis.IDENTITY, t.global_position + Vector3(0, 1.0, 0))
			var hit := false
			for h in main.get_world_3d().direct_space_state.intersect_shape(q, 8):
				if h.collider == t:
					hit = true
			_check("een soldaat die op de truck staat botst ertegen", hit)
			# maar een rijdende truck houdt het plaatsen van een gebouw niet tegen
			var at: Vector3 = t.global_position
			var st: Dictionary = g.builds.placement_status("zandzak", at, 0.0)
			_check("een truck blokkeert geen bouwplek (%s)" % str(st.reason), st.valid or str(st.reason) != "Er staat iets in de weg")
		# 4. wegdek, en niets van bomen of rotsen op de uitrit
		_check("de uitrit heeft wegdek", _stem_nodes() == 1)
		var F = load("res://scripts/foliage.gd")
		var dock0: Vector2 = sup.dock_point(depot)
		var regs: Array = [{"name": "uitrit", "center": dock0 + Vector2(0, -10.0), "size": Vector2(5.0, 18.0), "yaw": 0.0}]
		_check("bomen en rotsen op de uitrit zijn weg", F.count_clearable_in_regions(regs, Vector3.ZERO, 0.0, 0.0) == 0)
	if frames == 80:
		# 5. een muur voor de uitrit kapt hem af
		var a: Vector2i = K.snap(Vector3(-40.0, 0.0, -42.0))
		var c: Vector2i = K.snap(Vector3(-8.0, 0.0, -42.0))
		var path: Array = K.line_path(a, c)
		var r: Dictionary = K.build(path)
		_check("muur voor het depot gebouwd (%d stukken)" % int(r.built), int(r.built) > 0)
		var dock: Vector2 = sup.dock_point(depot)
		var len: float = dock.distance_to(sup.pre_dock_point(depot))
		print("  uitrit na de muur: %.1f m" % len)
		_check("de uitrit stopt voor de muur (%.1f m)" % len, len < 12.0 and len >= sup.STEM_MIN)
	if frames == 140:
		var dock: Vector2 = sup.dock_point(depot)
		var len: float = dock.distance_to(sup.pre_dock_point(depot))
		_check("het wegdek werd korter (%d)" % _stem_nodes(), _stem_nodes() == 1)
		# een depot recht achter de muur: te weinig ruimte voor de uitrit
		var st: Dictionary = g.builds.placement_status("depot", Vector3(-24.0, 0.0, -34.0), PI)
		_check("een depot vlak voor een muur kan niet (%s)" % str(st.reason), not st.valid)
		# 6. verkopen: het wegdek verdwijnt
		g.builds.remove(depot)
	if frames == 180:
		_check("het wegdek is weg met het depot (%d)" % _stem_nodes(), _stem_nodes() == 0)
		print("klaar, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false
