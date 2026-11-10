extends SceneTree
## Test: bosbrand als kettingreactie (scripts/bosbrand.gd). Een ontploffing steekt planten aan, het vuur loopt door,
## dooft vanzelf, steekt de rivier niet over, verschroeit planten en doet schade aan de speler.
## Draaien: godot --headless --path . -s tests/bosbrand_test.gd --fixed-fps 60

var main: Node
var frames := 0
var fails := 0
var bb: GDScript
var spot := Vector3.ZERO
var hp0 := 0.0
var peak := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		push_error("BOSBRAND TEST FAIL: " + msg)


func _initialize() -> void:
	load("res://scripts/data.gd").set("mcv_autodeploy", true)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frames += 1
	var game := root.get_node("Game")
	if frames == 3:
		main.begin()
	if frames > 3 and game.state == "prep":
		game.prep_t = 1e9
	if frames == 120:
		bb = load("res://scripts/bosbrand.gd")
		var inst: Node = bb.get("_inst")
		_check(is_instance_valid(inst), "Bosbrand is niet aangemaakt door level.gd")
		if not is_instance_valid(inst):
			quit(1)
			return true
		# zoek het vak met de meeste planten tussen de basis en de rivier
		var best := 0.0
		for k: Vector2i in inst._index:
			var f: float = inst._fuel(k)
			var mid: Vector3 = inst._mid(k)
			if f > best and mid.z < -40.0 and mid.z > -80.0 and not inst._blocked(k):
				best = f
				spot = mid
		print("dichtste vak: ", spot, " brandstof ", best)
		_check(bb.call("catch_blast", Vector3(0, 0, 0), 4.0) == 0, "op de kale basis mag niets vlam vatten")
		_check(bb.call("catch_blast", Vector3(10.0, 0.0, load("res://scripts/data.gd").river_z(10.0)), 4.0) == 0, "in de rivier mag niets vlam vatten")
		game.player.global_position = spot
		hp0 = game.player.hp
		game.note_blast(spot, 4.0)
		_check(bb.call("burning_count") > 0, "de ontploffing stak niets aan")
		_check(bb.call("is_burning_at", spot), "het vak van de ontploffing brandt niet")
	if frames > 120 and bb != null:
		peak = maxi(peak, bb.call("burning_count"))
	if frames == 240:
		_check(game.player.hp < hp0, "de speler in het vuur kreeg geen schade (hp %s -> %s)" % [hp0, game.player.hp])
		game.player.global_position = Vector3(0, 0, 0)
	if frames == 120 + 60 * 75:
		var inst: Node = bb.get("_inst")
		print("verbrande vakken: ", inst.burned_total, ", piek tegelijk: ", peak, ", nog brandend: ", bb.call("burning_count"))
		_check(inst.burned_total >= 6, "het vuur verspreidde zich niet (%d vakken)" % inst.burned_total)
		_check(inst.burned_total <= 400, "het vuur liep uit de hand (%d vakken)" % inst.burned_total)
		_check(bb.call("burning_count") == 0, "na 75 s brandt het nog")
		_check(peak <= inst.MAX_BURNING, "meer brandende vakken dan het maximum")
		_check(bb.call("is_burned_at", spot) and not bb.call("is_burning_at", spot), "het eerste vak hoort verbrand en gedoofd te zijn")
		var scorched := 0
		var far := 0.0
		var data: GDScript = load("res://scripts/data.gd")
		for k: Vector2i in inst._cells:
			var mid: Vector3 = inst._mid(k)
			far = maxf(far, mid.distance_to(spot))
			_check(absf(mid.z - data.river_z(mid.x)) >= data.RIVER_HALF, "een vak in de rivier is verbrand: %s" % mid)
			for e: Dictionary in inst._index.get(k, []):
				if e.get("scorched", false):
					scorched += 1
		print("verschroeide planten: ", scorched, ", verste vak: ", snappedf(far, 0.1), " m")
		_check(scorched > 0, "geen verschroeide planten")
		_check(far <= (inst.GEN + 2) * inst.CELL * 1.5, "het vuur kwam verder dan GEN stappen")
		_check(inst._img.get_pixel(int((spot.x - inst.MAP_X0) / inst.MAP_TEXEL), int((spot.z - inst.MAP_Z0) / inst.MAP_TEXEL)).r > 0.9, "de grond is niet zwart op de brandkaart")
		_check(bb.call("catch_blast", spot, 4.0) == 0, "verbrand gebied mag niet opnieuw branden")
		print("BOSBRAND TEST OK" if fails == 0 else "BOSBRAND TEST: %d FOUT" % fails)
		quit(1 if fails > 0 else 0)
		return true
	return false
