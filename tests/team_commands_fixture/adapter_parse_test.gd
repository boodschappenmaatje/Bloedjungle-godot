extends Control

const TeamCommandsScript = preload("res://team_commands.gd")
const TouchSticksScript = preload("res://touch_sticks.gd")

class FakeSoldier extends RefCounted:
	var helper := false
	var guard := false
	var truck: Node
	var command := "follow"
	var target := Vector3.ZERO
	var calls := 0

	func set_command(order: String, position: Vector3, _enemy: Node3D = null) -> void:
		command = order
		target = position
		calls += 1

func _ready() -> void:
	var team = TeamCommandsScript.new()
	var sticks = TouchSticksScript.new()
	add_child(team)
	add_child(sticks)
	var first_soldier := FakeSoldier.new()
	var second_soldier := FakeSoldier.new()
	var guard := FakeSoldier.new()
	guard.guard = true
	var helper := FakeSoldier.new()
	helper.helper = true
	var passenger := FakeSoldier.new()
	passenger.truck = Node.new()
	Game.allies = [first_soldier, second_soldier, guard, helper, passenger]
	team.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	team.size = Vector2(1024, 640)
	team._layout()
	var hud_button := Button.new()
	hud_button.add_to_group("hud_button")
	hud_button.position = Vector2(300, 180)
	hud_button.size = Vector2(70, 50)
	add_child(hud_button)
	if team.button == null:
		push_error("TEAM adapter did not build its ActionBtn")
		get_tree().quit(1)
		return
	if not sticks.is_in_group("touch_sticks") or not team.is_in_group("team_commands"):
		push_error("TEAM/joystick input routers did not register")
		get_tree().quit(1)
		return
	for corner in [Vector2.ZERO, Vector2(team.size.x, 0), Vector2(0, team.size.y), team.size]:
		team.controller.begin(8, corner)
		var corrected: Vector2 = team._wheel_center()
		_check(corrected.x >= 114.0 and corrected.x <= team.size.x - 114.0, "wheel stays inside safe horizontal edges")
		_check(corrected.y >= 86.0 and corrected.y <= team.size.y - 86.0, "wheel stays inside safe vertical edges")
		team.cancel_input()
	var center: Vector2 = team.button.get_global_rect().get_center()
	var down := InputEventScreenTouch.new()
	down.index = 3
	down.pressed = true
	down.position = center
	sticks._input(down)
	var other := InputEventScreenTouch.new()
	other.index = 4
	other.pressed = true
	other.position = Vector2(400, 200)
	sticks._input(other)
	_check(team.controller.pointer_id == 3, "TEAM keeps its owning multitouch finger")
	_check(team._available() == 2, "only two controllable recruits are counted")
	_check(sticks._sticks.is_empty(), "TEAM hold does not start a joystick")
	var wrong_release := InputEventScreenTouch.new()
	wrong_release.index = 4
	wrong_release.position = other.position
	sticks._input(wrong_release)
	_check(team.controller.pointer_id == 3, "second finger cannot release TEAM")
	var up := InputEventScreenTouch.new()
	up.index = 3
	up.position = center
	sticks._input(up)
	_check(Game.troop_mode == "hold", "short TEAM tap executes the shared hold order")
	_check(first_soldier.command == "hold" and second_soldier.command == "hold", "short TEAM tap orders every controllable recruit")
	_check(guard.calls == 0 and helper.calls == 0 and passenger.calls == 0, "guards, helpers, and vehicle passengers are excluded")
	_check(not sticks._mouse_down and not Game.fire, "TEAM input does not activate mouse fire")
	team.toggle_follow_hold() # same entry point used by the barracks menu
	_check(first_soldier.command == "follow" and second_soldier.command == "follow", "barracks toggle shares the TEAM follow state")
	passenger.truck.free()
	Game.allies.clear()
	var mouse_down := InputEventMouseButton.new()
	mouse_down.button_index = MOUSE_BUTTON_LEFT
	mouse_down.pressed = true
	mouse_down.position = center
	sticks._input(mouse_down)
	team.controller.advance(0.39)
	var wheel_center: Vector2 = team._wheel_center()
	var mouse_up := InputEventMouseButton.new()
	mouse_up.button_index = MOUSE_BUTTON_LEFT
	mouse_up.pressed = false
	mouse_up.position = wheel_center + Vector2.LEFT * 80.0
	sticks._input(mouse_up)
	_check(team.controller.pending_order == "attack", "long press selects attack through shared input router")
	var hud_down := InputEventMouseButton.new()
	hud_down.button_index = MOUSE_BUTTON_LEFT
	hud_down.pressed = true
	hud_down.position = hud_button.get_global_rect().get_center()
	sticks._input(hud_down)
	_check(team.controller.pending_order == "attack", "HUD button cannot become an attack target")
	_check(not sticks._mouse_down and not Game.fire, "target selection does not start shooting")
	var cancel := InputEventMouseButton.new()
	cancel.button_index = MOUSE_BUTTON_LEFT
	cancel.pressed = true
	cancel.position = center
	sticks._input(cancel)
	_check(team.controller.pending_order == "" and not team.is_modal(), "tapping TEAM cancels target mode")
	print("TEAM_ADAPTER_TESTS: adapters initialize; %d input checks passed" % _checks)
	get_tree().quit(0)


var _checks := 0
func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		push_error("TEAM_ADAPTER_TESTS failed: " + description)
		get_tree().quit(1)
