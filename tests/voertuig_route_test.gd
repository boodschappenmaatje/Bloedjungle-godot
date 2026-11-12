extends SceneTree
## Test van de weg die je eigen jeep en tank rijden als ze een bevel krijgen (VoertuigRoute, stap "voertuigbevel", Dennis' keuze 6A van 11 november 2026): vrij rijden ten zuiden van de rivier,
## over de brug, en in de stad en aan de vijandkant alleen over de vaste voertuigroute (AanvalRoutes.voertuig_pad, omgekeerd). Het is een rekensom zonder wereld.
## godot --headless --path . --script tests/voertuig_route_test.gd
## De klassen die de autoload Game gebruiken laden we pas tijdens het draaien (bij het compileren van dit bestand bestaat Game nog niet).

var fails := 0
var R: Script
var D: Script
var A: Script


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	R = load("res://scripts/voertuig_route.gd")
	D = load("res://scripts/data.gd")
	A = load("res://scripts/aanval_routes.gd")
	var rz: float = D.river_z(D.BRIDGE_X)
	var south := Vector3(40.0, 0.0, 20.0)
	var south2 := Vector3(-30.0, 0.0, -40.0)
	var north := Vector3(-6.0, 0.0, -118.5)   # een hoekpunt van de voertuigroute in de stad

	# kanten van de rivier
	_check("zuid van de rivier is kant 1", R.side(Vector3(0.0, 0.0, rz + 10.0)) == 1)
	_check("noord van de rivier is kant -1", R.side(Vector3(0.0, 0.0, rz - 10.0)) == -1)
	_check("in de rivierstrook is kant 0", R.side(Vector3(0.0, 0.0, rz)) == 0)

	# de oversteek: voor de brug, op de brug, erachter
	var cn: Array = R.crossing(true)
	var cs: Array = R.crossing(false)
	_check("oversteek naar het noorden: drie punten, eerst zuid, dan brug, dan noord", cn.size() == 3 and R.side(cn[0]) == 1 and R.side(cn[1]) == 0 and R.side(cn[2]) == -1)
	_check("oversteek naar het zuiden is de omgekeerde volgorde", cs.size() == 3 and _flat(cs[0], cn[2]) < 0.01 and _flat(cs[2], cn[0]) < 0.01)
	_check("de oversteek ligt op de brug (x = BRUG)", absf(cn[1].x - D.BRIDGE_X) < 0.01 and absf(cn[1].z - rz) < 0.01)

	# de vaste lijn: van de brug naar de poort van de vijandbasis, voor jeep en tank
	for tank in [false, true]:
		var line: Array = R.north_line(tank)
		var gate: Vector3 = load("res://scripts/vijand_basis.gd").gate_outside()
		_check("%s: de lijn begint bij de brug en eindigt bij de poort van de vijandbasis" % ("tank" if tank else "jeep"), line.size() > 8 and _flat(line[0], Vector3(0.0, 0.0, -103.0)) < 0.5 and _flat(line.back(), gate) < 0.5)
		_check("%s: de lijn is dezelfde als die van de vijandelijke voertuigen, omgekeerd" % ("tank" if tank else "jeep"), _flat(line[0], A.voertuig_pad(tank).back()) < 0.01)
		# het dichtstbijzijnde punt op de lijn
		var v1: Vector3 = line[3]
		var pr: Dictionary = R.project(line, v1 + Vector3(1.0, 0.0, 0.0))
		_check("%s: een punt naast een hoekpunt valt op de lijn (t = 3, afstand 1 m)" % ("tank" if tank else "jeep"), absf(float(pr.t) - 3.0) < 0.6 and absf(float(pr.d) - 1.0) < 0.6)
		var w: Array = R.walk(line, 1.5, 4.5)
		_check("%s: lopen langs de lijn van t 1,5 naar 4,5: eerst een tussenpunt, dan hoekpunten 2, 3 en 4, dan het eindpunt" % ("tank" if tank else "jeep"), w.size() == 5 and _flat(w[1], line[2]) < 0.01 and _flat(w[3], line[4]) < 0.01)
		var wb: Array = R.walk(line, 4.5, 1.5)
		_check("%s: de andere kant op krijg je dezelfde punten omgekeerd" % ("tank" if tank else "jeep"), wb.size() == 5 and _flat(wb[1], line[4]) < 0.01 and _flat(wb[3], line[2]) < 0.01)

	# een rit in je eigen gebied: rechtstreeks
	var p1: Dictionary = R.plan(south, south2, false)
	_check("zuid naar zuid: een punt, geen oversteek, niet kort", p1.pts.size() == 1 and _flat(p1.pts[0], south2) < 0.01 and int(p1.cross) == -1 and not bool(p1.short))

	# naar de stad: over de brug, dan de weg
	var p2: Dictionary = R.plan(south, north, false)
	var pts2: Array = p2.pts
	_check("zuid naar de stad: eerst voor de brug, dan op de brug", pts2.size() >= 4 and R.side(pts2[0]) == 1 and R.side(pts2[1]) == 0 and int(p2.cross) == 1)
	_check("zuid naar de stad: de rit eindigt op het doel op de weg en is niet kort", _flat(pts2.back(), north) < 1.0 and _flat(p2.reach, north) < 1.0 and not bool(p2.short))
	var all_north := true
	for i in range(2, pts2.size()):
		if R.side(pts2[i]) != -1:
			all_north = false
	_check("zuid naar de stad: na de brug blijft hij aan de noordkant", all_north)

	# een tik naast de weg in de stad: rijden tot de weg, daar stoppen, kort
	var off_road := Vector3(-60.0, 0.0, -150.0)
	var p3: Dictionary = R.plan(south, off_road, true)
	_check("tik naast de weg: kort, en de rit eindigt op de weg (niet op het doel)", bool(p3.short) and _flat(p3.reach, off_road) > R.NEAR_ROAD and _flat(p3.pts.back(), p3.reach) < 0.01)

	# naar de vijandbasis: de weg loopt door tot de poort
	var base_in: Vector3 = load("res://scripts/vijand_basis.gd").gate_inside()
	var p4: Dictionary = R.plan(south, base_in, false)
	var gate_o: Vector3 = load("res://scripts/vijand_basis.gd").gate_outside()
	_check("naar de vijandbasis: de weg loopt tot de poort", _flat(p4.pts.back(), gate_o) < 8.0)

	# in de stad: van punt naar punt langs de weg
	var north2: Vector3 = R.north_line(false)[8]
	var p5: Dictionary = R.plan(north, north2, false)
	_check("stad naar stad: langs de lijn, geen oversteek", p5.pts.size() >= 2 and int(p5.cross) == -1 and _flat(p5.pts.back(), north2) < 1.0)

	# terug naar je eigen gebied: eerst langs de weg naar de brug, dan over de brug, dan naar het doel
	var p6: Dictionary = R.plan(north2, south, false)
	var pts6: Array = p6.pts
	var cross6 := int(p6.cross)
	_check("stad naar zuid: de brug zit in de rit, en daarna volgen een punt achter de brug en het doel", cross6 >= 1 and cross6 + 2 < pts6.size() and absf(pts6[cross6].z - rz) < 0.01 and _flat(pts6.back(), south) < 0.01)
	_check("stad naar zuid: voor de brug rijdt hij over de weg (eerste punt ligt op de lijn)", float(R.project(R.north_line(false), pts6[0]).d) < 1.0)

	# een doel in de rivier wordt een punt vlak aan de kant van de aanrijder
	var p7: Dictionary = R.plan(south, Vector3(60.0, 0.0, D.river_z(60.0)), false)
	_check("doel in de rivier: de rit stopt aan jouw kant van de rivier", R.side(p7.pts.back()) == 1)

	# op de brug zelf begint hij gewoon waar hij heen moet
	var on_bridge := Vector3(D.BRIDGE_X, 0.0, rz)
	var p8: Dictionary = R.plan(on_bridge, north, false)
	_check("vanaf de brug naar de stad: door naar het noorden", p8.pts.size() >= 1 and R.side(p8.pts.back()) == -1)

	print("klaar, fouten: ", fails)
	quit(1 if fails > 0 else 0)
