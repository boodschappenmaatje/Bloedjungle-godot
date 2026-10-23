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
static var report_dir := "res://prestatie"  # in de projectmap: Working Copy zet nieuwe bestanden zelf op GitHub
const BIN_MS := 0.25  # een staafje in het histogram van beeldtijden
const BINS := 400  # tot 100 ms
const MAX_WAVE_SPIKES := 40

static var notes: Array = []  # {t, text, n}: wat er net gebeurde (golf begon, vijanden gespawnd, explosie)
static var bullets_live := 0

var frames := PackedFloat32Array()
var spikes: Array = []
var avg := 0.0
var p95 := 0.0
var worst := 0.0
var _stat_t := 0.0
var _text: Label
var _spike_text: Label
var _log_lines := 0
var _gpu_on := false

# Per golf verzameld (van de eerste tot de laatste speelseconde), na afloop als rapport weggeschreven
var _wave_active := false
var _wave_no := 0
var _w: Dictionary = {}
var _report_file := ""
var saved_to := ""  # waar het laatste rapport terecht kwam, of de reden dat het niet lukte


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
	visible = on and StadEditor.debug_enabled and not Game.editing
	if _gpu_on != on:
		_gpu_on = on
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), on)
		if not on:
			frames.clear()
			spikes.clear()
	if not on:
		return
	# de eigen duur van dit beeld (delta); niet het verschil in klokstanden, want dat telt de tijd van een pauze mee
	var ms := _delta * 1000.0 / maxf(Engine.time_scale, 0.001)
	record_frame(ms)
	_track_wave(ms)
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
	if _wave_active and _w.spikes.size() < MAX_WAVE_SPIKES:
		s.at = float(Time.get_ticks_msec() - int(_w.t0)) / 1000.0
		_w.spikes.append(s)
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
	t += "GPU %s · render-CPU %.1f · proces %.1f · fysica %.1f ms\n" % ["%.1f" % gpu if gpu > 0.0 else "n.b.", cpu, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0]
	t += "draw calls %d · objecten %d · driehoeken %dk · videogeh. %d MB\n" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0]
	t += "vijanden %d · kogels %d · vaten %d · nodes %d · %s" % [Game.enemies.size(), bullets_live, Game.barrels.size(), Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Game.state]
	_text.text = t
	var lines := PackedStringArray()
	for s in spikes:
		lines.append("%.0f ms · %s · %d vijanden%s" % [s.ms, s.state, s.enemies, (" · na: %s (%.1f s)" % [s.after, s.ago]) if s.after != "" else ""])
	_spike_text.text = ("rapport: %s\n" % saved_to if saved_to != "" else "") + "PIEKEN (>33 ms):\n" + ("\n".join(lines) if not lines.is_empty() else "geen")


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


# ------------------------------------------------------------------ rapport per golf

func _new_wave() -> Dictionary:
	var bins := PackedInt32Array()
	bins.resize(BINS + 1)
	return {"t0": Time.get_ticks_msec(), "n": 0, "sum": 0.0, "worst": 0.0, "over20": 0, "over33": 0, "bins": bins, "spikes": [],
		"enemies_max": 0, "bullets_max": 0, "draw_sum": 0.0, "draw_max": 0, "objects_max": 0, "tris_max": 0, "vmem_max": 0.0,
		"nodes_max": 0, "res_min": 9.0, "res_sum": 0.0, "base_hp": Game.base_hp, "points": Game.points, "kills": Game.kills}


## Elk beeld van een golf optellen. Een golf = zolang Game.state "play" is; daarna wordt het rapport geschreven.
func _track_wave(ms: float) -> void:
	var playing := Game.state == "play"
	if playing and not _wave_active:
		_wave_active = true
		_wave_no = Game.wave
		_w = _new_wave()
	elif not playing and _wave_active:
		_wave_active = false
		finish_wave()
	if not _wave_active:
		return
	_w.n += 1
	_w.sum += ms
	_w.worst = maxf(_w.worst, ms)
	if ms > 20.0:
		_w.over20 += 1
	if ms > SPIKE_MS:
		_w.over33 += 1
	_w.bins[mini(int(ms / BIN_MS), BINS)] += 1
	var dc := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_w.draw_sum += dc
	_w.draw_max = maxi(_w.draw_max, dc)
	_w.objects_max = maxi(_w.objects_max, int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
	_w.tris_max = maxi(_w.tris_max, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	_w.vmem_max = maxf(_w.vmem_max, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)
	_w.nodes_max = maxi(_w.nodes_max, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	_w.enemies_max = maxi(_w.enemies_max, Game.enemies.size())
	_w.bullets_max = maxi(_w.bullets_max, bullets_live)
	var rs := get_viewport().scaling_3d_scale
	_w.res_min = minf(_w.res_min, rs)
	_w.res_sum += rs


static func _percentile(bins: PackedInt32Array, n: int, q: float) -> float:
	var target := n * q
	var run := 0
	for i in bins.size():
		run += bins[i]
		if run >= target:
			return (i + 1) * BIN_MS
	return BINS * BIN_MS


## De samenvatting van één golf als Markdown (leesbaar in GitHub, en door mij te lezen).
func report_markdown() -> String:
	var n: int = maxi(int(_w.n), 1)
	var secs := float(Time.get_ticks_msec() - int(_w.t0)) / 1000.0
	var avg: float = float(_w.sum) / n
	var t := "## Golf %d · %.0f s gespeeld · %s\n\n" % [_wave_no, secs, Time.get_datetime_string_from_system().replace("T", " ")]
	t += "| | |\n|---|---|\n"
	t += "| beelden | %d (gem. %.1f ms = %.0f fps) |\n" % [_w.n, avg, 1000.0 / maxf(avg, 0.001)]
	t += "| p50 / p95 / p99 / slechtst | %.1f / %.1f / %.1f / %.1f ms |\n" % [_percentile(_w.bins, _w.n, 0.5), _percentile(_w.bins, _w.n, 0.95), _percentile(_w.bins, _w.n, 0.99), _w.worst]
	t += "| beelden > 20 ms | %d (%.1f%%) |\n" % [_w.over20, 100.0 * _w.over20 / n]
	t += "| beelden > 33 ms (pieken) | %d (%.2f%%) |\n" % [_w.over33, 100.0 * _w.over33 / n]
	t += "| resolutie 3D | gem. %.0f%% · laagst %.0f%% |\n" % [100.0 * _w.res_sum / n, 100.0 * _w.res_min]
	t += "| draw calls | gem. %.0f · max %d |\n" % [_w.draw_sum / n, _w.draw_max]
	t += "| objecten / driehoeken (max) | %d / %dk |\n" % [_w.objects_max, _w.tris_max / 1000]
	t += "| videogeheugen (max) | %.0f MB |\n" % _w.vmem_max
	t += "| nodes (max) | %d |\n" % _w.nodes_max
	t += "| vijanden / kogels (max) | %d / %d |\n" % [_w.enemies_max, _w.bullets_max]
	t += "| bunker | %.0f -> %.0f hp · kills %d · punten %d |\n\n" % [_w.base_hp, Game.base_hp, Game.kills - int(_w.kills), Game.points]
	if _w.spikes.is_empty():
		t += "Geen pieken boven 33 ms.\n\n"
	else:
		t += "**Pieken** (eerste %d):\n\n| na | ms | vijanden | kogels | gebeurtenis ervoor |\n|---|---|---|---|---|\n" % _w.spikes.size()
		for s in _w.spikes:
			t += "| %.1f s | %.0f | %d | %d | %s |\n" % [s.at, s.ms, s.enemies, s.bullets, ("%s (%.1f s eerder)" % [s.after, s.ago]) if s.after != "" else "-"]
		t += "\n"
	return t


static func device_header() -> String:
	var vp := Engine.get_main_loop() as SceneTree
	var size_ := DisplayServer.window_get_size()
	var t := "# Prestatiemeting Bloedjungle\n\n"
	t += "- toestel: %s · %s · %s\n" % [OS.get_name(), OS.get_model_name(), RenderingServer.get_video_adapter_name()]
	t += "- Godot %s · renderer %s · venster %dx%d\n" % [Engine.get_version_info().string, RenderingServer.get_current_rendering_method(), size_.x, size_.y]
	t += "- instellingen: grafiek %s · tijd %s · weer %s · Hz-keuze %s · schermsnelheid gemeld %.0f · bomen bewegen %s · boomschaduw %s\n\n" % [GameSettings.get_value("quality"), GameSettings.get_value("time"), GameSettings.get_value("weather"), GameSettings.get_value("hz"), DisplayServer.screen_get_refresh_rate(), GameSettings.get_value("wind"), GameSettings.get_value("treeshadow")]
	return t


## Schrijft het rapport van de afgelopen golf: eerst in de projectmap (res://prestatie), anders in user://prestatie.
func finish_wave() -> void:
	if int(_w.n) < 30:
		return  # te kort om iets te zeggen
	if _report_file == "":
		var d := Time.get_datetime_dict_from_system()
		_report_file = "meting_%04d%02d%02d_%02d%02d%02d.md" % [d.year, d.month, d.day, d.hour, d.minute, d.second]
	var body := report_markdown()
	for dir in [report_dir, "user://prestatie"]:
		DirAccess.make_dir_recursive_absolute(dir)
		var path: String = dir + "/" + _report_file
		var f := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
		if f == null:
			continue
		f.seek_end()
		if f.get_position() == 0:
			f.store_string(device_header())
		f.store_string(body)
		f.close()
		saved_to = ProjectSettings.globalize_path(path)
		note("rapport opgeslagen")
		return
	saved_to = "NIET opgeslagen (geen schrijfrechten)"
