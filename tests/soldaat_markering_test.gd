extends SceneTree
## Controleert de soldaatmarkeringen: ring per soort (vijand/bondgenoot, speler geen ring), groter model in Tactisch, de instelling
## "markeringen" (aan, alleen Tactisch, uit) en dat een gesneuvelde soldaat geen ring meer heeft.
## Draaien: godot --headless --path . -s tests/soldaat_markering_test.gd --fixed-fps 60

var failures: Array[String] = []
var main: Node
var game: Node


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("MARKERING TEST: " + message)


func _mark(m: SoldierModel) -> SoldierMark:
	return m.get_node_or_null("SoldierMark")


func _ring_on(m: SoldierModel) -> bool:
	return _mark(m)._ring.visible


func _body(m: SoldierModel) -> float:
	return (m._model as Node3D).scale.x


func _settle(camera: Camera3D) -> void:
	for _i in 4:
		camera.call("_process", 1.0 / 60.0)
		await process_frame


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	game = root.get_node("Game")
	for _i in 3:
		await process_frame
	await main.call("begin")
	for _i in 3:
		await process_frame
	var camera: Camera3D = main.get_node("Camera")
	var player: Node3D = game.get("player")
	var pm: SoldierModel = player.model
	var enemy: Node3D = main.ENEMY.instantiate()
	enemy.setup("rifle", 1)
	main.add_child(enemy)
	enemy.global_position = player.global_position + Vector3(4, 0, 4)
	var em: SoldierModel = enemy.model
	var am := SoldierModel.new()
	main.add_child(am)
	am.setup(Color("5a6a36"), "thompson")
	for _i in 3:
		await process_frame
	_check(_mark(pm) != null and _mark(pm).kind == "speler", "speler heeft geen spelermarkering")
	_check(_mark(em) != null and _mark(em).kind == "vijand", "vijand heeft geen vijandmarkering")
	_check(_mark(am) != null and _mark(am).kind == "vriend", "bondgenoot heeft geen vriendmarkering")
	_check(_mark(pm)._ring == null, "speler heeft nog een ring (v152: weggehaald)")
	# standaard: aan, Tactisch is de beginstand en daar is het lichaam groter
	GameSettings.values["markeringen"] = "on"
	await _settle(camera)
	_check(not bool(camera.get("combat_view")), "Tactisch is niet de beginstand")
	_check(_ring_on(em) and _ring_on(am), "ringen staan niet aan in Tactisch")
	_check(is_equal_approx(_body(em), SoldierMark.MODEL_BOOST), "model is niet groter in Tactisch: %.2f" % _body(em))
	camera.call("toggle_view")
	await _settle(camera)
	_check(_ring_on(em), "ringen staan niet aan in Gevecht")
	_check(is_equal_approx(_body(em), 1.0), "model is groter in Gevecht: %.2f" % _body(em))
	GameSettings.values["markeringen"] = "tact"
	await _settle(camera)
	_check(not _ring_on(em), "alleen-Tactisch laat ringen zien in Gevecht")
	camera.call("toggle_view")
	await _settle(camera)
	_check(_ring_on(em), "alleen-Tactisch verbergt de ringen in Tactisch")
	GameSettings.values["markeringen"] = "off"
	await _settle(camera)
	_check(not _ring_on(em) and not _ring_on(am), "uit laat nog ringen zien")
	_check(is_equal_approx(_body(em), 1.0), "uit maakt het model nog groter: %.2f" % _body(em))
	# gesneuvelde vijand: ring weg
	GameSettings.values["markeringen"] = "on"
	enemy.set("dead", true)
	await _settle(camera)
	_check(not _ring_on(em), "dode vijand houdt zijn ring")
	_check(is_equal_approx(_body(em), 1.0), "dode vijand blijft groter")
	main.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("MARKERING TEST PASS: ringen per soort, groter in Tactisch, instelling aan/alleen Tactisch/uit, geen ring bij dood")
		quit(0)
	else:
		quit(1)
