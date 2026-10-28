extends SceneTree
## De drie HUD 3.0-wielen (commando, steun, uitrusting) in de echte game: forceert het wiel open op een vaste plek.
## HUD3_OUT = uitvoermap. BJ_TOUCH=1 xvfb-run -a -s "-screen 0 932x430x24" godot --rendering-driver vulkan --path . -s tests/hud3_wielen_foto.gd --resolution 932x430 --fixed-fps 60
var main: Node
var game: Node
var frames := 0
var out := "/tmp/hud3"
var combat: Node
var team: Node


func _initialize() -> void:
	if OS.get_environment("HUD3_OUT") != "":
		out = OS.get_environment("HUD3_OUT")
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frames += 1
	game = root.get_node("Game")
	if frames == 3:
		main.begin()
		for m in get_nodes_in_group("menus"):
			m._show("")
		GameSettings.set_value("time", "day")
		game.prep_t = 9999.0
		game.inv = {"bags": 3, "trench": 2, "mine": 2, "wire": 1, "sentry": 0}
		game.changed.emit()
		combat = main.get_node("Hud").find_child("CombatButtons", true, false)
		team = get_first_node_in_group("team_commands")
	if frames == 30:
		game.streak_bank = ["truck", "napalm"]
		game.changed.emit()
	if frames == 60:
		combat._wheel_kind = "equipment"
		combat._hold_origin = Vector2(466, 215)
		combat._wheel_sector = 0
		combat.queue_redraw()
	if frames == 70:
		root.get_viewport().get_texture().get_image().save_png(out + "/wiel_uitrusting.png")
		combat._wheel_kind = "support"
		combat._wheel_sector = 3
		combat.queue_redraw()
	if frames == 80:
		root.get_viewport().get_texture().get_image().save_png(out + "/wiel_steun.png")
		combat._wheel_kind = ""
		combat.queue_redraw()
		team.controller.wheel_open = true
		team.controller.origin = Vector2(466, 215)
		team.controller.selected_sector = 0
		team.queue_redraw()
	if frames == 90:
		root.get_viewport().get_texture().get_image().save_png(out + "/wiel_commando.png")
	if frames == 92:
		team.controller.wheel_open = false
		team.queue_redraw()
	if frames == 100:
		root.get_viewport().get_texture().get_image().save_png(out + "/knoppen.png")
	return frames > 102
