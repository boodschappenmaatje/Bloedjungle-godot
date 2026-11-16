extends SceneTree
## Isolated headless smoke test. Run with:
## godot --headless --path prototypes/vfx_reference_lab --script res://tests/lab_smoke_test.gd

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var stage: PackedScene = load("res://scenes/lab.tscn")
	assert(stage != null, "Lab scene failed to load")
	var lab: Node3D = stage.instantiate()
	root.add_child(lab)
	await process_frame
	assert(lab.has_method("_fire"), "Lab fire preview unavailable")
	assert(lab.get_viewport().get_camera_3d() != null, "Preview camera missing")
	for material_idx in range(3):
		lab.set("selected", material_idx)
		lab.call("_fire")
		await process_frame
	var transients: Array = lab.get("transients")
	var marks: Array = lab.get("marks")
	assert(transients.size() > 0, "No gunfire VFX produced")
	assert(transients.size() <= 64, "Transient cap violated")
	assert(marks.size() == 3, "Expected one material mark per shot")
	for i in range(40):
		lab.call("_fire")
	await process_frame
	assert((lab.get("transients") as Array).size() <= 64, "Auto eviction failed for particles")
	assert((lab.get("marks") as Array).size() <= 24, "Oldest impact marks not evicted")
	print("BLOEDJUNGLE VFX REFERENCE LAB SMOKE: PASS")
	lab.queue_free()
	quit(0)
