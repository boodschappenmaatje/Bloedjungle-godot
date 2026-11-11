class_name BevelStand
extends Control
## De bevelstand in het spel (Dennis' keuzes 4A, 6A, 7A, 8A, 9A, 11A, 11 nov 2026).
## De BEVEL-knop staat boven de BOUW/TEAM-knop. Tik hem aan: de camera zoomt iets uit, de sticks rusten, het spel loopt op 30 %
## en je kiest je soldaten zoals in Command & Conquer: tik een soldaat, sleep een kader, dubbeltik = al je soldaten van die soort
## in beeld. Met een keuze tik je op de grond (verplaatsen), op een vijand (aanvallen) of je kiest een ander bevel in de bevelbalk.
## Groepsvakjes 1-2-3: tik = kiezen, vasthouden = opslaan. Tik op de radar opent de grote kaart met dezelfde keuze.
## Ook buiten de bevelstand tekent dit vlak de korte bevelmarkers en lijnen (1,6 s na een bevel).
## Alles wordt in 2D getekend met de camera (unproject): geen extra 3D-objecten, dus voor de iPhone vrijwel gratis.

const BTN := 48.0
const TAP_SLACK := 14.0
const PICK_PX := 30.0      # vinger: zo dicht bij een soldaat of vijand telt de tik als "op hem"
const HOLD_SAVE := 0.5
const DOUBLE_TAP := 0.4
const CAM_DISTANCE := 34.0 # camera iets verder weg zolang de bevelstand open is (normaal 22,5)
const CAM_SOUTH := 7.0     # m: en iets naar het zuiden, want de bevelbalk ligt onderin

var active := false
var _btn := Rect2()
var _bar: Array = []
var _row := {}             # "all", "none", "g0".."g2", "done" -> Rect2
var _hint_y := 0.0
var _touch := -2
var _mode := ""            # tap, box, klaar
var _start := Vector2.ZERO
var _box_to := Vector2.ZERO
var _press_t := 0.0
var _press_btn := ""
var _last_tap_t := -10.0
var _last_tap_unit: Node3D
var _dimmed: Array = []


func _ready() -> void:
	name = "BevelStand"
	add_to_group("bevel_stand")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 120
	process_mode = Node.PROCESS_MODE_ALWAYS


func _sel() -> TroepSelectie:
	return TroepSelectie.inst(get_tree())


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _allowed() -> bool:
	return Game.state in ["prep", "play"] and not Game.build_mode and not Game.editing and not get_tree().paused


func open_stand() -> bool:
	if active or not _allowed():
		return active
	var tc := get_tree().get_first_node_in_group("team_commands")
	if tc != null:
		if tc.controller.pointer_id != -2:
			return false   # het teamwiel heeft een vinger vast
		tc.cancel_input()
	active = true
	_touch = -2
	_mode = ""
	add_to_group("bevelstand_actief")
	add_to_group("kaart_open")   # TouchSticks: sticks en schieten rusten (zoals bij de grote kaart)
	_dim(true)
	Sfx.play("ping", 0.15)
	queue_redraw()
	return true


func close_stand() -> void:
	if not active:
		return
	active = false
	_touch = -2
	_mode = ""
	if is_in_group("bevelstand_actief"):
		remove_from_group("bevelstand_actief")
	if is_in_group("kaart_open"):
		remove_from_group("kaart_open")
	_dim(false)
	queue_redraw()


## Vechtknoppen, wapenbalk en sticks vervagen tijdens de bevelstand: je ziet dat ze nu niets doen.
func _dim(on: bool) -> void:
	if on:
		_dimmed.clear()
		for g in ["combat_buttons", "weapon_strip", "touch_sticks"]:
			for n in get_tree().get_nodes_in_group(g):
				if n is CanvasItem:
					_dimmed.append(n)
					(n as CanvasItem).modulate.a = 0.22
	else:
		for n in _dimmed:
			if is_instance_valid(n):
				(n as CanvasItem).modulate.a = 1.0
		_dimmed.clear()


func _exit_tree() -> void:
	close_stand()


func _layout() -> void:
	var v := size
	var safe := UI.safe_margins(v)
	var tc := get_tree().get_first_node_in_group("team_commands")
	if tc != null and tc.button != null:
		var tb: Rect2 = tc.button.get_global_rect()
		_btn = Rect2(Vector2(tb.get_center().x - BTN * 0.5, tb.position.y - BTN - 12.0), Vector2(BTN, BTN))
	else:
		_btn = Rect2(Vector2(safe.x + 25.0, v.y * 0.5 - BTN - 40.0), Vector2(BTN, BTN))
	var bar_w := minf(v.x - safe.x - safe.z - 40.0, 600.0)
	var bar_h := 44.0
	var bx := (v.x - bar_w) * 0.5
	var by := v.y - safe.w - bar_h - 10.0
	_bar = BevelBalk.rects(Rect2(Vector2(bx, by), Vector2(bar_w, bar_h)))
	var ry := by - 40.0
	var w := 62.0
	_row = {
		"all": Rect2(Vector2(bx, ry), Vector2(w, 32.0)),
		"none": Rect2(Vector2(bx + w + 6.0, ry), Vector2(w, 32.0)),
		"done": Rect2(Vector2(bx + bar_w - w - 10.0, ry), Vector2(w + 10.0, 32.0)),
	}
	var gw := 46.0
	var gx := bx + bar_w * 0.5 - (gw * 3.0 + 12.0) * 0.5
	for i in 3:
		_row["g%d" % i] = Rect2(Vector2(gx + float(i) * (gw + 6.0), ry), Vector2(gw, 32.0))
	_hint_y = ry - 10.0


func _process(_delta: float) -> void:
	_layout()
	if active and not _allowed():
		close_stand()
	if active:
		var hud := get_tree().get_first_node_in_group("hud_extra")
		if hud != null and hud.map_is_open():
			_touch = -2   # de kaart neemt de vinger over
			_mode = ""
		if _mode == "tap" and _press_btn.begins_with("g") and _now() - _press_t >= HOLD_SAVE:
			var ts := _sel()
			if ts != null:
				ts.save_group(int(_press_btn.substr(1)))
				Game.banner.emit("GROEP %d" % (int(_press_btn.substr(1)) + 1), "%d soldaten opgeslagen. Tik het vakje om ze weer te kiezen." % ts.sel.size(), 1.6)
			_mode = "klaar"
	var ts2 := _sel()
	if active or (ts2 != null and (ts2.lines_fresh() or not ts2.marks.is_empty())) or _button_visible():
		queue_redraw()


func _button_visible() -> bool:
	return Game.state in ["prep", "play"] and not Game.build_mode and not Game.editing


# ---------------------------------------------------------------- tekenen

func _draw() -> void:
	var cam := get_viewport().get_camera_3d()
	var ts := _sel()
	if _button_visible():
		_draw_button(ts)
	if cam == null or ts == null:
		return
	var hud := get_tree().get_first_node_in_group("hud_extra")
	var map_open: bool = hud != null and hud.map_is_open()
	if map_open:
		return
	var show_lines := active or ts.lines_fresh()
	if active:
		# wie je kunt kiezen: een dunne groene ring; gekozen: dik en licht, met een levensbalkje
		for a in TroepSelectie.units():
			if not ts.is_selected(a):
				_ground_ring(cam, a.global_position, 0.7, Color(HudExtra.C_EIGEN, 0.55), 1.2)
	for a in ts.sel:
		if not is_instance_valid(a):
			continue
		if active or ts.lines_fresh():
			_ground_ring(cam, a.global_position, 0.8, HudExtra.C_EIGEN_HI, 2.6)
			_hp_bar(cam, a)
		if show_lines:
			_order_line(cam, a)
	for m in ts.live_marks():
		_mark(cam, m)
	if active:
		_draw_panel(ts)
		if _mode == "box":
			var b := Rect2(_start, _box_to - _start).abs()
			draw_rect(b, Color(HudExtra.C_EIGEN_HI, 0.12), true)
			draw_rect(b, HudExtra.C_EIGEN_HI, false, 1.5)


func _draw_button(ts: TroepSelectie) -> void:
	var c := _btn.get_center()
	var r := BTN * 0.5
	var n := TroepSelectie.units().size()
	var col := UI.BRASS if n > 0 else Color(UI.BRASS, 0.45)
	draw_circle(c, r, Color(0.17, 0.14, 0.065, 0.94) if active else Color(0.025, 0.04, 0.035, 0.84))
	draw_arc(c, r, 0.0, TAU, 32, Color(UI.BRASS, 0.9 if active else 0.3), 1.4 if active else 1.0, true)
	# pictogram: kaderhoekjes om twee soldaatjes, met een pijl
	var s := 11.0
	for d in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var p := c + Vector2(d.x * s, d.y * s - 3.0)
		draw_polyline(PackedVector2Array([p - Vector2(d.x * 5.0, 0.0), p, p - Vector2(0.0, d.y * 5.0)]), col, 2.0)
	draw_circle(c + Vector2(-4.0, -6.0), 2.6, col)
	draw_circle(c + Vector2(4.0, -6.0), 2.6, col)
	draw_arc(c + Vector2(-4.0, 0.0), 4.0, PI, TAU, 8, col, 2.2)
	draw_arc(c + Vector2(4.0, 0.0), 4.0, PI, TAU, 8, col, 2.2)
	draw_string(UI.body(700, 1), Vector2(_btn.position.x - 10.0, _btn.end.y - 5.0), "BEVEL", HORIZONTAL_ALIGNMENT_CENTER, BTN + 20.0, 9, col)
	if ts != null and not ts.sel.is_empty():
		var bc := _btn.position + Vector2(BTN - 4.0, 4.0)
		draw_circle(bc, 8.0, Color(0.1, 0.2, 0.07, 0.95))
		draw_string(UI.body(700, 0), bc + Vector2(-8.0, 4.0), str(ts.sel.size()), HORIZONTAL_ALIGNMENT_CENTER, 16.0, 10, HudExtra.C_EIGEN_HI)


func _draw_panel(ts: TroepSelectie) -> void:
	var font := UI.body(700, 1)
	var n := ts.sel.size()
	var hint := "Tik een soldaat aan, sleep een kader of tik ALLES"
	if n > 0:
		var wie := "%d %s" % [n, "soldaat" if n == 1 else "soldaten"]
		match ts.armed:
			"attack":
				hint = wie + " · tik een vijand of plek om aan te vallen"
			"defend":
				hint = wie + " · tik de plek die ze verdedigen"
			"bewaak":
				hint = wie + " · tik wat ze bewaken (gebouw, voertuig, soldaat of jij)"
			_:
				hint = wie + " · tik waar ze heen moeten, of op een vijand"
	var w := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var hp := Vector2((size.x - w) * 0.5, _hint_y)
	draw_string_outline(font, hp, hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 5, Color(0, 0, 0, 0.85))
	draw_string(font, hp, hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.88, 0.6))
	for key in ["all", "none", "done"]:
		var r: Rect2 = _row[key]
		var label: String = {"all": "ALLES", "none": "GEEN", "done": "KLAAR"}[key]
		var strong: bool = key == "done"
		draw_style_box(UI.box(Color(0.08, 0.1, 0.06, 0.95) if strong else Color(0.03, 0.045, 0.03, 0.9), Color(UI.BRASS, 0.8 if strong else 0.45), 1, 5, 0), r)
		draw_string(font, Vector2(r.position.x, r.position.y + 21.0), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 11, UI.INK if strong else UI.BRASS)
	for i in 3:
		var r: Rect2 = _row["g%d" % i]
		var cnt := ts.group_count(i)
		var held: bool = _mode == "tap" and _press_btn == "g%d" % i
		draw_style_box(UI.box(Color(0.1, 0.2, 0.07, 0.95) if held else Color(0.03, 0.045, 0.03, 0.9), Color(HudExtra.C_EIGEN if cnt > 0 else UI.PANEL_LINE, 0.9), 1, 5, 0), r)
		if held:
			var f := clampf((_now() - _press_t) / HOLD_SAVE, 0.0, 1.0)
			draw_rect(Rect2(r.position + Vector2(2.0, r.size.y - 4.0), Vector2((r.size.x - 4.0) * f, 2.0)), HudExtra.C_EIGEN_HI)
		draw_string(font, Vector2(r.position.x, r.position.y + 21.0), "%d · %d" % [i + 1, cnt] if cnt > 0 else str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 12, HudExtra.C_EIGEN_HI if cnt > 0 else UI.INK_DIM)
	BevelBalk.draw(self, _bar, ts.armed, n > 0)


## Een ring op de grond rond `at` (in perspectief, net als de echte soldaatring).
func _ground_ring(cam: Camera3D, at: Vector3, r: float, col: Color, w: float) -> void:
	if cam.is_position_behind(at):
		return
	var pts := PackedVector2Array()
	for i in 21:
		var a := TAU * float(i) / 20.0
		pts.append(cam.unproject_position(Vector3(at.x + cos(a) * r, 0.06, at.z + sin(a) * r)))
	draw_polyline(pts, col, w, true)


func _hp_bar(cam: Camera3D, a: Node3D) -> void:
	var top: Vector3 = a.global_position + Vector3.UP * 2.15
	if cam.is_position_behind(top):
		return
	var p := cam.unproject_position(top)
	var f := clampf(float(a.get("hp")) / maxf(float(a.get("hp_max")), 1.0), 0.0, 1.0)
	var r := Rect2(p - Vector2(13.0, 2.0), Vector2(26.0, 4.0))
	draw_rect(r.grow(1.0), Color(0, 0, 0, 0.7), true)
	draw_rect(Rect2(r.position, Vector2(r.size.x * f, r.size.y)), HudExtra.C_EIGEN if f > 0.35 else Color(1.0, 0.55, 0.2), true)


func _order_line(cam: Camera3D, a: Node3D) -> void:
	var cmd := String(a.get("command"))
	if cmd in ["follow", "hold"]:
		return
	var to: Vector3 = a.get("command_target")
	var ce: Variant = a.get("command_enemy")
	var cn: Variant = a.get("command_node")
	if ce != null and is_instance_valid(ce):
		to = (ce as Node3D).global_position
	elif cn != null and is_instance_valid(cn):
		to = (cn as Node3D).global_position
	var from := Vector3(a.global_position.x, 0.08, a.global_position.z)
	to.y = 0.08
	if cam.is_position_behind(from) or cam.is_position_behind(to):
		return
	var p0 := cam.unproject_position(from)
	var p1 := cam.unproject_position(to)
	if p0.distance_to(p1) > 8.0:
		draw_dashed_line(p0, p1, Color(TroepSelectie.order_color(cmd), 0.7), 1.6, 7.0, true)


## Korte marker op de grond: groene vlag (verplaats), rood vizier (aanval), gouden schild (verdedig, houd, bewaak).
func _mark(cam: Camera3D, m: Dictionary) -> void:
	var at: Vector3 = m.pos
	if cam.is_position_behind(at):
		return
	var age := TroepSelectie.now() - float(m.t)
	var a := clampf(1.0 - age / TroepSelectie.MARK_TIME, 0.0, 1.0)
	var order := String(m.order)
	var col := Color(TroepSelectie.order_color(order), a)
	_ground_ring(cam, at, 0.6 + 1.1 * (1.0 - a), col, 2.2)
	_ground_ring(cam, at, 0.35, Color(col, a * 0.7), 1.4)
	var p := cam.unproject_position(at + Vector3.UP * 0.9)
	BevelBalk._glyph(self, "attack" if order == "basis" else order, p, 9.0, col)


# ---------------------------------------------------------------- invoer

func _row_at(pos: Vector2) -> String:
	for key in _row:
		if (_row[key] as Rect2).grow(3.0).has_point(pos):
			return key
	var b := BevelBalk.hit(_bar, pos)
	if b >= 0:
		return "bar%d" % b
	return ""


func _input(e: InputEvent) -> void:
	if not _button_visible():
		return
	var hud := get_tree().get_first_node_in_group("hud_extra")
	if hud != null and hud.map_is_open():
		return   # de grote kaart neemt alles
	var pressed := false
	var released := false
	var moved := false
	var id := -3
	var pos := Vector2.ZERO
	if e is InputEventScreenTouch:
		id = e.index
		pos = e.position
		pressed = e.pressed
		released = not e.pressed
	elif e is InputEventScreenDrag:
		id = e.index
		pos = e.position
		moved = true
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.device == InputEvent.DEVICE_ID_EMULATION:
			if active:
				get_viewport().set_input_as_handled()
			return
		id = -1
		pos = e.position
		pressed = e.pressed
		released = not e.pressed
	elif e is InputEventMouseMotion and e.device != InputEvent.DEVICE_ID_EMULATION and _touch == -1:
		id = -1
		pos = e.position
		moved = true
	elif e is InputEventKey and e.pressed and not e.echo and active and e.keycode == KEY_ESCAPE:
		close_stand()
		get_viewport().set_input_as_handled()
		return
	else:
		return
	if not active:
		# alleen de BEVEL-knop zelf
		if pressed and _btn.grow(4.0).has_point(pos):
			var tc := get_tree().get_first_node_in_group("team_commands")
			if tc != null and tc.controller.is_modal():
				return
			open_stand()
			get_viewport().set_input_as_handled()
		return
	# bevelstand: de radar (grote kaart) en het menuknopje blijven werken, al het andere is voor ons
	if hud != null and pressed and (hud.radar_hit(pos) or (hud._menu_button != null and hud._menu_button.get_global_rect().has_point(pos))):
		return
	get_viewport().set_input_as_handled()
	if pressed:
		if _touch != -2:
			return   # één vinger tegelijk
		_touch = id
		_start = pos
		_box_to = pos
		_press_t = _now()
		_press_btn = "btn" if _btn.grow(4.0).has_point(pos) else _row_at(pos)
		_mode = "tap"
	elif moved and id == _touch:
		if _mode == "tap" and _press_btn == "" and pos.distance_to(_start) > TAP_SLACK:
			_mode = "box"
		if _mode == "box":
			_box_to = pos
	elif released and id == _touch:
		_touch = -2
		if _mode == "tap":
			_tap(pos)
		elif _mode == "box":
			_finish_box()
		_mode = ""


## Schermplek van een soldaat of vijand (borsthoogte), of null achter de camera.
func _screen(cam: Camera3D, n: Node3D) -> Variant:
	var at := n.global_position + Vector3.UP * 0.9
	if cam.is_position_behind(at):
		return null
	return cam.unproject_position(at)


func _pick(cam: Camera3D, list: Array, pos: Vector2) -> Node3D:
	var best: Node3D = null
	var bd := PICK_PX
	for n in list:
		if not is_instance_valid(n) or not n is Node3D or n.get("dead") == true:
			continue
		var sp: Variant = _screen(cam, n)
		if sp == null:
			continue
		var d := (sp as Vector2).distance_to(pos)
		if d < bd:
			bd = d
			best = n
	return best


func _on_screen(cam: Camera3D) -> Array:
	var out: Array = []
	var r := get_viewport().get_visible_rect()
	for a in TroepSelectie.units():
		var sp: Variant = _screen(cam, a)
		if sp != null and r.has_point(sp):
			out.append(a)
	return out


func _finish_box() -> void:
	var cam := get_viewport().get_camera_3d()
	var ts := _sel()
	if cam == null or ts == null:
		return
	var box := Rect2(_start, _box_to - _start).abs().grow(6.0)
	var list: Array = []
	for a in TroepSelectie.units():
		var sp: Variant = _screen(cam, a)
		if sp != null and box.has_point(sp):
			list.append(a)
	ts.select(list)


## Een punt op de grond onder de vinger (de grond ligt op y = 0).
func _ground(cam: Camera3D, pos: Vector2) -> Variant:
	var o := cam.project_ray_origin(pos)
	var d := cam.project_ray_normal(pos)
	if d.y > -0.02:
		return null
	return o + d * (-o.y / d.y)


func _tap(pos: Vector2) -> void:
	var ts := _sel()
	if ts == null:
		return
	match _press_btn:
		"btn", "done":
			close_stand()
			return
		"all":
			ts.select_all()
			if ts.sel.is_empty():
				Game.banner.emit("GEEN SOLDATEN", "Bouw een kazerne en train soldaten.", 2.2)
			return
		"none":
			ts.clear()
			return
	if _press_btn.begins_with("g"):
		if not ts.pick_group(int(_press_btn.substr(1))):
			Game.banner.emit("GROEP %d IS LEEG" % (int(_press_btn.substr(1)) + 1), "Kies soldaten en houd het vakje vast om ze op te slaan.", 2.0)
		return
	if _press_btn.begins_with("bar"):
		ts.bar_press(TroepSelectie.ORDERS[int(_press_btn.substr(3))])
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var own := _pick(cam, TroepSelectie.units(), pos)
	if ts.armed == "bewaak" and not ts.sel.is_empty():
		var who: Node3D = own if own != null and not ts.is_selected(own) else _pick(cam, [Game.player], pos)
		var g: Variant = _ground(cam, pos)
		if who == null and g != null:
			who = TroepSelectie.guardable_near(get_tree(), g, 4.0)
		ts.apply_tap(g if g != null else Vector3.ZERO, null, who)
		return
	if own != null:
		var now := _now()
		if now - _last_tap_t < DOUBLE_TAP and is_instance_valid(_last_tap_unit) and String(_last_tap_unit.get("kind")) == String(own.get("kind")):
			ts.select_kind(String(own.get("kind")), _on_screen(cam))
			_last_tap_t = -10.0
		else:
			ts.select([own])
			_last_tap_t = now
			_last_tap_unit = own
		return
	if ts.sel.is_empty():
		return
	var enemy := _pick(cam, Game.enemies, pos)
	var world: Variant = _ground(cam, pos)
	if enemy == null and world == null:
		return
	ts.apply_tap(world if world != null else enemy.global_position, enemy, null)
