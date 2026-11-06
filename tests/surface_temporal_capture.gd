extends SceneTree
## Isolated real terrain/wall capture at 70% resolution. Uses a software Vulkan
## device on CI hosts; its timings are not native iPhone performance measurements.
## BJ_OUT=/tmp/surfaces BJ_MSAA=4 godot --path . --rendering-method mobile
## --resolution 1280x720 -s tests/surface_temporal_capture.gd
## BJ_BASELINE=1 restores the old independent LOD windows
## and unbiased terrain filtering; omit BJ_MSAA to capture the previous no-MSAA state.
func _initialize():
	call_deferred("run")
func run():
	print("START BUILD")
	var level=Node3D.new()
	root.add_child(level)
	var ground=MeshInstance3D.new()
	ground.mesh=PlaneMesh.new()
	ground.mesh.size=Vector2(100,100)
	var mat=ShaderMaterial.new()
	mat.shader=load("res://shaders/ground.gdshader")
	mat.set_shader_parameter("compound",28.0)
	mat.set_shader_parameter("gate_gap",3.4)
	mat.set_shader_parameter("detail_mip_bias",0.0 if OS.get_environment("BJ_BASELINE")=="1" else 0.5)
	var kit=load("res://scripts/kit.gd")
	mat.set_shader_parameter("noise_a",kit.noise_tex(0.02,3))
	mat.set_shader_parameter("noise_b",kit.noise_tex(0.045,8))
	var textures={"grass_tex":"grass/base_color.jpg","jungle_tex":"jungle_ground/base_color.jpg","dirt_tex":"dry_earth/base_color.jpg","mud_tex":"mud/base_color.jpg","dirt_normal":"surfaces/dry_earth.png","grass_surface":"surfaces/grass.png","jungle_surface":"surfaces/jungle_ground.png","mud_surface":"surfaces/mud.png","moss_surface":"surfaces/moss.png","moss_tex":"moss/base_color.jpg"}
	for key in textures:
		print("LOAD ",key)
		mat.set_shader_parameter(key,load("res://assets/textures/terrain/"+textures[key]))
	ground.material_override=mat
	level.add_child(ground)
	print("BUILD WALL")
	load("res://scripts/base_props.gd")._wall(level)
	# Reimport the original GLB settings for an exact imported-LOD baseline.
	if OS.get_environment("BJ_BASELINE")=="1":
		for n in level.get_children():
			if n is MultiMeshInstance3D and n.is_in_group("base_wall_visual"):
				n.multimesh.custom_aabb=AABB()
				n.lod_bias=1.0
				n.visibility_parent=NodePath("")
				var lod=0 if str(n.name).ends_with("LOD0") else (1 if str(n.name).ends_with("LOD1") else 2)
				n.visibility_range_end=[28.0,58.0,0.0][lod]
				n.visibility_range_end_margin=1.5 if lod<2 else 0.0
	print("WORLD")
	var world=WorldEnvironment.new()
	world.environment=Environment.new()
	world.environment.background_mode=Environment.BG_COLOR
	world.environment.background_color=Color("899989")
	world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color=Color.WHITE
	world.environment.ambient_light_energy=0.35
	root.add_child(world)
	var sun=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-33,-38,0)
	sun.light_energy=1.55
	sun.shadow_enabled=true
	sun.shadow_normal_bias=1.2
	sun.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance=40
	RenderingServer.directional_shadow_atlas_set_size(1024,true)
	root.add_child(sun)
	var cam=Camera3D.new()
	root.add_child(cam)
	cam.fov=45
	cam.position=Vector3(-20,14,25)
	cam.look_at(Vector3(-20,0,10))
	root.scaling_3d_scale=0.7
	if OS.get_environment("BJ_MSAA")=="4": root.msaa_3d=Viewport.MSAA_4X
	var out=OS.get_environment("BJ_OUT")
	if out.is_empty(): out="/tmp/bj-surfaces"
	DirAccess.make_dir_recursive_absolute(out)
	for i in 5:
		cam.position.x+=0.02
		for f in 3: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out+"/frame_%d.png"%i)
	print("SURFACE CAPTURE PASS renderer=",RenderingServer.get_current_rendering_method()," msaa=",root.msaa_3d)
	quit()
