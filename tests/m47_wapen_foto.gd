extends Node
## Opnames van het M-47 in het echte spel: wapenbalk met M-47, schot en inslag op een huis (spelcamera).
## Gebruik: godot --rendering-driver vulkan res://tests/m47_wapen_foto.tscn -- --out=/pad/

var out := "/tmp/m47spel/"


func _ready() -> void:
	call_deferred("_run")


func _hide_menu() -> void:
	for n in get_tree().root.find_children("*", "", true, false):
		if n.get_script() and String(n.get_script().resource_path).ends_with("pause_menu.gd") and "visible" in n:
			n.visible = false


func _snap(name_: String) -> void:
	_hide_menu()
	for _i in 3:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + name_ + ".png")


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	GameSettings.get_value("soldaat")
	GameSettings.values["soldaat"] = "meshy"
	var game: Node = get_tree().root.get_node("Game")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	main.begin()
	for _i in 10:
		await get_tree().process_frame
	game.points = 5000
	game.owned["m47"] = {"up": {"dmg": 0, "rate": 0, "mag": 0, "rel": 0}, "ammo": 3}
	game.take_weapon("m47")
	game.state = "play"
	var p: Node3D = game.player
	print("STATE ", game.state, " weapon ", p.weapon, " cur ", game.cur)
	p.call("equip", "m47")
	print("NA EQUIP ", p.weapon, " ", game.state)
	var h: Node3D = load("res://scripts/woonhuis.gd").call("place", main, p.global_position + Vector3(0, 0, 14.0), 0.0, "woonhuis")
	for _i in 90:
		await get_tree().process_frame
	await _snap("0_klaar")
	game.changed.emit()
	for _i in 20:
		await get_tree().process_frame
	await _snap("0_balk")
	p.set("face", 0.0)
	p.call("_shoot", game.wstat("m47"))
	var t0 := Time.get_ticks_msec()
	for k in 12:
		for _i in 3:
			await get_tree().process_frame
		await _snap("1_schot_%d" % k)
	get_tree().quit(0)
