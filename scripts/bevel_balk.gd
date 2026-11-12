class_name BevelBalk
extends RefCounted
## De bevelbalk (keuze 8A): zes knoppen VERPLAATS, AANVAL, VERDEDIG, HOUD, BEWAAK en VOLG MIJ.
## Gedeeld door de bevelstand in het spel (BevelStand) en de grote kaart (GroteKaart): alleen tekenen en raken, de bevelen zelf
## staan in TroepSelectie.


## Zes knoppen naast elkaar in `area`.
static func rects(area: Rect2, gap := 5.0) -> Array:
	var n := TroepSelectie.ORDERS.size()
	var w := (area.size.x - gap * float(n - 1)) / float(n)
	var out: Array = []
	for i in n:
		out.append(Rect2(area.position + Vector2(float(i) * (w + gap), 0.0), Vector2(w, area.size.y)))
	return out


## Zes knoppen onder elkaar in `area` (liggende grote kaart: rechts naast de kaart).
static func rects_v(area: Rect2, gap := 6.0, max_h := 44.0) -> Array:
	var n := TroepSelectie.ORDERS.size()
	var h := minf((area.size.y - gap * float(n - 1)) / float(n), max_h)
	var out: Array = []
	for i in n:
		out.append(Rect2(area.position + Vector2(0.0, float(i) * (h + gap)), Vector2(area.size.x, h)))
	return out


static func hit(rs: Array, pos: Vector2) -> int:
	for i in rs.size():
		if (rs[i] as Rect2).grow(3.0).has_point(pos):
			return i
	return -1


## `armed`: het bevel dat op een tik wacht (oplichtend). `enabled`: er is iemand gekozen.
static func draw(cv: CanvasItem, rs: Array, armed: String, enabled: bool) -> void:
	var font := UI.body(700, 1)
	for i in rs.size():
		var order: String = TroepSelectie.ORDERS[i]
		var r: Rect2 = rs[i]
		var col := TroepSelectie.order_color(order)
		var on: bool = enabled and order == armed and not order in TroepSelectie.DIRECT
		var bg := Color(col.r * 0.22, col.g * 0.22, col.b * 0.16, 0.95) if on else Color(0.03, 0.045, 0.03, 0.9 if enabled else 0.7)
		cv.draw_style_box(UI.box(bg, Color(col, 0.95 if on else (0.45 if enabled else 0.18)), 2 if on else 1, 6, 0), r)
		var a := 1.0 if enabled else 0.4
		var txt := Color(UI.INK, a) if not on else Color(1, 1, 1, 1)
		if r.size.x > r.size.y * 3.0:
			# breed en laag (rechterkolom van de kaart): pictogram links, tekst ernaast
			_glyph(cv, order, Vector2(r.position.x + 20.0, r.position.y + r.size.y * 0.5), minf(r.size.y * 0.22, 7.0), Color(col, a))
			cv.draw_string(font, Vector2(r.position.x + 38.0, r.position.y + r.size.y * 0.5 + 5.0), String(TroepSelectie.LABELS[order]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 42.0, 13, txt)
		else:
			_glyph(cv, order, Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.36), minf(r.size.y * 0.2, 7.0), Color(col, a))
			var fs := 10 if r.size.x >= 64.0 else 9
			cv.draw_string(font, Vector2(r.position.x, r.end.y - 6.0), String(TroepSelectie.LABELS[order]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, txt)


## Klein pictogram per bevel: vlag, vizier, schild, hand, oog-schild en pijl naar jou.
static func _glyph(cv: CanvasItem, order: String, c: Vector2, s: float, col: Color) -> void:
	match order:
		"move":
			cv.draw_line(c + Vector2(-s * 0.6, s), c + Vector2(-s * 0.6, -s), col, 1.6)
			cv.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.6, -s), c + Vector2(s, -s * 0.45), c + Vector2(-s * 0.6, s * 0.1)]), col)
		"attack":
			cv.draw_arc(c, s * 0.8, 0.0, TAU, 16, col, 1.5, true)
			for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				cv.draw_line(c + d * s * 0.45, c + d * s * 1.2, col, 1.5)
		"defend", "bewaak":
			var sh := PackedVector2Array([c + Vector2(-s * 0.85, -s), c + Vector2(s * 0.85, -s), c + Vector2(s * 0.85, 0.0), c + Vector2(0.0, s * 1.1), c + Vector2(-s * 0.85, 0.0)])
			if order == "defend":
				cv.draw_colored_polygon(sh, col)
			else:
				sh.append(sh[0])
				cv.draw_polyline(sh, col, 1.5, true)
				cv.draw_circle(c + Vector2(0.0, -s * 0.15), s * 0.3, col)
		"hold":
			cv.draw_rect(Rect2(c - Vector2(s * 0.75, s * 0.75), Vector2(s * 1.5, s * 1.5)), col, false, 1.6)
			cv.draw_line(c + Vector2(-s * 0.3, -s * 0.3), c + Vector2(s * 0.3, s * 0.3), col, 1.6)
			cv.draw_line(c + Vector2(s * 0.3, -s * 0.3), c + Vector2(-s * 0.3, s * 0.3), col, 1.6)
		"follow":
			cv.draw_circle(c + Vector2(s * 0.45, -s * 0.55), s * 0.38, col)
			cv.draw_line(c + Vector2(-s, s * 0.6), c + Vector2(s * 0.2, s * 0.6), col, 1.6)
			cv.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.75, s * 0.6), c + Vector2(s * 0.1, s * 0.15), c + Vector2(s * 0.1, s * 1.05)]), col)
