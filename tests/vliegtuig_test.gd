extends SceneTree
## Vliegtuig (stap 1): echt spel, vliegveld neerzetten, toestel staat in de hangar, instappen, taxiën, opstijgen,
## vliegen, landen (automatisch uitrollen en terug de hangar in), neerstorten tegen muur en boom, hoog erover = geen crash.
## Draaien: godot --headless --path . -s tests/vliegtuig_test.gd --fixed-fps 60

var failures := 0
var game
var main: Node
var plane
var V
var AH
var AF
var FO
var cx: Node3D


func _initialize() -> void:
	# scripts pas laden als de autoloads er zijn (anders compileert Sfx/Game niet)
	V = load("res://scripts/vliegtuig.gd")
	AH = load("res://scripts/airfield_hq_23.gd")
	AF = load("res://scripts/airfield_flight_integration.gd")
	FO = load("res://scripts/foliage.gd")
	root.size = Vector2i(932, 430)
	call_deferred("_run")


func _check(name: String, ok: bool) -> void:
	print(("OK    " if ok else "FAIL  ") + name)
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for _i in n:
		await physics_frame


func _until(cond: Callable, max_frames: int) -> bool:
	for _i in max_frames:
		if cond.call():
			return true
		await physics_frame
	return cond.call()


## Zet het toestel op de grond/in de lucht op een vliegveldpunt (x, z in vliegveldcoördinaten) met koers (rad).
func _put(ax: float, az: float, heading: float, alt: float, spd: float, mode) -> void:
	var w: Vector3 = cx.to_global(AH.layout_point(ax, az, 0.0))
	plane.global_position = Vector3(w.x, plane.ground_y(w) + alt, w.z)
	plane.rotation.y = cx.global_rotation.y + heading
	plane.speed = spd
	plane.alt = alt
	plane.mode = mode


func _new_plane() -> void:
	if is_instance_valid(plane) and plane.driven:
		plane._leave(game.player, false)
	if is_instance_valid(plane):
		plane.queue_free()
	await _frames(2)
	plane = V.spawn(airfield)
	await _frames(2)


var airfield: Dictionary


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	game = root.get_node("Game")
	await _frames(3)
	await main.call("begin")
	var pause_menu := get_first_node_in_group("menus")
	if pause_menu != null:
		pause_menu.call("_show", "")
	await _frames(3)
	game.build_credit = 100000
	game.points = 100000
	var at := Vector3(70.0, 0.0, 115.0)
	var b = game.builds.place("airfield", at, 0.0)
	_check("vliegveld staat", b != null)
	if b == null:
		quit(1)
		return
	airfield = b
	cx = b.node.get_meta("complex")
	var ok := await _until(func(): return b.aircraft.size() == 1 and is_instance_valid(b.aircraft[0].node), 240)
	_check("het vliegveld zet vanzelf een toestel klaar", ok)
	plane = b.aircraft[0].node
	await _frames(5)
	_check("toestel past in de hangar (span %.1f m, lengte %.1f m)" % [plane._span, plane._len], plane._hangar_fit)
	_check("toestel geparkeerd en in de hangar", plane.mode == V.Mode.PARKED and plane.on_pavement(plane.global_position) == false and plane._inside_hangar())
	var gl: Vector3 = plane.global_position
	_check("model staat met de wielen op de vloer (y=%.2f)" % gl.y, absf(gl.y - V.PAVEMENT_Y) < 0.03)
	# schaduw en camera-extra bij stilstand
	_check("camera_extra in rust is 0 (alt 0, snelheid 0)", plane.camera_extra() == 0.0)

	# ---------------------------------------------------------------- instappen
	var p = game.player
	p.global_position = plane.global_position + Vector3(4, 0, 4)
	await _frames(10)
	plane._press()
	_check("instappen: speler zit in het toestel", plane.driven and p.driving and p.airborne and not p.visible)
	_check("hangardeuren in de groep 'voertuigen'", plane.is_in_group("voertuigen"))
	# nog niet gas: blijft staan
	plane.override_move = Vector2.ZERO
	await _frames(30)
	_check("stick los op de grond: blijft staan", plane.speed < 0.1)
	# uitstappen en weer instappen
	plane._press()
	_check("UIT op de grond bij stilstand", not plane.driven and p.visible and not p.driving)
	plane._press()
	_check("opnieuw instappen", plane.driven)

	# ---------------------------------------------------------------- taxiën door de deur
	# hangardeur is dicht tot een voertuig dichtbij komt: naar het zuiden rijden (stick omlaag)
	plane.override_move = Vector2(0, 1)
	var z0: float = cx.to_local(plane.global_position).z
	var out := await _until(func(): return cx.to_local(plane.global_position).z > 14.0, 600)
	_check("rijdt de hangar uit (deuren gingen open, z=%.1f)" % cx.to_local(plane.global_position).z, out)
	_check("speler volgt het toestel", p.global_position.distance_to(Vector3(plane.global_position.x, 0, plane.global_position.z)) < 0.1)
	plane.override_move = Vector2.ZERO
	await _frames(60)

	# ---------------------------------------------------------------- opstijgen
	# begin van de baan aan de oostkant, koers west (stick naar links)
	_put(AF.TAKEOFF_START_X, AH.RUNWAY_CENTER_Z, PI * 0.5, 0.0, 0.0, V.Mode.GROUND)
	plane.override_move = Vector2(-1, 0)
	plane.override_climb = 1.0
	await _frames(20)
	_check("te langzaam om op te stijgen (v=%.1f)" % plane.speed, plane.mode == V.Mode.GROUND and plane.speed < V.LIFTOFF)
	var lifted := await _until(func(): return plane.mode == V.Mode.AIR, 240)
	var local_x: float = cx.to_local(plane.global_position).x
	_check("opgestegen na rol (x=%.1f van baan %.1f..%.1f, v=%.1f)" % [local_x, AH.RUNWAY_START_X, AH.RUNWAY_END_X, plane.speed], lifted and local_x > AH.RUNWAY_START_X + 2.0)
	await _frames(60)
	_check("klimt (hoogte %.1f m)" % plane.alt, plane.alt > 4.0)
	_check("camera zoomt mee uit (+%.1f m)" % plane.camera_extra(), plane.camera_extra() > 5.0)
	_check("schaduw ligt op de grond onder het toestel", plane._shadow.visible and plane._shadow.global_position.y < 1.0)
	# hoogte vasthouden
	plane.override_climb = 0.0
	var a1: float = plane.alt
	await _frames(30)
	_check("rechterstick los: hoogte blijft", absf(plane.alt - a1) < 0.01)

	# ---------------------------------------------------------------- sturen en snelheid
	plane.override_move = Vector2.ZERO
	await _frames(330)
	_check("stick los in de lucht: minimumsnelheid %.1f" % plane.speed, absf(plane.speed - V.MIN_AIR) < 0.5 and plane.mode == V.Mode.AIR)
	plane.override_move = Vector2(0, -1)   # naar het noorden
	await _frames(200)
	_check("volgt de stick (koers noord)", absf(wrapf(plane.rotation.y, -PI, PI)) < 0.15)
	_check("volle stick = topsnelheid (%.1f)" % plane.speed, plane.speed > V.MAX_SPEED - 1.0)
	plane.override_move = Vector2(0.5, 0)
	await _frames(240)
	_check("halve stick = halverwege (%.1f)" % plane.speed, plane.speed > 20.0 and plane.speed < 25.0)

	# ---------------------------------------------------------------- landen
	# laag aanvliegen boven asfalt, langzaam, stick omhoog (dalen)
	_put(AH.RUNWAY_START_X - 8.0, AH.RUNWAY_CENTER_Z + 2.0, -PI * 0.5, 6.0, 15.0, V.Mode.AIR)   # koers oost over de baan (net voor het begin)
	plane.override_move = Vector2(0.14, 0)   # net boven de dode zone: ~minimaal
	plane.override_climb = -1.0
	var landed := await _until(func(): return plane.mode == V.Mode.ROLLOUT, 600)
	_check("auto-landing boven asfalt, laag en langzaam", landed)
	var down := await _until(func(): return plane.mode == V.Mode.TAXI, 600)
	_check("uitgerold en gestopt, rijdt naar de hangar", down)
	plane.override_climb = null
	plane.override_move = null
	var parked := await _until(func(): return plane.mode == V.Mode.PARKED, 3600)
	_check("terug in de hangar geparkeerd (taxi duurde ok)", parked and plane._inside_hangar())
	_check("speler uitgestapt en weer zichtbaar", not plane.driven and p.visible and not p.driving and not p.airborne)
	_check("speler staat voor de hangardeur (z=%.1f)" % cx.to_local(p.global_position).z, absf(cx.to_local(p.global_position).z - 11.5) < 1.0)

	# ---------------------------------------------------------------- niet op gras landen
	await _new_plane()
	p.global_position = plane.global_position + Vector3(4, 0, 4)
	await _frames(5)
	plane._press()
	var gx := Vector3.ZERO   # open gras (geen asfalt, geen boom, geen muur) in de buurt
	# vliegveldmaten: het zoekgebied is 1/SCALE groter zodat de grasplek even ver van de gebouwen ligt als vroeger
	for gz in range(-100, 166, 10):
		for gxx in range(-116, 116, 10):
			var cand: Vector3 = cx.to_global(AH.layout_point(float(gxx), float(gz), 0.0))
			plane.global_position = Vector3(cand.x, 0.0, cand.z)
			if not plane.on_pavement(cand) and not FO.has_tree_near(cand.x, cand.z, 14.0) and not plane._blocked(8.0, 1.0):
				gx = cand
				break
		if gx != Vector3.ZERO:
			break
	_check("open grasplek gevonden", gx != Vector3.ZERO)
	plane.global_position = Vector3(gx.x, 5.0, gx.z)
	plane.mode = V.Mode.AIR
	plane.alt = 5.0
	plane.speed = 15.0
	plane.rotation.y = 0.0
	plane.override_move = Vector2(0.14, 0)
	plane.override_climb = -1.0
	await _frames(240)
	print("DEBUG mode=%s alt=%.2f driven=%s exploded=%s pos=%s" % [plane.mode, plane.alt, plane.driven, plane.exploded, plane.global_position])
	_check("op gras niet landen: blijft op minimale vlieghoogte (%.1f m)" % plane.alt, plane.mode == V.Mode.AIR and absf(plane.alt - V.MIN_FLY_ALT) < 0.05)

	# ---------------------------------------------------------------- hoog over de hangar = geen crash
	_put(0.0, 40.0, 0.0, 12.0, 20.0, V.Mode.AIR)   # koers noord, recht op de hangar af
	plane.override_move = Vector2(0, -0.5)
	plane.override_climb = 0.0
	await _frames(240)
	_check("op 12 m over de hangar: geen crash", plane.mode == V.Mode.AIR and not plane.exploded)

	# ---------------------------------------------------------------- tegen de hangar aan = crash
	_put(0.0, 40.0, 0.0, 2.0, 20.0, V.Mode.AIR)
	plane.override_move = Vector2(0, -0.5)
	plane.override_climb = 0.0
	var hp0: float = p.hp
	var crashed := await _until(func(): return plane.mode == V.Mode.WRECK, 240)
	_check("laag tegen de hangar: neergestort", crashed)
	_check("speler uit het toestel, zichtbaar", not plane.driven and p.visible and not p.driving and not p.airborne)
	_check("wrak: niet meer in groep voertuigen, schaduw weg", not plane.is_in_group("voertuigen") and not plane._shadow.visible)
	await _frames(5)
	_check("ontploffing kost de speler hp (%.0f -> %.0f)" % [hp0, p.hp], p.hp < hp0 or p.dead)
	_check("na een tijd komt er een nieuw toestel", await _until(func(): return b.aircraft.size() == 1 and is_instance_valid(b.aircraft[0].node) and b.aircraft[0].node != plane, 4000))

	# ---------------------------------------------------------------- tegen een boom = crash
	if p.dead:
		p.dead = false
		p.hp = p.get("max_hp") if p.get("max_hp") != null else 100.0
	plane = b.aircraft[0].node
	var tree := Vector2.ZERO
	for t in FO.trees:
		if Vector2(t.x - at.x, t.y - at.z).length() > 60.0 and Vector2(t.x, t.y).length() < 150.0:
			tree = Vector2(t.x, t.y)
			break
	if tree == Vector2.ZERO:
		print("SKIP  geen boom gevonden")
	else:
		p.global_position = plane.global_position + Vector3(4, 0, 4)
		await _frames(5)
		plane._press()
		plane.global_position = Vector3(tree.x, 3.0, tree.y + 20.0)
		plane.mode = V.Mode.AIR
		plane.alt = 3.0
		plane.speed = 20.0
		plane.rotation.y = 0.0   # noord, de boom in
		plane.override_move = Vector2(0, -0.5)
		plane.override_climb = 0.0
		var tc := await _until(func(): return plane.mode == V.Mode.WRECK, 240)
		_check("laag tegen een boom: neergestort", tc)
	print("klaar: %d fouten" % failures)
	quit(1 if failures > 0 else 0)
