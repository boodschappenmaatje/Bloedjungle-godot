class_name RangKeuze
extends Control
## Kiesscherm voor je rangpunten (Generals-plan E1): zes krachten onder elkaar (vier sinds E1, plus luchtaanval en parachutisten in E2), elk met pictogram, niveau (drie bolletjes) en wat het volgende
## niveau doet. Tik op een kracht om er een punt aan te geven; SLUIT of een tik ernaast sluit het scherm. Het spel loopt door, maar lopen en
## schieten staan stil zolang het scherm open staat (groep "kaart_open", zoals bij de grote kaart). Opent met de KIES-knop (CombatButtons).

const CARD_H := 54.0
const GAP := 6.0
const HEAD_H := 46.0
const FOOT_H := 44.0

var _cards: Array = []     # Rect2 per kracht in Rang.VOLGORDE
var _close := Rect2()
var _panel := Rect2()
var _hot := -1
var _born := -1            # beeldnummer waarin het scherm opende (zie _input)


static func open(parent: Control) -> RangKeuze:
	var k := RangKeuze.new()
	parent.add_child(k)
	return k


func _ready() -> void:
	add_to_group("kaart_open")   # TouchSticks laat sticks en schieten met rust zolang deze groep gevuld is
	name = "RangKeuze"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 120
	resized.connect(_layout)
	_layout()
	_born = Engine.get_process_frames()
	Sfx.play("click")


func _exit_tree() -> void:
	if is_in_group("kaart_open"):
		remove_from_group("kaart_open")


func _layout() -> void:
	var safe := UI.safe_margins(size)
	var w := minf(size.x - safe.x - safe.z - 24.0, 480.0)
	var n := Rang.VOLGORDE.size()
	var h := HEAD_H + float(n) * CARD_H + float(n - 1) * GAP + 10.0 + FOOT_H
	h = minf(h, size.y - safe.y - safe.w - 8.0)
	_panel = Rect2(Vector2((size.x - w) * 0.5, maxf(safe.y + 4.0, (size.y - h) * 0.5)), Vector2(w, h))
	_cards.clear()
	var y := _panel.position.y + HEAD_H
	var ch := minf(CARD_H, (h - HEAD_H - FOOT_H - float(n - 1) * GAP - 10.0) / float(n))
	for i in Rang.VOLGORDE.size():
		_cards.append(Rect2(Vector2(_panel.position.x + 10.0, y), Vector2(w - 20.0, ch)))
		y += ch + GAP
	_close = Rect2(Vector2(_panel.position.x + w * 0.5 - 60.0, _panel.end.y - FOOT_H + 4.0), Vector2(120.0, 34.0))
	queue_redraw()


func _process(_delta: float) -> void:
	var p = Game.player
	var weg: bool = Game.rang_punten <= 0 or p == null or not is_instance_valid(p) or p.dead or p.driving or get_tree().paused or Game.build_mode
	if weg:
		queue_free()
		return
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		queue_free()
		return
	var pos := Vector2.ZERO
	var pressed := false
	var pointer := false
	if event is InputEventScreenTouch:
		pos = event.position
		pressed = event.pressed
		pointer = true
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		pressed = event.pressed
		pointer = true
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		_hot = _card_at(event.position)
		return
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		get_viewport().set_input_as_handled()
		return
	if not pointer:
		return
	get_viewport().set_input_as_handled()   # nooit door naar de knoppen of sticks eronder
	if not pressed:
		return
	# Een vinger op de KIES-knop geeft twee gebeurtenissen vlak na elkaar: eerst het nagebootste muisgebaar (daar opent de knop op, button_down) en
	# daarna in hetzelfde beeld de aanraking zelf. Die tweede zou hier buiten het paneel vallen en het scherm meteen weer sluiten ("tik ernaast").
	if Engine.get_process_frames() <= _born:
		return
	if _close.has_point(pos) or not _panel.has_point(pos):
		queue_free()
		return
	var i := _card_at(pos)
	if i >= 0:
		kies(String(Rang.VOLGORDE[i]))


## Geeft een punt aan de kracht. Als er geen punten meer zijn sluit het scherm (via _process).
func kies(id: String) -> bool:
	var ok := Rang.punt_uitgeven(id)
	if not ok:
		Sfx.play("click", 0.6)
	queue_redraw()
	return ok


func _card_at(pos: Vector2) -> int:
	for i in _cards.size():
		if (_cards[i] as Rect2).has_point(pos):
			return i
	return -1


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.58))
	draw_style_box(UI.box(Color(0.03, 0.045, 0.038, 0.97), Color(UI.BRASS, 0.55), 1, 8, 0), _panel)
	var fh: Font = UI.body(700, 1)
	var fb: Font = UI.body(700, 0)
	var x0 := _panel.position.x + 14.0
	draw_string(fh, Vector2(x0, _panel.position.y + 22.0), "KIES EEN KRACHT", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UI.BRASS)
	var sub := "%s · %d %s over" % [Rang.naam(Game.rang), Game.rang_punten, "punt" if Game.rang_punten == 1 else "punten"]
	draw_string(fb, Vector2(x0, _panel.position.y + 38.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.INK_DIM)
	for i in _cards.size():
		_teken_kaart(i, _cards[i])
	draw_style_box(UI.box(Color(0.025, 0.04, 0.035, 0.9), Color(UI.BRASS, 0.6), 1, 8, 0), _close)
	var tw := fh.get_string_size("SLUIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(fh, _close.position + Vector2((_close.size.x - tw) * 0.5, 22.0), "SLUIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.INK)


func _teken_kaart(i: int, r: Rect2) -> void:
	var id: String = Rang.VOLGORDE[i]
	var n := Rang.echt_niveau(id)
	var max_ := n >= Rang.MAX_NIVEAU
	var hot := i == _hot and not max_
	draw_style_box(UI.box(Color(0.2, 0.155, 0.055, 0.98) if hot else Color(0.025, 0.04, 0.035, 0.92), Color(UI.BRASS, 0.9 if hot else (0.28 if max_ else 0.55)), 1, 8, 0), r)
	var col := Color(UI.INK_DIM, 0.55) if max_ else UI.BRASS
	var kk := clampf(r.size.y / CARD_H, 0.7, 1.0)   # zes kaarten passen op een lage telefoon alleen als ze iets krimpen
	Rang.teken_icoon(self, id, r.position + Vector2(30.0, r.size.y * 0.5), 0.9 * kk, col)
	var fh: Font = UI.body(700, 1)
	var fb: Font = UI.body(600, 0)
	var tx := r.position.x + 58.0
	draw_string(fh, Vector2(tx, r.position.y + 21.0 * kk), String(Rang.KRACHTEN[id].naam), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.INK if not max_ else UI.INK_DIM)
	var pip_x := tx + fh.get_string_size(String(Rang.KRACHTEN[id].naam), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 12.0
	for k in Rang.MAX_NIVEAU:
		var c := Vector2(pip_x + float(k) * 12.0, r.position.y + 16.5 * kk)
		if k < n:
			draw_circle(c, 4.0, UI.BRASS)
		else:
			draw_arc(c, 3.6, 0.0, TAU, 12, Color(UI.INK_DIM, 0.7), 1.3, true)
	var regel := ""
	if max_:
		regel = "Niveau 3: %s" % Rang.tekst(id, 3)
	elif n == 0:
		regel = "Nieuw: %s" % Rang.tekst(id, 1)
	else:
		regel = "Niveau %d: %s" % [n + 1, Rang.tekst(id, n + 1)]
		if id == "artillerie" and Game.hq_level >= 3 and int(Game.krachten.get(id, 0)) == 0:
			regel = "HK: niveau 1. " + regel
	draw_string(fb, Vector2(tx, r.position.y + 40.0 * kk), regel, HORIZONTAL_ALIGNMENT_LEFT, r.end.x - tx - 8.0, 10, UI.INK_DIM)
