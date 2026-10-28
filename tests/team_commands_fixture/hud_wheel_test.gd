extends Node

const Combat = preload("res://combat_buttons.gd")
var checks := 0

func _ready() -> void:
	var hud = Combat.new()
	_check(hud.call("_sector", Vector2(0, -80)) == 0, "north is first radial option")
	_check(hud.call("_sector", Vector2(80, 0)) == 1, "east is second radial option")
	_check(hud.call("_sector", Vector2(0, 80)) == 2, "south is third radial option")
	_check(hud.call("_sector", Vector2(-80, 0)) == 3, "west is fourth radial option")
	_check(hud.call("_sector", Vector2(10, 10)) == -1, "center release cancels the radial")
	hud.call("_select_wheel", "equipment", 3)
	_check(Game.equipment_sel == "mine", "implemented mine is selectable")
	hud.call("_select_wheel", "equipment", 1)
	_check(Game.equipment_sel == "mine", "unimplemented C4 does not become active")
	hud.call("_select_wheel", "equipment", 2)
	_check(Game.equipment_sel == "mine", "unimplemented smoke does not become active")
	hud.call("_select_wheel", "support", 0)
	_check(Game.streak_sel == "truck", "existing truck streak is selectable")
	hud.call("_select_wheel", "support", 3)
	_check(Game.streak_sel == "napalm", "existing napalm streak is selectable")
	hud.call("_select_wheel", "support", 1)
	_check(Game.streak_sel == "napalm", "unimplemented airstrike does not replace active support")
	hud.call("_select_wheel", "support", 2)
	_check(Game.streak_sel == "napalm", "unimplemented reinforcement does not replace active support")
	get_tree().root.call_deferred("add_child", hud)
	await get_tree().process_frame
	hud._wheel_kind = "support"
	hud._held_pointer = 4
	hud._wheel_sector = 0
	Game.streak_sel = "napalm"
	var other_touch := InputEventScreenTouch.new()
	other_touch.index = 5
	other_touch.pressed = true
	other_touch.position = Vector2(400, 200)
	_check(hud.call("_wheel_input", other_touch), "radial claims the input stream while open")
	_check(Game.streak_sel == "napalm", "another finger cannot select a support option")
	var owner_release := InputEventScreenTouch.new()
	owner_release.index = 4
	owner_release.pressed = false
	owner_release.position = Vector2(400, 200)
	_check(hud.call("_wheel_input", owner_release), "owning finger releases the wheel")
	_check(Game.streak_sel == "truck", "owning finger selects the active sector")
	print("HUD_WHEEL_TESTS: %d checks passed" % checks)
	hud.free()
	get_tree().quit(0 if checks == 16 else 1)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		push_error("HUD_WHEEL_TEST: " + message)
