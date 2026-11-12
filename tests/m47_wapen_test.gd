extends SceneTree
## Test: M-47 Muurbreker in het spel (winkelgegevens, wapenkeuze en een schot dat een huismuur echt stuk slaat).
## Draaien: godot --headless --path . -s tests/m47_wapen_test.gd --fixed-fps 60

var main: Node
var frames := 0
var fails := 0
var h
var player
var wall_before := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		push_error("M47 WAPEN TEST: " + msg)


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frames += 1
	var game = root.get_node("Game")
	if frames == 3:
		main.begin()
		return false
	if frames == 6:
		var w: Dictionary = Data.WEAPONS["m47"]
		_check(int(w.price) == 500, "prijs is niet 500")
		_check(Data.WEAPON_ORDER.has("m47"), "niet in de winkelvolgorde")
		game.points = 1000
		_check(game.buy(500), "kopen mislukt")
		game.owned["m47"] = {"up": {"dmg": 0, "rate": 0, "mag": 0, "rel": 0}, "ammo": w.mag}
		_check(game.take_weapon("m47"), "niet in het wapenwiel (loadout)")
		_check(game.carries("m47"), "niet meegenomen")
		player = game.player
		_check(player != null, "geen speler")
		if player != null:
			player.equip("m47")
			_check(player.weapon == "m47", "wapen niet gekozen")
			if player.model.meshy_player:
				_check(player.model._weapon_kind == "m47", "model houdt het M-47 niet vast")
		h = load("res://scripts/woonhuis.gd").place(main, Vector3(300, 0, 300), 0.0, "woonhuis")
		return false
	if frames == 9:
		wall_before = 0
		for s in h.segs:
			wall_before += 1 if int(s.staat) == 0 else 0
		# speler 10 m ten westen van het huis, kijkt naar +X (face = PI/2)
		var from: Vector3 = h.global_position + Vector3(-10.0, 1.3, 0.0)
		for i in 3:
			load("res://scripts/m47_shot.gd").call("fire", main, from, PI * 0.5, 520.0, 6.0)
		return false
	if frames == 120:
		# eigen kampmuur: stukken zetten en schieten; vijandelijke basismuur: schieten op de westmuur
		var b = game.builds
		var wall_nodes := []
		game.mcv_deployed = true
		var base_at: Vector3 = player.global_position + Vector3(14.0, 0, 14.0)
		for i in 3:
			var bd = b.place("kampmuur", base_at + Vector3(i * 3.5, 0, 0), 0.0, false, true)
			_check(bd != null, "kampmuur plaatsen mislukt")
			if bd != null:
				wall_nodes.append(bd)
		set_meta("walls", wall_nodes)
		var vb = load("res://scripts/vijand_basis.gd")
		set_meta("vb_voor", vb.call("muur_over"))
		var sh = load("res://scripts/m47_shot.gd")
		sh.call("fire", main, base_at + Vector3(3.5, 1.3, -10.0), 0.0, 520.0, 6.0)
		var p0: Vector3 = Data.VIJAND_POS
		sh.call("fire", main, Vector3(p0.x - Data.VIJAND_HALF.x - 10.0, 1.3, p0.z), PI * 0.5, 520.0, 6.0)
		return false
	if frames > 9 and frames < 300 and frames != 120:
		return false
	if frames == 300:
		var heel := 0
		for s in h.segs:
			heel += 1 if int(s.staat) == 0 else 0
		print("muurstukken heel: ", wall_before, " -> ", heel, " (ingestort: ", h._ruin or h._collapsed, ")")
		_check(heel < wall_before or h._ruin or h._collapsed, "huis is niet beschadigd door drie M-47 schoten")
		var down := 0
		for bd in get_meta("walls"):
			down += 0 if game.buildings.has(bd) else 1
		print("kampmuurstukken stuk: ", down, " van ", get_meta("walls").size())
		_check(down >= 2, "eigen kampmuur breekt niet (stuk: %d)" % down)
		var vb2 = load("res://scripts/vijand_basis.gd")
		print("vijandmuur stukken: ", get_meta("vb_voor"), " -> ", vb2.call("muur_over"))
		_check(int(vb2.call("muur_over")) < int(get_meta("vb_voor")), "vijandelijke basismuur breekt niet")
		print("M47_WAPEN_TEST ", "OK" if fails == 0 else "FOUT")
		quit(1 if fails > 0 else 0)
	return false
