class_name BuildMode
extends Control
## Bouwmodus (16d-base.js): tussen de golven kijk je van boven op de basis. Onderaan staan kaartjes
## met gebouwen en bouwstukken: sleep er een op de kaart en laat los om te bouwen, sleep een gebouw dat
## er staat om het te verschuiven, tik erop voor het paneel. Sleep de grond om te schuiven, knijp of
## gebruik + en − om te zoomen.

const CARD_H := 78.0
const GAP := 8.0
const ORDER := ["depot", "kazerne", "garage", "helipad", "airfield", "Ziekenboeg", "Munitiedepot", "Werkplaats", "Radiopost", "zandzak", "kampmuur", "poort", "wachttoren"]
const ORDERS := {"follow": "Volgen", "hold": "Posten"}

var _ui: Control
var _btn: Button
var _info: PanelContainer
var _points: Label
var _credit: Label
var _credit_box: VBoxContainer
var _msg: Label
var _panel: PanelContainer
var _cards: Array = []
var _zoom_btns: Array = []
var _airfield_rotate_btn: Button
var _sel: Variant = null
var _gate_armed := false   # MCV-start: het kaartje POORT is gekozen; tik op een muurstuk om er een poort van te maken
var _gate_sel: Variant = null   # MCV-start: de aangetikte poort (paneel met repareren en verkopen)
var _wall_mode := "lijn"   # "lijn": een rechte muur (de richting blijft vast, zijwaarts schuiven van je vinger doet niets) of "vierkant": een rechthoek in één sleep
var _gate_pending: Variant = null   # MCV-start: [muurstuk, buurstuk, middelpunt] waar de poort komt zodra je bevestigt
var _wall_armed := false   # MCV-start: de kampmuur is gekozen; slepen over de grond trekt een muur
var _wall_plan: Dictionary = {}
var _wall_ghost: Node3D
var _hq_open := false  # MCV-start: het hoofdkwartier is aangetikt in het bouwscherm (paneel om het te draaien)
var _build_info: Label = null  # label van "In aanbouw" dat live aftelt
var _build_b: Variant = null
var _flag_for: Variant = null  # kazerne die op een tik op de grond een verzamelvlag krijgt
var _sell_arm: Variant = null
var _ptrs := {}
var _pointer_map := {}
var _drag: Dictionary = {}
var _pinch: Dictionary = {}
var _touch := false
var _ghost: Node3D
var _ghost_material: StandardMaterial3D
var _ghost_single: MeshInstance3D
var _ghost_regions: Array[MeshInstance3D] = []
var _ring: Node3D
var _msg_t := 0.0
var _airfield_armed := false
var _airfield_yaw := 0.0
var _airfield_candidate := Vector3.ZERO
var _airfield_preview_dirty := true
var _previous_bcam := Vector3.ZERO
const DRAG_THRESHOLD := 10.0


class BuildIconButton:
	extends Button
	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.38)
		var col := UI.BRASS
		var dark := Color(0.08, 0.07, 0.035, 0.95)
		for p in [Vector2(-12, 2), Vector2(4, 2), Vector2(-4, -12)]:
			var r := Rect2(c + p, Vector2(12, 12))
			draw_rect(r, col, true)
			draw_rect(r, dark, false, 1.2)
		var f: Font = UI.body(700, 1)
		draw_string(f, Vector2(0, size.y - 10.0), "BOUWEN", HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, UI.INK)


class Card:
	extends Control
	var kind := ""
	var title := ""
	var sub := ""
	var off := false

	func _draw() -> void:
		var f: Font = UI.body(700, 0)
		draw_style_box(UI.box(UI.PANEL, UI.PANEL_LINE if off else Color(UI.BRASS, 0.6), 1, 6, 0), Rect2(Vector2.ZERO, size))
		var r := Rect2(6, 5, size.x - 12, size.y - 40)
		draw_rect(r, Color(0, 0, 0, 0.25))
		_icon(r)
		draw_string(f, Vector2(0, size.y - 21), title.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, UI.INK)
		draw_string(f, Vector2(0, size.y - 7), sub, HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, UI.BRASS)
		modulate.a = 0.45 if off else 1.0

	func _p(r: Rect2, x: float, y: float) -> Vector2:
		return r.position + Vector2(x * r.size.x / 64.0, y * r.size.y / 44.0)

	func _rc(r: Rect2, x: float, y: float, w: float, h: float, c: Color) -> void:
		draw_rect(Rect2(_p(r, x, y), Vector2(w * r.size.x / 64.0, h * r.size.y / 44.0)), c)

	func _ell(r: Rect2, x: float, y: float, rx: float, ry: float, c: Color) -> void:
		var pts := PackedVector2Array()
		for i in 14:
			var a := TAU * i / 14.0
			pts.append(_p(r, x + cos(a) * rx, y + sin(a) * ry))
		draw_colored_polygon(pts, c)

	func _icon(r: Rect2) -> void:
		match kind:
			"kazerne":
				_rc(r, 4, 38, 56, 4, Color("6a6a62"))
				_rc(r, 10, 18, 40, 20, Color("56603a"))
				draw_colored_polygon(PackedVector2Array([_p(r, 6, 19), _p(r, 30, 10), _p(r, 54, 19)]), Color("7a8360"))
				_rc(r, 25, 25, 10, 13, Color("15130e"))
				_rc(r, 22, 20, 16, 4, Color("c9a227"))
				_rc(r, 51, 4, 2, 34, Color("8a8a80"))
				_rc(r, 53, 4, 9, 6, Color("3e6b2a"))
			"depot":
				_rc(r, 6, 10, 52, 30, Color("7a786c"))
				_rc(r, 12, 14, 40, 12, Color("55603a"))
				_rc(r, 10, 30, 3, 8, Color("6b6f68"))
				_rc(r, 51, 30, 3, 8, Color("6b6f68"))
				_rc(r, 10, 29, 44, 2, Color("6b6f68"))
				_rc(r, 20, 32, 9, 7, Color("6e5a3c"))
				_rc(r, 6, 38, 52, 2, Color("c9a227"))
			"zandzak":
				for p in [[14, 36], [32, 36], [50, 36], [23, 27], [41, 27], [32, 18]]:
					_ell(r, p[0], p[1], 9, 5, Color("8a7a50"))
			"kampmuur":
				_rc(r, 4, 40, 56, 3, Color("5e5e58"))
				for x in [6, 24, 42]:
					_rc(r, x, 14, 16, 26, Color("9a978c"))
				_rc(r, 6, 30, 52, 2, Color("c9a227"))
			"wachttoren":
				_rc(r, 22, 6, 20, 5, Color("8a6a3c"))
				_rc(r, 20, 12, 24, 4, Color("6a4a2a"))
				_rc(r, 24, 16, 3, 24, Color("7a5a32"))
				_rc(r, 37, 16, 3, 24, Color("7a5a32"))
				_rc(r, 26, 24, 12, 2, Color("7a5a32"))
				_rc(r, 26, 32, 12, 2, Color("7a5a32"))
			"poort":
				_rc(r, 4, 40, 56, 3, Color("5e5e58"))
				_rc(r, 4, 14, 12, 26, Color("9a978c"))
				_rc(r, 48, 14, 12, 26, Color("9a978c"))
				_rc(r, 18, 22, 28, 18, Color("5a5f48"))
				_rc(r, 18, 22, 28, 3, Color("c9a227"))
			"garage":
				_rc(r, 6, 12, 52, 28, Color("7a786c"))
				_rc(r, 4, 9, 56, 4, Color("4a4a42"))
				_rc(r, 15, 18, 34, 22, Color("5a5f48"))
			"airfield":
				# Silhouetted 1940s single-engine fighter planform, not a substitute 3D aircraft.
				_rc(r, 30, 3, 4, 38, Color("aeb39b"))
				_rc(r, 22, 19, 20, 5, Color("7f8a65"))
				_rc(r, 5, 17, 54, 4, Color("7f8a65"))
				_rc(r, 27, 30, 10, 4, Color("aeb39b"))
			"helipad":
				_rc(r, 6, 3, 52, 38, Color("6a6a60"))
				_rc(r, 11, 7, 42, 30, Color("2e2e28"))
				_ell(r, 32, 22, 11, 11, Color("c9c2a8"))
				_ell(r, 32, 22, 9, 9, Color("2e2e28"))
				_rc(r, 26, 15, 3, 14, Color("c9c2a8"))
				_rc(r, 35, 15, 3, 14, Color("c9c2a8"))
				_rc(r, 26, 21, 12, 2.5, Color("c9c2a8"))
			"Ziekenboeg":
				draw_colored_polygon(PackedVector2Array([_p(r, 6, 40), _p(r, 32, 8), _p(r, 58, 40)]), Color("c9c2a8"))
				_rc(r, 28, 14, 8, 2.6, Color("c0140f"))
				_rc(r, 30.7, 11.3, 2.6, 8, Color("c0140f"))
			"Munitiedepot":
				_rc(r, 6, 22, 24, 18, Color("5a4a2a"))
				_rc(r, 34, 22, 24, 18, Color("4e4024"))
				_rc(r, 18, 6, 26, 16, Color("665530"))
			"Werkplaats":
				_ell(r, 24, 24, 12, 12, Color("9a9a90"))
				_ell(r, 24, 24, 5, 5, Color("2a2a24"))
				draw_line(_p(r, 40, 36), _p(r, 54, 10), Color("c9a227"), 4.0)
			"Radiopost":
				_rc(r, 12, 26, 26, 14, Color("4a5230"))
				_rc(r, 45, 6, 2.5, 34, Color("8a8a80"))
				_ell(r, 20, 33, 3, 3, Color("c9a227"))


## De kaartjes onderin.
func _build_cards() -> void:
	for c in _cards:
		if is_instance_valid(c):
			c.queue_free()
	_cards.clear()
	for k in ORDER:
		var c := Card.new()
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.kind = k
		c.title = Buildings.DEFS[k].name if Buildings.DEFS.has(k) else k
		_ui.add_child(c)
		_cards.append(c)


func _ready() -> void:
	add_to_group("build_mode")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_btn = BuildIconButton.new()
	_btn.add_to_group("hud_button")
	_btn.text = ""
	_btn.tooltip_text = "Bouwmodus openen"
	_btn.focus_mode = Control.FOCUS_NONE
	var normal := UI.box(Color(0.025, 0.035, 0.025, 0.88), Color(UI.BRASS, 0.55), 1, 8, 0)
	var pressed := UI.box(Color(0.16, 0.13, 0.055, 0.96), Color(UI.BRASS, 0.8), 2, 8, 0)
	for state in ["normal", "hover", "focus", "disabled"]:
		_btn.add_theme_stylebox_override(state, normal)
	_btn.add_theme_stylebox_override("pressed", pressed)
	_btn.pressed.connect(func(): _exit() if Game.build_mode else _enter())
	add_child(_btn)
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.visible = false
	add_child(_ui)
	_make_info()
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UI.box(UI.PANEL, UI.PANEL_LINE, 1, 6, 10))
	_panel.custom_minimum_size.x = 250
	_panel.visible = false
	_ui.add_child(_panel)
	_build_cards()
	for z in ["+", "−", "⌂"]:
		var b := Button.new()
		b.add_to_group("hud_button")
		b.text = z
		UI.style_button(b, "pause")
		b.add_theme_font_size_override("font_size", 22)
		b.size = Vector2(42, 42)
		b.pressed.connect(func(): _zoom_by({"+": 0.8, "−": 1.25, "⌂": 0.0}[z]))
		_ui.add_child(b)
		_zoom_btns.append(b)
	_airfield_rotate_btn = Button.new()
	_airfield_rotate_btn.add_to_group("hud_button")
	_airfield_rotate_btn.text = "90° ↻"
	_airfield_rotate_btn.tooltip_text = "Vliegveldvoorvertoning 90 graden draaien"
	_airfield_rotate_btn.custom_minimum_size = Vector2(78, 42)
	UI.style_button(_airfield_rotate_btn, "pause")
	_airfield_rotate_btn.pressed.connect(_rotate_airfield_preview)
	_airfield_rotate_btn.visible = false
	_ui.add_child(_airfield_rotate_btn)
	resized.connect(_layout)
	Game.changed.connect(_refresh)
	_layout()


func _make_info() -> void:
	_info = PanelContainer.new()
	_info.add_theme_stylebox_override("panel", UI.box(UI.PANEL, UI.PANEL_LINE, 1, 6, 8))
	_info.position = Vector2(12, 84)
	_info.custom_minimum_size.x = 204
	_ui.add_child(_info)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	_info.add_child(vb)
	vb.add_child(UI.label("BOUWMODUS ACTIEF", UI.display(1), 17, UI.INK))
	var hint := UI.label("Sleep een kaartje op de kaart. Verschuif de kaart met één vinger; knijp met twee vingers om te zoomen.", UI.body(600, 0), 12, UI.INK_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 186
	vb.add_child(hint)
	_msg = UI.label("", UI.body(700, 0), 12, Color("ff7a6a"))
	vb.add_child(_msg)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	vb.add_child(row)
	var pb := VBoxContainer.new()
	pb.add_child(UI.label("PUNTEN", UI.body(700, 1), 11, UI.INK_DIM))
	_points = UI.label("0", UI.display(0), 18, UI.BRASS)
	pb.add_child(_points)
	row.add_child(pb)
	_credit_box = VBoxContainer.new()
	_credit_box.add_child(UI.label("BOUWTEGOED", UI.body(700, 1), 11, UI.INK_DIM))
	_credit = UI.label("0", UI.display(0), 18, UI.GOOD)
	_credit_box.add_child(_credit)
	row.add_child(_credit_box)
	var done := Button.new()
	done.add_to_group("hud_button")
	done.text = "TERUG NAAR HET VELD"
	UI.style_button(done, "gold")
	done.pressed.connect(_exit)
	vb.add_child(done)


# ---------------------------------------------------------------- in en uit

func _enter() -> void:
	if Game.build_mode or Game.player == null:
		return
	# bouwen kan altijd, ook terwijl een aanvalsgroep onderweg is (Dennis, 4 nov: "je moet altijd kunnen bouwen")
	if Game.state != "prep" and Game.state != "play":
		return
	if Game.player.elev > 0.5:
		Game.banner.emit("KOM EERST VAN DE TOREN", "", 1.4)
		return
	Game.build_mode = true
	_airfield_armed = false
	Game.airfield_build_view = false
	_previous_bcam = Game.bcam
	_sel = null
	_flag_for = null
	_sell_arm = null
	_ptrs.clear()
	_pointer_map.clear()
	_drag = {}
	_pinch = {}
	_ui.visible = true
	Sfx.play("click")
	Game.changed.emit()


func _exit() -> void:
	if not Game.build_mode:
		return
	Game.build_mode = false
	Game.airfield_build_view = false
	_airfield_armed = false
	_airfield_rotate_btn.visible = false
	Game.bcam = _previous_bcam if _previous_bcam != Vector3.ZERO else Vector3(0, 0, 1)
	_ui.visible = false
	_ptrs.clear()
	_pointer_map.clear()
	_drag = {}
	_pinch = {}
	_sel = null
	_hq_open = false
	_wall_armed = false
	_gate_armed = false
	_gate_sel = null
	_gate_pending = null
	_wall_clear_ghost()
	_flag_for = null
	if _ghost:
		_ghost.visible = false
	if _ring:
		_ring.visible = false
	for b in Game.buildings:
		b.node.visible = true
	Game.changed.emit()


func _build_text(b: Dictionary) -> String:
	return ("In aanbouw: nog %.1f s · sterkte %d" % [maxf(0.0, float(b.build_t)), ceili(b.hp)]).replace(".", ",")


func _process(delta: float) -> void:
	# "In aanbouw" telt live af; is het gebouw klaar dan springt het paneel om naar de gewone knoppen
	if _build_b != null:
		if not is_instance_valid(_build_info) or not Game.buildings.has(_build_b):
			_build_info = null
			_build_b = null
		elif Buildings.under_construction(_build_b):
			_build_info.text = _build_text(_build_b)
		else:
			_build_info = null
			_build_b = null
			_fill_panel()
	# Build access is merged into the BOUW/TEAM action in TeamCommands.
	_btn.visible = false
	var safe := UI.safe_margins(size)
	var portrait := size.x < size.y
	_btn.size = Vector2(64, 64) if portrait else Vector2(82, 82)
	var button_x := safe.x + 8.0
	if portrait:
		button_x = safe.x + 8.0
		_btn.position = Vector2(button_x, size.y - safe.w - 316.0)
	else:
		# boven de linkerjoystick (zone 152 hoog, onderin): daar staat verder niets, en hij blijft vrij van de wapenbalk
		_btn.position = Vector2(safe.x + 8.0, size.y - safe.w - 152.0 - 8.0 - _btn.size.y)
	if Game.build_mode and Game.state != "prep" and Game.state != "play":
		_exit()
	if _msg_t > 0.0:
		_msg_t -= delta
		if _msg_t <= 0.0:
			_msg.text = ""
	if Game.build_mode:
		_airfield_rotate_btn.visible = _airfield_armed
		if _airfield_armed:
			if _airfield_preview_dirty:
				_show_airfield_preview()
		_panel.position = Vector2(size.x - _panel.size.x - 12.0, 76.0)


func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_B and not Game.editing:
		if Game.build_mode:
			_exit()
		else:
			_enter()


func _say(t: String, color: Color = Color("ff7a6a"), duration := 2.2) -> void:
	_msg.text = t
	_msg.add_theme_color_override("font_color", color)
	_msg_t = duration


# ---------------------------------------------------------------- indeling

func _layout() -> void:
	var n := _cards.size()
	var w := minf(84.0, (size.x - 24.0 - GAP * (n - 1)) / n)
	var rows := 1
	if w < 60.0:
		rows = 2
		w = minf(84.0, (size.x - 24.0 - GAP * 3.0) / 4.0)
	var per := ceili(float(n) / rows)
	var total_w := per * w + (per - 1) * GAP
	var top := size.y - 10.0 - rows * CARD_H - (rows - 1) * GAP
	for i in n:
		var c: Card = _cards[i]
		c.size = Vector2(w, CARD_H)
		c.position = Vector2((size.x - total_w) / 2.0 + (i % per) * (w + GAP), top + (i / per) * (CARD_H + GAP))
		c.queue_redraw()
	for i in _zoom_btns.size():
		var b: Button = _zoom_btns[i]
		b.position = Vector2(size.x - 12.0 - (3 - i) * 42.0 - (2 - i) * 6.0, top - 54.0)
	if _airfield_rotate_btn != null:
		_airfield_rotate_btn.position = Vector2(size.x - 238.0, top - 54.0)


func _refresh() -> void:
	if Game.builds == null or _ui == null:
		return
	_points.text = UI.nl(Game.points)
	_credit.text = UI.nl(Game.build_credit)
	_credit_box.visible = Game.build_credit > 0
	for c: Card in _cards:
		if Buildings.DEFS.has(c.kind):
			var d: Dictionary = Buildings.DEFS[c.kind]
			var built := Game.builds.full(c.kind)
			var need: String = Game.builds.missing(c.kind)
			var cost: int = Buildings.cost_of(c.kind)
			c.off = built or need != "" or (c.kind != "airfield" and not Game.can_afford_build(cost))
			c.sub = ("gebouwd" if not Game.builds.is_piece(c.kind) else "max") if built else ("eerst " + String(Buildings.DEFS[need].name) if need != "" else ("GRATIS" if cost == 0 else UI.nl(cost) + " pt"))
		elif c.kind == "poort":
			c.off = not Game.mcv_deployed or not Game.can_afford_build(Kampmuur.GATE_COST)
			c.sub = UI.nl(Kampmuur.GATE_COST) + " pt"
		else:
			c.off = true
			c.sub = "binnenkort"
		c.queue_redraw()
	if not Game.build_mode:
		return
	_airfield_preview_dirty = true
	_fill_panel()


## MCV-start: voorbeeld van de muur die je trekt: groen = komt er, rood = kan niet, oranje = te weinig punten, bestaande stukken blijven zoals ze zijn.
func _wall_show(plan: Dictionary) -> void:
	if _wall_ghost == null or not is_instance_valid(_wall_ghost):
		_wall_ghost = Node3D.new()
		_wall_ghost.name = "Muurvoorbeeld"
		Game.builds.add_child(_wall_ghost)
	var edges: Array = plan.edges
	while _wall_ghost.get_child_count() < edges.size():
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(Kampmuur.STEP - 0.2, 0.4, Kampmuur.THICK + 0.3)
		mi.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_wall_ghost.add_child(mi)
	for i in _wall_ghost.get_child_count():
		var mi := _wall_ghost.get_child(i) as MeshInstance3D
		if i >= edges.size() or edges[i].state == "bestaat":
			mi.visible = false
			continue
		var e: Dictionary = edges[i]
		mi.visible = true
		mi.position = Vector3(e.at.x, 0.3, e.at.z)
		mi.rotation.y = e.yaw
		var col: Color = {"ok": Color(0.2, 0.9, 0.3, 0.55), "slecht": Color(0.95, 0.2, 0.15, 0.6), "duur": Color(1.0, 0.65, 0.15, 0.6), "poort": Color(1.0, 0.82, 0.2, 0.7)}.get(e.state, Color.WHITE)
		(mi.material_override as StandardMaterial3D).albedo_color = col
	if plan.has("quiet"):
		return
	var n := int(plan.built)
	var cost := int(plan.cost)
	_say(("%d stukken · %s" % [n, "GRATIS" if cost == 0 else "%d pt" % cost]) if n > 0 else "Sleep verder om een muur te trekken", UI.INK_DIM, 1.2)


func _wall_clear_ghost() -> void:
	_wall_plan = {}
	if _wall_ghost != null and is_instance_valid(_wall_ghost):
		_wall_ghost.queue_free()
	_wall_ghost = null


## MCV-start: het paneel van een poort die je zelf in de muur zette: repareren en verkopen.
func _fill_gate_panel() -> void:
	var g: Dictionary = _gate_sel
	_panel.visible = true
	if _ring:
		_ring.visible = false
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_panel.add_child(vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	head.add_child(UI.label("POORT", UI.display(1), 18, UI.INK))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var status := "KAPOT" if g.broken else "%d%%" % roundi(g.hp / g.max_hp * 100.0)
	head.add_child(UI.label(status, UI.body(700, 0), 13, UI.BRASS))
	var x := Button.new()
	x.add_to_group("hud_button")
	x.text = "✕"
	UI.style_button(x, "pause")
	x.custom_minimum_size = Vector2(30, 30)
	x.pressed.connect(func():
		_gate_sel = null
		_fill_panel())
	head.add_child(x)
	var info := Label.new()
	info.add_theme_font_override("font", UI.body(600, 0))
	info.add_theme_font_size_override("font_size", 13)
	info.add_theme_color_override("font_color", UI.INK_DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size.x = 226
	info.text = "Gaat vanzelf open voor jou, je soldaten en je trucks. Vijanden slaan of schieten hem kapot."
	vb.add_child(info)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	vb.add_child(row)
	var fix: int = Game.gates.repair_cost(g)
	if fix > 0:
		_act(row, "Herbouw" if g.broken else "Repareer", "%d pt" % fix, Game.can_afford_build(fix), func():
			if Game.pay_build(fix):
				Game.gates.repair(g)
			Game.changed.emit())
	_act(row, "Verkoop", "+%d tegoed" % (Kampmuur.GATE_COST / 2), true, func():
		_gate_sel = null
		Kampmuur.sell_gate(g))


## MCV-start: het paneel van het hoofdkwartier. Draaien in stappen van 90° of 15°, het voorplein en de deur draaien mee.
func _fill_hq_panel() -> void:
	_panel.visible = true
	if _ring:
		_ring.visible = false
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_panel.add_child(vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	head.add_child(UI.label("HOOFDKWARTIER", UI.display(1), 18, UI.INK))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var x := Button.new()
	x.add_to_group("hud_button")
	x.text = "✕"
	UI.style_button(x, "pause")
	x.custom_minimum_size = Vector2(30, 30)
	x.pressed.connect(func():
		_hq_open = false
		_fill_panel())
	head.add_child(x)
	var info := Label.new()
	info.add_theme_font_override("font", UI.body(600, 0))
	info.add_theme_font_size_override("font_size", 13)
	info.add_theme_color_override("font_color", UI.INK_DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size.x = 226
	info.text = "Draai het hoofdkwartier zoals jij wilt. De deur en het voorplein draaien mee; je komt na sneuvelen weer voor de deur terug."
	vb.add_child(info)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	vb.add_child(row)
	for turn_def in [["⟲ 90°", PI / 2.0], ["⟲ 15°", deg_to_rad(15.0)], ["15° ⟳", -deg_to_rad(15.0)], ["90° ⟳", -PI / 2.0]]:
		var amount: float = turn_def[1]
		_act(row, str(turn_def[0]), "", true, func():
			var r: Dictionary = Mcv.rotate_hq(get_tree(), amount)
			if not r.ok:
				_say(String(r.reason).to_upper() if String(r.reason) != "Er staat iets in de weg" else "GEEN RUIMTE")
			else:
				Sfx.play("click")
			Game.changed.emit())


## Voorbeeld van de poort (goud): de twee muurstukken die hij vervangt.
func _gate_preview(pair: Array) -> void:
	var edges: Array = []
	for k in [pair[0], pair[1]]:
		edges.append({"key": k, "at": Kampmuur.edge_center(k), "yaw": Kampmuur.edge_yaw(k), "state": "poort"})
	_wall_show({"edges": edges, "cost": Kampmuur.GATE_COST, "built": 2, "quiet": true})


## Het paneel van een poort die je nog moet bevestigen: zo komt hij nooit ergens waar je hem niet wilt.
func _fill_gate_pending_panel() -> void:
	_panel.visible = true
	if _ring:
		_ring.visible = false
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_panel.add_child(vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	head.add_child(UI.label("POORT HIER?", UI.display(1), 18, UI.INK))
	var info := Label.new()
	info.add_theme_font_override("font", UI.body(600, 0))
	info.add_theme_font_size_override("font_size", 13)
	info.add_theme_color_override("font_color", UI.INK_DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size.x = 226
	info.text = "De poort vervangt de twee gouden muurstukken (7 m). Tik op een ander muurstuk om hem te verplaatsen."
	vb.add_child(info)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	vb.add_child(row)
	var pair: Array = _gate_pending
	_act(row, "Plaats", "%d pt" % Kampmuur.GATE_COST, Game.can_afford_build(Kampmuur.GATE_COST), func():
		var r: Dictionary = Kampmuur.place_gate(pair[0], pair[2])
		_gate_pending = null
		_wall_clear_ghost()
		if r.ok:
			_gate_armed = false
		_say("POORT GEPLAATST" if r.ok else String(r.reason).to_upper(), UI.INK_DIM if r.ok else Color("ff7a6a"), 2.0)
		Game.changed.emit())
	_act(row, "Annuleer", "", true, func():
		_gate_pending = null
		_wall_clear_ghost()
		Game.changed.emit())


## Het paneel van de kampmuur: rechte lijn of vierkant, en wat er nog gratis is.
func _fill_wall_panel() -> void:
	_panel.visible = true
	if _ring:
		_ring.visible = false
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_panel.add_child(vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	head.add_child(UI.label("KAMPMUUR", UI.display(1), 18, UI.INK))
	var info := Label.new()
	info.add_theme_font_override("font", UI.body(600, 0))
	info.add_theme_font_size_override("font_size", 13)
	info.add_theme_color_override("font_color", UI.INK_DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size.x = 226
	var left := Kampmuur.free_left()
	var price := "Gratis: nog %d stukken tot je omheining compleet is." % left if left > 0 else "Elk stuk kost %d." % Kampmuur.COST
	info.text = ("LIJN: sleep een rechte muur; de richting blijft vast, je vinger mag afdwalen." if _wall_mode == "lijn" else "VIERKANT: sleep van hoek naar hoek en je krijgt vier muren in één keer.") + " " + price
	vb.add_child(info)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	vb.add_child(row)
	for m in [["lijn", "Lijn"], ["vierkant", "Vierkant"]]:
		var mode: String = m[0]
		var b := Button.new()
		b.add_to_group("hud_button")
		b.text = ("✓ " if _wall_mode == mode else "") + String(m[1])
		UI.style_button(b, "buy" if _wall_mode == mode else "pause")
		b.add_theme_font_size_override("font_size", 13)
		b.custom_minimum_size = Vector2(100, 44)
		b.pressed.connect(func():
			_wall_mode = mode
			Sfx.play("click")
			Game.changed.emit())
		row.add_child(b)


func _fill_panel() -> void:
	for ch in _panel.get_children():
		ch.queue_free()
	if _sel != null:
		_hq_open = false
		_gate_sel = null
	if _gate_sel != null:
		if Game.gates == null or not Game.gates.list.has(_gate_sel):
			_gate_sel = null
		else:
			_fill_gate_panel()
			return
	if _hq_open:
		_fill_hq_panel()
		return
	if _gate_pending != null and _sel == null:
		_fill_gate_pending_panel()
		return
	if _wall_armed and _sel == null:
		_fill_wall_panel()
		return
	var st: Variant = _sel
	_panel.visible = st != null
	if _ring:
		_ring.visible = st != null
	if st == null:
		return
	if not Game.buildings.has(st):
		_sel = null
		_panel.visible = false
		return
	var b: Dictionary = st
	var def: Dictionary = Buildings.DEFS[b.kind]
	if _sell_arm != b:
		_sell_arm = null
	_place_ring(b)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_panel.add_child(vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	head.add_child(UI.label("VLIEGVELD — VLIEGTUIGHANGAR" if b.kind == "airfield" else def.name.to_upper(), UI.display(1), 18, UI.INK))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var status := "niveau %d" % b.lv if b.kind == "kazerne" else "%d%%" % roundi(b.hp / b.max_hp * 100.0)
	if b.down:
		status = "verwoest"
	head.add_child(UI.label(status.to_upper(), UI.body(700, 0), 13, UI.BRASS))
	var x := Button.new()
	x.add_to_group("hud_button")
	x.text = "✕"
	UI.style_button(x, "pause")
	x.custom_minimum_size = Vector2(30, 30)
	x.pressed.connect(func():
		_sel = null
		_fill_panel())
	head.add_child(x)
	var info := Label.new()
	info.add_theme_font_override("font", UI.body(600, 0))
	info.add_theme_font_size_override("font_size", 13)
	info.add_theme_color_override("font_color", UI.INK_DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size.x = 226
	vb.add_child(info)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	vb.add_child(row)
	var tip := ""
	_build_info = null
	_build_b = null
	if Buildings.under_construction(b):
		_build_info = info
		_build_b = b
		info.text = _build_text(b)
		tip = "Het gebouw is nog niet klaar. Training, wagens en vliegtuigen kunnen pas als de steigers weg zijn."
	elif b.kind == "kazerne":
		var lv: Dictionary = Buildings.LEVELS[b.lv]
		var nx: Variant = Buildings.LEVELS[b.lv + 1] if b.lv + 1 < Buildings.LEVELS.size() else null
		info.text = "Soldaten %d / %d%s · %ds per man · sterkte %d" % [Game.builds.soldiers_alive(), lv.max, " · in de rij %d / %d" % [b.queue, Buildings.RIJ_MAX] if b.queue else "", roundi(float(lv.time) * Buildings.time_factor()), ceili(b.hp)]
		# de bouwrij: gevulde blokjes zijn soldaten in de rij, tik erop om de laatste te annuleren (punten terug)
		var rij := HBoxContainer.new()
		rij.add_theme_constant_override("separation", 4)
		var usable: int = mini(Buildings.RIJ_MAX, b.queue + maxi(0, Game.builds.room(b)))
		for i in Buildings.RIJ_MAX:
			var slot := RijSlot.new()
			slot.setup(i, b, i >= usable, float(lv.time) * Buildings.time_factor())
			slot.pressed.connect(func(): Game.builds.cancel_recruit(b))
			rij.add_child(slot)
		vb.add_child(rij)
		vb.move_child(rij, row.get_index())
		# een knop per soldatensoort (Data.SOLDIER_TYPES): schutter, raketsoldaat, sluipschutter, hospik, ingenieur
		var types := HBoxContainer.new()
		types.add_theme_constant_override("separation", 6)
		vb.add_child(types)
		vb.move_child(types, row.get_index())
		for sk in Data.SOLDIER_ORDER:
			var sty: Dictionary = Data.SOLDIER_TYPES[sk]
			var can_train: bool = Game.builds.room(b) > 0 and b.queue < Buildings.RIJ_MAX and Game.points >= int(sty.cost)
			var kind_key: String = sk
			_act(types, String(sty.short), "%d pt" % int(sty.cost), can_train, func(): Game.builds.recruit(b, kind_key))
		var nw: int = Game.builds.wachten_of(b).size()
		_act(row, "Wacht", "%d pt · %d/%d" % [Wachten.COST, nw, Wachten.MAX_PER_KAZERNE], Game.builds.can_buy_wacht(b), func(): Game.builds.buy_wacht(b))
		_act(row, "Vlag", "zet punt", true, func():
			_flag_for = b
			_say("Tik op de grond voor het verzamelpunt", UI.INK_DIM, 3.0))
		_act(row, "Nieuwe: " + ("vlag" if b.rally_mode == "vlag" else "volgen"), "wissel", b.has_rally, func(): Game.builds.toggle_rally_mode(b))
		if nx:
			_act(row, "Upgrade", "%d pt" % nx.cost, Game.can_afford_build(nx.cost), func(): Game.builds.upgrade(b))
		else:
			_act(row, "Max", "", false, func(): pass)
		_act(row, ORDERS[Game.troop_mode], "soldaten", true, func():
			var team := get_tree().get_first_node_in_group("team_commands")
			if team != null:
				team.toggle_follow_hold()
			else:
				Game.troop_mode = "hold" if Game.troop_mode == "follow" else "follow"
				Game.squad_order = Game.troop_mode
				for soldier in Game.allies:
					if is_instance_valid(soldier) and not soldier.helper and not soldier.guard and soldier.truck == null:
						soldier.set_command(Game.troop_mode, Vector3.ZERO)
				Game.changed.emit())
		tip = "Raket: tegen pantser · Sluip: ver, tegen mensen · Hospik: heelt · Ingen.: repareert.  " + ("Niveau %d: %d soldaten, %ds training, sterker." % [b.lv + 1, nx.max, roundi(float(nx.time) * Buildings.time_factor())] if nx else "Volledig opgewaardeerd.") + (" Je soldaten bewaken de muur." if Game.troop_mode == "hold" else " Je soldaten lopen met je mee.")
	elif b.kind == "garage":
		var have: Array = []
		for k in Buildings.VEHICLES:
			if b.has[k] > 0:
				have.append("%s ×%d" % [Buildings.VEHICLES[k].name, b.has[k]])
		info.text = "In dienst: %s · in de rij %d · sterkte %d" % [", ".join(have) if have else "nog niets", b.order.size(), ceili(b.hp)]
		# de garagerij: gevulde blokjes zijn gekochte wagens die nog moeten uitrijden, tik erop om te annuleren (punten terug)
		var grij := HBoxContainer.new()
		grij.add_theme_constant_override("separation", 4)
		for i in Buildings.VEHICLES.size():
			var kind: String = b.order[i] if i < b.order.size() else ""
			var gs := RijSlot.new()
			gs.setup(i, b, false, 0.0, kind if kind != "" else "soldier", kind != "")
			if kind == "":
				gs.glyph = "leeg"
			gs.pressed.connect(func(): Game.builds.cancel_order(b, kind))
			grij.add_child(gs)
		vb.add_child(grij)
		vb.move_child(grij, row.get_index())
		for k in Buildings.VEHICLES:
			var v: Dictionary = Buildings.VEHICLES[k]
			_act(row, v.name, "%d pt" % v.cost, Game.builds.can_buy_vehicle(b, k), func(): Game.builds.buy_vehicle(b, k))
		tip = "Een gekochte wagen staat in de rij en rijdt de garage uit zodra je het bouwscherm verlaat; tik op het blokje om te annuleren. Jeep, tank en truck bestuur je zelf: loop erheen en tik INSTAPPEN. Stuur je ze niet, dan bewaakt de tank de basis. De truck neemt tot 10 soldaten mee."
	elif b.kind == "airfield":
		var aircraft: Array = b.get("aircraft", [])
		var parked: Array[String] = []
		for item in aircraft:
			parked.append(String(item.get("kind", "aircraft")).to_upper())
		info.text = "Vliegtuigplaatsen %d / %d · %s · sterkte %d" % [aircraft.size(), AirfieldHQ23.AIRCRAFT_CAPACITY, ", ".join(parked) if parked.size() > 0 else "geen vliegtuigen", ceili(b.hp)]
		if String(b.get("spawn_status", "")) != "":
			info.text += "\n" + String(b.spawn_status)
		var aircraft_status := AirfieldHQ23.shop_status("p47")
		var aircraft_def: Dictionary = AirfieldHQ23.AIRCRAFT["p47"]
		_act(row, "P-47 Thunderbolt", "%d pt" % aircraft_def.cost, Game.builds.can_buy_aircraft(b, "p47"), func(): Game.builds.buy_aircraft(b, "p47"))
		tip = "VLIEGVELD — VLIEGTUIGHANGAR · %s. De originele Meshy Pro-bron is vereist; zonder die asset wordt niets afgerekend." % aircraft_status
	elif b.kind == "helipad":
		info.text = "In dienst: %s · sterkte %d" % ["Apache" if b.has_heli else "nog niets", ceili(b.hp)]
		_act(row, "Apache", "gekocht" if b.has_heli else "%d pt" % Buildings.HELI_COST, Game.builds.can_buy_heli(b), func(): Game.builds.buy_heli(b))
		tip = "De luiken klappen open en de lift tilt de Apache uit de grond. Tik IN om te vliegen: linker stick vliegt, rechter stick richt en schiet. LANDEN brengt hem terug op het platform."
	else:
		info.text = "Sterkte %d / %d" % [ceili(b.hp), b.max_hp]
		tip = Buildings.INFO.get(b.kind, "")
	var fix: int = Game.builds.fix_cost(b)
	if fix > 0:
		_act(row, "Herbouw" if b.down else "Repareer", "%d pt" % fix, Game.can_afford_build(fix), func():
			Game.builds.repair(b)
			Game.changed.emit())
	if b.kind != "kampmuur":   # een muurstuk zit vast op het rooster
		_act(row, "Draai", "", true, func():
			if not Game.builds.turn(b):
				_say("GEEN RUIMTE" if Game.builds.last_turn_why == "" else Game.builds.last_turn_why.to_upper())
			Game.changed.emit())
	var armed: bool = _sell_arm == b
	_act(row, "Zeker?" if armed else "Verkoop", "+%d tegoed" % Game.builds.sell_value(b), true, func():
		if armed:
			_sell_arm = null
			_sel = null
			Game.builds.sell(b)
		else:
			_sell_arm = b
			Sfx.play("click")
			Game.changed.emit())
	if tip != "":
		var t := Label.new()
		t.text = tip
		t.add_theme_font_override("font", UI.body(600, 0))
		t.add_theme_font_size_override("font_size", 12)
		t.add_theme_color_override("font_color", UI.INK_DIM)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size.x = 226
		vb.add_child(t)


func _act(row: Container, text: String, sub: String, enabled: bool, cb: Callable) -> void:
	var b := Button.new()
	b.add_to_group("hud_button")
	b.text = text if sub == "" else text + "\n" + sub
	UI.style_button(b, "buy")
	b.add_theme_font_size_override("font_size", 13)
	b.custom_minimum_size = Vector2(70, 44)
	b.disabled = not enabled
	b.pressed.connect(cb)
	row.add_child(b)


# ---------------------------------------------------------------- invoer

func _input(event: InputEvent) -> void:
	if not Game.build_mode or Game.editing:
		return
	if event is InputEventScreenTouch:
		_touch = true
		if event.pressed:
			_down(event.index, event.position)
		else:
			_up(event.index)
	elif event is InputEventScreenDrag:
		_move(event.index, event.position)
	elif event is InputEventMouse and event.device != InputEvent.DEVICE_ID_EMULATION:
		_touch = false
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					_down(-1, event.position)
				else:
					_up(-1)
			elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_by(0.9)
			elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_by(1.1)
		elif event is InputEventMouseMotion and _ptrs.has(-1):
			_move(-1, event.position)


func _over_ui(p: Vector2) -> bool:
	var ctrls: Array = [_info, _panel, _airfield_rotate_btn]
	ctrls.append_array(_zoom_btns)
	for c: Control in ctrls:
		if c.is_visible_in_tree() and c.get_global_rect().has_point(p):
			return true
	return false


func _ground(p: Vector2) -> Variant:
	var cam := get_viewport().get_camera_3d()
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(cam.project_ray_origin(p), cam.project_ray_normal(p))
	return hit


func _struct_at(g: Vector3) -> Variant:
	for b in Game.buildings:
		if b.kind == "airfield":
			var local := Vector2(g.x - b.at.x, g.z - b.at.z).rotated(b.yaw)
			for region in AirfieldHQ23.site_regions():
				var rel := (local - Vector2(region.center.x, region.center.y)).rotated(float(region.get("yaw", 0.0)))
				var half: Vector2 = region.size * 0.5 + Vector2(0.5, 0.5)
				if absf(rel.x) <= half.x and absf(rel.y) <= half.y:
					return b
			continue
		var sz: Vector3 = Buildings.DEFS[b.kind].size
		var rel: Vector3 = g - b.at
		var u := rel.dot(Vector3(cos(b.yaw), 0, -sin(b.yaw)))
		var v := rel.dot(Vector3(sin(b.yaw), 0, cos(b.yaw)))
		if absf(u) < sz.x / 2.0 + 0.3 and absf(v) < sz.z / 2.0 + 0.3:
			return b
	return null


static func _snap(v: float) -> float:
	return roundf(v * 2.0) / 2.0


func _down(id: int, pos: Vector2) -> void:
	_ptrs[id] = pos
	_pointer_map[id] = not _over_ui(pos) and not _over_card(pos)
	if _ptrs.size() == 2:
		_cancel_drag()
		var map_pointers: Array = _pointer_map.values()
		if map_pointers.size() == 2 and bool(map_pointers[0]) and bool(map_pointers[1]):
			var v: Array = _ptrs.values()
			_pinch = {"d": maxf(1.0, (v[0] - v[1]).length()), "zoom": Game.bcam.z, "mid": (v[0] + v[1]) * 0.5}
		else:
			_pinch = {"blocked": true}
		return
	if _ptrs.size() > 2:
		return
	for c: Card in _cards:
		if c.get_global_rect().has_point(pos):
			if c.off:
				Sfx.play("ping", 0.5)
				if not Buildings.DEFS.has(c.kind):
					_say(c.kind.to_upper() + " KOMT LATER")
			elif c.kind == "poort":
				_airfield_armed = false
				Game.airfield_build_view = false
				_wall_armed = false
				_gate_armed = not _gate_armed
				_gate_pending = null
				_wall_clear_ghost()
				_hq_open = false
				_gate_sel = null
				_sel = null
				_fill_panel()
				_say("Tik op het muurstuk waar de poort moet komen; je ziet eerst een voorbeeld en bevestigt zelf · tik weer op POORT om te stoppen" if _gate_armed else "Poort plaatsen uit", UI.INK_DIM, 5.0)
			elif c.kind == "kampmuur":
				_gate_armed = false
				_gate_pending = null
				_wall_clear_ghost()
				_airfield_armed = false
				Game.airfield_build_view = false
				_wall_armed = not _wall_armed
				_hq_open = false
				_gate_sel = null
				_sel = null
				_fill_panel()
				_say("Sleep over de grond om een muur te trekken · tik op een muurstuk om hem te verkopen · twee vingers verschuiven de kaart · tik weer op KAMPMUUR om te stoppen" if _wall_armed else "Muur trekken uit", UI.INK_DIM, 5.0)
			elif c.kind == "airfield":
				_wall_armed = false
				_gate_armed = false
				_airfield_armed = true
				_airfield_yaw = 0.0
				Game.airfield_build_view = true
				Game.bcam = Vector3(AirfieldHQ23.SUGGESTED_CENTER.x, AirfieldHQ23.SUGGESTED_CENTER.z, 1.0)
				_airfield_candidate = AirfieldHQ23.SUGGESTED_CENTER
				_airfield_preview_dirty = true
				_sel = null
				_fill_panel()
				_clamp_pan()
				_say("Versleep de kaart met één vinger. Tik op een geldige plek om te bouwen.", UI.INK_DIM, 3.0)
			else:
				_wall_armed = false
				_gate_armed = false
				_airfield_armed = false
				Game.airfield_build_view = false
				_drag = {"kind": c.kind, "yaw": 0.0, "ox": 0.0, "oz": 0.0, "sp": pos, "moved": false, "id": id, "st": null}
			return
	if _over_ui(pos):
		return
	var g = _ground(pos)
	if g == null:
		return
	if _flag_for != null:
		var kz: Dictionary = _flag_for
		_flag_for = null
		if Game.builds.has_method("set_rally") and Game.buildings.has(kz):
			Game.builds.set_rally(kz, Vector3(g.x, 0.0, g.z))
			_say("Verzamelpunt gezet", UI.INK_DIM, 1.6)
		_fill_panel()
		return
	var st = _struct_at(g)
	var gate_hit: Variant = Game.gates.gate_at(g) if Game.gates != null else null
	if _gate_armed and st != null and st.kind == "kampmuur":
		_drag = {"pan": true, "last": pos, "sp": pos, "moved": false, "id": id, "gate_make": st, "at": g}   # tik = poort maken, slepen = kaart
	elif gate_hit != null and not _wall_armed:
		_drag = {"pan": true, "last": pos, "sp": pos, "moved": false, "id": id, "gate_tap": gate_hit}
	elif _wall_armed and (st == null or st.kind == "kampmuur"):
		_drag = {"wall": true, "st": st, "sp": pos, "moved": false, "id": id, "path": [Kampmuur.snap_start(g)], "axis": ""}   # tik = muurstuk selecteren, slepen = muur trekken
	elif st != null and st.kind == "kampmuur":
		_drag = {"pan": true, "last": pos, "sp": pos, "moved": false, "id": id, "wall_tap": st}   # een muurstuk zit vast op het rooster: alleen tikken (selecteren), slepen = kaart
	elif st != null:
		_drag = {"kind": st.kind, "st": st, "yaw": st.yaw, "ox": st.at.x - g.x, "oz": st.at.z - g.z, "sp": pos, "moved": false, "id": id}
	elif _airfield_armed:
		_drag = {"kind": "airfield", "sp": pos, "last": pos, "moved": false, "id": id, "st": null}
	elif Mcv.hq_hit(g):
		_drag = {"pan": true, "hq": true, "last": pos, "sp": pos, "moved": false, "id": id}   # tik = paneel om het hoofdkwartier te draaien, slepen = kaart verschuiven
	else:
		_drag = {"pan": true, "last": pos, "sp": pos, "moved": false, "id": id}


func _over_card(pos: Vector2) -> bool:
	for card: Card in _cards:
		if card.get_global_rect().has_point(pos):
			return true
	return false


func _cancel_drag() -> void:
	if _drag.get("wall", false):
		_wall_clear_ghost()
		_drag = {}
		return
	if _drag.has("st") and _drag.st != null:
		_drag.st.node.visible = true
	_drag = {}
	if _ghost:
		_ghost.visible = false


func _move(id: int, pos: Vector2) -> void:
	if _ptrs.has(id):
		_ptrs[id] = pos
	if not _pinch.is_empty() and _ptrs.size() >= 2:
		if _pinch.get("blocked", false):
			return
		var v: Array = _ptrs.values()
		_set_zoom(_pinch.zoom * _pinch.d / maxf(1.0, (v[0] - v[1]).length()))
		var mid: Vector2 = (v[0] + v[1]) * 0.5   # twee vingers verschuiven de kaart ook (nodig als je met één vinger muren trekt)
		if _pinch.has("mid"):
			_pan_by_screen_drag(_pinch.mid, mid)
		_pinch["mid"] = mid
		_airfield_preview_dirty = true
		return
	if _drag.is_empty() or id != _drag.id:
		return
	if _drag.get("wall", false):
		if not _drag.moved and pos.distance_to(_drag.sp) < DRAG_THRESHOLD:
			return
		_drag.moved = true
		var gw: Variant = _ground(pos)
		if gw == null:
			return
		var vtx := Kampmuur.snap(gw)
		var start: Vector2i = _drag.path[0]
		var new_path: Array
		if _wall_mode == "vierkant":
			new_path = Kampmuur.rect_path(start, vtx)
		else:
			# een rechte lijn: de richting wordt vastgelegd zodra je meer dan een stuk weg bent van het begin, en je vinger mag daarna zijwaarts afdwalen
			var d := vtx - start
			var axis: String = _drag.get("axis", "")
			if absi(d.x) < 1 and absi(d.y) < 1:
				axis = ""
			elif axis == "":
				axis = "x" if absi(d.x) >= absi(d.y) else "y"
			elif axis == "x" and absi(d.y) >= absi(d.x) + 3:
				axis = "y"   # je gaat duidelijk een andere kant op
			elif axis == "y" and absi(d.x) >= absi(d.y) + 3:
				axis = "x"
			_drag["axis"] = axis
			var end := start
			if axis == "x":
				end = Vector2i(vtx.x, start.y)
			elif axis == "y":
				end = Vector2i(start.x, vtx.y)
			new_path = Kampmuur.line_path(start, end)
		if new_path != _drag.path:
			_drag.path = new_path
			_wall_plan = Kampmuur.plan(_drag.path)
			_wall_show(_wall_plan)
		return
	if _drag.get("kind", "") == "airfield" and _drag.get("st") == null and not _drag.moved:
		if pos.distance_to(_drag.sp) < DRAG_THRESHOLD:
			return
		_drag.moved = true
		_drag.pan = true
		_drag.last = _drag.sp
	if _drag.get("pan", false):
		if not _drag.moved and pos.distance_to(_drag.sp) < DRAG_THRESHOLD:
			return
		_drag.moved = true
		_pan_by_screen_drag(_drag.last, pos)
		_drag.last = pos
		if _airfield_armed:
			_airfield_candidate = Vector3(Game.bcam.x, 0.0, Game.bcam.y)
			_airfield_preview_dirty = true
		return
	if not _drag.moved and pos.distance_to(_drag.sp) < DRAG_THRESHOLD:
		return
	_drag.moved = true
	var g = _ground(pos)
	if g == null:
		return
	_drag.x = _snap(g.x + _drag.ox)
	_drag.z = _snap(g.z + _drag.oz)
	var at := Vector3(_drag.x, 0, _drag.z)
	_drag.status = Game.builds.placement_status(_drag.kind, at, _drag.yaw, _drag.st)
	_drag.ok = _drag.status.valid
	_show_ghost(_drag.kind, at, _drag.yaw, _drag.ok)
	if _drag.st != null:
		_drag.st.node.visible = false


func _up(id: int) -> void:
	var release_pos: Vector2 = _ptrs.get(id, Vector2.ZERO)
	_ptrs.erase(id)
	_pointer_map.erase(id)
	if _ptrs.size() < 2:
		_pinch = {}
	if _drag.is_empty() or id != _drag.id:
		return
	var d := _drag
	_drag = {}
	if _ghost:
		_ghost.visible = false
	if d.get("wall", false):
		_wall_clear_ghost()
		if not d.moved:
			if d.st != null:
				_sel = null if _sel == d.st else d.st
				_sell_arm = null
				_hq_open = false
				Game.changed.emit()
			return
		var r: Dictionary = Kampmuur.build(d.path)
		if int(r.built) > 0:
			_say("%d MUURSTUKKEN GEBOUWD" % int(r.built) if int(r.built) != 1 else "1 MUURSTUK GEBOUWD", UI.INK_DIM, 2.0)
		if int(r.poor) > 0:
			_say("ONVOLDOENDE PUNTEN VOOR %d STUKKEN" % int(r.poor))
		elif int(r.skipped) > 0 and int(r.built) == 0:
			_say("HIER KAN GEEN MUUR (%s)" % String(r.reason).to_upper())
		return
	if d.get("pan", false):
		if not d.moved and d.get("gate_make") != null:
			_sel = null
			_sell_arm = null
			var pair: Variant = Kampmuur.gate_pair(d.gate_make.edge, d.at)
			if pair == null:
				_gate_pending = null
				_wall_clear_ghost()
				_say("EEN POORT HEEFT TWEE MUURSTUKKEN NAAST ELKAAR NODIG")
			else:
				_gate_pending = pair   # eerst een voorbeeld; pas bij Plaats komt de poort er echt
				_gate_preview(pair)
			_fill_panel()
		elif not d.moved and d.get("gate_tap") != null:
			_sel = null
			_hq_open = false
			_gate_sel = null if _gate_sel == d.gate_tap else d.gate_tap
			Sfx.play("click")
			_fill_panel()
		elif not d.moved and d.get("wall_tap") != null:
			_sel = null if _sel == d.wall_tap else d.wall_tap
			_sell_arm = null
			_hq_open = false
			Sfx.play("click")
			_fill_panel()
		elif not d.moved and d.get("hq", false):
			_sel = null
			_sell_arm = null
			_hq_open = true
			Sfx.play("click")
			_fill_panel()
		elif not d.moved and (_sel != null or _hq_open or _gate_sel != null):
			_sel = null
			_sell_arm = null
			_hq_open = false
			_gate_sel = null
			_fill_panel()
		return
	if d.get("kind", "") == "airfield" and d.get("st") == null:
		if d.get("pan", false):
			return
		var ground: Variant = _ground(release_pos)
		var site: Vector3 = Vector3(_snap(ground.x), 0.0, _snap(ground.z)) if ground != null else _airfield_candidate
		_airfield_candidate = site
		var status: Dictionary = Game.builds.placement_status("airfield", site, _airfield_yaw)
		if not status.valid:
			_show_ghost("airfield", site, _airfield_yaw, false)
			_airfield_preview_dirty = false
			_set_placement_message(status.reason, false)
			return
		if not Game.can_afford_build(AirfieldHQ23.BUILD_COST):
			_show_ghost("airfield", site, _airfield_yaw, true)
			_airfield_preview_dirty = false
			_set_placement_message("Onvoldoende punten", true)
			return
		_sel = Game.builds.place("airfield", site, _airfield_yaw, true)
		if _sel != null:
			_airfield_armed = false
			Game.changed.emit()
		else:
			var retry: Dictionary = Game.builds.placement_status("airfield", site, _airfield_yaw)
			_set_placement_message("Onvoldoende punten" if retry.valid else retry.reason, retry.valid)
		return
	if d.st != null:
		d.st.node.visible = true
		if not d.moved:
			_sel = null if _sel == d.st else d.st
		elif d.get("ok", false):
			Game.builds.move_to(d.st, Vector3(d.x, 0, d.z), d.yaw)
			_sel = d.st
		else:
			_say(String(d.get("status", {}).get("reason", "Ongeldige locatie")))
	elif d.moved and d.get("ok", false) and Game.can_afford_build(Buildings.cost_of(d.kind)):
		_sel = Game.builds.place(d.kind, Vector3(d.x, 0, d.z), d.yaw, true)
	elif d.moved:
		var status: Dictionary = d.get("status", {})
		var message := String(status.get("reason", "Ongeldige locatie"))
		if status.get("valid", false):
			message = "Onvoldoende punten"
		_say(message, UI.INK_DIM if message == "Onvoldoende punten" else Color("ff7a6a"))
	_sell_arm = null
	Game.changed.emit()


func _zoom_by(f: float) -> void:
	if f == 0.0:
		Game.bcam = Vector3(AirfieldHQ23.SUGGESTED_CENTER.x, AirfieldHQ23.SUGGESTED_CENTER.z, 1.0) if Game.airfield_build_view else Vector3(0, 0, 1)
		if Game.airfield_build_view:
			_airfield_candidate = Vector3(Game.bcam.x, 0.0, Game.bcam.y)
	else:
		_set_zoom(Game.bcam.z * f)
	_airfield_preview_dirty = true
	Sfx.play("click", 0.5)


func _set_zoom(z: float) -> void:
	Game.bcam.z = clampf(z, 0.35, 3.2)   # 7A: verder uitzoomen dan vroeger (2,4)
	_clamp_pan()
	_airfield_preview_dirty = true


func _pan_by_screen_drag(from: Vector2, to: Vector2) -> void:
	var from_ground: Variant = _ground(from)
	var to_ground: Variant = _ground(to)
	if from_ground == null or to_ground == null:
		return
	var delta: Vector3 = Vector3(to_ground) - Vector3(from_ground)
	Game.bcam.x -= delta.x
	Game.bcam.y -= delta.z
	_clamp_pan()


func _clamp_pan() -> void:
	if Game.airfield_build_view:
		var quarter_turn := absf(fposmod(_airfield_yaw, PI) - PI * 0.5) < 0.01
		var half_x := AirfieldHQ23.FOOTPRINT.z * 0.5 if quarter_turn else AirfieldHQ23.FOOTPRINT.x * 0.5
		var half_z := AirfieldHQ23.FOOTPRINT.x * 0.5 if quarter_turn else AirfieldHQ23.FOOTPRINT.z * 0.5
		var cam := get_viewport().get_camera_3d()
		var view_half_x := half_x
		var view_half_z := half_z
		if cam != null:
			var rect := get_viewport().get_visible_rect().size
			var aspect := maxf(0.1, rect.x / maxf(1.0, rect.y))
			var distance := maxf(AirfieldHQ23.FOOTPRINT.x / (2.0 * tan(deg_to_rad(cam.fov * 0.5)) * aspect), AirfieldHQ23.FOOTPRINT.z / (2.0 * tan(deg_to_rad(cam.fov * 0.5)))) * 1.15 * Game.bcam.z
			var half_view_z := distance * tan(deg_to_rad(cam.fov * 0.5))
			var half_view_x := half_view_z * aspect
			view_half_x = maxf(half_x, half_view_x)
			view_half_z = maxf(half_z, half_view_z)
		var min_x := -Data.WORLD_X + 1.0 + view_half_x
		var max_x := Data.WORLD_X - 1.0 - view_half_x
		var min_z := -Data.WORLD_Z_N + 1.0 + view_half_z
		var max_z := Data.WORLD_Z_S - 1.0 - view_half_z
		Game.bcam.x = (min_x + max_x) * 0.5 if min_x > max_x else clampf(Game.bcam.x, min_x, max_x)
		Game.bcam.y = (min_z + max_z) * 0.5 if min_z > max_z else clampf(Game.bcam.y, min_z, max_z)
		return
	Game.bcam.x = clampf(Game.bcam.x, -Data.WORLD_X + 6.0, Data.WORLD_X - 6.0)
	Game.bcam.y = clampf(Game.bcam.y, -Data.WORLD_Z_N + 6.0, Data.WORLD_Z_S - 6.0)


# ---------------------------------------------------------------- spookbeeld en selectiering

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	return m


func _show_ghost(kind: String, at: Vector3, yaw: float, ok: bool) -> void:
	if _ghost == null:
		_ghost = Node3D.new()
		_ghost.name = "Airfield build preview"
		Game.builds.add_child(_ghost)
	if _ghost_material == null:
		_ghost_material = _mat(Color.WHITE)
	var tint := Color(0.25, 0.95, 0.35, 0.40) if ok else Color(0.95, 0.2, 0.15, 0.45)
	_ghost_material.albedo_color = tint
	if kind == "airfield":
		var regions := AirfieldHQ23.preview_regions()
		while _ghost_regions.size() < regions.size():
			var region_mesh := MeshInstance3D.new()
			region_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			region_mesh.material_override = _ghost_material
			_ghost.add_child(region_mesh)
			_ghost_regions.append(region_mesh)
		for i in _ghost_regions.size():
			var region_mesh := _ghost_regions[i]
			region_mesh.visible = i < regions.size()
			if i >= regions.size():
				continue
			var region: Dictionary = regions[i]
			var plane := region_mesh.mesh as PlaneMesh
			if plane == null:
				plane = PlaneMesh.new()
				region_mesh.mesh = plane
			plane.size = region.size
			var transform := AirfieldHQ23.region_transform(at, yaw, region)
			transform.origin.y = 0.18 + float(i) * 0.001
			region_mesh.global_transform = transform
		if _ghost_single != null:
			_ghost_single.visible = false
	else:
		if _ghost_single == null:
			_ghost_single = MeshInstance3D.new()
			_ghost_single.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_ghost_single.material_override = _ghost_material
			_ghost.add_child(_ghost_single)
		_ghost_single.visible = true
		for region_mesh in _ghost_regions:
			region_mesh.visible = false
		var sz: Vector3 = Buildings.DEFS[kind].size
		var bm := BoxMesh.new()
		bm.size = sz
		_ghost_single.mesh = bm
	_ghost.visible = true
	if kind != "airfield":
		_ghost_single.global_position = at + Vector3(0, Buildings.DEFS[kind].size.y * 0.5, 0)
		_ghost_single.rotation.y = yaw


func _show_airfield_preview() -> void:
	var at := _airfield_candidate if _airfield_candidate != Vector3.ZERO else AirfieldHQ23.SUGGESTED_CENTER
	var status := Game.builds.placement_status("airfield", at, _airfield_yaw)
	_show_ghost("airfield", at, _airfield_yaw, status.valid)
	var message := String(status.reason)
	var funds_issue := false
	if status.valid and not Game.can_afford_build(AirfieldHQ23.BUILD_COST):
		message = "Onvoldoende punten"
		funds_issue = true
	_set_placement_message(message, funds_issue)
	_airfield_preview_dirty = false


func _set_placement_message(message: String, funds_issue: bool) -> void:
	_msg.text = message
	_msg.add_theme_color_override("font_color", Color("e0b94c") if funds_issue else (UI.GOOD if message.begins_with("Bouwen mogelijk") else Color("ff7a6a")))
	_msg_t = 0.0

func _rotate_airfield_preview() -> void:
	_airfield_yaw = wrapf(_airfield_yaw + PI * 0.5, 0.0, TAU)
	_clamp_pan()
	_airfield_candidate = Vector3(Game.bcam.x, 0.0, Game.bcam.y)
	_airfield_preview_dirty = true
	_show_airfield_preview()


func _place_ring(b: Dictionary) -> void:
	if _ring == null:
		_ring = Node3D.new()
		_ring.name = "Build selection footprint"
		Game.builds.add_child(_ring)
	for child in _ring.get_children():
		child.queue_free()
	if b.kind == "airfield":
		var lines := ImmediateMesh.new()
		var line_material := _mat(Color(0.84, 0.68, 0.31, 0.88))
		lines.surface_begin(Mesh.PRIMITIVE_LINES, line_material)
		for region in AirfieldHQ23.site_regions():
			if region.name == "taxiway":
				continue
			var center: Vector2 = region.center
			var half: Vector2 = region.size * 0.5 + Vector2(0.35, 0.35)
			var corners := [Vector2(-half.x,-half.y),Vector2(half.x,-half.y),Vector2(half.x,half.y),Vector2(-half.x,half.y)]
			var points: Array[Vector3] = []
			for corner in corners:
				var p := center + (corner as Vector2).rotated(-float(region.get("yaw",0.0)))
				points.append(Vector3(p.x,0.08,p.y))
			for i in 4:
				lines.surface_add_vertex(points[i])
				lines.surface_add_vertex(points[(i+1)%4])
		lines.surface_end()
		var outline := MeshInstance3D.new()
		outline.mesh = lines
		outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ring.add_child(outline)
		_ring.position = b.at
		_ring.rotation.y = b.yaw
		_ring.visible = true
		return
	var sz: Vector3 = Buildings.DEFS[b.kind].size
	var mesh_instance := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(sz.x + 0.8, sz.z + 0.8)
	mesh_instance.mesh = plane
	mesh_instance.material_override = _mat(Color(0.84, 0.68, 0.31, 0.38))
	_ring.add_child(mesh_instance)
	_ring.visible = true
	_ring.global_position = b.at + Vector3(0, 0.06, 0)
	_ring.rotation.y = b.yaw
