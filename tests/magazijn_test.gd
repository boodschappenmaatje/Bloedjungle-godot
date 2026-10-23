extends SceneTree
## End-to-end controle voor het magazijn: plaatsing, deuren, zicht, gevecht en instorting.
## Draaien: godot --headless --path . -s tests/magazijn_test.gd --fixed-fps 60

var main: Node
var game: Node
var warehouse
var camera: Camera3D
var frames := 0
var move := Vector2.ZERO
var enemy: CharacterBody3D
var outside_shot
var front_piece: Dictionary = {}
var failures := 0
var entry_stopped := false
var side_entry_stopped := false
var exit_stopped := false
var door_opened := false
var side_door_opened := false
var exit_door_opened := false
var grenade_hp_before := 0.0
var bullet_hp_before := 0.0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(func() -> void:
		if frames > 3 and game:
			game.move = move
	)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("OK: ", label)
	else:
		failures += 1
		push_error("MAGAZIJN_TEST: " + label)


func _local_player() -> Vector3:
	return warehouse.to_local(game.player.global_position)


func _at(v: Vector3) -> void:
	game.player.global_position = warehouse.to_global(v)
	game.player.position.y = v.y


func _gone() -> int:
	return warehouse.segs.filter(func(s: Dictionary) -> bool:
		return String(s.name).begins_with("M0") and s.staat >= 2
	).size()


func _wall_hp() -> float:
	var total := 0.0
	for s: Dictionary in warehouse.segs:
		total += float(s.hp)
	return total


func _cover_hits() -> int:
	var sphere := SphereShape3D.new()
	sphere.radius = 0.25
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis(), warehouse.to_global(Vector3(-2.15, 0.82, -2.45)))
	query.collision_mask = 2
	return game.player.get_world_3d().direct_space_state.intersect_shape(query, 10).size()


func _process(_delta: float) -> bool:
	frames += 1
	var t := frames - 3
	if t == 0:
		main.begin()
		game = root.get_node_or_null("Game")
		_check(game != null and game.player != null, "spelwereld en speler starten")
		if game == null or game.player == null:
			quit(1)
			return true
		for n in root.find_children("*", "", true, false):
			if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
				n.set_process(false)
		var found := get_nodes_in_group("magazijn")
		_check(not found.is_empty(), "magazijn is in de bestaande stad geplaatst")
		if found.is_empty():
			quit(1)
			return true
		warehouse = found[0]
		camera = main.get_node_or_null("Camera") as Camera3D
		_check(warehouse != null and warehouse.kind == "magazijn" and String(warehouse.get_script().resource_path).ends_with("woonhuis.gd"),
			"stadsgebouw gebruikt de gedeelde Woonhuis-integratie")
		var city_script: Variant = load("res://scripts/stad.gd")
		_check(city_script.available("magazijn") and city_script.KINDS.magazijn.model, "gebouw is beschikbaar als model in de stadseditor")
		_check(warehouse.segs.size() == 18, "18 destructibele muurdelen laden")
		_check(warehouse.doors.size() == 3, "twee magazijndeuren en de personeelsdeur laden")
		_check(warehouse._dak_heel != null and warehouse._dak_kapot != null, "beide daktoestanden zijn aanwezig")
		_check(not warehouse._guard_bodies.is_empty(), "opslagstellingen en voorraad hebben botsing als dekking")
		var mesh_nodes: Array = warehouse.model.find_children("*", "MeshInstance3D", true, false)
		var bounds := AABB()
		var has_bounds := false
		var materials := {}
		var textured_surfaces := 0
		var normal_surfaces := 0
		var normal_arrays := 0
		for node in mesh_nodes:
			var mi := node as MeshInstance3D
			if mi.mesh == null:
				continue
			var local_transform: Transform3D = warehouse.global_transform.affine_inverse() * mi.global_transform
			var mesh_bounds: AABB = local_transform * mi.get_aabb()
			bounds = mesh_bounds if not has_bounds else bounds.merge(mesh_bounds)
			has_bounds = true
			for surface in mi.mesh.get_surface_count():
				var material := mi.get_active_material(surface) as BaseMaterial3D
				if material:
					materials[material.resource_name] = true
					if material.albedo_texture:
						textured_surfaces += 1
					if material.normal_enabled and material.normal_texture:
						normal_surfaces += 1
				var arrays: Array = mi.mesh.surface_get_arrays(surface)
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				if not normals.is_empty():
					normal_arrays += 1
		print("MAGAZIJN_MODEL mesh_nodes=", mesh_nodes.size(), " materials=", materials.size(),
			" textured_surfaces=", textured_surfaces, " normal_surfaces=", normal_surfaces,
			" normal_arrays=", normal_arrays, " bounds=", bounds.size)
		_check(mesh_nodes.size() >= 90 and materials.size() >= 8 and normal_arrays > 0, "GLB-meshes, PBR-materialen en mesh-normals laden")
		_check(textured_surfaces >= 8 and normal_surfaces >= 6, "base-color- en normalemaps zijn in de GLB beschikbaar")
		_check(has_bounds and bounds.size.x > 11.0 and bounds.size.x < 13.5 and bounds.size.y > 5.0 and bounds.size.y < 6.5
			and bounds.size.z > 8.0 and bounds.size.z < 12.0, "GLB-afmetingen passen bij een 12 × 8 meter magazijn")
		var editor_item := {"k": "magazijn", "x": 72.0, "z": -86.0, "r": 1, "m": 0}
		var city = city_script.current
		if city:
			city.add_item(editor_item)
			_check(editor_item.get("node") != null and String(editor_item.node.get_script().resource_path).ends_with("woonhuis.gd"), "editor plaatst een bewerkbaar magazijnmodel")
			city.refresh(editor_item)
			_check(is_equal_approx(editor_item.node.rotation.y, PI * 0.5), "bestaande draaifunctie blijft werken")
			var stored: Array = city_script.to_lines([editor_item])
			_check(stored.size() == 1 and String(stored[0][0]) == "magazijn", "stadsopslag bewaart het bestaande magazijnsoort-ID")
			city.remove_item(editor_item)
			_check(not is_instance_valid(editor_item.get("node")), "bestaande verwijderfunctie blijft werken")
		else:
			_check(false, "stadseditor heeft een actieve stadsindeling")
		_at(Vector3(0.0, 0.0, 5.5))
		return false

	if warehouse == null or game == null:
		return false
	if not warehouse.doors.is_empty() and float(warehouse.doors[0].t) > 0.5:
		door_opened = true
	if warehouse.doors.size() > 2 and float(warehouse.doors[2].t) > 0.5:
		side_door_opened = true
	if not warehouse.doors.is_empty() and float(warehouse.doors[0].t) > 0.5 and t > 440:
		exit_door_opened = true
	if t == 30:
		_check(_cover_hits() > 0, "munitiekisten hebben actieve botsingen en werken als dekking")
	if t == 32:
		move = Vector2(0.0, -1.0)
	if t > 32 and not entry_stopped:
		var p := _local_player()
		if p.z <= 2.6 and p.z >= -3.2:
			move = Vector2.ZERO
			entry_stopped = true
	if t == 110:
		var p := _local_player()
		_check(entry_stopped and p.z < 3.5 and p.z > -3.5, "speler loopt door de geopende hoofdingang naar binnen")
		_check(door_opened, "automatische deuropening werkt")
		_check(absf(warehouse.doors[0].node.rotation.z - warehouse.doors[0].closed) > 0.5,
			"dubbele magazijndeuren draaien om hun verticale scharnieras")
		_check(warehouse._inside == 0, "gebouw herkent de speler binnen")
		_check(not warehouse._dak.visible, "dak verdwijnt boven de speler")
		_check(not warehouse._hidden.is_empty(), "camerakant van de binnenmuren wordt verborgen")
		_check(camera != null and int(camera.get("zoom_step")) == 0, "bestaande camera blijft actief zonder inzoomstap")
		if camera:
			var camera_distance := camera.global_position.distance_to(camera.get("focus"))
			_check(absf(camera_distance - 28.0) < 1.0, "camera behoudt de standaard 28 meter afstand binnen")
		_at(Vector3(-7.0, 0.0, 3.0))
		return false

	if t == 125:
		move = Vector2.ZERO
		return false
	if t == 140:
		move = Vector2(1.0, 0.0)
		return false
	if t > 140 and not side_entry_stopped:
		var side_p := _local_player()
		if side_p.x > -5.55 and side_p.x < -4.7:
			move = Vector2.ZERO
			side_entry_stopped = true
	if t == 220:
		var side_p := _local_player()
		_check(side_entry_stopped and side_p.x > -5.55 and side_p.x < -4.7 and warehouse._inside == 0,
			"speler kan ook via de aparte personeelsdeur naar binnen")
		_check(side_door_opened, "personeelsdeur opent volgens hetzelfde deursysteem")
		_check(absf(warehouse.doors[2].node.rotation.z - warehouse.doors[2].closed) > 0.5,
			"personeelsdeur draait om de verticale scharnieras")
		_at(Vector3(0.0, 0.0, -1.4))
		return false
	if t == 225:
		_at(Vector3(0.0, 0.0, -1.4))
		var enemy_scene := load("res://scenes/enemy.tscn") as PackedScene
		enemy = enemy_scene.instantiate() as CharacterBody3D
		enemy.call("setup", "knife", 1)
		main.add_child(enemy)
		enemy.global_position = warehouse.to_global(Vector3(0.0, 0.0, 6.5))
		return false
	if t == 400:
		_check(enemy != null and is_instance_valid(enemy) and warehouse.to_local(enemy.global_position).z < 3.5,
			"vijand-AI vindt de ingang en komt het magazijn binnen")
		if enemy and is_instance_valid(enemy):
			enemy.queue_free()
		enemy = null
		return false

	if t == 410:
		_at(Vector3(0.0, 0.0, -1.4))
		var src: Vector3 = game.player.global_position + Vector3(0.0, 1.05, 0.0)
		bullet_hp_before = _wall_hp()
		var bullet_script: Variant = load("res://scripts/bullet.gd")
		bullet_script.fire(main, src, PI, 75.0, 120.0, 0.6, true)
		return false
	if t == 418:
		_check(_wall_hp() < bullet_hp_before, "gewone kogel raakt een constructieve muur")
		_check(_gone() == 0, "gewone kogelschade blijft onder tankgranaatschade")
		return false
	if t == 420:
		var src: Vector3 = game.player.global_position + Vector3(0.0, 1.05, 0.0)
		var bullet_script: Variant = load("res://scripts/bullet.gd")
		bullet_script.fire(main, src, 0.0, 75.0, 20.0, 0.4, true)
		for n in main.get_children():
			var script = n.get_script()
			if script != null and String(script.resource_path).ends_with("bullet.gd"):
				outside_shot = n
		return false
	if t == 426:
		_check(outside_shot != null and is_instance_valid(outside_shot) and warehouse.to_local(outside_shot.global_position).z > 5.0,
			"speler kan via de deuropening naar buiten schieten")
		return false
	if t == 430:
		grenade_hp_before = _wall_hp()
		var src: Vector3 = game.player.global_position + Vector3(0.0, 1.05, 0.0)
		var bullet_script: Variant = load("res://scripts/bullet.gd")
		bullet_script.fire(main, src, PI, 75.0, 120.0, 0.6, true, false, 0, 2.0)
		return false
	if t == 438:
		_check(_wall_hp() < grenade_hp_before, "explosieve granaat beschadigt constructiedelen via het bestaande blast-systeem")
		return false
	if t == 440:
		var target: Dictionary = warehouse.segs.filter(func(s: Dictionary) -> bool:
			return String(s.name).begins_with("M0") and s.staat < 2
		)[0]
		var gone_before := _gone()
		var house_script: Variant = load("res://scripts/woonhuis.gd")
		house_script.blast_all(warehouse.seg_center(target), 1.8, 140.0)
		_check(target.staat == 1 and target.hp < target.max, "tankinslag brengt het gekozen muurdeel in beschadigde staat")
		house_script.blast_all(warehouse.seg_center(target), 1.8, 140.0)
		_check(target.staat == 2 and _gone() > gone_before, "tweede tankinslag vernietigt precies het geraakte muurdeel")
		_check(not warehouse._dak.get_meta("weg", false) and warehouse._dak_kapot.visible,
			"eerste dragende schade toont het beschadigde dak")
		while _gone() < 5:
			var next: Dictionary = warehouse.segs.filter(func(s: Dictionary) -> bool:
				return String(s.name).begins_with("M0") and String(s.name) not in ["M001", "M002", "M003"] and s.staat < 2
			)[0]
			warehouse.damage(next, float(next.hp) + 1.0)
		_check(warehouse._dak.get_meta("weg", false) and not warehouse._dak_heel.visible and not warehouse._dak_kapot.visible,
			"vijf verloren dragers laten het dak instorten en maken plaats voor puin")
		front_piece = warehouse.segs.filter(func(s: Dictionary) -> bool:
			return String(s.name) == "M002"
		)[0]
		warehouse.damage(front_piece, float(front_piece.max) * 0.51)
		_check(front_piece.staat == 1 and not (front_piece.kapot as Node3D).visible,
			"beschadigde camera-zijmuur blijft verborgen zolang de speler binnen staat")
		return false
	if t == 445:
		_at(Vector3(0.0, 0.0, 2.6))
		move = Vector2.ZERO
		return false
	if t == 470:
		move = Vector2(0.0, 1.0)
		return false
	if t > 445 and not exit_stopped:
		if _local_player().z > 5.0:
			move = Vector2.ZERO
			exit_stopped = true
	if t == 520:
		_check(exit_stopped and exit_door_opened and _local_player().z > 5.0 and warehouse._inside == -1,
			"speler verlaat het magazijn via de hoofdingang na muurschade")
		_check(front_piece.kapot.is_visible_in_tree() and warehouse._hidden.is_empty(),
			"beschadigde muurtoestand wordt bij verlaten zichtbaar hersteld")
		_at(Vector3(0.0, 0.0, 0.0))
		move = Vector2.ZERO
		return false
	if t == 540:
		_check(warehouse._inside == 0, "speler staat veilig binnen voor de instorting")
		while _gone() < 12:
			var next: Dictionary = warehouse.segs.filter(func(s: Dictionary) -> bool:
				return String(s.name).begins_with("M0") and s.staat < 2
			)[0]
			warehouse.damage(next, float(next.hp) + 1.0)
		var ruin := warehouse.model.find_child("Ruine", true, false) as Node3D
		_check(warehouse._ruin and ruin != null and ruin.visible, "twaalf verloren dragers vervangen het gebouw door de ruïne")
		_check(warehouse._inside == -1 and warehouse.to_local(game.player.global_position).z > warehouse.spec.hz + 2.0,
			"speler wordt bij totale instorting naar buiten verplaatst")
		var ruin_body := false
		for n in warehouse.get_children():
			if n is StaticBody3D and n.collision_layer == 2 and n.get_child_count() >= 3:
				ruin_body = true
		_check(ruin_body, "ruïne krijgt nieuwe botsingen voor geblokkeerde doorgangen en puin")
		print("MAGAZIJN_TEST_RESULT failures=", failures, " muursegmenten=", warehouse.segs.size(), " deuren=", warehouse.doors.size())
		var exit_status := 1 if failures else 0
		main.queue_free()
		await process_frame
		await physics_frame
		quit(exit_status)
		return true
	return false
