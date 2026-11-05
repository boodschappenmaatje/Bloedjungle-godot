extends SceneTree
## Meshy wall, perimeter, collision, gate and projectile regression.

const WALL_SCENE := "res://assets/base_wall_hq2.glb"

var failures := 0
var kit: GDScript
var data: GDScript
var props: GDScript
var rules: GDScript
var bullet_script: GDScript
var gates_script: GDScript
var barrel_script: GDScript
var artillery_script: GDScript
var grenade_script: GDScript
var tank_script: GDScript
var camera_script: GDScript


class DamageProbe extends Node3D:
	var hit_count := 0
	var t: Dictionary = {"r": 0.4}
	var dead := false

	func hit(_damage: float, _direction: Vector3, _explosive := false) -> void:
		hit_count += 1


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	if ok:
		print("PASS base-wall: ", label)
	else:
		failures += 1
		push_error("FAIL base-wall: " + label)


func _quit_after_cleanup(exit_code: int) -> void:
	await process_frame
	quit(exit_code)


func _ray(stage: Node3D, from: Vector3, to: Vector3, mask: int) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, mask)
	return stage.get_world_3d().direct_space_state.intersect_ray(query)


func _run() -> void:
	# Load game scripts after the project autoloads are live. This keeps the
	# regression runnable through Godot's existing --script CI convention.
	kit = load("res://scripts/kit.gd") as GDScript
	data = load("res://scripts/data.gd") as GDScript
	props = load("res://scripts/base_props.gd") as GDScript
	rules = load("res://scripts/base_wall_rules.gd") as GDScript
	bullet_script = load("res://scripts/bullet.gd") as GDScript
	gates_script = load("res://scripts/gates.gd") as GDScript
	barrel_script = load("res://scripts/barrel.gd") as GDScript
	artillery_script = load("res://scripts/artillerie.gd") as GDScript
	grenade_script = load("res://scripts/grenade.gd") as GDScript
	tank_script = load("res://scripts/tank.gd") as GDScript
	camera_script = load("res://scripts/camera_rig.gd") as GDScript
	var export_text := FileAccess.get_file_as_string("res://export_presets.cfg")
	_check(export_text.contains("source_assets/base_wall_hq2/*"), "verified Meshy source stays out of runtime exports and OTA PCKs")
	_check(export_text.contains("assets/base_wall_hq2_*"), "Godot-extracted GLB sidecars stay out while the embedded-texture wall GLB ships")
	var importer_text := FileAccess.get_file_as_string("res://assets/base_wall_hq2.glb.import")
	_check(importer_text.contains("gltf/embedded_image_handling=2"), "wall PBR textures stay Basis-compressed and embedded without loose texture files")
	var wall_mask: int = int(kit.get("LAYER_WALL")) | int(kit.get("LAYER_FORTIFICATION"))
	var packed := load(WALL_SCENE) as PackedScene
	_check(packed != null, "optimized GLB imports as a PackedScene")
	if packed == null:
		quit(1)
		return
	var asset := packed.instantiate()
	var meshes: Dictionary = {}
	for node in asset.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		meshes[instance.name] = instance.mesh
	for name in ["Wall_LOD0", "Wall_LOD1", "Wall_LOD2"]:
		_check(meshes.has(name), name + " exists")
	if meshes.size() == 3:
		var shared_materials: Array[Material] = []
		for lod_name in ["Wall_LOD0", "Wall_LOD1", "Wall_LOD2"]:
			var mesh: Mesh = meshes[lod_name] as Mesh
			var bounds: Vector3 = mesh.get_aabb().size
			_check(bounds.distance_to(Vector3(3.5, 3.0, 0.4)) < 0.015, "%s dimensions are 3.5 x 3.0 x 0.4 m" % lod_name)
			for surface in mesh.get_surface_count():
				var material := mesh.surface_get_material(surface)
				if material != null and not shared_materials.has(material):
					shared_materials.append(material)
			_check(mesh.get_surface_count() == 2, "%s has Meshy concrete and jute sandbag surfaces" % lod_name)
			if lod_name == "Wall_LOD0" and mesh.get_surface_count() == 2:
				for surface in mesh.get_surface_count():
					var pbr := mesh.surface_get_material(surface) as StandardMaterial3D
					_check(pbr != null and pbr.albedo_texture != null and pbr.normal_texture != null, "LOD0 surface %d retains embedded albedo and normal PBR maps" % surface)
					if pbr != null and pbr.albedo_texture != null:
						_check(maxi(pbr.albedo_texture.get_width(), pbr.albedo_texture.get_height()) <= 2048, "LOD0 surface %d uses a mobile sized 2K-or-smaller albedo" % surface)
		var tri0: int = int((meshes["Wall_LOD0"] as Mesh).get_faces().size() / 3)
		var tri1: int = int((meshes["Wall_LOD1"] as Mesh).get_faces().size() / 3)
		var tri2: int = int((meshes["Wall_LOD2"] as Mesh).get_faces().size() / 3)
		_check(shared_materials.size() == 2, "three LODs reuse only two material resources")
		_check(tri0 >= 6000 and tri0 <= 10000, "LOD0 triangle budget: %d" % tri0)
		_check(tri1 >= 1500 and tri1 <= 3000, "LOD1 triangle budget: %d" % tri1)
		_check(tri2 >= 300 and tri2 <= 800, "LOD2 triangle budget: %d" % tri2)
	asset.free()

	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	props.call("_wall", stage)
	var wall_body := stage.get_node_or_null("BaseHighWallCollision") as StaticBody3D
	_check(wall_body != null, "one low-cost shared StaticBody3D owns the perimeter colliders")
	if wall_body == null:
		quit(1)
		return
	_check(wall_body.collision_layer == wall_mask, "perimeter uses wall and high-fortification collision layers")
	_check(wall_body.get_child_count() == 6, "six continuous wall spans leave only the two gate openings")
	var lod_counts := [0, 0, 0]
	var visual_nodes := 0
	var checked_visual_spans: Dictionary = {}
	var lod_bounds: Dictionary = {}
	for child in stage.get_children():
		if child is MultiMeshInstance3D and child.name.begins_with("Wall_"):
			visual_nodes += 1
			var lod := 0 if child.name.ends_with("Wall_LOD0") else (1 if child.name.ends_with("Wall_LOD1") else 2)
			lod_counts[lod] += child.multimesh.instance_count
			var bounds: AABB = child.multimesh.custom_aabb
			var bounds_span := str(child.get_meta("wall_span", ""))
			_check(bounds.has_volume(), "wall LOD supplies explicit nonempty visibility bounds")
			if lod_bounds.has(bounds_span):
				_check(bounds == lod_bounds[bounds_span], "all LODs of %s have the same range centre and culling bounds" % bounds_span)
			else:
				lod_bounds[bounds_span] = bounds
			# The headless dummy RenderingServer does not retain MultiMesh transforms.
			var expected_transforms: Array = props.call("_wall_module_transforms", child.get_meta("wall_start"), child.get_meta("wall_end"), child.get_meta("wall_yaw"))
			for transform: Transform3D in expected_transforms:
				var actual: AABB = transform * child.multimesh.mesh.get_aabb()
				_check(bounds.grow(0.001).encloses(actual), "shared bounds contain every module without culling its edges")
			_check(is_equal_approx(child.visibility_range_begin, [0.0, 28.0, 58.0][lod]) and is_zero_approx(child.visibility_range_end), "" + child.name + " uses a begin range with a visibility parent")
			_check(is_equal_approx(child.visibility_range_begin_margin, 1.5 if lod > 0 else 0.0) and is_zero_approx(child.visibility_range_end_margin), "wall LOD transitions have one shared hysteresis decision")
			if lod < 2:
				var parent_lod := child.get_node_or_null(child.visibility_parent) as MultiMeshInstance3D
				_check(parent_lod != null and parent_lod.get_meta("wall_span") == child.get_meta("wall_span") and parent_lod.name.ends_with("Wall_LOD%d" % (lod + 1)), "LOD fallback references the next coarser mesh of the same span")
			_check(child.visibility_range_fade_mode == GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED and child.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "wall LODs do not create flickering independent shadow maps")
			if lod == 0:
				var span: String = str(child.get_meta("wall_span", ""))
				var along_x := span.begins_with("north") or span.begins_with("south")
				var span_axis := Vector3.RIGHT if along_x else Vector3.BACK
				var projected_centers: Array[float] = []
				var direction_ok := true
				var transforms: Array = props.call("_wall_module_transforms", child.get_meta("wall_start"), child.get_meta("wall_end"), child.get_meta("wall_yaw"))
				for instance_transform: Transform3D in transforms:
					direction_ok = direction_ok and absf(instance_transform.basis.x.normalized().dot(span_axis)) > 0.999
					projected_centers.append(instance_transform.origin.dot(span_axis))
				projected_centers.sort()
				var pitch_ok: bool = transforms.size() == child.multimesh.instance_count and is_equal_approx((child.multimesh.mesh as Mesh).get_aabb().size.x, 3.5)
				for i in range(1, projected_centers.size()):
					pitch_ok = pitch_ok and absf(absf(projected_centers[i] - projected_centers[i - 1]) - 3.5) < 0.001
				_check(direction_ok and pitch_ok, "%s LOD0 modules follow the correct axis at a gap-free 3.5 m pitch" % span)
				checked_visual_spans[span] = true
	_check(visual_nodes == 18, "six perimeter spans each share three LOD MultiMeshes")
	_check(lod_counts == [60, 60, 60], "60 modules cover the four sides, excluding both portals")
	_check(checked_visual_spans.size() == 6, "all six sides have validated wall axes and contiguous module bounds")
	var berm := stage.get_node_or_null("BaseWallEarthBerm") as MultiMeshInstance3D
	_check(berm != null and berm.multimesh.instance_count == 6, "one shared six-instance earth berm follows the wall spans and leaves both portals open")
	# Elke bermstrook moet langs zijn eigen muur liggen, niet 90 graden gedraaid dwars door de basis
	# (dat gaf de flikkerende streep op z = 0). Headless bewaart geen MultiMesh-data, dus de plaatsing zelf testen.
	var berm_box := AABB(Vector3(-0.5, 0.0, -0.41), Vector3(1.0, 0.22, 0.82))
	var berm_inside := true
	for span: Dictionary in props.wall_spans():
		var box: AABB = props.wall_berm_transform(span) * berm_box
		var c: float = data.COMPOUND
		var along_x: bool = span.along_x
		var thin := box.size.z < 1.2 if along_x else box.size.x < 1.2
		var on_wall := absf(absf(box.get_center().z if along_x else box.get_center().x) - c) < 1.0
		var within := box.position.x > -c - 1.0 and box.end.x < c + 1.0 and box.position.z > -c - 1.0 and box.end.z < c + 1.0
		if not (thin and on_wall and within):
			berm_inside = false
			print("berm verkeerd: ", span.name, " ", box)
	_check(berm_inside, "every earth berm strip lies along its own wall (no strip across the compound)")
	var berm_corners := stage.get_node_or_null("BaseWallEarthBermCorners") as MultiMeshInstance3D
	_check(berm_corners != null and berm_corners.multimesh.instance_count == 4, "four shared berm corner caps close the outer foot at each 90 degree join")
	var stable_shadows := stage.find_children("BaseWallShadow_*", "MeshInstance3D", true, false)
	_check(stable_shadows.size() == 6, "six constant SHADOWS_ONLY wall proxies replace LOD-specific shadows")
	for shadow_node in stable_shadows:
		_check((shadow_node as MeshInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY, "shadow proxy cannot render as a second visible wall")
	_check(stage.find_children("*", "MeshInstance3D", true, false).size() == stable_shadows.size(), "no legacy concrete wall meshes remain")

	await physics_frame
	var rays := [
		[Vector3(10, 1.5, -30), Vector3(10, 1.5, -26), "north"],
		[Vector3(10, 1.5, 30), Vector3(10, 1.5, 26), "south"],
		[Vector3(-30, 1.5, 0), Vector3(-26, 1.5, 0), "west"],
		[Vector3(30, 1.5, 0), Vector3(26, 1.5, 0), "east"],
		[Vector3(-30, 1.5, -30), Vector3(-26, 1.5, -26), "northwest corner"],
		[Vector3(-25.5, 1.5, -30), Vector3(-25.5, 1.5, -26), "north segment seam"],
		[Vector3(0, 1.5, -30), Vector3(0, 1.5, -26), "north gate opening"],
	]
	for item in rays:
		var hit := _ray(stage, item[0], item[1], int(kit.get("LAYER_FORTIFICATION")))
		var should_hit: bool = item[2] != "north gate opening"
		_check((not hit.is_empty()) == should_hit, "physics ray %s %s" % [item[2], "hits wall" if should_hit else "passes through portal"])
	var enemy_probe := (load("res://scenes/enemy.tscn") as PackedScene).instantiate()
	enemy_probe.call("setup", "assault", 1)
	stage.add_child(enemy_probe)
	enemy_probe.global_position = Vector3(10, 0, -30)
	_check(not enemy_probe.call("_clear_shot", Vector3(10, 1.3, -26), false), "enemy AI refuses a direct shot through the closed high wall")
	_check(not enemy_probe.call("_clear_shot", Vector3(10, 8.0, -26), false), "enemy AI cannot angle direct fire over the 3 m wall at an elevated target")
	enemy_probe.global_position = Vector3(0, 0, -30)
	_check(enemy_probe.call("_clear_shot", Vector3(0, 1.3, -26), false), "enemy AI has line of sight through the existing gate opening")
	var enemy_game := root.get_node_or_null("Game")
	if enemy_game != null:
		(enemy_game.get("enemies") as Array).erase(enemy_probe)
	enemy_probe.queue_free()
	_check(rules.call("blocks_blast", Vector3(10, 0, -30), Vector3(10, 0, -26)), "blast line is occluded across closed wall")
	_check(rules.call("blocks_blast", Vector3(10, 0, -28), Vector3(10, 0, -26)), "blast originating inside the wall collider cannot leak through to the safe side")
	_check(not rules.call("blocks_blast", Vector3(10, 0, -30), Vector3(14, 0, -30)), "blast line remains open on the same side")
	_check(not tank_script.call("shell_can_damage", Vector3(10, 0, -30), Vector3(10, 0, -26)), "tank shell splash cannot damage a character behind the high wall")
	_check(tank_script.call("shell_can_damage", Vector3(10, 0, -30), Vector3(14, 0, -30)), "tank shell splash still damages on the same side")

	var actor := CharacterBody3D.new()
	actor.name = "CollisionProbe"
	actor.collision_mask = int(kit.get("LAYER_WALL"))
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	actor.add_child(shape)
	actor.position = Vector3(10, 0, -30)
	stage.add_child(actor)
	await physics_frame
	_check(actor.test_move(actor.global_transform, Vector3(0, 1.6, 4.5)), "character capsule cannot cross or jump over the closed 3 m wall")
	var camera := Camera3D.new()
	camera.set_script(camera_script)
	stage.add_child(camera)
	var desired_camera := Vector3(10, 8, -40)
	var camera_after_wall: Vector3 = camera.call("_avoid_obstacles", Vector3(10, 1.2, -26), desired_camera, actor)
	_check(camera_after_wall.distance_to(desired_camera) < 0.001, "camera stays at intended distance beyond an occluding base wall")
	_check(camera.get("_wall_occluded_spans").has("north_east"), "camera identifies the correct wall span without clipping against it")
	camera.call("_apply_wall_occlusion", 1.0)
	var camera_side := stage.get_node("Wall_north_east_Wall_LOD0") as GeometryInstance3D
	var current_renderer := RenderingServer.get_current_rendering_method()
	if current_renderer == "mobile" or current_renderer == "gl_compatibility":
		_check(not camera_side.visible and is_zero_approx(camera_side.transparency), "mobile renderer hides occluded span without unsupported transparency")
	else:
		_check(camera_side.transparency > 0.5, "Forward+ camera obstruction fades only the visible perimeter span")
	_check(camera.call("_mobile_wall_hidden", "probe", true, 0.016), "mobile wall hides when actually occluded")
	_check(camera.call("_mobile_wall_hidden", "probe", false, 0.2), "mobile wall holds visibility state through a brief raycast miss")
	_check(not camera.call("_mobile_wall_hidden", "probe", false, 1.0), "mobile wall becomes visible after release delay")
	_check(wall_body.collision_layer == wall_mask, "camera fade leaves the physical and combat wall collision intact")

	var over_wall = bullet_script.call("fire", stage, Vector3(10, 1.3, -30), 0.0, 80.0, 1.0, 1.0, true, true)
	_check((over_wall.mask & int(kit.get("LAYER_FORTIFICATION"))) != 0, "over_wall bullets retain the high-wall mask")
	_check((over_wall.mask & int(kit.get("LAYER_WALL"))) == 0, "over_wall bullets still pass low cover outside the fortified perimeter")
	_check(not _ray(stage, Vector3(10, 1.3, -30), Vector3(10, 1.3, -26), over_wall.mask).is_empty(), "over_wall bullet ray still hits the high wall")
	for frame in 3:
		await physics_frame
	await process_frame
	_check(not is_instance_valid(over_wall), "actual over_wall projectile terminates at the closed fortification")
	var arcing_ground_bullet = bullet_script.call("fire", stage, Vector3(10, 1.5, -30), 0.0, 80.0, 1.0, 1.0, true, true, 0, 0.0, 0.0, 2.0)
	for frame in 3:
		await physics_frame
		await process_frame
	_check(not is_instance_valid(arcing_ground_bullet), "ground direct fire cannot arc above the 3 m wall")
	var wall_origin_bullet = bullet_script.call("fire", stage, Vector3(10, 1.5, -28), 0.0, 80.0, 1.0, 1.0, true, true)
	await physics_frame
	await process_frame
	_check(not is_instance_valid(wall_origin_bullet), "projectile starting inside the wall collider cannot emerge on the safe side")
	var grenade_path: Dictionary = grenade_script.call("predict", stage.get_world_3d(), Vector3(10, 1.3, -30), Vector3(10, 0.1, -26))
	_check(grenade_path.blocked, "grenade trajectory collides with the high wall")
	var open_grenade_path: Dictionary = grenade_script.call("predict", stage.get_world_3d(), Vector3(0, 1.3, -30), Vector3(0, 0.1, -26))
	_check(not open_grenade_path.blocked, "grenade trajectory remains open through the portal")
	bullet_script.call("fire_rocket", stage, Vector3(10, 1.3, -30), 0.0, 30.0, 3.0)
	var rocket: Node3D
	for child in stage.get_children():
		if child.get_script() == bullet_script and child.get("rocket") == true:
			rocket = child as Node3D
	_check(rocket != null and (int(rocket.get("mask")) & int(kit.get("LAYER_FORTIFICATION"))) != 0, "enemy rocket mask also stops at the high wall")
	if rocket != null:
		rocket.queue_free()

	var gates: Node3D = gates_script.new()
	var game_node := root.get_node_or_null("Game")
	if game_node != null:
		game_node.set("gates", gates)
	_check(game_node != null, "project Game autoload is available")
	stage.add_child(gates)
	await physics_frame
	for gate: Dictionary in gates.get("list"):
		var z: float = gate.sz * float(data.get("COMPOUND"))
		var upper_gate := (gate.panel as Node3D).find_child("FortificationUpperGateLeaf", true, false) as MeshInstance3D
		_check(upper_gate != null and is_equal_approx(upper_gate.mesh.get_aabb().size.y, 1.78) and is_equal_approx(upper_gate.position.y, 2.11), "%s upper gate leaf closes the visual gap to 3 m" % gate.name)
		var from := Vector3(0, 1.0, z + signf(z) * 2.0)
		var to := Vector3(0, 1.0, z - signf(z) * 2.0)
		_check(not _ray(stage, from, to, int(kit.get("LAYER_FORTIFICATION"))).is_empty(), "%s closed gate blocks passage" % gate.name)
		_check(rules.call("blocks_blast", from, to), "%s closed gate blocks blast line" % gate.name)
		var high_from := Vector3(0, 2.5, z + signf(z) * 2.0)
		var high_to := Vector3(0, 2.5, z - signf(z) * 2.0)
		_check(not _ray(stage, high_from, high_to, int(kit.get("LAYER_FORTIFICATION"))).is_empty(), "%s closed upper gate leaf seals 3 m opening" % gate.name)
		gate.open = 1.0
		gates.call("_apply", gate)
		await physics_frame
		_check(_ray(stage, from, to, int(kit.get("LAYER_FORTIFICATION"))).is_empty(), "%s open gate has no invisible collision" % gate.name)
		_check(not rules.call("blocks_blast", from, to), "%s open gate permits line of sight" % gate.name)
		_check(_ray(stage, high_from, high_to, int(kit.get("LAYER_FORTIFICATION"))).is_empty(), "%s open gate upper section also clears" % gate.name)

	var probe := DamageProbe.new()
	probe.position = Vector3(10, 0, -26)
	stage.add_child(probe)
	var original_enemies = game_node.get("enemies")
	game_node.set("enemies", [probe])
	barrel_script.call("area_damage", Vector3(10, 0, -30), 5.0, 100.0)
	_check(probe.hit_count == 0, "ground explosion cannot directly damage a character behind the closed wall")
	probe.position = Vector3(10, 0, -29)
	barrel_script.call("area_damage", Vector3(10, 0, -30), 5.0, 100.0)
	_check(probe.hit_count == 1, "ground explosion still damages characters on the same side")
	probe.position = Vector3(10, 0, -26)
	artillery_script.call("damage_at", Vector3(10, 0, -30))
	_check(probe.hit_count == 2, "overhead artillery retains its explicit wall-bypass gameplay rule")
	game_node.set("enemies", original_enemies)
	game_node.set("gates", null)
	current_scene = null
	stage.queue_free()
	await process_frame

	print("BASE WALL HQ2 TEST %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	call_deferred("_quit_after_cleanup", 0 if failures == 0 else 1)
