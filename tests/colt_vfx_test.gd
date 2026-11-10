extends SceneTree
## Opt-in Colt VFX: gelijktijdige atlasframes, verschillende inslagen en oudste sporen.
## godot --headless --path . -s tests/colt_vfx_test.gd --fixed-fps 60

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var fx: Script = load("res://scripts/fx.gd")
	var stage := Node3D.new()
	root.add_child(stage)
	OS.set_environment("M1911_VFX_TEST", "1")
	_check(fx.m1911_vfx_enabled(), "Colt opt-in staat niet aan")
	fx.muzzle(stage, Vector3.ZERO, "m1911", 0.0)
	fx.muzzle(stage, Vector3(2, 0, 0), "m1911", 0.0)
	var flashes: Array[MeshInstance3D] = []
	for child in stage.get_children():
		if child is MeshInstance3D and child.get_meta("m1911_flipbook", false):
			flashes.append(child)
	_check(flashes.size() == 2, "twee Colt-schoten maken geen twee afzonderlijke flitsen")
	if flashes.size() == 2:
		var first := flashes[0].material_override as ShaderMaterial
		var second := flashes[1].material_override as ShaderMaterial
		_check(first != second, "gelijktijdige flitsen delen hetzelfde animatieframe")
		first.set_shader_parameter("frame_index", 12.0)
		_check(is_equal_approx(float(second.get_shader_parameter("frame_index")), 0.0), "eerste flits verandert de tweede")
	var first_decal_count: int = fx._decals.size()
	fx.impact(stage, Vector3(1, 1, 0), Vector3.BACK, "wood", true)
	_check(fx._decals.size() == first_decal_count + 1, "Colt op hout mist blijvende schorsschade")
	fx.impact(stage, Vector3(2, 1, 0), Vector3.BACK, "concrete", true)
	_check(fx._decals.size() == first_decal_count + 2, "Colt op beton mist kogelgat")
	var bark := fx._decals[first_decal_count] as Decal
	var concrete := fx._decals[first_decal_count + 1] as Decal
	_check(bark.texture_albedo != concrete.texture_albedo, "boom en muur gebruiken hetzelfde oppervlaktespoor")
	var oldest: Decal = fx._decals[0]
	for i in fx.MAX_DECALS + 2:
		fx.decal(stage, Vector3(i, 1, 0), Vector3.BACK, "hole", 0.3, 120.0)
	_check(fx._decals.size() == fx.MAX_DECALS, "decal-limiet overschreden")
	await process_frame
	_check(not is_instance_valid(oldest), "oudste kogelspoor is niet opgeruimd")
	OS.set_environment("M1911_VFX_TEST", "0")
	_check(not fx.m1911_vfx_enabled(), "normale instellingen zijn niet teruggezet")
	stage.queue_free()
	print("COLT VFX TEST: %s" % ("PASS" if failures.is_empty() else "FAIL: " + str(failures)))
	quit(0 if failures.is_empty() else 1)
