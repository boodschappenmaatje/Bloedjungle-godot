extends SceneTree
## Actual runtime model contracts: placement/collision, tower climb/hide, and jeep clips/drive.
var failures: Array[String] = []
var lab: Node3D


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("VQ2 TEST FAIL: " + message)


func frames(n: int) -> void:
	for _i in n:
		await physics_frame


func _run() -> void:
	lab = load("res://scenes/vq2_showcase.tscn").instantiate()
	root.add_child(lab)
	for _i in 600:
		if lab.get("is_ready"):
			break
		await process_frame
	check(bool(lab.get("is_ready")), "showcase did not start the existing world")
	if not lab.get("is_ready"):
		quit(1)
		return
	var game: Node = root.get_node("Game")
	await frames(2)
	for menu in get_nodes_in_group("menus"):
		if menu is CanvasLayer or menu is CanvasItem:
			check(not menu.visible, "main menu obscures the interactive showcase")
	var player: CharacterBody3D = lab.get("player")
	lab.get("main").get_node("Hud/Sticks").set_process(false)
	player.set_physics_process(false)
	for name in ["kazerne", "wachttoren", "legerjeep"]:
		lab.call("select_asset", name, "v2")
		await frames(2)
		var subject: Node3D = lab.get("subject")
		var maps := 0
		for mesh: MeshInstance3D in subject.find_children("*", "MeshInstance3D", true, false):
			check(mesh.mesh != null, name + " missing mesh")
			for surface in mesh.mesh.get_surface_count():
				var material := mesh.get_active_material(surface)
				if material is StandardMaterial3D and material.resource_name.begins_with("VQ2_"):
					check(mesh.get_surface_override_material(surface) == null, name + " VQ2 material replaced by legacy Kit.skin")
					check(material.albedo_texture != null and material.normal_texture != null and material.roughness_texture != null, name + " incomplete PBR maps")
					check(material.albedo_texture.resource_path.begins_with("res://assets/textures/vq2/"), name + " duplicates embedded textures instead of sharing the runtime texture set")
					check(material.roughness_texture == material.metallic_texture, name + " ORM texture is not shared")
					maps += 1
		check(maps >= 3, name + " missing imported VQ2 PBR surfaces")
		if name == "legerjeep":
			check(subject is StaticBody3D, "static jeep is no longer StaticBody3D")
			var collision: CollisionShape3D = subject.get_node("BodyCollision")
			check(collision.shape.size.is_equal_approx(Vector3(1.5, .85, 3.4)), "static jeep collision changed")
		if name == "wachttoren":
			var tower: Node3D = lab.get("tower")
			var roof: Node3D = tower.find_child("Toren_dak", true, false)
			var rib: Node3D = tower.find_child("Toren_dakrib", true, false)
			check(roof != null and rib != null, "tower roof node names changed")
			var deck_vertices := 0
			for mesh: MeshInstance3D in tower.find_children("Toren_plank*", "MeshInstance3D", true, false):
				for surface in mesh.mesh.get_surface_count():
					var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
					for point in vertices:
						var local := tower.to_local(mesh.to_global(point))
						if absf(local.y - 5.3) < .002 and absf(local.x) < 1.1 and absf(local.z) > 1.32 and absf(local.z) < 1.37:
							deck_vertices += 1
			check(deck_vertices > 20, "actual platform geometry is not at 5.3m")
			player.global_position = tower.to_global(Vector3(1.8, 0, 0))
			player.set("climb_cd", 0.0)
			player.call("_find_stairs", Vector2(-1, 0))
			check(float(player.get("climb")) >= 0.0, "+X tower ladder does not engage")
			check(not roof.visible and not rib.visible, "roof did not hide on climb")
			for _i in 400:
				if float(player.get("climb")) < 0.0:
					break
				player.call("_climb_step", 1.0 / 60.0)
			check(is_equal_approx(float(player.get("elev")), 5.3), "tower climb does not reach 5.3m deck")
			player.global_position = tower.to_global(Vector3(1.35, 5.3, 0))
			player.set("climb_cd", 0.0)
			player.call("_on_deck", Vector2(1, 0))
			for _i in 400:
				if float(player.get("climb")) < 0.0:
					break
				player.call("_climb_step", 1.0 / 60.0)
			check(is_zero_approx(float(player.get("elev"))) and roof.visible and rib.visible, "descent does not restore roof/collision")
			check(player.collision_mask == int(player.get("_mask0")), "climb collision mask not restored")
		lab.call("select_asset", name, "v1")
		await frames(1)
		check(lab.get("subject") != null, name + " V1 comparison failed to load")
	# Placement still uses the original Buildings path and size, not a showcase-only mesh.
	game.set("points", 10000)
	game.set("build_credit", 10000)
	var builds: Node = game.get("builds")
	var placed: Variant = builds.call("place", "kazerne", Vector3(-6, 0, -8), PI)
	check(placed != null, "existing barracks placement failed")
	if placed != null:
		var collider: CollisionShape3D = placed.node.get_child(0)
		check(collider.shape.size.is_equal_approx(Vector3(4.4, 2.2, 3.2)), "barracks footprint changed")
	# Verify original exported animation tracks visibly transform real jeep nodes.
	var raw: Node3D = load("res://assets/jeep.glb").instantiate()
	root.add_child(raw)
	var anim: AnimationPlayer = raw.get_node("AnimationPlayer")
	for clip in ["Stationair", "Rijden", "Achteruit", "Bocht", "Remmen", "Vuren", "Rondkijken"]:
		check(anim.has_animation(clip), "missing playable jeep clip " + clip)
	anim.play("Rijden")
	anim.seek(.07, true)
	var wheel: Node3D = raw.get_node("Jeep/Body/StuurLV/WielLV")
	var first := wheel.transform
	anim.seek(.18, true)
	check(not first.is_equal_approx(wheel.transform), "Rijden lists a clip but wheel does not rotate")
	anim.play("Bocht")
	anim.seek(.6, true)
	check(raw.get_node("Jeep/Body/StuurLV").rotation.length() > .15, "Bocht does not steer front wheels")
	anim.play("Vuren")
	anim.seek(0, true)
	var mg: Node3D = raw.get_node("Jeep/Body/Geschut/MG")
	first = mg.transform
	anim.seek(.06, true)
	check(not first.is_equal_approx(mg.transform), "Vuren has no MG recoil")
	raw.queue_free()
	lab.call("select_asset", "jeep")
	var picker: OptionButton = lab.get("clips")
	var demo: AnimationPlayer = lab.get("demo_anim")
	for clip in ["Bocht", "Rijden"]:
		for i in picker.item_count:
			if picker.get_item_text(i) == clip:
				picker.select(i)
		lab.call("play_clip")
		demo.seek(.6 if clip == "Bocht" else 0.0, true)
		var steering: Node3D = lab.get("subject").get_node("Model/Jeep/Body/StuurLV")
		check(steering.rotation.length() > .15 if clip == "Bocht" else steering.rotation.length() < .001, "switching jeep clips does not restore the real rest pose")
	lab.call("drive")
	var jeep: CharacterBody3D = lab.get("subject")
	check(bool(jeep.get("driven")), "showcase cannot enter actual playable jeep")
	var start := jeep.global_position
	game.set("move", Vector2(0, -1))
	await frames(90)
	check(jeep.global_position.distance_to(start) > 1.0, "actual drive code does not move the jeep")
	game.set("move", Vector2.ZERO)
	jeep.call("_toggle")
	check(not bool(player.get("driving")), "cannot exit playable jeep")
	lab.queue_free()
	await process_frame
	if failures.is_empty():
		print("VQ2 TEST PASS: PBR import, V1/V2 loading, barracks placement/collision, tower 5.3m climb/roof visibility, jeep clips and actual drive/exit")
		quit(0)
	else:
		quit(1)
