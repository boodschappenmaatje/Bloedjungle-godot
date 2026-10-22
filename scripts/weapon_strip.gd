extends Control
## V66: compacte Dead Nation-geinspireerde wapenstrip.
## Het spel bezit de wapens; de HUD is uitsluitend een selectie- en informatielaag.

class WeaponGlyph:
	extends Control
	var kind: String = ""
	var tone: Color = Color.WHITE
	func _draw() -> void:
		var c := tone
		var y := size.y * 0.5
		var left := 3.0
		var right := size.x - 3.0
		# Herkenbaar zijprofiel per wapentype; geen externe assetdownloads.
		match kind:
			"m1911":
				draw_line(Vector2(5,y-5),Vector2(right-7,y-5),c,4)
				draw_line(Vector2(right-7,y-5),Vector2(right-7,y-1),c,3)
				draw_colored_polygon(PackedVector2Array([Vector2(10,y-2),Vector2(21,y-2),Vector2(17,y+11),Vector2(12,y+11)]),c)
			"bazooka":
				draw_line(Vector2(left,y-3),Vector2(right,y-3),c,7)
				draw_line(Vector2(left+4,y-9),Vector2(left+4,y+3),c,2)
				draw_line(Vector2(right-3,y-9),Vector2(right-3,y+3),c,2)
				draw_line(Vector2(22,y+1),Vector2(20,y+10),c,3)
			_:
				draw_line(Vector2(left,y-4),Vector2(right,y-4),c,4)
				draw_line(Vector2(right-13,y-8),Vector2(right-13,y-1),c,2)
				draw_line(Vector2(19,y-1),Vector2(14,y+9),c,4)
				draw_line(Vector2(left+4,y-1),Vector2(left,y+6),c,3)
				if kind == "thompson" or kind == "mg42":
					draw_line(Vector2(26,y-2),Vector2(27,y+10),c,5)
				if kind == "trench":
					draw_line(Vector2(12,y+1),Vector2(33,y+1),c,3)
				if kind == "mg42":
					draw_line(Vector2(right-11,y),Vector2(right-14,y+10),c,2)
					draw_line(Vector2(right-11,y),Vector2(right-4,y+10),c,2)

var _slots: Array[Button] = []
var _glyphs: Array[WeaponGlyph] = []
var _counts: Array[Label] = []
var _names: Array[Label] = []
var _last_state := ""
const IDS := ["m1911", "thompson", "garand", "trench", "mg42", "bazooka"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in IDS.size():
		var b := Button.new()
		b.text = ""
		b.focus_mode = Control.FOCUS_NONE
		b.add_to_group("hud_button")
		b.pressed.connect(_select.bind(i))
		add_child(b)
		_slots.append(b)
		var glyph := WeaponGlyph.new()
		glyph.kind = IDS[i]
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(glyph)
		_glyphs.append(glyph)
		var count := Label.new()
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count.add_theme_font_size_override("font_size", 12)
		b.add_child(count)
		_counts.append(count)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 9)
		b.add_child(label)
		_names.append(label)
	resized.connect(_layout)
	_layout()
	_refresh()

func _layout() -> void:
	var portrait := size.x < size.y
	var slot_w := minf(67.0, (size.x * (0.57 if not portrait else 0.94) - 18.0) / 6.0)
	var slot_h := 64.0
	var x0 := 16.0
	# Op iPhone landschap boven de linker bewegingszone, zodat de sticks vrij blijven.
	var y0 := size.y - (140.0 if not portrait else 188.0)
	for i in _slots.size():
		var b := _slots[i]
		b.position = Vector2(x0 + i * (slot_w + 3.0), y0)
		b.size = Vector2(slot_w, slot_h)
		_glyphs[i].position = Vector2(5, 5)
		_glyphs[i].size = Vector2(slot_w - 10, 29)
		_names[i].position = Vector2(1, 34)
		_names[i].size = Vector2(slot_w - 2, 13)
		_counts[i].position = Vector2(1, 46)
		_counts[i].size = Vector2(slot_w - 2, 16)

func _select(index: int) -> void:
	if Game.state != "play" and Game.state != "prep":
		return
	var id: String = IDS[index]
	if not Game.owned.has(id):
		return
	Game.cur = id
	Game.changed.emit()
	_last_state = ""
	_refresh()

func _process(_delta: float) -> void:
	visible = (Game.state == "play" or Game.state == "prep") and not Game.build_mode
	if visible:
		_refresh()

func _refresh() -> void:
	var fingerprint := Game.cur
	for id in IDS:
		fingerprint += "|" + id + ":" + (str(Game.owned[id].ammo) if Game.owned.has(id) else "-")
	if Game.player != null:
		fingerprint += ":" + str(Game.player.weapon) + ":" + str(Game.player.ammo)
	if fingerprint == _last_state:
		return
	_last_state = fingerprint
	for i in IDS.size():
		var id: String = IDS[i]
		var owned: bool = Game.owned.has(id)
		var active: bool = owned and Game.cur == id
		var color := Color(1.0, 0.88, 0.63) if active else (Color(0.79, 0.84, 0.78) if owned else Color(0.43, 0.47, 0.43))
		_slots[i].disabled = not owned
		_glyphs[i].tone = color
		_glyphs[i].queue_redraw()
		_names[i].text = str(Data.WEAPONS[id].short).substr(0, 9)
		_names[i].add_theme_color_override("font_color",color)
		var ammo := "--"
		if owned:
			ammo = str(Game.owned[id].ammo)
			if Game.player != null and Game.player.weapon == id:
				ammo = str(Game.player.ammo)
		_counts[i].text = ammo
		_counts[i].add_theme_color_override("font_color",color)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.12,0.17,0.13,0.92) if active else Color(0.035,0.06,0.05,0.79)
		sb.border_color = Color(1,0.73,0.32) if active else Color(0.35,0.45,0.35,0.35)
		sb.set_border_width_all(2 if active else 1)
		sb.set_corner_radius_all(5)
		for state in ["normal","hover","pressed","disabled","focus"]:
			_slots[i].add_theme_stylebox_override(state,sb)
