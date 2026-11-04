extends SceneTree
## Diagnostische toggles mogen alleen render-objecten aanpassen, nooit botsingen.
## Draaien: godot --headless --path . -s tests/wall_diagnostics_test.gd
var failures := 0

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("WALL DIAGNOSTICS FAIL: " + message)

func _run() -> void:
	var diagnostic := load("res://scripts/wall_diagnostics.gd") as GDScript
	_check(diagnostic != null, "diagnostic helper loads")
	if diagnostic == null:
		quit(1)
		return
	var stage := Node3D.new()
	stage.name = "WallDiagnosticTestStage"
	root.add_child(stage)
	current_scene = stage
	var wall0 := MultiMeshInstance3D.new()
	wall0.name = "Wall_west_Wall_LOD0"
	wall0.visibility_range_begin = 0.0
	wall0.visibility_parent = NodePath("Wall_west_Wall_LOD1")
	wall0.add_to_group("base_wall_visual")
	stage.add_child(wall0)
	var wall1 := MultiMeshInstance3D.new()
	wall1.name = "Wall_west_Wall_LOD1"
	wall1.visibility_range_begin = 28.0
	wall1.visibility_range_begin_margin = 1.5
	wall1.visibility_parent = NodePath("Wall_west_Wall_LOD2")
	wall1.add_to_group("base_wall_visual")
	stage.add_child(wall1)
	var wall2 := MultiMeshInstance3D.new()
	wall2.name = "Wall_west_Wall_LOD2"
	wall2.visibility_range_begin = 58.0
	wall2.visibility_range_begin_margin = 1.5
	wall2.add_to_group("base_wall_visual")
	stage.add_child(wall2)
	var berm := MultiMeshInstance3D.new()
	berm.name = "BaseWallEarthBerm"
	berm.add_to_group("base_wall_berm")
	stage.add_child(berm)
	var berm_corner := MultiMeshInstance3D.new()
	berm_corner.name = "BaseWallEarthBermCorners"
	berm_corner.add_to_group("base_wall_berm")
	stage.add_child(berm_corner)
	var shadow := MeshInstance3D.new()
	shadow.name = "BaseWallShadow_west"
	shadow.add_to_group("base_wall_shadow")
	stage.add_child(shadow)
	var collider := StaticBody3D.new()
	collider.name = "BaseHighWallCollision"
	collider.collision_layer = 42
	stage.add_child(collider)

	diagnostic.call("apply", self, "no_wall")
	_check(not wall0.visible and not wall1.visible and not wall2.visible, "no_wall hides only visual LODs")
	_check(berm.visible and berm_corner.visible and shadow.visible, "no_wall keeps berm and shadow")
	_check(collider.collision_layer == 42, "wall collision unchanged")

	# Camera normal renderer refreshes wall visibilities immediately before diagnostic override.
	wall0.visible = true
	wall1.visible = true
	wall2.visible = true
	diagnostic.call("apply", self, "no_berm")
	_check(wall0.visible and wall1.visible and wall2.visible and shadow.visible, "no_berm leaves wall and shadow")
	_check(not berm.visible and not berm_corner.visible, "no_berm hides main berm and corner caps")
	diagnostic.call("apply", self, "no_shadow")
	_check(berm.visible and berm_corner.visible and not shadow.visible, "no_shadow hides only shadow proxy")
	diagnostic.call("apply", self, "lod1")
	_check(not wall0.visible and wall1.visible and not wall2.visible, "lod1 isolates only LOD1")
	_check(is_zero_approx(wall1.visibility_range_begin) and wall1.visibility_parent.is_empty(), "forced LOD has no parent and no cutoff")
	diagnostic.call("apply", self, "lod0")
	_check(wall0.visible and not wall1.visible and not wall2.visible, "lod0 isolates only LOD0")
	diagnostic.call("apply", self, "lod2")
	_check(not wall0.visible and not wall1.visible and wall2.visible, "lod2 isolates only LOD2")
	# Simulate ordinary camera visibility pass before resetting test mode.
	wall0.visible = true
	wall1.visible = true
	wall2.visible = true
	diagnostic.call("apply", self, "normal")
	_check(wall0.visibility_parent == NodePath("Wall_west_Wall_LOD1"), "LOD0 parent restored")
	_check(wall1.visibility_parent == NodePath("Wall_west_Wall_LOD2"), "LOD1 parent restored")
	_check(is_equal_approx(wall1.visibility_range_begin, 28.0) and is_equal_approx(wall2.visibility_range_begin, 58.0), "original visibility distances restored")
	_check(berm.visible and berm_corner.visible and shadow.visible, "normal restores auxiliary objects")
	_check(collider.collision_layer == 42, "no diagnostic modifies collision")
	print("WALL DIAGNOSTICS TEST %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	current_scene = null
	stage.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _initialize() -> void:
	call_deferred("_run")
