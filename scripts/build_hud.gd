class_name BuildHud
extends Control
## Bouwmodus: knop BOUWEN met een lijstje gebouwen, ZET NEER voor het spookbeeld, het kazernepaneel
## (rekruut opleiden, niveau omhoog) als je bij de deur staat, en volgen/posten voor je soldaten.

var _open := false
var _btn: Button
var _sheet: PanelContainer
var _card: Button
var _cancel: Button
var _place: Button
var _troop: Button
var _panel: PanelContainer
var _info: Label
var _train: Button
var _up: Button
var _near: Variant = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_btn = _mk("BOUWEN", "pause", 16)
	_btn.pressed.connect(func():
		_open = not _open
		_sync())
	_sheet = PanelContainer.new()
	_sheet.add_theme_stylebox_override("panel", UI.box(Color(0.05, 0.07, 0.03, 0.92), UI.PANEL_LINE, 1, 6, 8))
	add_child(_sheet)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_sheet.add_child(vb)
	var head := UI.label("BOUWEN", UI.display(1), 15, UI.BRASS)
	vb.add_child(head)
	_card = Button.new()
	_card.add_to_group("hud_button")
	UI.style_button(_card, "buy")
	_card.custom_minimum_size = Vector2(230, 56)
	_card.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_card.pressed.connect(func(): _arm("kazerne"))
	vb.add_child(_card)
	_place = _mk("ZET\nNEER", "gold", 17)
	_place.custom_minimum_size = Vector2(74, 74)
	_place.add_theme_constant_override("line_spacing", -2)
	_place.pressed.connect(func(): Game.builds.place())
	_cancel = _mk("ANNULEER", "pause", 13)
	_cancel.pressed.connect(func():
		Game.build_arm = ""
		Game.changed.emit())
	_troop = _mk("", "pause", 14)
	_troop.pressed.connect(func():
		Game.troop_mode = "hold" if Game.troop_mode == "follow" else "follow"
		Game.changed.emit())
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UI.box(Color(0.05, 0.07, 0.03, 0.92), UI.BRASS, 1, 6, 8))
	add_child(_panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 6)
	_panel.add_child(pv)
	pv.add_child(UI.label("KAZERNE", UI.display(1), 15, UI.BRASS))
	_info = UI.label("", UI.body(600, 0), 13, UI.INK)
	pv.add_child(_info)
	_train = Button.new()
	_train.add_to_group("hud_button")
	UI.style_button(_train, "buy")
	_train.custom_minimum_size = Vector2(230, 44)
	_train.pressed.connect(func():
		if _near != null:
			Game.builds.recruit(_near))
	pv.add_child(_train)
	_up = Button.new()
	_up.add_to_group("hud_button")
	UI.style_button(_up, "buy")
	_up.custom_minimum_size = Vector2(230, 44)
	_up.pressed.connect(func():
		if _near != null:
			Game.builds.upgrade(_near))
	pv.add_child(_up)
	resized.connect(_layout)
	Game.changed.connect(_sync)
	_sync()


func _mk(text: String, kind: String, fs: int) -> Button:
	var b := Button.new()
	b.add_to_group("hud_button")
	b.text = text
	UI.style_button(b, kind)
	b.add_theme_font_override("font", UI.display(1))
	b.add_theme_font_size_override("font_size", fs)
	add_child(b)
	return b


func _arm(k: String) -> void:
	if not Game.can_afford_build(Buildings.DEFS[k].cost):
		Sfx.play("ping")
		return
	Game.build_arm = k
	Game.place_armed = false
	_open = false
	Game.changed.emit()


func _process(_d: float) -> void:
	var n: Variant = Game.builds.near_barracks() if Game.builds else null
	if n != _near or (n != null and Engine.get_process_frames() % 10 == 0):
		_near = n
		_sync()


func _sync() -> void:
	if Game.builds == null:
		return
	var live := Game.state == "play" or Game.state == "prep"
	var arm := Game.build_arm != ""
	_btn.visible = live and not arm
	_sheet.visible = live and _open and not arm
	_place.visible = live and arm
	_cancel.visible = live and arm
	_troop.visible = live and not arm and Game.allies.size() > 0
	_troop.text = "SOLDATEN: " + ("VOLGEN" if Game.troop_mode == "follow" else "POSTEN")
	var d: Dictionary = Buildings.DEFS["kazerne"]
	var left: int = d.max - Game.builds.count("kazerne")
	_card.text = "  Kazerne  —  %d\n  tegoed %d  ·  punten %d  ·  nog %d te bouwen" % [d.cost, Game.build_credit, Game.points, left]
	_card.add_theme_font_size_override("font_size", 13)
	_card.disabled = left <= 0 or not Game.can_afford_build(d.cost)
	_panel.visible = live and not arm and _near != null
	if _near != null:
		var b: Dictionary = _near
		var lv: Dictionary = Buildings.LEVELS[b.lv]
		_info.text = "Niveau %d  ·  soldaten %d/%d  ·  in opleiding %d" % [b.lv, Game.builds.soldiers_alive(), lv.max, Game.builds.queued()]
		_train.text = "Schutter opleiden  —  %d" % Buildings.TRAIN_COST
		_train.disabled = Game.builds.room(b) <= 0 or Game.points < Buildings.TRAIN_COST
		var nx: Variant = Buildings.LEVELS[b.lv + 1] if b.lv + 1 < Buildings.LEVELS.size() else null
		_up.visible = nx != null
		if nx != null:
			_up.text = "Niveau %d  —  %d" % [b.lv + 1, nx.cost]
			_up.disabled = not Game.can_afford_build(nx.cost)
	_layout()


func _layout() -> void:
	_btn.size = Vector2(110, 40)
	_btn.position = Vector2(12, 128)
	_sheet.position = Vector2(12, 176)
	_troop.size = Vector2(190, 36)
	_troop.position = Vector2(12, 176)
	_panel.position = Vector2(12, 176 + (44 if _troop.visible else 0))
	var bottom := size.y - 64.0
	_place.size = Vector2(74, 74)
	_place.position = Vector2(size.x - 16.0 - 74.0, bottom - 74.0)
	_cancel.size = Vector2(100, 34)
	_cancel.position = Vector2(size.x - 16.0 - 100.0, bottom - 74.0 - 42.0)


func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and Game.builds:
		if e.keycode == KEY_B:
			if Game.build_arm != "":
				Game.builds.place()
			else:
				_open = not _open
				_sync()
