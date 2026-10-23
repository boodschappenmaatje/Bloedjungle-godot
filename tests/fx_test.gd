extends SceneTree
## Test: tracers, huls, vonken en flits maken geen fouten. Draaien: godot --headless --path . -s tests/fx_test.gd --fixed-fps 60
var main: Node
# Klassen met autoload-verwijzingen worden pas tijdens het draaien geladen: bij het compileren van een -s test bestaan de autoloads nog niet.
var _fx: Script
var _bullet: Script
var frames := 0
func _initialize() -> void:
	_fx = load("res://scripts/fx.gd")
	_bullet = load("res://scripts/bullet.gd")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
func _process(_d: float) -> bool:
	frames += 1
	var g = root.get_node("Game")
	if frames == 3:
		main.begin()
	if frames > 5 and frames < 400:
		var pp: Vector3 = g.player.global_position
		_fx.muzzle(main, pp + Vector3(0, 1, 0))
		_fx.casing(main, pp + Vector3(0, 1.2, 0))
		_fx.spark(main, pp + Vector3(3, 1, 0), Vector3.UP)
		_fx.impact(main, pp + Vector3(0, 1, 3), Vector3.BACK)
		_bullet.fire(main, pp + Vector3(0, 1.3, 0), 0.5, 70.0, 1.0, 0.5, true)
		_bullet.fire(main, pp + Vector3(0, 1.3, 0), 2.0, 70.0, 1.0, 0.5, false)
	if frames == 400:
		print("casings: ", _fx._casings, " bullets: ", get_nodes_in_group("x").size(), " ok")
		quit()
	return false
