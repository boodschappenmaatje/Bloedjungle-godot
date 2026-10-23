extends SceneTree
## Test: vijandelijke kogels en ontploffingen beschadigen bouwstukken. Draaien: godot --headless --path . -s tests/schade_test.gd

var main: Node
# Klassen met autoload-verwijzingen worden pas tijdens het draaien geladen: bij het compileren van een -s test bestaan de autoloads nog niet.
var _bullet: Script
var frames := 0
var kaz: Variant
var muur: Variant
var zak: Variant


func _initialize() -> void:
	_bullet = load("res://scripts/bullet.gd")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frames += 1
	var game = root.get_node("Game")
	if frames == 3:
		main.begin()
		game.build_credit = 5000
		kaz = game.builds.place("kazerne", Vector3(-10, 0, -24), 0.0)
		muur = game.builds.place("muur", Vector3(8, 0, 22), 0.0)
		zak = game.builds.place("zandzak", Vector3(-8, 0, 22), 0.0)
		print("geplaatst: ", kaz != null, muur != null, zak != null)
	if frames == 6:
		# vijandelijke kogel richting de muur (van z=30 naar z=22)
		_bullet.fire(main, Vector3(8, 1.0, 28), PI, 75.0, 400.0, 0.6, false, false)
		_bullet.fire(main, Vector3(-10, 1.0, -30), 0.0, 75.0, 400.0, 0.6, false, false)
	if frames == 20:
		print("muur hp ", muur.hp, " kazerne hp ", kaz.hp)
		game.builds.damage(muur, 5000.0)
		game.builds.damage(kaz, 5000.0)
		game.builds.damage(zak, 100.0)
	if frames == 24:
		print("muur weg: ", not game.buildings.has(muur), " kazerne down: ", kaz.down, " zak hp ", zak.hp)
		print("fix ", game.builds.fix_cost(kaz))
		game.builds.repair(kaz)
		print("na herbouw: down=", kaz.down, " hp=", kaz.hp, " scale=", kaz.node.scale)
		game.builds.blast(Vector3(-8, 0, 22), 6.0, 300.0, false)
		print("zak na blast ", zak.hp if game.buildings.has(zak) else "weg")
		print("KLAAR")
		quit()
	return false
