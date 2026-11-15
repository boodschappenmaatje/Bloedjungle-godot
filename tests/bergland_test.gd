extends SceneTree
## Test (dambreuk-plan stap 1, diepte): het bergland rond de kaart laat het speelveld ongemoeid (hoogte 0 op de hele
## grondplaat), loopt daarbuiten op, heeft een rivierdal en een kloof naar het stuwmeer, en blijft binnen het budget.
## Draaien: godot --headless --path . -s tests/bergland_test.gd

var frames := 0
var main: Node


func _fail(msg: String) -> void:
	print("FAIL ", msg)


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frames += 1
	if frames < 4:
		return false
	# 1. terrassen blijven precies vlak: kamp, stad, vijandbasis, oevers en de overgangen (brug, ondiepte, Backdoor)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 600:
		var x := 0.0
		var z := 0.0
		match i % 5:
			0:   # kamp en startplek
				x = rng.randf_range(-50.0, 50.0)
				z = rng.randf_range(-32.0, 60.0)
			1:   # stad
				x = rng.randf_range(-Bergland.CITY_HALF_X, Bergland.CITY_HALF_X)
				z = rng.randf_range(-230.0, -100.0)
			2:   # vijandbasis
				x = rng.randf_range(Data.VIJAND_POS.x - Data.VIJAND_HALF.x, Data.VIJAND_POS.x + Data.VIJAND_HALF.x)
				z = rng.randf_range(Data.VIJAND_POS.z - Data.VIJAND_HALF.y, Data.VIJAND_POS.z + Data.VIJAND_HALF.y)
			3:   # strook langs de rivier (3 m) en de oversteken (ruim 5 m breed)
				x = rng.randf_range(-190.0, 190.0)
				z = Data.river_z(x) + rng.randf_range(-3.4, 3.4)
			4:
				var cx: float = [Data.BRIDGE_X, Data.FORD_X, Data.BACKDOOR_X][rng.randi() % 3]
				x = cx + rng.randf_range(-5.0, 5.0)
				z = Data.river_z(x) + rng.randf_range(-20.0, 20.0)
		if Data.ground_y(x, z) != 0.0:
			_fail("terras niet vlak bij %s: %.2f" % [Vector2(x, z), Data.ground_y(x, z)])
			return true
	# 1b. er is wel reliëf: heuvelrug langs de zuidoever, noordoever buiten de stad en hoge flanken, nergens te steil
	var top_berm := 0.0
	var top_flank := 0.0
	var steepest := 0.0
	for i in 4000:
		var x := rng.randf_range(-Bergland.PLATE_X, Bergland.PLATE_X)
		var z := rng.randf_range(Bergland.PLATE_Z_N, Bergland.PLATE_Z_S)
		var y := Data.ground_y(x, z)
		if absf(x) < 130.0:
			top_berm = maxf(top_berm, y)
		else:
			top_flank = maxf(top_flank, y)
		var gx := (Data.ground_y(x + 1.0, z) - Data.ground_y(x - 1.0, z)) * 0.5
		var gz := (Data.ground_y(x, z + 1.0) - Data.ground_y(x, z - 1.0)) * 0.5
		steepest = maxf(steepest, sqrt(gx * gx + gz * gz))
	if top_berm < 1.5:
		_fail("heuvelrug langs de rivier te laag: %.2f" % top_berm)
	if top_flank < 3.0:
		_fail("flanken te laag: %.2f" % top_flank)
	if steepest > 0.2:
		_fail("te steil voor voertuigen: helling %.2f" % steepest)
	print("reliëf: heuvelrug ", snappedf(top_berm, 0.01), " m, flank ", snappedf(top_flank, 0.01), " m, steilste helling ", snappedf(steepest, 0.001))
	# 1c. de plaatrand sluit aan op het bergland erbuiten (geen scheur in het landschap)
	for z in range(-290, 211, 25):
		var inside := Data.ground_y(Bergland.PLATE_X - 0.5, z)
		var outside := Data.ground_y(Bergland.PLATE_X + 0.5, z)
		if absf(inside - outside) > 0.4 and z > -270 and absf(z - Data.river_z(Bergland.PLATE_X)) > 20.0:
			_fail("scheur aan de plaatrand bij z=%d: %.2f naast %.2f" % [z, inside, outside])
	# 2. vliegtuigen (12 m) blijven vrij in de eerste 60 m buiten de kaart, behalve de kloofwanden in het noorden
	for x in range(-280, 281, 20):
		for z in [Bergland.PLATE_Z_S + 50.0]:
			if Data.ground_y(x, z) > 11.0:
				_fail("heuvel te hoog vlak buiten de zuidrand bij %s: %.1f" % [Vector2(x, z), Data.ground_y(x, z)])
	# 3. bergen in het noorden zijn echt hoog, kloof en bekken zijn laag
	var top := 0.0
	for x in range(-700, 701, 20):
		top = maxf(top, Data.ground_y(x, -620.0))
	if top < 35.0:
		_fail("noordelijke bergen te laag: %.1f" % top)
	var gorge := Data.ground_y(Bergland.gorge_x(Bergland.DAM_Z + 20.0), Bergland.DAM_Z + 20.0)   # voor de dam (de kroon zelf ligt 14 m hoger)
	if absf(gorge - Bergland.DAM_FLOOR) > 1.5:
		_fail("kloofbodem bij de dam op %.1f in plaats van %.1f" % [gorge, Bergland.DAM_FLOOR])
	var wall := Data.ground_y(Bergland.gorge_x(Bergland.DAM_Z) + 70.0, Bergland.DAM_Z)
	if wall < Bergland.LAKE_Y + 4.0:
		_fail("kloofwand naast de dam te laag voor het stuwmeer: %.1f" % wall)
	if Data.ground_y(Bergland.BASIN.x, Bergland.BASIN.y) > Bergland.BASIN_FLOOR + 1.0:
		_fail("stuwmeerbekken niet laag")
	# 4. rivierdal buiten de plaat ligt onder het water
	for x in [260.0, -260.0, 500.0, -500.0]:
		var rz := Data.river_z(clampf(x, -Bergland.RIVER_X_MAX, Bergland.RIVER_X_MAX))
		if Data.ground_y(x, rz) > Bergland.RIVER_WATER_Y:
			_fail("rivierdal bij x=%.0f boven het water" % x)
	# 5. mesh-budget en aanwezigheid in de wereld
	var mesh := Bergland.build_mesh()
	var tris := mesh.surface_get_array_index_len(0) / 3
	print("bergland driehoeken: ", tris)
	if tris > 45000:
		_fail("bergland te zwaar: %d driehoeken" % tris)
	if main.get_node("Level").find_child("Bergen", true, false) == null:
		_fail("bergland niet in de wereld")
	print("bergland_test klaar")
	return true
