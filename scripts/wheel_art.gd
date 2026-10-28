class_name WheelArt
extends RefCounted
## HUD 3.0-wiel: vier segmenten rond een centrumknop (×), elk met een pictogram en een naam. Gebruikt door het
## commando-wiel (TeamCommands) en het steun- en uitrustingswiel (CombatButtons).

const OUTER := 104.0
const INNER := 30.0
const GAP := 0.045
const DARK := Color(0.05, 0.06, 0.04, 0.9)


## items: [{"label", "icon", "active", "current"}] met item i op first_angle + i * 90° (0 = rechts, -90° = boven).
## selected: sector die de vinger nu aanwijst (-1 = geen).
static func draw(ci: CanvasItem, center: Vector2, items: Array, first_angle: float, selected: int) -> void:
	ci.draw_circle(center, OUTER + 4.0, Color(0.0, 0.0, 0.0, 0.42))
	for i in items.size():
		var a := first_angle + float(i) * TAU / 4.0
		var it: Dictionary = items[i]
		var active: bool = it.get("active", true)
		var current: bool = it.get("current", false)
		var hot := i == selected
		var fill := Color(0.02, 0.03, 0.025, 0.86)
		if hot:
			fill = Color(0.2, 0.155, 0.055, 0.98)
		elif current:
			fill = Color(0.12, 0.095, 0.035, 0.96)
		var poly := _segment(center, a)
		ci.draw_colored_polygon(poly, fill)
		var edge := Color(UI.BRASS, 0.95 if hot or current else (0.62 if active else 0.28))
		ci.draw_polyline(poly + PackedVector2Array([poly[0]]), edge, 2.2 if hot or current else 1.6, true)
		var mid := center + Vector2(cos(a), sin(a)) * (OUTER + INNER) * 0.5
		var col := UI.BRASS if active else Color(UI.INK_DIM, 0.62)
		icon(ci, String(it.get("icon", "")), mid + Vector2(0, -9), col)
		var f: Font = UI.body(700)
		var text: String = it.get("label", "")
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		ci.draw_string(f, mid + Vector2(-tw * 0.5, 22), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI.INK if active else Color(UI.INK_DIM, 0.8))
	ci.draw_circle(center, INNER - 4.0, Color(0.02, 0.03, 0.025, 0.98))
	ci.draw_arc(center, INNER - 4.0, 0.0, TAU, 28, Color(UI.BRASS, 0.9), 1.8, true)
	ci.draw_line(center + Vector2(-6, -6), center + Vector2(6, 6), UI.INK, 2.2, true)
	ci.draw_line(center + Vector2(-6, 6), center + Vector2(6, -6), UI.INK, 2.2, true)


static func _segment(center: Vector2, a: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var half := PI / 4.0 - GAP
	var steps := 14
	for s in steps + 1:
		var t := a - half + 2.0 * half * float(s) / float(steps)
		pts.append(center + Vector2(cos(t), sin(t)) * OUTER)
	for s in steps + 1:
		var t := a + half - 2.0 * half * float(s) / float(steps)
		pts.append(center + Vector2(cos(t), sin(t)) * (INNER + 4.0))
	return pts


## Pictogrammen van de wielen, ongeveer 28 px groot, midden in c.
static func icon(ci: CanvasItem, kind: String, c: Vector2, col: Color) -> void:
	match kind:
		"volgen":
			for i in 3:
				var hc := c + Vector2(-10 + i * 10, 2 - (4 if i == 1 else 0))
				ci.draw_arc(hc, 5.5, PI, TAU, 10, col, 2.4)
				ci.draw_line(hc + Vector2(-7.5, 0), hc + Vector2(7.5, 0), col, 2.0)
			ci.draw_line(c + Vector2(-14, 9), c + Vector2(14, 9), col, 2.0)
		"verdedigen":
			var shield := PackedVector2Array([c + Vector2(-10, -12), c + Vector2(10, -12), c + Vector2(10, 1), c + Vector2(0, 13), c + Vector2(-10, 1), c + Vector2(-10, -12)])
			ci.draw_polyline(shield, col, 2.6, true)
			ci.draw_line(c + Vector2(0, -12), c + Vector2(0, 12), col, 1.8)
		"aanvallen":
			ci.draw_arc(c, 9.0, 0.0, TAU, 20, col, 2.4, true)
			for d in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
				ci.draw_line(c + d * 5.0, c + d * 14.0, col, 2.4)
			ci.draw_circle(c, 1.8, col)
		"verplaatsen":
			ci.draw_line(c + Vector2(-8, -13), c + Vector2(-8, 13), col, 2.6)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-8, -13), c + Vector2(11, -8), c + Vector2(-8, -2)]), col)
		"truck", "napalm":
			Streak.draw_icon(ci, kind, c, 1.0, col)
		"luchtaanval":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -14), c + Vector2(3, -5), c + Vector2(14, 4), c + Vector2(14, 7), c + Vector2(3, 3), c + Vector2(2, 10),
				c + Vector2(7, 13), c + Vector2(7, 15), c + Vector2(0, 13), c + Vector2(-7, 15), c + Vector2(-7, 13), c + Vector2(-2, 10), c + Vector2(-3, 3), c + Vector2(-14, 7),
				c + Vector2(-14, 4), c + Vector2(-3, -5)]), col)
		"versterking":
			ci.draw_arc(c + Vector2(0, -3), 12.0, PI, TAU, 14, col, 3.0, true)
			ci.draw_line(c + Vector2(-12, -3), c + Vector2(-2, 9), col, 1.6)
			ci.draw_line(c + Vector2(12, -3), c + Vector2(2, 9), col, 1.6)
			ci.draw_line(c + Vector2(0, -3), c + Vector2(0, 9), col, 1.6)
			ci.draw_rect(Rect2(c + Vector2(-3, 9), Vector2(6, 5)), col)
		"granaat":
			ci.draw_circle(c + Vector2(0, 3), 10.0, col)
			ci.draw_rect(Rect2(c + Vector2(-3, -12), Vector2(6, 6)), col)
			ci.draw_line(c + Vector2(2, -11), c + Vector2(10, -14), col, 2.4)
			ci.draw_arc(c + Vector2(0, 3), 6.0, 2.4, 3.9, 6, DARK, 2.0)
		"mijn":
			ci.draw_circle(c + Vector2(0, 3), 11.0, col)
			ci.draw_arc(c + Vector2(0, 3), 11.0, 0, TAU, 20, DARK, 2.0)
			ci.draw_circle(c + Vector2(0, 3), 3.5, DARK)
		"c4":
			ci.draw_rect(Rect2(c + Vector2(-10, -8), Vector2(20, 20)), col, false, 2.0)
			ci.draw_line(c + Vector2(-7, -11), c + Vector2(7, -11), col, 2.0)
			ci.draw_line(c + Vector2(-6, -11), c + Vector2(-6, -7), col, 2.0)
			ci.draw_line(c + Vector2(6, -11), c + Vector2(6, -7), col, 2.0)
		"rook":
			ci.draw_circle(c + Vector2(-7, 2), 6.0, col)
			ci.draw_circle(c + Vector2(3, -2), 8.0, col)
			ci.draw_circle(c + Vector2(10, 4), 5.0, col)
			ci.draw_rect(Rect2(c + Vector2(-11, 3), Vector2(25, 6)), col)
