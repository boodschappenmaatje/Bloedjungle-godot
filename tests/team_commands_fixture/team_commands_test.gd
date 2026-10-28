extends SceneTree

const Controller = preload("res://team_command_controller.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_test_short_and_long_press()
	_test_wheel_sectors_and_commands()
	_test_safe_edge_sector()
	_test_target_orders()
	_test_cancel_reset_and_invalid_targets()
	_test_pointer_ownership_and_conflicts()
	_test_eligibility()
	_test_ally_command_goals()
	if failures.is_empty():
		print("TEAM_CONTROLLER_TESTS: %d checks passed" % checks)
		quit(0)
	else:
		push_error("TEAM_CONTROLLER_TESTS: %d/%d failed: %s" % [failures.size(), checks, "; ".join(failures)])
		quit(1)


func _test_short_and_long_press() -> void:
	var c = Controller.new()
	_check(c.begin(4, Vector2(100, 100)), "touch starts")
	_check(not c.advance(0.2), "short press stays tap")
	_check(c.release(4, Vector2(100, 100), Vector2(100, 100)).kind == "toggle", "short release toggles")
	_check(c.begin(-1, Vector2(100, 100)), "mouse starts")
	_check(not c.advance(0.37), "below hold threshold")
	_check(c.advance(0.02), "long press opens wheel")
	_check(c.wheel_open, "wheel state recorded")


func _test_wheel_sectors_and_commands() -> void:
	var center := Vector2(300, 240)
	var points := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
	for i in 4:
		_check(Controller.sector(center, center + points[i] * 80.0) == i, "wheel sector %d" % i)
	var c = Controller.new()
	for i in 4:
		c.cancel()
		c.begin(1, center)
		c.advance(Controller.HOLD_TIME)
		var result: Dictionary = c.release(1, center + points[i] * 80.0, center)
		_check(result.get("order", "") == Controller.COMMANDS[i], "wheel command %s" % Controller.COMMANDS[i])
		_check(result.kind == ("issue" if Controller.COMMANDS[i] == "follow" else "target"), "wheel action kind %s" % Controller.COMMANDS[i])


func _test_target_orders() -> void:
	var c = Controller.new()
	for order in ["defend", "attack", "move"]:
		c.cancel()
		c.begin(2, Vector2.ZERO)
		c.advance(Controller.HOLD_TIME)
		var idx: int = Controller.COMMANDS.find(order)
		var pos := Vector2.RIGHT.rotated(float(idx) * PI / 2.0) * 80.0
		var chosen: Dictionary = c.release(2, pos, Vector2.ZERO)
		_check(chosen.order == order and c.pending_order == order, "%s awaits world target" % order)
		_check(c.begin_target(7), "%s target touch begins" % order)
		var target_type := "enemy" if order == "attack" else "ground"
		_check(c.complete_target(7, target_type) == order, "%s accepts %s target" % [order, target_type])
		_check(c.pending_order == "", "%s target clears pending order" % order)
	# Attack supports both enemy references and a ground position through the same completion path.
	for target_type in ["enemy", "ground"]:
		c.begin(3, Vector2.ZERO)
		c.advance(Controller.HOLD_TIME)
		var attack_index: int = Controller.COMMANDS.find("attack")
		c.release(3, Vector2.RIGHT.rotated(float(attack_index) * PI / 2.0) * 80.0, Vector2.ZERO)
		c.begin_target(9)
		_check(c.complete_target(9, target_type) == "attack", "attack accepts %s selection" % target_type)


func _test_safe_edge_sector() -> void:
	var c = Controller.new()
	var raw_origin := Vector2(12, 18)
	var safe_center := Vector2(114, 86) # same inward correction used by the on-screen wheel
	c.begin(2, raw_origin)
	c.advance(Controller.HOLD_TIME)
	_check(c.release(2, raw_origin, safe_center).kind == "cancel", "release at clamped edge origin cancels")
	c.begin(2, raw_origin)
	c.advance(Controller.HOLD_TIME)
	_check(Controller.sector(safe_center, safe_center + Vector2.RIGHT * 80) == 0, "safe-edge east sector uses displayed center")
	_check(c.release(2, safe_center + Vector2.RIGHT * 80, safe_center).order == "attack", "safe-edge wheel command matches drawn sector")


func _test_cancel_reset_and_invalid_targets() -> void:
	var c = Controller.new()
	c.begin(1, Vector2.ZERO)
	c.advance(Controller.HOLD_TIME)
	c.release(1, Vector2.LEFT * 80, Vector2.ZERO) # defend sector
	_check(c.is_modal(), "targeting is modal")
	_check(c.begin_target(5), "target pointer assigned")
	_check(c.complete_target(5, "missing") == "", "invalid/missing target does not issue")
	_check(c.pending_order == "defend", "failed ray keeps target request active")
	c.cancel()
	_check(not c.is_modal() and c.pending_order == "", "cancel clears all temporary state")
	_check(c.release(1, Vector2.ZERO, Vector2.ZERO).is_empty(), "cancelled finger cannot issue later")
	c.begin_target(6) # no pending order
	_check(c.target_pointer == -2, "stale target ignored after reset")


func _test_pointer_ownership_and_conflicts() -> void:
	var c = Controller.new()
	_check(c.begin(0, Vector2.ZERO), "first finger owns gesture")
	_check(not c.begin(1, Vector2.RIGHT), "second finger cannot steal gesture")
	_check(not c.begin(-1, Vector2.RIGHT), "mouse cannot steal touch gesture")
	_check(c.release(1, Vector2.RIGHT, Vector2.ZERO).is_empty(), "foreign release ignored")
	_check(c.pointer_id == 0, "first owner remains assigned")
	c.cancel()
	c.begin(0, Vector2.ZERO)
	c.advance(Controller.HOLD_TIME)
	var target: Dictionary = c.release(0, Vector2.LEFT * 80.0, Vector2.ZERO)
	_check(target.kind == "target", "wheel enters target mode")
	_check(c.begin_target(4), "second finger may target after command selection")
	_check(not c.begin_target(5), "only one target pointer is captured")
	_check(Controller.can_accept_target(false, false), "world point may be selected")
	_check(not Controller.can_accept_target(true, false), "HUD touch cannot select command")
	_check(not Controller.can_accept_target(false, true), "joystick touch cannot select command")
	c.cancel()
	_check(not c.is_modal(), "cancel releases both touch owners")


func _test_eligibility() -> void:
	_check(Controller.can_command(false, false, false), "player recruit is commandable")
	_check(not Controller.can_command(false, true, false), "base guard excluded")
	_check(not Controller.can_command(true, false, false), "reinforcement helper excluded")
	_check(not Controller.can_command(false, false, true), "vehicle occupant excluded")


func _test_ally_command_goals() -> void:
	var target := Vector3(10, 0, 20)
	var hold := Vector3(-3, 0, 7)
	var enemy := Vector3(25, 0, 30)
	var follow := Vector3(1, 0, 2)
	_check(Controller.soldier_goal("hold", target, enemy, false, 0, hold, follow) == hold, "hold keeps each soldier's current position")
	var defend := Controller.soldier_goal("defend", target, enemy, false, 0, hold, follow)
	_check(is_equal_approx(defend.distance_to(target), 3.0), "defend holds a perimeter around the marked position")
	var move_goals: Array[Vector3] = []
	for i in 4:
		move_goals.append(Controller.soldier_goal("move", target, enemy, false, i, hold, follow))
	_check(move_goals[0].distance_to(target) > 0.5, "move preserves a dispersed arrival formation")
	_check(move_goals[0] != move_goals[1] and move_goals[1] != move_goals[2], "move soldiers do not stack at one point")
	_check(is_equal_approx(move_goals[0].z, target.z - 0.8) and is_equal_approx(move_goals[1].z, target.z - 0.8), "first move row stays aligned")
	_check(is_equal_approx(move_goals[2].z, target.z + 0.8) and is_equal_approx(move_goals[3].z, target.z + 0.8), "second move row stays aligned")
	var ground_attack := Controller.soldier_goal("attack", target, Vector3.ZERO, false, 0, hold, follow)
	_check(ground_attack.distance_to(target) < 2.0, "ground attack leads to the selected location")
	var enemy_attack := Controller.soldier_goal("attack", target, enemy, true, 0, hold, follow)
	_check(enemy_attack.distance_to(enemy) < 3.1 and enemy_attack.distance_to(target) > 10.0, "enemy attack follows the selected living target")
	var fallen_enemy_fallback := Controller.soldier_goal("attack", target, enemy, false, 0, hold, follow)
	_check(fallen_enemy_fallback.distance_to(target) < 2.0, "vanished target safely falls back to its last position")


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error("FAILED: " + description)
