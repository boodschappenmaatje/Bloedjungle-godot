extends Camera3D
## Schuin van boven meekijkende camera (22-camera.js): staand scherm hoger, liggend dichterbij,
## en een stukje vooruit in de kijkrichting, verder als je richt.

var _lead := Vector3.ZERO
var _blook := Vector3.ZERO
var _nlook := Vector3.ZERO
var _fog0 := -1.0
var combat_view := false
var zoom_step := 0  # legacy leeswaarde voor bestaande capturetests; gameplayzoom is uitgeschakeld
var focus := Vector3.ZERO  # het punt waar de camera naar kijkt (speler + look-ahead, iets naar achteren geschoven)
var _snap := true  # eerste beeld meteen op de speler, niet ernaartoe vliegen
const EDITOR_DISTANCE := 62.0
const EDITOR_TILT := PI / 6.0  # 30° uit het lood: kleine straatobjecten krijgen een zichtbare hoogte.
var editor_oblique := true
var _editor_tilt := EDITOR_TILT
var _editor_active := false
var _combat_shake_time := 0.0
var _combat_shake_strength := 0.0
var _group_distance := 0.0
var _group_shift := Vector3.ZERO  # groepsverschuiving t.o.v. de speler (beweegt mee tussen scans)
var _group_offset := Vector3.ZERO  # zacht bijgestuurde versie van _group_shift
var _group_weight := 0.0  # 0..1, glijdt in en uit i.p.v. per scan te verspringen
var _look := Vector3.ZERO  # zacht gevolgd kijkpunt, zodat de camera nooit in één frame draait
var _group_hold := 0.0
var _group_scan := 0.0
const GROUP_HOLD_SECONDS := 2.0


func toggle_view() -> void:
	combat_view = not combat_view

## Kleine, korte camerakick voor zware wapens en nabije explosies.
func combat_impulse(strength: float) -> void:
	_combat_shake_strength = maxf(_combat_shake_strength, clampf(strength, 0.0, 0.055))
	_combat_shake_time = maxf(_combat_shake_time, 0.13)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C and not Game.build_mode and (Game.state == "play" or Game.state == "prep"):
		toggle_view()


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


## Alleen de stadseditor: rond hetzelfde grondpunt kantelen, met dezelfde afstand en zoom.
func _edit_cam(delta: float) -> void:
	var target := Vector3(Game.ecam.x, 0.0, Game.ecam.y)
	var tilt := EDITOR_TILT if editor_oblique else 0.0
	var f := 1.0 - exp(-10.0 * delta)
	if not _editor_active:
		_blook = target
		_editor_tilt = tilt
		_editor_active = true
	else:
		_blook = _blook.lerp(target, f)
		_editor_tilt = lerpf(_editor_tilt, tilt, f)
	var distance := EDITOR_DISTANCE * Game.ecam.z
	global_position = _blook + Vector3(0, cos(_editor_tilt), sin(_editor_tilt)) * distance
	look_at(_blook, Vector3(0, 0, -1))
	far = maxf(220.0, distance * 1.6 + 40.0)


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
		if Game.editing:
			_edit_cam(delta)
		else:
			_editor_active = false
			_build_cam(delta, portrait)
		# geen bladdithering in het overzicht: de fade loopt rustig naar 0
		Foliage.update_visibility_focus(p.global_position, global_position, delta, false)
		Foliage.update_pushers(p, get_tree(), false)
		return
	_editor_active = false
	if _fog0 >= 0.0 and env:
		# mist en zichtafstand keren zacht terug i.p.v. in één frame te springen
		env.fog_density = lerpf(env.fog_density, _fog0, minf(1.0, delta * 4.0))
		if absf(env.fog_density - _fog0) < _fog0 * 0.02:
			env.fog_density = _fog0
			_fog0 = -1.0
	attributes.dof_blur_far_enabled = GameSettings.get_value("quality") == "ultra" and GameSettings.get_value("t_post") == "on"  # scherptediepte kost veel op mobiel
	_blook = Vector3.ZERO
	far = lerpf(far, 220.0, minf(1.0, delta * 3.0))
	# Houd het personage leesbaar; alleen nabije teamleden en voertuigen vragen meer ruimte.
	_group_scan -= delta
	if _group_scan <= 0.0:
		_group_scan = 0.4
		_scan_group(p)
	_group_hold = maxf(0.0, _group_hold - delta)
	var base_distance := 20.0 if combat_view else 22.5
	var wanted_distance: float = base_distance
	# Alleen automatische tank-/groepskadrering kan de vaste speelcamera tijdelijk verruimen.
	if _group_hold > 0.0:
		wanted_distance = maxf(wanted_distance, _group_distance)
	# Snel ruimte maken wanneer een voertuig opduikt, langzaam terug naar de speler.
	var zoom_speed := 2.2 if wanted_distance > _camera_distance else 0.85
	var dist: float = lerpf(_camera_distance if _camera_distance > 0.0 else wanted_distance, wanted_distance, 1.0 - exp(-zoom_speed * delta))
	_camera_distance = dist
	if portrait:
		dist = minf(dist * 1.2, 44.0)
	var angle: float = deg_to_rad(clampf(float(GameSettings.get_value("camera_pitch")), 35.0, 75.0))
	var h: float = sin(angle) * dist
	var back: float = cos(angle) * dist
	var aiming: bool = not is_nan(Game.aim)
	var lead_dist: float = (5.0 if combat_view else 6.0) if aiming else 0.7
	var want: Vector3 = Vector3(sin(p.face), 0.0, cos(p.face)) * lead_dist
	_lead = _lead.lerp(want, 1.0 - exp(-3.0 * delta))
	# De groepsuitsnede is een verschuiving t.o.v. de speler die zacht in- en uitglijdt. Een vast wereldpunt
	# per scan liet de camera elke 0,4 s verspringen en tussendoor achter de lopende speler blijven hangen.
	var group_f := 1.0 - exp(-2.5 * delta)
	_group_weight = lerpf(_group_weight, 1.0 if _group_hold > 0.0 else 0.0, group_f)
	_group_offset = _group_offset.lerp(_group_shift, group_f)
	var target: Vector3 = p.global_position + _lead + _group_offset * _group_weight
	# De speler staat iets onder het midden van het beeld: de camera kijkt een stukje voorbij hem
	# De ingestelde kijkhoek blijft behouden; de uitsnede houdt ruimte voor de schietrichting.
	focus = target + Vector3(0.0, 0.0, -dist * (0.05 if portrait else 0.07))
	var goal: Vector3 = focus + Vector3(0.0, h, back)
	goal = _avoid_obstacles(target + Vector3.UP * 1.2, goal, p)
	var follow := 1.0 - exp(-5.0 * delta)
	global_position = goal if _snap else global_position.lerp(goal, follow)
	# Kijkpunt en positie volgen met dezelfde snelheid: de kijkhoek blijft gelijk en draait niet abrupt.
	_look = focus if _snap else _look.lerp(focus, follow)
	_snap = false
	if _combat_shake_time > 0.0:
		var envelope := clampf(_combat_shake_time / 0.13, 0.0, 1.0) * _combat_shake_strength
		var t := float(Time.get_ticks_usec()) * 0.000001
		global_position += Vector3(sin(t * 97.0) * envelope, sin(t * 131.0) * envelope * 0.3, cos(t * 83.0) * envelope)
		_combat_shake_time = maxf(0.0, _combat_shake_time - delta)
		if _combat_shake_time == 0.0:
			_combat_shake_strength = 0.0
	_nlook = _look
	look_at(_look, Vector3.UP)
	# Alleen de zichtlijn naar de speler en naar de dichtstbijzijnde vijanden wordt uit de bladeren gehouden.
	Foliage.update_visibility_focus(p.global_position, global_position, delta, true, _nearby_enemies(p))
	Foliage.update_pushers(p, get_tree())


var _camera_distance := 0.0


## Een goedkope periodieke scan, met tijdsmarge tegen voortdurend pompend zoomen.
func _scan_group(p: Node3D) -> void:
	var points: Array[Vector3] = []
	var tank_near := false
	for vehicle in get_tree().get_nodes_in_group("voertuigen"):
		if vehicle is CharacterBody3D and vehicle.get_script() == preload("res://scripts/tank.gd") and vehicle.global_position.distance_to(p.global_position) < 27.0:
			points.append(vehicle.global_position)
			tank_near = true
	for ally in Game.allies:
		if is_instance_valid(ally) and ally is Node3D and ally.global_position.distance_to(p.global_position) < 20.0:
			points.append(ally.global_position)
	if not tank_near and points.size() < 2:
		return
	var center := p.global_position
	for point in points:
		center += point
	center /= float(points.size() + 1)
	var radius := 0.0
	for point in points:
		radius = maxf(radius, point.distance_to(center))
	radius = maxf(radius, p.global_position.distance_to(center))
	_group_shift = (center - p.global_position) * 0.42
	_group_distance = clampf(18.5 + radius * 0.85 + (1.5 if tank_near else 0.0), 23.0, 39.0)
	_group_hold = GROUP_HOLD_SECONDS


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
	var skip: Array[RID] = [player.get_rid()]
	var hit := {}
	# muren van een huis die voor de camera zijn weggehaald (en relingen/trapwangen binnen) tellen niet mee,
	# anders schiet de camera naar de speler toe zodra je naar binnen loopt
	for i in 8:
		query.exclude = skip
		hit = get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return desired
		var c: Object = hit.collider
		if c is HouseBody and not (c.seg.heel.is_visible_in_tree() or c.seg.kapot.is_visible_in_tree()):
			skip.append(hit.rid)
		elif c is Node and c.has_meta("nocam"):
			skip.append(hit.rid)
		else:
			break
	return hit.position + hit.normal * 0.35
