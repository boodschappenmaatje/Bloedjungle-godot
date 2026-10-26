class_name StreakHud
extends Control
## De killstreak-teller: een klein metalen naamplaatje (dogtag) met het aantal kills, stipjes tot de volgende beloning en het
## pictogram daarvan. Alleen te zien tot FADE_AFTER seconden na je laatste kill, daarna vervaagt hij en is het scherm weer rustig.

const W := 84.0
const H := 24.0

var _shown := 0.0     # 0..1 zichtbaarheid
var _pop := 0.0       # korte opveer bij een nieuwe kill
var _last_streak := 0
var _age := 99.0      # s sinds de laatste streak-kill (speeltijd, niet de klok)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	pivot_offset = Vector2(14, H * 0.5)


func _process(delta: float) -> void:
	var active := (Game.state == "play" or Game.state == "prep") and not Game.build_mode and not Game.editing and Game.streak > 0
	_age += delta
	var want := 1.0 if active and _age < Streak.FADE_AFTER else 0.0
	_shown = move_toward(_shown, want, delta * (6.0 if want > _shown else 1.6))
	if Game.streak != _last_streak:
		if Game.streak > _last_streak:
			_pop = 1.0
			_age = 0.0
		_last_streak = Game.streak
	_pop = maxf(0.0, _pop - delta * 5.0)
	visible = _shown > 0.01
	if visible:
		modulate.a = _shown
		scale = Vector2.ONE * (1.0 + 0.16 * _pop)
		queue_redraw()


func _draw() -> void:
	var metal := Color(0.74, 0.72, 0.64)
	var edge := Color(0.30, 0.29, 0.25)
	var ink := Color(0.10, 0.10, 0.08)
	# plaatje met afgeronde linkerkant en een gaatje voor het kettinkje
	var pts := PackedVector2Array([Vector2(H * 0.5, 0), Vector2(W - 4, 0), Vector2(W, 4), Vector2(W, H - 4), Vector2(W - 4, H), Vector2(H * 0.5, H)])
	for i in 7:
		var a := PI * 0.5 + PI * float(i) / 6.0
		pts.append(Vector2(H * 0.5 + cos(a) * H * 0.5, H * 0.5 + sin(a) * H * 0.5))
	draw_colored_polygon(pts, edge)
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(Vector2(1.5 + (p.x - 1.5) * (W - 3.0) / W, 1.5 + (p.y - 1.5) * (H - 3.0) / H))
	draw_colored_polygon(inner, metal)
	draw_circle(Vector2(8, H * 0.5), 2.0, edge)
	var f: Font = UI.display(1)
	draw_string(f, Vector2(15, H * 0.5 + 6.5), str(Game.streak), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, ink)
	# stipjes: hoever naar de volgende beloning
	var pr := Streak.progress()
	var n := mini(int(pr.span), 8)
	var done := roundi(float(pr.done) * n / float(pr.span))
	var nx := Streak.next_reward()
	var x0 := 15.0 + f.get_string_size(str(Game.streak), HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x + 5.0
	var step := 4.6
	for i in n:
		var c := Vector2(x0 + i * step, H * 0.5 + 0.5)
		draw_circle(c, 1.7, ink if i < done else Color(0, 0, 0, 0.18))
		if i >= done:
			draw_arc(c, 1.7, 0, TAU, 8, Color(ink, 0.55), 0.8)
	if not nx.is_empty():
		Streak.draw_icon(self, nx.id, Vector2(W - 11, H * 0.5), 0.44, ink)
