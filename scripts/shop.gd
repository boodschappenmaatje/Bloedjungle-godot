class_name Shop
extends Control
## De wapenkamer (24-shop.js): tussen de golven punten uitgeven aan wapens, upgrades en uitrusting.
## Bevat ook de knoppen "Winkel" (in de pauze) en "Wissel" (wapen wisselen tijdens het spel).

const TABS := ["Wapens", "Upgrades", "Uitrusting"]

var _tab := 0
var _open_btn: Button
var _swap_btn: Button
var _panel: PanelContainer
var _points: Label
var _list: VBoxContainer
var _tab_btns: Array = []
var _scroll: ScrollContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_open_btn = _button("Winkel", Vector2(-120, 206), Vector2(120, 254))
	_open_btn.pressed.connect(open)
	_swap_btn = Button.new()
	_swap_btn.text = "Wissel"
	_swap_btn.add_to_group("hud_button")
	_swap_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_swap_btn.offset_left = 150
	_swap_btn.offset_right = 250
	_swap_btn.offset_top = -64
	_swap_btn.offset_bottom = -8
	_swap_btn.pressed.connect(cycle_weapon)
	add_child(_swap_btn)
	_build_panel()
	Game.changed.connect(_sync)
	_sync()


func _button(text: String, a: Vector2, b: Vector2) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_to_group("hud_button")
	btn.anchor_left = 0.5
	btn.anchor_right = 0.5
	btn.offset_left = a.x
	btn.offset_top = a.y
	btn.offset_right = b.x
	btn.offset_bottom = b.y
	add_child(btn)
	return btn


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	var k: int = event.physical_keycode
	if k == KEY_B and (Game.state == "prep" or Game.state == "shop"):
		close() if Game.state == "shop" else open()
	elif k == KEY_Q and Game.state != "shop":
		cycle_weapon()
	elif k >= KEY_1 and k <= KEY_6 and Game.state != "shop":
		var id: String = Data.WEAPON_ORDER[k - KEY_1]
		if Game.owned.has(id):
			Game.cur = id


func _sync() -> void:
	_open_btn.visible = Game.state == "prep"
	_swap_btn.visible = Game.state == "play" and Game.owned.size() > 1
	var order: Array = Data.WEAPON_ORDER.filter(func(id): return Game.owned.has(id))
	if order.size() > 1:
		var nxt: String = order[(order.find(Game.cur) + 1) % order.size()]
		_swap_btn.text = "Wissel\n" + Data.WEAPONS[nxt].short


func cycle_weapon() -> void:
	var order: Array = Data.WEAPON_ORDER.filter(func(id): return Game.owned.has(id))
	if order.size() < 2:
		return
	Game.cur = order[(order.find(Game.cur) + 1) % order.size()]
	Game.changed.emit()


func open() -> void:
	if Game.state != "prep":
		return
	Game.state = "shop"
	_panel.show()
	_render()
	Game.changed.emit()


func close() -> void:
	_panel.hide()
	Game.state = "prep"
	Game.changed.emit()


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.add_to_group("hud_button")
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.05, 1.0)
	sb.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	_panel.hide()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_panel.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	col.add_child(top)
	var title := Label.new()
	title.text = "Wapenkamer"
	title.add_theme_font_size_override("font_size", 22)
	top.add_child(title)
	_points = Label.new()
	_points.add_theme_font_size_override("font_size", 20)
	_points.add_theme_color_override("font_color", Color(1, 0.86, 0.5))
	_points.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_points.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_points)
	var go := Button.new()
	go.text = "Verder"
	go.custom_minimum_size = Vector2(110, 40)
	go.pressed.connect(close)
	top.add_child(go)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	col.add_child(tabs)
	for i in TABS.size():
		var tb := Button.new()
		tb.text = TABS[i]
		tb.toggle_mode = true
		tb.custom_minimum_size = Vector2(0, 40)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.pressed.connect(func():
			_tab = i
			_scroll.scroll_vertical = 0
			_render())
		tabs.add_child(tb)
		_tab_btns.append(tb)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	_scroll.add_child(_list)


func _render() -> void:
	_points.text = "%d punten" % Game.points
	for i in _tab_btns.size():
		_tab_btns[i].button_pressed = i == _tab
	for c in _list.get_children():
		c.queue_free()
	match _tab:
		0:
			for id in Data.WEAPON_ORDER:
				_weapon_card(id)
		1:
			for id in Data.WEAPON_ORDER:
				if Game.owned.has(id):
					_upgrade_card(id)
		2:
			_gear_cards()


## Eén kaart: titel, uitleg en rechts een koopknop.
func _card(title: String, desc: String, spec: String, btn_text: String, enabled: bool, action: Callable, tag := "") -> void:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.15, 0.1, 1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	pc.add_theme_stylebox_override("panel", sb)
	_list.add_child(pc)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	pc.add_child(row)
	var txt := VBoxContainer.new()
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(txt)
	var t := Label.new()
	t.text = title + ("   " + tag if tag != "" else "")
	t.add_theme_font_size_override("font_size", 17)
	txt.add_child(t)
	if desc != "":
		var d := Label.new()
		d.text = desc
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.add_theme_font_size_override("font_size", 13)
		d.modulate = Color(1, 1, 1, 0.75)
		txt.add_child(d)
	if spec != "":
		var s := Label.new()
		s.text = spec
		s.add_theme_font_size_override("font_size", 13)
		s.modulate = Color(1, 0.86, 0.5, 0.9)
		txt.add_child(s)
	var b := Button.new()
	b.text = btn_text
	b.disabled = not enabled
	b.custom_minimum_size = Vector2(120, 44)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func():
		action.call()
		_render()
		Game.changed.emit())
	row.add_child(b)


func _spec(id: String) -> String:
	var w: Dictionary = Game.wstat(id)
	var pel := "%dx" % w.pellets if w.pellets > 1 else ""
	return "Schade %s%d   Tempo %d/min   Magazijn %d" % [pel, roundi(w.dmg), roundi(60.0 / w.rate), w.mag]


func _weapon_card(id: String) -> void:
	var w: Dictionary = Data.WEAPONS[id]
	var own: bool = Game.owned.has(id)
	if own:
		var equipped: bool = Game.cur == id
		_card(w.name, w.desc, _spec(id), "Uitgerust" if equipped else "Uitrusten", not equipped, func(): Game.cur = id, "In bezit")
	else:
		_card(w.name, w.desc, _spec(id), "Koop · %d" % w.price, Game.points >= w.price, func():
			if Game.buy(w.price):
				Game.owned[id] = {"up": {"dmg": 0, "rate": 0, "mag": 0, "rel": 0}, "ammo": Data.WEAPONS[id].mag}
				Game.cur = id)


func _upgrade_card(id: String) -> void:
	var w: Dictionary = Data.WEAPONS[id]
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.15, 0.1, 1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	pc.add_theme_stylebox_override("panel", sb)
	_list.add_child(pc)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	pc.add_child(col)
	var t := Label.new()
	t.text = w.name
	t.add_theme_font_size_override("font_size", 17)
	col.add_child(t)
	var s := Label.new()
	s.text = _spec(id)
	s.add_theme_font_size_override("font_size", 13)
	s.modulate = Color(1, 0.86, 0.5, 0.9)
	col.add_child(s)
	for u in Data.UPGS:
		var lvl: int = Game.owned[id].up[u[0]]
		var row := HBoxContainer.new()
		col.add_child(row)
		var l := Label.new()
		l.text = "%s  (%s)   %s" % [u[1], u[2], "●".repeat(lvl) + "○".repeat(Data.UPG_MAX - lvl)]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_font_size_override("font_size", 14)
		row.add_child(l)
		var b := Button.new()
		b.custom_minimum_size = Vector2(110, 38)
		if lvl >= Data.UPG_MAX:
			b.text = "Max"
			b.disabled = true
		else:
			var cost := Data.upg_cost(id, lvl)
			b.text = "+ · %d" % cost
			b.disabled = Game.points < cost
			var key: String = u[0]
			b.pressed.connect(func():
				if Game.buy(cost):
					Game.owned[id].up[key] += 1
					Game.owned[id].ammo = Game.wstat(id).mag
					if Game.player and id == Game.cur:
						Game.player.ammo = Game.owned[id].ammo
				_render()
				Game.changed.emit())
		row.add_child(b)


func _gear_cards() -> void:
	var p = Game.player
	var hp: float = p.hp if p else 0.0
	_card("Veldhospitaal", "Volledig genezen.", "%d / %d" % [ceili(hp), roundi(Game.max_hp())], "Genees · 200", Game.points >= 200 and hp < Game.max_hp(), func():
		if Game.buy(200) and p:
			p.hp = Game.max_hp())
	_tiered("Taaiheid", "+25 maximale gezondheid.", "maxhp", 5, 260, func():
		if Game.player:
			Game.player.hp += 25.0)
	_tiered("Kogelvrij vest", "8% minder schade per niveau.", "armor", 5, 350, func(): pass)
	_tiered("Conditie", "7% sneller lopen.", "speed", 4, 300, func(): pass)
	var missing := Game.base_max - Game.base_hp
	_card("Bunker repareren", "Herstelt 350 punten structuur.", "%d / %d" % [ceili(Game.base_hp), roundi(Game.base_max)], "Repareer · 250", Game.points >= 250 and missing > 0.0, func():
		if Game.buy(250):
			Game.base_hp = minf(Game.base_max, Game.base_hp + 350.0))
	_tiered("Beton versterken", "+300 maximale structuur en direct hersteld.", "fort", 5, 400, func():
		Game.base_max += 300.0
		Game.base_hp = Game.base_max)


func _tiered(title: String, desc: String, key: String, max_lvl: int, base_cost: int, extra: Callable) -> void:
	var lvl: int = Game.upg[key]
	var cost := base_cost * (lvl + 1)
	var pips := "●".repeat(lvl) + "○".repeat(max_lvl - lvl)
	if lvl >= max_lvl:
		_card(title, desc, pips, "Max", false, func(): pass)
	else:
		_card(title, desc, pips, "Koop · %d" % cost, Game.points >= cost, func():
			if Game.buy(cost):
				Game.upg[key] += 1
				extra.call())
