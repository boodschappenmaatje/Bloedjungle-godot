class_name PauseMenu
extends CanvasLayer
## Pauzemenu en instellingen van de web-versie. Staat in een eigen laag boven de rest van de HUD.

const ROWS := [
	["quality", "Grafiek", [["low", "Laag"], ["high", "Hoog"], ["ultra", "Ultra"]]],
	["time", "Tijd", [["day", "Dag"], ["dusk", "Avond"], ["night", "Nacht"]]],
	["prep", "Bouwtijd tussen golven", [["60", "1 min"], ["120", "2 min"], ["300", "5 min"], ["600", "10 min"]]],
	["weather", "Weer", [["clear", "Helder"], ["rain", "Regen"], ["mist", "Mist"]]],
	["fps", "FPS-teller", [["off", "Uit"], ["on", "Aan"]]],
]
const NOTES := {
	"low": "Laag: geen schaduwen en een lichtere afbeelding, voor oudere telefoons.",
	"high": "Hoog: schaduwen dichtbij en gloed, een goede balans.",
	"ultra": "Ultra gebruikt de volle kracht van nieuwe iPhones: scherpere pixels en alle schaduwen.",
}

var _root: ColorRect
var _pause_sheet: PanelContainer
var _set_sheet: PanelContainer
var _mute_btn: Button
var _note: Label
var _segs := {}


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = ColorRect.new()
	_root.color = Color(6.0 / 255.0, 8.0 / 255.0, 4.0 / 255.0, 0.72)
	_root.add_to_group("hud_button")
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_root.hide()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	_pause_sheet = _sheet(380)
	center.add_child(_pause_sheet)
	_set_sheet = _sheet(520)
	center.add_child(_set_sheet)
	_build_pause()
	_build_settings()
	set_paused(false)


func _sheet(w: float) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.custom_minimum_size.x = w
	var sb := UI.box(UI.PANEL, UI.PANEL_LINE, 1, 8, 20)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 30
	pc.add_theme_stylebox_override("panel", sb)
	return pc


func _button(text: String, kind: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	UI.style_button(b, kind)
	b.pressed.connect(cb)
	return b


func _build_pause() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_pause_sheet.add_child(v)
	v.add_child(UI.label("PAUZE", UI.display(1), 34, UI.INK))
	v.add_child(_button("VERDER", "primary", func(): set_paused(false)))
	_mute_btn = _button("", "secondary", _toggle_sound)
	v.add_child(_mute_btn)
	v.add_child(_button("Instellingen", "secondary", func(): _show(true)))
	v.add_child(_button("Stoppen", "secondary", func():
		get_tree().paused = false
		get_tree().reload_current_scene()))
	_refresh_sound()


func _build_settings() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_set_sheet.add_child(v)
	v.add_child(UI.label("BEELD EN SFEER", UI.body(700, 2), 12, UI.BRASS))
	v.add_child(UI.label("INSTELLINGEN", UI.display(1), 34, UI.INK))
	for r in ROWS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var l := UI.label(r[1], UI.body(600, 0), 17, UI.INK)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var seg := HBoxContainer.new()
		seg.add_theme_constant_override("separation", 4)
		_segs[r[0]] = []
		for o in r[2]:
			var key: String = r[0]
			var val: String = o[0]
			var b := _button(o[1], "seg", func():
				GameSettings.set_value(key, val)
				_apply()
				_refresh())
			b.set_meta("v", val)
			seg.add_child(b)
			_segs[key].append(b)
		row.add_child(seg)
		v.add_child(row)
	_note = UI.label("", UI.body(500, 0), 14, UI.INK_DIM)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size.x = 440
	v.add_child(_note)
	v.add_child(_button("KLAAR", "primary", func(): _show(false)))
	_refresh()


func _refresh() -> void:
	for key in _segs:
		for b in _segs[key]:
			UI.seg_state(b, GameSettings.get_value(key) == b.get_meta("v"))
	_note.text = NOTES[GameSettings.get_value("quality")]


func _apply() -> void:
	for n in get_tree().get_nodes_in_group("atmosphere"):
		n.apply_settings()


func _toggle_sound() -> void:
	GameSettings.set_value("sound", "off" if GameSettings.get_value("sound") == "on" else "on")
	_refresh_sound()


func _refresh_sound() -> void:
	var on := GameSettings.get_value("sound") == "on"
	AudioServer.set_bus_mute(0, not on)
	_mute_btn.text = "Geluid: aan" if on else "Geluid: uit"


func _show(settings: bool) -> void:
	_pause_sheet.visible = not settings
	_set_sheet.visible = settings


func set_paused(on: bool) -> void:
	get_tree().paused = on
	_root.visible = on
	_show(false)


func is_open() -> bool:
	return _root.visible


func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		if _root.visible and _set_sheet.visible:
			_show(false)
		else:
			set_paused(not _root.visible)
