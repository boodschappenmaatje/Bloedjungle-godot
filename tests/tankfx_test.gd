extends SceneTree
## Tankschot (TankFx): Nieuw maakt vuur, rook, stof, ring en lamp met een vaste bovengrens; Klassiek valt terug op het oude schot;
## de lichtstreep en de inslag bestaan en ruimen zichzelf op.
## godot --headless --path . -s tests/tankfx_test.gd --fixed-fps 60

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("TANKFX TEST: " + message)


func _keys(stage: Node, prefix: String) -> Array:
	return stage.find_children("*", "Node3D", true, false).filter(func(n): return str(n.get_meta("wfx_key", "")).begins_with(prefix) and n.get_meta("wfx_active", false))


func _run() -> void:
	var gs: Script = load("res://scripts/game_settings.gd")
	var tfx: Script = load("res://scripts/tank_fx.gd")
	var old_value: String = gs.get_value("wapenfx")
	var stage := Node3D.new()
	root.add_child(stage)

	gs.set_value("wapenfx", "nieuw")
	_check(tfx.enabled(), "Nieuw staat niet aan")
	tfx.shot(stage, Vector3(0, 2, 0), Vector3(0, 0, 1), true, false)
	_check(not _keys(stage, "tankvuur").is_empty(), "het schot maakt geen vuur")
	_check(not _keys(stage, "tankrook").is_empty(), "het schot maakt geen rook")
	_check(not _keys(stage, "tankstof").is_empty(), "het schot maakt geen stof")
	_check(not _keys(stage, "tanklicht").is_empty(), "het schot maakt geen licht")
	# een salvo van 40 schoten: de voorraad blijft begrensd (nooit meer dan 8 per soort)
	for i in 40:
		tfx.shot(stage, Vector3(i, 2, 0), Vector3(0, 0, 1), i % 2 == 0, false)
	for k in ["tankvuur", "tankrook", "tankstof", "tanklicht"]:
		_check(_keys(stage, k).size() <= 8, "%s: meer dan 8 tegelijk (%d)" % [k, _keys(stage, k).size()])
	var rings := stage.find_children("*", "MeshInstance3D", true, false).filter(func(n): return n.material_override is ShaderMaterial and (n.material_override as ShaderMaterial).shader == tfx.G2_SHOCK)
	_check(rings.size() <= tfx.MAX_RING, "meer schokringen dan de grens (%d)" % rings.size())

	# lichtstreep en inslag
	var before := stage.get_child_count()
	tfx.flight(stage, Vector3.ZERO, Vector3(0, 0, 30), 0.1)
	_check(stage.get_child_count() == before + 1, "de lichtstreep ontbreekt")
	tfx.impact(stage, Vector3(5, 0, 5), 1.0)
	_check(not _keys(stage, "tankaarde").is_empty(), "de inslag maakt geen aardfontein")

	# Klassiek: geen nieuwe lagen, geen lichtstreep
	for n in stage.get_children():
		n.queue_free()
	await process_frame
	gs.set_value("wapenfx", "klassiek")
	_check(not tfx.enabled(), "Klassiek staat niet uit")
	tfx.shot(stage, Vector3(0, 2, 0), Vector3(0, 0, 1), true, false)
	_check(_keys(stage, "tankvuur").is_empty() and _keys(stage, "tankrook").is_empty(), "Klassiek maakt toch nieuwe lagen")
	var kids := stage.get_child_count()
	tfx.flight(stage, Vector3.ZERO, Vector3(0, 0, 30), 0.1)
	_check(stage.get_child_count() == kids, "Klassiek maakt toch een lichtstreep")

	# na het afspelen is alles weer vrij voor de voorraad
	gs.set_value("wapenfx", "nieuw")
	for n in stage.get_children():
		n.queue_free()
	await process_frame
	tfx.shot(stage, Vector3(0, 2, 0), Vector3(1, 0, 1), false, false)
	for i in 400:
		await process_frame
	_check(_keys(stage, "tankvuur").is_empty(), "het vuur wordt niet teruggegeven aan de voorraad")

	gs.set_value("wapenfx", old_value)
	if failures.is_empty():
		print("TANKFX TEST: OK")
	quit(1 if not failures.is_empty() else 0)
