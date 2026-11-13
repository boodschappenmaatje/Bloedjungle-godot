class_name HudExtra
extends Control
## De HUD van de web-versie (23-hud.js, styles.css): balken met icoontjes linksboven, golf, vijanden,
## punten en score met pauzeknop rechtsboven, munitie rechtsonder, rode rand bij schade en
## aanvalspijltjes aan de kant waar de aanval vandaan komt.

const HUD_SCRIPT := preload("res://scripts/hud.gd")  # voor het versienummer achter de fps-teller

var _hp_bar: ProgressBar
var _base_bar: ProgressBar
var _enemies: Label
var _points: Label
var _score: Label
var _weapon: Label
var _ammo: Label
var _weapon_t := 0.0
var _last_weapon := ""
var _hurt: ColorRect
var _hurt_a := 0.0
var _last_hp := -1.0
var _veh_fill := false   # de balk heeft nu de kleur van het voertuig (groen) in plaats van die van je soldaat (rood)
var _last_vf := -1.0   # deel levenspunten van je jeep of tank bij het vorige beeld (VoertuigSchade), -1 = je zit in geen voertuig
var _arrows: Control
var _bars: VBoxContainer
var _status_panel: PanelContainer
var _top_right: HBoxContainer
var _menu: PauseMenu
var _menu_button: Button
var _fps: Label
var _camera_controls: Control
var _camera_button: Button
var _radar: Control
var _map: Control   # de grote kaart (GroteKaart), opent bij een tik op de radar
var _cv: Control    # het vlak waarop de kaart nu getekend wordt: de radar of de grote kaart
var _k := 1.0       # schaal van de stippen en lijnen: 1 op de radar, groter op de grote kaart
var _rang: RangHud
var _radar_refresh := 0.0
var _foto: KaartFoto   # luchtfoto van de wereld voor radar en kaart (keuze 2A)
var _foto_hq := false  # stond het hoofdkwartier er bij de laatste foto
## Contacten op de radar: alleen vijanden die je zelf, je torens, je soldaten of de basis kunnen zien.
## Een gezien contact blijft nog even (vervagend) staan.
const RADAR_SIGHT := 38.0  # m rond de speler
const RADAR_POST_SIGHT := 26.0  # m rond torens, soldaten en gebouwen
const RADAR_BASE_MARGIN := 8.0  # m buiten de startplek-maat rond het hoofdkwartier die de basis overziet
const RADAR_MEMORY := 2.5  # s
var _seen := {}  # instance-id -> laatste keer gezien (s)


class MenuGlyph:
	extends Control
	func _draw() -> void:
		var c := size * 0.5
		for y in [-6.0, 0.0, 6.0]:
			draw_line(c + Vector2(-8.0, y), c + Vector2(8.0, y), UI.BRASS, 2.0, true)


func _ready() -> void:
	add_to_group("hud_extra")   # TeamCommands vraagt hier of een tik op de radar valt (radar_hit) en opent de grote kaart
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hurt = ColorRect.new()
	_hurt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hurt.material = _vignette_material()
	_hurt.color = Color.WHITE
	add_child(_hurt)
	_arrows = Control.new()
	_arrows.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_arrows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrows.draw.connect(_draw_arrows)
	add_child(_arrows)
	var combat_hud := CombatTargetHud.new()
	add_child(combat_hud)
	_build_bars()
	_build_top_right()
	_build_ammo()
	_build_camera_controls()
	_build_radar()
	_rang = RangHud.new()
	_rang.name = "RangHud"
	add_child(_rang)
	_menu = PauseMenu.new()
	add_child(_menu)
	# de grote kaart in een eigen laag boven alle knoppen (de UITKLAPPEN-knop van de bouwwagen scheen er vroeger doorheen)
	var map_layer := CanvasLayer.new()
	map_layer.name = "KaartLaag"
	map_layer.layer = 40
	add_child(map_layer)
	_map = GroteKaart.new()
	_map._hud = self
	map_layer.add_child(_map)
	_foto = KaartFoto.new()
	add_child(_foto)
	_fps = _shadowed(UI.label("", UI.body(700, 0), 13, UI.GOOD))
	_fps.position = Vector2(12, 84)
	add_child(_fps)
	resized.connect(_layout)
	_layout()


func _shadowed(l: Label) -> Label:
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.add_theme_constant_override("shadow_outline_size", 2)
	return l


func _build_bars() -> void:
	_status_panel = PanelContainer.new()
	_status_panel.name = "StatusPanel"
	_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_panel.custom_minimum_size = Vector2(0, 48)
	var status_style := UI.box(Color(0.015, 0.025, 0.02, 0.88), Color(UI.PANEL_LINE, 0.82), 1, 6, 6)
	status_style.border_width_top = 2
	_status_panel.add_theme_stylebox_override("panel", status_style)
	add_child(_status_panel)
	_bars = VBoxContainer.new()
	_bars.add_theme_constant_override("separation", 5)
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_panel.add_child(_bars)
	_hp_bar = _bar_row("heart", Color8(224, 71, 58), UI.BLOOD_HI)
	_base_bar = _bar_row("base", UI.OLIVE_HI, UI.OLIVE_HI)


func _bar_row(icon: String, icon_col: Color, fill: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars.add_child(row)
	var ic := TextureRect.new()
	ic.texture = load("res://assets/ui/icons/icon_%s.png" % icon)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(14, 14)
	ic.modulate = icon_col
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.tooltip_text = "Spelergezondheid" if icon == "heart" else "Gezondheid van de basis"
	row.add_child(ic)
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.min_value = 0.0
	pb.max_value = 1.0
	pb.value = 1.0
	pb.custom_minimum_size = Vector2(0, 8)
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pb.tooltip_text = "Spelergezondheid" if icon == "heart" else "Gezondheid van de basis"
	pb.add_theme_stylebox_override("background", UI.box(Color(0, 0, 0, 0.55), Color(UI.INK, 0.25), 1, 2, 0))
	pb.add_theme_stylebox_override("fill", UI.box(fill, Color(0, 0, 0, 0), 0, 1, 0))
	row.add_child(pb)
	return pb


func _build_top_right() -> void:
	_top_right = HBoxContainer.new()
	_top_right.add_theme_constant_override("separation", 10)
	_top_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top_right)
	var en := HBoxContainer.new()
	en.add_theme_constant_override("separation", 3)
	en.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	en.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_right.add_child(en)
	var sk := TextureRect.new()
	sk.texture = load("res://assets/ui/icons/icon_skull.png")
	sk.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sk.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sk.custom_minimum_size = Vector2(14, 14)
	sk.modulate = UI.INK_DIM
	sk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	en.add_child(sk)
	_enemies = _shadowed(UI.label("–", UI.body(700, 0), 13, UI.INK_DIM))
	en.add_child(_enemies)
	_points = _shadowed(UI.label("0 pt", UI.display(0), 16, UI.BRASS))
	_points.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_top_right.add_child(_points)
	_score = _shadowed(UI.label("★ 0", UI.body(700, 0), 12, UI.INK_DIM))
	_score.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_top_right.add_child(_score)
	_menu_button = Button.new()
	_menu_button.name = "MenuButton"
	_menu_button.tooltip_text = "Pauzemenu"
	_menu_button.custom_minimum_size = Vector2(38, 34)
	_menu_button.add_to_group("hud_button")
	_menu_button.process_mode = Node.PROCESS_MODE_ALWAYS
	UI.style_button(_menu_button, "pause")
	var glyph := MenuGlyph.new()
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_button.add_child(glyph)
	_menu_button.pressed.connect(func(): _set_paused(true))


func _build_ammo() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_right = -30
	box.offset_bottom = -30
	add_child(box)
	_weapon = _shadowed(UI.label("", UI.display(1), 14, UI.INK))
	_weapon.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_weapon.modulate.a = 0.0
	box.add_child(_weapon)
	_ammo = _shadowed(UI.label("8 | 8", UI.body(700, 0), 15, UI.BRASS))
	_ammo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_ammo)
	# De munitie staat nu alleen nog onder het actieve wapen in de wapenstrip (geen dubbele weergave);
	# de naam van een nieuw wapen verschijnt kort als toast.
	_ammo.visible = false


func _build_camera_controls() -> void:
	_camera_controls = Control.new()
	_camera_controls.name = "CameraControls"
	_camera_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_camera_controls)
	_camera_button = _camera_button_new("TACTISCH", Vector2(104, 30))
	_camera_button.pressed.connect(_toggle_camera)
	_camera_controls.add_child(_camera_button)


func _camera_button_new(text_: String, button_size: Vector2) -> Button:
	var b := Button.new()
	b.name = "CameraViewButton"
	b.text = text_
	b.size = button_size
	b.add_to_group("hud_button")
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 11 if text_ == "TACTISCH" else 18)
	UI.style_button(b, "pause")
	return b


func _toggle_camera() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam != null and cam.has_method("toggle_view"):
		cam.call("toggle_view")
		_update_camera_controls()


func _update_camera_controls() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var combat: bool = cam.get("combat_view") == true
	_camera_button.text = "GEVECHT" if combat else "TACTISCH"
	_camera_button.tooltip_text = "Schakel tussen tactische en gevechtscamera"


func _build_radar() -> void:
	_radar = Control.new()
	_radar.name = "TacticalRadar"
	_radar.custom_minimum_size = Vector2(120, 128)
	_radar.size = _radar.custom_minimum_size
	_radar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radar.draw.connect(_draw_radar)
	_radar.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS   # luchtfoto verkleind zonder korrel
	add_child(_radar)
	_menu_button.size = Vector2(36, 34)
	_menu_button.position = Vector2(_radar.size.x - 38.0, 4.0)
	_radar.add_child(_menu_button)


func _radar_point(world_pos: Vector3, area: Rect2) -> Vector2:
	var fx := clampf((world_pos.x + Data.WORLD_X) / (2.0 * Data.WORLD_X), 0.0, 1.0)
	var fz := clampf((world_pos.z + Data.WORLD_Z_N) / (Data.WORLD_Z_N + Data.WORLD_Z_S), 0.0, 1.0)
	return area.position + Vector2(fx * area.size.x, fz * area.size.y)


## Het kaartvlak binnen de radar (in radar-coördinaten): onder de kop, binnen de rand.
func _radar_map() -> Rect2:
	var head := 22.0 if _radar.size.x >= 110.0 else 16.0
	return Rect2(5.0, head, _radar.size.x - 10.0, _radar.size.y - head - 5.0)


## Het rode vlakje van de vijandbasis op de radar (in radar-coördinaten), minstens 10 x 8 punten zodat het op een klein scherm te zien is.
func _base_patch(map: Rect2) -> Rect2:
	var a := _radar_point(VijandBasis.P - Vector3(VijandBasis.HALF.x, 0.0, VijandBasis.HALF.y), map)
	var b := _radar_point(VijandBasis.P + Vector3(VijandBasis.HALF.x, 0.0, VijandBasis.HALF.y), map)
	var r := Rect2(a, b - a).abs()
	var grow := Vector2(maxf(0.0, 10.0 - r.size.x), maxf(0.0, 8.0 - r.size.y)) * 0.5
	return r.grow_individual(grow.x, grow.y, grow.x, grow.y)


## Is deze tik (schermpunt) op de radar? Ruim genomen, maar het pauzeknopje in de hoek blijft een pauzeknopje.
func radar_hit(screen: Vector2) -> bool:
	if _radar == null or not _radar.visible or not _radar.is_visible_in_tree():
		return false
	if _menu_button != null and _menu_button.get_global_rect().has_point(screen):
		return false
	return _radar.get_global_rect().grow(8.0).has_point(screen)


## Mag de grote kaart nu open? Niet in menu's, tijdens pauze, bouwen of de stadseditor, en niet terwijl het commandowiel een vinger vasthoudt.
func map_allowed() -> bool:
	if _map == null or Game.state not in ["prep", "play"] or Game.build_mode or Game.editing or get_tree().paused:
		return false
	var tc := get_tree().get_first_node_in_group("team_commands")
	return tc == null or tc.controller.pointer_id == -2


## Opent de grote kaart. `target` = het commandowiel wacht op een doel: een tik op de kaart is dan dat doel.
func open_map(target: bool) -> bool:
	if not map_allowed():
		return false
	_map.open_map(target)
	if KaartFoto.tex != null and KaartFoto.age() > KaartFoto.REFRESH:
		_foto.request(1)   # de kaart is oud (nieuwe gebouwen, brand): tegel voor tegel opnieuw, de oude blijft zolang staan
	return true


func map_is_open() -> bool:
	return _map != null and _map.is_open()


## Een tik op de radar (buiten een commandokeuze) opent de grote kaart. Tijdens een commandokeuze doet TeamCommands dat zelf.
func _input(e: InputEvent) -> void:
	if _map == null or _map.is_open():
		return
	var pos := Vector2.ZERO
	if e is InputEventScreenTouch and e.pressed:
		pos = e.position
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and e.device != InputEvent.DEVICE_ID_EMULATION:
		pos = e.position
	else:
		return
	if not radar_hit(pos):
		return
	var tc := get_tree().get_first_node_in_group("team_commands")
	if tc != null and tc.controller.is_modal():
		return
	if open_map(false):
		get_viewport().set_input_as_handled()


## Staat het teamwiel te wachten op een doel voor Aanvallen?
func _attack_pending() -> bool:
	var tc := get_tree().get_first_node_in_group("team_commands")
	return tc != null and tc.controller.pending_order == "attack"


## Stap 5a-3a: de vijandbasis als rood vlakje met een stip op het HK. Tijdens een Aanvallen-keuze knippert het en staat er een lijst om: tik erop.
func _draw_vijand_basis(map: Rect2) -> void:
	var patch := _base_patch(map)
	var targeting := _attack_pending()
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 200.0)
	_cv.draw_rect(patch, Color(0.9, 0.16, 0.1, 0.5 + (0.35 * pulse if targeting else 0.1)), true)
	_cv.draw_rect(patch, Color(1.0, 0.42, 0.28, 0.95), false, 1.2 * _k)
	var hk := VijandHk.inst
	if hk == null or not hk.down:
		var dot := _radar_point(VijandBasis.hk_pos(), map)
		_cv.draw_rect(Rect2(dot - Vector2(2.0, 2.0) * _k, Vector2(4.0, 4.0) * _k), Color(1.0, 0.92, 0.55), true)
	if targeting:
		_cv.draw_rect(patch.grow((3.0 + 2.0 * pulse) * _k), Color(1.0, 0.88, 0.5, 0.9), false, 1.5 * _k)
	if Beleg.actief():
		# je leger beschiet het HK zonder jou (Beleg): oranje rand rond het vlakje
		_cv.draw_rect(patch.grow(2.0 * _k), Color(1.0, 0.62, 0.15, 0.55 + 0.4 * pulse), false, 1.6 * _k)


## Bezette stadsgebouwen (F2, keuze 3A/8A): een vlak met een rand in partijkleur, rood voor de vijand en groen voor jouw soldaten.
func _draw_garnizoenen(map: Rect2) -> void:
	for g: Garnizoen in Garnizoen.all:
		if not is_instance_valid(g) or g.partij == "" or g.bewoners.is_empty():
			continue
		var h: Woonhuis = g.huis
		var hx := float(h.spec.hx)
		var hz := float(h.spec.hz)
		var pts := PackedVector2Array()
		for c in [Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, hz)]:
			pts.append(_radar_point(h.to_global(c), map))
		var col := C_VIJAND if g.partij == "vijand" else C_EIGEN
		_cv.draw_colored_polygon(pts, Color(col, 0.38))
		pts.append(pts[0])
		_cv.draw_polyline(pts, Color(col, 0.95), 1.3 * _k, true)


## Kleuren van radar en kaart (keuze 3A): jij goud met een pijl, al je eigen eenheden groen (net als hun ringen in het spel),
## je gebouwen goud, de vijand rood.
const C_JIJ := Color(0.98, 0.8, 0.36)
const C_EIGEN := Color(0.45, 0.88, 0.36)
const C_EIGEN_HI := Color(0.74, 1.0, 0.58)
const C_GEBOUW := Color(0.86, 0.68, 0.3)
const C_VIJAND := Color(1.0, 0.3, 0.2)
const C_VAST := Color(1.0, 0.84, 0.18)   # een eigen voertuig dat vastzit (voertuigbevel, keuze 9A)
const C_RAND := Color(0.84, 0.67, 0.31)
var _first := {}   # instance-id -> eerste keer gezien (s): een nieuw contact knippert even


func _draw_radar() -> void:
	if _radar == null or not _radar.visible:
		return
	_cv = _radar
	_k = 1.0
	var bounds := Rect2(Vector2.ZERO, _radar.size)
	var head := 22.0 if _radar.size.x >= 110.0 else 16.0
	# commandoradar (keuze 1A): donker paneel met gouden rand en hoekjes, de luchtfoto als terrein
	_cv.draw_style_box(UI.box(Color(0.02, 0.03, 0.02, 0.92), Color(C_RAND, 0.55), 1, 5, 0), bounds)
	var sat: bool = Game.satelliet_t > 0.0
	if head > 6.0:
		var kop := "SAT %d" % ceili(Game.satelliet_t) if sat else "RADAR"
		_cv.draw_string(UI.body(700, 1), Vector2(7, 14), kop, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.5, 0.9, 1.0) if sat else Color(C_RAND, 0.9))
	if _radar.size.x >= 88.0:
		var north_x := _radar.size.x * 0.5
		_cv.draw_string(UI.body(700, 0), Vector2(north_x - 4.0, 13.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UI.INK)
		_cv.draw_colored_polygon(PackedVector2Array([Vector2(north_x, 15.0), Vector2(north_x - 3.5, 21.0), Vector2(north_x + 3.5, 21.0)]), UI.BRASS)
	var map := _radar_map()
	_draw_map_content(map)
	draw_frame(_cv, map, 1.0, Color(0.5, 0.9, 1.0) if sat and int(Time.get_ticks_msec() / 400) % 2 == 0 else C_RAND)


## Gouden lijst met hoekjes om een kaartvlak (radar en grote kaart).
func draw_frame(cv: Control, r: Rect2, k: float, col := C_RAND) -> void:
	cv.draw_rect(r, Color(col, 0.55), false, 1.0)
	var L := 7.0 * k
	var w := 2.0 * k
	for c in [[r.position, Vector2(1, 1)], [Vector2(r.end.x, r.position.y), Vector2(-1, 1)], [r.end, Vector2(-1, -1)], [Vector2(r.position.x, r.end.y), Vector2(1, -1)]]:
		var p: Vector2 = c[0]
		var d: Vector2 = c[1]
		cv.draw_polyline(PackedVector2Array([p + Vector2(0.0, L * d.y), p, p + Vector2(L * d.x, 0.0)]), col, w)


## Het kaartbeeld zelf: muren, rivier, vijandbasis, gebouwen, vijanden en jij. Dezelfde tekenroutine voor de radar (k = 1)
## en de grote kaart (GroteKaart, k = 2 tot 3): `canvas` is het Control waarvan we nu in de draw-aanroep zitten.
## `map` is het vlak van de hele wereld; op de ingezoomde grote kaart is dat groter dan wat je ziet (de kaart knipt de rest af).
func draw_map_on(canvas: Control, map: Rect2, k: float) -> void:
	_cv = canvas
	_k = k
	_draw_map_content(map)
	_cv = _radar
	_k = 1.0


## Terrein: de luchtfoto (KaartFoto), iets gedempt en groen-goud getint zodat de tekens erop goed te lezen zijn.
## Zolang er geen foto is: een donkergroen vlak met de rivier.
func _draw_terrain(map: Rect2) -> void:
	if KaartFoto.tex != null:
		_cv.draw_texture_rect(KaartFoto.tex, map, false, Color(0.8, 0.86, 0.72))
		_cv.draw_rect(map, Color(0.02, 0.04, 0.02, 0.28), true)
	else:
		_cv.draw_rect(map, Color(0.11, 0.16, 0.09), true)
	var river := PackedVector2Array()
	for i in 33:
		var xw: float = lerpf(-Data.WORLD_X, Data.WORLD_X, float(i) / 32.0)
		river.append(_radar_point(Vector3(xw, 0.0, Data.river_z(xw)), map))
	_cv.draw_polyline(river, Color(0.32, 0.66, 0.78, 0.45 if KaartFoto.tex != null else 0.8), (1.2 if KaartFoto.tex != null else 2.2) * _k, true)


func _draw_map_content(map: Rect2) -> void:
	_draw_terrain(map)
	_draw_vijand_basis(map)
	_draw_garnizoenen(map)
	# De bunker staat op het echte wereldnulpunt; overige markers volgen de huidige bouwdata.
	var base := _radar_point(Game.base_pos, map)
	if Game.mcv_deployed:   # pas een hoofdkwartier als de wagen is uitgeklapt
		if Game.hq_level >= 2:
			_draw_hq_radar(map, base)
		var hk := Rect2(base - Vector2(4.0, 4.0) * _k, Vector2(8, 8) * _k)
		_cv.draw_rect(hk, C_GEBOUW, true)
		_cv.draw_rect(hk, Color(0.1, 0.07, 0.02, 0.9), false, 1.0)
	for tower in get_tree().get_nodes_in_group("tower"):
		if is_instance_valid(tower) and tower is Node3D:
			var tp := _radar_point(tower.global_position, map)
			_cv.draw_colored_polygon(PackedVector2Array([tp + Vector2(0, -3.6) * _k, tp + Vector2(3.6, 0) * _k, tp + Vector2(0, 3.6) * _k, tp + Vector2(-3.6, 0) * _k]), C_GEBOUW)
	if Game.gates != null and is_instance_valid(Game.gates):
		for gate in Game.gates.list:
			var root: Variant = gate.get("root")
			if root != null and is_instance_valid(root):
				var gate_color := Color(0.4, 0.86, 0.42) if float(gate.get("open", 0.0)) > 0.8 else Color(0.92, 0.3, 0.18)
				_cv.draw_circle(_radar_point(root.global_position, map), 1.8 * _k, gate_color)
	for building in Game.buildings:
		if not building is Dictionary:
			continue
		var node: Variant = building.get("node")
		if node != null and not is_instance_valid(node):
			continue
		var at: Vector3 = building.get("at", Vector3.ZERO)
		var kind: String = str(building.get("kind", ""))
		var point := _radar_point(at, map)
		if kind in ["muur", "zandzak"]:
			_cv.draw_rect(Rect2(point - Vector2(1.5, 1.5) * _k, Vector2(3, 3) * _k), Color(C_GEBOUW, 0.7), true)
		else:
			var r := Rect2(point - Vector2(3, 3) * _k, Vector2(6, 6) * _k)
			_cv.draw_rect(r, C_GEBOUW, true)
			_cv.draw_rect(r, Color(0.1, 0.07, 0.02, 0.85), false, 1.0)
	# eigen voertuigen (jeep, tank, auto's, bus, bouwwagen) en voorraadtrucks: groene silhouetjes
	for v in get_tree().get_nodes_in_group("voertuigen"):
		if is_instance_valid(v) and v is Node3D and (v as Node3D).is_visible_in_tree():
			_draw_vehicle(_radar_point(v.global_position, map), (v as Node3D).global_rotation.y, C_EIGEN, _is_tank(v), 1.0)
	for t in get_tree().get_nodes_in_group("voorraadtruck"):
		if is_instance_valid(t) and t is Node3D:
			_draw_vehicle(_radar_point(t.global_position, map), (t as Node3D).global_rotation.y, C_EIGEN, false, 0.9)
	for enemy in Game.enemies:
		if not is_instance_valid(enemy) or not enemy is Node3D or enemy.get("dead") == true:
			continue
		var vis := _enemy_vis(enemy)
		if vis <= 0.0:
			continue
		var point := _radar_point(enemy.global_position, map)
		if enemy.is_in_group("vijand_voertuig"):
			# een voertuig is een groter teken (keuze 8A uit de voertuigkeuzes): rood silhouet met een lichte rand
			_draw_vehicle(point, (enemy as Node3D).global_rotation.y, Color(C_VIJAND, 0.95 * vis), String(enemy.get_script().resource_path).ends_with("tank.gd"), 1.15, Color(1.0, 0.92, 0.8, 0.9 * vis))
		else:
			var r := 2.6 * _k
			_cv.draw_colored_polygon(PackedVector2Array([point + Vector2(0, -r), point + Vector2(r, 0), point + Vector2(0, r), point + Vector2(-r, 0)]), Color(C_VIJAND, 0.95 * vis))
		# een nieuw contact knippert anderhalve seconde met een ring
		var born: float = _first.get(enemy.get_instance_id(), -99.0)
		var since := Time.get_ticks_msec() / 1000.0 - born
		if since < 1.5 and vis >= 1.0:
			var pulse := fmod(since, 0.5) / 0.5
			_cv.draw_arc(point, (3.0 + 6.0 * pulse) * _k, 0.0, TAU, 16, Color(C_VIJAND, 1.0 - pulse), 1.2 * _k, true)
	if _seen.size() > 64:  # oude contacten opruimen
		var alive := {}
		for e in Game.enemies:
			if is_instance_valid(e):
				alive[e.get_instance_id()] = true
		for id in _seen.keys():
			if not alive.has(id):
				_seen.erase(id)
				_first.erase(id)
	# je soldaten (groen), ook als ze ver weg onzichtbaar marcheren; gekozen soldaten met een lichte ring
	var ts := TroepSelectie.inst(get_tree())
	for ally in Game.allies:
		if is_instance_valid(ally) and ally is Node3D:
			var ap := _radar_point(ally.global_position, map)
			var picked: bool = ts != null and ts.is_selected(ally)
			_cv.draw_circle(ap, (1.6 if _k < 1.5 else 2.4) * _k, C_EIGEN_HI if picked else C_EIGEN)
			if picked:
				_cv.draw_arc(ap, 4.6 * _k, 0.0, TAU, 14, C_EIGEN_HI, 1.0 * _k, true)
	# je gekozen voertuigen krijgen een lichte ring; een voertuig dat vastzit een geel waarschuwingsteken (voertuigbevel, keuze 9A)
	for b in VoertuigBestuurder.all:
		if not is_instance_valid(b) or b.dead or not is_instance_valid(b.vehicle) or not (b.vehicle as Node3D).is_visible_in_tree():
			continue
		var bp := _radar_point(b.global_position, map)
		if ts != null and ts.is_selected(b):
			_cv.draw_arc(bp, 7.5 * _k, 0.0, TAU, 16, C_EIGEN_HI, 1.2 * _k, true)
		if b.vast:
			var tw := 4.2 * _k
			var tri := PackedVector2Array([bp + Vector2(0.0, -11.0 * _k), bp + Vector2(tw, -4.0 * _k), bp + Vector2(-tw, -4.0 * _k)])
			_cv.draw_colored_polygon(tri, C_VAST)
			_cv.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color(0.1, 0.07, 0.0, 0.9), 0.8 * _k, true)
	_draw_view(map)
	var player: Node3D = Game.player
	if player != null and is_instance_valid(player):
		var center := _radar_point(player.global_position, map)
		var direction := Vector2(sin(player.face), cos(player.face)).normalized()
		var side := Vector2(direction.y, -direction.x) * 3.4 * _k
		var arrow := PackedVector2Array([center + direction * 5.6 * _k, center - direction * 3.2 * _k + side, center - direction * 1.4 * _k, center - direction * 3.2 * _k - side])
		_cv.draw_colored_polygon(arrow, C_JIJ)
		_cv.draw_polyline(PackedVector2Array([arrow[0], arrow[1], arrow[2], arrow[3], arrow[0]]), Color(0.08, 0.06, 0.02, 0.9), 0.8 * maxf(1.0, _k * 0.6), true)
	_draw_radar_attacks(map)


func _is_tank(v: Node) -> bool:
	var sc: Script = v.get_script()
	return sc != null and String(sc.resource_path).get_file() == "tank.gd"


## Een voertuig als klein silhouet in zijn rijrichting: romp, en bij een tank een loop.
func _draw_vehicle(p: Vector2, yaw: float, col: Color, tank: bool, scale := 1.0, edge := Color(0.05, 0.08, 0.04, 0.9)) -> void:
	var f := Vector2(sin(yaw), cos(yaw))   # voorkant in kaartrichting (x oost, z zuid = omlaag)
	var s := Vector2(f.y, -f.x)
	var L := 4.4 * _k * scale
	var W := 2.8 * _k * scale
	var hull := PackedVector2Array([p + f * L + s * W, p + f * L - s * W, p - f * L - s * W, p - f * L + s * W])
	_cv.draw_colored_polygon(hull, col)
	_cv.draw_polyline(PackedVector2Array([hull[0], hull[1], hull[2], hull[3], hull[0]]), edge, 0.8 * maxf(1.0, _k * 0.5), true)
	if tank:
		_cv.draw_line(p, p + f * L * 1.7, edge, 1.6 * _k * scale * 0.6, true)
		_cv.draw_circle(p, W * 0.6, edge)


## Wat de camera nu in beeld heeft, als stippelkader op de kaart (keuze 1A).
func _draw_view(map: Rect2) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or Game.build_mode:
		return
	var vs := get_viewport().get_visible_rect().size
	var pts := PackedVector2Array()
	for c in [Vector2.ZERO, Vector2(vs.x, 0.0), vs, Vector2(0.0, vs.y)]:
		var o := cam.project_ray_origin(c)
		var d := cam.project_ray_normal(c)
		if d.y > -0.05:
			d.y = -0.05   # bovenrand richting de horizon: niet oneindig ver
		var t := -o.y / d.y
		var g := o + d * minf(t, 160.0)
		pts.append(_radar_point(g, map))
	pts.append(pts[0])
	_cv.draw_polyline(pts, Color(0.92, 0.94, 0.86, 0.55), 1.0, true)


## Hoofdkwartier niveau 2: de radarring (bereik) met een zwaaiende lijn, zoals de draaiende schotel op het dak.
func _draw_hq_radar(map: Rect2, base: Vector2) -> void:
	var ring := PackedVector2Array()
	for i in 41:
		var a := TAU * float(i) / 40.0
		ring.append(_radar_point(Game.base_pos + Vector3(cos(a), 0.0, sin(a)) * HqPerks.RADAR_RANGE, map))
	_cv.draw_polyline(ring, Color(0.45, 0.92, 0.55, 0.32), 1.0 * _k, true)
	var sweep := fmod(Time.get_ticks_msec() / 8000.0, 1.0) * TAU   # zelfde 8 s als de Radar-loop van het model
	var tip := _radar_point(Game.base_pos + Vector3(cos(sweep), 0.0, sin(sweep)) * HqPerks.RADAR_RANGE, map)
	_cv.draw_line(base, tip, Color(0.45, 0.92, 0.55, 0.5), 1.2 * _k, true)


## Wie ziet dit punt: de speler, de basis, een toren, een soldaat of een eigen gebouw.
func _in_friendly_sight(pos: Vector3) -> bool:
	if Game.satelliet_t > 0.0:
		return true   # kracht SATELLIET (Rang): alle vijanden staan op de kaart
	if Game.hq_level >= 2 and Vector2(pos.x - Game.base_pos.x, pos.z - Game.base_pos.z).length() <= HqPerks.RADAR_RANGE:
		return true   # hoofdkwartier niveau 2: de radar ziet alles binnen 85 m
	var player: Node3D = Game.player
	if player != null and is_instance_valid(player) and Vector2(pos.x - player.global_position.x, pos.z - player.global_position.z).length() <= RADAR_SIGHT:
		return true
	var edge := Data.START_CLEAR + RADAR_BASE_MARGIN
	if Game.mcv_deployed and absf(pos.x - Game.base_pos.x) <= edge and absf(pos.z - Game.base_pos.z) <= edge:
		return true
	for tower in get_tree().get_nodes_in_group("tower"):
		if is_instance_valid(tower) and tower is Node3D and Vector2(pos.x - tower.global_position.x, pos.z - tower.global_position.z).length() <= RADAR_POST_SIGHT:
			return true
	for ally in Game.allies:
		if is_instance_valid(ally) and ally is Node3D and Vector2(pos.x - ally.global_position.x, pos.z - ally.global_position.z).length() <= RADAR_POST_SIGHT:
			return true
	for building in Game.buildings:
		if building is Dictionary:
			var at: Vector3 = building.get("at", Vector3.ZERO)
			if Vector2(pos.x - at.x, pos.z - at.z).length() <= RADAR_POST_SIGHT:
				return true
	return false


## 1 = nu in zicht, tussen 0 en 1 = kort geleden gezien (vervagend), 0 = onbekend.
func _enemy_vis(enemy: Node3D) -> float:
	var now := Time.get_ticks_msec() / 1000.0
	var id := enemy.get_instance_id()
	if _in_friendly_sight(enemy.global_position):
		if not _first.has(id) or now - float(_seen.get(id, -999.0)) > 20.0:
			_first[id] = now   # nieuw (of lang weg geweest): even laten knipperen
		_seen[id] = now
		return 1.0
	var last: float = _seen.get(id, -999.0)
	return clampf(1.0 - (now - last) / RADAR_MEMORY, 0.0, 1.0)


## Tijdens de pauze en zolang er nog vijanden komen: de vaste aanvalsroutes van deze golf.
func _routes_shown() -> bool:
	if Game.routes.is_empty() or Game.build_mode or Game.editing:
		return false
	if Game.state == "prep":
		return true
	var main := get_parent().get_parent()
	return Game.state == "play" and "queue" in main and not main.queue.is_empty()


## Grote rode pijl per route: op de plek waar ze bij de basis aankomen, of aan de schermrand als die plek buiten beeld ligt.
func _draw_route_arrows() -> void:
	if not _routes_shown():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var pulse := 0.85 + 0.15 * sin(Time.get_ticks_msec() / 260.0)
	var red := Color(1.0, 0.2, 0.1, pulse)
	var safe := Rect2(Vector2(70.0, 120.0), size - Vector2(140.0, 270.0))  # buiten de banner, radar en knoppen
	var font := UI.body(700, 0)
	for id in Game.routes:
		var r: Dictionary = AanvalRoutes.LIST[id]
		var at: Vector3 = r.show
		var travel := -Vector3(at.x, 0.0, at.z).normalized()  # ze lopen van hier naar de bunker
		var behind := cam.is_position_behind(at)
		var p := cam.unproject_position(at)
		var tip: Vector2
		var dir: Vector2
		if not behind and safe.has_point(p):
			# in beeld: de pijl ligt op de grond en wijst in de looprichting
			dir = (cam.unproject_position(at + travel * 4.0) - p).normalized()
			tip = p + dir * 30.0
		else:
			var c := size * 0.5
			var v := (p - c) * (-1.0 if behind else 1.0)
			if v.length() < 1.0:
				v = Vector2.UP
			var k := minf(absf(safe.size.x * 0.5 / v.x) if absf(v.x) > 0.001 else INF, absf(safe.size.y * 0.5 / v.y) if absf(v.y) > 0.001 else INF)
			dir = v.normalized()
			tip = c + v * k  # aan de rand: de punt wijst naar buiten, naar waar ze vandaan komen
		var side := Vector2(-dir.y, dir.x)
		var base := tip - dir * 40.0
		_arrows.draw_colored_polygon(PackedVector2Array([tip, base + side * 24.0, base + dir * 10.0, base - side * 24.0]), red)
		_arrows.draw_line(base + dir * 4.0, base - dir * 22.0, red, 10.0, true)
		var label: String = r.naam
		var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var lp := base - dir * 44.0 - Vector2(lw * 0.5, -5.0)
		lp.x = clampf(lp.x, 6.0, size.x - lw - 6.0)
		lp.y = clampf(lp.y, 20.0, size.y - 8.0)
		_arrows.draw_string_outline(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, Color(0, 0, 0, 0.75))
		_arrows.draw_string(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.86, 0.8, pulse))


## Op de radar: de routes als rode lijnen, met een stip waar ze beginnen.
func _draw_radar_routes(map: Rect2) -> void:
	if not _routes_shown():
		return
	var col := Color(1.0, 0.25, 0.12, 0.55 + 0.25 * sin(Time.get_ticks_msec() / 260.0))
	for id in Game.routes:
		var r: Dictionary = AanvalRoutes.LIST[id]
		var line := PackedVector2Array()
		for q in r.pts:
			line.append(_radar_point(q, map))
		line.append(_radar_point(r.show, map))
		_cv.draw_polyline(line, col, 2.0 * _k, true)
		_cv.draw_circle(line[0], 2.5 * _k, col)


## 9A: na contact een rode stippellijn van waar de groep gezien is naar waar hij heen gaat (verzamelpunt, gebouw).
func _draw_radar_contacts(map: Rect2) -> void:
	if AanvalAI.ik == null or AanvalAI.ik.contacten.is_empty():
		return
	var pulse := 0.6 + 0.3 * sin(Time.get_ticks_msec() / 220.0)
	for c in AanvalAI.ik.contacten:
		var a := _radar_point(c.van, map)
		var b := _radar_point(c.naar, map)
		var alpha := clampf(float(c.t) / 6.0, 0.0, 1.0) * pulse
		var col := Color(1.0, 0.3, 0.15, alpha)
		_cv.draw_dashed_line(a, b, col, 2.0 * _k, 4.0 * _k, true)
		var d := (b - a).normalized() if (b - a).length() > 0.5 else Vector2.DOWN
		var s := Vector2(-d.y, d.x)
		_cv.draw_colored_polygon(PackedVector2Array([b, b - d * 6.0 * _k + s * 3.5 * _k, b - d * 6.0 * _k - s * 3.5 * _k]), col)
		_cv.draw_circle(a, 2.6 * _k, col)


func _draw_radar_attacks(map: Rect2) -> void:
	_draw_radar_routes(map)
	_draw_radar_contacts(map)
	var cx := map.position.x + map.size.x * 0.5
	var cy := map.position.y + map.size.y * 0.5
	var pulse := 0.65 + 0.35 * sin(Time.get_ticks_msec() / 180.0)
	var kk := _k
	var arrows := {
		"N": [Vector2(cx, map.position.y + 2 * kk), Vector2(cx - 5 * kk, map.position.y + 9 * kk), Vector2(cx + 5 * kk, map.position.y + 9 * kk)],
		"Z": [Vector2(cx, map.end.y - 2 * kk), Vector2(cx - 5 * kk, map.end.y - 9 * kk), Vector2(cx + 5 * kk, map.end.y - 9 * kk)],
		"W": [Vector2(map.position.x + 2 * kk, cy), Vector2(map.position.x + 9 * kk, cy - 5 * kk), Vector2(map.position.x + 9 * kk, cy + 5 * kk)],
		"O": [Vector2(map.end.x - 2 * kk, cy), Vector2(map.end.x - 9 * kk, cy - 5 * kk), Vector2(map.end.x - 9 * kk, cy + 5 * kk)],
	}
	for direction in arrows:
		if Game.attack.get(direction, 0.0) > 0.0:
			_cv.draw_colored_polygon(PackedVector2Array(arrows[direction]), Color(1.0, 0.25, 0.12, pulse))


func _set_paused(on: bool) -> void:
	_menu.set_paused(on)


func _radar_size() -> Vector2:
	if size.x < size.y:
		return Vector2(88, 100)  # staand: smal, anders overlapt hij de knoppen onder de golf-titel
	if size.y < 420.0:
		return Vector2(104, 112)  # klein liggend scherm: blijft boven de wisselknop
	return Vector2(120, 128)


func _layout() -> void:
	var safe := UI.safe_margins(size)
	_radar.custom_minimum_size = _radar_size()
	_radar.size = _radar.custom_minimum_size
	_status_panel.position = Vector2(safe.x, safe.y)
	_status_panel.size = Vector2(minf(size.x * 0.42, 190.0), 48.0)
	_top_right.reset_size()
	_camera_controls.position = Vector2(safe.x, safe.y + _status_panel.size.y + 7.0)
	# rang (sterren en balk): liggend rechts naast de balken, staand eronder (daar staan de TACTISCH-knoppen niet)
	if size.x < size.y:
		_rang.position = Vector2(safe.x + 2.0, safe.y + _status_panel.size.y + 5.0)
	else:
		_rang.position = Vector2(safe.x + _status_panel.size.x + 8.0, safe.y + 8.0)
	_radar.position = Vector2(size.x - safe.z - _radar.size.x, safe.y + 8.0)
	_menu_button.position = Vector2(_radar.size.x - 38.0, 4.0)
	if size.x < size.y:
		# staand: rechts, onder de radar (x volgt in _process uit de breedte van de tekst)
		_top_right.position = Vector2(safe.x, _radar.position.y + _radar.size.y + 4.0)
	else:
		_top_right.position = Vector2(size.x - safe.z - _radar.size.x - _top_right.size.x, safe.y + 4.0)
	# onder de TACTISCH-knoppen (liggend) of onder de punten (staand), zodat hij niets afdekt
	var below := _top_right.position.y + _top_right.size.y if size.x < size.y else _camera_controls.position.y + 34.0
	_fps.position = Vector2(safe.x + 4.0, below + 6.0)
	_arrows.queue_redraw()


func _vignette_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float amount = 0.0;
void fragment() {
	float d = length(UV - vec2(0.5)) / 0.7071;
	COLOR = vec4(0.59, 0.0, 0.0, smoothstep(0.45, 1.0, d) * 0.85 * amount);
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _process(delta: float) -> void:
	visible = Game.state != "menu"
	_bars.visible = not Game.editing
	_status_panel.visible = not Game.editing
	_top_right.visible = not Game.editing
	_weapon.visible = not Game.editing
	var active_hud := Game.state == "play" or Game.state == "prep"
	_camera_controls.visible = active_hud and not Game.build_mode and size.x >= size.y
	_radar.visible = active_hud
	if active_hud and not Game.editing:
		# de eerste foto zodra de wereld staat, en opnieuw als het hoofdkwartier is uitgeklapt
		if KaartFoto.tex == null and not _foto.busy() and KaartFoto.age() > 999.0:
			_foto.request(20)
			KaartFoto.made_at = Time.get_ticks_msec() / 1000.0 - 990.0   # niet elk beeld opnieuw vragen als het mislukt
		elif Game.mcv_deployed != _foto_hq and not _foto.busy():
			_foto_hq = Game.mcv_deployed
			_foto.request(45)
	if active_hud:
		_update_camera_controls()
		_radar_refresh -= delta
		if _radar_refresh <= 0.0:
			_radar_refresh = 0.05 if _attack_pending() else 0.12   # tijdens een Aanvallen-keuze knippert het rode vlakje vloeiend
			_radar.queue_redraw()
	# alleen de instelling telt; vroeger ook StadEditor.debug_enabled (F3), en die kun je op de iPhone niet aanzetten
	_fps.visible = GameSettings.get_value("fps") == "on" and not Game.editing
	if _fps.visible:
		_fps.text = "%d FPS · %d%%%s%s · %s" % [Engine.get_frames_per_second(), roundi(get_viewport().scaling_3d_scale * 100.0), (" · T%d" % Atmosphere.tier) if Atmosphere.tier > 0 else "", Upscaling.overlay_tag(), HUD_SCRIPT.VERSION]
	var main := get_parent().get_parent()
	var left: int = Game.enemies.size() + (main.queue.size() if "queue" in main else 0)
	# tijdens een groep: aantal vijanden en het aftellen naar de volgende groep (de plaat boven in beeld is dan weg)
	_enemies.text = "–" if Game.state != "play" else "%d · %s" % [left, AanvalRoutes.klok(Game.prep_t)]
	_points.text = "%s pt" % UI.nl(Game.points)
	_score.text = "★ %s" % UI.nl(Game.score)
	_base_bar.value = Game.base_hp / Game.base_max
	var p = Game.player
	var vf := VoertuigSchade.bestuurd_fractie()   # zit je in je jeep of tank, dan toont de balk het voertuig (V3)
	if p:
		_hp_bar.value = vf if vf >= 0.0 else p.hp / Game.max_hp()
		_hp_bar.tooltip_text = ("%s" % VoertuigSchade.bestuurd_naam()) if vf >= 0.0 else "Spelergezondheid"
		if (vf >= 0.0) != _veh_fill:
			_veh_fill = vf >= 0.0
			_hp_bar.add_theme_stylebox_override("fill", UI.box(Color8(112, 176, 84) if _veh_fill else UI.BLOOD_HI, Color(0, 0, 0, 0), 0, 1, 0))
		if vf >= 0.0:
			if _last_vf >= 0.0 and vf < _last_vf:
				_hurt_a = 0.5
		elif _last_hp >= 0.0 and p.hp < _last_hp:
			_hurt_a = 0.5
		_last_hp = p.hp
		_last_vf = vf
		if p.weapon != _last_weapon:
			if _last_weapon != "":
				_weapon.text = Data.WEAPONS[p.weapon].name.to_upper()
				_weapon_t = 0.9
			_last_weapon = p.weapon
		var w: Dictionary = Game.wstat(p.weapon)
		if p.reload_t > 0.0:
			_ammo.text = "…"
		elif p.weapon == "m1911":
			_ammo.text = "%d+%d | 7" % [p.m1911_mag_rounds, int(p.m1911_chambered)]
		else:
			_ammo.text = "%d | %d" % [p.ammo, w.mag]
		var low: bool = p.reload_t <= 0.0 and p.ammo <= w.mag * 0.25
		_ammo.add_theme_color_override("font_color", Color8(255, 90, 58) if low else (UI.INK_DIM if p.reload_t > 0.0 else UI.BRASS))
	_top_right.reset_size()
	if size.x < size.y:
		_top_right.position.x = size.x - 12.0 - _top_right.size.x
	else:
		# liggend: links van de radar, anders staat de radar over de punten
		_top_right.position.x = size.x - UI.safe_margins(size).z - _radar.size.x - 6.0 - _top_right.size.x
	_weapon_t = maxf(0.0, _weapon_t - delta)
	_weapon.modulate.a = clampf(_weapon_t / 0.3, 0.0, 1.0)
	_hurt_a = maxf(0.0, _hurt_a - delta)
	var low_hp := 0.0
	if p and Game.state == "play":
		var f: float = vf if vf >= 0.0 else p.hp / Game.max_hp()
		if f < 0.3:
			low_hp = (0.3 - f) * 2.0 * (0.6 + 0.4 * sin(Time.get_ticks_msec() / 180.0))
	(_hurt.material as ShaderMaterial).set_shader_parameter("amount", clampf(maxf(_hurt_a * 2.0, low_hp), 0.0, 1.0))
	for d in Game.attack:
		Game.attack[d] = maxf(0.0, Game.attack[d] - delta)
	_arrows.queue_redraw()


## Rode pijltjes aan de rand, knipperend, zoals .atk in styles.css.
func _draw_arrows() -> void:
	if Game.state != "play":
		return
	var a := 0.675 + 0.325 * cos(Time.get_ticks_msec() / 400.0 * PI)
	var w := size.x
	var h := size.y
	var shapes := {
		"N": PackedVector2Array([Vector2(w / 2.0, 50), Vector2(w / 2.0 + 15, 72), Vector2(w / 2.0 - 15, 72)]),
		"Z": PackedVector2Array([Vector2(w / 2.0, h - 8), Vector2(w / 2.0 + 15, h - 30), Vector2(w / 2.0 - 15, h - 30)]),
		"W": PackedVector2Array([Vector2(2, h / 2.0), Vector2(24, h / 2.0 - 15), Vector2(24, h / 2.0 + 15)]),
		"O": PackedVector2Array([Vector2(w - 2, h / 2.0), Vector2(w - 24, h / 2.0 - 15), Vector2(w - 24, h / 2.0 + 15)]),
	}
	for d in shapes:
		if Game.attack[d] > 0.0:
			_arrows.draw_colored_polygon(shapes[d], Color(1.0, 0.23, 0.12, a))
