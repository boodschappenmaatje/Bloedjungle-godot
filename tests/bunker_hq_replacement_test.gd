extends SceneTree
## Regression contract for the existing bunker gameplay body and the HQ mesh asset.
## Run: godot --headless --path . -s tests/bunker_hq_replacement_test.gd --fixed-fps 60
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error("BUNKER HQ REPLACEMENT TEST: " + description)

func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	_check(scene != null, "main scene ontbreekt")
	if scene == null:
		quit(1)
		return
	var main := scene.instantiate()
	root.add_child(main)
	await process_frame
	var sticks := main.get_node_or_null("Hud/Sticks")
	if sticks != null:
		sticks.set_process(false)
	main.begin()
	for _i in range(8):
		await process_frame

	var bunker := main.find_child("Bunker", true, false) as StaticBody3D
	_check(bunker != null, "gameplay-body Bunker ontbreekt")
	if bunker != null:
		_check(bunker.collision_layer == Kit.LAYER_BUNKER and bunker.collision_mask == 0,
			"bunker collision layer/mask veranderd")
		_check(bunker.get_script() == load("res://scripts/bunker.gd"), "bestaande schadescript ontbreekt")
		var collision := bunker.get_node_or_null("BunkerCollision") as CollisionShape3D
		_check(collision != null, "BunkerCollision ontbreekt")
		if collision != null:
			var box := collision.shape as BoxShape3D
			_check(box != null and box.size.is_equal_approx(Vector3(4.6, 2.0, 4.6)),
				"bunker collider is niet meer 4.6 x 2.0 x 4.6 m")
			_check(is_equal_approx(collision.position.y, 1.0), "bunker collider staat niet op juiste hoogte")
		var hq := bunker.get_node_or_null("Hoofdkwartier") as Node3D
		_check(hq != null, "Hoofdkwartier-visual ontbreekt")
		if hq != null:
			_check(hq.get_script() == load("res://scripts/hoofdkwartier.gd"),
				"Hoofdkwartier gebruikt niet het bestaande visual-script")
		# Damage contract: incoming enemy damage is reduced to 80%; friendly shots do nothing.
		var saved_state: String = str(Game.state)
		var saved_hp: float = Game.base_hp
		Game.state = "play"
		Game.base_hp = Game.base_max
		bunker.hit(100.0, Vector3.ZERO, false)
		_check(is_equal_approx(Game.base_hp, Game.base_max - 80.0),
			"vijandelijke schade wordt niet als 80% op basis toegepast")
		bunker.hit(100.0, Vector3.ZERO, true)
		_check(is_equal_approx(Game.base_hp, Game.base_max - 80.0),
			"eigen schoten beschadigen de bunker")
		Game.base_hp = saved_hp
		Game.state = saved_state

	var asset_path: String = BaseProps.BUNKER_GAME_ASSET_PAD
	_check(ResourceLoader.exists(asset_path), "gebakken bunker-GLB ontbreekt")
	if ResourceLoader.exists(asset_path):
		var imported := load(asset_path) as PackedScene
		_check(imported != null, "gebakken bunker-GLB importeert niet als scene")
		if imported != null:
			var visual := imported.instantiate()
			root.add_child(visual)
			var mesh_count := 0
			var surface_count := 0
			var textured_surfaces := 0
			for mesh: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
				if mesh.mesh == null:
					continue
				mesh_count += 1
				for surface in range(mesh.mesh.get_surface_count()):
					surface_count += 1
					var material := mesh.get_active_material(surface) as StandardMaterial3D
					if material != null and material.albedo_texture != null:
						textured_surfaces += 1
			_check(mesh_count >= 1 and surface_count >= 8, "bunker GLB mist de acht PBR-oppervlakken")
			_check(textured_surfaces >= 1, "bunker GLB heeft geen zichtbare kleurtextuur")
			visual.queue_free()
	main.queue_free()
	if failures == 0:
		print("BUNKER HQ REPLACEMENT TEST PASS")
	else:
		print("BUNKER HQ REPLACEMENT TEST FAIL: ", failures)
	quit(0 if failures == 0 else 1)
