extends SceneTree
## Native-equivalent physics contract for both animated checkpoint barrier arms.
## godot --headless --path . -s tests/slagboom_collision_test.gd --fixed-fps 60
var failures := 0

func _check(ok: bool, message: String) -> void:
	if ok:
		print("PASS slagboom: " + message)
	else:
		failures += 1
		push_error("FAIL slagboom: " + message)


func _ray_hits_arm(level: Node3D, post: Dictionary) -> bool:
	var z: float = (post.barrier as Node3D).global_position.z
	var ray := PhysicsRayQueryParameters3D.create(Vector3(0.0, 0.95, z - 1.35), Vector3(0.0, 0.95, z + 1.35), Kit.LAYER_WALL)
	var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(ray)
	return not hit.is_empty() and hit.get("collider") == post.get("arm_body")


func _player_move_blocked(level: Node3D, post: Dictionary) -> bool:
	var z: float = (post.barrier as Node3D).global_position.z
	var actor := CharacterBody3D.new()
	actor.name = "SlagboomPlayerCollisionProbe"
	actor.collision_layer = 0
	actor.collision_mask = Kit.LAYER_WALL
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 2.15
	var cs := CollisionShape3D.new()
	cs.shape = cap
	cs.position.y = 1.075
	actor.add_child(cs)
	actor.position = Vector3(0.0, 0.0, z - 1.5)
	level.add_child(actor)
	var blocked := actor.test_move(actor.global_transform, Vector3(0, 0, 2.5))
	actor.queue_free()
	return blocked


func _run() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(main)
	await process_frame
	await process_frame
	main.begin()
	Game.move = Vector2.ZERO
	Game.prep_t = 9999.0
	if Game.player != null:
		Game.player.global_position = Vector3.ZERO
	for i in 25:
		await process_frame
	var wp := Wachtpost.inst
	_check(wp != null and wp.posts.size() == 2, "north and south checkpoint posts spawn")
	if wp == null or wp.posts.size() != 2:
		quit(1)
		return
	for i in wp.posts.size():
		var post: Dictionary = wp.posts[i]
		var arm_body := post.get("arm_body") as PostBody
		var arm_shape := post.get("arm_shape") as CollisionShape3D
		_check(arm_body != null and arm_shape != null, "arm %d has its own physics body and collision shape" % i)
		if arm_body == null or arm_shape == null:
			continue
		_check(arm_body.get_parent() == post.arm, "arm %d collision follows the GLB Boom pivot" % i)
		_check((arm_body.collision_layer & Kit.LAYER_WALL) != 0, "arm %d uses the player vehicle wall collision layer" % i)
		_check(not arm_shape.disabled, "closed arm %d has collision enabled" % i)
		_check(_ray_hits_arm(main, post), "closed arm %d physically blocks the approach ray" % i)
		_check(_player_move_blocked(main, post), "closed arm %d blocks a player-sized character" % i)
		var gate: Dictionary = Game.gates.list[i]
		gate.open = 1.0
		wp._physics_process(0.0)
		await physics_frame
		_check(not _ray_hits_arm(main, post), "raised arm %d clears the roadway" % i)
		gate.open = 0.0
		wp._physics_process(0.0)
		await physics_frame
		_check(_ray_hits_arm(main, post), "lowered arm %d blocks roadway again" % i)
		wp.damage(post, "boom", 120.0, "explosive")
		await physics_frame
		_check(post.boom_down and arm_shape.disabled, "destroyed arm %d has no active collision" % i)
		wp.repair_all()
		await physics_frame
		_check(not post.boom_down and not arm_shape.disabled, "repaired arm %d restores collision" % i)
	main.queue_free()
	await process_frame
	print("SLAGBOOM COLLISION TEST %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)


func _initialize() -> void:
	call_deferred("_run")
