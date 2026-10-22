class_name PerfMonitor
extends Control
## Prestatiemodus (Instellingen > Prestatiemodus). Laat per beeld zien hoe lang het duurde, met een grafiek van de
## laatste seconden, de zwaarste beelden (pieken) en wat het spel toen aan het doen was. Doel: meten waar haperingen
## vandaan komen, in plaats van het te raden. Uit = doet niets (geen meting, geen kosten).

const SAMPLES := 300  # ~5 seconden bij 60 fps
const SPIKE_MS := 33.4  # een beeld dat langer duurt dan twee beelden bij 60 fps
const GRAPH := Vector2(280, 46)
const LOG_PATH := "user://prestatie.log"
const MAX_LOG_LINES := 300

static var notes: Array = []  # {t, text, n}: wat er net gebeurde (golf begon, vijanden gespawnd, explosie)
static var bullets_live := 0

var frames := PackedFloat32Array()
var spikes: Array = []
var avg := 0.0
var p95 := 0.0
var worst := 0.0
var _last_us := 0
var _stat_t := 0.0
var _text: Label
var _spike_text: Label
var _log_lines := 0
var _gpu_on := false


static func note(text: String) -> void:
	var now := Time.get_ticks_msec()
	if not notes.is_empty() and notes[-1].text == text and now - int(notes[-1].t) < 400:
		notes[-1].n += 1
		notes[-1].t = now
		return
	notes.append({"t": now, "text": text, "n": 1})
	if notes.size() > 40:
		notes.pop_front()


static func enabled() -> bool:
	return GameSettings.get_value("perf") == "on"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	_text = _label(Color(0.85, 1.0, 0.85), 12)
	_spike_text = _label(Color(1.0, 0.85, 0.5), 11)
	resized.connect(_place)
	_place()


func _label(c: Color, size_: int) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size_)
	l.add_theme_color_override("font_color", c)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	add_child(l)
	return l


func _place() -> void:
	var x := size.x * 0.5 - GRAPH.x * 0.5
	_text.position = Vector2(x, 4.0 + GRAPH.y + 4.0)
	_spike_text.position = Vector2(x, 4.0 + GRAPH.y + 4.0 + 62.0)


func _process(_delta: float) -> void:
	var on := enabled()
	visible = on
	if _gpu_on != on:
		_gpu_on = on
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), on)
		if not on:
			frames.clear()
			spikes.clear()
	if not on:
		_last_us = 0
		return
	var now := Time.get_ticks_usec()
	if _last_us > 0:
		record_frame(float(now - _last_us) / 1000.0)
	_last_us = now
	_stat_t -= _delta
	if _stat_t <= 0.0:
		_stat_t = 0.25
		_refresh_text()
		queue_redraw()


## Eén beeld in ms; ook los aan te roepen (tests). Houdt de laatste SAMPLES beelden bij en let op pieken.
func record_frame(ms: float) -> void:
	frames.append(ms)
	if frames.size() > SAMPLES:
		frames.remove_at(0)
	if ms > SPIKE_MS and Time.get_ticks_msec() > maxi(4000, PerfGovernor.grace_until) and Game.state != "menu":
		_add_spike(ms)


func _add_spike(ms: float) -> void:
	var s := {"ms": ms, "state": Game.state, "enemies": Game.enemies.size(), "bullets": bullets_live, "after": "", "ago": 0.0}
	var now := Time.get_ticks_msec()
	for i in range(notes.size() - 1, -1, -1):
		var age := float(now - int(notes[i].t)) / 1000.0
		if age <= 1.5:
			s.after = "%s%s" % [notes[i].text, (" ×%d" % notes[i].n) if int(notes[i].n) > 1 else ""]
			s.ago = age
			break
	spikes.push_front(s)
	if spikes.size() > 8:
		spikes.pop_back()
	_log(s)


func _log(s: Dictionary) -> void:
	if _log_lines >= MAX_LOG_LINES:
		return
	var f := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE if FileAccess.file_exists(LOG_PATH) else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line("%.1f s\t%.1f ms\t%s\tvijanden %d\tkogels %d\t%s (%.1f s eerder)" % [Time.get_ticks_msec() / 1000.0, s.ms, s.state, s.enemies, s.bullets, s.after, s.ago])
	_log_lines += 1


static func stats_of(samples: PackedFloat32Array) -> Dictionary:
	if samples.is_empty():
		return {"avg": 0.0, "p95": 0.0, "worst": 0.0}
	var sorted := samples.duplicate()
	sorted.sort()
	var sum := 0.0
	for v in samples:
		sum += v
	return {"avg": sum / samples.size(), "p95": sorted[mini(sorted.size() - 1, int(sorted.size() * 0.95))], "worst": sorted[sorted.size() - 1]}


func _refresh_text() -> void:
	var st := stats_of(frames)
	avg = st.avg
	p95 = st.p95
	worst = st.worst
	var vp := get_viewport().get_viewport_rid()
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(vp)
	var cpu := RenderingServer.viewport_get_measured_render_time_cpu(vp)
	var t := "beeld gem %.1f · p95 %.1f · slechtst %.1f ms (%.0f fps)\n" % [avg, p95, worst, 1000.0 / maxf(avg, 0.001)]
	t += "GPU %.1f · render-CPU %.1f · scripts %.1f ms\n" % [gpu, cpu, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0 + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0]
	t += "draw calls %d · objecten %d · driehoeken %dk · videogeh. %d MB\n" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0]
	t += "vijanden %d · kogels %d · vaten %d · nodes %d · %s" % [Game.enemies.size(), bullets_live, Game.barrels.size(), Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Game.state]
	_text.text = t
	var lines := PackedStringArray()
	for s in spikes:
		lines.append("%.0f ms · %s · %d vijanden%s" % [s.ms, s.state, s.enemies, (" · na: %s (%.1f s)" % [s.after, s.ago]) if s.after != "" else ""])
	_spike_text.text = "PIEKEN (>33 ms):\n" + ("\n".join(lines) if not lines.is_empty() else "geen")


func _draw() -> void:
	var x := size.x * 0.5 - GRAPH.x * 0.5
	var y := 4.0
	draw_rect(Rect2(x - 4, y - 2, GRAPH.x + 8, GRAPH.y + 4), Color(0, 0, 0, 0.55))
	# lijnen bij 16,7 ms (60 fps) en 33,3 ms (30 fps); schaal 0 .. 50 ms
	var top := 50.0
	for pair in [[16.7, Color(0.4, 1.0, 0.4, 0.5)], [33.3, Color(1.0, 0.5, 0.3, 0.5)]]:
		var ly: float = y + GRAPH.y * (1.0 - pair[0] / top)
		draw_line(Vector2(x, ly), Vector2(x + GRAPH.x, ly), pair[1], 1.0)
	var n := frames.size()
	if n < 2:
		return
	var w := GRAPH.x / float(SAMPLES)
	for i in n:
		var v := minf(frames[i], top)
		var h := GRAPH.y * v / top
		var c := Color(0.5, 1.0, 0.5) if v < 16.7 * 1.2 else (Color(1.0, 0.85, 0.3) if v < SPIKE_MS else Color(1.0, 0.3, 0.2))
		draw_rect(Rect2(x + (SAMPLES - n + i) * w, y + GRAPH.y - h, maxf(w, 1.0), h), c)
