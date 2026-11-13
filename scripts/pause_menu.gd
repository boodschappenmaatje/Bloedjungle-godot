class_name PauseMenu
extends CanvasLayer

class MenuIcon extends Control:
	var icon_name := "play"
	var tint := Color("d6ad4f")

	func _draw() -> void:
		var c := size * 0.5
		match icon_name:
			"play":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-5, -8), c + Vector2(8, 0), c + Vector2(-5, 8)]), tint)
			"gear":
				for i in range(8):
					var a := TAU * float(i) / 8.0
					var d := Vector2(cos(a), sin(a))
					draw_line(c + d * 6.0, c + d * 11.0, tint, 3.0, true)
				draw_circle(c, 6.0, tint, false, 2.0, true)
				draw_circle(c, 2.0, tint, true)
			"city":
				draw_rect(Rect2(c + Vector2(-10, -4), Vector2(8, 14)), tint, false, 2.0, true)
				draw_rect(Rect2(c + Vector2(1, -10), Vector2(9, 20)), tint, false, 2.0, true)
				for p in [Vector2(-7, 0), Vector2(-2, 0), Vector2(4, -6), Vector2(8, -6), Vector2(4, 0), Vector2(8, 0)]:
					draw_rect(Rect2(c + p, Vector2(2, 2)), tint, true)
			"updates":
				draw_arc(c, 8.0, -2.3, 1.2, 20, tint, 2.0, true)
				draw_colored_polygon(PackedVector2Array([c + Vector2(8, -7), c + Vector2(10, -1), c + Vector2(4, -3)]), tint)
			"target":
				draw_circle(c, 8.0, tint, false, 2.0, true)
				draw_circle(c, 2.0, tint, true)
				draw_line(c + Vector2(-13, 0), c + Vector2(-7, 0), tint, 2.0, true)
				draw_line(c + Vector2(7, 0), c + Vector2(13, 0), tint, 2.0, true)
				draw_line(c + Vector2(0, -13), c + Vector2(0, -7), tint, 2.0, true)
				draw_line(c + Vector2(0, 7), c + Vector2(0, 13), tint, 2.0, true)
			"meld":
				draw_polyline(PackedVector2Array([c + Vector2(0, -11), c + Vector2(11, 9), c + Vector2(-11, 9), c + Vector2(0, -11)]), tint, 2.0, true)
				draw_line(c + Vector2(0, -4), c + Vector2(0, 3), tint, 2.5, true)
				draw_circle(c + Vector2(0, 6.5), 1.5, tint, true)


## Alle schermen van de web-versie die over het spel heen komen: hoofdmenu, pauze, instellingen,
## uitrusting, wapenwiel en "missie mislukt". Staat in een eigen laag boven de rest van de HUD.

const ROWS := [
	["soldaat", "Mannetjes (na nieuw spel)", [["vq2", "Realistisch"], ["meshy", "Meshy-speler"], ["v1", "Oud model"]]],
	["enemy_models", "Vijandmodellen", [["all", "Alle types"], ["meshy", "Alleen Meshy"]]],
	["ai_niveau", "Vijand slimheid", [["makkelijk", "Makkelijk"], ["normaal", "Normaal"], ["moeilijk", "Moeilijk"]]],
	["m1911_fire_mode", "M1911 schieten", [["assist", "Rustig (0,5 s)"], ["manual", "Handmatig"]]],
	["vliegtuig_hoogte", "Vliegtuighoogte (rechterstick)", [["normaal", "Omlaag = stijgen"], ["omgekeerd", "Omhoog = stijgen"]]],
	["ragdoll", "Doodsval vijanden", [["on", "Ragdoll"], ["off", "Animatie"]]],
	["markeringen", "Markeringen soldaten", [["on", "Aan"], ["tact", "Tactisch"], ["off", "Uit"]]],
	["sound", "Geluid", [["on", "Aan"], ["off", "Uit"]]],
	["g2", "Graphics 2.0", [["on", "Aan"], ["off", "Klassiek"]]],
	["wapenfx", "Wapeneffecten (shotgun, pistool)", [["nieuw", "Nieuw"], ["klassiek", "Klassiek"]]],
	["wapen_haptiek", "Trilling bij schieten", [["on", "Aan"], ["off", "Uit"]]],
	["quality", "Grafiek", [["low", "Laag"], ["high", "Hoog"], ["ultra", "Ultra"]]],
	["upscaling", "Upscaling (MetalFX)", [["off", "Uit"], ["quality", "Kwaliteit"], ["balanced", "Balans"], ["performance", "Prestatie"]]],
	["time", "Tijd", [["day", "Dag"], ["dusk", "Avond"], ["night", "Nacht"]]],
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
	["g2_fx", "Test: Graphics 2.0 effecten", [["on", "Aan"], ["off", "Uit"]]],
	["g2_licht", "Test: Graphics 2.0 belichting", [["on", "Aan"], ["off", "Uit"]]],
	["g2_diepte", "Test: Graphics 2.0 diepte", [["on", "Aan"], ["off", "Uit"]]],
	["t_res", "Test: 3D-beeld klein (30%)", [["auto", "Uit"], ["small", "Aan"]]],
	["perf", "Prestatiemodus", [["off", "Uit"], ["on", "Aan"]]],
	["t_krachten", "Test: alle krachten op niveau 3, geen afkoeling", [["off", "Uit"], ["on", "Aan"]]],
	["diag", "Diagnose-run (30 s, start zelf in het spel)", [["off", "Uit"], ["on", "Aan"]]],
]
## Instellingen in tabbladen (keuze 2A): links/rechts zijn de twee kolommen in liggend; staand komen ze onder elkaar.
## "#..." is een blok tekst of de camerahoek in plaats van een keuzeregel.
const SETTINGS_TABS := [
	{"title": "BEELD", "left": ["quality", "upscaling", "hz", "perf"], "right": ["fps", "treeshadow", "buildshadow", "g2", "wapenfx"], "note": true},
	{"title": "WERELD", "left": ["time", "weather"], "right": ["wind"]},
	{"title": "SOLDATEN", "left": ["soldaat", "enemy_models", "ai_niveau"], "right": ["ragdoll", "markeringen", "#meshy"]},
	{"title": "GELUID & BESTURING", "left": ["sound", "m1911_fire_mode", "vliegtuig_hoogte", "#m1911"], "right": ["#camera", "wapen_haptiek"]},
	{"title": "TEST", "left": ["t_sun", "t_jungle", "t_stad", "t_post", "t_res"], "right": ["g2_fx", "g2_licht", "g2_diepte", "t_krachten", "diag"]},
]
const TEXTS := {
	"#meshy": "Alleen Meshy gebruikt de nieuwe Assault-soldaten met M1 Garand. Omschakelen verwijdert oude vijandtypes; de groepsgrootte blijft gelijk.",
	"#m1911": "Colt M1911: beweeg de rechterstick licht om te richten; de buitenste ring vuurt. Rustig vuurt maximaal iedere 0,5 seconde. Handmatig vraagt voor elk schot een nieuwe beweging naar de schietring.",
}
const LABEL_W := 132.0  # breedte van de naamkolom in liggend; past het langste woord (PRESTATIEMODUS, SCHERPTEDIEPTE)

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
var _menu_background: TextureRect
var _menu_tint: ColorRect
var _drag_sc: ScrollContainer
var _drag_id := -2
var _drag_acc := 0.0
var _drag_end := -1000
var _sheets := {}  # naam -> Control
var _pcs := {}  # naam -> het paneel zelf
var _cur := ""
var _return := "pause"
var _mute_btn: Button
var _menu_shade: TextureRect
var _menu_outer: MarginContainer
var _menu_layout: BoxContainer
var _menu_left: VBoxContainer
var _menu_right: VBoxContainer
var _centers := {}  # naam -> CenterContainer (binnen de veilige marges)
var _orient := []  # BoxContainers die staand onder elkaar gaan
var _name_boxes := []  # naamkolommen van de keuzeregels
var _grids := []  # [GridContainer, kolommen liggend, kolommen staand]
var _tab_buttons := []
var _tab_pages := []
var _tab := 0
var _settings_scroll: ScrollContainer
var _note: Label
var _segs := {}
var _camera_pitch_slider: HSlider
var _camera_pitch_label: Label
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
var over_delay_win := 3.4  # na het slopen van het vijandelijke hoofdkwartier: tijd voor de instorting
var _over_title: Label
var _meld_intro: Label
var _meld_tekst: LineEdit
var _meld_status: Label
var _meld_knop: Button
var _meld_vorige := false
var _meld_terug := "menu"
var _meld_aangeboden := false


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
	_menu_background = TextureRect.new()
	_menu_background.texture = load("res://assets/ui/main_menu_bunker.jpg") as Texture2D
	_menu_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_menu_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_menu_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_background.visible = false
	_root.add_child(_menu_background)
	_menu_tint = ColorRect.new()
	_menu_tint.color = Color(0.025, 0.035, 0.025, 0.23)
	_menu_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_tint.visible = false
	_root.add_child(_menu_tint)
	# keuze 5A: links donker naar rechts doorzichtig, zodat het uitzicht zichtbaar blijft
	_menu_shade = TextureRect.new()
	_menu_shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_menu_shade.stretch_mode = TextureRect.STRETCH_SCALE
	_menu_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_shade.visible = false
	_root.add_child(_menu_shade)
	_root.hide()
	_build_menu()
	_build_test()
	_build_pause()
	_build_settings()
	# een nieuwe update meldt zich vanzelf, maar alleen in het hoofdmenu (nooit midden in het spel); de speler bevestigt zelf
	Updater.update_beschikbaar.connect(func(_m): if Game.state == "menu": UpdatePanel.open(self))
	_build_gear()
	_build_wheel()
	_build_over()
	_build_melden()
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
	pc.add_theme_stylebox_override("panel", UI.sheet_box())
	center.add_child(pc)
	_sheets[name] = center
	_centers[name] = center
	_pcs[name] = pc
	return pc


## Een blad met vaste kop (titel + knop rechtsboven, keuze 6A) en daaronder inhoud die alleen bij een heel klein
## scherm met de vinger verschuift; een scrollbalk wordt nooit getoond.
func _sheet(pc: PanelContainer, title: String, close_text := "", close_cb := Callable()) -> VBoxContainer:
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	pc.add_child(outer)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.visible = title != "" or close_text != ""
	outer.add_child(head)
	var t := UI.label(title, UI.display(1), 28, UI.INK)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(t)
	if close_text != "":
		var b := _button(close_text, "field_primary", close_cb)
		b.custom_minimum_size = Vector2(112, 42)
		b.add_theme_font_size_override("font_size", 17)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(b)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	outer.add_child(sc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	return v


func _scroll_of(pc: Control) -> ScrollContainer:
	var found := pc.find_children("*", "ScrollContainer", true, false)
	return found[0] as ScrollContainer if not found.is_empty() else null


func _portrait() -> bool:
	var vp := get_viewport().get_visible_rect().size
	return vp.y > vp.x


## Liggend of staand: kolommen naast of onder elkaar, naam naast of boven de keuzebalk, rasters met meer of minder kolommen.
func _relayout(portrait: bool, vp: Vector2) -> void:
	for b in _orient:
		(b as BoxContainer).vertical = portrait
	for nb in _name_boxes:
		(nb as Control).custom_minimum_size.x = 0.0 if portrait else LABEL_W
		(nb as Control).size_flags_vertical = Control.SIZE_FILL if portrait else Control.SIZE_SHRINK_CENTER
		((nb as Control).get_parent() as Control).add_theme_constant_override("separation", 2 if portrait else 10)
	for g in _grids:
		(g[0] as GridContainer).columns = g[2] if portrait else g[1]
	for b in _tab_buttons:
		(b as Button).add_theme_font_size_override("font_size", 12 if portrait else 15)
	var safe := UI.safe_margins(vp, 10.0)
	for n in _centers:
		var c: Control = _centers[n]
		c.offset_left = safe.x
		c.offset_top = safe.y
		c.offset_right = -safe.z
		c.offset_bottom = -safe.w
	_layout_menu(portrait, vp)


func _fit_sheets() -> void:
	var vp := get_viewport().get_visible_rect().size
	var portrait := vp.y > vp.x
	_relayout(portrait, vp)
	var safe := UI.safe_margins(vp, 10.0)
	var avail := Vector2(vp.x - safe.x - safe.z, vp.y - safe.y - safe.w)
	for name in _pcs:
		var pc: PanelContainer = _pcs[name]
		pc.custom_minimum_size.x = minf(pc.get_meta("w"), avail.x)
		var sc := _scroll_of(pc)
		if sc == null:
			continue
		var other := pc.get_combined_minimum_size().y - sc.get_combined_minimum_size().y
		var want: float = (sc.get_child(0) as Control).get_combined_minimum_size().y
		if name == "settings":
			# vaste hoogte, zodat het blad niet verspringt bij een ander tabblad
			want = 99999.0 if portrait else maxf(want, 360.0)
		sc.custom_minimum_size.y = maxf(60.0, minf(want, avail.y - other))


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
		# Een veeg over de hoekschuifregelaar moet de slider, niet het menu, bedienen.
		if _camera_pitch_slider != null and _camera_pitch_slider.is_visible_in_tree() and _camera_pitch_slider.get_global_rect().has_point(pos):
			_drag_id = -2
			return
		for name in _pcs:
			var pc: PanelContainer = _pcs[name]
			if not pc.is_visible_in_tree():
				continue
			for c in pc.find_children("*", "ScrollContainer", true, false):
				if (c as Control).is_visible_in_tree() and (c as Control).get_global_rect().has_point(pos):
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


func _wrap(t: String, size := 14, color := UI.INK_DIM, w := 0.0) -> Label:
	var l := UI.label(t, UI.body(500, 0), size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = w if w > 0.0 else 100.0
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _show(name: String) -> void:
	_cur = name
	_root.visible = name != ""
	# in het hoofdmenu en de schermen die je van daaruit opent: de foto van de commandopost
	var command_screen := name == "menu" or (name in ["settings", "gear", "test", "melden"] and Game.state == "menu")
	_menu_background.visible = command_screen
	_menu_tint.visible = command_screen
	_menu_shade.visible = name == "menu"
	_root.color.a = 0.0 if command_screen else 0.6
	for n in _sheets:
		_sheets[n].visible = n == name
	if name != "":
		_fit_sheets()
		await get_tree().process_frame  # na de regelafbreking pas kent een blad zijn echte hoogte
		_fit_sheets()


# ---------------------------------------------------------------- hoofdmenu

func _menu_action_button(icon_name: String, label_text: String, kind: String, cb: Callable, font_size := 21) -> Button:
	var style_kind := "field_primary" if kind == "gold" else "field"
	var b := _button("", style_kind, cb)
	b.custom_minimum_size = Vector2(0, 52 if kind != "gold" else 62)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -12
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10 if kind != "gold" else 14)
	var icon := MenuIcon.new()
	icon.icon_name = icon_name
	icon.tint = UI.INK if kind == "gold" else UI.BRASS
	icon.custom_minimum_size = Vector2(30, 30) if kind != "gold" else Vector2(36, 36)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var divider := ColorRect.new()
	divider.color = Color(UI.BRASS, 0.72)
	divider.custom_minimum_size = Vector2(2, 28)
	divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(divider)
	var label := UI.label(label_text, UI.display(0), font_size, UI.INK)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	b.add_child(row)
	return b


## Kleinere tegel met pictogram boven de naam (Stadseditor, Updates, Testgroep).
func _menu_tile(icon_name: String, label_text: String, cb: Callable) -> Button:
	var b := _button("", "field", cb)
	b.custom_minimum_size = Vector2(0, 64)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := MenuIcon.new()
	icon.icon_name = icon_name
	icon.tint = UI.BRASS
	icon.custom_minimum_size = Vector2(28, 26)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(icon)
	var label := UI.label(label_text, UI.display(0), 13, UI.INK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(label)
	b.add_child(col)
	return b


## Hoofdmenu (keuze 1B): SPELEN groot, Uitrusting en Instellingen naast elkaar, drie tegels eronder. Geen scrollvak:
## alles past liggend en staand op een iPhone.
func _build_menu() -> void:
	_menu_outer = MarginContainer.new()
	_menu_outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_menu_outer)
	_sheets["menu"] = _menu_outer

	_menu_layout = BoxContainer.new()
	_menu_layout.add_theme_constant_override("separation", 20)
	_menu_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_outer.add_child(_menu_layout)

	_menu_left = VBoxContainer.new()
	_menu_left.add_theme_constant_override("separation", 10)
	_menu_left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_menu_layout.add_child(_menu_left)
	_menu_left.add_child(_eyebrow("COMMANDOPOST  ·  OPERATIE GROENE HEL  ·  1944"))
	_menu_left.add_child(UI.label("BLOEDJUNGLE", UI.display(2), 44, UI.INK))
	_menu_left.add_child(UI.label("OPERATIE GROENE HEL", UI.body(700, 4), 16, UI.BRASS))
	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	_menu_left.add_child(gap)
	_menu_left.add_child(_menu_action_button("play", "SPELEN", "gold", _start_game))
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 10)
	_menu_left.add_child(pair)
	pair.add_child(_menu_action_button("gear", "UITRUSTING", "secondary", func(): _open_gear("menu"), 16))
	pair.add_child(_menu_action_button("gear", "INSTELLINGEN", "secondary", func(): _open_settings("menu"), 16))
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 10)
	_menu_left.add_child(tiles)
	tiles.add_child(_menu_tile("city", "STADSEDITOR", _open_stad_editor))
	tiles.add_child(_menu_tile("updates", "UPDATES", func(): UpdatePanel.open(self)))
	tiles.add_child(_menu_tile("target", "TESTGROEP", func(): _show("test")))
	tiles.add_child(_menu_tile("target", "M-47", func(): get_tree().change_scene_to_file("res://scenes/m47_proefveld.tscn")))
	tiles.add_child(_menu_tile("meld", "MELDEN", func(): open_melden("menu")))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_layout.add_child(spacer)

	_menu_right = VBoxContainer.new()
	_menu_right.size_flags_vertical = Control.SIZE_SHRINK_END
	_menu_right.add_theme_constant_override("separation", 6)
	_menu_layout.add_child(_menu_right)
	_menu_right.add_child(_eyebrow("BESTE SOLDATEN"))
	_scores_box = VBoxContainer.new()
	_scores_box.add_theme_constant_override("separation", 4)
	_menu_right.add_child(_scores_box)


func _layout_menu(portrait: bool, vp: Vector2) -> void:
	var safe := UI.safe_margins(vp, 22.0)
	_menu_outer.add_theme_constant_override("margin_left", roundi(safe.x + 8.0))
	_menu_outer.add_theme_constant_override("margin_top", roundi(safe.y + 8.0))
	_menu_outer.add_theme_constant_override("margin_right", roundi(safe.z + 8.0))
	_menu_outer.add_theme_constant_override("margin_bottom", roundi(safe.w + 8.0))
	var inner_w := vp.x - safe.x - safe.z - 16.0
	_menu_layout.vertical = portrait
	_menu_left.custom_minimum_size.x = inner_w if portrait else minf(470.0, inner_w * 0.56)
	_menu_right.custom_minimum_size.x = inner_w if portrait else minf(320.0, inner_w * 0.3)
	_menu_left.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if portrait else Control.SIZE_SHRINK_CENTER
	var g := Gradient.new()
	var dark := Color(0.035, 0.045, 0.025)
	if portrait:
		# staand staat alles over de hele breedte: van boven donker naar onder iets lichter
		g.set_color(0, Color(dark, 0.86))
		g.set_color(1, Color(dark, 0.6))
	else:
		g.set_color(0, Color(dark, 0.9))
		g.set_color(1, Color(dark, 0.0))
		g.add_point(0.5, Color(dark, 0.74))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 256
	tex.height = 256
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1) if portrait else Vector2(0.78, 0)
	_menu_shade.texture = tex


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
	var heads := ["#", "NAAM", "GROEP", "SCORE"]
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
	# liep het spel de vorige keer vast of waren er fouten: één keer aanbieden om dat te melden (nooit vanzelf versturen)
	if not _meld_aangeboden and Logboek.inst != null and Logboek.inst.vorige_uitleg() != "" and DisplayServer.get_name() != "headless":
		_meld_aangeboden = true
		open_melden("menu", true)


# ---------------------------------------------------------------- meld probleem (foutenlogboek op afstand)

func _build_melden() -> void:
	var v := _sheet(_centered("melden", 620), "MELD PROBLEEM")
	_meld_intro = _wrap("", 15, UI.INK, 300.0)
	v.add_child(_meld_intro)
	v.add_child(_wrap("Mee gaan: versie, toestel, fps, foutmeldingen, je laatste acties en je positie van de laatste 5 minuten. Geen naam of andere persoonlijke gegevens. Er gaat alleen iets weg als je op VERSTUUR tikt.", 13, UI.INK_DIM, 300.0))
	_meld_tekst = LineEdit.new()
	_meld_tekst.max_length = 300
	_meld_tekst.placeholder_text = "Wat ging er mis? (mag leeg blijven)"
	_meld_tekst.custom_minimum_size.y = 44
	_meld_tekst.add_theme_font_override("font", UI.body(600, 0))
	_meld_tekst.add_theme_font_size_override("font_size", 17)
	_meld_tekst.add_theme_color_override("font_color", UI.INK)
	_meld_tekst.add_theme_stylebox_override("normal", UI.box(Color(0, 0, 0, 0.35), UI.PANEL_LINE, 1, 4, 10))
	_meld_tekst.add_theme_stylebox_override("focus", UI.box(Color(0, 0, 0, 0.35), UI.BRASS, 1, 4, 10))
	v.add_child(_meld_tekst)
	_meld_status = _wrap("", 14, UI.BRASS, 300.0)
	v.add_child(_meld_status)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	_meld_knop = _button("VERSTUUR", "primary", _melden_versturen)
	_meld_knop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_meld_knop)
	var terug := _button("TERUG", "secondary", _melden_sluiten)
	terug.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(terug)


## Opent het meldscherm vanuit het hoofdmenu of de pauze. van_vorige: het gaat om de vorige (vastgelopen) sessie.
func open_melden(from: String, van_vorige := false) -> void:
	_meld_terug = from
	_meld_vorige = van_vorige
	_meld_tekst.text = ""
	_meld_status.text = ""
	_meld_knop.disabled = false
	var boek := Logboek.inst
	if boek == null:
		_meld_intro.text = "Het logboek draait niet; er valt niets te melden."
		_meld_knop.disabled = true
	elif van_vorige:
		_meld_intro.text = boek.vorige_uitleg() + " Wil je dat aan Claude melden? Dan kan het worden uitgezocht."
	else:
		_meld_intro.text = "Stuur wat er net gebeurde naar Claude, zodat het kan worden uitgezocht."
		var n := boek.wachtrij_aantal()
		if n > 0:
			_meld_status.text = "%d eerdere melding(en) wachten nog op verbinding." % n
	_show("melden")


func _melden_versturen() -> void:
	var boek := Logboek.inst
	if boek == null or boek.bezig:
		return
	_meld_knop.disabled = true
	_meld_status.text = "Versturen..."
	if not boek.verstuurd.is_connected(_melden_klaar):
		boek.verstuurd.connect(_melden_klaar)
	boek.meld(_meld_tekst.text.strip_edges(), _meld_vorige)
	_meld_vorige = false


func _melden_klaar(ok: bool, uitleg: String) -> void:
	if _cur != "melden":
		return
	_meld_status.text = uitleg
	_meld_status.add_theme_color_override("font_color", UI.INK if ok else UI.BRASS)
	if ok:
		_meld_tekst.text = ""


func _melden_sluiten() -> void:
	if _meld_vorige and Logboek.inst != null:
		Logboek.inst.vorige_afwijzen()   # NIET MELDEN: niet nog eens vragen
	_meld_vorige = false
	_show(_meld_terug)


func _start_game() -> void:
	Progress.test_groep = 0
	_show("")
	get_tree().current_scene.begin()


# ---------------------------------------------------------------- test: start bij groep

const TEST_GROEPEN := 12

## Wat er in aanvalsgroep n meekomt (aantal soldaten + voertuigen), voor de testknoppen en de banner.
static func groep_inhoud(n: int) -> String:
	var t := "%d soldaten" % (4 + int(n * 2.4))   # zelfde aantal als Data.build_group(n)
	var vt := Data.groep_voertuigen(n)
	if not vt.is_empty():
		t += " + " + " + ".join(vt)
	return t


func _build_test() -> void:
	var v := _sheet(_centered("test", 940), "START BIJ GROEP", "TERUG", func(): _show("menu"))
	v.add_child(_wrap("Kies een groep: het spel begint zoals altijd met de bouwwagen, maar de eerste aanvalsgroep is meteen de gekozen groep, %d s na het uitklappen (of eerder met Start nu). Een testspel telt niet mee voor je beste groep en de scorelijst." % int(Progress.TEST_RUST), 14, UI.INK_DIM))
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	v.add_child(g)
	_grids.append([g, 4, 2])
	for n in range(1, TEST_GROEPEN + 1):
		var groep: int = n
		var b := _button("Groep %d\n%s" % [n, groep_inhoud(n)], "secondary", func(): _start_test(groep))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 58)
		b.add_theme_font_size_override("font_size", 14)
		g.add_child(b)


func _start_test(n: int) -> void:
	Progress.test_groep = n
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
			Game.banner.emit("STADSEDITOR", "Alleen als er geen groep onderweg is", 2.0)
			return
		set_paused(false)
	ed.enter()


# ---------------------------------------------------------------- pauze

func _build_pause() -> void:
	var v := _sheet(_centered("pause", 460), "PAUZE")
	v.add_child(_button("VERDER", "primary", func(): set_paused(false)))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	v.add_child(g)
	_mute_btn = _button("", "secondary", _toggle_sound)
	var knoppen: Array = [_mute_btn,
		_button("Instellingen", "secondary", func(): _open_settings("pause")),
		_button("Stadseditor", "secondary", _open_stad_editor),
		_button("Updates", "secondary", func(): UpdatePanel.open(self))]
	for b in knoppen:
		(b as Button).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(b)
	v.add_child(_button("Meld probleem", "secondary", func(): open_melden("pause")))
	v.add_child(_button("Stoppen", "secondary", func():
		get_tree().paused = false
		_show("")
		Game.end_game("Missie afgebroken na groep %d" % Game.wave)))
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
	var pc := _centered("settings", 980)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	pc.add_child(outer)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	outer.add_child(head)
	var title := UI.label("INSTELLINGEN", UI.display(1), 28, UI.INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(title)
	var klaar := _button("KLAAR", "field_primary", func(): _show(_return))
	klaar.custom_minimum_size = Vector2(112, 42)
	klaar.add_theme_font_size_override("font_size", 17)
	klaar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(klaar)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 2)
	outer.add_child(tabs)
	var line := ColorRect.new()
	line.color = UI.PANEL_LINE
	line.custom_minimum_size.y = 1
	outer.add_child(line)

	_settings_scroll = ScrollContainer.new()
	_settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_settings_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	outer.add_child(_settings_scroll)
	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings_scroll.add_child(pages)

	for i in SETTINGS_TABS.size():
		var tab: Dictionary = SETTINGS_TABS[i]
		var idx := i
		var tb := _button(tab["title"], "tab", func(): _select_tab(idx))
		tb.custom_minimum_size.y = 40
		tabs.add_child(tb)
		_tab_buttons.append(tb)
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 12)
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pages.add_child(page)
		_tab_pages.append(page)
		var cols := BoxContainer.new()
		cols.add_theme_constant_override("separation", 24)
		page.add_child(cols)
		_orient.append(cols)
		for side in ["left", "right"]:
			var col := VBoxContainer.new()
			col.add_theme_constant_override("separation", 9)
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cols.add_child(col)
			for key in tab[side]:
				_add_settings_block(col, key)
		if tab.get("note", false):
			_note = _wrap("", 13, UI.INK_DIM)
			page.add_child(_note)
	_select_tab(0)
	_refresh()


func _add_settings_block(col: VBoxContainer, key: String) -> void:
	if key == "#camera":
		_build_camera_pitch_controls(col)
	elif TEXTS.has(key):
		col.add_child(_wrap(TEXTS[key], 12, UI.INK_DIM))
	else:
		var matches: Array = ROWS.filter(func(r): return r[0] == key)
		if not matches.is_empty():
			_add_setting_row(col, matches[0])


func _select_tab(i: int) -> void:
	_tab = i
	for j in _tab_pages.size():
		(_tab_pages[j] as Control).visible = j == i
		var b: Button = _tab_buttons[j]
		var sb := UI.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 0)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		if j == i:
			sb.border_color = UI.BRASS
			sb.border_width_bottom = 3
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, sb)
		for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(cn, UI.BRASS if j == i else UI.INK_DIM)
	if _settings_scroll != null:
		_settings_scroll.scroll_vertical = 0


## Naam van een regel (keuze 3A): hoofdletters, nooit midden in een woord afgebroken; wat tussen haakjes staat komt klein eronder.
## In het tabblad TEST valt het voorvoegsel "Test:" weg.
static func setting_name(text: String) -> PackedStringArray:
	var main := text
	var sub := ""
	if main.begins_with("Test: "):
		main = main.substr(6)
	var open := main.find(" (")
	if open > 0 and main.ends_with(")"):
		sub = main.substr(open + 2, main.length() - open - 3)
		main = main.substr(0, open)
	return PackedStringArray([main.to_upper(), sub])


func _add_setting_row(v: VBoxContainer, r: Array) -> void:
	var row := BoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_orient.append(row)
	var names := setting_name(r[1])
	var name_box := VBoxContainer.new()
	name_box.add_theme_constant_override("separation", 0)
	name_box.custom_minimum_size.x = LABEL_W
	name_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_box.set_meta("setting", r[0])
	_name_boxes.append(name_box)
	var l := UI.label(names[0], UI.body(700, 1), 15, UI.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_box.add_child(l)
	if names[1] != "":
		var s := UI.label(names[1], UI.body(500, 0), 12, UI.INK_DIM)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD
		name_box.add_child(s)
	row.add_child(name_box)
	# keuze 4A: één balk op een donkere ondergrond, alle vakjes even breed en even hoog
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fb := UI.box(Color(0.02, 0.025, 0.014, 0.85), UI.PANEL_LINE, 1, 4, 1)
	frame.add_theme_stylebox_override("panel", fb)
	var seg := HBoxContainer.new()
	seg.add_theme_constant_override("separation", 0)
	frame.add_child(seg)
	_segs[r[0]] = []
	for o in r[2]:
		var key: String = r[0]
		var val: String = o[0]
		var b := _button(o[1], "seg", func():
			GameSettings.set_value(key, val)
			if key == "enemy_models" and Game.state in ["prep", "play"]:
				var scene := get_tree().current_scene
				if scene != null and scene.has_method("apply_enemy_model_filter"):
					scene.call("apply_enemy_model_filter")
			if key == "sound":
				_refresh_sound()
			_apply()
			_refresh())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 42)
		b.clip_text = true  # zo worden alle vakjes precies even breed
		b.add_theme_font_size_override("font_size", 14)
		b.set_meta("v", val)
		seg.add_child(b)
		_segs[r[0]].append(b)
	row.add_child(frame)
	v.add_child(row)


## Instelbare schuine camera: 35° = meer zijkant, 75° = meer bovenaanzicht.
## De gekozen hoek wordt lokaal opgeslagen; zoom en de groepscamera blijven onafhankelijk.
func _build_camera_pitch_controls(v: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(Color(0.02, 0.03, 0.02, 0.80), UI.PANEL_LINE, 1, 7, 10))
	v.add_child(panel)
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 8)
	panel.add_child(group)
	var heading := HBoxContainer.new()
	group.add_child(heading)
	var title := UI.label("CAMERAHOEK · TESTEN", UI.body(700, 1), 14, UI.INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	_camera_pitch_label = UI.label("53°", UI.body(700, 1), 19, UI.BRASS)
	_camera_pitch_label.name = "CameraPitchValue"
	heading.add_child(_camera_pitch_label)
	_camera_pitch_slider = HSlider.new()
	_camera_pitch_slider.name = "CameraPitchSlider"
	_camera_pitch_slider.min_value = 35.0
	_camera_pitch_slider.max_value = 75.0
	_camera_pitch_slider.step = 1.0
	_camera_pitch_slider.custom_minimum_size = Vector2(180.0, 42.0)
	_camera_pitch_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_camera_pitch_slider.value_changed.connect(_on_camera_pitch_changed)
	group.add_child(_camera_pitch_slider)
	group.add_child(_wrap("35° = schuiner (meer zijkant)     75° = steiler (meer bovenaanzicht).", 12, UI.INK_DIM))
	var presets := HBoxContainer.new()
	presets.add_theme_constant_override("separation", 8)
	group.add_child(presets)
	for degrees in [40, 53, 65]:
		var preset := _button("%d°" % degrees + (" · standaard" if degrees == 53 else ""), "seg", func():
			_camera_pitch_slider.value = float(degrees))
		preset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		presets.add_child(preset)
	group.add_child(_wrap("Vergelijk de hoek in hetzelfde spel. 53° is de vorige Bloedjungle-stand; geen officieel bevestigde Dead Nation-hoek.", 12, UI.INK_DIM))
	group.add_child(_button("TEST MET DEZE CAMERAHOEK", "secondary", _preview_camera_pitch))


func _on_camera_pitch_changed(value: float) -> void:
	var degrees := clampi(roundi(value), 35, 75)
	_camera_pitch_label.text = "%d°" % degrees
	if GameSettings.get_value("camera_pitch") != str(degrees):
		GameSettings.set_value("camera_pitch", str(degrees))


func _preview_camera_pitch() -> void:
	if _return == "pause":
		set_paused(false)
	elif _return == "menu":
		_start_game()
	else:
		_show(_return)


func _open_settings(from: String) -> void:
	_return = from
	_refresh()
	_show("settings")


func _refresh() -> void:
	if _camera_pitch_slider != null:
		var pitch := clampf(float(GameSettings.get_value("camera_pitch")), 35.0, 75.0)
		_camera_pitch_slider.set_value_no_signal(pitch)
		_camera_pitch_label.text = "%d°" % roundi(pitch)
	for key in _segs:
		for b in _segs[key]:
			UI.seg_state(b, GameSettings.get_value(key) == b.get_meta("v"))
	_note.text = NOTES[GameSettings.get_value("quality")] + "\n" + NOTES[GameSettings.get_value("buildshadow") + "_b"]
	_note.text += "\n" + Upscaling.note()
	if GameSettings.get_value("hz") == "120":
		_note.text += "\n" + NOTES["120"]


func _apply() -> void:
	GameSettings.apply_hz()
	for n in get_tree().get_nodes_in_group("atmosphere"):
		n.apply_settings()


# ---------------------------------------------------------------- uitrusting

func _build_gear() -> void:
	var v := _sheet(_centered("gear", 960), "UITRUSTING", "KLAAR", func(): _show(_return))
	_gear_stats = _wrap("", 13)
	v.add_child(_gear_stats)
	_gear_body = VBoxContainer.new()
	_gear_body.add_theme_constant_override("separation", 10)
	v.add_child(_gear_body)
	v.add_child(_wrap("Vergrendelde onderdelen speel je vrij met mijlpalen. Je voortgang blijft bewaard tussen missies.", 13))


func _open_gear(from: String) -> void:
	_return = from
	_render_gear()
	_show("gear")


func _render_gear() -> void:
	for c in _gear_body.get_children():
		c.queue_free()
	var st := Progress.stats
	_gear_stats.text = "Beste groep %d · %d vijanden gedood · %d missies gespeeld" % [st.bestWave, st.kills, st.games]
	for slot in Progress.GEAR:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		box.add_child(UI.label(Progress.TITLES[slot].to_upper(), UI.body(700, 2), 12, UI.INK_DIM))
		var grid := GridContainer.new()
		grid.columns = 3 if _portrait() else 6
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
	b.custom_minimum_size = Vector2(0, 70)
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
	var top := _sheet(_centered("over", 900), "")
	var cols := BoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	top.add_child(cols)
	_orient.append(cols)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(v)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	_over_reason = _eyebrow("Je bent gesneuveld")
	v.add_child(_over_reason)
	_over_title = UI.label("MISSIE MISLUKT", UI.display(1), 34, UI.INK)
	v.add_child(_over_title)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 22)
	for k in [["score", "Score"], ["wave", "Groepen"], ["kills", "Doden"]]:
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
	right.add_child(_eyebrow("BESTE SOLDATEN"))
	_over_scores = VBoxContainer.new()
	right.add_child(_over_scores)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var again := _button("OPNIEUW", "primary", func():
		Progress.autostart = true
		get_tree().paused = false
		get_tree().reload_current_scene())
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(again)
	var naar_menu := _button("MENU", "secondary", func():
		Progress.autostart = false
		Progress.test_groep = 0
		get_tree().paused = false
		get_tree().reload_current_scene())
	naar_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(naar_menu)
	v.add_child(row)


func _on_over(reason: String) -> void:
	_saved = false
	var fresh := Progress.check_unlocks()
	Progress.save()
	# gewonnen: eerst de instorting van het vijandelijke hoofdkwartier laten zien
	await get_tree().create_timer(over_delay_win if Game.won else over_delay).timeout
	_over_title.text = "MISSIE GESLAAGD" if Game.won else "MISSIE MISLUKT"
	_over_reason.text = reason.to_upper()
	_over_stats.score.text = UI.nl(Game.score)
	_over_stats.wave.text = str(Game.wave)
	_over_stats.kills.text = str(Game.kills)
	_over_name.text = Progress.player_name
	_over_save_row.visible = Game.score > 0 and Progress.test_groep == 0   # testspel: geen score bewaren
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
			"test":
				_show("menu")
			"wheel":
				_close_wheel()
			"pause":
				set_paused(false)
			"":
				set_paused(true)
