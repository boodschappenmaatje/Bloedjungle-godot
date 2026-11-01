class_name RijSlot
extends Button
## Eén vakje van de bouwrij in het kazernepaneel: soldaatsilhouet, gouden rand als er een soldaat in de rij staat,
## voortgangsring op het eerste vakje en een slotje boven je limiet.

const GOLD := Color(0.82, 0.68, 0.24)
const OLIVE := Color(0.45, 0.52, 0.27)
const DIM := Color(0.55, 0.58, 0.5, 0.35)
const LOCK := Color(0.7, 0.7, 0.65, 0.55)

var index := 0
var locked := false
var filled := false
var b: Dictionary = {}
var time := 10.0
var glyph := "soldier"


func setup(i: int, building: Dictionary, is_locked: bool, train_time: float, item_icon := "soldier", is_filled := false) -> void:
	time = train_time
	glyph = item_icon
	index = i
	b = building
	locked = is_locked
	filled = is_filled if glyph != "soldier" else i < int(b.queue)
	disabled = not filled
	custom_minimum_size = Vector2(40, 40)
	focus_mode = Control.FOCUS_NONE
	add_to_group("hud_button")
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.45)
	sb.border_color = GOLD if filled else Color(0.45, 0.45, 0.4, 0.5)
	sb.set_border_width_all(2 if filled else 1)
	sb.set_corner_radius_all(5)
	for n in ["normal", "disabled", "hover", "focus"]:
		add_theme_stylebox_override(n, sb)
	var sp := sb.duplicate() as StyleBoxFlat
	sp.bg_color = Color(0.25, 0.2, 0.05, 0.7)
	add_theme_stylebox_override("pressed", sp)
	pressed.connect(func():
		var sfx := get_node_or_null("/root/Sfx")
		if sfx != null:
			sfx.play("click"))
	set_process(filled and index == 0 and glyph == "soldier")


func _process(_d: float) -> void:
	queue_redraw()


func _progress() -> float:
	if index != 0 or not filled or b.is_empty():
		return 0.0
	return 1.0 - clampf(float(b.train_t) / maxf(0.1, time), 0.0, 1.0)


func _draw() -> void:
	var c := size * 0.5
	if locked:
		var w := 14.0
		var bx := Rect2(c.x - w * 0.5, c.y - 1.0, w, 11.0)
		draw_rect(bx, LOCK)
		draw_arc(Vector2(c.x, c.y - 1.0), 4.5, PI, TAU, 12, LOCK, 2.0)
		return
	var col := OLIVE if filled else DIM
	match glyph:
		"leeg":
			pass
		"jeep":
			draw_rect(Rect2(c.x - 11.0, c.y - 3.0, 22.0, 8.0), col)
			draw_rect(Rect2(c.x - 4.0, c.y - 9.0, 9.0, 6.0), col.darkened(0.2))
			draw_circle(c + Vector2(-7, 7), 3.0, col.darkened(0.45))
			draw_circle(c + Vector2(7, 7), 3.0, col.darkened(0.45))
		"tank":
			draw_rect(Rect2(c.x - 12.0, c.y, 24.0, 8.0), col)
			draw_rect(Rect2(c.x - 6.0, c.y - 7.0, 12.0, 7.0), col.darkened(0.2))
			draw_rect(Rect2(c.x + 5.0, c.y - 5.0, 9.0, 2.5), col.darkened(0.2))
		"truck":
			draw_rect(Rect2(c.x - 12.0, c.y - 8.0, 16.0, 13.0), col)
			draw_rect(Rect2(c.x + 5.0, c.y - 4.0, 8.0, 9.0), col.darkened(0.2))
			draw_circle(c + Vector2(-6, 7), 3.0, col.darkened(0.45))
			draw_circle(c + Vector2(8, 7), 3.0, col.darkened(0.45))
		_:
			# soldaat: hoofd met helm en schouders
			draw_circle(c + Vector2(0, -6), 5.0, col)
			draw_rect(Rect2(c.x - 6.0, c.y - 11.0, 12.0, 4.0), col.darkened(0.2))
			draw_rect(Rect2(c.x - 9.0, c.y + 1.0, 18.0, 10.0), col)
	if filled and index == 0 and glyph == "soldier":
		var p := _progress()
		draw_arc(c, size.x * 0.5 - 3.0, -PI * 0.5, -PI * 0.5 + TAU * maxf(p, 0.02), 32, GOLD, 3.0)
