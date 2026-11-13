extends Node3D
## Isolated movement, collision and camera showcase for Tropical Shop A.
## It does not modify the active city scene, player controller, or default camera.
const MODEL_PATH := "res://assets/tropical_shop_a.glb"
const SOLDIER_PATH := "res://assets/soldaat_vq2.glb"
const W := 10.3
const D := 8.6
const WALL := 0.24
const FLOOR1 := 3.55
const TOP := 6.72

var player: CharacterBody3D
var pivot: Node3D
var spring: SpringArm3D
var game_camera: Camera3D
var build_camera: Camera3D
var model: Node3D
var roof: Node3D
var footprint: MeshInstance3D
var status_label: Label
var top_down := false
var mouse_captured := false
var door_open := false
var self_test_mode := false
var doors: Array[Node3D] = []
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

func _ready() -> void:
	_setup_world()
	_setup_building()
	_setup_collision()
	_setup_player()
	_setup_cameras()
	_setup_ui()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mouse_captured = true
	_update_roof()
	if OS.get_cmdline_user_args().has("--shop-self-test"):
		call_deferred("_run_self_test")

func _run_self_test() -> void:
	var failures: Array[String] = []
	await get_tree().physics_frame
	if model == null: failures.append("GLB model failed to instantiate")
	if roof == null: failures.append("Roof_Meshy node was not found")
	if doors.size() < 3: failures.append("Expected interactive door pivots were not found")
	if get_node_or_null("Simplified building collision") == null: failures.append("Building collision body is missing")
	if not Stad.KINDS.has("tropical_shop_a") or not Stad.ORDER["gebouw"].has("tropical_shop_a") or not Stad.available("tropical_shop_a"):
		failures.append("Tropical Shop A is missing from the city editor building palette")
	else:
		var city := Stad.new()
		city.name = "Temporary city editor placement test"
		add_child(city)
		var placement := {"k": "tropical_shop_a", "x": 18.0, "z": 0.0, "r": 1, "m": 0}
		city._make_node(placement)
		await get_tree().process_frame
		var placed := placement.get("node") as Woonhuis
		if placed == null or placed.kind != "tropical_shop_a" or placed.model == null:
			failures.append("The city editor could not instantiate the placed building")
		elif placed.doors.size() < 7 or placed._guard_body == null or placed._meubels.size() < 2:
			failures.append("The placed city building is missing doors, collision, or interior furniture collision")
		else:
			placed._inside = 0
			placed._apply_view()
			if placed._dak.visible or placed.model.find_child("Exterior_Walls_Ground", true, false).visible or placed.model.find_child("Upper_Floor", true, false).visible:
				failures.append("City runtime did not hide the roof and upper level on the ground floor")
			placed._inside = 1
			placed._apply_view()
			if placed._dak.visible or placed.model.find_child("Ground_Floor", true, false).visible or not placed.model.find_child("Accessible_Balcony", true, false).visible:
				failures.append("City runtime did not expose the upper floor cutaway and balcony")
			placed._inside = -1
			placed._apply_view()
		city.queue_free()
	# The front entrance must stay clear at character height, while the adjacent wall blocks movement.
	var entrance := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.25, 5.0))
	if player.test_move(entrance, Vector3(0.0, 0.0, -2.5)):
		failures.append("Character capsule is blocked at the front entrance")
	var wall_test := Transform3D(Basis.IDENTITY, Vector3(4.7, 0.25, 5.0))
	if not player.test_move(wall_test, Vector3(0.0, 0.0, -2.5)):
		failures.append("Front exterior wall does not block character movement")
	# A ray through the open entrance must reach the interior without hitting an invisible wall.
	var ray := PhysicsRayQueryParameters3D.create(Vector3(0.0, 1.1, 4.1), Vector3(0.0, 1.1, 0.0), 1)
	if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		failures.append("Interior ray is blocked through the open entrance")
	var balcony_ray := PhysicsRayQueryParameters3D.create(Vector3(0.0, FLOOR1 + 0.8, D * 0.5 + 1.15), Vector3(0.0, FLOOR1 - 0.1, D * 0.5 + 1.15), 1)
	if get_world_3d().direct_space_state.intersect_ray(balcony_ray).is_empty():
		failures.append("Accessible balcony has no walkable collision surface")
	# Walk from the stair foot to the second floor on the simplified collision ramp.
	self_test_mode = true
	player.global_position = Vector3(-3.25, 0.22, -3.35)
	player.velocity = Vector3.ZERO
	for frame in range(240):
		if not player.is_on_floor(): player.velocity.y -= gravity / 60.0
		else: player.velocity.y = 0.0
		player.velocity.z = 2.2
		player.velocity.x = 0.0
		player.move_and_slide()
		await get_tree().physics_frame
	if player.global_position.y < FLOOR1 - 0.4 or player.global_position.z < 1.3:
		failures.append("Character did not reach the upper floor via the staircase")
	self_test_mode = false
	# Exercise the independent top-down camera toggle.
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	_unhandled_input(tab)
	if not top_down or not build_camera.current or not footprint.visible:
		failures.append("Top-down build camera or placement footprint did not activate")
	tab = InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	_unhandled_input(tab)
	if top_down or not game_camera.current:
		failures.append("Third-person camera did not restore")
	# Animate a nearby actual GLB door pivot and check that its angle changes.
	player.global_position = Vector3(0.0, 0.22, 5.1)
	_toggle_nearest_door()
	await get_tree().create_timer(0.45).timeout
	var door_animated := false
	for door in doors:
		if absf(door.rotation.y) > 0.5: door_animated = true
	if not door_open or not door_animated:
		failures.append("Nearby door did not animate open")
	if failures.is_empty():
		print("TROPICAL_SHOP_A_SELF_TEST: PASS — GLB, city editor placement, doors, collision, furniture, stair traversal, balcony, interior ray, cameras")
	else:
		for failure in failures: push_error("TROPICAL_SHOP_A_SELF_TEST: " + failure)
		print("TROPICAL_SHOP_A_SELF_TEST: FAIL — ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)

func _setup_world() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.24, 0.37, 0.43)
	sky_material.sky_horizon_color = Color(0.73, 0.76, 0.66)
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.66, 0.61)
	environment.ambient_light_energy = 0.7
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "Tropical daylight"
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	ground.name = "Test ground visual"
	var plane := PlaneMesh.new()
	plane.size = Vector2(100.0, 100.0)
	ground.mesh = plane
	ground.position.y = -0.14
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.22, 0.25, 0.19)
	ground_mat.roughness = 0.96
	ground.material_override = ground_mat
	add_child(ground)
	var floor_body := StaticBody3D.new()
	floor_body.name = "Test ground collision"
	floor_body.collision_layer = 1
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100.0, 0.25, 100.0)
	floor_shape.shape = box
	floor_shape.position.y = -0.13
	floor_body.add_child(floor_shape)
	add_child(floor_body)

func _setup_building() -> void:
	var packed := load(MODEL_PATH) as PackedScene
	if packed == null:
		push_error("Tropical Shop A GLB failed to load: " + MODEL_PATH)
		return
	model = packed.instantiate() as Node3D
	model.name = "Tropical_Shop_A_Model"
	add_child(model)
	roof = _find_named(model, "Roof_Meshy")
	for node in _all_nodes(model):
		var lower := String(node.name).to_lower()
		if lower.contains("door") and lower.contains("pivot") and node is Node3D:
			doors.append(node as Node3D)

func _setup_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "Simplified building collision"
	body.collision_layer = 1
	body.collision_mask = 1
	add_child(body)
	_box(body, "Ground floor", Vector3(0, 0.10, 0), Vector3(W, 0.22, D))
	_box(body, "Accessible balcony deck", Vector3(0.0, FLOOR1, D * 0.5 + 1.15), Vector3(4.1, 0.24, 1.65))
	_box(body, "Balcony front rail collision", Vector3(0.0, FLOOR1 + 0.52, D * 0.5 + 1.93), Vector3(4.05, 1.10, 0.12))
	for side in [-1.0, 1.0]:
		_box(body, "Balcony return rail collision", Vector3(side * 2.03, FLOOR1 + 0.52, D * 0.5 + 0.78), Vector3(0.12, 1.10, 1.15))
	# Upper floor panels leave a real stair opening at the west/rear side.
	var hx0 := -3.95
	var hx1 := -2.55
	var hz0 := -2.75
	var hz1 := 1.75
	_box(body, "Upper floor west panel", Vector3((-W * 0.5 + hx0) * 0.5, FLOOR1 - 0.08, 0), Vector3(hx0 + W * 0.5, 0.22, D - 0.24))
	_box(body, "Upper floor east panel", Vector3((hx1 + W * 0.5) * 0.5, FLOOR1 - 0.08, 0), Vector3(W * 0.5 - hx1, 0.22, D - 0.24))
	_box(body, "Upper floor front panel", Vector3((hx0 + hx1) * 0.5, FLOOR1 - 0.08, (D * 0.5 + hz1) * 0.5), Vector3(hx1 - hx0, 0.22, D * 0.5 - hz1))
	_box(body, "Upper floor rear panel", Vector3((hx0 + hx1) * 0.5, FLOOR1 - 0.08, (-D * 0.5 + hz0) * 0.5), Vector3(hx1 - hx0, 0.22, hz0 + D * 0.5))
	# Openings use exactly the same centers and dimensions as the Blender shell.
	_wall_y(body, "Front ground", D * 0.5 - 0.07, 0.22, 3.38, -W * 0.5 + 0.05, W * 0.5 - 0.05,
		[[-3.28, 1.30, 0.92, 2.52], [0.0, 1.52, 0.02, 2.40], [3.28, 1.30, 0.92, 2.52]])
	_wall_y(body, "Rear ground", -D * 0.5 + 0.07, 0.22, 3.38, -W * 0.5 + 0.05, W * 0.5 - 0.05, [[2.5, 1.22, 0.02, 2.35]])
	_wall_x(body, "West ground", -W * 0.5 + 0.07, 0.22, 3.38, -D * 0.5 + 0.05, D * 0.5 - 0.05, [[0.35, 1.15, 1.05, 2.45], [-2.4, 1.0, 1.05, 2.45]])
	_wall_x(body, "East ground", W * 0.5 - 0.07, 0.22, 3.38, -D * 0.5 + 0.05, D * 0.5 - 0.05, [[0.35, 1.15, 1.05, 2.45], [-2.4, 1.0, 1.05, 2.45]])
	_wall_y(body, "Front upper", D * 0.5 - 0.07, FLOOR1, TOP, -W * 0.5 + 0.05, W * 0.5 - 0.05,
		[[-3.18, 1.28, 4.45, 5.95], [0.0, 1.56, FLOOR1 + 0.02, 6.02], [3.18, 1.28, 4.45, 5.95]])
	_wall_y(body, "Rear upper", -D * 0.5 + 0.07, FLOOR1, TOP, -W * 0.5 + 0.05, W * 0.5 - 0.05,
		[[-1.5, 1.0, 4.55, 5.80], [2.4, 1.0, 4.55, 5.80]])
	_wall_x(body, "West upper", -W * 0.5 + 0.07, FLOOR1, TOP, -D * 0.5 + 0.05, D * 0.5 - 0.05, [[0.6, 1.15, 4.5, 5.85], [-2.25, 1.15, 4.5, 5.85]])
	_wall_x(body, "East upper", W * 0.5 - 0.07, FLOOR1, TOP, -D * 0.5 + 0.05, D * 0.5 - 0.05, [[0.6, 1.15, 4.5, 5.85], [-2.25, 1.15, 4.5, 5.85]])
	# One simplified sloped collision surface follows the visible 18 timber treads.
	var stair_shape := ConvexPolygonShape3D.new()
	stair_shape.points = PackedVector3Array([
		Vector3(-3.25 - 0.575, 0.20, -2.97), Vector3(-3.25 - 0.575, FLOOR1, 1.46), Vector3(-3.25 - 0.575, 0.20, 1.46),
		Vector3(-3.25 + 0.575, 0.20, -2.97), Vector3(-3.25 + 0.575, FLOOR1, 1.46), Vector3(-3.25 + 0.575, 0.20, 1.46)
	])
	var stair_collision := CollisionShape3D.new()
	stair_collision.name = "Walkable staircase ramp collision"
	stair_collision.shape = stair_shape
	body.add_child(stair_collision)

func _wall_y(body: StaticBody3D, label: String, z: float, low: float, high: float, xmin: float, xmax: float, openings: Array) -> void:
	var cuts: Array[float] = [xmin, xmax]
	for opening in openings:
		cuts.append(opening[0] - opening[1] * 0.5)
		cuts.append(opening[0] + opening[1] * 0.5)
	cuts.sort()
	for index in range(cuts.size() - 1):
		var a: float = cuts[index]
		var b: float = cuts[index + 1]
		if b - a < 0.02: continue
		var center := (a + b) * 0.5
		var aperture: Array = []
		for opening in openings:
			if center > opening[0] - opening[1] * 0.5 and center < opening[0] + opening[1] * 0.5:
				aperture = opening
				break
		if aperture.is_empty():
			_box(body, label, Vector3((a + b) * 0.5, (low + high) * 0.5, z), Vector3(b - a, high - low, WALL))
		else:
			if aperture[2] > low + 0.03:
				_box(body, label + " sill", Vector3(center, (low + aperture[2]) * 0.5, z), Vector3(b - a, aperture[2] - low, WALL))
			if aperture[3] < high - 0.03:
				_box(body, label + " lintel", Vector3(center, (aperture[3] + high) * 0.5, z), Vector3(b - a, high - aperture[3], WALL))

func _wall_x(body: StaticBody3D, label: String, x: float, low: float, high: float, zmin: float, zmax: float, openings: Array) -> void:
	var cuts: Array[float] = [zmin, zmax]
	for opening in openings:
		cuts.append(opening[0] - opening[1] * 0.5)
		cuts.append(opening[0] + opening[1] * 0.5)
	cuts.sort()
	for index in range(cuts.size() - 1):
		var a: float = cuts[index]
		var b: float = cuts[index + 1]
		if b - a < 0.02: continue
		var center := (a + b) * 0.5
		var aperture: Array = []
		for opening in openings:
			if center > opening[0] - opening[1] * 0.5 and center < opening[0] + opening[1] * 0.5:
				aperture = opening
				break
		if aperture.is_empty():
			_box(body, label, Vector3(x, (low + high) * 0.5, center), Vector3(WALL, high - low, b - a))
		else:
			if aperture[2] > low + 0.03:
				_box(body, label + " sill", Vector3(x, (low + aperture[2]) * 0.5, center), Vector3(WALL, aperture[2] - low, b - a))
			if aperture[3] < high - 0.03:
				_box(body, label + " lintel", Vector3(x, (aperture[3] + high) * 0.5, center), Vector3(WALL, high - aperture[3], b - a))

func _box(parent: Node3D, node_name: String, pos: Vector3, size: Vector3) -> void:
	var collision := CollisionShape3D.new()
	collision.name = node_name
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = pos
	parent.add_child(collision)

func _setup_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Third-person soldier"
	player.position = Vector3(0, 0.22, D * 0.5 + 3.5)
	player.collision_layer = 2
	player.collision_mask = 1
	var capsule := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.34
	shape.height = 1.82
	capsule.shape = shape
	capsule.position.y = 0.91
	player.add_child(capsule)
	var soldier_scene := load(SOLDIER_PATH) as PackedScene
	if soldier_scene:
		var soldier := soldier_scene.instantiate() as Node3D
		soldier.name = "Existing VQ2 soldier model"
		soldier.position.y = 0.02
		player.add_child(soldier)
	else:
		var fallback := MeshInstance3D.new()
		var mesh := CapsuleMesh.new()
		mesh.radius = 0.32
		mesh.height = 1.75
		fallback.mesh = mesh
		fallback.position.y = 0.9
		player.add_child(fallback)
	add_child(player)

func _setup_cameras() -> void:
	pivot = Node3D.new()
	pivot.name = "Camera yaw and pitch"
	pivot.position = Vector3(0, 1.45, 0)
	player.add_child(pivot)
	spring = SpringArm3D.new()
	spring.name = "Collision-safe third-person boom"
	spring.spring_length = 4.8
	spring.margin = 0.15
	spring.collision_mask = 1
	pivot.add_child(spring)
	game_camera = Camera3D.new()
	game_camera.name = "Third-person camera"
	game_camera.current = true
	game_camera.fov = 62.0
	spring.add_child(game_camera)
	build_camera = Camera3D.new()
	build_camera.name = "Top-down building camera"
	build_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	build_camera.size = 19.0
	build_camera.position = Vector3(0, 21, 0)
	build_camera.rotation_degrees = Vector3(-90, 0, 0)
	add_child(build_camera)
	var preview := BoxMesh.new()
	preview.size = Vector3(W + 0.2, 0.035, D + 0.2)
	footprint = MeshInstance3D.new()
	footprint.name = "Placement footprint preview"
	footprint.mesh = preview
	footprint.position.y = 0.04
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.24, 0.84, 0.58, 0.24)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	footprint.material_override = material
	footprint.visible = false
	add_child(footprint)

func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Showcase controls"
	add_child(layer)
	status_label = Label.new()
	status_label.position = Vector2(18, 18)
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_color", Color(0.93, 0.94, 0.83))
	layer.add_child(status_label)
	var note := Label.new()
	note.text = "WASD bewegen · muis kijken · E deur · klik schieten · Tab bouwcamera · Esc cursor"
	note.position = Vector2(18, 52)
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", Color(0.86, 0.88, 0.76))
	layer.add_child(note)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			mouse_captured = not mouse_captured
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mouse_captured else Input.MOUSE_MODE_VISIBLE
		elif event.keycode == KEY_TAB:
			top_down = not top_down
			build_camera.current = top_down
			game_camera.current = not top_down
			footprint.visible = top_down
			_update_roof()
		elif event.keycode == KEY_E:
			_toggle_nearest_door()
	if event is InputEventMouseMotion and mouse_captured and not top_down:
		pivot.rotation.y -= event.relative.x * 0.0028
		spring.rotation.x = clampf(spring.rotation.x - event.relative.y * 0.0024, -1.12, 0.2)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not top_down:
		_fire_ray()

func _physics_process(delta: float) -> void:
	if self_test_mode: return
	if player == null: return
	var input_dir := Vector2.ZERO
	input_dir.x = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	input_dir.y = float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
	var forward := -pivot.global_basis.z
	forward.y = 0
	forward = forward.normalized()
	var right := pivot.global_basis.x
	right.y = 0
	right = right.normalized()
	var direction := (right * input_dir.x + forward * input_dir.y).normalized()
	var speed := 4.2 if not Input.is_key_pressed(KEY_SHIFT) else 6.0
	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed
	if not player.is_on_floor():
		player.velocity.y -= gravity * delta
	elif Input.is_key_pressed(KEY_SPACE):
		player.velocity.y = 4.7
	player.move_and_slide()
	_update_roof()
	status_label.text = ("BOUWMODUS · dak zichtbaar · plaatsingscontour" if top_down else ("BINNEN · dak verborgen" if _inside_building() else "DERDEPERSOON · dak zichtbaar"))

func _inside_building() -> bool:
	if player == null: return false
	return absf(player.position.x) < W * 0.5 and absf(player.position.z) < D * 0.5 and player.position.y < 9.5

func _update_roof() -> void:
	if roof:
		roof.visible = top_down or not _inside_building()

func _toggle_nearest_door() -> void:
	if doors.is_empty():
		status_label.text = "Geen deurpivot gevonden in de GLB-scene"
		return
	var nearest: Node3D
	var best := 3.2
	for door in doors:
		var distance := door.global_position.distance_to(player.global_position)
		if distance < best:
			best = distance
			nearest = door
	if nearest == null:
		status_label.text = "Geen deur binnen bereik"
		return
	door_open = not door_open
	var target := nearest.rotation
	target.y = deg_to_rad(92.0 if door_open else 0.0)
	var tween := create_tween()
	tween.tween_property(nearest, "rotation", target, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	status_label.text = "Deur open" if door_open else "Deur dicht"

func _fire_ray() -> void:
	var origin := game_camera.global_position
	var end := origin + -game_camera.global_basis.z * 55.0
	var query := PhysicsRayQueryParameters3D.create(origin, end, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	status_label.text = "Schot raakt: " + String(hit.collider.name) if not hit.is_empty() else "Schot door open ruimte · 55 m"

func _all_nodes(root: Node) -> Array[Node]:
	var result: Array[Node] = [root]
	for child in root.get_children(): result.append_array(_all_nodes(child))
	return result

func _find_named(root: Node, target: String) -> Node3D:
	for node in _all_nodes(root):
		if String(node.name).to_lower().replace(" ", "_") == target.to_lower():
			return node as Node3D
	return null
