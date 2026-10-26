class_name ActionBtn
extends Button
## Kleine ronde actieknop met een getekend icoon en een bijschrift (poort, repareer, in/uitstappen).
## Vaste plekken (slot 0..2) naast elkaar onderin, zodat knoppen elkaar nooit overlappen.

const SIZE := Vector2(54, 54)
const GAP := 62.0

var kind := ""
var caption := ""
var equipment_kind := "grenade"
var reward := ""   # luchtsteun-knop: id van de beloning die klaarstaat (Streak.LADDER)
var bar := -1.0  # 0..1 toont een smalle sterktebalk onder de knop, -1 verbergt hem
var open_state := false
var badge := ""  # klein getal rechtsboven, bijv. "×3"


static func slot_x(i: int) -> float:
	return (i - 1) * GAP - SIZE.x * 0.5  # relatief aan het midden van het scherm


static func make(k: String, cap: String) -> ActionBtn:
	var b := ActionBtn.new()
	b.kind = k
	b.caption = cap
	b.tooltip_text = {
		"granaat": "Granaat gooien",
		"herlaad": "Actief wapen herladen",
		"sprint": "Sprinten · balk toont uithoudingsvermogen",
		"rol": "Ontwijkrol · afkoeling wordt rond de knop getoond",
		"lucht": "Luchtsteun · tik om te gebruiken, napalm: vasthouden en slepen om de strook te richten",
	}.get(k, cap)
	b.add_to_group("hud_button")
	b.custom_minimum_size = SIZE
	b.size = SIZE
	UI.style_button(b, "round")
	var idle := UI.box(Color(0.025, 0.04, 0.035, 0.84), Color(UI.BRASS, 0.28), 1, 30, 0)
	var pressed := UI.box(Color(0.17, 0.14, 0.065, 0.94), Color(UI.BRASS, 0.72), 1, 30, 0)
	var disabled := UI.box(Color(0.02, 0.03, 0.025, 0.56), Color(UI.INK_DIM, 0.16), 1, 30, 0)
	for state in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(state, idle)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.text = ""
	b.visible = false
	return b


func place(i: int, parent_size: Vector2) -> void:
	size = SIZE
	var safe := UI.safe_margins(parent_size)
	var y := parent_size.y - 126.0 - maxf(0.0, safe.w - 12.0)
	if parent_size.x >= parent_size.y:
		# In landschap staat de wapenbalk midden onderin; contextacties komen er net onder.
		var weapon_y := parent_size.y - 140.0 - maxf(0.0, safe.w - 12.0)
		y = weapon_y + 64.0 + 8.0
	position = Vector2(parent_size.x * 0.5 + slot_x(i), y)


func set_caption(c: String) -> void:
	if c != caption:
		caption = c
		queue_redraw()


func _draw() -> void:
	var col: Color = Color(UI.BRASS, 0.42) if disabled else UI.BRASS
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
		"herlaad":
			# kogel met een ronde pijl eromheen
			draw_arc(c, 12.0, -0.6, TAU - 1.2, 18, col, w)
			draw_colored_polygon(PackedVector2Array([c + Vector2(9.5, -12.5), c + Vector2(15.5, -4.5), c + Vector2(6.0, -5.0)]), col)
			draw_rect(Rect2(c + Vector2(-2.5, -4), Vector2(5, 9)), col)
			draw_circle(c + Vector2(0, -4), 2.5, col)
		"sprint":
			# twee pijlpunten achter elkaar
			for i in 2:
				var o := Vector2(-6.0 + i * 11.0, 0)
				draw_polyline(PackedVector2Array([c + o + Vector2(-5, -10), c + o + Vector2(5, 0), c + o + Vector2(-5, 10)]), col, 3.4)
		"rol":
			# gebogen pijl: een koprol
			draw_arc(c, 11.0, PI * 0.15, PI * 1.75, 16, col, w)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-13, 2), c + Vector2(-5, 3), c + Vector2(-9, 11)]), col)
		"lucht":
			Streak.draw_icon(self, reward, c + Vector2(0, 1), 1.0, col)
			if not disabled:
				var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 260.0)
				draw_arc(size * 0.5, size.x * 0.5 - 1.5, 0, TAU, 32, Color(UI.BRASS, 0.35 + 0.65 * pulse), 2.6, true)
		"granaat":
			match equipment_kind:
				"mine":
					draw_circle(c + Vector2(0, 3), 11.0, col)
					draw_arc(c + Vector2(0, 3), 11.0, 0, TAU, 20, Color(0.05, 0.06, 0.04, 0.8), 2.0)
					draw_circle(c + Vector2(0, 3), 3.5, Color(0.05, 0.06, 0.04, 0.9))
				"c4":
					draw_rect(Rect2(c + Vector2(-10, -8), Vector2(20, 20)), col, false, 2.0)
					draw_line(c + Vector2(-7, -11), c + Vector2(7, -11), col, 2.0)
					draw_line(c + Vector2(-6, -11), c + Vector2(-6, -7), col, 2.0)
					draw_line(c + Vector2(6, -11), c + Vector2(6, -7), col, 2.0)
				_:
					draw_circle(c + Vector2(0, 3), 10.0, col)
					draw_rect(Rect2(c + Vector2(-3, -12), Vector2(6, 6)), col)
					draw_line(c + Vector2(2, -11), c + Vector2(10, -14), col, 2.4)
					draw_arc(c + Vector2(0, 3), 6.0, 2.4, 3.9, 6, Color(0.05, 0.06, 0.04, 0.8), 2.0)
	if kind in ["sprint"] and open_state:
		draw_arc(size * 0.5, size.x * 0.5 - 2.0, 0, TAU, 28, UI.BRASS, 2.4)  # staat aan
	if kind == "rol" and bar >= 0.0:
		var ring_center := Vector2(size.x * 0.5, size.y * 0.5)
		var radius := size.x * 0.5 - 2.0
		draw_arc(ring_center, radius, 0, TAU, 36, Color(UI.INK_DIM, 0.45), 2.2, true)
		if bar > 0.001:
			draw_arc(ring_center, radius, -PI * 0.5, -PI * 0.5 + TAU * clampf(bar, 0.0, 1.0), 36, UI.BRASS, 2.8, true)
	var f: Font = UI.body(700, 1)
	var fs := 10
	while fs > 6 and f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - 16.0:
		fs -= 1
	var tw := f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, Vector2((size.x - tw) * 0.5, size.y - 7.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.INK)
	if badge != "":
		var bw := f.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 8.0
		var br := Rect2(size.x - bw + 2.0, -2.0, bw, 16.0)
		draw_rect(br, Color(0, 0, 0, 0.75))
		draw_string(f, br.position + Vector2(4, 12), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.BRASS)
	if bar >= 0.0:
		draw_rect(Rect2(6, size.y + 4, size.x - 12, 4), Color(0, 0, 0, 0.6))
		var fill := UI.OLIVE_HI if bar > 0.4 else UI.BLOOD_HI
		draw_rect(Rect2(6, size.y + 4, (size.x - 12) * clampf(bar, 0.0, 1.0), 4), fill)
