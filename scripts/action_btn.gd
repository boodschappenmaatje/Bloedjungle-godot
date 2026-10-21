class_name ActionBtn
extends Button
## Kleine ronde actieknop met een getekend icoon en een bijschrift (poort, repareer, in/uitstappen).
## Vaste plekken (slot 0..2) naast elkaar onderin, zodat knoppen elkaar nooit overlappen.

const SIZE := Vector2(54, 54)
const GAP := 62.0

var kind := ""
var caption := ""
var bar := -1.0  # 0..1 toont een smalle sterktebalk onder de knop, -1 verbergt hem
var open_state := false


static func slot_x(i: int) -> float:
	return (i - 1) * GAP - SIZE.x * 0.5  # relatief aan het midden van het scherm


static func make(k: String, cap: String) -> ActionBtn:
	var b := ActionBtn.new()
	b.kind = k
	b.caption = cap
	b.add_to_group("hud_button")
	b.custom_minimum_size = SIZE
	b.size = SIZE
	UI.style_button(b, "round")
	b.text = ""
	b.visible = false
	return b


func place(i: int, parent_size: Vector2) -> void:
	size = SIZE
	position = Vector2(parent_size.x * 0.5 + slot_x(i), parent_size.y - 126.0)


func set_caption(c: String) -> void:
	if c != caption:
		caption = c
		queue_redraw()


func _draw() -> void:
	var col: Color = UI.BRASS
	var c := Vector2(size.x * 0.5, 21.0)
	var w := 2.6
	match kind:
		"poort":
			draw_rect(Rect2(c + Vector2(-15, -11), Vector2(4, 22)), col)
			draw_rect(Rect2(c + Vector2(11, -11), Vector2(4, 22)), col)
			if open_state:
				for y in [-5.0, 2.0, 9.0]:
					draw_line(c + Vector2(6, y), c + Vector2(10, y), col, w)
			else:
				for y in [-5.0, 2.0, 9.0]:
					draw_line(c + Vector2(-11, y), c + Vector2(11, y), col, w)
		"brug":
			draw_rect(Rect2(c + Vector2(-15, -3), Vector2(4, 14)), col)
			draw_rect(Rect2(c + Vector2(11, -3), Vector2(4, 14)), col)
			if open_state:  # klep omhoog
				draw_line(c + Vector2(-11, 9), c + Vector2(-9, -13), col, 3.5)
			else:
				draw_line(c + Vector2(-11, 6), c + Vector2(11, 6), col, 3.5)
			draw_line(c + Vector2(-15, 11), c + Vector2(15, 11), col, 2.0)
		"repair":
			draw_line(c + Vector2(-9, 10), c + Vector2(6, -5), col, 4.0)
			draw_circle(c + Vector2(8, -8), 6.5, col)
			draw_circle(c + Vector2(11, -11), 3.0, Color(0.05, 0.06, 0.04, 0.9))
		"troepen":
			# drie helmpjes naast elkaar
			for i in 3:
				var hc := c + Vector2(-10 + i * 10, 2 - (4 if i == 1 else 0))
				draw_arc(hc, 5.5, PI, TAU, 10, col, 2.4)
				draw_line(hc + Vector2(-7.5, 0), hc + Vector2(7.5, 0), col, 2.0)
			draw_line(c + Vector2(-14, 9), c + Vector2(14, 9), col, 2.0)
		"zeil":
			# laadbak met zeil: dicht = boog vol, open = alleen spanten
			draw_rect(Rect2(c + Vector2(-15, 4), Vector2(30, 7)), col, false, 2.2)
			if open_state:
				draw_arc(c + Vector2(0, 4), 13.0, PI, TAU, 14, col, 4.0)
			else:
				for x in [-10.0, 0.0, 10.0]:
					draw_line(c + Vector2(x, 4), c + Vector2(x, -7), col, 1.6)
				draw_circle(c + Vector2(0, -10), 3.5, col)
		"exit", "enter":
			draw_rect(Rect2(c + Vector2(-13, -11), Vector2(13, 22)), col, false, 2.2)
			var d := 1.0 if kind == "exit" else -1.0
			draw_line(c + Vector2(-4, 0), c + Vector2(13, 0), col, w)
			draw_line(c + Vector2(13, 0) - Vector2(5 * d, 5), c + Vector2(13, 0), col, w)
			draw_line(c + Vector2(13, 0) - Vector2(5 * d, -5), c + Vector2(13, 0), col, w)
	var f: Font = UI.body(700, 1)
	var fs := 10
	while fs > 6 and f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - 16.0:
		fs -= 1
	var tw := f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, Vector2((size.x - tw) * 0.5, size.y - 7.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.INK)
	if bar >= 0.0:
		draw_rect(Rect2(6, size.y + 4, size.x - 12, 4), Color(0, 0, 0, 0.6))
		var fill := UI.OLIVE_HI if bar > 0.4 else UI.BLOOD_HI
		draw_rect(Rect2(6, size.y + 4, (size.x - 12) * clampf(bar, 0.0, 1.0), 4), fill)
