extends SceneTree
## Test: wereld per start (W2) - de rivier kronkelt elk spel anders en de doorwaadplaats schuift mee, maar de vaste
## Data.WORLD_SEED_DEFAULT (editor, headless, tests) blijft precies de oude vaste rivier (zelfde kronkel, FORD_X = 38.0).
## De brug blijft altijd op x = 0 (StadData.ITEMS sluit daar met een vaste straat op aan).
## Draaien: godot --headless --path . -s tests/rivier_seed_test.gd --fixed-fps 60

var fails := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		push_error("RIVIER SEED TEST FAIL: " + msg)


func _sample(seed_: int) -> Dictionary:
	Data.world_seed = seed_
	Data._randomize_river()
	var zs := PackedFloat32Array()
	var x := -80.0
	while x <= 80.0:
		zs.append(Data.river_z(x))
		x += 4.0
	return {"zs": zs, "ford": Data.FORD_X}


func _initialize() -> void:
	# Vaste standaard-seed: exact de oude vaste rivier en doorwaadplaats.
	Data.world_seed = Data.WORLD_SEED_DEFAULT
	Data._randomize_river()
	_check(is_equal_approx(Data.river_z(0.0), Data.RIVER_Z0 + 2.0 * sin(1.0)), "bij de vaste standaard-seed moet de oude rivierformule ongewijzigd blijven")
	_check(is_equal_approx(Data.FORD_X, 38.0), "bij de vaste standaard-seed moet FORD_X op de oude vaste 38.0 blijven")
	_check(is_equal_approx(Data.BRIDGE_X, 0.0), "de brug blijft altijd op x=0, ook bij een willekeurige seed")
	print("stap 1 ok: vaste standaard-seed geeft de oude rivier en FORD_X=38.0")

	# Twee verschillende willekeurige seeds: andere kronkel, andere doorwaadplaats.
	var a := _sample(4242)
	var b := _sample(99001)
	_check(a.zs != b.zs, "twee verschillende seeds moeten een andere rivier-kronkel geven")
	_check(not is_equal_approx(a.ford, 38.0), "een willekeurige seed mag niet de oude vaste FORD_X teruggeven")
	_check(not is_equal_approx(b.ford, 38.0), "een willekeurige seed mag niet de oude vaste FORD_X teruggeven")
	_check(a.ford != b.ford, "twee verschillende seeds moeten een andere doorwaadplaats geven")
	_check(absf(a.ford) >= 20.0 and absf(a.ford) <= 65.0, "FORD_X moet ruim weg blijven van de brug en van de kaartrand")
	_check(absf(b.ford) >= 20.0 and absf(b.ford) <= 65.0, "FORD_X moet ruim weg blijven van de brug en van de kaartrand")
	print("stap 2 ok: seed 4242 FORD_X=", a.ford, ", seed 99001 FORD_X=", b.ford)

	# Dezelfde seed nog eens: exact dezelfde rivier terug (reproduceerbaar).
	var a2 := _sample(4242)
	_check(a2.zs == a.zs, "dezelfde seed moet twee keer precies dezelfde rivier-kronkel geven")
	_check(is_equal_approx(a2.ford, a.ford), "dezelfde seed moet twee keer precies dezelfde doorwaadplaats geven")
	print("stap 3 ok: seed 4242 herhaald geeft dezelfde rivier")

	# Terug naar de vaste standaard-seed: weer exact de oude rivier (geen lekkage tussen seeds).
	Data.world_seed = Data.WORLD_SEED_DEFAULT
	Data._randomize_river()
	_check(is_equal_approx(Data.river_z(0.0), Data.RIVER_Z0 + 2.0 * sin(1.0)), "terug naar de standaard-seed moet weer exact de oude rivier geven")
	_check(is_equal_approx(Data.FORD_X, 38.0), "terug naar de standaard-seed moet FORD_X weer op 38.0 zetten")
	print("stap 4 ok: terug naar de standaard-seed geeft weer de oude rivier")

	if fails == 0:
		print("RIVIER SEED TEST OK")
	quit(1 if fails > 0 else 0)
