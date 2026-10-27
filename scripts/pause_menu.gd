class_name PauseMenu
extends CanvasLayer
## Alle schermen van de web-versie die over het spel heen komen: hoofdmenu, pauze, instellingen,
## uitrusting, wapenwiel en "missie mislukt". Staat in een eigen laag boven de rest van de HUD.

const ROWS := [
	["soldaat", "Mannetjes (na nieuw spel)", [["vq2", "Realistisch"], ["v1", "Oud model"]]],
	["quality", "Grafiek", [["low", "Laag"], ["high", "Hoog"], ["ultra", "Ultra"]]],
	["time", "Tijd", [["day", "Dag"], ["dusk", "Avond"], ["night", "Nacht"]]],
	["prep", "Bouwtijd tussen golven", [["60", "1 min"], ["120", "2 min"], ["300", "5 min"], ["600", "10 min"]]],
	["weather", "Weer", [["clear", "Helder"], ["rain", "Regen"], ["mist", "Mist"]]],
	["wind", "Bomen bewegen", [["off", "Uit"], ["on", "Aan"]]],
	["treeshadow", "Boomschaduw", [["fake", "Vast"], ["real", "Echt"], ["off", "Uit"]]],
	["buildshadow", "Gebouwschaduw", [["low", "Laag"], ["medium", "Midden"], ["high", "Hoog"]]],
	["hz", "Beeldsnelheid", [["30", "30 fps"], ["60", "60 fps"], ["90", "90 fps"], ["120", "120 fps"]]],
	["fps", "FPS-teller", [["off", "Uit"], ["on", "Aan"]]],
	["t_sun", "Test: zon-schaduw", [["on", "Aan"], ["off", "Uit"]]],
	["t_jungle", "Test: jungle (bomen, gras)", [["on", "Aan"], ["off", "Uit"]]],
	["t_stad", "Test: stad zien", [["on", "Aan"], ["off", "Uit"]]],
	["t_post", "Test: mist, gloed, scherptediepte", [["on", "Aan"], ["off", "Uit"]]],
	["t_res", "Test: 3D-beeld klein (30%)", [["auto", "Uit"], ["small", "Aan"]]],
	["perf", "Prestatiemodus", [["off", "Uit"], ["on", "Aan"]]],
	["t_streak", "Test: alle killstreaks, onbeperkt", [["off", "Uit"], ["on", "Aan"]]],
	["diag", "Diagnose-run (30 s, start zelf in het spel)", [["off", "Uit"], ["on", "Aan"]]],
]
const NOTES := {
	"low": "Laag: geen schaduwen en een lichtere afbeelding, voor oudere telefoons.",
	"high": "Hoog: schaduwen dichtbij en minder gras, blijft vloeiend op 60 beeld per seconde.",
	"120": "120 fps: voor ProMotion-schermen (iPhone Pro, iPad Pro). Kost meer batterij; op een gewoon scherm blijft het 60.",
	"30": "30 fps: lager energieverbruik.",
	"90": "90 fps: werkt alleen als het scherm deze verversingssnelheid ondersteunt.",
	"low_b": "Gebouwschaduw laag: gebouwen werpen geen schaduw. Haalt 60 fps (geschat, nog niet op een iPhone gemeten).",
	"medium_b": "Gebouwschaduw midden: één schaduw per heel gebouw, ziet er hetzelfde uit als hoog. Haalt 60 fps (geschat, nog niet op een iPhone gemeten).",
	"high_b": "Gebouwschaduw hoog: elk stukje van een gebouw werpt zelf schaduw. Het zwaarst; in de stad kan het onder 60 fps komen.",
	"ultra": "Ultra gebruikt de volle kracht van nieuwe iPhones: scherpere pixels, alle schaduwen en dubbel zoveel gras.",
}

var _root: ColorRect
var _drag_sc: ScrollContainer
var _drag_id := -2
var _drag_acc := 0.0
var _drag_end := -1000
var _sheets := {}  # naam -> Control
var _pcs := {}  # naam -> het paneel zelf
var _cur := ""
var _return := "pause"
var _mute_btn: Button
var _note: Label
var _segs := {}
var _scores_box: VBoxContainer
var _gear_body: VBoxContainer
var _gear_stats: Label
var _wheel_area: Control
var _over_reason: Label
var _over_stats := {}
var _over_name: LineEdit
var _over_save_row: HBoxContainer
var _over_scores: VBoxContainer
var _saved_id := -1
var _saved := false
var over_delay := 1.4  # korte pauze voor het scherm verschijnt, zodat je de dood nog ziet


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("menus")
	Progress.load_all()
	Progress.seed_seen()
	_root = ColorRect.new()
	_root.color = Color(6.0 / 255.0, 8.0 / 255.0, 4.0 / 255.0, 0.72)
	_root.add_to_group("hud_button")
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_root.hide()
	_build_menu()
	_build_pause()
	_build_settings()
	# een nieuwe update meldt zich vanzelf, maar alleen in het hoofdmenu (nooit midden in het spel); de speler bevestigt zelf
	Updater.update_beschikbaar.connect(func(_m): if Game.state == "menu": UpdatePanel.open(self))
	_build_gear()
	_build_wheel()
	_build_over()
	Game.over.connect(_on_over)
	get_viewport().size_changed.connect(_fit_sheets)
	_show("")


# ---------------------------------------------------------------- hulpjes

func _centered(name: String, w: float) -> PanelContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var pc := PanelContainer.new()
	pc.set_meta("w", w)
	var sb := UI.box(UI.PANEL, UI.PANEL_LINE, 1, 8, 20)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 30
	pc.add_theme_stylebox_override("panel", sb)
	center.add_child(pc)
	_sheets[name] = center
	_pcs[name] = pc
	return pc


## Een blad dat binnen het scherm blijft en verticaal scrolt als het niet past.
func _scrolling(pc: PanelContainer) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.set_meta("sheet", pc)
	pc.add_child(sc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	return v


func _fit_sheets() -> void:
	var vp := get_viewport().get_visible_rect().size
	for name in _pcs:
		var pc: PanelContainer = _pcs[name]
		pc.custom_minimum_size.x = minf(pc.get_meta("w"), vp.x - 24.0)
		for c in pc.get_children():
			if c is ScrollContainer:
				c.custom_minimum_size.y = minf(c.get_child(0).get_combined_minimum_size().y, vp.y - 24.0 - 40.0)


func _button(text: String, kind: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	UI.style_button(b, kind)
	# een veeg om te scrollen telt niet als druk op de knop waar je vinger begon of eindigde
	b.pressed.connect(func():
		if Time.get_ticks_msec() - _drag_end > 200:
			cb.call())
	return b


## Met je vinger (of muis) een blad verslepen om te scrollen; de scrollbalk hoeft niet.
func _input(event: InputEvent) -> void:
	if _root == null or not _root.visible:
		return
	var pos := Vector2.ZERO
	var kind := ""
	var idx := -1
	if event is InputEventScreenTouch:
		pos = event.position
		kind = "down" if event.pressed else "up"
		idx = event.index
	elif event is InputEventScreenDrag:
		pos = event.position
		kind = "move"
		idx = event.index
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		pos = event.position
		kind = "down" if event.pressed else "up"
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		pos = event.position
		kind = "move"
	if kind == "down":
		_drag_sc = null
		for name in _pcs:
			var pc: PanelContainer = _pcs[name]
			if not pc.is_visible_in_tree():
				continue
			for c in pc.get_children():
				if c is ScrollContainer and c.get_global_rect().has_point(pos):
					_drag_sc = c
		_drag_id = idx
		_drag_acc = 0.0
	elif kind == "move" and idx == _drag_id and _drag_sc != null:
		var rel: float = event.relative.y
		_drag_acc += absf(rel)
		if _drag_acc > 12.0:
			_drag_sc.scroll_vertical -= int(rel)
			_drag_end = Time.get_ticks_msec()
	elif kind == "up" and idx == _drag_id:
		if _drag_acc > 12.0:
			_drag_end = Time.get_ticks_msec()
		_drag_id = -2
		_drag_sc = null


func _eyebrow(t: String) -> Label:
	return UI.label(t.to_upper(), UI.body(700, 2), 12, UI.BRASS)


func _head(v: Control, eyebrow: String, title: String, size := 34) -> void:
	v.add_child(_eyebrow(eyebrow))
	v.add_child(UI.label(title, UI.display(1), size, UI.INK))


func _wrap(t: String, size := 14, color := UI.INK_DIM, w := 0.0) -> Label:
	var l := UI.label(t, UI.body(500, 0), size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = w if w > 0.0 else 100.0
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _show(name: String) -> void:
	_cur = name
	_root.visible = name != ""
	_root.color.a = 0.35 if name == "gear" else (0.88 if name == "menu" else 0.72)
	for n in _sheets:
		_sheets[n].visible = n == name
	if name != "":
		_fit_sheets()
		await get_tree().process_frame  # na de regelafbreking pas kent een blad zijn echte hoogte
		_fit_sheets()


# ---------------------------------------------------------------- hoofdmenu

func _build_menu() -> void:
	var pc := _centered("menu", 880)
	var v := _scrolling(pc)
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 24)
	v.add_child(grid)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.2
	grid.add_child(left)
	left.add_child(_eyebrow("Operatie Groene Hel · 1944"))
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 0)
	title.add_child(UI.label("BLOED", UI.display(2), 56, UI.INK))
	title.add_child(UI.label("JUNGLE", UI.display(2), 56, UI.BLOOD_HI))
	left.add_child(title)
	left.add_child(_wrap("Je bent de laatste man van je eenheid. Houd de bunker overeind, zoek dekking achter de muur en koop met je punten zwaarder geschut en upgrades.", 15))
	var ctrl := GridContainer.new()
	ctrl.columns = 2
	ctrl.add_theme_constant_override("h_separation", 12)
	ctrl.add_theme_constant_override("v_separation", 4)
	left.add_child(ctrl)
	for r in [["Links", "Sleep om te lopen"], ["Rechts", "Sleep om te richten en te schieten"], ["Dekking", "Sta vlak achter de muur of een wrak. Jij schiet eroverheen, vijandelijke kogels niet."], ["Toetsenbord", "WASD · muis · Q (wissel) · B (wapenkamer)"]]:
		ctrl.add_child(UI.label(r[0], UI.body(700, 0), 15, UI.INK))
		ctrl.add_child(_wrap(r[1], 15, UI.INK_DIM, 220.0))
	var tip := _wrap("Draai je iPhone liggend voor het beste zicht.", 14, UI.INK)
	var tb := PanelContainer.new()
	var tsb := UI.box(Color(0, 0, 0, 0), UI.OLIVE_HI, 0, 0, 0)
	tsb.border_width_left = 3
	tsb.content_margin_left = 10
	tb.add_theme_stylebox_override("panel", tsb)
	tb.add_child(tip)
	left.add_child(tb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var start := _button("START MISSIE", "primary", _start_game)
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(start)
	row.add_child(_button("Uitrusting", "secondary", func(): _open_gear("menu")))
	row.add_child(_button("Instellingen", "secondary", func(): _open_settings("menu")))
	row.add_child(_button("Stadseditor", "secondary", _open_stad_editor))
	row.add_child(_button("Updates", "secondary", func(): UpdatePanel.open(self)))
	left.add_child(row)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(right)
	right.add_child(_eyebrow("Beste soldaten"))
	_scores_box = VBoxContainer.new()
	right.add_child(_scores_box)


func _score_table(into: VBoxContainer, highlight := -1) -> void:
	for c in into.get_children():
		c.queue_free()
	if Progress.scores.is_empty():
		into.add_child(_wrap("Nog geen scores. Overleef een paar golven en zet je naam bovenaan.", 14))
		return
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 5)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	into.add_child(g)
	var heads := ["#", "NAAM", "GOLF", "SCORE"]
	for i in 4:
		var l := UI.label(heads[i], UI.body(700, 2), 11, UI.INK_DIM)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL if i == 1 else Control.SIZE_FILL
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if i == 3 else HORIZONTAL_ALIGNMENT_LEFT
		g.add_child(l)
	for i in Progress.scores.size():
		var r: Dictionary = Progress.scores[i]
		var col: Color = UI.BRASS if r.id == highlight else UI.INK
		var vals := [str(i + 1), r.name, str(r.wave), UI.nl(r.score)]
		for j in 4:
			var l := UI.label(vals[j], UI.body(600, 0), 15, col)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL if j == 1 else Control.SIZE_FILL
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if j == 3 else HORIZONTAL_ALIGNMENT_LEFT
			g.add_child(l)


func show_menu() -> void:
	_score_table(_scores_box)
	_show("menu")


func _start_game() -> void:
	_show("")
	get_tree().current_scene.begin()


## Stadseditor vanuit het hoofdmenu (start de wereld op en opent hem meteen) of vanuit het pauzemenu (alleen tussen de golven).
func _open_stad_editor() -> void:
	var ed := get_tree().get_first_node_in_group("stad_editor") as StadEditor
	if ed == null:
		return
	if Game.state == "menu":
		_show("")
		await get_tree().current_scene.begin()
	else:
		if Game.state != "prep":
			Game.banner.emit("STADSEDITOR", "Alleen tussen de golven", 2.0)
			return
		set_paused(false)
	ed.enter()


# ---------------------------------------------------------------- pauze

func _build_pause() -> void:
	var v := _scrolling(_centered("pause", 380))
	v.add_child(UI.label("PAUZE", UI.display(1), 34, UI.INK))
	v.add_child(_button("VERDER", "primary", func(): set_paused(false)))
	_mute_btn = _button("", "secondary", _toggle_sound)
	v.add_child(_mute_btn)
	v.add_child(_button("Instellingen", "secondary", func(): _open_settings("pause")))
	v.add_child(_button("Stadseditor", "secondary", _open_stad_editor))
	v.add_child(_button("Updates", "secondary", func(): UpdatePanel.open(self)))
	v.add_child(_button("Stoppen", "secondary", func():
		get_tree().paused = false
		_show("")
		Game.end_game("Missie afgebroken in golf %d" % Game.wave)))
	_refresh_sound()


func set_paused(on: bool) -> void:
	if on and (Game.state == "menu" or Game.state == "over"):
		return
	get_tree().paused = on
	_show("pause" if on else "")


func is_open() -> bool:
	return _root.visible


func _toggle_sound() -> void:
	GameSettings.set_value("sound", "off" if GameSettings.get_value("sound") == "on" else "on")
	_refresh_sound()


func _refresh_sound() -> void:
	var on := GameSettings.get_value("sound") == "on"
	AudioServer.set_bus_mute(0, not on)
	_mute_btn.text = "Geluid: aan" if on else "Geluid: uit"


# ---------------------------------------------------------------- instellingen

func _build_settings() -> void:
	var v := _scrolling(_centered("settings", 520))
	_head(v, "Beeld en sfeer", "INSTELLINGEN")
	for r in ROWS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var l := UI.label(r[1].to_upper(), UI.body(700, 1), 14, UI.INK_DIM)
		l.custom_minimum_size.x = 110
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(l)
		var frame := PanelContainer.new()
		frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		frame.add_theme_stylebox_override("panel", UI.box(Color(0, 0, 0, 0), UI.PANEL_LINE, 1, 4, 0))
		var seg := HBoxContainer.new()
		seg.add_theme_constant_override("separation", 1)
		frame.add_child(seg)
		_segs[r[0]] = []
		for o in r[2]:
			var key: String = r[0]
			var val: String = o[0]
			var b := _button(o[1], "seg", func():
				GameSettings.set_value(key, val)
				_apply()
				_refresh())
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.set_meta("v", val)
			seg.add_child(b)
			_segs[key].append(b)
		row.add_child(frame)
		v.add_child(row)
	_note = _wrap("", 14, UI.INK_DIM, 440.0)
	v.add_child(_note)
	v.add_child(_button("KLAAR", "primary", func(): _show(_return)))
	_refresh()


func _open_settings(from: String) -> void:
	_return = from
	_show("settings")


func _refresh() -> void:
	for key in _segs:
		for b in _segs[key]:
			UI.seg_state(b, GameSettings.get_value(key) == b.get_meta("v"))
	_note.text = NOTES[GameSettings.get_value("quality")] + "\n" + NOTES[GameSettings.get_value("buildshadow") + "_b"]
	if GameSettings.get_value("hz") == "120":
		_note.text += "\n" + NOTES["120"]


func _apply() -> void:
	GameSettings.apply_hz()
	for n in get_tree().get_nodes_in_group("atmosphere"):
		n.apply_settings()


# ---------------------------------------------------------------- uitrusting

func _build_gear() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	_root.add_child(margin)
	_sheets["gear"] = margin
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	var pc := PanelContainer.new()
	pc.set_meta("w", 460.0)
	pc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := UI.box(UI.PANEL, UI.PANEL_LINE, 1, 8, 20)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 30
	pc.add_theme_stylebox_override("panel", sb)
	row.add_child(pc)
	_pcs["gear"] = pc
	var v := _scrolling(pc)
	_head(v, "Jouw soldaat", "UITRUSTING")
	_gear_stats = _wrap("", 13)
	v.add_child(_gear_stats)
	_gear_body = VBoxContainer.new()
	_gear_body.add_theme_constant_override("separation", 12)
	v.add_child(_gear_body)
	v.add_child(_wrap("Vergrendelde onderdelen speel je vrij met mijlpalen. Je voortgang blijft bewaard tussen missies.", 13))
	v.add_child(_button("KLAAR", "primary", func(): _show(_return)))


func _open_gear(from: String) -> void:
	_return = from
	_render_gear()
	_show("gear")


func _render_gear() -> void:
	for c in _gear_body.get_children():
		c.queue_free()
	var st := Progress.stats
	_gear_stats.text = "Beste golf %d · %d vijanden gedood · %d missies gespeeld" % [st.bestWave, st.kills, st.games]
	for slot in Progress.GEAR:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		box.add_child(UI.label(Progress.TITLES[slot].to_upper(), UI.body(700, 2), 12, UI.INK_DIM))
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		box.add_child(grid)
		for it in Progress.GEAR[slot]:
			grid.add_child(_gear_chip(slot, it))
		_gear_body.add_child(box)


func _gear_chip(slot: String, it: Dictionary) -> Button:
	var open := Progress.is_unlocked(it)
	var on: bool = Progress.item(slot).id == it.id
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(124, 74)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = not open
	var n := UI.box(Color(UI.BRASS, 0.12) if on else Color(0, 0, 0, 0.28), UI.BRASS if on else UI.PANEL_LINE, 1, 4, 8)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, n)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 8
	v.offset_top = 6
	v.offset_right = -8
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	b.add_child(v)
	var nm := HBoxContainer.new()
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nm.add_theme_constant_override("separation", 6)
	var sw: Color = it.get("color", it.get("col", Color(0, 0, 0, 0)))
	if sw.a > 0.0:
		var dot := ColorRect.new()
		dot.color = sw
		dot.custom_minimum_size = Vector2(12, 12)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nm.add_child(dot)
	nm.add_child(UI.label(it.name, UI.body(700, 0), 15, UI.INK))
	v.add_child(nm)
	var txt: String = it.bonus if open else "Vergrendeld · %s (%s)" % [Progress.unlock_text(it.unlock), Progress.progress_text(it.unlock)]
	var bl := _wrap(txt, 12, UI.BRASS if on else UI.INK_DIM)
	bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(bl)
	if not open:
		b.modulate.a = 0.55
	b.pressed.connect(func():
		Progress.sel[slot] = it.id
		Progress.save()
		Progress.recompute()
		if Game.player:
			Game.player.refresh_look()
		_render_gear())
	return b


# ---------------------------------------------------------------- wapenwiel

func _build_wheel() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	_sheets["wheel"] = center
	_wheel_area = Control.new()
	_wheel_area.custom_minimum_size = Vector2(560, 340)
	_wheel_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_wheel_area)


func open_wheel() -> void:
	if Game.state != "play" and Game.state != "prep":
		return
	for c in _wheel_area.get_children():
		c.queue_free()
	var owned: Array = Data.WEAPON_ORDER.filter(func(id): return Game.carries(id))
	var r := minf(120.0, get_viewport().get_visible_rect().size.y * 0.3)
	for i in owned.size():
		var id: String = owned[i]
		var ang := -PI / 2.0 + float(i) / owned.size() * TAU
		var slot := _wheel_slot(id)
		slot.position = Vector2(280.0 + cos(ang) * r * 1.2 - 61.0, 170.0 + sin(ang) * r - 42.0)
		_wheel_area.add_child(slot)
	var close := Button.new()
	close.focus_mode = Control.FOCUS_NONE
	close.size = Vector2(76, 76)
	close.position = Vector2(280.0 - 38.0, 170.0 - 38.0)
	close.text = "%s\nsluit" % Data.WEAPONS[Game.cur].short
	var cn := UI.box(Color(10.0 / 255.0, 8.0 / 255.0, 4.0 / 255.0, 0.7), Color(UI.BRASS, 0.4), 1, 38, 0)
	for st in ["normal", "hover", "pressed", "focus"]:
		close.add_theme_stylebox_override(st, cn)
	close.add_theme_font_override("font", UI.display(0))
	close.add_theme_font_size_override("font_size", 11)
	close.pressed.connect(func(): _close_wheel())
	_wheel_area.add_child(close)
	get_tree().paused = true
	_show("wheel")


func _wheel_slot(id: String) -> Button:
	var cur: bool = id == Game.cur
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size = Vector2(122, 84)
	var tier := _tier(id)
	var edge: Color = Color(UI.OLIVE_HI) if cur else (Color(Shop.TIER_COLORS[tier], 0.9) if tier > 0 else Color(UI.BRASS, 0.6))
	var n := UI.box(Color(0.48, 0.53, 0.26, 0.85) if cur else Color(20.0 / 255.0, 16.0 / 255.0, 8.0 / 255.0, 0.9), edge, 2, 10, 0)
	var pr := UI.box(Color(163.0 / 255.0, 16.0 / 255.0, 15.0 / 255.0, 0.6), edge, 2, 10, 0)
	for st in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(st, n)
	b.add_theme_stylebox_override("pressed", pr)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var tr := TextureRect.new()
	tr.texture = load("res://assets/ui/weapons/weapon_%s.png" % id)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(104, 44)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tr)
	for l in [UI.label(Data.WEAPONS[id].short, UI.display(0), 11, UI.INK), UI.label("%d / %d" % [Game.owned[id].ammo if not cur or Game.player == null else Game.player.ammo, Game.wstat(id).mag], UI.display(0), 11, UI.BRASS)]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	b.pressed.connect(func():
		Game.cur = id
		Game.changed.emit()
		_close_wheel())
	return b


func _tier(id: String) -> int:
	var total := 0
	for k in Game.owned[id].up:
		total += Game.owned[id].up[k]
	return 4 if total >= 16 else (3 if total >= 10 else (2 if total >= 5 else (1 if total >= 1 else 0)))


func _close_wheel() -> void:
	get_tree().paused = false
	_show("")


# ---------------------------------------------------------------- missie mislukt

func _build_over() -> void:
	var v := _scrolling(_centered("over", 560))
	_over_reason = _eyebrow("Je bent gesneuveld")
	v.add_child(_over_reason)
	v.add_child(UI.label("MISSIE MISLUKT", UI.display(1), 34, UI.INK))
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 22)
	for k in [["score", "Score"], ["wave", "Golf"], ["kills", "Doden"]]:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		var big := UI.label("0", UI.display(0), 30, UI.INK)
		col.add_child(big)
		col.add_child(UI.label(k[1].to_upper(), UI.body(700, 2), 12, UI.INK_DIM))
		_over_stats[k[0]] = big
		stats.add_child(col)
	v.add_child(stats)
	_over_save_row = HBoxContainer.new()
	_over_save_row.add_theme_constant_override("separation", 8)
	_over_name = LineEdit.new()
	_over_name.max_length = 14
	_over_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_over_name.custom_minimum_size.y = 44
	_over_name.add_theme_font_override("font", UI.body(600, 0))
	_over_name.add_theme_font_size_override("font_size", 18)
	_over_name.add_theme_color_override("font_color", UI.INK)
	var ib := UI.box(Color(0, 0, 0, 0.35), UI.PANEL_LINE, 1, 4, 10)
	_over_name.add_theme_stylebox_override("normal", ib)
	_over_name.add_theme_stylebox_override("focus", UI.box(Color(0, 0, 0, 0.35), UI.BRASS, 1, 4, 10))
	_over_save_row.add_child(_over_name)
	_over_save_row.add_child(_button("Bewaar score", "buy", _save_score))
	v.add_child(_over_save_row)
	_over_scores = VBoxContainer.new()
	v.add_child(_over_scores)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var again := _button("OPNIEUW", "primary", func():
		Progress.autostart = true
		get_tree().paused = false
		get_tree().reload_current_scene())
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(again)
	row.add_child(_button("Menu", "secondary", func():
		Progress.autostart = false
		get_tree().paused = false
		get_tree().reload_current_scene()))
	v.add_child(row)


func _on_over(reason: String) -> void:
	_saved = false
	var fresh := Progress.check_unlocks()
	Progress.save()
	await get_tree().create_timer(over_delay).timeout
	_over_reason.text = reason.to_upper()
	_over_stats.score.text = UI.nl(Game.score)
	_over_stats.wave.text = str(Game.wave)
	_over_stats.kills.text = str(Game.kills)
	_over_name.text = Progress.player_name
	_over_save_row.visible = Game.score > 0
	_score_table(_over_scores)
	if not fresh.is_empty():
		var l := _wrap("Nieuw vrijgespeeld: " + ", ".join(fresh), 14, UI.BRASS)
		_over_scores.add_child(l)
	_show("over")


func _save_score() -> void:
	if _saved:
		return
	_saved = true
	var nm := _over_name.text.strip_edges().left(14)
	Progress.player_name = nm if nm != "" else "Rambo"
	var id := Progress.add_score(Game.score, Game.wave, Game.kills)
	_over_save_row.hide()
	_score_table(_over_scores, id)


# ---------------------------------------------------------------- toetsen

func _unhandled_key_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	if e.keycode == KEY_ESCAPE:
		match _cur:
			"settings", "gear":
				_show(_return)
			"wheel":
				_close_wheel()
			"pause":
				set_paused(false)
			"":
				set_paused(true)
