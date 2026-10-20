class_name PlaceHud
extends Control
## Knop om te verdedigen: zet het gekozen ding (zandzakken, loopgraaf, mijn, prikkeldraad, MG-nest) voor je neer
## en een kleine knop ernaast om te wisselen. Alleen zichtbaar als je iets in je tas hebt.

var _place: Button
var _cycle: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place = Button.new()
	_place.add_to_group("hud_button")
	UI.style_button(_place, "gold")
	_place.pressed.connect(func(): Game.defs.place())
	add_child(_place)
	_cycle = Button.new()
	_cycle.add_to_group("hud_button")
	_cycle.text = "▶"
	UI.style_button(_cycle, "pause")
	_cycle.add_theme_font_override("font", UI.display(0))
	_cycle.custom_minimum_size = Vector2(34, 40)
	_cycle.pressed.connect(func(): Game.defs.cycle())
	add_child(_cycle)
	resized.connect(_layout)
	Game.changed.connect(_sync)
	_sync()


func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and Game.defs:
		if e.keycode == KEY_F:
			Game.defs.place()
		elif e.keycode == KEY_V:
			Game.defs.cycle()


func _sync() -> void:
	var total := 0
	for k in Game.inv:
		total += Game.inv[k]
	var show := total > 0 and (Game.state == "play" or Game.state == "prep")
	_place.visible = show
	_cycle.visible = show
	if show:
		_place.text = "ZET NEER · %s ×%d" % [Defenses.NAMES[Game.place_sel].to_upper(), Game.inv[Game.place_sel]]
		_place.reset_size()
		_layout()


func _layout() -> void:
	_place.size = Vector2(maxf(120.0, _place.get_minimum_size().x), 40)
	_cycle.size = Vector2(34, 40)
	var y := size.y - 104.0
	_place.position = Vector2(size.x - 16.0 - _place.size.x, y)
	_cycle.position = Vector2(_place.position.x - 8.0 - _cycle.size.x, y)
