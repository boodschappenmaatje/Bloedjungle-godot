extends SceneTree
## Regression: jeep MG must reach an exposed high M2 gunner through real Bullet
## physics, but not through the rotating steel shield or an intervening wall.
## Run: godot --headless --path . --script tests/jeep_m2_schutter_test.gd --fixed-fps 60

var failures := 0
var main: Node3D
var _watchdog := 0


# Fail fast if a fixture error prevents _run() from calling quit().
func _process(_delta: float) -> bool:
	_watchdog += 1
	if _watchdog > 900:
		push_error("Jeep M2 test stuck; fixture did not finish")
		quit(99)
	return false


func _initialize() -> void:
	call_deferred("_run")


func _check(label: String, value: bool) -> void:
	print(("OK  " if value else "FOUT  ") + label)
	if not value:
		failures += 1


func _frames(count: int) -> void:
	for _i in count:
		await process_frame


func _blocking_box(center: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.name = "TemporaryLOSWall"
	wall.collision_layer = 2  # Bullet.MASK_WALL; avoid class preloading before Game autoload
	wall.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 9.0, 0.35)
	shape.shape = box
	wall.add_child(shape)
	main.add_child(wall)
	wall.global_position = center
	return wall


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main.begin()
	await _frames(40)

	# Isolated fixture outside the level's normal walls/buildings: retains the
	# same approved tower GLB, enemy capsule, jeep muzzle, bullet physics.
	# Load gameplay class after main/autoloads are initialized, as other tests do.
	var tower = load("res://scripts/vijand_m2_toren.gd").new()
	tower.name = "JeepTargetTower"
	tower.position = Vector3(300.0, 0.0, -20.0)
	main.add_child(tower)
	var shooter = load("res://scenes/vijand_verdediger.tscn").instantiate()
	shooter.setup("assault", 1)
	shooter.post = "schutter"
	shooter.add_to_group("vijand_verdediger")
	shooter.hp = 90.0
	shooter.max_hp = 90.0
	main.add_child(shooter)
	shooter.global_position = tower.get_node("ShooterMount").global_position
	shooter.tower = tower
	tower.shooter = shooter

	var jeep = load("res://scenes/jeep.tscn").instantiate()
	main.add_child(jeep)
	jeep.global_position = tower.global_position + Vector3(0.0, 0.0, 21.0)
	jeep.rotation.y = 0.0
	jeep.set_physics_process(false)
	await _frames(3)
	_check("toren heeft los schietend bemanningslid", tower.operational())
	_check("toren heeft echte MG-articulatie", tower.has_articulated_m2())
	var shield = tower.yaw.get_node_or_null("MG_ShieldCollision")
	_check("beschermschild is een fysiek onderdeel", shield is StaticBody3D)
	if shield is StaticBody3D:
		var side_a: Vector3 = shield.to_global(Vector3(0.0, 0.0, 1.5))
		var side_b: Vector3 = shield.to_global(Vector3(0.0, 0.0, -1.5))
		var armor_query := PhysicsRayQueryParameters3D.create(side_a, side_b, 16  # Bullet.MASK_BUNKER)
		var armor_hit := main.get_world_3d().direct_space_state.intersect_ray(armor_query)
		_check("draaibaar stalen schild houdt kogels tegen", not armor_hit.is_empty() and armor_hit.collider == shield)
	
	var from: Vector3 = jeep._monding.global_position
	var to: Vector3 = shooter.global_position + Vector3.UP * 1.85
	var diff := to - from
	var desired_angle := atan2(diff.x, diff.z)
	var assist: Dictionary = jeep._tower_gunner_solution(from, desired_angle)
	_check("jeep vindt zichtbare torenschutter binnen smalle richtkegel", not assist.is_empty() and assist.get("target") == shooter)
	_check("jeep MG verhoogt kogelbaan naar platform", not assist.is_empty() and float(assist.get("rise", 0.0)) > 0.01)
	_check("ver naast de schutter geeft geen automatische richthulp", jeep._tower_gunner_solution(from, desired_angle + 0.22).is_empty())
	
	# A solid wall between jeep and target must prohibit assist, no magical hits.
	var wall := _blocking_box(from.lerp(to, 0.5))
	await _frames(3)
	_check("tussenmuur blokkeert richthulp", jeep._tower_gunner_solution(from, desired_angle).is_empty())
	wall.queue_free()
	await _frames(3)

	# Fire actual Bullet instances, not a direct test-only shooter.hit call.
	assist = jeep._tower_gunner_solution(from, desired_angle)
	_check("schutter weer zichtbaar na weghalen muur", not assist.is_empty() and assist.get("target") == shooter)
	if not assist.is_empty():
		for _shot in 11:
			jeep._shoot(float(assist.angle), float(assist.rise))
		await _frames(60)
		_check("jeepkogels doden afzonderlijke MG-schutter", shooter.dead)
		_check("MG stopt meteen na dood schutter", not tower.operational() and not tower.destroyed)
		_check("toren blijft onvernietigd na schuttertreffers", tower.hp == tower.HP)
	print("jeep M2 regression errors: ", failures)
	quit(1 if failures else 0)
