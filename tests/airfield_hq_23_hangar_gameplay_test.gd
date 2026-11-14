extends Node
## Hangar gameplay contract: closed walls and doors block a player-mask body, the doors slide open
## when someone stands in front of them (and stay open while someone is inside), and the roof
## fades out while the player is inside and returns outside.

var failures := 0

func _check(name: String, ok: bool) -> void:
	print(("OK    " if ok else "FAIL  ") + name)
	if not ok:
		failures += 1

func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame

func _ready() -> void:
	call_deferred("_run")

func _walk(body: CharacterBody3D, direction: Vector3, frames: int) -> void:
	for _i in frames:
		body.velocity = direction * 6.0
		body.move_and_slide()
		await get_tree().physics_frame

func _run() -> void:
	var complex_body := AirfieldHQ23.make_complex()
	get_tree().root.add_child(complex_body)
	var showcase := complex_body.get_node("AirfieldCompactRoot/AirfieldHQ23CompactCore") as AirfieldHQ23CompactShowcase
	var far := Node3D.new()
	get_tree().root.add_child(far)
	far.global_position = Vector3(0, 0, 400)
	Game.player = far
	await _frames(5)
	for body_name in AirfieldHQ23CompactShowcase.HANGAR_WALL_BODIES:
		var wall := showcase.get_node("GameplayCollisions/" + body_name) as StaticBody3D
		_check("%s staat op de muurlaag" % body_name, wall.collision_layer == Kit.LAYER_WALL)
	_check("dak is los van de muren gesplitst (%d dakdelen)" % showcase._roof_nodes.size(), showcase._roof_nodes.size() >= 1)
	for roof in showcase._roof_nodes:
		_check("dak %s heeft geometrie" % roof.get_parent().name, roof.mesh != null and roof.mesh.get_surface_count() > 0)

	var walker := CharacterBody3D.new()
	walker.collision_layer = 0
	walker.collision_mask = 250  # zoals scenes/player.tscn
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	shape.shape = capsule
	walker.add_child(shape)
	get_tree().root.add_child(walker)
	walker.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	# 1) Gesloten deuren: van buiten (z = +20) naar binnen lopen mag niet.
	walker.global_position = showcase.to_global(Vector3(0, 1.0, 20.0))
	Game.player = far
	await _walk(walker, Vector3(0, 0, -1), 90)
	var z_closed := showcase.to_local(walker.global_position).z
	_check("gesloten deuren houden je buiten (z=%.1f, deur op 9.8)" % z_closed, z_closed > 9.9)
	# 2) Muur: zijwand van de hangar blokkeert.
	walker.global_position = showcase.to_global(Vector3(-16.0, 1.0, 0.0))
	await _walk(walker, Vector3(1, 0, 0), 90)
	var x_wall := showcase.to_local(walker.global_position).x
	_check("zijmuur blokkeert (x=%.1f, muur op -11)" % x_wall, x_wall < -10.4)
	# 3) Deuren openen als je ervoor staat.
	walker.global_position = showcase.to_global(Vector3(0, 1.0, 13.0))
	Game.player = walker
	await _frames(240)
	_check("deuren staan open als je ervoor staat", showcase._doors_open and absf(showcase.left_collision.position.x) > 10.5 and absf(showcase.right_collision.position.x) > 10.5)
	var open_ok := true
	for side in [&"left", &"right"]:
		var meshes: Array = showcase._door_meshes(side)
		open_ok = open_ok and meshes.size() == 3
		for m in meshes:
			open_ok = open_ok and absf(m.position.x) > 10.9
	_check("beide deurmeshes in alle 3 LODs staan open", open_ok)
	await _walk(walker, Vector3(0, 0, -1), 150)
	var z_in := showcase.to_local(walker.global_position).z
	_check("je loopt door de open deur naar binnen (z=%.1f)" % z_in, z_in < 5.0)
	# 4) Binnen: dak weg en deuren blijven open.
	await _frames(60)
	_check("dak is weggefaded en onzichtbaar", showcase._roof_hidden and showcase._roof_nodes.all(func(n): return not n.visible))
	_check("deuren blijven open met jou binnen", showcase._doors_open)
	# 5) Weer naar buiten: dak terug, deuren dicht.
	walker.global_position = showcase.to_global(Vector3(0, 1.0, 30.0))
	await _frames(300)
	_check("dak is terug buiten", not showcase._roof_hidden and showcase._roof_nodes.all(func(n): return n.visible and is_zero_approx(n.transparency)))
	_check("deuren zijn weer dicht", not showcase._doors_open and absf(showcase.left_collision.position.x) < 3.9)
	var closed_ok := true
	for side in [&"left", &"right"]:
		for m in showcase._door_meshes(side):
			closed_ok = closed_ok and absf(m.position.x) < 3.9
	_check("beide deurmeshes zijn weer dicht", closed_ok)
	print("AIRFIELD HQ 2.3 HANGAR GAMEPLAY TEST fouten: ", failures)
	get_tree().quit(1 if failures > 0 else 0)
