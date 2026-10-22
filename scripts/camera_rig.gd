extends Camera3D
## Schuin van boven meekijkende camera (22-camera.js): staand scherm hoger, liggend dichterbij,
## en een stukje vooruit in de kijkrichting, verder als je richt.

var _lead := Vector3.ZERO
var _blook := Vector3.ZERO
var _nlook := Vector3.ZERO
var _fog0 := -1.0
var combat_view := false
var zoom_step := 0
var focus := Vector3.ZERO  # het punt waar de camera naar kijkt (speler + look-ahead, iets naar achteren geschoven)
var _snap := true  # eerste beeld meteen op de speler, niet ernaartoe vliegen


func toggle_view() -> void:
	combat_view = not combat_view

func zoom(delta_step: int) -> void:
	zoom_step = clampi(zoom_step + delta_step, -3, 4)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C and not Game.build_mode and (Game.state == "play" or Game.state == "prep"):
		toggle_view()


func _unhandled_input(event: InputEvent) -> void:
	# Het muiswiel zoomt alleen in de speelcamera; bouwmodus behoudt zijn eigen zoombediening.
	if Game.build_mode or (Game.state != "play" and Game.state != "prep"):
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(-1)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(1)
			get_viewport().set_input_as_handled()

func _ready() -> void:
	# lange lens en onscherpe verte: kijkt als een filmbeeld, niet als een kaart
	fov = 45.0
	far = 220.0
	var cam := CameraAttributesPractical.new()
	cam.dof_blur_far_enabled = true
	cam.dof_blur_far_distance = 36.0
	cam.dof_blur_far_transition = 55.0
	cam.dof_blur_amount = 0.07
	attributes = cam
	_dust()


## Stofdeeltjes die in het zonlicht zweven, meebewegend met de camera.
func _dust() -> void:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(20, 6, 14)
	pm.direction = Vector3(0.6, 0.15, 0.2)
	pm.spread = 40.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.7
	pm.gravity = Vector3(0, -0.02, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.93, 0.75, 0.3)
	m.no_depth_test = false
	quad.material = m
	var pa := GPUParticles3D.new()
	pa.process_material = pm
	pa.draw_pass_1 = quad
	pa.amount = 140
	pa.lifetime = 9.0
	pa.preprocess = 9.0
	pa.local_coords = false
	pa.position = Vector3(0, -12, -14)
	pa.visibility_aabb = AABB(Vector3(-40, -20, -40), Vector3(80, 40, 80))
	add_child(pa)


## Bouwmodus (placeBuildCam in 22-camera.js): hoog boven de basis, verschuiven en zoomen met Game.bcam.
func _build_cam(delta: float, portrait: bool) -> void:
	var k := Data.COMPOUND / 14.0 * 1.1 * Game.bcam.z
	# liggend ~71 graden neerwaarts op ~48 m (richtwaarde 70); staand blijft steiler zodat de smalle breedte past
	var goal := Vector3(Game.bcam.x, (83.0 if portrait else 46.0) * k, Game.bcam.y + (16.0 if portrait else 19.2) * k)
	var look := Vector3(Game.bcam.x, 0.0, Game.bcam.y + 3.4 * k)
	if _blook == Vector3.ZERO:
		_blook = _nlook
	var f := minf(1.0, delta * 6.0)
	global_position = global_position.lerp(goal, f)
	_blook = _blook.lerp(look, f)
	look_at(_blook, Vector3.UP)
	far = maxf(220.0, global_position.y * 1.5 + 40.0)


func _process(delta: float) -> void:
	var p = Game.player
	if p == null:
		return
	var size := get_viewport().get_visible_rect().size
	var portrait := size.x < size.y
	var env := get_world_3d().environment
	if Game.build_mode:
		if env and _fog0 < 0.0:
			_fog0 = env.fog_density
		if env:
			env.fog_density = lerpf(env.fog_density, _fog0 * 0.3, minf(1.0, delta * 4.0))
		attributes.dof_blur_far_enabled = false
		_build_cam(delta, portrait)
		# geen bladdithering in het overzicht: de fade loopt rustig naar 0
		Foliage.update_visibility_focus(p.global_position, global_position, delta, false)
		return
	if _fog0 >= 0.0 and env:
		# mist en zichtafstand keren zacht terug i.p.v. in één frame te springen
		env.fog_density = lerpf(env.fog_density, _fog0, minf(1.0, delta * 4.0))
		if absf(env.fog_density - _fog0) < _fog0 * 0.02:
			env.fog_density = _fog0
			_fog0 = -1.0
	attributes.dof_blur_far_enabled = GameSettings.get_value("quality") == "ultra"  # scherptediepte kost veel op mobiel
	_blook = Vector3.ZERO
	far = lerpf(far, 220.0, minf(1.0, delta * 3.0))
	# Generals-first camera, Dead Nation gevechtsstand, met begrensde zoom.
	var dist: float = clampf((16.0 if combat_view else 28.0) + float(zoom_step) * 2.5, 8.5, 38.0)
	if portrait:
		dist = minf(dist * 1.2, 42.0)
	var angle: float = deg_to_rad(48.0 if combat_view else 58.0)
	var h: float = sin(angle) * dist
	var back: float = cos(angle) * dist
	var aiming: bool = not is_nan(Game.aim)
	var lead_dist: float = (2.5 if combat_view else 3.0) if aiming else 0.5
	var want: Vector3 = Vector3(sin(p.face), 0.0, cos(p.face)) * lead_dist
	_lead = _lead.lerp(want, 1.0 - exp(-3.0 * delta))
	var target: Vector3 = p.global_position + _lead
	# De speler staat iets onder het midden van het beeld: de camera kijkt een stukje voorbij hem
	# (kijkhoek en afstand tot dat punt blijven 58°/28 m en 48°/16 m).
	focus = target + Vector3(0.0, 0.0, -dist * (0.05 if portrait else 0.07))
	var goal: Vector3 = focus + Vector3(0.0, h, back)
	goal = _avoid_obstacles(target + Vector3.UP * 1.2, goal, p)
	global_position = goal if _snap else global_position.lerp(goal, 1.0 - exp(-5.0 * delta))
	_snap = false
	_nlook = focus
	look_at(focus, Vector3.UP)
	# Alleen de zichtlijn naar de speler en naar de dichtstbijzijnde vijanden wordt uit de bladeren gehouden.
	Foliage.update_visibility_focus(p.global_position, global_position, delta, true, _nearby_enemies(p))


## De (hoogstens) drie vijanden het dichtst bij de speler, voor de jungle-zichtlijn.
func _nearby_enemies(p: Node3D) -> Array:
	var best: Array = []  # [afstand², positie]
	for e in Game.enemies:
		if not is_instance_valid(e) or not e is Node3D or bool(e.get("dead")):
			continue
		var d2: float = (e as Node3D).global_position.distance_squared_to(p.global_position)
		if d2 > 256.0:  # verder dan 16 m heeft de speler er niets aan
			continue
		best.append([d2, (e as Node3D).global_position])
		best.sort_custom(func(a, b): return a[0] < b[0])
		if best.size() > 3:
			best.resize(3)
	var out: Array = []
	for b in best:
		out.append(b[1])
	return out


func _avoid_obstacles(origin: Vector3, desired: Vector3, player: Node3D) -> Vector3:
	# Alleen statische bouwstukken en de bunker blokkeren de camera; het grote grondvlak
	# ligt onder de zichtlijn en wordt niet iedere frame onnodig meegenomen.
	var query := PhysicsRayQueryParameters3D.create(origin, desired, Kit.LAYER_WALL | Kit.LAYER_BUNKER)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return desired
	return hit.position + hit.normal * 0.35
