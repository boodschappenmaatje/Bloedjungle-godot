class_name RangHud
extends Control
## De rang in beeld: vijf sterren, de naam van je rang en een dunne balk naar de volgende ster (Rang.voortgang). Een gouden "+N" toont dat je
## nog punten hebt om uit te geven (KIES-knop). Bij een bevordering veert het plaatje even op. Klein en rustig, zoals de rest van de HUD.

const W := 158.0
const H := 30.0

var _last_rang := 0
var _pop := 0.0
var _key := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	pivot_offset = Vector2(14, H * 0.5)


func _process(delta: float) -> void:
	var active := (Game.state == "play" or Game.state == "prep") and not Game.build_mode and not Game.editing
	visible = active
	if not active:
		return
	if Game.rang != _last_rang:
		if Game.rang > _last_rang:
			_pop = 1.0
		_last_rang = Game.rang
	_pop = maxf(0.0, _pop - delta * 2.5)
	scale = Vector2.ONE * (1.0 + 0.18 * _pop)
	var k := "%d|%d|%d" % [Game.score, Game.rang, Game.rang_punten]
	if k != _key or _pop > 0.0 or Game.rang_punten > 0:   # met een punt over pulseert het plusje
		_key = k
		queue_redraw()


func _draw() -> void:
	draw_style_box(UI.box(Color(0.025, 0.045, 0.035, 0.82), Color(UI.PANEL_LINE, 0.75), 1, 6, 0), Rect2(Vector2.ZERO, size))
	for i in 5:
		var c := Vector2(13.0 + float(i) * 15.0, 11.5)
		var vol: bool = i < Game.rang
		draw_colored_polygon(Rang.ster_punten(c, 6.6, 2.9), UI.BRASS if vol else Color(UI.INK_DIM, 0.32))
	draw_string(UI.body(700, 0), Vector2(13.0 + 5.0 * 15.0 + 1.0, 15.0), Rang.naam(Game.rang), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI.INK)
	var vg: Dictionary = Rang.voortgang()
	var bar := Rect2(7.0, H - 9.0, W - 14.0, 3.0)
	draw_rect(bar, Color(0, 0, 0, 0.6))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(vg.done) / float(vg.span), bar.size.y)), UI.BRASS if vg.volgende >= 0 else UI.OLIVE_HI)
	if Game.rang_punten > 0:
		var f: Font = UI.body(700, 1)
		var txt := "+%d" % Game.rang_punten
		var bw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 10.0
		var br := Rect2(W - bw + 3.0, -5.0, bw, 16.0)
		var pulse := 0.65 + 0.35 * sin(Time.get_ticks_msec() / 220.0)
		draw_rect(br, Color(0.02, 0.03, 0.025, 0.92))
		draw_rect(br, Color(UI.BRASS, pulse), false, 1.4)
		draw_string(f, br.position + Vector2(5, 12), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.BRASS)
