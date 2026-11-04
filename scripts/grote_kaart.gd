class_name GroteKaart
extends Control
## De grote kaart: tik op de kleine radar rechtsboven en de kaart vult het scherm, zodat je duim er niet meer overheen ligt.
## Zonder commandokeuze is het een overzicht (tik ergens om te sluiten). Wacht het commandowiel op een doel (Aanvallen,
## Verplaatsen, Verdedigen), dan is een tik op de kaart dat doel: op het rode vlak van de vijandbasis stuurt Aanvallen je leger naar zijn poort.
## Het tekenwerk is hetzelfde als op de radar (HudExtra.draw_map_on); hier komen alleen de ruimte, de teksten en de tik bij.

const MARGIN := 12.0
const HEAD := 52.0
const TAP_SLACK := 22.0   # verder dan dit verschuift de vinger: dan is het geen tik meer

var _hud: Node
var _target := false
var _panel := Rect2()
var _map := Rect2()
var _close := Rect2()
var _side := false   # titel en uitleg links van de kaart (liggend scherm) in plaats van erboven
var _down := -2   # vinger-index (of -1 voor de muis) die op de kaart is neergekomen
var _down_pos := Vector2.ZERO
var _moved := false


func _ready() -> void:
	name = "GroteKaart"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # de invoer loopt via _input, zodat het commandowiel en de sticks er niet doorheen grijpen
	z_index = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hud = get_parent()
	resized.connect(_layout)


func is_open() -> bool:
	return visible


## `target`: het commandowiel wacht op een doel, een tik op de kaart is dat doel.
func open_map(target: bool) -> void:
	_target = target
	_down = -2
	_moved = false
	visible = true
	add_to_group("kaart_open")   # TouchSticks laat sticks en schieten met rust zolang deze groep gevuld is
	_layout()
	queue_redraw()


func close_map() -> void:
	visible = false
	_down = -2
	if is_in_group("kaart_open"):
		remove_from_group("kaart_open")


func _process(_delta: float) -> void:
	if not visible:
		return
	# pauze, menu, bouwen of game over: de kaart gaat dicht
	if Game.state not in ["prep", "play"] or Game.build_mode or Game.editing or get_tree().paused:
		close_map()
		return
	var tc := get_tree().get_first_node_in_group("team_commands")
	if _target and (tc == null or tc.controller.pending_order == ""):
		_target = false   # het bevel is al geannuleerd of uitgegeven: alleen nog een overzicht
	queue_redraw()


## Indeling. Liggend scherm: de kaart gebruikt de hele hoogte, de titel en uitleg staan links ernaast. Staand: een kop boven de kaart.
func _layout() -> void:
	var safe := UI.safe_margins(size)
	_panel = Rect2(Vector2(safe.x + MARGIN, safe.y + MARGIN), size - Vector2(safe.x + safe.z + 2.0 * MARGIN, safe.y + safe.w + 2.0 * MARGIN))
	var aspect := (2.0 * Data.WORLD_X) / (Data.WORLD_Z_N + Data.WORLD_Z_S)
	var landscape := _panel.size.x >= _panel.size.y * 1.25
	var inner := _panel.grow(-10.0)
	if not landscape:
		inner = Rect2(_panel.position + Vector2(10.0, HEAD), _panel.size - Vector2(20.0, HEAD + 10.0))
	var w := inner.size.x
	var h := w / aspect
	if h > inner.size.y:
		h = inner.size.y
		w = h * aspect
	_map = Rect2(inner.position + (inner.size - Vector2(w, h)) * 0.5, Vector2(w, h))
	_side = landscape and _map.position.x - _panel.position.x >= 170.0
	_close = Rect2(Vector2(_panel.end.x - 100.0, _panel.position.y + 6.0), Vector2(92.0, 36.0))


func map_rect() -> Rect2:
	return _map


## Schermpunt op de kaart naar een punt in de wereld (y = 0).
func to_world(screen: Vector2) -> Vector3:
	var fx := clampf((screen.x - _map.position.x) / _map.size.x, 0.0, 1.0)
	var fz := clampf((screen.y - _map.position.y) / _map.size.y, 0.0, 1.0)
	return Vector3(lerpf(-Data.WORLD_X, Data.WORLD_X, fx), 0.0, lerpf(-Data.WORLD_Z_N, Data.WORLD_Z_S, fz))


func _hint() -> String:
	if not _target:
		return "Tik ergens om te sluiten"
	var tc := get_tree().get_first_node_in_group("team_commands")
	match tc.controller.pending_order if tc != null else "":
		"attack":
			return "Tik op het rode vlak om de vijandbasis aan te vallen"
		"move":
			return "Tik waar je soldaten heen moeten"
		"defend":
			return "Tik op de plek die ze moeten verdedigen"
	return "Tik op de kaart"


func _draw() -> void:
	if not visible or _hud == null:
		return
	var font := UI.body(700, 0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.64))
	draw_style_box(UI.box(Color(0.02, 0.035, 0.028, 0.97), Color(UI.PANEL_LINE, 0.95), 2, 8, 0), _panel)
	draw_string(font, _panel.position + Vector2(14.0, 26.0), "KAART", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, UI.BRASS)
	var hint_col := Color(1.0, 0.86, 0.55) if _target else UI.INK_DIM
	if _side:
		var room := _map.position.x - _panel.position.x - 34.0
		draw_multiline_string(font, _panel.position + Vector2(14.0, 52.0), _hint(), HORIZONTAL_ALIGNMENT_LEFT, room, 15, 4, hint_col)
	else:
		draw_string(font, _panel.position + Vector2(14.0, 46.0), _hint(), HORIZONTAL_ALIGNMENT_LEFT, _panel.size.x - 120.0, 13, hint_col)
	draw_style_box(UI.box(Color(0.1, 0.12, 0.08, 0.95), Color(UI.BRASS, 0.9), 1, 6, 0), _close)
	draw_string(font, _close.position + Vector2(0.0, 24.0), "SLUIT", HORIZONTAL_ALIGNMENT_CENTER, _close.size.x, 14, UI.INK)
	draw_rect(_map, Color(0.07, 0.11, 0.08, 1.0), true)
	draw_rect(_map, Color(UI.PANEL_LINE, 0.9), false, 1.5)
	var k := clampf(_map.size.y / 170.0, 1.6, 3.0)
	_hud.draw_map_on(self, _map, k)
	_draw_labels(font)
	_draw_legend(font)


func _label(font: Font, at: Vector2, text: String, col: Color, anchor_center := false) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var p := at - Vector2(w * 0.5 if anchor_center else 0.0, 0.0)
	p.x = clampf(p.x, _map.position.x + 3.0, _map.end.x - w - 3.0)
	p.y = clampf(p.y, _map.position.y + 13.0, _map.end.y - 4.0)
	draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color(0, 0, 0, 0.8))
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)


func _draw_labels(font: Font) -> void:
	var patch: Rect2 = _hud._base_patch(_map)
	_label(font, Vector2(patch.get_center().x, patch.position.y - 7.0), "VIJANDBASIS", Color(1.0, 0.62, 0.5), true)
	_label(font, _hud._radar_point(Vector3.ZERO, _map) + Vector2(11.0, 15.0), "JOUW BASIS", Color(1.0, 0.82, 0.45))
	var player: Node3D = Game.player
	if player != null and is_instance_valid(player):
		_label(font, _hud._radar_point(player.global_position, _map) + Vector2(10.0, -8.0), "JIJ", Color(0.55, 0.9, 1.0))
	_label(font, _map.position + Vector2(8.0, 16.0), "N ▲", UI.INK_DIM)


## Wat de kleuren betekenen, naast de kaart als er ruimte is (liggend scherm).
func _draw_legend(font: Font) -> void:
	var room := _panel.end.x - _map.end.x - 24.0
	if room < 130.0:
		return
	var x := _map.end.x + 22.0
	var y := _map.position.y + 20.0
	var rows := [
		["jij", Color(0.27, 0.86, 1.0)],
		["je soldaten", Color(0.35, 0.68, 1.0)],
		["vijand", Color(1.0, 0.24, 0.16)],
		["vijandbasis", Color(0.9, 0.16, 0.1)],
		["jouw basis en torens", Color(1.0, 0.74, 0.28)],
	]
	for row in rows:
		draw_circle(Vector2(x, y - 4.0), 5.0, row[1])
		draw_string(font, Vector2(x + 12.0, y), String(row[0]), HORIZONTAL_ALIGNMENT_LEFT, room - 12.0, 12, UI.INK_DIM)
		y += 24.0


func _input(e: InputEvent) -> void:
	if not visible:
		return
	if e is InputEventKey:
		if e.pressed and not e.echo and (e.keycode == KEY_ESCAPE or e.keycode == KEY_M):
			close_map()
			get_viewport().set_input_as_handled()
		return
	if e is InputEventScreenTouch:
		if e.pressed:
			if _down == -2:
				_down = e.index
				_down_pos = e.position
				_moved = false
		elif e.index == _down:
			_down = -2
			if not _moved:
				_tap(e.position)
	elif e is InputEventScreenDrag:
		if e.index == _down and e.position.distance_to(_down_pos) > TAP_SLACK:
			_moved = true
	elif e is InputEventMouseButton:
		if e.device != InputEvent.DEVICE_ID_EMULATION:   # een aanraking komt ook als muis binnen: die tellen we niet dubbel
			if e.button_index == MOUSE_BUTTON_LEFT:
				if e.pressed:
					_down = -1
					_down_pos = e.position
					_moved = false
				elif _down == -1:
					_down = -2
					if not _moved:
						_tap(e.position)
			elif e.button_index == MOUSE_BUTTON_RIGHT and e.pressed:
				close_map()
	elif e is InputEventMouseMotion:
		if _down == -1 and e.position.distance_to(_down_pos) > TAP_SLACK:
			_moved = true
	else:
		return
	get_viewport().set_input_as_handled()


func _tap(pos: Vector2) -> void:
	if _close.grow(6.0).has_point(pos):
		close_map()
		return
	if not _target:
		close_map()   # overzicht: een tik sluit
		return
	if not _map.has_point(pos):
		if not _panel.has_point(pos):
			close_map()   # naast het paneel: terug naar het spel, het bevel blijft wachten
		return
	var tc := get_tree().get_first_node_in_group("team_commands")
	if tc == null:
		close_map()
		return
	var world := to_world(pos)
	var attack: bool = tc.controller.pending_order == "attack"
	var on_base: bool = attack and (_hud._base_patch(_map).grow(10.0).has_point(pos) or VijandBasis.contains(world, 6.0))
	if not attack and VijandBasis.contains(world, 2.0):
		Game.banner.emit("VIJANDBASIS", "Daar stuur je geen soldaten heen. Kies Aanvallen om de basis aan te vallen.", 2.5)
		return   # de kaart blijft open, het bevel blijft wachten
	if tc.pick_from_map(world, on_base):
		close_map()
