extends SceneTree
## Test: je draagt maximaal 5 wapens; inleveren geeft de helft terug. Draaien: godot --headless --path . -s tests/loadout_test.gd

var fails := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		push_error("LOADOUT TEST: " + msg)


func _initialize() -> void:
	var game = root.get_node("Game")
	game.reset()
	_check(not game.loadout_full(), "vol bij het begin")
	for id in ["thompson", "garand", "trench", "mg42"]:
		game.owned[id] = {"up": {"dmg": 0, "rate": 0, "mag": 0, "rel": 0}, "ammo": 5}
	_check(game.owned.size() == 5 and game.loadout_full(), "5 wapens is niet vol")
	var p0: int = game.points
	game.cur = "mg42"
	game.drop_weapon("mg42")
	_check(not game.owned.has("mg42"), "wapen is niet ingeleverd")
	_check(game.points - p0 == 1400, "terugbetaling klopt niet: %d" % (game.points - p0))
	_check(game.cur != "mg42" and game.owned.has(game.cur), "actief wapen is niet doorgeschakeld")
	_check(not game.loadout_full(), "na inleveren is er geen plek")
	for id in ["thompson", "garand", "trench"]:
		game.drop_weapon(id)
	game.drop_weapon("m1911")
	_check(game.owned.size() == 1, "het laatste wapen mag niet weg")
	if fails == 0:
		print("LOADOUT TEST PASS: maximaal 5 wapens, inleveren geeft de helft terug")
	quit(1 if fails > 0 else 0)
