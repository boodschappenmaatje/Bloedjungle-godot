class_name StadEditor
extends Control
## Stadseditor: deel de stad achter de brug zelf in. De editor opent vergrendeld in KIJK; schakel naar BEWERK
## om iets te plaatsen of te veranderen. Schuin of recht van boven; twee vingers bewegen en zoomen de kaart.
## Twee vingers schuiven en zoomen. Alles springt op een raster; rood betekent dat het daar niet past.
## Open hem tussen de golven met "Stadseditor" in het hoofdmenu of het pauzemenu (of F8). Je indeling wordt vanzelf bewaard;
## via de titel krijg je de tekst van de indeling om te delen of in stad_data.gd op te nemen.

const FOLIAGE_GROUPS := ["foliage_palm", "foliage_bush", "foliage_fern", "foliage_grass", "foliage_rock", "treeshadow"]
const TABS := [["weg", "WEGEN"], ["gebouw", "GEBOUWEN"], ["straat", "STRAAT"], ["gum", "GUM"]]
const GOOD_COL := Color(0.3, 0.9, 0.35, 0.45)
const BAD_COL := Color(1.0, 0.25, 0.2, 0.5)
const SEL_COL := Color(1.0, 0.85, 0.3, 0.4)
const LINE_TOOLS := {"lijn": "weg_recht", "lijn_steeg": "weg_steeg"}   # wegen trek je als een lijn; het spel kiest de wegdelen
const ICON_DIR := "res://assets/stad_icons/%s.png"
const EUI = preload("res://scripts/stad_editor_ui.gd")
const Preview = preload("res://scripts/stad_editor_preview.gd")
enum LibraryState { HIDDEN, COMPACT, EXPANDED }
static var debug_enabled := false

var _stad: Stad
var _side: PanelContainer
var _side_tabs: VBoxContainer
var _look_btn: Button
var _selected_label: Label
var _fps_bar: ProgressBar
var _sloop_label: Label
var _title_btn: Button
var _undo_btn: Button
var _done_btn: Button
var _mirror_btn: Button
var _copy_btn: Button
var _delete_btn: Button
var _library_scroll: ScrollContainer
var _palette_handle: Button
var _action_grid: GridContainer
var _toast: PanelContainer
var _modal_scrim: ColorRect
var _cards := {}
var _textures := {}
var _library_drag := {}
var _library_drag_end := -1000
var _library_state := LibraryState.COMPACT
var _safe_area_override := Rect2()
var _ghost: Node3D
var _borders: Array[MeshInstance3D] = []
var _border_mat: StandardMaterial3D
var _grid: MeshInstance3D
var _grid_key := ""
var _last_toolbar_rect := Rect2()
var _last_toolbar_signature := ""
var _rot_btn: Button
var _ui: Control
var _top: PanelContainer
var _fps_label: Label
var _hint: Label
var _msg: Label
var _tab_btns := {}
var _chips: GridContainer
var _palette: PanelContainer
var _actions: PanelContainer
var _brush_btn: Button
var _zoom_box: VBoxContainer
var _view_btn: Button
var _popup: PanelContainer
var _text: TextEdit
var _reset_btn: Button
var _reset_arm := false
var _hl: MeshInstance3D
var _hl_mesh: BoxMesh
var _hl_mat: StandardMaterial3D
var _marks: Array = []

var _tool := ""             # "" = niets gekozen, een soortnaam = plaatsen, "gum" = weghalen
var _cat := "gebouw"
var _look_mode := true
var _rot := 0
var _mir := 0
var _brush := false
var _sel: Dictionary = {}
var _undo: Array = []
var _ptrs := {}
var _drag: Dictionary = {}
var _pinch: Dictionary = {}
var _touch := false
var _msg_t := 0.0
var _fps_refresh := 0.0
var _cand: Dictionary = {}
var _last_brush := Vector2(INF, INF)
var _hidden: Array = []
var _line_hl: Node3D
var _line_cells: Array = []   # cellen van de lijn die je trekt (Vector2i), op volgorde
var _line_plan: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("stad_editor")
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.visible = false
	add_child(_ui)
	_make_top()
	_make_palette()
	_make_actions()
	_make_zoom()
	_make_popup()
	_make_highlight()
	resized.connect(_layout)
	_layout()


func _exit_tree() -> void:
	# Ook als de editor nooit geopend werd, mogen de losse previewnodes niet achterblijven.
	for node in [_hl, _ghost, _grid]:
		if is_instance_valid(node) and not node.is_inside_tree():
			node.free()


# ---------------------------------------------------------------- opbouw van het scherm

func _panel(margin := 8) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", EUI.panel(margin))
	_ui.add_child(pc)
	return pc


func _btn(text: String, kind: String, cb: Callable, parent: Control, icon := "") -> Button:
	var b := Button.new()
	b.add_to_group("hud_button")
	b.text = text
	EUI.button(b, false, kind == "gold")
	b.custom_minimum_size = Vector2(0, 44)
	if icon != "":
		b.icon = EUI.icon(icon)
		b.add_theme_constant_override("icon_max_width", 17)
	b.pressed.connect(cb)
	b.pressed.connect(func(): Sfx.play("click"))
	parent.add_child(b)
	return b


func _make_top() -> void:
	_top = _panel(4)
	_top.name = "Bovenbalk"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_top.add_child(row)
	_title_btn = _btn("STADSEDITOR", "", _show_text, row)
	_title_btn.add_theme_font_override("font", UI.display(0))
	_title_btn.tooltip_text = "Stadsindeling kopiëren of de standaardstad herstellen"
	_title_btn.add_theme_stylebox_override("normal", UI.box(Color.TRANSPARENT))
	_selected_label = UI.label("Kies een object", EUI.font(), 13, EUI.GOLD)
	_selected_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_selected_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_selected_label.clip_text = true
	row.add_child(_selected_label)
	_fps_bar = ProgressBar.new()
	_fps_bar.name = "ActueleFPS"
	_fps_bar.show_percentage = false
	_fps_bar.max_value = 60.0
	_fps_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_fps_bar.add_theme_stylebox_override("background", UI.box(Color("30392d"), Color.TRANSPARENT, 0, 4, 0))
	_fps_bar.add_theme_stylebox_override("fill", UI.box(EUI.GREEN, Color.TRANSPARENT, 0, 4, 0))
	_fps_bar.custom_minimum_size = Vector2(70, 8)
	row.add_child(_fps_bar)
	_fps_label = UI.label("", EUI.font(), 13, EUI.INK)
	row.add_child(_fps_label)
	_sloop_label = UI.label("", EUI.font(500), 11, EUI.MUTED)
	_sloop_label.tooltip_text = "Maximaal %d sloopbare gebouwen tegelijk actief" % Stad.MAX_SLOOP
	row.add_child(_sloop_label)
	_undo_btn = _btn("", "", _do_undo, row, "undo")
	_undo_btn.custom_minimum_size.x = 44
	_undo_btn.tooltip_text = "Ongedaan maken · Ctrl+Z"
	_done_btn = _btn("KLAAR", "gold", exit, row)
	_done_btn.custom_minimum_size.x = 84
	_hint = UI.label("", UI.body(), 12, EUI.MUTED)
	_hint.visible = false
	_ui.add_child(_hint)
	_toast = _panel(8)
	_toast.name = "Plaatsingsmelding"
	_toast.visible = false
	_msg = UI.label("", EUI.font(), 13, Color("f1cf9a"))
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_child(_msg)


func _make_palette() -> void:
	_side = _panel(6)
	_side.name = "Categorieën"
	_side_tabs = VBoxContainer.new()
	_side_tabs.add_theme_constant_override("separation", 3)
	_side.add_child(_side_tabs)
	_look_btn = _btn("KIJK", "", _toggle_look_mode, _side_tabs, "oog")
	_look_btn.name = "VeiligeKijkmodus"
	_look_btn.custom_minimum_size = Vector2(96, 48)
	_look_btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_look_btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	_look_btn.add_theme_constant_override("icon_max_width", 18)
	_look_btn.add_theme_font_size_override("font_size", 11)
	_look_btn.tooltip_text = "Veilig rondkijken; kaartacties zijn vergrendeld"
	for t in TABS:
		var id: String = t[0]
		var b := _btn(t[1], "", func(): _pick_tab(id), _side_tabs, id)
		b.name = "Categorie_" + id
		b.custom_minimum_size = Vector2(96, 44)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width", 18)
		b.add_theme_font_size_override("font_size", 10)
		_tab_btns[id] = b
	_palette = _panel(6)
	_palette.name = "Bouwbibliotheek"
	_library_scroll = ScrollContainer.new()
	_library_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_library_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_library_scroll.scroll_deadzone = 10
	_palette.add_child(_library_scroll)
	_chips = GridContainer.new()
	_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chips.add_theme_constant_override("h_separation", 6)
	_chips.add_theme_constant_override("v_separation", 6)
	_library_scroll.add_child(_chips)
	_palette_handle = _btn("", "", _cycle_library, _ui, "grip")
	_palette_handle.name = "Bibliotheekgreep"
	_palette_handle.custom_minimum_size = Vector2(72, 44)
	_palette_handle.tooltip_text = "Bibliotheek: compact, uitgebreid of verborgen"


func _make_actions() -> void:
	_actions = _panel(4)
	_actions.name = "Objectgereedschap"
	_action_grid = GridContainer.new()
	_action_grid.columns = 1
	_action_grid.add_theme_constant_override("h_separation", 2)
	_action_grid.add_theme_constant_override("v_separation", 2)
	_actions.add_child(_action_grid)
	_rot_btn = _btn("Draai", "", _rotate, _action_grid, "draai")
	_rot_btn.tooltip_text = "Draai 90 graden · R"
	_mirror_btn = _btn("Spiegel", "", _mirror, _action_grid, "spiegel")
	_copy_btn = _btn("Kopie", "", _copy, _action_grid, "kopie")
	_delete_btn = _btn("Wis", "", _delete_sel, _action_grid, "wis")
	_brush_btn = _btn("Kwast", "", _toggle_brush, _action_grid, "kwast")
	_brush_btn.tooltip_text = "Straatobjecten of gum langs een veeg plaatsen · K"
	for b: Button in _action_grid.get_children():
		b.add_theme_font_size_override("font_size", 11)
	_actions.visible = false


func _make_zoom() -> void:
	_view_btn = _btn("SCHUIN", "", _toggle_camera, _ui, "view")
	_view_btn.name = "EditorKijkhoek"
	_view_btn.add_theme_font_size_override("font_size", 11)
	_zoom_box = VBoxContainer.new()
	_zoom_box.name = "Kaartzoom"
	_zoom_box.add_theme_constant_override("separation", 6)
	_ui.add_child(_zoom_box)
	for z in ["plus", "minus"]:
		var b := _btn("", "", func(): _zoom_by(0.8 if z == "plus" else 1.25), _zoom_box, z)
		b.custom_minimum_size = Vector2(44, 44)
		b.add_theme_constant_override("icon_max_width", 21)
		b.tooltip_text = "Inzoomen" if z == "plus" else "Uitzoomen"


func _make_popup() -> void:
	_modal_scrim = ColorRect.new()
	_modal_scrim.color = Color(0, 0, 0, 0.42)
	_modal_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_scrim.visible = false
	_ui.add_child(_modal_scrim)
	_popup = _panel(14)
	_popup.visible = false
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_popup.add_child(vb)
	vb.add_child(UI.label("Jouw stad", EUI.font(), 18, EUI.INK))
	var info := UI.label("Je stad wordt automatisch bewaard. Kopieer de tekst om de indeling te delen.", EUI.font(500), 13, EUI.MUTED)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(info)
	_text = TextEdit.new()
	_text.custom_minimum_size = Vector2(0, 120)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("font_size", 12)
	vb.add_child(_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	vb.add_child(row)
	_btn("KOPIEER", "gold", _copy_text, row).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reset_btn = _btn("STANDAARD", "", _reset_default, row)
	_reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn("SLUIT", "", _close_popup, row).size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _close_popup() -> void:
	_popup.visible = false
	_modal_scrim.visible = false


func _make_highlight() -> void:
	_marks.clear()
	_borders.clear()
	_grid_key = ""
	_hl = MeshInstance3D.new()
	_hl_mesh = BoxMesh.new()
	_hl.mesh = _hl_mesh
	_hl_mat = StandardMaterial3D.new()
	_hl_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hl_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hl_mat.no_depth_test = true
	_hl_mat.albedo_color = GOOD_COL
	_hl.material_override = _hl_mat
	_hl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hl.visible = false
	_border_mat = StandardMaterial3D.new()
	_border_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_border_mat.no_depth_test = true
	for i in 4:
		var edge := MeshInstance3D.new()
		edge.mesh = BoxMesh.new()
		edge.material_override = _border_mat
		edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_hl.add_child(edge)
		_borders.append(edge)
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.35, 0.055, 0.35)
		m.mesh = bm
		m.material_override = _border_mat
		m.visible = false
		_hl.add_child(m)
		_marks.append(m)
	_ghost = Preview.new()
	_grid = MeshInstance3D.new()
	_grid.name = "Plaatsingsraster"
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_color = Color(0.7, 0.82, 0.62, 0.16)
	_grid.material_override = gm
	_grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_grid.visible = false


func _safe_rect() -> Rect2:
	var full := Rect2(Vector2.ZERO, size)
	if _safe_area_override.has_area():
		return full.intersection(_safe_area_override)
	if OS.has_feature("mobile") or DisplayServer.is_touchscreen_available():
		var screen := Rect2(DisplayServer.get_display_safe_area())
		if screen.has_area():
			var local := get_viewport().get_screen_transform().affine_inverse() * screen
			var result := full.intersection(local)
			if result.has_area():
				return result
	return full


func _layout() -> void:
	if _top == null or _palette == null or _popup == null:
		return
	var safe := _safe_rect()
	var pad := 10.0
	var inner := safe.grow(-pad)
	_top.position = inner.position
	_top.size = Vector2(inner.size.x, 52)
	var narrow := inner.size.x < 760.0
	_title_btn.custom_minimum_size.x = 88 if narrow else 114
	_title_btn.add_theme_font_size_override("font_size", 11 if narrow else 13)
	_selected_label.custom_minimum_size.x = 40 if narrow else 74
	_selected_label.add_theme_font_size_override("font_size", 12 if narrow else 13)
	_fps_bar.custom_minimum_size.x = 32 if narrow else 64
	_fps_label.add_theme_font_size_override("font_size", 11 if narrow else 13)
	_sloop_label.add_theme_font_size_override("font_size", 10 if narrow else 11)
	_done_btn.custom_minimum_size.x = 68 if narrow else 84
	_side.position = Vector2(inner.position.x, _top.position.y + 64)
	_side.size = Vector2(108, _side_tabs.get_combined_minimum_size().y + 12)
	var library_x := _side.position.x + _side.size.x + 10
	var library_w := inner.end.x - library_x
	var library_h := 112.0 if _library_state == LibraryState.COMPACT else minf(188.0, safe.size.y * 0.40)
	var count := 0
	for card: Button in _chips.get_children():
		if card.visible:
			count += 1
	_chips.columns = maxi(1, ceili(count / 2.0) if _library_state == LibraryState.EXPANDED else count)
	var card_h := (library_h - 18.0) * 0.5 if _library_state == LibraryState.EXPANDED else 96.0
	for card: Button in _chips.get_children():
		card.custom_minimum_size = Vector2(140, card_h)
		var picture := card.get_node("Inhoud/Preview") as TextureRect
		picture.custom_minimum_size.y = maxf(24, card_h - 26)
	_library_scroll.custom_minimum_size.y = maxf(0, library_h - 12)
	_palette.visible = _library_state != LibraryState.HIDDEN and _tool != "gum"
	_palette.size = Vector2(library_w, library_h)
	_palette.position = Vector2(library_x, inner.end.y - library_h)
	_palette_handle.size = Vector2(72, 44)
	_palette_handle.position = Vector2(library_x + (library_w - 72) * 0.5, (_palette.position.y if _palette.visible else inner.end.y) - 46)
	_palette_handle.icon = EUI.icon("down" if _library_state == LibraryState.EXPANDED else "up")
	_palette_handle.tooltip_text = ["Bibliotheek tonen", "Bibliotheek uitbreiden", "Bibliotheek verbergen"][_library_state]
	var map_bottom := _palette.position.y - 8 if _palette.visible else inner.end.y
	var map_top := _top.position.y + _top.size.y + 8
	_view_btn.size = Vector2(96, 44)
	_view_btn.position = Vector2(inner.end.x - 96, map_top)
	_zoom_box.size = Vector2(44, 94)
	_zoom_box.position = Vector2(inner.end.x - 44, maxf(_view_btn.position.y + 52, (map_top + map_bottom - 94) * 0.5))
	_toast.size = Vector2(minf(380, library_w - 64), 0)
	_toast.position = Vector2(library_x + (library_w - _toast.size.x) * 0.5, map_top)
	_msg.custom_minimum_size.x = maxf(80, _toast.size.x - 16)
	_popup.size = Vector2(minf(560, inner.size.x), minf(360, inner.size.y))
	_popup.position = inner.position + (inner.size - _popup.size) * 0.5
	var columns := 1 if map_bottom - map_top >= 236 else 5 if inner.size.x > 600 else 3
	_action_grid.columns = columns
	for b: Button in _action_grid.get_children():
		b.custom_minimum_size = Vector2(80 if columns == 1 else 70, 44)
	_actions.reset_size()
	_last_toolbar_signature = ""
	_position_actions()


func _cycle_library() -> void:
	_set_library_state((_library_state + 1) % 3)


func _set_library_state(state: int) -> void:
	_library_state = clampi(state, LibraryState.HIDDEN, LibraryState.EXPANDED)
	_layout()


func _toggle_brush() -> void:
	if _look_mode:
		return
	_brush = not _brush
	_last_brush = Vector2(INF, INF)
	_refresh()


func _toggle_camera() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var preview := _cand.duplicate() if _drag.is_empty() and _is_place() else {}
	_cancel_drag()
	_ptrs.clear()
	_pinch = {}
	camera.set("editor_oblique", not bool(camera.get("editor_oblique")))
	_cand = preview
	_refresh_hl()
	_sync_camera_button()


func _sync_camera_button() -> void:
	var camera := get_viewport().get_camera_3d()
	var oblique := camera != null and bool(camera.get("editor_oblique"))
	_view_btn.text = "SCHUIN" if oblique else "BOVEN"
	_view_btn.tooltip_text = "Kijkhoek: schuin of recht van boven. Zoom en kaartpositie blijven gelijk."
	_look_btn.text = "KIJK" if _look_mode else "BEWERK"
	_look_btn.tooltip_text = "Veilig rondkijken; kaartacties zijn vergrendeld" if _look_mode else "Bewerken ingeschakeld; tik op KIJK om kaartacties te vergrendelen"
	EUI.button(_look_btn, _look_mode)


func _layout_dynamic() -> void:
	_position_actions()


func _position_actions() -> void:
	if not _actions.visible or not Game.editing:
		return
	var safe := _safe_rect().grow(-10)
	var target: Dictionary = _cand if not _cand.is_empty() else _sel
	var anchor := Rect2(safe.get_center() - Vector2(24, 24), Vector2(48, 48))
	var cam := get_viewport().get_camera_3d()
	if cam and not target.is_empty():
		var foot := Stad.rect_of(target)
		var h: float = Stad.KINDS[target.k].get("h", 0.3)
		var points := PackedVector2Array()
		for corner in [foot.position, Vector2(foot.end.x, foot.position.y), foot.end, Vector2(foot.position.x, foot.end.y)]:
			for y in [0.0, h]:
				var world := Vector3(corner.x, y, corner.y)
				if not cam.is_position_behind(world):
					points.append(cam.unproject_position(world))
		if not points.is_empty():
			anchor = Rect2(points[0], Vector2.ZERO)
			for point in points:
				anchor = anchor.expand(point)
	var toolbar_size := _actions.size
	var signature := "%s|%s|%s|%s|%s" % [safe, toolbar_size, _library_state, _tool, _toast.visible]
	if signature == _last_toolbar_signature and anchor.position.distance_squared_to(_last_toolbar_rect.position) < 1.0 and anchor.size.distance_squared_to(_last_toolbar_rect.size) < 1.0:
		return
	_last_toolbar_signature = signature
	_last_toolbar_rect = anchor
	var candidates: Array[Vector2] = [Vector2(anchor.end.x + 12, anchor.get_center().y - toolbar_size.y * 0.5),
		Vector2(anchor.position.x - toolbar_size.x - 12, anchor.get_center().y - toolbar_size.y * 0.5),
		Vector2(anchor.get_center().x - toolbar_size.x * 0.5, anchor.position.y - toolbar_size.y - 12),
		Vector2(anchor.get_center().x - toolbar_size.x * 0.5, anchor.end.y + 12)]
	var obstacles: Array[Control] = [_top, _side, _palette, _palette_handle, _zoom_box, _view_btn, _toast]
	var best := safe.position
	var best_score := INF
	# Bij een rand of klein scherm zoeken we ook vrije plekken langs de bedieningspanelen.
	for y in range(int(_top.position.y + _top.size.y + 6), int(safe.end.y - toolbar_size.y + 1), 16):
		for x in [safe.position.x + _side.size.x + 12, safe.end.x - toolbar_size.x - 52, safe.get_center().x - toolbar_size.x * 0.5]:
			candidates.append(Vector2(x, y))
	for point: Vector2 in candidates:
		var min_y := _top.position.y + _top.size.y + 8
		var max_y := (_palette.position.y - 8 if _palette.visible else safe.end.y) - toolbar_size.y
		var at := Vector2(clampf(point.x, safe.position.x, maxf(safe.position.x, safe.end.x - toolbar_size.x)),
			clampf(point.y, min_y, maxf(min_y, max_y)))
		var rect := Rect2(at, toolbar_size)
		var score := rect.get_center().distance_to(anchor.get_center())
		# Houd ook de geselecteerde geometrie vrij zolang elders plek is.
		score += rect.intersection(anchor.grow(6)).get_area() * 100
		for obstacle in obstacles:
			if obstacle.is_visible_in_tree():
				var overlap := rect.intersection(obstacle.get_rect().grow(4))
				if overlap.has_area():
					score += overlap.get_area() * 1000
		if score < best_score:
			best_score = score
			best = at
	_actions.position = best


# ---------------------------------------------------------------- in en uit

func enter() -> void:
	if Game.editing or Game.build_mode or Game.state != "prep" or Game.player == null:
		return
	if Game.player.elev > 0.5:
		Game.banner.emit("KOM EERST VAN DE TOREN", "", 1.4)
		return
	_stad = Stad.current
	if _stad == null:
		return
	if not is_instance_valid(_hl):
		_make_highlight()
	if _hl.get_parent() != _stad:
		if _hl.get_parent() != null:
			_hl.get_parent().remove_child(_hl)
		_stad.add_child(_hl)
	for preview in [_ghost, _grid]:
		if preview.get_parent() != _stad:
			if preview.get_parent() != null:
				preview.get_parent().remove_child(preview)
			_stad.add_child(preview)
	Game.editing = true
	_stad.view_limit(false)
	Game.build_mode = true
	_sync_camera_button()
	_ui.visible = true
	_close_popup()
	_library_state = LibraryState.COMPACT
	debug_enabled = OS.get_environment("BJ_EDITOR_DEBUG") == "1"
	_brush = false
	_cand = {}
	_tool = ""
	_look_mode = true
	_sel = {}
	_undo.clear()
	_ptrs.clear()
	_library_drag = {}
	_drag = {}
	_pinch = {}
	for g in FOLIAGE_GROUPS:
		for n in get_tree().get_nodes_in_group(g):
			if n is Node3D and n.visible:
				n.visible = false
				_hidden.append(n)
	Sfx.play("click")
	Game.changed.emit()
	_refresh()
	_stats()
	call_deferred("_layout")


func exit() -> void:
	if not Game.editing:
		return
	Game.editing = false
	if is_instance_valid(_stad):
		_stad.view_limit(true)
	Game.build_mode = false
	_ui.visible = false
	_close_popup()
	_hl.visible = false
	_ghost.visible = false
	_grid.visible = false
	_cand = {}
	_line_clear()
	_ptrs.clear()
	_library_drag = {}
	_drag = {}
	_pinch = {}
	for n in _hidden:
		if is_instance_valid(n):
			n.visible = true
	_hidden.clear()
	Game.changed.emit()


func _process(delta: float) -> void:
	if Game.editing and Game.state != "prep":
		exit()
	if _msg_t > 0.0:
		_msg_t -= delta
		if _msg_t <= 0.0:
			_msg.text = ""
	_toast.visible = Game.editing and _msg.text != ""
	if Game.editing:
		_layout_dynamic()
		_fps_refresh -= delta
		if _fps_refresh <= 0.0:
			_fps_refresh = 0.5
			_update_performance_display(Engine.get_frames_per_second(), GameSettings.target_fps())


func _say(t: String) -> void:
	_msg.text = t
	_toast.visible = t != ""
	_msg_t = 2.6
	_last_toolbar_signature = ""
	Sfx.play("ping", 0.5)


# ---------------------------------------------------------------- palet

func _pick_tab(id: String) -> void:
	if id == "gum":
		_tool = "gum" if _tool != "gum" else ""
	else:
		_cat = id
		if not Stad.ORDER[_cat].has(_tool):
			_tool = ""
	_sel = {}
	_cand = {}
	_last_brush = Vector2(INF, INF)
	_refresh()


func _toggle_look_mode() -> void:
	_set_look_mode(not _look_mode)


func _set_look_mode(enabled: bool) -> void:
	if _look_mode == enabled:
		return
	if enabled:
		_cancel_drag()
		_ptrs.clear()
		_pinch = {}
		_line_clear()
	_sel = {}
	_cand = {}
	_tool = ""
	_brush = false
	_look_mode = enabled
	_refresh()


func _pick_kind(kind: String) -> void:
	_tool = "" if _tool == kind else kind
	if Stad.KINDS.has(kind):
		_cat = Stad.KINDS[kind].cat
	elif LINE_TOOLS.has(kind):
		_cat = "weg"
	_sel = {}
	_cand = {}
	_rot = 0
	_mir = 0
	_last_brush = Vector2(INF, INF)
	_refresh()
	if _is_place():
		var bottom := _palette.position.y if _palette.visible else size.y - 20
		var pos := Vector2((_side.position.x + _side.size.x + size.x - 54) * 0.5, (_top.position.y + _top.size.y + bottom) * 0.5)
		_hover(pos)


func _refresh() -> void:
	if _chips == null:
		return
	for t in TABS:
		var on: bool = (t[0] == "gum" and _tool == "gum") or (t[0] != "gum" and t[0] == _cat and _tool != "gum")
		EUI.button(_tab_btns[t[0]], on)
		(_tab_btns[t[0]] as Button).add_theme_font_size_override("font_size", 10)
	if not _cards.has("category_" + _cat):
		for kind: String in Stad.ORDER[_cat]:
			if Stad.available(kind):
				_chip(kind, String(Stad.KINDS[kind].name), kind)
		if _cat == "weg":
			_chip("lijn", "Trek weg", "weg_recht")
			_chip("lijn_steeg", "Trek steeg", "weg_steeg")
		_cards["category_" + _cat] = true
	for card: Button in _chips.get_children():
		card.visible = card.get_meta("category") == _cat and _tool != "gum"
		var selected: bool = String(card.get_meta("tool")) == _tool
		EUI.button(card, selected)
		(card.get_node("Inhoud/Naam") as Label).add_theme_color_override("font_color", EUI.GOLD if selected else EUI.INK)
	_line_clear()
	EUI.button(_brush_btn, _brush)
	EUI.button(_rot_btn, _tool == "draai")
	_brush_btn.add_theme_font_size_override("font_size", 11)
	_rot_btn.add_theme_font_size_override("font_size", 11)
	_hint.text = "Tik om te plaatsen of te selecteren. Sleep een object om te verplaatsen; twee vingers bewegen en zoomen de kaart."
	_refresh_hl()
	_layout()


func _chip(tool: String, label: String, icon_kind: String) -> void:
	var b := _btn("", "", func():
		if Time.get_ticks_msec() - _library_drag_end > 160:
			_pick_kind(tool), _chips)
	# Geef touchbewegingen door aan de ScrollContainer; die annuleert kaartklikken bij een veeg.
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.name = "Kaart_" + tool
	b.set_meta("tool", tool)
	b.set_meta("category", _cat)
	b.tooltip_text = label
	b.clip_contents = true
	var box := VBoxContainer.new()
	box.name = "Inhoud"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 5
	box.offset_top = 4
	box.offset_right = -5
	box.offset_bottom = -4
	box.add_theme_constant_override("separation", 1)
	var picture := TextureRect.new()
	picture.name = "Preview"
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var path := ICON_DIR % icon_kind
	if ResourceLoader.exists(path):
		if not _textures.has(path):
			_textures[path] = load(path)
		picture.texture = _textures[path]
	box.add_child(picture)
	var short_names := {"winkel": "Winkel + flat", "kerk": "Kerk + toren", "benzine": "Benzine", "autobrand": "Brandende auto", "busbrand": "Brandende bus"}
	var title := UI.label(short_names.get(tool, label), EUI.font(), 12, EUI.INK)
	title.name = "Naam"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	box.add_child(title)
	_cards[tool] = b


func _stats(persist := true) -> void:
	if _stad == null:
		return
	_sloop_label.text = "SLOOPBAAR %d" % Stad.sloop_count(_stad.items)
	_update_performance_display(Engine.get_frames_per_second(), GameSettings.target_fps())
	_update_controls()
	if persist:
		_stad.save_user()


func _update_performance_display(fps: float, target: float) -> void:
	var goal := maxf(1.0, target)
	var actual := maxf(0.0, fps)
	var ratio := actual / goal
	var status := "METEN"
	var color: Color = EUI.MUTED
	if actual > 0.0:
		if ratio >= 0.93:
			status = "OP DOEL"
			color = EUI.GREEN
		elif ratio >= 0.75:
			status = "ONDER DOEL"
			color = EUI.GOLD
		else:
			status = "LAGE FPS"
			color = Color("ed8e78")
	_fps_label.text = "%d FPS · %s" % [roundi(actual), status]
	_fps_label.add_theme_color_override("font_color", color)
	_fps_label.tooltip_text = "Gemeten: %d FPS · doel: %d FPS" % [roundi(actual), roundi(goal)]
	_fps_bar.max_value = goal
	_fps_bar.value = minf(actual, goal)
	_fps_bar.tooltip_text = _fps_label.tooltip_text
	_fps_bar.add_theme_stylebox_override("fill", UI.box(color, Color.TRANSPARENT, 0, 4, 0))


func _update_controls() -> void:
	if _selected_label == null:
		return
	_look_btn.text = "KIJK" if _look_mode else "BEWERK"
	_look_btn.tooltip_text = "Veilig rondkijken; kaartacties zijn vergrendeld" if _look_mode else "Bewerken ingeschakeld; tik op KIJK om kaartacties te vergrendelen"
	EUI.button(_look_btn, _look_mode)
	var kind := String(_sel.get("k", _tool))
	_selected_label.text = String(Stad.KINDS[kind].name) if Stad.KINDS.has(kind) else "Weg tekenen" if LINE_TOOLS.has(kind) else "Gum" if kind == "gum" else "Draaimodus" if kind == "draai" else "Kies een object"
	_selected_label.tooltip_text = _selected_label.text
	_undo_btn.disabled = _look_mode or _undo.is_empty()
	var has_kind := Stad.KINDS.has(kind)
	var building: bool = has_kind and Stad.KINDS[kind].cat == "gebouw"
	_mirror_btn.disabled = building or not has_kind
	_mirror_btn.tooltip_text = "Dit gebouw behoudt zijn vaste oriëntatie; draaien kan wel" if building else "Spiegelen · M"
	_rot_btn.disabled = not has_kind and _tool != "draai"
	_copy_btn.disabled = _sel.is_empty()
	_delete_btn.disabled = _sel.is_empty()
	_brush_btn.disabled = not (_tool == "gum" or has_kind and Stad.KINDS[kind].cat == "straat" and _is_place())
	var selected_city_item := not _sel.is_empty() and _stad != null and _stad.items.has(_sel)
	var show_actions := not _look_mode and selected_city_item
	if _actions.visible != show_actions:
		_actions.visible = show_actions
		call_deferred("_layout")
	_last_toolbar_signature = ""


func _input(event: InputEvent) -> void:
	if not Game.editing:
		return
	if _library_input(event):
		get_viewport().set_input_as_handled()
		return
	var consumed := false
	if event is InputEventScreenTouch:
		_touch = true
		consumed = _ptrs.has(event.index) or not _over_ui(event.position)
		if event.canceled:
			if _ptrs.has(event.index):
				_cancel_drag()
				_ptrs.erase(event.index)
				_pinch = {}
		elif event.pressed:
			_down(event.index, event.position)
		else:
			_up(event.index, event.position)
	elif event is InputEventScreenDrag:
		consumed = _ptrs.has(event.index)
		_move(event.index, event.position)
	elif event is InputEventMouse and event.device != InputEvent.DEVICE_ID_EMULATION:
		_touch = false
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				consumed = _ptrs.has(-1) or not _over_ui(event.position)
				if event.pressed:
					_down(-1, event.position)
				else:
					_up(-1, event.position)
			elif event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
				if event.pressed and not _over_ui(event.position):
					_ptrs[-2] = event.position
					_drag = {"pan": true, "last": event.position, "sp": event.position, "moved": true, "id": -2}
					consumed = true
				elif not event.pressed and _drag.get("id", 0) == -2:
					_up(-2, event.position)
					consumed = true
			elif event.pressed and not _over_ui(event.position):
				if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
					_zoom_by(0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1)
					consumed = true
		elif event is InputEventMouseMotion:
			if _ptrs.has(-1) or _ptrs.has(-2):
				_move(-2 if _ptrs.has(-2) else -1, event.position)
				consumed = true
			elif _is_place() and not _over_ui(event.position):
				_hover(event.position)
	if consumed:
		get_viewport().set_input_as_handled()


func _library_input(event: InputEvent) -> bool:
	# Godots native veegbediening hangt van muisemulatie en de touchscreen-driver af.
	# Verwerk ruwe touch hier, zodat ook Xogot en tests dezelfde horizontale veeg krijgen.
	if _popup.visible:
		return false
	if event is InputEventScreenTouch:
		if event.pressed and _library_drag.is_empty() and _palette.is_visible_in_tree() and _palette.get_global_rect().has_point(event.position):
			if not _drag.is_empty():
				_cancel_drag()
			_ptrs.clear()
			_pinch = {}
			_library_drag = {"id": event.index, "start": event.position, "scroll": _library_scroll.scroll_horizontal, "moved": false}
		elif not _library_drag.is_empty():
			if event.index != _library_drag.id:
				return true
			if not event.pressed:
				if _library_drag.moved or event.canceled:
					_chips.propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
					_library_drag_end = Time.get_ticks_msec()
				_library_drag = {}
		# Laat loslaten ook door de GUI lopen, zodat eventuele muisemulatie haar focus vrijgeeft.
		return false
	if event is InputEventScreenDrag and not _library_drag.is_empty():
		if event.index != _library_drag.id:
			return true
		var delta: Vector2 = event.position - _library_drag.start
		if not _library_drag.moved and delta.length() > _library_scroll.scroll_deadzone:
			_library_drag.moved = true
			_chips.propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
		if _library_drag.moved:
			_library_drag_end = Time.get_ticks_msec()
			_library_scroll.scroll_horizontal = roundi(_library_drag.scroll - delta.x)
			return true
	if event is InputEventMouseMotion and event.device == InputEvent.DEVICE_ID_EMULATION and _library_drag.get("moved", false):
		return true
	return false


func _unhandled_key_input(e: InputEvent) -> void:
	if not e is InputEventKey or not e.pressed or e.echo:
		return
	if e.keycode == KEY_F8:
		if Game.editing:
			exit()
		else:
			enter()
		return
	if not Game.editing:
		return
	if _look_mode and e.keycode != KEY_ESCAPE and e.keycode != KEY_F3:
		return
	match e.keycode:
		KEY_R:
			_rotate()
		KEY_M:
			_mirror()
		KEY_K:
			if not _brush_btn.disabled:
				_toggle_brush()
		KEY_F3:
			debug_enabled = not debug_enabled
		KEY_DELETE, KEY_BACKSPACE:
			_delete_sel()
		KEY_ESCAPE:
			if _popup.visible:
				_close_popup()
			else:
				_tool = ""
				_sel = {}
				_cand = {}
				_refresh()
		KEY_Z:
			if e.ctrl_pressed or e.meta_pressed:
				_do_undo()


## Een gewoon onderdeel plaatsen (geen gum, draaimodus of wegenlijn)?
func _is_place() -> bool:
	return _tool != "" and _tool != "gum" and _tool != "draai" and not LINE_TOOLS.has(_tool)


func _over_ui(p: Vector2) -> bool:
	if _popup.visible:
		return true
	for control: Control in [_top, _side, _palette, _palette_handle, _actions, _zoom_box, _view_btn, _toast]:
		if control.is_visible_in_tree() and control.get_global_rect().has_point(p):
			return true
	return false


func _ground(p: Vector2) -> Variant:
	var cam := get_viewport().get_camera_3d()
	return Plane(Vector3.UP, 0.0).intersects_ray(cam.project_ray_origin(p), cam.project_ray_normal(p))


func _zoom_by(f: float) -> void:
	Game.ecam.z = clampf(Game.ecam.z * f, 0.35, 1.9)


func _clamp_cam() -> void:
	Game.ecam.x = clampf(Game.ecam.x, -Data.WORLD_X, Data.WORLD_X)
	Game.ecam.y = clampf(Game.ecam.y, -Data.WORLD_Z_N, 10.0)


## Grondprojectie houdt slepen correct bij beide kijkhoeken, zoom en schermranden.
func _pan_screen(from: Vector2, to: Vector2) -> void:
	var a: Variant = _ground(from)
	var b: Variant = _ground(to)
	if a != null and b != null:
		Game.ecam.x += a.x - b.x
		Game.ecam.y += a.z - b.z
		_clamp_cam()


func _down(id: int, pos: Vector2) -> void:
	if _over_ui(pos):
		if not _ptrs.is_empty():
			_cancel_drag()
		return
	_ptrs[id] = pos
	if _ptrs.size() == 2:
		_cancel_drag()
		var v: Array = _ptrs.values()
		_pinch = {"d": maxf(1.0, (v[0] - v[1]).length()), "zoom": Game.ecam.z, "mid": (v[0] + v[1]) * 0.5}
		return
	if _ptrs.size() > 2:
		return
	if _look_mode:
		_drag = {"pan": true, "last": pos, "sp": pos, "moved": false, "id": id}
		return
	var g: Variant = _ground(pos)
	if g == null:
		return
	if _tool == "gum":
		if _brush:
			_drag = {"gum": true, "g": g, "id": id, "sp": pos, "moved": false, "undo_start": _undo.size()}
		else:
			_drag = {"tap": "gum", "g": g, "id": id, "sp": pos, "moved": false, "last": pos}
		return
	if _tool == "draai":
		var it := _pick(g)
		if it.is_empty():
			_drag = {"pan": true, "last": pos, "sp": pos, "moved": false, "id": id}
		else:
			_sel = it
			_drag = {"tap": "rotate", "g": g, "id": id, "sp": pos, "moved": false, "last": pos}
			_refresh_hl()
		return
	if LINE_TOOLS.has(_tool):
		_line_cells = [_cell_of(g)]
		_drag = {"line": true, "id": id, "sp": pos, "moved": false}
		_line_update()
		return
	if _is_place():
		_aim(g)
		if _brush and Stad.KINDS[_tool].cat == "straat":
			_last_brush = Vector2(INF, INF)
			_drag = {"place": true, "g": g, "id": id, "sp": pos, "moved": false, "undo_start": _undo.size()}
		else:
			_drag = {"tap": "place", "g": g, "id": id, "sp": pos, "moved": false, "last": pos}
		return
	var it := _pick(g)
	if it.is_empty():
		_sel = {}
		_drag = {"pan": true, "last": pos, "sp": pos, "moved": false, "id": id}
		_refresh_hl()
		return
	_sel = it
	_drag = {"move": true, "d": it, "off": Vector2(it.x - g.x, it.z - g.z), "sp": pos, "moved": false, "id": id,
		"old": {"x": it.x, "z": it.z, "r": it.r, "m": it.m}}
	_refresh_hl()


func _cancel_drag() -> void:
	var undo_start := int(_drag.get("undo_start", _undo.size()))
	_drag = {}
	_cand = {}
	_line_clear()
	# Een tweede vinger maakt van de lopende kwast/gum een kaartgebaar.
	while _undo.size() > undo_start:
		_do_undo()
	_refresh_hl()


func _move(id: int, pos: Vector2) -> void:
	if not _ptrs.has(id):
		return
	_ptrs[id] = pos
	if not _pinch.is_empty() and _ptrs.size() >= 2:
		var v: Array = _ptrs.values()
		_set_zoom(_pinch.zoom * _pinch.d / maxf(1.0, (v[0] - v[1]).length()))
		var mid: Vector2 = (v[0] + v[1]) * 0.5
		_pan_screen(_pinch.mid, mid)
		_pinch.mid = mid
		return
	if _drag.is_empty() or id != _drag.id:
		return
	if _drag.has("tap"):
		if pos.distance_to(_drag.sp) < 10.0:
			return
		_drag = {"pan": true, "last": _drag.last, "sp": _drag.sp, "moved": false, "id": id}
		_cand = {}
		_refresh_hl()
	if _drag.has("pan"):
		if not _drag.moved and pos.distance_to(_drag.sp) < 8.0:
			return
		_drag.moved = true
		_pan_screen(_drag.last, pos)
		_drag.last = pos
		return
	if _over_ui(pos):
		return
	if _drag.has("line"):
		var gl: Variant = _ground(pos)
		if gl != null:
			_line_extend(_cell_of(gl))
		_drag.moved = true
		return
	if not _drag.moved and pos.distance_to(_drag.sp) < 6.0:
		return
	_drag.moved = true
	var g: Variant = _ground(pos)
	if g == null:
		return
	if _drag.has("gum"):
		_erase_at(g)
	elif _drag.has("place"):
		_aim(g)
		var at := Vector2(_cand.x, _cand.z)
		if _last_brush.distance_to(at) >= float(Stad.KINDS[_tool].spacing):
			_stamp()
	elif _drag.has("move"):
		var it: Dictionary = _drag.d
		var snap: float = Stad.KINDS[it.k].snap
		_cand = {"k": it.k, "x": roundf((g.x + _drag.off.x) / snap) * snap, "z": roundf((g.z + _drag.off.y) / snap) * snap, "r": it.r, "m": it.m}
		_show_cand()


func _set_zoom(z: float) -> void:
	Game.ecam.z = clampf(z, 0.35, 1.9)


func _up(id: int, pos := Vector2.INF) -> void:
	var last: Vector2 = _ptrs.get(id, Vector2.INF) if pos == Vector2.INF else pos
	_ptrs.erase(id)
	if _ptrs.size() < 2:
		_pinch = {}
	if _drag.is_empty() or id != _drag.id:
		return
	if last != Vector2.INF and _over_ui(last) and not _drag.has("pan"):
		_cancel_drag()
		return
	var dr := _drag
	_drag = {}
	# Sommige touchplatformen voegen de laatste beweging bij het loslaten samen.
	if dr.has("tap") and last != Vector2.INF and last.distance_to(dr.sp) >= 10.0:
		_cand = {}
		_refresh_hl()
		return
	if dr.has("line"):
		_line_apply()
		return
	if dr.has("tap"):
		if dr.tap == "gum":
			_erase_at(dr.g)
		elif dr.tap == "rotate":
			if not _sel.is_empty():
				_turn(_sel)
		else:
			_aim(dr.g)
			_place_cand()
			_cand = {}
		_refresh_hl()
		return
	if dr.has("gum") and not dr.moved:
		_erase_at(dr.g)
	elif dr.has("place") and not dr.moved:
		_stamp()
	elif dr.has("move") and dr.moved and not _cand.is_empty():
		var it: Dictionary = dr.d
		var problem := Stad.problem(_cand, _stad.items, it)
		if problem == "":
			it.x = _cand.x
			it.z = _cand.z
			_undo.append({"op": "move", "d": it, "old": dr.old})
			_stad.refresh(it)
			Sfx.play("click")
			_stats()
		else:
			_say(problem)
	_cand = {}
	_refresh_hl()


func _aim(g: Vector3) -> void:
	if _look_mode or not _is_place():
		return
	var s: float = Stad.KINDS[_tool].snap
	_cand = {"k": _tool, "x": roundf(g.x / s) * s, "z": roundf(g.z / s) * s, "r": _rot, "m": _mir}
	_show_cand()


func _hover(pos: Vector2) -> void:
	var g: Variant = _ground(pos)
	if g != null:
		_aim(g)


func _stamp() -> void:
	if _look_mode or _cand.is_empty():
		return
	if _place_cand():
		_last_brush = Vector2(_cand.x, _cand.z)


func _place_cand() -> bool:
	if _look_mode or _cand.is_empty():
		return false
	var p := Stad.problem(_cand, _stad.items)
	if p != "":
		_say(p)
		return false
	var d := _cand.duplicate()
	_stad.add_item(d)
	_undo.append({"op": "add", "d": d})
	Sfx.play("click")
	_stats()
	return true


func _pick(g: Vector3) -> Dictionary:
	# Bij schuin zicht ligt de zichtbare bovenkant niet boven dezelfde schermpixel als de voet.
	# Raak daarom eerst de echte botsvorm en zoek het bijbehorende bestaande stadsitem.
	var camera := get_viewport().get_camera_3d()
	var picked := {}
	var distance := INF
	if camera and Game.editing:
		var screen := camera.unproject_position(g)
		var origin := camera.project_ray_origin(screen)
		var end := origin + camera.project_ray_normal(screen) * camera.far
		var query := PhysicsRayQueryParameters3D.create(origin, end, Kit.LAYER_WALL)
		var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var node: Node = hit.collider
			while node != null and node != _stad:
				for item in _stad.items:
					if is_instance_valid(item.get("node")) and item.node == node:
						picked = item
						distance = origin.distance_squared_to(hit.position)
				node = node.get_parent()
		# Lantaarns zijn bewust decor zonder spelbotsing. Test hun zichtbare modelgrenzen
		# uitsluitend in de editor, zonder nieuwe physics of wijzigingen aan AI/gevechten.
		for item in _stad.items:
			if Stad.KINDS[item.k].cat == "straat" and is_instance_valid(item.get("node")):
				var mesh_distance := _mesh_hit(item.node, origin, end)
				if mesh_distance < distance:
					distance = mesh_distance
					picked = item
		if not picked.is_empty():
			return picked
	var pt := Vector2(g.x, g.z)
	for cat in ["straat", "gebouw", "weg"]:
		for i in range(_stad.items.size() - 1, -1, -1):
			var d: Dictionary = _stad.items[i]
			if Stad.KINDS[d.k].cat != cat:
				continue
			var r := Stad.rect_of(d)
			if cat == "straat":
				r = r.grow_individual(maxf(0.0, 0.9 - r.size.x / 2.0), maxf(0.0, 0.9 - r.size.y / 2.0), maxf(0.0, 0.9 - r.size.x / 2.0), maxf(0.0, 0.9 - r.size.y / 2.0))
			if r.has_point(pt):
				return d
	return {}


func _mesh_hit(node: Node, origin: Vector3, end: Vector3) -> float:
	if node is Node3D and not node.is_visible_in_tree():
		return INF
	var distance := INF
	if node is MeshInstance3D and node.mesh:
		var hit: Variant = node.mesh.get_aabb().intersects_segment(node.to_local(origin), node.to_local(end))
		if hit != null:
			distance = origin.distance_squared_to(node.to_global(hit))
	for child in node.get_children():
		distance = minf(distance, _mesh_hit(child, origin, end))
	return distance


func _erase_at(g: Vector3) -> void:
	var it := _pick(g)
	if it.is_empty():
		return
	_stad.remove_item(it)
	_undo.append({"op": "del", "d": it})
	if is_same(_sel, it):
		_sel = {}
	Sfx.play("click")
	_stats()
	_refresh_hl()


func _delete_sel() -> void:
	if _look_mode:
		return
	if _sel.is_empty():
		_say("TIK EERST OP IETS")
		return
	var it := _sel
	_sel = {}
	_stad.remove_item(it)
	_undo.append({"op": "del", "d": it})
	_stats()
	_refresh_hl()


## DRAAI: met een soort gekozen draait het plaatsvlak; anders zet het draaimodus aan of uit.
## In draaimodus draait elke tik op een onderdeel het een kwartslag.
func _rotate() -> void:
	if _look_mode:
		return
	if _is_place():
		_rot = (_rot + 1) % 4
		if not _cand.is_empty():
			_cand.r = _rot
			_show_cand()
		return
	if not _sel.is_empty():
		_turn(_sel)
		return
	_tool = "" if _tool == "draai" else "draai"
	_cand = {}
	_refresh()


func _turn(it: Dictionary) -> void:
	var cand := it.duplicate()
	cand.r = (int(it.r) + 1) % 4
	_apply_change(it, cand)


func _mirror() -> void:
	if _look_mode:
		return
	var kind := String(_sel.get("k", _tool))
	if Stad.KINDS.has(kind) and Stad.KINDS[kind].cat == "gebouw":
		_say("GEBOUWEN KUNNEN NIET SPIEGELEN")
		return
	if _is_place():
		_mir = 1 - _mir
		if not _cand.is_empty():
			_cand.m = _mir
			_show_cand()
		return
	if _sel.is_empty():
		_say("TIK EERST OP IETS")
		return
	var cand := _sel.duplicate()
	cand.m = 1 - int(_sel.m)
	_apply_change(_sel, cand)


func _apply_change(it: Dictionary, cand: Dictionary) -> void:
	var p := Stad.problem(cand, _stad.items, it)
	if p != "":
		_say(p)
		return
	_undo.append({"op": "move", "d": it, "old": {"x": it.x, "z": it.z, "r": it.r, "m": it.m}})
	it.x = cand.x
	it.z = cand.z
	it.r = cand.r
	it.m = cand.m
	_stad.refresh(it)
	Sfx.play("click")
	_stats()
	_refresh_hl()


func _copy() -> void:
	if _look_mode:
		return
	if _sel.is_empty():
		_say("TIK EERST OP IETS")
		return
	var h := Stad.half_of(_sel)
	var gap := 0.4 if Stad.KINDS[_sel.k].cat == "gebouw" else 0.5 if Stad.KINDS[_sel.k].cat == "straat" else 0.0
	var snap: float = Stad.KINDS[_sel.k].snap
	var dx := ceilf((h.x * 2.0 + gap) / snap) * snap
	var dz := ceilf((h.y * 2.0 + gap) / snap) * snap
	for off in [Vector2(dx, 0), Vector2(-dx, 0), Vector2(0, dz), Vector2(0, -dz)]:
		var cand := _sel.duplicate()
		cand.erase("node")
		cand.x = _sel.x + off.x
		cand.z = _sel.z + off.y
		if Stad.problem(cand, _stad.items) == "":
			_stad.add_item(cand)
			_undo.append({"op": "add", "d": cand})
			_sel = cand
			Sfx.play("click")
			_stats()
			_refresh_hl()
			return
	_say("GEEN PLEK ERNAAST")


func _do_undo() -> void:
	if _undo.is_empty():
		_say("NIETS OM ONGEDAAN TE MAKEN")
		return
	var u: Dictionary = _undo.pop_back()
	if u.op == "group":
		for i in range(u.ops.size() - 1, -1, -1):
			var o: Dictionary = u.ops[i]
			if o.op == "add":
				_stad.remove_item(o.d)
			else:
				_stad.add_item(o.d)
		_sel = {}
		Sfx.play("click")
		_stats()
		_refresh_hl()
		return
	var d: Dictionary = u.d
	match u.op:
		"add":
			_stad.remove_item(d)
		"del":
			_stad.add_item(d)
		"move":
			d.x = u.old.x
			d.z = u.old.z
			d.r = u.old.r
			d.m = u.old.m
			_stad.refresh(d)
	if is_same(_sel, d):
		_sel = {}
	Sfx.play("click")
	_stats()
	_refresh_hl()


# ---------------------------------------------------------------- aanwijzing op de kaart

func _show_cand() -> void:
	if _cand.is_empty():
		_hl.visible = false
		return
	var p := Stad.problem(_cand, _stad.items, _drag.d if _drag.has("move") else {})
	_set_hl(_cand, GOOD_COL if p == "" else BAD_COL, true)
	if p != "" and _drag.get("moved", false):
		_msg.text = p
		_msg_t = 0.6


func _refresh_hl() -> void:
	_update_controls()
	if _hl == null or _stad == null:
		return
	if not _sel.is_empty() and _drag.is_empty():
		_set_hl(_sel, SEL_COL)
	elif not _cand.is_empty() and (_is_place() or _drag.has("move")):
		_show_cand()
	else:
		_hl.visible = false
		_ghost.visible = false
		_grid.visible = false


func _set_hl(d: Dictionary, col: Color, preview := false) -> void:
	var r := Stad.rect_of(d)
	var k: Dictionary = Stad.KINDS[d.k]
	_hl_mesh.size = Vector3(r.size.x, 0.025, r.size.y)
	_hl.position = Vector3(r.get_center().x, 0.14, r.get_center().y)
	_hl_mat.albedo_color = Color(col, 0.075)
	_border_mat.albedo_color = Color(col, 1.0)
	_hl.visible = true
	for i in 4:
		var edge: MeshInstance3D = _borders[i]
		(edge.mesh as BoxMesh).size = Vector3(r.size.x + 0.12, 0.045, 0.12) if i < 2 else Vector3(0.12, 0.045, r.size.y)
		edge.position = Vector3(0, 0.02, r.size.y * (0.5 if i == 0 else -0.5)) if i < 2 else Vector3(r.size.x * (0.5 if i == 2 else -0.5), 0.02, 0)
	var dirs: Array = []
	if k.cat == "weg" and k.has("open"):
		for c in String(k.open):
			dirs.append(Stad.DIRS[c])
	elif k.cat != "weg":
		dirs.append(Vector2(0, 1))
	var yaw := Stad.yaw_of(d)
	for i in 4:
		var mark: MeshInstance3D = _marks[i]
		mark.visible = i < dirs.size()
		if i < dirs.size():
			var dv: Vector2 = dirs[i]
			var local := Vector3(dv.x * (-1.0 if int(d.m) == 1 else 1.0), 0, dv.y)
			var world := Basis(Vector3.UP, yaw) * local
			var reach := Stad.half_of(d)
			mark.position = world * (absf(world.x) * reach.x + absf(world.z) * reach.y + 0.28)
			mark.position.y = 0.04
	if preview:
		_ghost.show_item(d, col == GOOD_COL)
		_update_grid(d)
	else:
		_ghost.visible = false
		_grid.visible = false
	_update_controls()


func _update_grid(d: Dictionary) -> void:
	var snap: float = Stad.KINDS[d.k].snap
	var radius := 12.0
	var key := str(snap)
	if key != _grid_key:
		_grid_key = key
		var mesh := ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		var cells := ceili(radius / snap)
		for i in range(-cells, cells + 1):
			var at := float(i) * snap
			mesh.surface_add_vertex(Vector3(at, 0, -radius))
			mesh.surface_add_vertex(Vector3(at, 0, radius))
			mesh.surface_add_vertex(Vector3(-radius, 0, at))
			mesh.surface_add_vertex(Vector3(radius, 0, at))
		mesh.surface_end()
		_grid.mesh = mesh
	_grid.position = Vector3(d.x, 0.105, d.z)
	_grid.visible = true


const N := 1
const E := 2
const S := 4
const W := 8
static var _mask_table := {}   # bitmasker van openingen -> [soort, kwartslagen]


## Bitmasker (N=1, E=2, S=4, W=8) van de openingen van een wegdeel, met kwartslagen r (en spiegeling).
static func open_mask(open: String, r: int, mir := 0) -> int:
	var m := 0
	for c in open:
		var v: Vector2 = Stad.DIRS[c]
		var w := Basis(Vector3.UP, r * PI / 2.0) * Vector3(v.x * (-1.0 if mir == 1 else 1.0), 0, v.y)
		if roundf(w.z) < -0.5:
			m |= N
		elif roundf(w.x) > 0.5:
			m |= E
		elif roundf(w.z) > 0.5:
			m |= S
		else:
			m |= W
	return m


static func _table() -> Dictionary:
	if _mask_table.is_empty():
		for kind in ["weg_recht", "weg_bocht", "weg_t", "weg_kruis"]:
			for r in 4:
				var m := open_mask(Stad.KINDS[kind].open, r)
				if not _mask_table.has(m):
					_mask_table[m] = [kind, r]
	return _mask_table


static func _bits(m: int) -> int:
	return ((m & N) >> 0) + ((m & E) >> 1) + ((m & S) >> 2) + ((m & W) >> 3)


## Welk wegdeel en welke kwartslag hoort bij een bitmasker; steeg = smalle versie voor rechte stukken.
static func piece_for(mask: int, narrow: bool) -> Array:
	var m := mask
	if _bits(m) <= 1:
		m = E | W if (m & (E | W)) != 0 else N | S
	var t: Array = _table()[m]
	if narrow and t[0] == "weg_recht":
		return ["weg_steeg", t[1]]
	return t


static func _dir_bit(d: Vector2i) -> int:
	if d.x > 0:
		return E
	if d.x < 0:
		return W
	return S if d.y > 0 else N


static func _opposite(bit: int) -> int:
	match bit:
		N:
			return S
		S:
			return N
		E:
			return W
	return E


static func _bit_dir(bit: int) -> Vector2i:
	match bit:
		N:
			return Vector2i(0, -1)
		S:
			return Vector2i(0, 1)
		E:
			return Vector2i(1, 0)
	return Vector2i(-1, 0)


func _cell_of(g: Vector3) -> Vector2i:
	return Vector2i(roundi(g.x / Stad.CELL), roundi(g.z / Stad.CELL))


func _cell_pos(c: Vector2i) -> Vector2:
	return Vector2(c.x, c.y) * Stad.CELL


## Voegt cel c aan de lijn toe; tussenliggende cellen worden aangevuld, teruggaan maakt het laatste stukje ongedaan.
func _line_extend(c: Vector2i) -> void:
	var cur: Vector2i = _line_cells[-1]
	var guard := 0
	while cur != c and guard < 60:
		guard += 1
		var d := c - cur
		var step := Vector2i(signi(d.x), 0) if absi(d.x) >= absi(d.y) else Vector2i(0, signi(d.y))
		var nxt := cur + step
		if _line_cells.size() >= 2 and _line_cells[-2] == nxt:
			_line_cells.pop_back()
		else:
			_line_cells.append(nxt)
		cur = nxt
	_line_update()


func _road_items() -> Dictionary:
	var out := {}
	for d in _stad.items:
		var k: Dictionary = Stad.KINDS[d.k]
		if k.cat == "weg" and k.has("open"):
			out[Vector2i(roundi(d.x / Stad.CELL), roundi(d.z / Stad.CELL))] = d
	return out


func _in_plein(c: Vector2i) -> bool:
	var p := _cell_pos(c)
	for d in _stad.items:
		if Stad.KINDS[d.k].get("plein", false) and Stad.rect_of(d).has_point(p):
			return true
	return false


## Wat moet er gebeuren voor deze lijn? {ok, problem, cells: [[pos, slecht]], remove: [items], add: [items]}
func _line_plan_for(cells: Array) -> Dictionary:
	var narrow: bool = _tool == "lijn_steeg"
	var masks := {}
	for c: Vector2i in cells:
		if not masks.has(c):
			masks[c] = 0
	for i in range(cells.size() - 1):
		var a: Vector2i = cells[i]
		var b: Vector2i = cells[i + 1]
		var bit := _dir_bit(b - a)
		masks[a] |= bit
		masks[b] |= _opposite(bit)
	var roads := _road_items()
	var remove: Array = []
	var add: Array = []
	var shown: Array = []
	var bad := ""
	var base: Array = []
	var ro := {}   # cel -> bestaand item dat vervangen wordt
	for c: Vector2i in masks:
		if roads.has(c):
			ro[c] = roads[c]
	for d in _stad.items:
		var replaced := false
		for c in ro:
			if is_same(ro[c], d):
				replaced = true
		if not replaced:
			base.append(d)
	for c: Vector2i in masks:
		if _in_plein(c):
			continue
		var m: int = masks[c]
		# sluit aan op bestaande wegen ernaast die naar deze cel wijzen
		for bit in [N, E, S, W]:
			var nb: Vector2i = c + _bit_dir(bit)
			if masks.has(nb) or not roads.has(nb):
				continue
			var nd: Dictionary = roads[nb]
			if (open_mask(Stad.KINDS[nd.k].open, int(nd.r), int(nd.m)) & _opposite(bit)) != 0:
				m |= bit
		var was_narrow := false
		var was_zebra := false
		if ro.has(c):
			var od: Dictionary = ro[c]
			m |= open_mask(Stad.KINDS[od.k].open, int(od.r), int(od.m))
			was_narrow = od.k == "weg_steeg"
			was_zebra = od.k == "weg_zebra"
		var pc := piece_for(m, (narrow and not ro.has(c)) or was_narrow)
		if was_zebra and pc[0] == "weg_recht":
			pc = ["weg_zebra", pc[1]]   # een zebrapad blijft een zebrapad zolang de weg recht blijft
		var item := {"k": pc[0], "x": float(c.x) * Stad.CELL, "z": float(c.y) * Stad.CELL, "r": pc[1], "m": 0}
		if ro.has(c):
			var od2: Dictionary = ro[c]
			if od2.k == item.k and int(od2.r) == int(item.r):
				shown.append([_cell_pos(c), false])
				continue
			remove.append(od2)
		var p := Stad.problem(item, base)
		if p != "":
			if bad == "":
				bad = p
			shown.append([_cell_pos(c), true])
			continue
		base.append(item)
		add.append(item)
		shown.append([_cell_pos(c), false])
	return {"ok": bad == "" and not (add.is_empty() and remove.is_empty()), "problem": bad, "cells": shown, "remove": remove, "add": add}


func _line_update() -> void:
	_line_plan = _line_plan_for(_line_cells)
	_line_show(_line_plan.cells)
	if _line_plan.problem != "":
		_msg.text = _line_plan.problem
		_msg_t = 0.6


func _line_show(cells: Array) -> void:
	if _line_hl == null or not is_instance_valid(_line_hl):
		_line_hl = Node3D.new()
		_stad.add_child(_line_hl)
	while _line_hl.get_child_count() < cells.size():
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(Stad.CELL - 0.3, 0.3, Stad.CELL - 0.3)
		mi.mesh = bm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_line_hl.add_child(mi)
	for i in _line_hl.get_child_count():
		var mi := _line_hl.get_child(i) as MeshInstance3D
		mi.visible = i < cells.size()
		if i < cells.size():
			var pos: Vector2 = cells[i][0]
			mi.position = Vector3(pos.x, 0.25, pos.y)
			mi.material_override = _hl_mat_for(cells[i][1])


var _good_mat: StandardMaterial3D
var _bad_mat: StandardMaterial3D


func _hl_mat_for(bad: bool) -> StandardMaterial3D:
	if _good_mat == null:
		_good_mat = _hl_mat.duplicate()
		_good_mat.albedo_color = GOOD_COL
		_bad_mat = _hl_mat.duplicate()
		_bad_mat.albedo_color = BAD_COL
	return _bad_mat if bad else _good_mat


func _line_clear() -> void:
	_line_cells = []
	_line_plan = {}
	if _line_hl != null and is_instance_valid(_line_hl):
		for c in _line_hl.get_children():
			(c as Node3D).visible = false


func _line_apply() -> void:
	var plan := _line_plan
	_line_clear()
	if plan.is_empty():
		return
	if plan.problem != "":
		_say(plan.problem)
		return
	if plan.add.is_empty() and plan.remove.is_empty():
		return
	var ops: Array = []
	for d in plan.remove:
		_stad.remove_item(d)
		ops.append({"op": "del", "d": d})
	for d in plan.add:
		_stad.add_item(d)
		ops.append({"op": "add", "d": d})
	_undo.append({"op": "group", "ops": ops})
	Sfx.play("click")
	_stats()


# ---------------------------------------------------------------- tekst voor Claude

func _show_text() -> void:
	_cancel_drag()
	_ptrs.clear()
	_library_drag = {}
	_pinch = {}
	_modal_scrim.visible = true
	_text.text = Stad.to_text(_stad.items)
	_reset_arm = false
	_reset_btn.text = "STANDAARD"
	_popup.visible = true


func _copy_text() -> void:
	DisplayServer.clipboard_set(_text.text)
	_msg.text = "GEKOPIEERD. PLAK HET IN DE CHAT MET CLAUDE."
	_msg_t = 3.5
	Sfx.play("buy")


## Terug naar de stad zoals die in de code staat: haalt je eigen indeling weg.
func _reset_default() -> void:
	if not _reset_arm:
		_reset_arm = true
		_reset_btn.text = "ZEKER?"
		return
	_reset_arm = false
	_reset_btn.text = "STANDAARD"
	_sel = {}
	_undo.clear()
	_stad.set_items(Stad.from_lines(StadData.ITEMS))
	Stad.clear_saved()
	_close_popup()
	_stats(false)
	_refresh_hl()
