extends SceneTree
## Schermafbeeldingen van de grote kaart (overzicht en doelkeuze bij Aanvallen) en van het commandowiel boven je duim.
## FOTO_DIR=/pad FOTO_TAG=liggend BJ_TOUCH=1 VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 932x430x24" godot --rendering-driver vulkan --path . -s tests/grote_kaart_foto.gd --resolution 932x430 --fixed-fps 60

var main: Node
var frames := 0
var game: Node
var dir := OS.get_environment("FOTO_DIR") if OS.get_environment("FOTO_DIR") != "" else "/tmp"
var tag := OS.get_environment("FOTO_TAG") if OS.get_environment("FOTO_TAG") != "" else "liggend"
var allies: Array = []
var thumb: Control
var thumb_at := Vector2.ZERO


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(func(): if frames > 3 and game != null: game.move = Vector2.ZERO)


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/kaart_%s_%s.png" % [dir, name, tag])
	print("foto ", name)


## Een duim (en de hand eronder) die op het scherm ligt, zodat je ziet wat hij afdekt.
func _draw_thumb() -> void:
	if thumb_at == Vector2.ZERO:
		return
	var skin := Color(0.93, 0.74, 0.6, 0.93)
	thumb.draw_colored_polygon(PackedVector2Array([thumb_at + Vector2(-24, 0), thumb_at + Vector2(24, 0), thumb_at + Vector2(70, 200), thumb_at + Vector2(-90, 200)]), skin)
	thumb.draw_circle(thumb_at, 25.0, skin)
	thumb.draw_arc(thumb_at, 25.0, 0.0, TAU, 32, Color(0.55, 0.35, 0.25, 0.9), 2.0, true)


func _process(_d: float) -> bool:
	frames += 1
	game = root.get_node("Game")
	var hud := get_first_node_in_group("hud_extra")
	var tc := get_first_node_in_group("team_commands")
	if frames == 2:
		for n in main.get_children():
			if n.get_script() and String(n.get_script().resource_path).ends_with("patrouille.gd"):
				n.queue_free()
	if frames == 3:
		main.begin()
		for n in root.find_children("*", "", true, false):
			if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
				n.set_process(false)
		for m in get_nodes_in_group("menus"):
			m._show("")
		GameSettings.set_value("time", "day")
	if frames > 3 and game.state == "prep":
		game.prep_t = 1e9
	if frames == 5:
		var ally_script: GDScript = load("res://scripts/ally.gd")
		for i in 6:
			var a = ally_script.new()
			game.player.get_parent().add_child(a)
			a.global_position = Vector3(30 + i, 0, 30)
			a.setup(100.0, 16.0, i)
			game.allies.append(a)
			allies.append(a)
		thumb = Control.new()
		thumb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumb.z_index = 300
		thumb.draw.connect(_draw_thumb)
		hud.get_parent().add_child(thumb)
	if frames == 60:
		# je leger onderweg naar de vijandbasis: een paar soldaten op de stadsroute
		var spots := [Vector3(-2, 0, -112), Vector3(-30, 0, -122), Vector3(-44, 0, -170), Vector3(-34, 0, -214), Vector3(-34, 0, -230)]
		for i in allies.size():
			allies[i].global_position = spots[i % spots.size()] + Vector3(i * 0.7, 0, 0)
			if not game.allies.has(allies[i]):
				game.allies.append(allies[i])   # begin() wist de lijst nog een keer na het maken van de soldaten
		game.player.global_position = Vector3(10, 0, 18)
		hud.open_map(false)
	if frames == 80:
		_shot("overzicht")
		hud._map.close_map()
		tc.controller.pending_order = "attack"
		hud.open_map(true)
	if frames == 100:
		_shot("aanvallen")
		hud._map.close_map()
		tc.cancel_input()
	if frames == 110:
		# het wiel zoals het was (middelpunt vast op de plek van je duim, ingeklemd in het scherm) en zoals het nu is (erboven)
		var origin: Vector2 = tc.button.get_global_rect().get_center()
		thumb_at = origin
		tc.controller.begin(1, origin)
		tc.controller.origin = origin + Vector2(0, 112)
		tc.controller.wheel_open = true
		tc.queue_redraw()
		thumb.queue_redraw()
	if frames == 125:
		_shot("wiel_oud")
		var origin2: Vector2 = tc.button.get_global_rect().get_center()
		tc.controller.origin = origin2
		tc.queue_redraw()
	if frames == 140:
		_shot("wiel_nieuw")
		tc.cancel_input()
	return frames > 142
