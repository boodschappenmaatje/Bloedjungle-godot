extends SceneTree
## Test: het uitgeklapte hoofdkwartier draaien in het bouwscherm (MCV-start). Tik op het HK opent een paneel met draaiknoppen; draaien kan alleen als de
## nieuwe voetafdruk vrij is; deur (terugkomplek), botsblok en vijandafstand draaien mee.
## godot --headless --path . --script tests/mcv_draai_test.gd --fixed-fps 60

var D: GDScript
var M: GDScript
var main: Node
var frames := 0
var fails := 0
var mcv: Node
var kz = null


func _initialize() -> void:
	D = load("res://scripts/data.gd")
	M = load("res://scripts/mcv.gd")
	D.set("mcv_autodeploy", false)
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
	var p = g.player
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
	if frames == 22:
		_check("voor het draaien: yaw 0", is_equal_approx(g.base_yaw, 0.0))
		_check("tik op het hoofdkwartier raakt het", M.hq_hit(Vector3(40, 0, 42)) and M.hq_hit(Vector3(43, 0, 46)))
		_check("tik ernaast raakt het niet", not M.hq_hit(Vector3(40, 0, 60)) and not M.hq_hit(Vector3(70, 0, 40)))
		# het bouwscherm: paneel met draaiknoppen
		var bm: Node = _bm()
		_check("bouwscherm gevonden", bm != null)
		if bm:
			bm._enter()
			bm._hq_open = true
			bm._fill_panel()
			var btns: Array = []
			_buttons(bm.get("_panel"), btns)
			var texts: Array = []
			for b in btns:
				texts.append(b.text)
			print("knoppen in het HK-paneel: ", texts)
			_check("HK-paneel heeft vier draaiknoppen", texts.has("⟲ 90°") and texts.has("⟲ 15°") and texts.has("15° ⟳") and texts.has("90° ⟳"))
			for b in btns:
				if b.text == "⟲ 90°":
					b.pressed.emit()
			_check("knop ⟲ 90° draait het hoofdkwartier", absf(g.base_yaw - PI / 2.0) < 0.001)
			bm._exit()
	if frames == 26:
		var holder: Node3D = get_nodes_in_group("mcv_hq")[0]
		var bunker := main.find_child("Bunker", true, false) as StaticBody3D
		_check("holder en bunker draaien mee", absf(holder.rotation.y - PI / 2.0) < 0.001 and absf(bunker.global_rotation.y - PI / 2.0) < 0.001)
		_check("terugkomplek ligt voor de gedraaide deur", p.home.distance_to(g.base_home()) < 0.01 and absf(p.home.x - 44.0) < 0.05 and absf(p.home.z - 40.0) < 0.05)
		var r1: Dictionary = M.rotate_hq(self, -deg_to_rad(15.0))
		_check("15° terug lukt", r1.ok and absf(g.base_yaw - (PI / 2.0 - deg_to_rad(15.0))) < 0.001)
		var r2: Dictionary = M.rotate_hq(self, deg_to_rad(15.0))
		_check("en weer 15° vooruit", r2.ok and absf(g.base_yaw - PI / 2.0) < 0.001)
		# een gebouw net buiten de voetafdruk: een kwartslag erbij zou het raken
		# nu staat het hoofdkwartier op yaw 90°: voetafdruk x 34..50, z 33..47; na nog een kwartslag (180°) loopt hij z 30..46
		var at := Vector3(40.0, 0.0, 31.0)
		kz = g.builds.place("kazerne", at, 0.0, false, true)
		_check("kazerne naast het hoofdkwartier gezet", kz != null)
	if frames == 30 and kz != null:
		var y0: float = g.base_yaw
		var r3: Dictionary = M.rotate_hq(self, PI / 2.0)
		_check("draaien tegen een gebouw aan wordt geweigerd (%s)" % str(r3.reason), not r3.ok and absf(g.base_yaw - y0) < 0.0001)
		g.builds.remove(kz)
	if frames == 36:
		var r4: Dictionary = M.rotate_hq(self, PI / 2.0)
		_check("zonder gebouw lukt de kwartslag weer", r4.ok)
		# vijanden meten vanaf het gedraaide hoofdkwartier
		var e: Node = load("res://scenes/enemy.tscn").instantiate()
		e.setup("knife", 1)
		main.add_child(e)
		e.global_position = g.base_point(Vector3(0, 0, 25))
		_check("vijandafstand klopt na het draaien", absf(e._bunker_dist() - (25.0 - D.BUNKER_HALF)) < 0.3)
		print("klaar, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false
