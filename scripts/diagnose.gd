class_name Diagnose
extends Node
## Eenmalige diagnose-run (Instellingen > Diagnose-run): meet in ~30 s op het toestel zelf wat het beeld het meest kost.
## Per fase gaat één onderdeel uit (zon-schaduw, jungle, stad, nabewerking, HUD, fysica, scripts, de hele 3D-wereld) en we
## meten de echte beeldtijd. Het verschil met de basis is wat dat onderdeel kost. Het rapport komt in prestatie/ (Working Copy
## zet het zelf op GitHub). De run start vanzelf 6 s nadat je in een spel (pauze of golf) staat en zet zichzelf daarna uit.

const START_AFTER := 6.0   # seconden in het spel voor de run begint
const PHASE_SECS := 2.5
const SKIP_SECS := 0.8     # na elke omschakeling de eerste beelden niet meetellen

var _layer: CanvasLayer
var _label: Label
var _running := false
var _in_game := 0.0
var _times := PackedFloat32Array()
var _last_us := 0
var _saved_vis: Array = []   # [node, was_visible]
var _saved_proc: Array = []  # [node, process, physics]


func _process(delta: float) -> void:
	if _last_us != 0 and _running:
		_times.append((Time.get_ticks_usec() - _last_us) / 1000.0)
	_last_us = Time.get_ticks_usec()
	if _running or GameSettings.get_value("diag") != "on":
		return
	if Game.state == "prep" or Game.state == "play":
		_in_game += delta
		if _in_game >= START_AFTER:
			_run()
	else:
		_in_game = 0.0


func _show(text: String) -> void:
	if _layer == null:
		_layer = CanvasLayer.new()
		_layer.layer = 100
		add_child(_layer)
		_label = Label.new()
		_label.position = Vector2(24, 18)
		_label.add_theme_font_size_override("font_size", 15)
		_label.add_theme_color_override("font_color", Color(1, 1, 0.7))
		_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		_label.add_theme_constant_override("outline_size", 6)
		_layer.add_child(_label)
	_label.text = text


func _atm() -> Atmosphere:
	return get_tree().get_first_node_in_group("atmosphere") as Atmosphere


func _hide_nodes(nodes: Array) -> void:
	for n in nodes:
		if n is CanvasItem or n is Node3D or n is CanvasLayer:
			_saved_vis.append([n, n.visible])
			n.visible = false


func _hide_groups(groups: Array) -> void:
	for g in groups:
		_hide_nodes(get_tree().get_nodes_in_group(g))


func _restore_vis() -> void:
	for p in _saved_vis:
		if is_instance_valid(p[0]):
			p[0].visible = p[1]
	_saved_vis.clear()


## Alle HUD- en menulagen behalve die van deze diagnose.
func _hud_layers() -> Array:
	var out := []
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if n != _layer:
			out.append(n)
	return out


func _stop_scripts() -> void:
	for n in get_tree().root.find_children("*", "Node", true, false):
		if n == self or n is PerfGovernor or n is PerfMonitor or n is Diagnose:
			continue
		var p: bool = n.is_processing()
		var q: bool = n.is_physics_processing()
		if p or q:
			_saved_proc.append([n, p, q])
			n.set_process(false)
			n.set_physics_process(false)


func _restore_scripts() -> void:
	for r in _saved_proc:
		if is_instance_valid(r[0]):
			r[0].set_process(r[1])
			r[0].set_physics_process(r[2])
	_saved_proc.clear()


const NAMES := [
	"basis (alles aan)", "zon-schaduw uit", "jungle onzichtbaar", "stad onzichtbaar", "nabewerking uit (mist, gloed, kleur, tonemap)",
	"HUD en menu's uit", "3D-resolutie 25%", "fysica uit", "alle scripts uit (geen _process)", "hele 3D-wereld uit (alleen HUD)",
	"3D en HUD uit (kaal beeld, ondergrens)",
]
var _mem := {}


func _apply(i: int) -> void:
	var vp := get_viewport()
	var atm := _atm()
	var env: Environment = atm._env
	var cam := vp.get_camera_3d()
	match i:
		1:
			_mem.sun = atm._sun.shadow_enabled
			atm._sun.shadow_enabled = false
		2:
			_hide_groups(["foliage_palm", "foliage_bush", "foliage_fern", "foliage_grass", "foliage_rock", "treeshadow"])
		3:
			if Stad.current != null and is_instance_valid(Stad.current):
				_hide_nodes([Stad.current])
		4:
			_mem.post = [env.fog_enabled, env.glow_enabled, env.ssao_enabled, env.adjustment_enabled, env.tonemap_mode]
			env.fog_enabled = false
			env.glow_enabled = false
			env.ssao_enabled = false
			env.adjustment_enabled = false
			env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
			if cam and cam.attributes is CameraAttributesPractical:
				_mem.dof = (cam.attributes as CameraAttributesPractical).dof_blur_far_enabled
				(cam.attributes as CameraAttributesPractical).dof_blur_far_enabled = false
		5:
			_hide_nodes(_hud_layers())
		6:
			_mem.scale = vp.scaling_3d_scale
			vp.scaling_3d_scale = 0.25
		7:
			PhysicsServer3D.set_active(false)
		8:
			_stop_scripts()
		9:
			vp.disable_3d = true
		10:
			vp.disable_3d = true
			_hide_nodes(_hud_layers())


func _undo(i: int) -> void:
	var vp := get_viewport()
	var atm := _atm()
	var env: Environment = atm._env
	var cam := vp.get_camera_3d()
	match i:
		1:
			atm._sun.shadow_enabled = _mem.sun
		2, 3, 5:
			_restore_vis()
		4:
			var post: Array = _mem.post
			env.fog_enabled = post[0]
			env.glow_enabled = post[1]
			env.ssao_enabled = post[2]
			env.adjustment_enabled = post[3]
			env.tonemap_mode = post[4]
			if cam and cam.attributes is CameraAttributesPractical and _mem.has("dof"):
				(cam.attributes as CameraAttributesPractical).dof_blur_far_enabled = _mem.dof
		6:
			vp.scaling_3d_scale = _mem.scale
		7:
			PhysicsServer3D.set_active(true)
		8:
			_restore_scripts()
		9:
			vp.disable_3d = false
		10:
			vp.disable_3d = false
			_restore_vis()


func _median(a: PackedFloat32Array) -> float:
	if a.is_empty():
		return 0.0
	var s := a.duplicate()
	s.sort()
	return s[s.size() / 2]


func _p95(a: PackedFloat32Array) -> float:
	if a.is_empty():
		return 0.0
	var s := a.duplicate()
	s.sort()
	return s[mini(s.size() - 1, int(s.size() * 0.95))]


func _run() -> void:
	_running = true
	PerfGovernor.paused = true   # de resolutieregelaar blijft stil, anders meten we hem mee
	var rows: Array = []
	for i in NAMES.size():
		_show("DIAGNOSE %d/%d: %s\nBeweeg niet en kijk niet weg; klaar na ~%d s" % [i + 1, NAMES.size(), NAMES[i], int((NAMES.size() - i) * PHASE_SECS)])
		_apply(i)
		_times.clear()
		var t_start := Time.get_ticks_msec()
		var proc := 0.0
		var phys := 0.0
		var draw := 0.0
		var n := 0
		while Time.get_ticks_msec() - t_start < int(PHASE_SECS * 1000.0):
			await get_tree().process_frame
			if Time.get_ticks_msec() - t_start > int(SKIP_SECS * 1000.0):
				proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
				phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
				draw += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
				n += 1
		var keep := PackedFloat32Array()
		var skip := int(SKIP_SECS * 1000.0 / maxf(_median(_times), 1.0))
		for k in range(mini(skip, _times.size()), _times.size()):
			keep.append(_times[k])
		_undo(i)
		await get_tree().process_frame
		rows.append({"name": NAMES[i], "med": _median(keep), "p95": _p95(keep), "proc": proc / maxi(n, 1), "phys": phys / maxi(n, 1), "draw": draw / maxi(n, 1), "n": keep.size()})
	PerfGovernor.paused = false
	var body := _markdown(rows)
	var saved := _save(body)
	_show(_screen_text(rows) + "\n" + saved)
	GameSettings.set_value("diag", "off")
	await get_tree().create_timer(40.0).timeout
	_show("")
	_running = false


func _markdown(rows: Array) -> String:
	var base: float = rows[0].med
	var t := PerfMonitor.device_header()
	t += "## Diagnose-run · %s\n\n" % Time.get_datetime_string_from_system().replace("T", " ")
	t += "Per fase gaat één onderdeel uit; **winst** = hoeveel ms het beeld korter wordt (basis %.1f ms). Staat de winst bij alles dicht bij 0, dan ligt het niet aan het tekenen maar aan iets buiten het spel (scherm/iOS/Xogot).\n\n" % base
	t += "| fase | mediaan ms | p95 ms | fps | winst ms | proces ms | fysica ms | draw calls |\n|---|---|---|---|---|---|---|---|\n"
	for r in rows:
		t += "| %s | %.1f | %.1f | %.0f | %+.1f | %.1f | %.1f | %.0f |\n" % [r.name, r.med, r.p95, 1000.0 / maxf(r.med, 0.001), base - r.med, r.proc, r.phys, r.draw]
	var best := rows.slice(1, rows.size() - 2)
	best.sort_custom(func(a, b): return a.med < b.med)
	t += "\nGrootste winst: **%s** (%+.1f ms). Ondergrens (kaal beeld): %.1f ms = %.0f fps.\n" % [best[0].name, base - best[0].med, rows[-1].med, 1000.0 / maxf(rows[-1].med, 0.001)]
	return t


func _screen_text(rows: Array) -> String:
	var base: float = rows[0].med
	var s := "DIAGNOSE KLAAR (basis %.1f ms = %.0f fps)\n" % [base, 1000.0 / maxf(base, 0.001)]
	for r in rows:
		s += "%-44s %5.1f ms  winst %+5.1f\n" % [r.name, r.med, base - r.med]
	return s


func _save(body: String) -> String:
	var d := Time.get_datetime_dict_from_system()
	var file := "diagnose_%04d%02d%02d_%02d%02d%02d.md" % [d.year, d.month, d.day, d.hour, d.minute, d.second]
	for dir in [PerfMonitor.report_dir, "user://prestatie"]:
		DirAccess.make_dir_recursive_absolute(dir)
		var f := FileAccess.open(dir + "/" + file, FileAccess.WRITE)
		if f == null:
			continue
		f.store_string(body)
		f.close()
		return "rapport: " + dir + "/" + file
	return "rapport NIET opgeslagen"
