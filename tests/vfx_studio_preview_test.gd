extends SceneTree
## Standalone VFX Studio preview regression.
## Godot 4.7.2: --headless --path . -s tests/vfx_studio_preview_test.gd --fixed-fps 60
## No live gameplay scene or production weapons are changed.

var failures := 0
var ticks := 0

func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	ticks += 1
	if ticks > 900:
		push_error("VFX STUDIO TEST timed out")
		quit(99)
	return false


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(label: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1


func _run() -> void:
	var original_main: String = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	var game_settings_before: Dictionary = GameSettings.values.duplicate(true)
	var packed := load("res://vfx/preview/vfx_test_arena.tscn") as PackedScene
	_check("VFX scene exists", packed != null)
	if packed == null:
		quit(1)
		return
	var arena := packed.instantiate() as Node3D
	root.add_child(arena)
	await _frames(5)
	_check("isolated arena has 12 emitters", arena._muzzle_nodes.size() == 12)
	_check("five material targets exist", arena._target_nodes.size() == 5)
	_check("starts with zero shots", arena._shots == 0)
	_check("main scene unchanged", str(ProjectSettings.get_setting("application/run/main_scene", "")) == original_main)

	arena._single_shot()
	await _frames(3)
	_check("single shot increments count", arena._shots == 1)
	arena._set_guns(5)
	arena._single_shot()
	await _frames(3)
	_check("five MG salvo", arena._shots == 6)
	arena._set_guns(12)
	arena._cycle_profile()
	arena._cycle_material()
	arena._single_shot()
	await _frames(5)
	_check("12 MG salvo", arena._shots == 18)
	_check("M2 effects capped", M2PreviewFx.counts().m2_flash_live <= M2PreviewFx.FLASH_LIMIT)
	_check("tracers within pool limit", arena._tracer_created <= 48)
	arena._start_mode("Gestopt")
	await _frames(90)
	_check("M2 active flash nodes recycle", M2PreviewFx.counts().m2_flash_live == 0)
	_check("M2 active smoke nodes recycle", M2PreviewFx.counts().m2_smoke_live == 0)
	_check("tracer active nodes recycle", arena._tracer_live == 0)
	_check("preview did not change graphics defaults", GameSettings.DEFAULTS.get("quality") == "high")
	_check("main scene still unchanged", str(ProjectSettings.get_setting("application/run/main_scene", "")) == original_main)
	_check("settings cache unchanged", GameSettings.values == game_settings_before)
	arena.queue_free()
	await _frames(3)
	if failures == 0:
		print("VFX STUDIO PREVIEW TEST PASS")
		quit(0)
	else:
		push_error("VFX STUDIO PREVIEW TEST FAIL: %d checks" % failures)
		quit(1)
