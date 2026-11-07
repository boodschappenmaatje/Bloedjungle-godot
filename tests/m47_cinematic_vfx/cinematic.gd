extends Node3D

const CLIPS := ["Idle", "Equip", "Aim", "Fire", "Reload"]
const FPS := 30
const FRAMES := 270
const IMPACT_TIME := 4.12
const MUZZLE := Vector3(0.72, 1.42, 0.36)
const IMPACT := Vector3(4.04, 1.42, 0.36)

var weapon: Node3D
var weapon_mount: Node3D
var animation: AnimationPlayer
var core: Node3D
var rotor_a: Node3D
var rotor_b: Node3D
var projectile: Node3D
var projectile_light: OmniLight3D
var muzzle: Node3D
var shock: Node3D
var wall_root: Node3D
var wall_intact: Node3D
var wall_breach: Node3D
var wall_body: StaticBody3D
var breach_animation: AnimationPlayer
var breach_started := false
var smoke_sheets: Array[Sprite3D] = []
var dust_sheets: Array[Sprite3D] = []
var sparks: Array[MeshInstance3D] = []
var trail: Array[Node3D] = []
var smoke_spiral: MeshInstance3D
var fragments: Array[Node3D] = []
var t := 0.0
var failures := 0
var checks: Array[String] = []
var capture := true
var camera: Camera3D


func _ready() -> void:
	capture = not OS.get_cmdline_user_args().has("--no-capture")
	_build_environment()
	_build_hero()
	_build_wall()
	_build_effects()
	await get_tree().process_frame
	_validate_assets()
	for frame in range(FRAMES):
		t = float(frame) / FPS
		_update_shot(t)
		await get_tree().process_frame
		if frame % 30 == 0:
			print("CINEMATIC_FRAME ", frame, "/", FRAMES)
		if capture:
			var image := get_viewport().get_texture().get_image()
			image.save_png("res://frames/frame_%04d.png" % frame)
			if frame in [49, 98, 109, 125, 130, 148, 244]:
				image.save_png("res://screenshots/cinematic_%03d.png" % frame)
	_validate_final()
	var file := FileAccess.open("res://results.txt", FileAccess.WRITE)
	for line in checks:
		file.store_line(line)
	file.store_line("Godot " + Engine.get_version_info().string)
	file.store_line("Result " + ("PASS" if failures == 0 else "FAIL %d" % failures))
	file.close()
	print("M47_CINEMATIC_TEST ", "PASS" if failures == 0 else "FAIL %d" % failures)
	get_tree().quit(0 if failures == 0 else 1)


func _check(ok: bool, description: String) -> void:
	checks.append(("PASS " if ok else "FAIL ") + description)
	if not ok:
		failures += 1


func _material(color: Color, emission: float = 0.0, transparent: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.13
	m.roughness = 0.18 if emission > 0.0 else 0.87
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _mesh(name: String, shape: Mesh, parent: Node3D, pos: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = shape
	node.material_override = mat
	node.position = pos
	parent.add_child(node)
	return node


func _light(pos: Vector3, color: Color, energy: float, size: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = size
	l.shadow_enabled = false
	add_child(l)
	return l


func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("07151b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("56828b")
	env.ambient_light_energy = 0.36
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	camera = Camera3D.new()
	camera.name = "ComparisonCamera_ExactVFX21Angle"
	camera.position = Vector3(-0.4, 5.6, 7.2)
	camera.fov = 47.0
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(2.0, 1.28, 0.25), Vector3.UP)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -24, -8)
	sun.light_color = Color("b7d3ca")
	sun.light_energy = 0.79
	sun.shadow_enabled = true
	add_child(sun)
	_light(Vector3(1.2, 3.4, -1.4), Color("1b8fff"), 1.2, 5.0)
	_light(Vector3(5.2, 3.0, 2.0), Color("ffb968"), 0.9, 4.0)
	var ground := PlaneMesh.new()
	ground.size = Vector2(19, 16)
	ground.subdivide_width = 12
	ground.subdivide_depth = 12
	var ground_mat := _material(Color("748078"))
	ground_mat.albedo_texture = load("res://jungle_ground_base_color.jpg")
	ground_mat.normal_enabled = true
	ground_mat.normal_texture = load("res://jungle_ground_normal_gl.jpg")
	ground_mat.roughness_texture = load("res://jungle_ground_roughness.jpg")
	ground_mat.uv1_scale = Vector3(3.0, 3.0, 1.0)
	_mesh("PBRJungleGround", ground, self, Vector3(1.8, -0.015, 0), ground_mat)
	var jungle_scene := load("res://jungle.glb") as PackedScene
	if jungle_scene != null:
		var leaf_mat := _material(Color("617a5a"))
		leaf_mat.albedo_texture = load("res://leaf_color.png")
		leaf_mat.normal_enabled = true
		leaf_mat.normal_texture = load("res://leaf_normal.png")
		leaf_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var palm_mat := _material(Color("68865c"))
		palm_mat.albedo_texture = load("res://palm_color.png")
		palm_mat.normal_enabled = true
		palm_mat.normal_texture = load("res://palm_normal.png")
		palm_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var bark_mat := _material(Color("342f29"))
		var rock_mat := _material(Color("444b49"))
		var prototype := jungle_scene.instantiate()
		var variants: Array[MeshInstance3D] = []
		_collect_meshes(prototype, variants)
		var rng := RandomNumberGenerator.new()
		rng.seed = 4704
		for i in range(42):
			if variants.is_empty():
				break
			var source := variants[i % variants.size()]
			var clone := MeshInstance3D.new()
			clone.name = "ExistingJungleAsset_%02d_%s" % [i, source.name]
			clone.mesh = source.mesh
			clone.material_override = source.material_override
			if source.name.begins_with("Boom"):
				for surface in range(clone.mesh.get_surface_count()):
					clone.set_surface_override_material(surface, leaf_mat if surface == 1 else bark_mat)
			elif source.name.begins_with("Palm"):
				for surface in range(clone.mesh.get_surface_count()):
					clone.set_surface_override_material(surface, palm_mat if surface == 1 else bark_mat)
			elif source.name.begins_with("Rots"):
				clone.material_override = rock_mat
			else:
				clone.material_override = bark_mat
			var is_tree := source.name.begins_with("Boom") or source.name.begins_with("Palm")
			if is_tree:
				clone.position = Vector3(rng.randf_range(-4.5, 8.5), -0.02, -8.5 - rng.randf_range(0.0, 4.0))
			else:
				var side := -1.0 if i % 2 == 0 else 1.0
				clone.position = Vector3(rng.randf_range(-3.0, 8.0), -0.02, side * rng.randf_range(2.7, 4.6))
			clone.rotation.y = rng.randf_range(0.0, TAU)
			clone.scale = Vector3.ONE * (rng.randf_range(0.55, 0.95) if is_tree else rng.randf_range(0.4, 0.8))
			add_child(clone)
		prototype.free()
	var mist := _material(Color(0.16, 0.35, 0.4, 0.12), 0.3, true)
	for i in range(6):
		var sheet := PlaneMesh.new()
		sheet.size = Vector2(4.5, 1.45)
		var fog := _mesh("BlueJungleMist_%02d" % i, sheet, self, Vector3(i * 1.7 - 2.0, 0.12, -2.0 - i % 2), mist)
		fog.rotation.x = PI / 2.0


func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		_collect_meshes(child, out)


func _build_hero() -> void:
	var player_scene := load("res://soldaat_vq2.glb") as PackedScene
	if player_scene != null:
		var player := player_scene.instantiate() as Node3D
		player.name = "ExistingVQ2Soldier"
		add_child(player)
		var p_anim := player.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if p_anim != null and p_anim.has_animation("stil"):
			p_anim.play("stil")
	var m47 := load("res://M47_Muurbreker_1.0_animated.glb") as PackedScene
	if m47 == null:
		return
	weapon_mount = Node3D.new()
	weapon_mount.name = "CinematicOnly_HandMount"
	weapon_mount.position = Vector3(-0.165, 1.45, 0.38)
	weapon_mount.rotation.y = PI
	weapon_mount.scale = Vector3.ONE * 0.72
	add_child(weapon_mount)
	weapon = m47.instantiate() as Node3D
	weapon_mount.add_child(weapon)
	animation = weapon.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for lod in ["M47_LOD0", "M47_LOD1", "M47_LOD2"]:
		var node := weapon.find_child(lod, true, false) as MeshInstance3D
		if node != null:
			node.visible = lod == "M47_LOD0"
	core = Node3D.new()
	core.name = "CinematicOnly_VisibleEnergyCore"
	core.position = Vector3(-0.58, 0.04, -0.20)
	weapon_mount.add_child(core)
	var blue := _material(Color("158eff"), 3.5)
	for i in range(4):
		var torus := TorusMesh.new()
		torus.inner_radius = 0.125 + i * 0.025
		torus.outer_radius = 0.144 + i * 0.025
		torus.ring_segments = 30
		torus.rings = 9
		var ring := _mesh("SpinningCoreRing_%d" % i, torus, core, Vector3(0, 0, (i - 1.5) * 0.095), blue)
		ring.rotation.x = PI / 2
		if i == 0:
			rotor_a = ring
		if i == 1:
			rotor_b = ring
	for i in range(7):
		var vane_mesh := BoxMesh.new()
		vane_mesh.size = Vector3(0.04, 0.12, 0.025)
		var vane := _mesh("VisibleSpinningCoreVane_%d" % i, vane_mesh, core,
			Vector3(0.0, cos(TAU*i/7.0)*0.18, sin(TAU*i/7.0)*0.18), blue)
		vane.rotation.x = TAU*i/7.0


func _build_wall() -> void:
	var scene := load("res://cinematic_concrete_breach.glb") as PackedScene
	if scene == null:
		return
	wall_root = scene.instantiate() as Node3D
	wall_root.position = Vector3(4.28, 1.36, 0.36)
	add_child(wall_root)
	breach_animation = wall_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	wall_intact = wall_root.find_child("Wall_Intact", true, false) as Node3D
	wall_breach = wall_root.find_child("Wall_Permanent_Breach", true, false) as Node3D
	if wall_breach != null:
		wall_breach.visible = false
	for i in range(42):
		var piece := wall_root.find_child("Concrete_Fragment_%02d" % i, true, false) as Node3D
		if piece != null:
			piece.visible = false
			fragments.append(piece)
	wall_body = StaticBody3D.new()
	wall_body.name = "CinematicTestWallCollision"
	wall_body.collision_layer = 1 << 7
	wall_body.collision_mask = 0
	wall_body.position = wall_root.position
	add_child(wall_body)
	var hitbox := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.65, 2.75, 3.75)
	wall_body.add_child(hitbox)
	hitbox.shape = box
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1 << 3
	add_child(floor_body)
	var floor_hitbox := CollisionShape3D.new()
	floor_hitbox.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(floor_hitbox)


func _build_effects() -> void:
	var white := _material(Color("d3faff"), 10.0)
	var cyan := _material(Color("087cff"), 3.8)
	var electric := _material(Color("39caff"), 4.5)
	projectile = Node3D.new()
	projectile.name = "RotatingElectricEnergyProjectile"
	add_child(projectile)
	projectile.visible = false
	var shell := CylinderMesh.new()
	shell.top_radius = 0.17
	shell.bottom_radius = 0.17
	shell.height = 0.72
	shell.radial_segments = 32
	var body := _mesh("BlueWhiteEnergyBody", shell, projectile, Vector3.ZERO, cyan)
	body.rotation.z = PI / 2
	var nose := SphereMesh.new()
	nose.radius = 0.20
	nose.height = 0.4
	_mesh("WhiteHotFront", nose, projectile, Vector3(0.42, 0, 0), white)
	for i in range(5):
		var ring_mesh := TorusMesh.new()
		ring_mesh.inner_radius = 0.21 + i * 0.017
		ring_mesh.outer_radius = 0.24 + i * 0.017
		ring_mesh.ring_segments = 32
		ring_mesh.rings = 8
		var ring := _mesh("ConcentricRotatingRing_%d" % i, ring_mesh, projectile, Vector3((i - 2) * 0.18, 0, 0), electric)
		ring.rotation.y = PI / 2
		ring.rotation.x = i * 0.32
	for i in range(6):
		var tube := _make_filament("ElectricFilament_%d" % i, 0.03, 2.4, 0.32, i * TAU / 6.0, electric)
		projectile.add_child(tube)
	projectile_light = _light(MUZZLE, Color("3ec9ff"), 0.0, 3.2)
	muzzle = Node3D.new()
	muzzle.name = "BlueWhiteMuzzleFlash"
	muzzle.position = MUZZLE
	muzzle.visible = false
	add_child(muzzle)
	for i in range(14):
		var beam := CylinderMesh.new()
		beam.top_radius = 0.012
		beam.bottom_radius = 0.09 if i % 2 == 0 else 0.05
		beam.height = 0.29 if i % 2 == 0 else 0.47
		beam.radial_segments = 7
		var spike := _mesh("StarburstRay_%02d" % i, beam, muzzle, Vector3.ZERO, white if i % 3 == 0 else cyan)
		spike.rotation.z = TAU * i / 14.0
		spike.position = Vector3(0.18, cos(TAU * i / 14) * 0.11, sin(TAU * i / 14) * 0.11)
	var flash_core := SphereMesh.new()
	flash_core.radius = 0.15
	flash_core.height = 0.30
	_mesh("MuzzleWhiteCore", flash_core, muzzle, Vector3.ZERO, white)
	var flare := _flare_card("BlueWhiteMuzzleOpticalStar", 0.0044)
	flare.position.x = 0.08
	muzzle.add_child(flare)
	shock = Node3D.new()
	shock.name = "MultiLayerHexShockwave"
	shock.position = IMPACT
	shock.visible = false
	add_child(shock)
	for layer in range(3):
		var ring := _make_hex_ring(1.0 + layer * 0.16, 0.044 + layer * 0.012, cyan if layer != 1 else white)
		ring.name = "HexShockLayer_%d" % layer
		shock.add_child(ring)
		ring.position.x = -0.18 - layer * 0.09
	var impact_sphere := SphereMesh.new()
	impact_sphere.radius = 0.20
	impact_sphere.height = 0.40
	_mesh("ImpactWhiteFlash", impact_sphere, shock, Vector3(-0.26, 0, 0), white)
	var impact_flare := _flare_card("ImpactBlueWhiteOpticalStar", 0.0065)
	impact_flare.position.x = -0.34
	shock.add_child(impact_flare)
	for i in range(35):
		var spark_mesh := SphereMesh.new()
		spark_mesh.radius = 0.018 + (i % 4) * 0.007
		spark_mesh.height = spark_mesh.radius * 2.0
		var s := _mesh("ImpactSpark_%02d" % i, spark_mesh, self, IMPACT, white if i % 3 == 0 else cyan)
		s.visible = false
		sparks.append(s)
	for i in range(38):
		var puff := Node3D.new()
		puff.name = "HelicalSmoke_%02d" % i
		add_child(puff)
		trail.append(puff)
		var smoke := _flipbook_sprite("smoke", 1.0 + (i % 5) * 0.10)
		puff.add_child(smoke)
		smoke_sheets.append(smoke)
	smoke_spiral = _make_smoke_spiral()
	smoke_spiral.position = MUZZLE
	smoke_spiral.visible = false
	add_child(smoke_spiral)
	for i in range(26):
		var dust := _flipbook_sprite("dust", 1.1 + (i % 7) * 0.22)
		add_child(dust)
		dust.visible = false
		dust_sheets.append(dust)


func _make_filament(name: String, radius: float, length: float, helix_radius: float, phase: float, material: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in range(95):
		var a := float(k) / 95.0
		var b := float(k + 1) / 95.0
		var p := Vector3((a - 0.5) * length, cos(a * TAU * 2.5 + phase) * helix_radius, sin(a * TAU * 2.5 + phase) * helix_radius)
		var q := Vector3((b - 0.5) * length, cos(b * TAU * 2.5 + phase) * helix_radius, sin(b * TAU * 2.5 + phase) * helix_radius)
		for vertex in [p + Vector3(0, radius, 0), q + Vector3(0, radius, 0), p - Vector3(0, radius, 0), p - Vector3(0, radius, 0), q + Vector3(0, radius, 0), q - Vector3(0, radius, 0)]:
			st.set_normal(Vector3.UP)
			st.add_vertex(vertex)
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = st.commit()
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _make_smoke_spiral() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var length := IMPACT.x - MUZZLE.x
	for strand in range(2):
		for k in range(170):
			var a := float(k) / 170.0
			var b := float(k + 1) / 170.0
			var phase := strand * PI
			var p := Vector3(length * a, sin(a * TAU * 3.15 + phase) * 0.19, cos(a * TAU * 3.15 + phase) * 0.19)
			var q := Vector3(length * b, sin(b * TAU * 3.15 + phase) * 0.19, cos(b * TAU * 3.15 + phase) * 0.19)
			var width := 0.014 if strand == 0 else 0.009
			for vertex in [p + Vector3(0, width, 0), q + Vector3(0, width, 0), p - Vector3(0, width, 0), p - Vector3(0, width, 0), q + Vector3(0, width, 0), q - Vector3(0, width, 0)]:
				st.set_normal(Vector3.UP)
				st.add_vertex(vertex)
	var line := MeshInstance3D.new()
	line.name = "ElectricBlueSmokeSpiral"
	line.mesh = st.commit()
	line.material_override = _material(Color(0.15, 0.68, 1.0, 0.43), 2.0, true)
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return line


func _make_hex_ring(radius: float, thickness: float, material: Material) -> Node3D:
	var root := Node3D.new()
	for n in range(6):
		var a := TAU * n / 6
		var b := TAU * (n + 1) / 6
		var p := Vector3(0, cos(a) * radius, sin(a) * radius)
		var q := Vector3(0, cos(b) * radius, sin(b) * radius)
		var length := p.distance_to(q)
		var box := BoxMesh.new()
		box.size = Vector3(thickness, thickness, length)
		var edge := _mesh("HexEdge_%d" % n, box, root, (p + q) * 0.5, material)
		edge.basis = Basis.looking_at(q - p, Vector3.RIGHT)
	return root


func _flipbook_sprite(kind: String, size: float) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = load("res://%s_atlas.png" % kind)
	sprite.hframes = 4
	sprite.vframes = 4
	sprite.pixel_size = (0.0042 if kind == "smoke" else 0.0053) * size
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.transparent = true
	sprite.no_depth_test = false
	sprite.modulate = Color(1, 1, 1, 0.16)
	sprite.visible = false
	return sprite


func _flare_card(name: String, size: float) -> Sprite3D:
	var card := Sprite3D.new()
	card.name = name
	card.texture = load("res://blue_white_flare.png")
	card.pixel_size = size
	card.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	card.shaded = false
	card.transparent = true
	card.no_depth_test = false
	return card


func _set_clip(name: String, speed: float) -> void:
	if animation == null:
		return
	for clip in animation.get_animation_list():
		if String(clip) == name or String(clip).ends_with("/" + name):
			if animation.current_animation != clip:
				animation.play(clip)
			animation.speed_scale = speed
			return


func _update_shot(now: float) -> void:
	if now < 0.3:
		_set_clip("Equip", 1.0)
	elif now < 1.0:
		_set_clip("Aim", 0.8)
	elif now < 3.1:
		_set_clip("Idle", lerpf(0.45, 4.2, clampf((now - 1.0) / 2.1, 0, 1)))
	elif now < 3.45:
		_set_clip("Fire", 1.0)
	elif now > 6.2 and now < 8.1:
		_set_clip("Reload", 0.8)
	if core != null:
		var spin := 1.0 + 20.0 * clampf((now - 1.0) / 2.1, 0, 1)
		core.rotation.x += spin / FPS
	if weapon_mount != null:
		var recoil := maxf(0.0, 1.0 - absf(now - 3.17) / 0.2)
		weapon_mount.position.x = -0.165 - recoil * 0.22
		weapon_mount.rotation.z = recoil * 0.055
	if muzzle != null:
		muzzle.visible = now >= 3.12 and now <= 3.34
		muzzle.scale = Vector3.ONE * (0.26 + 0.66 * sin(PI * clampf((now - 3.12) / 0.22, 0, 1)))
	if projectile != null:
		var flight := clampf((now - 3.24) / (IMPACT_TIME - 3.24), 0, 1)
		projectile.visible = now >= 3.24 and now < IMPACT_TIME
		projectile.position = MUZZLE.lerp(IMPACT, flight)
		projectile.rotation.x = now * 16.0
		projectile.rotation.y = now * 12.0
		projectile_light.position = projectile.position
		projectile_light.light_energy = 4.5 if projectile.visible else 0.0
		if smoke_spiral != null:
			smoke_spiral.visible = now >= 3.25 and now < IMPACT_TIME + 0.15
			smoke_spiral.scale.x = maxf(0.01, flight)
	for i in range(trail.size()):
		var phase := float(i) / trail.size()
		var tail_time := now - 3.25 - phase * 0.58
		var travel := clampf(tail_time / (IMPACT_TIME - 3.24), 0, 1)
		var puff := trail[i]
		puff.position = MUZZLE.lerp(IMPACT, travel) + Vector3(0, cos(now * 15.0 + i * 0.55) * 0.24, sin(now * 15.0 + i * 0.55) * 0.24)
		var sprite := smoke_sheets[i]
		sprite.visible = tail_time > 0 and tail_time < 1.65
		sprite.frame = int(fposmod((now * 18.0 + i * 0.61), 16.0))
		sprite.modulate.a = 0.22 * minf(1.0, tail_time * 4.0) * clampf((1.65 - tail_time) / 0.7, 0, 1)
	if shock != null:
		var age := now - IMPACT_TIME
		shock.visible = age > 0 and age < 0.72
		shock.scale = Vector3.ONE * (0.48 + 1.35 * clampf(age / 0.72, 0, 1))
		for child in shock.get_children():
			if child.name == "ImpactWhiteFlash" or child.name == "ImpactBlueWhiteOpticalStar":
				child.visible = age < 0.27
			else:
				child.visible = age > 0.03
	if wall_intact != null:
		wall_intact.visible = now < IMPACT_TIME
	if wall_breach != null:
		wall_breach.visible = now >= IMPACT_TIME
	if wall_body != null:
		wall_body.collision_layer = (1 << 7) if now < IMPACT_TIME else 0
	if wall_root != null:
		if now >= IMPACT_TIME and not breach_started and breach_animation != null:
			breach_started = true
			for clip in breach_animation.get_animation_list():
				if String(clip) == "Breach" or String(clip).ends_with("/Breach"):
					breach_animation.play(clip)
					break
		for piece in fragments:
			piece.visible = now >= IMPACT_TIME
	for i in range(dust_sheets.size()):
		var age := now - IMPACT_TIME - i * 0.014
		var dust := dust_sheets[i]
		dust.visible = age > 0 and age < 2.4
		dust.frame = mini(15, int(maxf(0, age) * 6.0))
		dust.position = IMPACT + Vector3(-0.28 + sin(i * 4.7) * 0.62, -0.7 + age * 0.32, cos(i * 6.3) * 0.75)
		dust.modulate.a = 0.25 * clampf((2.4 - age) / 1.15, 0, 1)
	for i in range(sparks.size()):
		var age := now - IMPACT_TIME
		var s := sparks[i]
		s.visible = age > 0 and age < 0.55
		s.position = IMPACT + Vector3(-age * (1.7 + i % 5), sin(i * 11.1) * age * 2.1, cos(i * 7.3) * age * 2.3)
	if camera != null:
		camera.h_offset = sin(now * 85) * maxf(0, 0.025 * (1.0 - absf(now - IMPACT_TIME) / 0.55))


func _validate_assets() -> void:
	_check(Engine.get_version_info().string.begins_with("4.7.2") and Engine.get_version_info().status == "stable", "official Godot 4.7.2")
	_check(weapon != null and animation != null, "approved M-47 GLB and AnimationPlayer imported")
	if animation != null:
		for wanted in CLIPS:
			var found := false
			for clip in animation.get_animation_list():
				found = found or String(clip) == wanted or String(clip).ends_with("/" + wanted)
			_check(found, "approved animation " + wanted)
	if weapon != null:
		var lod_count := 0
		for name in ["M47_LOD0", "M47_LOD1", "M47_LOD2"]:
			var lod := weapon.find_child(name, true, false) as MeshInstance3D
			_check(lod != null, "approved " + name)
			if lod != null and lod.visible:
				lod_count += 1
		_check(lod_count == 1, "exactly one M-47 LOD visible")
		var lod0 := weapon.find_child("M47_LOD0", true, false) as MeshInstance3D
		if lod0 != null and lod0.mesh != null:
			var pbr := lod0.mesh.surface_get_material(0) as StandardMaterial3D
			_check(pbr != null and pbr.albedo_texture != null and pbr.normal_texture != null and pbr.roughness_texture != null and pbr.metallic_texture != null, "approved M-47 PBR channels intact")
	_check(wall_intact != null and wall_breach != null, "Blender concrete wall and permanent breach imported")
	var debris_clip := false
	if breach_animation != null:
		for clip in breach_animation.get_animation_list():
			debris_clip = debris_clip or String(clip) == "Breach" or String(clip).ends_with("/Breach")
	_check(debris_clip, "Blender Breach GLB animation imported")
	_check(load("res://smoke_atlas.png") != null and load("res://dust_atlas.png") != null, "Blender Cycles smoke and dust flipbooks imported")
	_check(camera.position.is_equal_approx(Vector3(-0.4, 5.6, 7.2)) and is_equal_approx(camera.fov, 47.0), "same comparison camera as VFX 2.1")


func _validate_final() -> void:
	_check(wall_intact != null and not wall_intact.visible and wall_breach != null and wall_breach.visible, "permanent visible wall breach after impact")
	_check(wall_body != null and wall_body.collision_layer == 0, "test wall collision removed after breach")
	_check(FRAMES / FPS >= 8, "video sequence at least eight seconds")
