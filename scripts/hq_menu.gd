class_name HqMenu
extends CanvasLayer
## Op het hoofdkwartier tikken opent een klein upgradepaneel (niveau 2 en 3), net als bij de garage. Werkt ook tijdens de golf.
## Een tik is: vinger kort neer en weer op, zonder te schuiven. Tik ergens anders om het paneel te sluiten.
## De kosten en het effect staan in Game.upgrade_hq() en HqPerks.UPGRADE_TEXT, dezelfde als in de wapenkamer (tab Basis).

const TAP_MAX_MOVE := 22.0
const TAP_MAX_TIME := 0.4
const HIT_HALF := 3.4        # m: het hoofdkwartier (4,6 m) plus een rand voor je vinger
const HIT_HEIGHT := 1.6      # m: hoogte van het vlak waarop de tik wordt omgerekend (halverwege het gebouw)

var _panel: PanelContainer
var _box: VBoxContainer
var _open := false
var _press := {}  # vinger -> {"pos": Vector2, "t": float, "moved": float}


func _ready() -> void:
	layer = 6
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UI.box(UI.PANEL, UI.PANEL_LINE, 1, 6, 10))
	_panel.custom_minimum_size.x = 300
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_bottom = -110
	_panel.visible = false
	add_child(_panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	_panel.add_child(_box)
	Game.changed.connect(_refresh)


func _process(_d: float) -> void:
	if _open and (Game.build_mode or (Game.state != "play" and Game.state != "prep")):
		_close()


func _input(event: InputEvent) -> void:
	if Game.build_mode or (Game.state != "play" and Game.state != "prep"):
		return
	var id := -2
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch:
		id = event.index
		pos = event.position
		if event.pressed:
			_press[id] = {"pos": pos, "t": Time.get_ticks_msec() / 1000.0, "moved": 0.0}
		elif _press.has(id):
			var p: Dictionary = _press[id]
			_press.erase(id)
			if p.moved < TAP_MAX_MOVE and Time.get_ticks_msec() / 1000.0 - p.t < TAP_MAX_TIME:
				_tap(pos)
	elif event is InputEventScreenDrag and _press.has(event.index):
		_press[event.index].moved = maxf(_press[event.index].moved, event.position.distance_to(_press[event.index].pos))
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press[-1] = {"pos": event.position, "t": Time.get_ticks_msec() / 1000.0, "moved": 0.0}
		elif _press.has(-1):
			var p: Dictionary = _press[-1]
			_press.erase(-1)
			if event.position.distance_to(p.pos) < TAP_MAX_MOVE and Time.get_ticks_msec() / 1000.0 - p.t < TAP_MAX_TIME:
				_tap(event.position)


func _tap(pos: Vector2) -> void:
	if _panel.visible and _panel.get_global_rect().has_point(pos):
		return
	for b: Control in get_tree().get_nodes_in_group("hud_button"):
		if b.is_visible_in_tree() and b.get_global_rect().has_point(pos):
			return
	if hit_hq(pos):
		_open = true
		Sfx.play("click")
		_refresh()
	else:
		_close()


## Valt dit schermpunt op het hoofdkwartier? (De tik wordt op een vlak halverwege het gebouw omgerekend.)
func hit_hq(pos: Vector2) -> bool:
	var hq := get_tree().get_first_node_in_group("hq") as Node3D
	var cam := get_viewport().get_camera_3d()
	if hq == null or cam == null:
		return false
	var hit = Plane(Vector3.UP, HIT_HEIGHT).intersects_ray(cam.project_ray_origin(pos), cam.project_ray_normal(pos))
	if hit == null:
		return false
	var rel: Vector3 = hit - hq.global_position
	return absf(rel.x) < HIT_HALF and absf(rel.z) < HIT_HALF


func _close() -> void:
	_open = false
	if _panel != null:
		_panel.visible = false


func _refresh() -> void:
	if not _open or _panel == null:
		return
	for ch in _box.get_children():
		ch.queue_free()
	_panel.visible = true
	var lvl: int = Game.hq_level
	var head := HBoxContainer.new()
	_box.add_child(head)
	head.add_child(UI.label("HOOFDKWARTIER · NIVEAU %d/3" % lvl, UI.display(1), 18, UI.INK))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(UI.label(UI.nl(Game.points) + " PT", UI.body(700, 0), 13, UI.BRASS))
	var x := Button.new()
	x.add_to_group("hud_button")
	x.text = "✕"
	UI.style_button(x, "pause")
	x.custom_minimum_size = Vector2(30, 30)
	x.pressed.connect(_close)
	head.add_child(x)
	var info := Label.new()
	info.text = HqPerks.UPGRADE_TEXT[clampi(lvl, 1, 3)]
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size.x = 280
	info.add_theme_font_override("font", UI.body(600, 0))
	info.add_theme_font_size_override("font_size", 12)
	info.add_theme_color_override("font_color", UI.INK_DIM)
	_box.add_child(info)
	if lvl < 3:
		var cost: int = Game.hq_upgrade_cost()
		var btn := Button.new()
		btn.add_to_group("hud_button")
		btn.text = "Upgrade naar niveau %d · %s" % [lvl + 1, UI.nl(cost)]
		UI.style_button(btn, "buy")
		btn.add_theme_font_size_override("font_size", 14)
		btn.custom_minimum_size = Vector2(280, 44)
		btn.disabled = Game.points < cost
		btn.pressed.connect(func(): Game.upgrade_hq())
		_box.add_child(btn)
