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
	# 1. speelveld blijft plat
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 400:
		var x := rng.randf_range(-Bergland.PLATE_X, Bergland.PLATE_X)
		var z := rng.randf_range(Bergland.PLATE_Z_N, Bergland.PLATE_Z_S)
		if Data.ground_y(x, z) != 0.0:
			_fail("grond niet plat op de plaat bij %s" % Vector2(x, z))
			return true
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
	var gorge := Data.ground_y(Bergland.gorge_x(Bergland.DAM_Z), Bergland.DAM_Z)
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
