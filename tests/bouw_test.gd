extends SceneTree
## Test: kazerne bouwen, rekruut opleiden en laten schieten. godot --headless --path . -s tests/bouw_test.gd --fixed-fps 60

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
		g.player.global_position = Vector3(-10, 0, -24)
		g.player.face = 0.0
	if frames == 8:
		g.build_arm = "kazerne"
	if frames == 12:
		g.builds.place()
		print("gebouwen: ", g.buildings.size(), " tegoed ", g.build_credit, " punten ", g.points)
		var b = g.buildings[0]
		g.player.global_position = g.builds.door_of(b)
	if frames == 16:
		print("bij kazerne: ", g.builds.near_barracks() != null)
		g.points = 5000
		g.builds.recruit(g.buildings[0])
		g.builds.recruit(g.buildings[0])
		g.builds.recruit(g.buildings[0])
		print("in wachtrij: ", g.buildings[0].queue, " punten ", g.points)
	if frames == 16 + 60 * 21:
		print("soldaten: ", g.builds.soldiers_alive())
		g.builds.upgrade(g.buildings[0])
		print("niveau ", g.buildings[0].lv, " tegoed ", g.build_credit, " punten ", g.points)
		main.start_wave()
	if frames > 16 + 60 * 21 and frames % 300 == 0:
		print("kills ", g.kills, " vijanden ", g.enemies.size())
	if frames > 16 + 60 * 21 + 60 * 40:
		print("EINDE kills ", g.kills)
		return true
	return false
