extends SceneTree
## Test van het voertuigbevel in de echte game (stap "voertuigbevel", Dennis' keuzes 1A-9A van 11 november 2026): je jeep en tank hebben een ingebouwde bestuurder, staan in dezelfde
## keuzelijst als je soldaten, krijgen dezelfde zes bevelen en rijden en schieten dan zelf.
## Wat hier gecontroleerd wordt: selecteren (ALLES, VOERTUIGEN, dubbeltik), VERPLAATS in open veld (jeep en tank), schieten (jeep rijdend, tank alleen stilstaand), konvooi met afstand,
## de brug (omhoog = wachten), instappen wist het bevel en uitstappen is HOUD, vastzitten = achteruit, nog eens proberen, dan melding en stoppen, de rit naar de vijandbasis.
## godot --headless --path . --script tests/voertuig_bevel_test.gd --fixed-fps 60
## Draai hem met Godot 4.7.2 (zoals de CI). Klassenamen gebruiken we niet statisch: de autoload Game bestaat nog niet als dit bestand compileert.

var fails := 0
var main: Node
var G: Node
var ts: Node
var _watchdog := 0
var _base_enemies: Array = []
var _banners: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _process(_d: float) -> bool:
	_watchdog += 1
	if _watchdog > 60000:
		push_error("Voertuigbevel-test hangt")
		quit(99)
	return false


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


## Wacht tot `cond` waar is (hoogstens `max_f` beelden). Geeft het aantal beelden terug, of -1 als het niet gelukt is.
func _until(cond: Callable, max_f: int) -> int:
	for i in max_f:
		if cond.call():
			return i
		await process_frame
	return -1


func _vehicle(kind: String, pos: Vector3, rot := 0.0) -> Node:
	var v = load("res://scenes/%s.tscn" % kind).instantiate()
	main.add_child(v)
	v.global_position = pos
	v.rotation.y = rot
	return v


func _bst(v: Node) -> Node:
	return v.get_node("Bestuurder")


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _remove(v: Node) -> void:
	if is_instance_valid(v):
		v.queue_free()


## Een stilstaande vijand met veel levenspunten: je ziet aan zijn levenspunten of er op hem geschoten is.
func _dummy_enemy(pos: Vector3) -> Node:
	var e: Node = load("res://scenes/enemy.tscn").instantiate()
	e.call("setup", "rifle", 1)
	main.add_child(e)
	e.global_position = pos
	e.set_process(false)
	e.set_physics_process(false)
	e.max_hp = 100000.0
	e.hp = 100000.0
	return e


func _clear_new_enemies() -> void:
	for e in G.enemies.duplicate():
		if _base_enemies.has(e):
			continue
		G.enemies.erase(e)
		if is_instance_valid(e):
			e.queue_free()


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main.begin()
	await _frames(12)
	G = root.get_node("Game")
	G.state = "play"
	G.prep_t = 99999.0
	G.banner.connect(func(big: String, small: String, _t: float): _banners.append(big + " | " + small))
	ts = get_first_node_in_group("troep_selectie")
	_base_enemies = G.enemies.duplicate()
	# de aanraakbediening zet Game.move elk beeld terug op nul; we sturen niet zelf, maar laten hem met rust
	for n in root.find_children("*", "", true, false):
		if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
			n.set_process(false)
			n.set_process_input(false)
			n.set_process_unhandled_input(false)
	G.player.global_position = Vector3(-60.0, 0.0, 40.0)   # ver weg van het open veld waar de voertuigen rijden

	await _test_selectie()
	await _test_verplaats()
	await _test_schieten()
	await _test_konvooi()
	await _test_instappen()
	await _test_vast()
	await _test_brug()
	await _test_basis()

	print("klaar, fouten: ", fails)
	quit(1 if fails > 0 else 0)


# ---------------------------------------------------------------- selecteren

func _test_selectie() -> void:
	print("-- selecteren")
	var j := _vehicle("jeep", Vector3(100.0, 0.0, -10.0))
	var t := _vehicle("tank", Vector3(112.0, 0.0, -10.0))
	await _frames(4)
	var bj := _bst(j)
	var bt := _bst(t)
	_check("jeep en tank hebben een bestuurder", bj != null and bt != null and bj.kind == "jeep" and bt.kind == "tank")
	_check("de bestuurder heeft de velden van een soldaat (hp, hp_max, command, ring)", bj.hp > 0.0 and bj.hp_max >= bj.hp and bj.command == "hold" and bj.ring_r > 1.5 and bt.ring_r > bj.ring_r)
	_check("beide voertuigen staan in de keuzelijst van de bevelstand", ts.units().has(bj) and ts.units().has(bt))
	_check("vehicles() geeft alleen voertuigen", ts.vehicles().size() == 2 and ts.vehicles().has(bj))
	ts.select_all()
	_check("ALLES kiest ook de voertuigen", ts.sel.has(bj) and ts.sel.has(bt))
	_check("tekst bij de keuze: twee voertuigen", ts.wie(ts.sel) == "2 voertuigen")
	ts.select([bj])
	_check("tekst bij de keuze: een jeep", ts.wie(ts.sel) == "1 jeep")
	ts.select([bt])
	_check("tekst bij de keuze: een tank", ts.wie(ts.sel) == "1 tank")
	ts.select_vehicles()
	_check("de knop VOERTUIGEN kiest jeep en tank", ts.sel.size() == 2)
	ts.select_kind("jeep", ts.units())
	_check("dubbeltik op een jeep kiest alle jeeps", ts.sel.size() == 1 and ts.sel[0] == bj)
	ts.save_group(0)
	ts.clear()
	_check("groepsvakje bewaart een voertuig", ts.pick_group(0) and ts.sel.size() == 1 and ts.sel[0] == bj)
	# een bevel op een gemengde keuze
	var ally_script: GDScript = load("res://scripts/ally.gd")
	var a = ally_script.new()
	a.kind = "geweer"
	main.add_child(a)
	a.setup(100.0, 16.0, 0)
	a.global_position = Vector3(90.0, 0.0, 0.0)
	a.set_physics_process(false)
	G.allies.append(a)
	ts.select([a, bj])
	_check("tekst bij een gemengde keuze: twee eenheden", ts.wie(ts.sel) == "2 eenheden")
	var n: int = ts.issue("move", Vector3(100.0, 0.0, 5.0))
	_check("een bevel aan soldaat en jeep samen: beide krijgen het", n == 2 and bj.command == "move" and a.command == "move")
	G.allies.erase(a)
	a.queue_free()
	ts.clear()
	bj.set_command("hold", Vector3.ZERO)
	_check("de bestuurder neemt HOUD aan", bj.command == "hold")
	# aanval op de vijandbasis wordt de mars naar de poort, ook voor een voertuig
	ts.select([bt])
	ts.issue("attack", load("res://scripts/vijand_basis.gd").gate_inside())
	_check("aanval op de vijandbasis is het bevel basis", bt.command == "basis")
	bt.set_command("hold", Vector3.ZERO)
	ts.clear()
	_remove(j)
	_remove(t)
	await _frames(3)
	_check("een weg gehaald voertuig valt uit de lijst", ts.vehicles().is_empty())


# ---------------------------------------------------------------- verplaatsen

func _test_verplaats() -> void:
	print("-- verplaatsen in open veld")
	var j := _vehicle("jeep", Vector3(100.0, 0.0, -10.0))
	var t := _vehicle("tank", Vector3(130.0, 0.0, -10.0))
	await _frames(4)
	var bj := _bst(j)
	var bt := _bst(t)
	var jt := Vector3(100.0, 0.0, 30.0)   # achter hem: eerst omdraaien
	ts.select([bj])
	ts.issue("move", jt)
	var f: int = await _until(func(): return bj.arrived and _flat(j.global_position, jt) < 4.0, 60 * 25)
	_check("jeep rijdt 40 m naar een doel achter zich en is er binnen 25 s (%.1f s)" % (float(f) / 60.0), f >= 0)
	_check("jeep staat dan stil binnen 3 m van het doel (%.1f m)" % _flat(j.global_position, jt), _flat(j.global_position, jt) < 3.0 and not bj.vast)
	var tt := Vector3(130.0, 0.0, 25.0)
	ts.select([bt])
	ts.issue("move", tt)
	f = await _until(func(): return bt.arrived and _flat(t.global_position, tt) < 5.0, 60 * 40)
	_check("tank rijdt 35 m naar een doel achter zich en is er binnen 40 s (%.1f s)" % (float(f) / 60.0), f >= 0)
	_check("tank staat dan stil binnen 4 m van het doel (%.1f m)" % _flat(t.global_position, tt), _flat(t.global_position, tt) < 4.0 and not bt.vast)
	# een voertuig dat de bestuurder niet bevelt, blijft staan
	var p0: Vector3 = j.global_position
	await _frames(60)
	_check("zonder bevel (HOUD) blijft de jeep staan", _flat(j.global_position, p0) < 0.3)
	# VOLG MIJ: hij rijdt naar jou toe en blijft 8 m van je af
	G.player.global_position = Vector3(100.0, 0.0, 70.0)
	bj.set_command("follow", Vector3.ZERO)
	f = await _until(func(): return _flat(j.global_position, G.player.global_position) < 10.5 and bj.arrived, 60 * 20)
	_check("VOLG MIJ: de jeep komt naar je toe en stopt op ruim 6 m (%.1f m)" % _flat(j.global_position, G.player.global_position), f >= 0 and _flat(j.global_position, G.player.global_position) > 6.0)
	G.player.global_position = Vector3(-60.0, 0.0, 40.0)
	bj.set_command("hold", Vector3.ZERO)
	bt.set_command("hold", Vector3.ZERO)
	ts.clear()
	_remove(j)
	_remove(t)
	await _frames(3)


# ---------------------------------------------------------------- schieten

func _test_schieten() -> void:
	print("-- schieten")
	_clear_new_enemies()
	var j := _vehicle("jeep", Vector3(100.0, 0.0, -10.0))
	await _frames(4)
	var bj := _bst(j)
	var e := _dummy_enemy(Vector3(100.0, 0.0, -32.0))   # 22 m voor hem
	await _frames(60 * 3)
	_check("een geparkeerde jeep (HOUD) schiet zelf op een vijand binnen 30 m (%.0f schade)" % (e.max_hp - e.hp), e.hp < e.max_hp)
	# een vijand buiten bereik: niets
	e.hp = e.max_hp
	e.global_position = Vector3(100.0, 0.0, -60.0)   # 50 m
	await _frames(60 * 2)
	_check("een vijand op 50 m wordt niet beschoten", e.hp >= e.max_hp)
	# rijdend schieten: de jeep rijdt dwars langs een vijand en schiet onderweg
	e.global_position = Vector3(112.0, 0.0, -30.0)
	e.hp = e.max_hp
	j.global_position = Vector3(100.0, 0.0, -10.0)
	j.rotation.y = 0.0
	ts.select([bj])
	ts.issue("move", Vector3(100.0, 0.0, -60.0))
	var moved_and_hit := false
	for i in 60 * 20:
		await process_frame
		if j.global_position.z < -22.0 and e.hp < e.max_hp and not bj.arrived:
			moved_and_hit = true
		if bj.arrived or moved_and_hit:
			break
	_check("de jeep schiet tijdens het rijden (VERPLAATS, vijand dwars op 12 m)", moved_and_hit)
	bj.set_command("hold", Vector3.ZERO)
	_clear_new_enemies()
	_remove(j)
	await _frames(3)

	var t := _vehicle("tank", Vector3(100.0, 0.0, -10.0))
	await _frames(4)
	var bt := _bst(t)
	e = _dummy_enemy(Vector3(100.0, 0.0, -34.0))   # 24 m
	await _frames(60 * 8)
	_check("een geparkeerde tank schiet zelf op een vijand binnen 34 m (%.0f schade)" % (e.max_hp - e.hp), e.hp < e.max_hp)
	# rijdend schiet de tank niet: hij rijdt weg en de vijand blijft ongeschonden zolang hij rijdt
	e.hp = e.max_hp
	e.global_position = Vector3(112.0, 0.0, -10.0)
	t.global_position = Vector3(100.0, 0.0, -10.0)
	t.rotation.y = 0.0
	await _frames(2)
	bt.set_command("move", Vector3(100.0, 0.0, 22.0))
	var shots_moving := 0
	var hp_before: float = e.hp
	var stood_still_at_end := false
	for i in 60 * 14:
		await process_frame
		if not bt.arrived:
			if e.hp < hp_before:
				shots_moving += 1
			hp_before = e.hp
		else:
			stood_still_at_end = true
			break
	_check("de tank rijdt naar zijn doel (VERPLAATS) zonder te schieten", stood_still_at_end and shots_moving == 0)
	# aangekomen staat hij stil en schiet weer
	await _frames(60 * 8)
	_check("aangekomen schiet de tank weer (hij staat stil)", e.hp < hp_before)
	bt.set_command("hold", Vector3.ZERO)
	_clear_new_enemies()
	_remove(t)
	await _frames(3)


# ---------------------------------------------------------------- konvooi

func _test_konvooi() -> void:
	print("-- konvooi")
	var a := _vehicle("jeep", Vector3(100.0, 0.0, -10.0))
	var b := _vehicle("jeep", Vector3(100.0, 0.0, 4.0))
	await _frames(4)
	var ba := _bst(a)
	var bb := _bst(b)
	ts.select([ba, bb])
	ts.issue("move", Vector3(100.0, 0.0, -70.0))
	var min_clear := 99.0
	var f := -1
	for i in 60 * 30:
		await process_frame
		var d: float = _flat(a.global_position, b.global_position)
		min_clear = minf(min_clear, d - 4.2)
		if ba.arrived and bb.arrived:
			f = i
			break
	if f < 0:
		print("   a: %s arrived %s drive %.1f cmd %s | b: %s arrived %s drive %.1f cmd %s" % [a.global_position, ba.arrived, ba.drive_speed, ba.command, b.global_position, bb.arrived, bb.drive_speed, bb.command])
	_check("twee jeeps in een rij komen allebei aan (%.1f s)" % (float(f) / 60.0), f >= 0)
	_check("ze rijden niet op elkaar in: tussenruimte blijft minstens 1,5 m (kleinste %.1f m)" % min_clear, min_clear > 1.5)
	_check("en ze staan niet op dezelfde plek: uitgewaaierd bij het doel (%.1f m uit elkaar)" % _flat(a.global_position, b.global_position), _flat(a.global_position, b.global_position) > 5.0)
	ba.set_command("hold", Vector3.ZERO)
	bb.set_command("hold", Vector3.ZERO)
	ts.clear()
	_remove(a)
	_remove(b)
	await _frames(3)


# ---------------------------------------------------------------- instappen en uitstappen

func _test_instappen() -> void:
	print("-- instappen en uitstappen")
	var j := _vehicle("jeep", Vector3(100.0, 0.0, -10.0))
	await _frames(4)
	var bj := _bst(j)
	ts.select([bj])
	ts.issue("move", Vector3(100.0, 0.0, 30.0))
	await _frames(30)
	_check("de jeep rijdt op bevel", bj.command == "move" and not bj.arrived)
	G.player.global_position = j.global_position
	j._toggle()
	_check("instappen: jij bestuurt en het bevel vervalt (HOUD)", j.driven and bj.command == "hold")
	await _frames(2)
	_check("een voertuig waar jij in zit is geen eenheid meer en valt uit de keuze", not ts.units().has(bj) and not ts.sel.has(bj))
	bj.set_command("move", Vector3(100.0, 0.0, 60.0))
	_check("en neemt geen bevel aan", bj.command == "hold")
	j._toggle()
	_check("uitstappen: hij blijft staan (HOUD) en is weer te bevelen", not j.driven and bj.command == "hold" and ts.units().has(bj))
	G.player.global_position = Vector3(-60.0, 0.0, 40.0)
	_remove(j)
	await _frames(3)


# ---------------------------------------------------------------- vast

func _test_vast() -> void:
	print("-- vastzitten")
	_banners.clear()
	var j := _vehicle("jeep", Vector3(100.0, 0.0, -10.0))
	await _frames(4)
	var bj := _bst(j)
	ts.select([bj])
	ts.issue("move", Vector3(100.0, 0.0, -60.0))
	# we houden hem vast (alsof hij vastzit): elk beeld terug op zijn plek en in zijn richting
	var pin: Vector3 = j.global_position
	var yaw: float = j.rotation.y
	var backed := false
	var f := -1
	for i in 60 * 30:
		j.global_position = pin
		j.rotation.y = yaw
		await process_frame
		if bj._back_t > 0.0:
			backed = true
		if bj.vast:
			f = i
			break
	_check("een jeep die niet vooruit komt zet eerst achteruit", backed)
	_check("en geeft het na een paar pogingen op (%.1f s)" % (float(f) / 60.0), f >= 0 and bj.vast)
	_check("dan stopt hij (HOUD) en geeft een melding", bj.command == "hold" and bj.arrived and _banners.any(func(s): return s.begins_with("JEEP VAST")))
	_check("het teken VAST staat voor de kaart", bj.vast)
	# een nieuw bevel haalt het teken weg
	bj.set_command("move", Vector3(100.0, 0.0, -30.0))
	_check("een nieuw bevel haalt VAST weg", not bj.vast)
	bj.set_command("hold", Vector3.ZERO)
	ts.clear()
	_remove(j)
	await _frames(3)


# ---------------------------------------------------------------- de brug

func _test_brug() -> void:
	print("-- de brug")
	var D: Script = load("res://scripts/data.gd")
	var rz: float = D.river_z(D.BRIDGE_X)
	_banners.clear()
	G.bridge.toggle()   # omhoog
	await _until(func(): return G.bridge.state == 2, 60 * 12)
	_check("de brug staat omhoog", G.bridge.state == 2)
	var j := _vehicle("jeep", Vector3(D.BRIDGE_X, 0.0, rz + 30.0))
	await _frames(4)
	var bj := _bst(j)
	var goal := Vector3(-6.0, 0.0, -118.5)   # een hoekpunt van de voertuigroute in de stad
	ts.select([bj])
	ts.issue("move", goal)
	var f: int = await _until(func(): return bj.waiting_bridge, 60 * 20)
	_check("de jeep wacht voor de brug die omhoog staat (%.1f s)" % (float(f) / 60.0), f >= 0)
	await _frames(60 * 3)
	_check("en blijft aan jouw kant van de rivier (z %.1f, rivier %.1f)" % [j.global_position.z, rz], j.global_position.z > rz + D.RIVER_HALF and bj.waiting_bridge)
	_check("met een melding BRUG OMHOOG", _banners.any(func(s): return s.begins_with("BRUG OMHOOG")))
	G.bridge.toggle()   # omlaag
	f = await _until(func(): return j.global_position.z < rz - 6.0, 60 * 40)
	_check("brug omlaag: de jeep rijdt erover naar de stad (%.1f s)" % (float(f) / 60.0), f >= 0)
	f = await _until(func(): return bj.arrived, 60 * 30)
	_check("en rijdt door tot zijn doel op de weg (%.1f m ervandaan)" % _flat(j.global_position, goal), f >= 0 and _flat(j.global_position, goal) < 5.0 and not bj.vast)
	# terug naar jouw kant
	var back := Vector3(30.0, 0.0, rz + 40.0)
	ts.select([bj])
	ts.issue("move", back)
	f = await _until(func(): return bj.arrived, 60 * 60)
	_check("en weer terug naar jouw kant van de rivier (%.1f m ervandaan, %.1f s)" % [_flat(j.global_position, back), float(f) / 60.0], f >= 0 and _flat(j.global_position, back) < 5.0)
	bj.set_command("hold", Vector3.ZERO)
	ts.clear()
	_remove(j)
	await _frames(3)


# ---------------------------------------------------------------- naar de vijandbasis

func _test_basis() -> void:
	print("-- naar de vijandbasis")
	var D: Script = load("res://scripts/data.gd")
	var rz: float = D.river_z(D.BRIDGE_X)
	var VB: Script = load("res://scripts/vijand_basis.gd")
	var gate: Vector3 = VB.gate_outside()
	for gz in load("res://scripts/garnizoen.gd").get("all"):
		gz._leeg()   # F2: deze test gaat over de route; vijanden in de stadsgebouwen zouden de jeep onderweg beschieten
	var j := _vehicle("jeep", Vector3(D.BRIDGE_X, 0.0, rz + 25.0))
	await _frames(4)
	var bj := _bst(j)
	ts.select([bj])
	ts.issue("attack", VB.gate_inside())
	_check("aanval op de vijandbasis: bevel basis", bj.command == "basis")
	var st := {"z": 1.0e9}
	var f: int = await _until(func():
		st.z = minf(st.z, j.global_position.z)
		return st.z < gate.z + 25.0 or bj.vast or bj.dead, 60 * 70)
	var best_z: float = st.z
	_check("de jeep rijdt over de brug en de weg door de stad tot vlak bij de poort (laagste z %.0f, poort %.0f, %.1f s)" % [best_z, gate.z, float(f) / 60.0], f >= 0 and best_z < gate.z + 25.0 and not bj.vast)
	_remove(j)
	await _frames(3)
