class_name TeamCommands
extends Control
## HUD adapter for the shared, asset-independent team input controller.

const LABELS := ["AANVALLEN", "VERPLAATSEN", "VERDEDIGEN", "VOLGEN"]
const Controller = preload("res://scripts/team_command_controller.gd")

var button: ActionBtn
var controller = Controller.new()
var _last_context := ""
var _target_release_pointer := -2


func _ready() -> void:
	add_to_group("team_commands")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	button = ActionBtn.make("troepen", "TEAM")
	button.kind = "combined"
	button.set_caption("BOUW / TEAM")
	button.visible = true
	button.custom_minimum_size = Vector2(58, 58)
	button.size = button.custom_minimum_size
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(button)
	resized.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	if button == null:
		return
	var v := get_viewport_rect().size
	var safe := UI.safe_margins(v)
	var x := safe.x + 20.0 if v.x < v.y else maxf(safe.x + 100.0, v.x * 0.5 - 210.0)
	var y := v.y - safe.w - 220.0
	button.position = Vector2(clampf(x, safe.x, v.x - safe.z - button.size.x), clampf(y, safe.y, v.y - safe.w - button.size.y))


func _process(delta: float) -> void:
	var context := "%s:%s:%s" % [Game.state, str(Game.build_mode), str(get_tree().paused)]
	if context != _last_context:
		_last_context = context
		if Game.state in ["menu", "shop", "over"] or Game.build_mode or get_tree().paused:
			cancel_input()
	button.visible = (Game.state == "prep" or (Game.state == "play" and _available() > 0)) and not Game.build_mode
	button.badge = str(_available())
	mouse_filter = Control.MOUSE_FILTER_STOP if controller.is_modal() else Control.MOUSE_FILTER_IGNORE
	if controller.advance(delta):
		queue_redraw()


func _available() -> int:
	var n := 0
	for a in Game.allies:
		if is_instance_valid(a) and Controller.can_command(a.helper, a.guard, a.truck != null):
			n += 1
	return n


func is_modal() -> bool:
	return controller.is_modal()


## Called first by TouchSticks so a touch/mouse event has one owner before movement/fire is evaluated.
func handle_pointer_event(e: InputEvent) -> bool:
	if e is InputEventScreenTouch:
		var id: int = e.index
		if not e.pressed and id == _target_release_pointer:
			_target_release_pointer = -2
			get_viewport().set_input_as_handled()
			return true
		if controller.pointer_id != -2:
			if id == controller.pointer_id:
				if not e.pressed:
					_finish_pointer(id, e.position)
				get_viewport().set_input_as_handled()
			else:
				# While holding TEAM, extra fingers cannot start a stick or trigger another HUD action.
				get_viewport().set_input_as_handled()
			return true
		if controller.pending_order != "":
			if e.pressed:
				if button.get_global_rect().has_point(e.position):
					cancel_input()
					get_viewport().set_input_as_handled()
					return true
				controller.begin_target(id)
				if controller.target_pointer == id:
					_try_select_world(e.position)
			else:
				controller.finish_target(id)
			get_viewport().set_input_as_handled()
			return true
		if controller.pointer_id == -2 and e.pressed and button.visible and button.get_global_rect().has_point(e.position):
			controller.begin(id, e.position)
			get_viewport().set_input_as_handled()
			return true
	elif e is InputEventScreenDrag:
		if controller.pointer_id != -2:
			if e.index == controller.pointer_id and controller.wheel_open:
				controller.move(e.index, e.position, _wheel_center())
				queue_redraw()
			get_viewport().set_input_as_handled()
			return true
		if controller.pending_order != "":
			get_viewport().set_input_as_handled()
			return true
	elif e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_LEFT and not e.pressed and _target_release_pointer == -1:
			_target_release_pointer = -2
			get_viewport().set_input_as_handled()
			return true
		if e.button_index == MOUSE_BUTTON_RIGHT and e.pressed and controller.is_modal():
			cancel_input()
			get_viewport().set_input_as_handled()
			return true
		if e.button_index != MOUSE_BUTTON_LEFT or e.device == InputEvent.DEVICE_ID_EMULATION:
			return false
		if controller.pointer_id != -2:
			if controller.pointer_id == -1 and not e.pressed:
				_finish_pointer(-1, e.position)
			get_viewport().set_input_as_handled()
			return true
		if controller.pending_order != "":
			if e.pressed:
				if button.get_global_rect().has_point(e.position):
					cancel_input()
					get_viewport().set_input_as_handled()
					return true
				if controller.begin_target(-1):
					_try_select_world(e.position)
			else:
				controller.finish_target(-1)
			get_viewport().set_input_as_handled()
			return true
		if controller.pointer_id == -2 and e.pressed and button.visible and button.get_global_rect().has_point(e.position):
			controller.begin(-1, e.position)
			get_viewport().set_input_as_handled()
			return true
	elif e is InputEventMouseMotion and controller.pointer_id == -1 and controller.wheel_open:
		controller.move(-1, e.position, _wheel_center())
		queue_redraw()
		get_viewport().set_input_as_handled()
		return true
	return false


func _finish_pointer(id: int, pos: Vector2) -> void:
	var result: Dictionary = controller.release(id, pos, _wheel_center())
	match result.get("kind", ""):
		"toggle":
			if Game.state == "prep":
				var build := get_tree().get_first_node_in_group("build_mode")
				if build != null:
					build.call("_enter")
			else:
				toggle_follow_hold()
		"issue":
			_issue(result.order, Vector3.ZERO, null)
		"target":
			queue_redraw()
		"cancel":
			pass
	queue_redraw()


func toggle_follow_hold() -> void:
	_issue("hold" if Game.troop_mode == "follow" else "follow", Vector3.ZERO, null)


func reset_squad() -> void:
	cancel_input()
	Game.squad_order = "follow"
	Game.squad_target = Vector3.ZERO
	Game.squad_target_enemy = null
	Game.troop_mode = "follow"
	for a in Game.allies:
		if is_instance_valid(a) and Controller.can_command(a.helper, a.guard, a.truck != null):
			a.set_command("follow", Vector3.ZERO)
	Game.changed.emit()


func cancel_input() -> void:
	controller.cancel()
	_target_release_pointer = -2
	queue_redraw()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		cancel_input()


func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_ESCAPE and controller.is_modal():
			cancel_input()
			get_viewport().set_input_as_handled()
		elif e.keycode == KEY_T and not controller.is_modal() and not Game.build_mode and button.visible:
			toggle_follow_hold()
			get_viewport().set_input_as_handled()


func _draw() -> void:
	if not controller.wheel_open:
		return
	var center := _wheel_center()
	draw_circle(center, 106.0, Color(0.01, 0.018, 0.012, 0.96))
	draw_arc(center, 106.0, 0.0, TAU, 64, Color(UI.BRASS, 0.88), 2.2, true)
	draw_line(center + Vector2(0, -103), center + Vector2(0, 103), Color(UI.BRASS, 0.28), 1.0)
	draw_line(center + Vector2(-103, 0), center + Vector2(103, 0), Color(UI.BRASS, 0.28), 1.0)
	for i in 4:
		var angle: float = TAU * i / 4.0
		var p := center + Vector2(cos(angle), sin(angle)) * 62.0
		draw_circle(p, 37.0, Color(0.12, 0.095, 0.035, 0.98) if i == controller.selected_sector else UI.PANEL)
		draw_arc(p, 37.0, 0.0, TAU, 40, UI.BRASS if i == controller.selected_sector else Color(UI.BRASS, 0.58), 2.0, true)
		draw_string(UI.body(700), p + Vector2(-45, 5), LABELS[i], HORIZONTAL_ALIGNMENT_CENTER, 90, 10, UI.INK)
	draw_circle(center, 17.0, UI.PANEL)
	draw_arc(center, 17.0, 0.0, TAU, 24, UI.BRASS, 1.6, true)
	draw_string(UI.body(700), center + Vector2(-4, 5), "×", HORIZONTAL_ALIGNMENT_CENTER, 8, 16, UI.INK)


func _wheel_center() -> Vector2:
	var safe := UI.safe_margins(size)
	# The diagonal 104×48 sector panels extend about 113 px horizontally and 85 px vertically.
	return Vector2(clampf(controller.origin.x, safe.x + 114.0, size.x - safe.z - 114.0), clampf(controller.origin.y, safe.y + 86.0, size.y - safe.w - 86.0))


func _issue(command: String, target: Vector3, enemy: Node3D) -> void:
	Game.squad_order = command
	Game.squad_target = target
	Game.squad_target_enemy = enemy if is_instance_valid(enemy) else null
	Game.troop_mode = "hold" if command in ["defend", "move", "attack", "hold"] else "follow"
	for a in Game.allies:
		if is_instance_valid(a) and Controller.can_command(a.helper, a.guard, a.truck != null):
			a.set_command(command, target, enemy)
	Game.changed.emit()


func _try_select_world(screen: Vector2) -> void:
	if controller.pending_order == "":
		return
	var sticks := get_tree().get_first_node_in_group("touch_sticks")
	if sticks != null and not Controller.can_accept_target(sticks.blocks_team_target_hud(screen), sticks.blocks_team_target_joystick(screen)):
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var from := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	var mask: int = Bullet.MASK_ENEMY | Bullet.MASK_WALL | Bullet.MASK_BUNKER | Kit.LAYER_GROUND
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * 250.0, mask)
	var hit: Dictionary = get_viewport().world_3d.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider: Object = hit.collider
	var enemy: Node3D
	var check := collider as Node
	while check != null:
		if check is Node3D and check.is_in_group("enemies"):
			enemy = check
			break
		check = check.get_parent()
	_target_release_pointer = controller.target_pointer
	var order: String = controller.complete_target(controller.target_pointer, "enemy" if is_instance_valid(enemy) else "ground")
	if order == "":
		return
	_issue(order, enemy.global_position if is_instance_valid(enemy) else hit.position, enemy)
	queue_redraw()
