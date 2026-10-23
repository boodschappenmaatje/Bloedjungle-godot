extends Control
## Compacte wapenkaart in de stijl van Dead Nation: alleen het wapen dat je vast hebt (met munitie), met
## ◀ ▶ om te wisselen. Tik op de kaart en de andere wapens klappen 3 seconden open. De plaatjes zijn
## foto's van de echte 3D-wapenmodellen (assets/wapens.glb), eenmalig gerenderd bij het opstarten.
## Het spel bezit de wapens; de HUD is uitsluitend een selectie- en informatielaag.

## Pijl getekend als vorm: het lettertype heeft geen ◀ ▶ en toonde alleen een leeg vakje.
class ArrowGlyph:
	extends Control
	var dir := 1.0
	func _draw() -> void:
		var c := size * 0.5
		var w := minf(size.x * 0.28, 9.0)
		var h := minf(size.y * 0.22, 14.0)
		var pts := PackedVector2Array([c + Vector2(dir * w, 0.0), c + Vector2(-dir * w, -h), c + Vector2(-dir * w, h)])
		draw_colored_polygon(pts, Color.WHITE)  # de kleur komt van modulate (goud of gedimd)


const IDS := ["m1911", "thompson", "garand", "trench", "mg42", "bazooka"]
const GUNS := preload("res://assets/wapens.glb")
const OPEN_TIME := 3.0
const ICON_SIZE := Vector2i(256, 96)

var _icons := {}  # wapen-id -> ImageTexture
var _card: Button
var _prev: Button
var _next: Button
var _prev_glyph: ArrowGlyph
var _next_glyph: ArrowGlyph
var _pic: TextureRect
var _name: Label
var _ammo: Label
var _list: Array[Button] = []  # uitgeklapt: de andere wapens
var _list_pics: Array[TextureRect] = []
var _list_names: Array[Label] = []
var _open_t := 0.0
var _last_state := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card = _button(_toggle_list)
	_pic = _picture(_card)
	_name = _label(_card, 11, HORIZONTAL_ALIGNMENT_LEFT)
	_ammo = _label(_card, 22, HORIZONTAL_ALIGNMENT_RIGHT)
	_prev = _button(_cycle.bind(-1))
	_prev_glyph = _arrow(_prev, -1.0)
	_next = _button(_cycle.bind(1))
	_next_glyph = _arrow(_next, 1.0)
	for i in IDS.size():
		var b := _button(_select.bind(i))
		_list.append(b)
		_list_pics.append(_picture(b))
		_list_names.append(_label(b, 10, HORIZONTAL_ALIGNMENT_CENTER))
	resized.connect(_layout)
	_layout()
	_refresh()
	_render_icons()


func _button(on_press: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.add_to_group("hud_button")
	b.button_down.connect(on_press)
	add_child(b)
	return b


func _arrow(parent: Control, dir: float) -> ArrowGlyph:
	var g := ArrowGlyph.new()
	g.dir = dir
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(g)
	return g


func _picture(parent: Control) -> TextureRect:
	var r := TextureRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	parent.add_child(r)
	return r


func _label(parent: Control, font_size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", font_size)
	parent.add_child(l)
	return l


## Elk wapenmodel zijdelings in een eigen kleine wereld fotograferen (loop naar rechts) en als texture bewaren.
func _render_icons() -> void:
	if DisplayServer.get_name() == "headless":
		return  # zonder beeldscherm is er niets te fotograferen
	var vp := SubViewport.new()
	vp.size = ICON_SIZE
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.88, 0.9)
	env.ambient_light_energy = 1.4
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35.0, 55.0, 0.0)
	sun.light_energy = 1.6
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	var holder := GUNS.instantiate()
	vp.add_child(holder)
	for i in IDS.size():
		var id: String = IDS[i]
		var node := holder.find_child(SoldierModel.GUN_OF[id], true, false) as Node3D
		if node == null:
			continue
		for other in holder.get_children():
			(other as Node3D).visible = false
		node.visible = true
		var p := node.get_parent()
		while p != null and p != holder:
			(p as Node3D).visible = true
			p = p.get_parent()
		var box := _box(node)
		var center := box.get_center()
		# de loop wijst langs -Z; een camera op +X die naar -X kijkt heeft -Z rechts in beeld
		cam.size = maxf(box.size.y, box.size.z / (float(ICON_SIZE.x) / float(ICON_SIZE.y))) * 1.12
		cam.position = center + Vector3(6.0, 0.0, 0.0)
		cam.look_at(center, Vector3.UP)
		await get_tree().process_frame
		await get_tree().process_frame
		var img := vp.get_texture().get_image()
		if img != null and not img.is_empty():
			_icons[id] = ImageTexture.create_from_image(_polish(img))
	vp.queue_free()
	_last_state = ""
	_refresh()


## Maakt het plaatje leesbaar op de donkere kaart: de donkere metalen delen lichter en een lichte rand rondom, zodat de vorm
## ook van een zwart pistool goed te zien is.
static func _polish(img: Image) -> Image:
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var src := img.get_data()
	var out := src.duplicate()
	var r := 3
	# rand: alpha een paar punten uitsmeren (eerst horizontaal, dan verticaal)
	var hor := PackedByteArray()
	hor.resize(w * h)
	for y in h:
		for x in w:
			var m := 0
			for k in range(-r, r + 1):
				var xx := x + k
				if xx >= 0 and xx < w:
					m = maxi(m, src[(y * w + xx) * 4 + 3])
			hor[y * w + x] = m
	for y in h:
		for x in w:
			var m := 0
			for k in range(-r, r + 1):
				var yy := y + k
				if yy >= 0 and yy < h:
					m = maxi(m, hor[yy * w + x])
			var i := (y * w + x) * 4
			var fa := src[i + 3] / 255.0
			var ba := (m / 255.0) * 0.9  # de lichte rand
			# voorgrond (opgelicht) over de rand heen leggen
			var fr := minf(src[i] / 255.0 * 1.7 + 0.1, 1.0)
			var fg := minf(src[i + 1] / 255.0 * 1.7 + 0.1, 1.0)
			var fb := minf(src[i + 2] / 255.0 * 1.7 + 0.1, 1.0)
			var oa := fa + ba * (1.0 - fa)
			if oa <= 0.001:
				continue
			out[i] = int(clampf((fr * fa + 0.96 * ba * (1.0 - fa)) / oa, 0.0, 1.0) * 255.0)
			out[i + 1] = int(clampf((fg * fa + 0.86 * ba * (1.0 - fa)) / oa, 0.0, 1.0) * 255.0)
			out[i + 2] = int(clampf((fb * fa + 0.62 * ba * (1.0 - fa)) / oa, 0.0, 1.0) * 255.0)
			out[i + 3] = int(oa * 255.0)
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, out)


static func _box(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if root is MeshInstance3D:
		var b2: AABB = root.global_transform * (root as MeshInstance3D).get_aabb()
		box = b2 if first else box.merge(b2)
	return box


func _layout() -> void:
	var portrait := size.x < size.y
	var y0 := size.y - (140.0 if not portrait else 222.0)  # staand boven de zet-neer-knoppen (place_hud.gd)
	var arrow := Vector2(34.0, 64.0)
	var card := Vector2(150.0, 64.0)
	var x := 16.0
	_prev.position = Vector2(x, y0)
	_prev.size = arrow
	_card.position = Vector2(x + arrow.x + 3.0, y0)
	_card.size = card
	_next.position = Vector2(x + arrow.x + 3.0 + card.x + 3.0, y0)
	_next.size = arrow
	_pic.position = Vector2(4, 4)
	_pic.size = Vector2(card.x - 8.0, 40.0)
	_name.position = Vector2(8, 45)
	_name.size = Vector2(card.x - 70.0, 16)
	_ammo.position = Vector2(card.x - 74.0, 40.0)
	_ammo.size = Vector2(66.0, 24.0)
	# uitgeklapt: de andere wapens in een rij boven de kaart
	var lw := 74.0
	for i in _list.size():
		_list[i].size = Vector2(lw, 54.0)
		_list[i].position = Vector2(x + i * (lw + 3.0), y0 - 54.0 - 6.0)
		_list_pics[i].position = Vector2(3, 3)
		_list_pics[i].size = Vector2(lw - 6.0, 32.0)
		_list_names[i].position = Vector2(0, 37)
		_list_names[i].size = Vector2(lw, 14)


func _owned_ids() -> Array:
	var out := []
	for id in IDS:
		if Game.carries(id):
			out.append(id)
	return out


func _ready_to_switch() -> bool:
	return Game.state == "play" or Game.state == "prep"


func _toggle_list() -> void:
	if not _ready_to_switch():
		return
	_open_t = 0.0 if _open_t > 0.0 else OPEN_TIME
	_last_state = ""
	_refresh()


## ◀ ▶: het vorige of volgende wapen dat je hebt.
func _cycle(dir: int) -> void:
	if not _ready_to_switch():
		return
	var ids := _owned_ids()
	if ids.size() < 2:
		return
	var i := ids.find(Game.cur)
	_set_weapon(ids[posmod(i + dir, ids.size())])


func _select(index: int) -> void:
	if not _ready_to_switch():
		return
	var id: String = IDS[index]
	if not Game.carries(id):
		return
	_set_weapon(id)
	_open_t = 0.0


func _set_weapon(id: String) -> void:
	if id == Game.cur:
		return
	Game.cur = id
	Game.changed.emit()
	_last_state = ""
	_refresh()


func _process(delta: float) -> void:
	visible = (Game.state == "play" or Game.state == "prep") and not Game.build_mode
	if not visible:
		return
	if _open_t > 0.0:
		_open_t -= delta
		if _open_t <= 0.0:
			_last_state = ""
	_refresh()


func _style(active: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.17, 0.13, 0.92) if active else Color(0.035, 0.06, 0.05, 0.79)
	sb.border_color = Color(1, 0.73, 0.32) if active else Color(0.35, 0.45, 0.35, 0.45)
	sb.set_border_width_all(2 if active else 1)
	sb.set_corner_radius_all(5)
	return sb


func _skin(b: Button, active: bool) -> void:
	var sb := _style(active)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, sb)


func _refresh() -> void:
	var fingerprint := Game.cur + "|" + str(_open_t > 0.0) + "|" + str(_icons.size())
	for id in IDS:
		fingerprint += id + ("+" if Game.carries(id) else "-")
	if Game.player != null:
		fingerprint += ":" + str(Game.player.weapon) + ":" + str(Game.player.ammo) + ":" + str(Game.player.reload_t > 0.0)
	if fingerprint == _last_state:
		return
	_last_state = fingerprint
	var cur: String = Game.cur
	var gold := Color(1.0, 0.88, 0.63)
	_skin(_card, true)
	_skin(_prev, false)
	_skin(_next, false)
	var multi := _owned_ids().size() > 1
	_prev.disabled = not multi
	_next.disabled = not multi
	for g in [_prev_glyph, _next_glyph]:
		g.modulate = gold if multi else Color(0.45, 0.47, 0.45, 0.6)
	_pic.texture = _icons.get(cur)
	_name.text = str(Data.WEAPONS[cur].short)
	_name.add_theme_color_override("font_color", gold)
	# munitie alleen van het wapen in je hand
	var live: bool = Game.player != null
	var ammo := str(Game.owned[cur].ammo) if Game.owned.has(cur) else "--"
	var empty := false
	if live:
		if Game.player.weapon == cur:
			ammo = str(Game.player.ammo)
		empty = Game.player.reload_t <= 0.0 and Game.player.ammo <= int(Game.wstat(cur).mag * 0.25)
		if Game.player.reload_t > 0.0:
			ammo = "…"
	_ammo.text = ammo
	_ammo.add_theme_color_override("font_color", Color8(255, 90, 58) if empty else gold)
	var open := _open_t > 0.0
	for i in IDS.size():
		var id: String = IDS[i]
		var shown := open and Game.carries(id) and id != cur
		_list[i].visible = shown
		if not shown:
			continue
		_skin(_list[i], false)
		_list_pics[i].texture = _icons.get(id)
		_list_names[i].text = str(Data.WEAPONS[id].short).substr(0, 9)
		_list_names[i].add_theme_color_override("font_color", Color(0.79, 0.84, 0.78))
