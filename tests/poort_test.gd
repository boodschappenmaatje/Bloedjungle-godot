extends SceneTree
## Test van de schuifpoorten. godot --headless --path . -s tests/poort_test.gd --fixed-fps 60

var main: Node
var frames := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frames += 1
	var g = root.get_node("Game")
	if frames == 2:
		main.get_node("Hud/Sticks").set_process(false)
	if frames == 4:
		main.begin()
		g.player.global_position = Vector3(0, 0, -16.5)
		g.player.face = PI
	if frames == 8:
		var gt = g.gates.list[0]
		print("poort dicht: open ", gt.open, " collider uit ", gt.shape.disabled, " breed ", (gt.shape.shape as BoxShape3D).size.x)
		print("dichtbij: ", g.gates.near_player() != null)
		g.gates.toggle(gt)
	if frames == 8 + 75:
		var gt = g.gates.list[0]
		print("na 1,25 s: open ", snappedf(gt.open, 0.01), " breed ", snappedf((gt.shape.shape as BoxShape3D).size.x, 0.1))
	if frames == 8 + 60 * 3:
		var gt = g.gates.list[0]
		print("na 3 s: open ", gt.open, " collider uit ", gt.shape.disabled)
		g.player.global_position = Vector3(0, 0, -30)
	if frames == 8 + 60 * 3 + 30:
		print("speler weg, gebruiker open: ", g.gates.list[0].user_open)
	if frames == 8 + 60 * 8:
		print("na 5 s weg: open ", snappedf(g.gates.list[0].open, 0.01))
		g.player.global_position = Vector3(0, 0, 0)
		main.start_wave()
	if frames > 8 + 60 * 8 and frames % 600 == 0:
		var s := ""
		for gt in g.gates.list:
			s += " %s hp %d broken %s open %.2f" % [gt.name, gt.hp, gt.broken, gt.open]
		print("t ", frames / 60, " kills ", g.kills, " vijanden ", g.enemies.size(), s)
	if frames > 8 + 60 * 8 + 60 * 70:
		print("EINDE poort")
		return true
	return false
