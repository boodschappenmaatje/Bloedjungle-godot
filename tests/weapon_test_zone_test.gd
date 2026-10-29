extends Node
## Regression: the real Main scene can be launched as a weapon range with all six guns and targets.

var failures := 0
var game: Node


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("WEAPON TEST ZONE: " + message)


func _run() -> void:
	var zone: Node3D = load("res://scenes/weapon_test_zone.tscn").instantiate()
	get_tree().root.add_child(zone)
	game = get_node("/root/Game")
	for _i in 3600:
		await get_tree().process_frame
		if zone.has_node("WeaponTestControls/Help"):
			break
	var main := zone.get_node_or_null("Main")
	_check(main != null and main.get_node_or_null("Player") != null and main.get_node_or_null("Camera") != null, "echte game scene, speler of gamecamera ontbreekt")
	_check(game.state == "prep", "testzone houdt een golf tegen en blijft schietbaar")
	_check(game.loadout == Data.WEAPON_ORDER, "alle zes wapens zijn rechtstreeks te selecteren in de testzone")
	_check(game.player != null and game.player.global_position.distance_to(Vector3(40, 0, 40)) < 0.1, "speler staat niet op het vrije testveld")
	var target_count := 0
	for node in main.get_children():
		if node.get_script() != null and node.get_script().resource_path == "res://scripts/weapon_test_target.gd":
			target_count += 1
	_check(target_count == 3, "licht, hard en bewegend testdoel ontbreken")
	var has_car := false
	var has_bus := false
	for node in main.get_children():
		has_car = has_car or str(node.get("kind")) == "auto"
		has_bus = has_bus or str(node.get("kind")) == "bus"
	_check(has_car and has_bus, "auto- en busdoel ontbreken")
	_check(zone.has_node("WeaponTestControls/Help"), "bedieningsuitleg ontbreekt")
	var select_last := InputEventKey.new()
	select_last.keycode = KEY_6
	select_last.pressed = true
	zone.call("_unhandled_key_input", select_last)
	_check(game.cur == "bazooka", "6 selecteert de Bazooka in de zone")
	zone.queue_free()
	await get_tree().process_frame
	if failures == 0:
		print("WEAPON TEST ZONE PASS: echte Main/player/camera, 6 selecteerbare wapens, 3 doelen, auto en bus")
	get_tree().quit(1 if failures > 0 else 0)
