extends SceneTree
## Pixel regression for initially opening the camera on either wall LOD threshold.
## Needs a real rendering device (software Vulkan works), not --headless.
## BJ_LEGACY_LOD=1 reproduces the old independent-window failures.
## Optional BJ_LOD_OUT directory retains the rendered frames.
func _initialize(): call_deferred("run")
func run():
	if DisplayServer.get_name() == "headless":
		push_error("LOD pixel regression requires a rendering device; no headless PASS is valid")
		quit(2)
		return
	var camera=Camera3D.new()
	root.add_child(camera)
	var material=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=Color.WHITE
	var fail=0
	# Rebuild at each boundary, so the test exercises initial hysteresis state too.
	for distance in [26.0,28.0,29.0,30.0,56.0,58.0,59.0,60.0,29.0,58.0]:
		var stage=Node3D.new()
		root.add_child(stage)
		load("res://scripts/base_props.gd")._wall(stage)
		for node in stage.get_children():
			if node is MultiMeshInstance3D and str(node.get_meta("wall_span",""))=="west":
				node.material_override=material
				if OS.get_environment("BJ_LEGACY_LOD")=="1":
					node.visibility_parent=NodePath("")
					var lod=0 if str(node.name).ends_with("LOD0") else (1 if str(node.name).ends_with("LOD1") else 2)
					node.visibility_range_end=[28.0,58.0,0.0][lod]
					node.visibility_range_end_margin=1.5 if lod<2 else 0.0
			else: node.free()
		camera.position=Vector3(-28,1.5,0)+Vector3(8,12.5,25).normalized()*distance
		camera.look_at(Vector3(-28,1.5,0))
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		var image=root.get_texture().get_image()
		var out=OS.get_environment("BJ_LOD_OUT")
		if not out.is_empty():
			DirAccess.make_dir_recursive_absolute(out)
			image.save_png(out+"/distance-%s.png"%distance)
		var pixels=0
		for y in range(image.get_height()/2-10,image.get_height()/2+10):
			for x in range(image.get_width()/2-10,image.get_width()/2+10):
				if image.get_pixel(x,y).r>0.9: pixels+=1
		print("LOD_PIXEL distance=",distance," white_pixels=",pixels)
		if pixels==0: fail+=1
		stage.free()
		await process_frame
	print("LOD PIXEL TEST ","PASS" if fail==0 else "FAIL"," failures=",fail)
	quit(fail)
