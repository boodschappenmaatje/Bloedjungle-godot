extends Control
## Compacte, rechtstreeks selecteerbare wapenstrook gebaseerd op Dead Nation.
## Hergebruikt Game.cur, Game.owned en Data.WEAPON_ORDER; geen nieuwe inventaris.
var _slots: Array[Button] = []
var _ammo_labels: Array[Label] = []
var _last_signature := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_layout)
	for i in Data.WEAPON_ORDER.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(51, 48)
		b.add_to_group("hud_button")
		b.add_theme_font_size_override("font_size", 10)
		b.pressed.connect(_select.bind(i))
		add_child(b)
		_slots.append(b)
	_layout()
	_refresh()

func _select(index: int) -> void:
	if Game.state != "play" and Game.state != "prep":
		return
	var id: String = Data.WEAPON_ORDER[index]
	if not Game.owned.has(id):
		return
	Game.cur = id
	Game.changed.emit()
	_refresh()

func _layout() -> void:
	var width_available := maxf(180.0, size.x - 24.0)
	var slot_width := minf(51.0, (width_available - 5.0 * 3.0) / 6.0)
	var y := size.y - (169.0 if size.x < size.y else 110.0)
	for i in _slots.size():
		_slots[i].position = Vector2(12.0 + i * (slot_width + 3.0), y)
		_slots[i].size = Vector2(slot_width, 48.0)

func _process(_delta: float) -> void:
	visible = (Game.state == "play" or Game.state == "prep") and not Game.build_mode
	if not visible:
		return
	_refresh()

func _refresh() -> void:
	for i in _slots.size():
		var id: String = Data.WEAPON_ORDER[i]
		var b: Button = _slots[i]
		var owned: bool = Game.owned.has(id)
		b.disabled = not owned
		var name_text: String = str(Data.WEAPONS[id].name)
		var short_name := name_text.substr(0, 9)
		var amount := "--"
		if owned:
			amount = str(Game.owned[id].ammo)
			if Game.player != null and Game.player.weapon == id:
				amount = str(Game.player.ammo)
		b.text = "%s\n%s" % [short_name, amount]
		var active: bool = Game.cur == id and owned
		b.add_theme_color_override("font_color", Color(1.0, 0.84, 0.47) if active else Color(0.85, 0.86, 0.81))
		b.add_theme_color_override("font_disabled_color", Color(0.48, 0.5, 0.48))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.14, 0.19, 0.15, 0.9) if active else Color(0.04, 0.08, 0.07, 0.76)
		sb.border_color = Color(1.0, 0.74, 0.31) if active else Color(0.45, 0.54, 0.43, 0.55)
		sb.set_border_width_all(2 if active else 1)
		sb.set_corner_radius_all(4)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
