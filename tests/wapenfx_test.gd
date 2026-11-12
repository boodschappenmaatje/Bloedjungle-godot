extends SceneTree
## Wapeneffecten AAA: shotgun en pistool. Voorraden begrensd, Klassiek blijft ongewijzigd, sporen/hulzen/landing aanwezig.
## godot --headless --path . -s tests/wapenfx_test.gd --fixed-fps 60

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("WAPENFX TEST: " + message)


func _flash_nodes(stage: Node) -> Array:
	return stage.find_children("*", "MeshInstance3D", true, false).filter(func(n): return str(n.get_meta("wfx_key", "")).begins_with("flash:"))


func _run() -> void:
	var gs: Script = load("res://scripts/game_settings.gd")
	var wfx: Script = load("res://scripts/wapenfx.gd")
	var fx: Script = load("res://scripts/fx.gd")
	var old_value: String = gs.get_value("wapenfx")
	var stage := Node3D.new()
	root.add_child(stage)

	# --- Nieuw ---
	gs.set_value("wapenfx", "nieuw")
	_check(wfx.enabled("trench") and wfx.enabled("m1911"), "Nieuw staat niet aan voor shotgun en pistool")
	_check(not wfx.enabled("garand"), "Garand hoort de nieuwe effecten niet te krijgen")
	fx.muzzle(stage, Vector3.ZERO, "trench", 0.0)
	fx.muzzle(stage, Vector3(3, 0, 0), "m1911", 0.0)
	var flashes := _flash_nodes(stage)
	_check(flashes.size() >= 2, "twee schoten maken minder dan twee vlammen (%d)" % flashes.size())
	var tr_flash: Array = flashes.filter(func(n): return str(n.get_meta("wfx_key")) == "flash:trench")
	var pi_flash: Array = flashes.filter(func(n): return str(n.get_meta("wfx_key")) == "flash:m1911")
	_check(not tr_flash.is_empty() and not pi_flash.is_empty(), "shotgun of pistool heeft geen eigen vlam")
	if not tr_flash.is_empty() and not pi_flash.is_empty():
		var a := (tr_flash[0] as MeshInstance3D).material_override as ShaderMaterial
		var b := (pi_flash[0] as MeshInstance3D).material_override as ShaderMaterial
		_check(a != null and b != null and a != b, "vlammen delen hetzelfde materiaal")
		_check(a.get_shader_parameter("flipbook_atlas") != b.get_shader_parameter("flipbook_atlas"), "shotgun en pistool gebruiken hetzelfde vlamplaatje")
	# afvuren zonder pauze: de voorraden mogen niet onbegrensd groeien
	for i in 120:
		fx.muzzle(stage, Vector3(i * 0.1, 0, 0), "trench", float(i))
		fx.muzzle(stage, Vector3(i * 0.1, 0, 2), "m1911", float(i))
	var counts: Dictionary = wfx.counts()
	for key in counts:
		var base := String(key).get_slice(":", 0)
		_check(int(counts[key]) <= int(wfx.CAP[base]), "voorraad %s te groot: %d" % [key, int(counts[key])])
	var lights := stage.find_children("*", "OmniLight3D", true, false).size()
	_check(lights <= int(wfx.CAP.light), "te veel flitslichten: %d" % lights)

	# --- kogelspoor ---
	for w in ["trench", "m1911"]:
		var m: ArrayMesh = wfx.tracer_mesh(w)
		_check(m != null and m.get_surface_count() == 1, "kogelspoor %s heeft niet één vlak" % w)
	_check(wfx.trace_length("m1911") < 4.0 and wfx.trace_length("trench") < 2.5, "kogelsporen zijn langer dan afgesproken")

	# --- hulzen ---
	fx.casing(stage, Vector3(0, 1.2, 0), Vector3.RIGHT, Vector3.FORWARD, "trench")
	var shell_found := false
	for c in stage.get_children():
		if c is MeshInstance3D and c.mesh != null and c.mesh.get_surface_count() == 2:
			shell_found = true
	_check(shell_found, "shotgunhuls (rood met koperen bodem) ontbreekt")

	# --- landing op de grond ---
	var before: int = int((wfx.counts() as Dictionary).get("stof", 0))
	for i in 8:
		wfx.ground_hit(stage, Vector3(i, 1.0, 0), "m1911")
	_check(int((wfx.counts() as Dictionary).get("stof", 0)) > before, "geen stofwolkje bij landing")

	# --- Klassiek ---
	gs.set_value("wapenfx", "klassiek")
	_check(not wfx.enabled("trench") and not wfx.enabled("m1911"), "Klassiek zet de nieuwe effecten niet uit")
	var stage2 := Node3D.new()
	root.add_child(stage2)
	var made_before := (wfx.counts() as Dictionary).duplicate()
	fx.muzzle(stage2, Vector3.ZERO, "m1911", 0.0)
	_check((wfx.counts() as Dictionary) == made_before, "Klassiek maakt toch nieuwe effectknopen")
	_check(wfx.kick("trench") < 0.0, "Klassiek geeft toch een nieuwe camerakick")
	wfx.ground_hit(stage2, Vector3.ZERO, "m1911")
	_check((wfx.counts() as Dictionary) == made_before, "Klassiek laat toch stof landen")

	# --- opruimen: alles in de voorraad wordt vanzelf weer vrij ---
	gs.set_value("wapenfx", "nieuw")
	await create_timer(5.6).timeout
	var active := 0
	for n in stage.find_children("*", "Node3D", true, false):
		if n.get_meta("wfx_active", false):
			active += 1
	_check(active == 0, "%d effecten blijven actief na afloop" % active)

	gs.set_value("wapenfx", old_value)
	stage.queue_free()
	stage2.queue_free()
	print("WAPENFX TEST: %s" % ("PASS" if failures.is_empty() else "FAIL: " + str(failures)))
	quit(0 if failures.is_empty() else 1)
