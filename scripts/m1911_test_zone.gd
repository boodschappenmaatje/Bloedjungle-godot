extends Node
## Opt-in standalone M1911 test overlay. Run scenes/m1911_test_zone.tscn; production Main remains untouched.

var main: Node3D
var readout: Label
var volume: HSlider
var autofire := false
var shots := 0
var frames: Array[float] = []
var sample_timer := 0.0
var perf_line := "FPS: —"

func _ready() -> void:
	main = get_node("Main")
	_build_ui()
	_boot.call_deferred()
	set_process(true)

func _boot() -> void:
	await main.begin()
	Game.state = "play"
	Game.wave = 1
	Game.player.weapon = "m1911"
	Game.player.model.set_gun("m1911")
	Game.changed.emit()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 18)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(260, 0)
	panel.add_child(box)
	readout = Label.new()
	readout.text = "M1911A1 TEST ZONE — laden…"
	box.add_child(readout)
	for spec in [["Fire once", _fire_once], ["Reload", _reload], ["Empty slide", _empty], ["Stand / crouch / prone", _stance], ["Hold fire assist", _toggle_assist], ["A/B real sample / procedural", _toggle_ab]]:
		var b := Button.new()
		b.text = spec[0]
		b.pressed.connect(spec[1])
		box.add_child(b)
	var vol_label := Label.new()
	vol_label.text = "M1911 sample volume"
	box.add_child(vol_label)
	volume = HSlider.new()
	volume.min_value = 0.0
	volume.max_value = 1.5
	volume.step = 0.05
	volume.value = 1.0
	volume.value_changed.connect(_set_volume)
	box.add_child(volume)

func _process(delta: float) -> void:
	frames.append(delta)
	if frames.size() > 300:
		frames.pop_front()
	sample_timer += delta
	if sample_timer >= 0.5 and not frames.is_empty():
		sample_timer = 0.0
		var sorted := frames.duplicate()
		sorted.sort()
		var sum := 0.0
		for f in frames:
			sum += f
		var average := sum / frames.size()
		var p99_frame: float = sorted[mini(sorted.size() - 1, int(ceil(sorted.size() * 0.99)) - 1)]
		var low_1_fps: float = 1.0 / maxf(sorted[mini(sorted.size() - 1, int(sorted.size() * 0.99))], 0.00001)
		perf_line = "FPS avg %.1f / 1%% low %.1f | p99 %.2f ms" % [1.0 / maxf(average, 0.00001), low_1_fps, p99_frame * 1000.0]
	if autofire and Game.player and Game.player.fire_t <= 0.0:
		_fire_once()
	if Game.player:
		var p = Game.player
		var fps := 1.0 / maxf(delta, 0.00001)
		readout.text = "M1911A1 TEST ZONE\nAmmo: %d+%d / 7  |  shots: %d\nReload phase: %d  |  stance: %d\n%s | now %.1f fps" % [p.m1911_mag_rounds, int(p.m1911_chambered), shots, p._reload_phase, p.stance, perf_line, fps]

func _fire_once() -> void:
	if not Game.player:
		return
	Game.player.fire_t = 0.0
	Game.player._shoot(Game.wstat("m1911"))
	shots += 1

func _reload() -> void:
	if Game.player:
		Game.player.request_reload()

func _empty() -> void:
	if Game.player:
		Game.player.m1911_mag_rounds = 0
		Game.player.m1911_chambered = false
		Game.player._sync_m1911_ammo()
		Game.player.model.shoot_recoil("m1911", true)

func _stance() -> void:
	if Game.player:
		Game.player.set_stance((Game.player.stance + 1) % 3)

func _toggle_assist() -> void:
	autofire = not autofire

func _set_volume(value: float) -> void:
	if Sfx.has_method("set_m1911_test_volume"):
		Sfx.set_m1911_test_volume(value)

func _toggle_ab() -> void:
	Sfx.toggle_m1911_test_ab()
