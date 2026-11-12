extends SceneTree
## Test van de routezoeker van je eigen jeep en tank (stap "voertuigbevel", Dennis' wens van 11 november 2026: "een routezoeker zodat ze altijd hun weg kunnen vinden").
## Wat hier gecontroleerd wordt: het raster (rivier, rand, muren, rotsen en palmen: een tank rijdt door palmen, een jeep niet), een zoekactie met afgevlakte route, de poort van je kamp,
## de rekentijd per beeld, en echte voertuigen die een U-val, een zigzagmuur, een afgesloten plek en een doel in een boom oplossen.
## godot --headless --path . --script tests/voertuig_zoeker_test.gd --fixed-fps 60
## Klassenamen gebruiken we niet statisch: de autoload Game bestaat nog niet als dit bestand compileert.

var fails := 0
var main: Node
var G: Node
var R: Script
var _watchdog := 0
var _banners: Array = []
var _walls: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _process(_d: float) -> bool:
	_watchdog += 1
	if _watchdog > 90000:
		push_error("Routezoeker-test hangt")
		quit(99)
	return false


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _until(cond: Callable, max_f: int) -> int:
	for i in max_f:
		if cond.call():
			return i
		await process_frame
	return -1


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _space() -> PhysicsDirectSpaceState3D:
	return root.get_world_3d().direct_space_state


func _vehicle(kind: String, pos: Vector3, rot := 0.0) -> Node:
	var v = load("res://scenes/%s.tscn" % kind).instantiate()
	main.add_child(v)
	v.global_position = pos
	v.rotation.y = rot
	return v


## Een muur (of rots, of boom): een statisch blok op de gegeven laag.
func _block(center: Vector3, size: Vector3, layer := 2, meta := "") -> Node:
	var b := StaticBody3D.new()
	b.collision_layer = layer
	b.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	if meta != "":
		b.set_meta("vegetation_kind", meta)
	main.add_child(b)
	b.global_position = center + Vector3(0.0, size.y * 0.5, 0.0)
	_walls.append(b)
	return b


## Een boomstronk of een staande palm als cilinder (zoals Foliage ze maakt): een botsingszuil van 0,8 of 1,3 m is een stronk, 2,2 m een staande boom; allebei met de meta "palm".
func _cyl(center: Vector3, height: float) -> Node:
	var b := StaticBody3D.new()
	b.collision_layer = 128
	b.collision_mask = 0
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.height = height
	cy.radius = 0.5
	cs.shape = cy
	b.add_child(cs)
	b.set_meta("vegetation_kind", "palm")
	main.add_child(b)
	b.global_position = center + Vector3(0.0, height * 0.5, 0.0)
	_walls.append(b)
	return b


## Hoeveel botsingsvormen van bomen en rotsen hebben hun middelpunt binnen dit vlak (x, z)?
func _nature_in(rect: Rect2) -> int:
	var q := PhysicsShapeQueryParameters3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(rect.size.x + 8.0, 12.0, rect.size.y + 8.0)
	q.shape = bs
	q.collision_mask = 128
	q.transform = Transform3D(Basis.IDENTITY, Vector3(rect.get_center().x, 1.0, rect.get_center().y))
	var n := 0
	for h in _space().intersect_shape(q, 1024):
		var c := h.collider as CollisionObject3D
		if c == null:
			continue
		var owner_id := c.shape_find_owner(int(h.shape))
		if owner_id < 0:
			continue
		var node := c.shape_owner_get_owner(owner_id) as Node3D
		if node != null and rect.has_point(Vector2(node.global_position.x, node.global_position.z)):
			n += 1
	return n


func _remove_walls() -> void:
	for w in _walls:
		if is_instance_valid(w):
			w.queue_free()
	_walls.clear()


## Haalt de bomen en rotsen uit een stuk van de kaart, zodat een proef niet van het toeval van het bos afhangt.
func _clear_nature(center: Vector3, size: Vector3) -> int:
	var q := PhysicsShapeQueryParameters3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	q.shape = bs
	q.collision_mask = 128
	q.transform = Transform3D(Basis.IDENTITY, center)
	var n := 0
	for h in _space().intersect_shape(q, 512):
		var c := h.collider as CollisionObject3D
		if c != null and c.collision_layer != 0:
			c.collision_layer = 0
			n += 1
	return n


func _run() -> void:
	R = load("res://scripts/voertuig_raster.gd")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main.begin()
	await _frames(12)
	G = root.get_node("Game")
	G.state = "play"
	G.prep_t = 99999.0
	G.banner.connect(func(big: String, small: String, _t: float): _banners.append(big + " | " + small))
	for n in root.find_children("*", "", true, false):
		if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
			n.set_process(false)
			n.set_process_input(false)
			n.set_process_unhandled_input(false)
	G.player.global_position = Vector3(-60.0, 0.0, 40.0)
	await _frames(20)

	await _test_raster()
	await _test_poort()
	await _test_poortlaan()
	await _test_rekentijd()
	await _test_u_val()
	await _test_zigzag()
	await _test_afgesloten()

	print("klaar, fouten: ", fails)
	quit(1 if fails > 0 else 0)


# ---------------------------------------------------------------- het raster

func _test_raster() -> void:
	print("-- raster")
	R.reset()
	var rj = R.raster(false)
	var rt = R.raster(true)
	rj.tick()
	rt.tick()
	var sp := _space()
	var c: Vector2i = rj.cell_of(rj.center(10, 20))
	_check("cel en middelpunt horen bij elkaar", c == Vector2i(10, 20))
	_check("buiten het raster is dicht", not rj.is_free(sp, -1, 5) and not rj.is_free(sp, 5, 9999))
	var rz: float = load("res://scripts/data.gd").river_z(0.0)
	var cr: Vector2i = rj.cell_of(Vector3(0.0, 0.0, rz))
	_check("de rivier is dicht", not rj.is_free(sp, cr.x, cr.y) and not rt.is_free(sp, cr.x, cr.y))
	var cn: Vector2i = rj.cell_of(Vector3(0.0, 0.0, rz - 25.0))
	_check("ten noorden van de rivier is dicht (de stad hoort bij de vaste weg)", not rj.is_free(sp, cn.x, cn.y))
	var cleared := _clear_nature(Vector3(110.0, 1.0, -20.0), Vector3(100.0, 8.0, 100.0))
	await _frames(3)
	R.reset()
	rj = R.raster(false)
	rt = R.raster(true)
	rj.tick()
	rt.tick()
	var ca: Vector2i = rj.cell_of(Vector3(110.0, 0.0, -20.0))
	_check("een leeg stuk veld is vrij voor jeep en tank (%d bossen weggehaald)" % cleared, rj.is_free(sp, ca.x, ca.y) and rt.is_free(sp, ca.x, ca.y))
	_block(Vector3(110.0, 0.0, -20.0), Vector3(2.0, 3.0, 2.0))
	await _frames(3)
	R.reset()
	rj = R.raster(false)
	rt = R.raster(true)
	rj.tick()
	rt.tick()
	_check("een muurblok maakt zijn cel dicht, voor jeep en tank", not rj.is_free(sp, ca.x, ca.y) and not rt.is_free(sp, ca.x, ca.y))
	var cside: Vector2i = rj.cell_of(Vector3(110.0 + 7.5, 0.0, -20.0))
	_check("drie cellen ernaast is het vrij", rj.is_free(sp, cside.x, cside.y) and rt.is_free(sp, cside.x, cside.y))
	var cnear: Vector2i = rj.cell_of(Vector3(110.0 + 4.5, 0.0, -20.0))
	_check("de tank heeft meer ruimte nodig dan de jeep (4,5 m naast het blok: jeep vrij, tank dicht)", rj.is_free(sp, cnear.x, cnear.y) and not rt.is_free(sp, cnear.x, cnear.y))
	_remove_walls()
	var pa := _block(Vector3(130.0, 0.0, -20.0), Vector3(1.0, 3.0, 1.0), 128, "palm")
	var ro := _block(Vector3(130.0, 0.0, -40.0), Vector3(1.0, 3.0, 1.0), 128, "rock")
	var lg := _block(Vector3(130.0, 0.0, -60.0), Vector3(1.0, 0.6, 1.0), 128, "")
	await _frames(3)
	R.reset()
	rj = R.raster(false)
	rt = R.raster(true)
	rj.tick()
	rt.tick()
	var cp: Vector2i = rj.cell_of(Vector3(130.0, 0.0, -20.0))
	var cro: Vector2i = rj.cell_of(Vector3(130.0, 0.0, -40.0))
	var clg: Vector2i = rj.cell_of(Vector3(130.0, 0.0, -60.0))
	_check("een palm: de jeep gaat eromheen, de tank rijdt erdoorheen", not rj.is_free(sp, cp.x, cp.y) and rt.is_free(sp, cp.x, cp.y))
	_check("een rots houdt jeep en tank allebei tegen", not rj.is_free(sp, cro.x, cro.y) and not rt.is_free(sp, cro.x, cro.y))
	_check("een omgevallen stam houdt ook de tank tegen", not rj.is_free(sp, clg.x, clg.y) and not rt.is_free(sp, clg.x, clg.y))
	_remove_walls()
	_cyl(Vector3(150.0, 0.0, -50.0), 1.3)   # een stronk (laag, maar met de meta van een palm)
	_cyl(Vector3(150.0, 0.0, -30.0), 2.2)   # een staande palm
	await _frames(3)
	R.reset()
	rj = R.raster(false)
	rt = R.raster(true)
	rj.tick()
	rt.tick()
	var cst: Vector2i = rj.cell_of(Vector3(150.0, 0.0, -50.0))
	var cpm: Vector2i = rj.cell_of(Vector3(150.0, 0.0, -30.0))
	_check("een stronk is hard, ook voor de tank", not rj.is_free(sp, cst.x, cst.y) and not rt.is_free(sp, cst.x, cst.y) and not rj.is_open(sp, cst.x, cst.y) and not rt.is_open(sp, cst.x, cst.y))
	_check("een staande palm is zacht: de jeep kan er desnoods doorheen, de tank rijdt erdoorheen", not rj.is_free(sp, cpm.x, cpm.y) and rj.is_open(sp, cpm.x, cpm.y) and rt.is_free(sp, cpm.x, cpm.y))
	_remove_walls()
	await _frames(3)
	R.reset()
	rj = R.raster(false)
	rj.tick()
	# vastgezeten: de cellen vlak voor de neus zijn een tijd dicht
	var pos := Vector3(110.0, 0.0, 0.0)
	rj.block_ahead(pos, Vector3(0.0, 0.0, -1.0))
	var cb: Vector2i = rj.cell_of(Vector3(110.0, 0.0, -4.5))
	_check("een vastzittend voertuig sluit de cellen voor zijn neus", not rj.is_free(sp, cb.x, cb.y))
	rj.now_s += 40
	_check("na een halve minuut zijn ze weer open", rj.is_free(sp, cb.x, cb.y))


# ---------------------------------------------------------------- de poort van je kamp

func _test_poort() -> void:
	print("-- poort van het kamp")
	var K: Script = load("res://scripts/kampmuur.gd")
	# een muur langs de x-as op z = 10,5 met een poort van 6,8 m in het midden (x = 140)
	_block(Vector3(127.975, 0.0, 10.5), Vector3(15.95, 3.0, 0.7))
	_block(Vector3(152.025, 0.0, 10.5), Vector3(15.95, 3.0, 0.7))
	var e1: Vector4i = K.edge_key(Vector2i(39, 3), Vector2i(40, 3))
	var e2: Vector4i = K.edge_key(Vector2i(40, 3), Vector2i(41, 3))
	G.gates.add_gate(Vector3(140.0, 0.0, 10.5), 0.0, e1, e2)
	await _frames(6)
	R.reset()
	var sp := _space()
	for tank in [false, true]:
		var r = R.raster(tank)
		r.tick()
		var cg: Vector2i = r.cell_of(Vector3(140.0, 0.0, 10.5))
		var cw: Vector2i = r.cell_of(Vector3(128.0, 0.0, 10.5))
		_check("%s: de muur is dicht, de opening van de poort telt als vrij" % ("tank" if tank else "jeep"), not r.is_free(sp, cw.x, cw.y) and r.is_free(sp, cg.x, cg.y))
		var s = r.search(Vector3(140.0, 0.0, 30.0), Vector3(140.0, 0.0, -10.0))
		s.finish(sp)
		var x_at := 999.0
		var pts: Array = [Vector3(140.0, 0.0, 30.0)] + s.path
		for i in pts.size() - 1:
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[i + 1]
			if (a.z - 10.5) * (b.z - 10.5) <= 0.0 and absf(b.z - a.z) > 0.01:
				x_at = a.x + (b.x - a.x) * (10.5 - a.z) / (b.z - a.z)
		_check("%s: de route gaat dwars door de poort (x = %.1f bij de muur)" % ["tank" if tank else "jeep", x_at], s.ok and absf(x_at - 140.0) < 1.4)
	# zonder de poort (de opening dicht gemaakt) is de muur 40 m lang en moet hij er omheen: een route die langs een uiteinde loopt
	G.gates.remove_gate(G.gates.list[G.gates.list.size() - 1])
	_block(Vector3(140.0, 0.0, 10.5), Vector3(8.1, 3.0, 0.7))
	await _frames(4)
	R.reset()
	var r2 = R.raster(true)
	r2.tick()
	var s2 = r2.search(Vector3(140.0, 0.0, 30.0), Vector3(140.0, 0.0, -10.0))
	s2.finish(sp)
	var x_cross := 999.0
	var pts2: Array = [Vector3(140.0, 0.0, 30.0)] + s2.path
	for i in pts2.size() - 1:
		var a2: Vector3 = pts2[i]
		var b2: Vector3 = pts2[i + 1]
		if (a2.z - 10.5) * (b2.z - 10.5) <= 0.0 and absf(b2.z - a2.z) > 0.01:
			x_cross = a2.x + (b2.x - a2.x) * (10.5 - a2.z) / (b2.z - a2.z)
	_check("zonder poort gaat de route om de muur heen (x = %.1f bij de muur)" % x_cross, s2.ok and absf(x_cross - 140.0) > 8.0)
	_remove_walls()
	await _frames(3)


# ---------------------------------------------------------------- rekentijd

## Een nieuwe poort ruimt de weg: bomen, stronken en rotsen vlak voor en achter de opening verdwijnen.
func _test_poortlaan() -> void:
	print("-- poortlaan")
	var K: Script = load("res://scripts/kampmuur.gd")
	var half := Vector2(K.GATE_LANE_SIDE, K.GATE_LANE_ALONG)
	var best := Vector3.ZERO
	var most := 0
	for cx in range(-160, 0, 20):
		for cz in range(70, 170, 20):
			var n := _nature_in(Rect2(Vector2(cx, cz) - half, half * 2.0))
			if n > most:
				most = n
				best = Vector3(cx, 0.0, cz)
	_check("er staat natuur waar de poortlaan komt (%d vormen bij %s)" % [most, str(best)], most > 0)
	K.clear_gate_lane(best, 0.0)
	await _frames(4)
	var after := _nature_in(Rect2(Vector2(best.x, best.z) - half, half * 2.0))
	_check("de poortlaan is leeg (was %d, nu %d)" % [most, after], after == 0)
	# een kwartslag gedraaid (een poort in een muur langs z): de laan loopt dan langs x
	var best2 := Vector3.ZERO
	var most2 := 0
	for cx in range(-160, 0, 20):
		for cz in range(70, 170, 20):
			if absf(float(cx) - best.x) < 30.0 and absf(float(cz) - best.z) < 30.0:
				continue
			var n2 := _nature_in(Rect2(Vector2(cx, cz) - Vector2(half.y, half.x), Vector2(half.y, half.x) * 2.0))
			if n2 > most2:
				most2 = n2
				best2 = Vector3(cx, 0.0, cz)
	K.clear_gate_lane(best2, PI * 0.5)
	await _frames(4)
	var after2 := _nature_in(Rect2(Vector2(best2.x, best2.z) - Vector2(half.y, half.x), Vector2(half.y, half.x) * 2.0))
	_check("ook gedraaid is de laan leeg (was %d, nu %d)" % [most2, after2], most2 > 0 and after2 == 0)


func _test_rekentijd() -> void:
	print("-- rekentijd")
	R.reset()
	var sp := _space()
	var r = R.raster(true)
	var searches: Array = []
	for i in 3:
		searches.append(r.search(Vector3(-80.0 + float(i) * 10.0, 0.0, 120.0), Vector3(150.0, 0.0, -40.0 + float(i) * 10.0)))
	var worst_total := 0
	var worst_one := 0
	var frames := 0
	var all_done := false
	while not all_done and frames < 600:
		var before: Array = []
		for s in searches:
			before.append(s.micros)
		for s in searches:
			s.step(sp)
		var total := 0
		for i in searches.size():
			var d: int = searches[i].micros - before[i]
			total += d
			worst_one = maxi(worst_one, d)
		worst_total = maxi(worst_total, total)
		all_done = true
		for s in searches:
			if not s.done:
				all_done = false
		frames += 1
		await process_frame
	_check("drie lange zoekacties zijn klaar (%d beelden)" % frames, all_done)
	_check("ze vinden alle drie een weg", searches[0].ok and searches[1].ok and searches[2].ok)
	_check("samen hooguit 4 ms per beeld (gemeten %.2f ms, een zoekactie %.2f ms)" % [worst_total / 1000.0, worst_one / 1000.0], worst_total < 4000)
	# een onbereikbaar doel: stopt na MAX_EXPAND met de beste benadering
	var s_un = r.search(Vector3(-80.0, 0.0, 120.0), Vector3(0.0, 0.0, -150.0))
	var f2 := 0
	while not s_un.done and f2 < 800:
		s_un.step(sp)
		f2 += 1
		await process_frame
	_check("een onbereikbaar doel (ten noorden van de rivier): een beste benadering, geen weg (%d beelden)" % f2, s_un.done and s_un.partial and not s_un.ok and s_un.expanded <= 6000 and s_un.path.size() >= 1)


# ---------------------------------------------------------------- echte voertuigen

func _drive(v: Node, goal: Vector3, max_f: int, st: Dictionary) -> int:
	var b: Node = v.get_node("Bestuurder")
	b.set_command("move", goal)
	return await _until(func():
		var p: Vector3 = v.global_position
		var depth: float = st.get("depth", 0.0)
		if st.has("u"):
			var u: Rect2 = st["u"]
			if u.has_point(Vector2(p.x, p.z)):
				st["depth"] = maxf(depth, u.end.y - p.z)
		return b.arrived, max_f)


func _test_u_val() -> void:
	print("-- U-val (de weg erheen loopt dood in de val; erachter ligt het doel)")
	R.reset()
	_walls.clear()
	_block(Vector3(110.0, 0.0, -30.0), Vector3(30.0, 3.0, 1.0))
	_block(Vector3(95.0, 0.0, -20.0), Vector3(1.0, 3.0, 20.0))
	_block(Vector3(125.0, 0.0, -20.0), Vector3(1.0, 3.0, 20.0))
	await _frames(5)
	var goal := Vector3(110.0, 0.0, -50.0)
	for kind in ["jeep", "tank"]:
		_banners.clear()
		var v := _vehicle(kind, Vector3(110.0, 0.0, 4.0))
		await _frames(4)
		var b: Node = v.get_node("Bestuurder")
		var st := {"u": Rect2(96.5, -29.0, 27.0, 19.0)}   # het inwendige van de U (x, z, breedte, diepte)
		var f: int = await _drive(v, goal, 5000, st)
		var d := _flat(v.global_position, goal)
		_check("%s: komt langs de U-val bij het doel (%d beelden, nog %.1f m)" % [kind, f, d], f >= 0 and d < 6.0 and not b.vast)
		_check("%s: rijdt niet de val in (diepste punt %.1f m in de U)" % [kind, float(st.get("depth", 0.0))], float(st.get("depth", 0.0)) < 5.0)
		_check("%s: geen melding VAST of GEEN WEG" % kind, not _banners.any(func(t): return String(t).contains("VAST") or String(t).contains("GEEN WEG")))
		v.queue_free()
		await _frames(3)
	_remove_walls()
	await _frames(3)


func _test_zigzag() -> void:
	print("-- zigzagmuur (drie lange muren met om en om een opening)")
	R.reset()
	_block(Vector3(102.5, 0.0, -5.0), Vector3(45.0, 3.0, 1.0))    # opening aan de oostkant (x 125 tot 160)
	_block(Vector3(117.5, 0.0, -20.0), Vector3(45.0, 3.0, 1.0))   # opening aan de westkant (x 60 tot 95)
	_block(Vector3(102.5, 0.0, -35.0), Vector3(45.0, 3.0, 1.0))   # opening aan de oostkant
	await _frames(5)
	_banners.clear()
	var v := _vehicle("jeep", Vector3(105.0, 0.0, 10.0))
	await _frames(4)
	var b: Node = v.get_node("Bestuurder")
	var goal := Vector3(100.0, 0.0, -50.0)
	var f: int = await _drive(v, goal, 6000, {})
	var d := _flat(v.global_position, goal)
	_check("jeep: weeft door de zigzag naar het doel (%d beelden, nog %.1f m)" % [f, d], f >= 0 and d < 6.0 and not b.vast)
	_check("jeep: geen melding VAST of GEEN WEG", not _banners.any(func(t): return String(t).contains("VAST") or String(t).contains("GEEN WEG")))
	# een nieuw doel onderweg: hij zoekt opnieuw
	b.set_command("move", Vector3(130.0, 0.0, 15.0))
	var f2: int = await _until(func(): return b.arrived, 3000)
	_check("jeep: een nieuw bevel vanuit het einde van de zigzag brengt hem er weer uit (%d beelden)" % f2, f2 >= 0 and _flat(v.global_position, Vector3(130.0, 0.0, 15.0)) < 6.0 and not b.vast)
	v.queue_free()
	_remove_walls()
	await _frames(3)


func _test_afgesloten() -> void:
	print("-- afgesloten plek en een doel in een boom")
	R.reset()
	# een ring van vier muren: het doel erbinnen is niet te bereiken
	_block(Vector3(110.0, 0.0, -26.0), Vector3(12.0, 3.0, 1.0))
	_block(Vector3(110.0, 0.0, -14.0), Vector3(12.0, 3.0, 1.0))
	_block(Vector3(104.0, 0.0, -20.0), Vector3(1.0, 3.0, 12.0))
	_block(Vector3(116.0, 0.0, -20.0), Vector3(1.0, 3.0, 12.0))
	await _frames(5)
	_banners.clear()
	var v := _vehicle("jeep", Vector3(110.0, 0.0, 10.0))
	await _frames(4)
	var b: Node = v.get_node("Bestuurder")
	var goal := Vector3(110.0, 0.0, -20.0)
	b.set_command("move", goal)
	var f: int = await _until(func(): return b.vast, 4000)
	var d := _flat(v.global_position, goal)
	_check("afgesloten plek: hij rijdt zo dichtbij als kan en meldt GEEN WEG (%d beelden, nog %.1f m)" % [f, d], f >= 0 and d > 6.0 and d < 20.0 and _banners.any(func(t): return String(t).contains("GEEN WEG")))
	_check("afgesloten plek: hij staat stil (HOUD) en krijgt het gele teken", b.vast and b.command == "hold")
	v.queue_free()
	_remove_walls()
	await _frames(3)
	# een doel dat zelf in een rots ligt: rijdt tot de dichtstbijzijnde vrije plek en staat dan gewoon stil (geen VAST)
	R.reset()
	_block(Vector3(110.0, 0.0, -20.0), Vector3(4.0, 3.0, 4.0), 128, "rock")
	await _frames(5)
	_banners.clear()
	var v2 := _vehicle("tank", Vector3(110.0, 0.0, 10.0))
	await _frames(4)
	var b2: Node = v2.get_node("Bestuurder")
	b2.set_command("move", Vector3(110.0, 0.0, -20.0))
	var f2: int = await _until(func(): return b2.arrived, 4000)
	var d2 := _flat(v2.global_position, Vector3(110.0, 0.0, -20.0))
	_check("doel in een rots: de tank komt zo dichtbij als kan (%d beelden, nog %.1f m) en staat stil" % [f2, d2], f2 >= 0 and d2 < 14.0 and not b2.vast)
	print("   (meldingen: %s, vast=%s, command=%s)" % [str(_banners), str(b2.vast), b2.command])
	_check("doel in een rots: geen foutmelding", not _banners.any(func(t): return String(t).contains("VAST") or String(t).contains("GEEN WEG")))
	v2.queue_free()
	_remove_walls()
