extends SceneTree
## Test: je neemt maximaal 5 wapens mee; gekochte wapens blijven van jou en kunnen terug in de wapenkamer.
## Draaien: godot --headless --path . -s tests/loadout_test.gd

var fails := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		push_error("LOADOUT TEST: " + msg)


func _initialize() -> void:
	var game = root.get_node("Game")
	game.reset()
	_check(game.loadout == ["m1911"], "begin-loadout klopt niet")
	for id in ["thompson", "garand", "trench", "mg42", "bazooka"]:
		game.owned[id] = {"up": {"dmg": 2, "rate": 0, "mag": 0, "rel": 0}, "ammo": 5}
		game.take_weapon(id)
	_check(game.owned.size() == 6, "alle 6 wapens horen van jou te zijn")
	_check(game.loadout.size() == 5 and game.loadout_full(), "loadout is niet precies vol (5)")
	_check(not game.carries("bazooka") and game.owned.has("bazooka"), "het zesde wapen hoort in de wapenkamer te blijven")
	_check(not game.take_weapon("bazooka"), "een vol pak neemt er toch een bij")
	game.cur = "mg42"
	game.leave_weapon("mg42")
	_check(game.owned.has("mg42") and int(game.owned["mg42"].up.dmg) == 2, "wapen of upgrades zijn kwijt na terugzetten")
	_check(not game.carries("mg42") and game.carries(game.cur), "actief wapen is niet doorgeschakeld")
	_check(game.take_weapon("bazooka") and game.carries("bazooka"), "meenemen uit de wapenkamer lukt niet")
	for id in game.loadout.duplicate():
		game.leave_weapon(id)
	_check(game.loadout.size() == 1, "de laatste in de loadout mag niet weg")
	game.reset()
	_check(game.loadout == ["m1911"], "reset zet de loadout niet terug")
	if fails == 0:
		print("LOADOUT TEST PASS: 5 mee, rest blijft van jou in de wapenkamer, upgrades blijven")
	quit(1 if fails > 0 else 0)
