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
	z_index = 100   # het commandowiel ligt boven alle andere HUD-knoppen
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
	# Staand boven de wapenbalk, liggend aan de linkerrand tussen TACTISCH en de linkerstick: vrij van de plaatsingsbalk en wapenbalk.
	var portrait := v.x < v.y
	var x := safe.x + 20.0
	var y := v.y - safe.w - 320.0 if portrait else v.y * 0.5 - button.size.y * 0.5
	button.position = Vector2(clampf(x, safe.x, v.x - safe.z - button.size.x), clampf(y, safe.y, v.y - safe.w - button.size.y))


func _process(delta: float) -> void:
	var context := "%s:%s:%s" % [Game.state, str(Game.build_mode), str(get_tree().paused)]
	if context != _last_context:
		_last_context = context
		if Game.state in ["menu", "shop", "over"] or Game.build_mode or get_tree().paused:
			cancel_input()
	button.visible = (Game.state == "prep" or Game.state == "play") and not Game.build_mode
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
			if Game.state == "prep" or Game.state == "play":
				# tikken opent het bouwscherm, ook tijdens een aanvalsgroep (volgen/blijven: T-toets of het wiel)
				var build := get_tree().get_first_node_in_group("build_mode")
				if build != null:
					build.call("_enter")
			else:
				toggle_follow_hold()
		"issue":
			_issue(result.order, Vector3.ZERO, null)
		"target":
			if result.order == "attack":
				Game.banner.emit("AANVALLEN", "Tik op een vijand, op de grond of op het rode vlak van de vijandbasis op de radar", 3.2)
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
	# sector 0 rechts, 1 onder, 2 links, 3 boven (zelfde volgorde als LABELS)
	var icons := ["aanvallen", "verplaatsen", "verdedigen", "volgen"]
	var items: Array = []
	for i in 4:
		items.append({"label": LABELS[i], "icon": icons[i], "active": true})
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.5))
	WheelArt.draw(self, _wheel_center(), items, 0.0, controller.selected_sector)


func _wheel_center() -> Vector2:
	var safe := UI.safe_margins(size)
	var r := WheelArt.OUTER + 6.0
	# Het wiel hangt boven je duim in plaats van eromheen: bij de linkerrand lag je duim anders op VERDEDIGEN en je hand over VERPLAATSEN.
	var c: Vector2 = controller.origin + Vector2(0.0, -(WheelArt.OUTER + 8.0))
	return Vector2(clampf(c.x, safe.x + r, size.x - safe.z - r), clampf(c.y, safe.y + r, size.y - safe.w - r))


func _issue(command: String, target: Vector3, enemy: Node3D) -> void:
	Game.squad_order = command
	Game.squad_target = target
	Game.squad_target_enemy = enemy if is_instance_valid(enemy) else null
	Game.troop_mode = "hold" if command in ["defend", "move", "attack", "hold", "basis"] else "follow"
	var sent := 0
	for a in Game.allies:
		if is_instance_valid(a) and Controller.can_command(a.helper, a.guard, a.truck != null):
			a.set_command(command, target, enemy)
			sent += 1
	if command == "basis":
		if sent > 0:
			Game.banner.emit("LEGER NAAR DE VIJANDBASIS", "%d soldaten marcheren naar zijn poort. VOLGEN roept ze terug." % sent, 3.0)
		else:
			Game.banner.emit("GEEN SOLDATEN", "Bouw een kazerne en train soldaten om de vijandbasis aan te vallen.", 3.0)
	Game.changed.emit()


## De grote kaart koos een doel (wereldpunt, of de vijandbasis zelf bij Aanvallen). True als het bevel is uitgegeven.
func pick_from_map(world_pos: Vector3, on_base: bool) -> bool:
	var order: String = controller.complete_pending("ground")
	if order == "":
		return false
	if on_base and order == "attack":
		_issue("basis", VijandBasis.gate_outside(), null)
	else:
		_issue(order, world_pos, null)
	queue_redraw()
	return true


## Aanvallen op de vijandbasis (stap 5a-3a): de soldaten marcheren via de stad naar zijn poort en beschieten het hoofdkwartier.
func _attack_base() -> void:
	_target_release_pointer = controller.target_pointer
	if controller.complete_target(controller.target_pointer, "ground") == "":
		return
	_issue("basis", VijandBasis.gate_outside(), null)
	queue_redraw()


func _try_select_world(screen: Vector2) -> void:
	if controller.pending_order == "":
		return
	# een tik op de radar opent de grote kaart: daar kies je het doel, zonder dat je duim erover ligt
	var hud := get_tree().get_first_node_in_group("hud_extra")
	if hud != null and hud.radar_hit(screen):
		if hud.open_map(true):
			controller.finish_target(controller.target_pointer)   # de rest van deze aanraking is voor de kaart
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
	var hit_at: Vector3 = hit.position
	var on_base: bool = controller.pending_order == "attack" and VijandBasis.contains(hit_at, 6.0)   # ook de grond in en rond de vijandbasis (tactische camera)
	var check := collider as Node
	while check != null:
		if check is Node3D and check.is_in_group("enemies"):
			enemy = check
			break
		if check.is_in_group("vijand_basis"):
			on_base = controller.pending_order == "attack"   # muur, toren, gebouw of het HK zelf
			break
		check = check.get_parent()
	if on_base and not is_instance_valid(enemy):
		_attack_base()
		return
	_target_release_pointer = controller.target_pointer
	var order: String = controller.complete_target(controller.target_pointer, "enemy" if is_instance_valid(enemy) else "ground")
	if order == "":
		return
	_issue(order, enemy.global_position if is_instance_valid(enemy) else hit.position, enemy)
	queue_redraw()
