class_name CombatTargetHud
extends Control
## Top-down screen projection of a world-space aim point, not a joystick cross.
## Only one target and one health readout; all visuals ignore touch input.
const NEUTRAL := Color(0.93, 0.95, 0.88, 0.95)
const ENEMY := Color(1.0, 0.31, 0.22, 0.98)
const BLOCKED := Color(1.0, 0.73, 0.23, 0.98)
const CONFIRMED := Color(1.0, 0.95, 0.73, 0.99)
const HIT_DURATION := 0.17

var _prediction: Dictionary = {}
var _hit_time := 0.0
var _hit_point := Vector3.ZERO


func _ready() -> void:
	name = "CombatTargetHud"
	add_to_group("combat_target_hud")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var game := get_tree().root.get_node_or_null("Game")
	if game != null and not game.is_connected("combat_hit_confirmed", _on_confirmed):
		game.connect("combat_hit_confirmed", _on_confirmed)


func set_prediction(data: Dictionary) -> void:
	_prediction = data
	queue_redraw()


func clear_prediction() -> void:
	if not _prediction.is_empty():
		_prediction = {}
		queue_redraw()


func _on_confirmed(point: Vector3, damage: float, source: String) -> void:
	if source != "jeep" or damage <= 0.0:
		return
	_hit_point = point
	_hit_time = HIT_DURATION
	queue_redraw()


func _active() -> bool:
	var game := get_tree().root.get_node_or_null("Game")
	if game == null or str(game.get("state")) not in ["play", "prep"] or bool(game.get("build_mode")) or bool(game.get("editing")):
		return false
	if get_tree().paused or get_tree().get_first_node_in_group("kaart_open") != null:
		return false
	var player = game.get("player")
	return player != null and is_instance_valid(player) and player.driving and not player.dead


func _process(delta: float) -> void:
	_hit_time = maxf(0.0, _hit_time - delta)
	if not _prediction.is_empty() or _hit_time > 0.0:
		queue_redraw()


func _screen_point(camera: Camera3D, at: Vector3) -> Variant:
	if camera.is_position_behind(at):
		return null
	var p := camera.unproject_position(at)
	var edges := Rect2(Vector2(14.0, 14.0), size - Vector2(28.0, 28.0))
	return p if edges.has_point(p) else null


func _draw() -> void:
	if not _active():
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	if not _prediction.is_empty():
		var point: Variant = _screen_point(camera, _prediction.point)
		if point != null:
			var state: String = str(_prediction.get("state", "clear"))
			var col: Color = ENEMY if state == "enemy" else (BLOCKED if state == "blocked" else NEUTRAL)
			_draw_cross(point, col, state == "enemy", state == "blocked")
		var target := _prediction.get("target") as Node3D
		if is_instance_valid(target) and not bool(target.get("dead")):
			_draw_target(camera, target)
	if _hit_time > 0.0:
		var hit_at: Variant = _screen_point(camera, _hit_point)
		if hit_at != null:
			var alpha := clampf(_hit_time / HIT_DURATION, 0.0, 1.0)
			var col := Color(CONFIRMED.r, CONFIRMED.g, CONFIRMED.b, alpha)
			for delta in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				draw_line(hit_at + delta * 6.0, hit_at + delta * 11.0, col, 2.5, true)


func _draw_cross(p: Vector2, col: Color, selected: bool, blocked: bool) -> void:
	# Open center keeps the 3D target visible underneath.
	draw_arc(p, 7.5, 0.0, TAU, 32, Color(0, 0, 0, 0.55), 3.4, true)
	draw_arc(p, 7.5, 0.0, TAU, 32, col, 1.8, true)
	for v in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		draw_line(p + v * 11.0, p + v * 17.0, col, 1.8, true)
	if blocked:
		# Amber dash explicitly distinguishes a wall/shield from a vulnerable actor.
		draw_line(p + Vector2(-5, 22), p + Vector2(5, 22), col, 2.5, true)
	if selected:
		draw_arc(p, 21.0, -PI * 0.30, PI * 0.30, 12, Color(col, 0.65), 1.4, true)
		draw_arc(p, 21.0, PI * 0.70, PI * 1.30, 12, Color(col, 0.65), 1.4, true)


func _draw_target(camera: Camera3D, target: Node3D) -> void:
	var at: Variant = _screen_point(camera, target.global_position + Vector3.UP * 2.55)
	if at == null:
		return
	var center: Vector2 = at
	var color := ENEMY
	var half := Vector2(24.0, 16.0)
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			var corner := center + Vector2(half.x * x, half.y * y)
			draw_line(corner, corner - Vector2(7.0 * x, 0), color, 1.7, true)
			draw_line(corner, corner - Vector2(0, 7.0 * y), color, 1.7, true)
	# The enemy already has a distant-health RangeMarker; never draw a duplicate.
	var existing := target.get("_range_marker") as Node3D
	if existing != null and existing.visible:
		return
	var hp := maxf(float(target.get("hp")), 0.0)
	var max_hp := maxf(float(target.get("max_hp")), 1.0)
	var rect := Rect2(center + Vector2(-26, -29), Vector2(52, 5))
	draw_rect(rect, Color(0.02, 0.03, 0.025, 0.84))
	draw_rect(Rect2(rect.position + Vector2(1, 1), Vector2(50.0 * clampf(hp / max_hp, 0, 1), 3)), color)
