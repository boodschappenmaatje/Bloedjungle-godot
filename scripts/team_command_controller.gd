extends RefCounted
## Pure input/order state shared by the HUD adapter and the lightweight test fixture.

const HOLD_TIME := 0.38
const COMMANDS := ["follow", "defend", "attack", "move"]

var pointer_id := -2 # screen finger index, or -1 for the mouse
var origin := Vector2.ZERO
var elapsed := 0.0
var wheel_open := false
var pending_order := ""
var target_pointer := -2
var selected_sector := -1


func begin(pointer: int, position: Vector2) -> bool:
	if pointer_id != -2 or pending_order != "":
		return false
	pointer_id = pointer
	origin = position
	elapsed = 0.0
	wheel_open = false
	selected_sector = -1
	return true


func advance(delta: float) -> bool:
	if pointer_id == -2 or wheel_open:
		return false
	elapsed += delta
	if elapsed >= HOLD_TIME:
		wheel_open = true
		return true
	return false


func move(pointer: int, position: Vector2, center: Vector2) -> bool:
	if pointer != pointer_id or not wheel_open:
		return false
	selected_sector = sector(center, position)
	return true


## Returns {"kind":"toggle"}, {"kind":"issue","order":...}, or {"kind":"target","order":...}.
func release(pointer: int, position: Vector2, center: Vector2) -> Dictionary:
	if pointer != pointer_id:
		return {}
	var result := {"kind": "toggle"}
	if wheel_open:
		# A hold with no thumb movement is a cancel, even when the wheel center was clamped inward.
		var index := -1 if position.distance_to(origin) < 24.0 else sector(center, position)
		if index < 0:
			result = {"kind": "cancel"}
		else:
			var order: String = COMMANDS[index]
			result = {"kind": "issue", "order": order} if order == "follow" else {"kind": "target", "order": order}
	_reset_pointer()
	if result.kind == "target":
		pending_order = result.order
	return result


func begin_target(pointer: int) -> bool:
	if pending_order == "" or pointer == pointer_id or target_pointer != -2:
		return false
	target_pointer = pointer
	return true


func complete_target(pointer: int, target_kind: String) -> String:
	if pointer != target_pointer:
		return ""
	if target_kind not in ["ground", "enemy"]:
		return ""
	target_pointer = -2
	var order := pending_order
	pending_order = ""
	return order


func finish_target(pointer: int) -> String:
	if pointer != target_pointer:
		return ""
	target_pointer = -2
	return pending_order


func cancel() -> void:
	_reset_pointer()
	pending_order = ""
	target_pointer = -2
	selected_sector = -1


func is_modal() -> bool:
	return pointer_id != -2 or pending_order != "" or target_pointer != -2


static func sector(center: Vector2, position: Vector2) -> int:
	var d := position - center
	if d.length() < 24.0:
		return -1
	var angle := fposmod(atan2(d.y, d.x) + TAU, TAU)
	return int(floor((angle + PI / 4.0) / (PI / 2.0))) % 4


static func can_command(is_helper: bool, is_guard: bool, is_in_vehicle: bool) -> bool:
	return not is_helper and not is_guard and not is_in_vehicle


static func can_accept_target(is_hud: bool, is_joystick_zone: bool) -> bool:
	return not is_hud and not is_joystick_zone


## Shared target positioning used directly by Ally._goal and by the asset-free tests.
static func soldier_goal(order: String, target: Vector3, target_enemy_position: Vector3, has_valid_enemy: bool, index: int, hold_position: Vector3, follow_position: Vector3) -> Vector3:
	match order:
		"hold":
			return hold_position
		"defend":
			return target + Vector3(cos(float(index) * TAU / 4.0), 0.0, sin(float(index) * TAU / 4.0)) * 3.0
		"move":
			return target + Vector3((index % 2) * 1.6 - 0.8, 0.0, (index / 2 % 2) * 1.6 - 0.8)
		"attack":
			if has_valid_enemy:
				return target_enemy_position + Vector3(cos(float(index) * 2.4), 0.0, sin(float(index) * 2.4)) * 3.0
			return target + Vector3((index % 2) * 1.8 - 0.9, 0.0, (index / 2 % 2) * 1.8 - 0.9)
	return follow_position


func _reset_pointer() -> void:
	pointer_id = -2
	elapsed = 0.0
	wheel_open = false
	selected_sector = -1
