class_name TeamCommands
extends Control
## Tijdelijke squadbediening; de bestaande ActionBtn en touch-zones blijven leidend.

const HOLD_TIME := 0.38
const COMMANDS := ["follow", "defend", "attack", "move"]
const LABELS := ["VOLGEN", "VERDEDIGEN", "AANVALLEN", "VERPLAATSEN"]
var button: ActionBtn
var hold_timer := 0.0
var finger := -2
var origin := Vector2.ZERO
var wheel := false
var pending := ""
var chosen := -1
var _cancel_requested := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	button = ActionBtn.make("troepen", "TEAM")
	button.visible = true
	button.custom_minimum_size = Vector2(58, 58)
	button.size = button.custom_minimum_size
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(button)
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	if button == null: return
	var v := get_viewport_rect().size
	var safe := UI.safe_margins(v)
	# Reserveer de linker middenzone voor de move-stick en de onderrand voor wapenbalk.
	var x := safe.x + 20.0 if v.x < v.y else maxf(safe.x + 100.0, v.x * 0.5 - 210.0)
	var y := v.y - safe.w - 204.0
	button.position = Vector2(clampf(x, safe.x, v.x-safe.z-button.size.x), clampf(y,safe.y,v.y-safe.w-button.size.y))

func _process(delta: float) -> void:
	button.visible = (Game.state == "play" or Game.state == "prep") and not Game.build_mode and _available()>0
	button.badge = str(_available())
	if finger != -2 and not wheel:
		hold_timer += delta
		if hold_timer >= HOLD_TIME:
			wheel = true
			queue_redraw()

func _available() -> int:
	var n := 0
	for a in Game.allies:
		if is_instance_valid(a) and not a.helper and a.truck == null: n += 1
	return n

func _toggle() -> void:
	_issue("hold" if Game.troop_mode == "follow" else "follow", Vector3.ZERO, null)

func reset_squad() -> void:
	pending = ""
	wheel = false
	chosen = -1
	finger = -2
	Game.squad_order = "follow"
	Game.squad_target = Vector3.ZERO
	Game.squad_target_enemy = null
	Game.troop_mode = "follow"
	for a in Game.allies:
		if is_instance_valid(a) and not a.helper and not a.guard: a.set_command("follow", Vector3.ZERO)
	Game.changed.emit()

func _input(e: InputEvent) -> void:
	if not button.visible: return
	if (e is InputEventScreenTouch and e.pressed and button.get_global_rect().has_point(e.position)) or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and button.get_global_rect().has_point(e.position)):
		get_viewport().set_input_as_handled()
		_cancel_requested = false
		if e is InputEventScreenTouch: finger=e.index
		else: finger=-1
		origin=e.position; hold_timer=0.0
		return
	if pending != "" and (e is InputEventScreenTouch or e is InputEventMouseButton):
		var pressed: bool = e.pressed
		var idx: int = e.index if e is InputEventScreenTouch else -1
		if pressed and (e is InputEventMouseButton or idx != finger):
			if e.position.distance_to(origin) < 32.0: return
			if e is InputEventMouseButton and e.button_index != MOUSE_BUTTON_LEFT: return
			_select_world(e.position)
			get_viewport().set_input_as_handled()
			return
		if not pressed and (e is InputEventMouseButton or idx == finger):
			pending=""; get_viewport().set_input_as_handled(); return
	if e is InputEventScreenTouch:
		if not e.pressed and e.index==finger:
			_finish(e.position); finger=-2; get_viewport().set_input_as_handled()
	elif e is InputEventScreenDrag and e.index==finger and wheel:
		chosen=_sector(e.position); queue_redraw()
	elif e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT and e.device!=InputEvent.DEVICE_ID_EMULATION:
		if not e.pressed and finger==-1: _finish(e.position); finger=-2; get_viewport().set_input_as_handled()
	elif e is InputEventMouseMotion and finger==-1 and wheel:
		chosen=_sector(e.position); queue_redraw()
	elif e is InputEventKey and e.pressed and not e.echo and e.keycode==KEY_T and not Game.build_mode:
		_toggle(); get_viewport().set_input_as_handled()

func _finish(pos: Vector2) -> void:
	if not wheel:
		_toggle()
	else:
		chosen=_sector(pos)
		if chosen>=0:
			var cmd:String=COMMANDS[chosen]
			if cmd == "follow": _issue(cmd, Vector3.ZERO, null)
			else: pending=cmd
	wheel=false; chosen=-1; queue_redraw()

func _sector(pos: Vector2) -> int:
	var d:=pos-origin
	if d.length()<24: return -1
	var angle:=fposmod(atan2(d.y,d.x)+TAU,TAU)
	return int(floor((angle+PI/4.0)/ (PI/2.0)))%4

func _draw() -> void:
	if not wheel: return
	var center:=Vector2(clampf(origin.x, 112.0, size.x-112.0),clampf(origin.y,112.0,size.y-112.0))
	for i in 4:
		var a:float=TAU*i/4.0-PI/4.0
		var p:=center+Vector2(cos(a),sin(a))*86.0
		var r:=Rect2(p-Vector2(52,24),Vector2(104,48))
		draw_rect(r,UI.PANEL,true)
		draw_rect(r,UI.BRASS if i==chosen else UI.PANEL_LINE,false,2.0)
		draw_string(UI.body(700),p+Vector2(-42,5),LABELS[i],HORIZONTAL_ALIGNMENT_LEFT,-1,13,UI.INK)

func _issue(command:String, target:Vector3, enemy:Node3D) -> void:
	Game.squad_order=command; Game.squad_target=target; Game.squad_target_enemy=enemy if is_instance_valid(enemy) else null
	Game.troop_mode="hold" if command in ["defend","move","hold"] else "follow"
	for a in Game.allies:
		if is_instance_valid(a) and not a.helper and not a.guard and a.truck == null: a.set_command(command,target,enemy)
	Game.changed.emit()

func _select_world(screen:Vector2) -> void:
	if pending == "": return
	var camera:=get_viewport().get_camera_3d()
	if camera==null:return
	var from:=camera.project_ray_origin(screen)
	var dir:=camera.project_ray_normal(screen)
	var q:=PhysicsRayQueryParameters3D.create(from,from+dir*250.0,Bullet.MASK_ENEMY|Bullet.MASK_WALL|Bullet.MASK_BUNKER|Bullet.MASK_GROUND)
	var hit:=get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty(): return
	var cmd:=pending; pending=""
	if hit.collider is Node3D and (hit.collider as Node3D).is_in_group("enemies"):
		_issue(cmd,(hit.collider as Node3D).global_position,hit.collider)
	else:
		_issue(cmd,hit.position,null)
