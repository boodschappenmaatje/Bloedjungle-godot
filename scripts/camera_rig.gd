extends Camera3D
## Speelcamera met twee standen (camerakaart 13 nov, 1A-9A):
## - Third person (standaard): boven-achter de soldaat (8 m, 25°), draait zacht mee met waar je loopt;
##   bij richten staat de draai stil en kijkt hij verder vooruit. Jeep en tank krijgen een eigen afstand.
## - Tactisch: de oude schuine camera van boven (noord boven). Bevelstand, krachten, bouwwagen en vliegen
##   gaan daar vanzelf naartoe. De TACTISCH-knop (of toets C) wisselt en de keuze wordt bewaard.
## Bouwen hangt 1,6 keer hoger dan vroeger; elke wissel tussen standen is een vloeiende vlucht.

const VLIEGTUIG := preload("res://scripts/vliegtuig.gd")

var _lead := Vector3.ZERO
var _blook := Vector3.ZERO
var _nlook := Vector3.ZERO
var _fog0 := -1.0
var combat_view := true  # true = third person, false = tactisch (zelfde naam als vroeger: markeringen lezen hem)
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
var _fov_punch := 0.0   # Wapeneffecten AAA: korte inzoomstoot (graden) bij een schot
var _group_distance := 0.0
var _group_shift := Vector3.ZERO  # groepsverschuiving t.o.v. de speler (beweegt mee tussen scans)
var _group_offset := Vector3.ZERO  # zacht bijgestuurde versie van _group_shift
var _group_weight := 0.0  # 0..1, glijdt in en uit i.p.v. per scan te verspringen
var _look := Vector3.ZERO  # zacht gevolgd kijkpunt, zodat de camera nooit in één frame draait
var _group_hold := 0.0
var _group_scan := 0.0
const GROUP_HOLD_SECONDS := 2.0

# ---- third person (1A, 2A, 4A, 5A, 6A)
const TP_DISTANCE := 8.0          # te voet: 8 m achter het kijkpunt
const TP_PITCH := 25.0            # graden onder de horizon
const TP_PITCH_BLOCKED := 55.0    # muur of dak vlak achter je: de camera klimt naar boven-achter
const TP_FOV := 58.0
const TP_FOV_AIM := 52.0
const TP_FAR := 60.0              # zichtafstand in third person (tactisch 220); verder weg verdwijnt alles in de mist
const TP_FOG := 2.2               # mistdichtheid x2,2 in third person: de rand van de zichtafstand valt weg in de nevel
const TP_TURN_MAX := deg_to_rad(120.0)   # nooit sneller draaien dan 120°/s
const TP_VEHICLE_DISTANCE := {"tank": 12.0, "jeep": 9.0}
const TP_VEHICLE_DEFAULT := 10.0  # auto, bus, vrachtwagen
const BUILD_HEIGHT := 1.6         # 7A: bouwcamera 1,6 keer hoger dan voor v231
const TRANS_BUILD := 1.2          # 8A: vlucht tussen spelen en bouwen
const TRANS_VIEW := 0.6           # wissel tussen third person en tactisch
var yaw := PI                     # kijkrichting van de third-personcamera (atan2(x, z), PI = noord)
var _tp_raise := 0.0              # 0..1: hoeveel de camera omhoog is gegaan om een obstakel
var _ppos := Vector3.ZERO         # gladgestreken camerapositie in de speelstanden
var _bpos := Vector3.ZERO         # idem in de bouwstand
var _mode := ""
var _trans_from := Transform3D()
var _trans_t := 1.0
var _trans_len := 1.0
var _vehicle: Node3D = null
var _vehicle_scan := 0.0


func toggle_view() -> void:
	combat_view = not combat_view
	GameSettings.set_value("camera_view", "third" if combat_view else "tact")


## Welke stand de speelcamera nu echt heeft: third person kan tijdelijk wijken voor het bovenbeeld.
func third_person_active() -> bool:
	return _mode == "third"


## Hoeveel de sticks gedraaid moeten worden zodat "stick omhoog" vooruit in beeld is (0 in het bovenbeeld).
func input_turn() -> float:
	return yaw - PI if _mode == "third" else 0.0


## One-frame snap after a respawn/teleport, not a camera flyover across the
## entire city. Existing follow and combat camera parameters stay unchanged.
func snap_to_player() -> void:
	_snap = true
	_lead = Vector3.ZERO
	_trans_t = 1.0
	if Game.player != null:
		yaw = _player_heading(Game.player)
	_group_offset = Vector3.ZERO
	_group_weight = 0.0
	_group_hold = 0.0

## Kleine, korte camerakick voor zware wapens en nabije explosies.
func fov_punch(deg: float) -> void:
	_fov_punch = maxf(_fov_punch, clampf(deg, 0.0, 1.5))


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
	combat_view = GameSettings.get_value("camera_view") != "tact"
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
	if Game.airfield_build_view:
		var aspect := maxf(0.1, get_viewport().get_visible_rect().size.x / get_viewport().get_visible_rect().size.y)
		var tan_v := tan(deg_to_rad(fov * 0.5))
		var tan_h := tan_v * aspect
		var distance := maxf(AirfieldHQ23.FOOTPRINT.x / (2.0 * tan_h), AirfieldHQ23.FOOTPRINT.z / (2.0 * tan_v)) * 1.15 * maxf(Game.bcam.z, 0.35)
		var target := Vector3(Game.bcam.x, 0.0, Game.bcam.y)
		global_transform = Transform3D(Basis(Vector3.RIGHT, Vector3(0, 0, -1), Vector3.UP), target + Vector3(0, distance, 0))
		far = maxf(220.0, distance + 80.0)
		return
	var k := (20.0 if Game.airfield_build_view else 2.2) * Game.bcam.z * BUILD_HEIGHT
	# liggend ~71 graden neerwaarts (richtwaarde 70); staand blijft steiler zodat de smalle breedte past
	var goal := Vector3(Game.bcam.x, (83.0 if portrait else 46.0) * k, Game.bcam.y + (16.0 if portrait else 19.2) * k)
	var look := Vector3(Game.bcam.x, 0.0, Game.bcam.y + 3.4 * k)
	if _blook == Vector3.ZERO:
		# net de bouwstand in: meteen op de eindstand; de vlucht ernaartoe doet _blend()
		_blook = look
		_bpos = goal
	var f := minf(1.0, delta * 6.0)
	_bpos = _bpos.lerp(goal, f)
	_blook = _blook.lerp(look, f)
	global_position = _bpos
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
	var mode := "edit" if Game.build_mode and Game.editing else ("build" if Game.build_mode else ("third" if _wants_third(p) else "tact"))
	if mode != _mode:
		if _mode != "" and not _snap:
			_trans_from = global_transform
			_trans_t = 0.0
			_trans_len = TRANS_BUILD if (mode == "build" or _mode == "build") else TRANS_VIEW
			if mode == "edit" or _mode == "edit":
				_trans_t = 1.0   # de stadseditor heeft zijn eigen kantel-overgang
		if mode == "third" and _mode != "third":
			yaw = _player_heading(p)
			_tp_raise = 0.0
		if mode == "third" or mode == "tact":
			_snap_pose = true   # de speelstand begint meteen op zijn doel; de vlucht ernaartoe doet _blend()
		_mode = mode
	if Game.build_mode:
		if env and _fog0 < 0.0:
			_fog0 = env.fog_density
		if env:
			env.fog_density = lerpf(env.fog_density, _fog0 * 0.3, minf(1.0, delta * 4.0))
		attributes.dof_blur_far_enabled = false
		_base_fov = lerpf(_base_fov, 45.0, minf(1.0, delta * 6.0))
		fov = _base_fov
		if Game.editing:
			_edit_cam(delta)
		else:
			_editor_active = false
			_build_cam(delta, portrait)
			_blend(delta)
		# geen bladdithering in het overzicht: de fade loopt rustig naar 0
		Foliage.update_visibility_focus(p.global_position, global_position, delta, false)
		Foliage.update_pushers(p, get_tree(), false)
		return
	_editor_active = false
	_blook = Vector3.ZERO
	if mode == "third" and env:
		# 9A: third person kijkt tot de horizon. Dichtere mist plus een korte zichtafstand houden het aantal
		# getekende bladgroepen in de buurt van het bovenbeeld (zie tests/camera_third_foto.gd, METING-regels).
		if _fog0 < 0.0:
			_fog0 = env.fog_density
		env.fog_density = lerpf(env.fog_density, _fog0 * TP_FOG, minf(1.0, delta * 4.0))
	elif _fog0 >= 0.0 and env:
		# mist en zichtafstand keren zacht terug i.p.v. in één frame te springen
		env.fog_density = lerpf(env.fog_density, _fog0, minf(1.0, delta * 4.0))
		if absf(env.fog_density - _fog0) < _fog0 * 0.02:
			env.fog_density = _fog0
			_fog0 = -1.0
	attributes.dof_blur_far_enabled = Upscaling.effective_quality() == "ultra" and GameSettings.get_value("t_post") == "on"  # scherptediepte kost veel op mobiel
	if mode == "third":
		_third(delta, p)
		return
	far = lerpf(far, 220.0, minf(1.0, delta * 3.0))
	# Houd het personage leesbaar; alleen nabije teamleden en voertuigen vragen meer ruimte.
	_group_scan -= delta
	if _group_scan <= 0.0:
		_group_scan = 0.4
		_scan_group(p)
	_group_hold = maxf(0.0, _group_hold - delta)
	var base_distance := 22.5
	var wanted_distance: float = base_distance
	var plane = VLIEGTUIG.driven_plane if is_instance_valid(VLIEGTUIG.driven_plane) else null
	if plane != null:
		wanted_distance += plane.camera_extra()   # hoger en sneller vliegen: de tactische camera zoomt rustig mee uit
	# Bouwwagen kiest een plek: ver genoeg weg om het hele voorterrein en de omgeving te zien waar het hoofdkwartier komt.
	if not get_tree().get_nodes_in_group("mcv").is_empty():
		wanted_distance = maxf(wanted_distance, MCV_DISTANCE)
	# Wegrijden, uitklappen en bouwen van het hoofdkwartier: ruim beeld, midden tussen hoofdkwartier en wagen.
	var opbouw := get_tree().get_first_node_in_group("mcv_opbouw")
	if opbouw != null:
		wanted_distance = maxf(wanted_distance, OPBOUW_DISTANCE)
	_opbouw_weight = lerpf(_opbouw_weight, 1.0 if opbouw != null else 0.0, 1.0 - exp(-1.5 * delta))
	# Bevelstand (troepenbevel): iets verder weg, zodat je meer soldaten en de grond eromheen ziet.
	if get_tree().get_first_node_in_group("bevelstand_actief") != null:
		wanted_distance = maxf(wanted_distance, BevelStand.CAM_DISTANCE)
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
	if plane != null:
		lead_dist = plane.camera_lead()
	var want: Vector3 = Vector3(sin(p.face), 0.0, cos(p.face)) * lead_dist
	_lead = _lead.lerp(want, 1.0 - exp(-(6.0 if plane != null else 3.0) * delta))
	# De groepsuitsnede is een verschuiving t.o.v. de speler die zacht in- en uitglijdt. Een vast wereldpunt
	# per scan liet de camera elke 0,4 s verspringen en tussendoor achter de lopende speler blijven hangen.
	var group_f := 1.0 - exp(-2.5 * delta)
	_group_weight = lerpf(_group_weight, 1.0 if _group_hold > 0.0 else 0.0, group_f)
	_group_offset = _group_offset.lerp(_group_shift, group_f)
	var target: Vector3 = p.global_position + _lead + _group_offset * _group_weight
	if get_tree().get_first_node_in_group("bevelstand_actief") != null:
		target.z += BevelStand.CAM_SOUTH   # bevelstand: beeld iets naar het zuiden, zodat soldaten achter je boven de bevelbalk staan
	if opbouw != null:
		_opbouw_focus = opbouw.camera_focus()
	if _opbouw_weight > 0.001:
		target = target.lerp(Vector3(_opbouw_focus.x, 0.0, _opbouw_focus.z), _opbouw_weight)
	# De speler staat iets onder het midden van het beeld: de camera kijkt een stukje voorbij hem
	# De ingestelde kijkhoek blijft behouden; de uitsnede houdt ruimte voor de schietrichting.
	focus = target + Vector3(0.0, 0.0, -dist * (0.05 if portrait else 0.07))
	var goal: Vector3 = focus + Vector3(0.0, h, back)
	if opbouw == null and _opbouw_weight < 0.05:
		goal = _avoid_obstacles(target + Vector3.UP * 1.2, goal, p)   # tijdens de opbouw telt de bouwplek zelf niet als obstakel
	var follow := 1.0 - exp(-(8.0 if plane != null else 5.0) * delta)
	var hard := _snap or _snap_pose
	_ppos = goal if hard else _ppos.lerp(goal, follow)
	global_position = _ppos
	# Kijkpunt en positie volgen met dezelfde snelheid: de kijkhoek blijft gelijk en draait niet abrupt.
	_look = focus if hard else _look.lerp(focus, follow)
	_snap = false
	_snap_pose = false
	if _combat_shake_time > 0.0:
		var envelope := clampf(_combat_shake_time / 0.13, 0.0, 1.0) * _combat_shake_strength
		var t := float(Time.get_ticks_usec()) * 0.000001
		global_position += Vector3(sin(t * 97.0) * envelope, sin(t * 131.0) * envelope * 0.3, cos(t * 83.0) * envelope)
		_combat_shake_time = maxf(0.0, _combat_shake_time - delta)
		if _combat_shake_time == 0.0:
			_combat_shake_strength = 0.0
	if _fov_punch > 0.0:
		_fov_punch = maxf(0.0, _fov_punch - delta * 9.0)
	# na third person (58°) zacht terug naar de lange lens van het bovenbeeld
	_base_fov = lerpf(_base_fov, 45.0, 1.0 - exp(-6.0 * delta))
	if absf(_base_fov - 45.0) < 0.02:
		_base_fov = 45.0
	fov = _base_fov - _fov_punch
	_nlook = _look
	look_at(_look, Vector3.UP)
	_blend(delta)
	# Alleen de zichtlijn naar de speler en naar de dichtstbijzijnde vijanden wordt uit de bladeren gehouden.
	Foliage.update_visibility_focus(p.global_position, global_position, delta, true, _nearby_enemies(p))
	Foliage.update_pushers(p, get_tree())


var _opbouw_weight := 0.0
var _opbouw_focus := Vector3.ZERO
const OPBOUW_DISTANCE := 27.0   # camera-afstand tijdens wegrijden, uitklappen en bouwen (dichterbij: je ziet de kraan en de bouwers)
const MCV_DISTANCE := 38.0   # camera-afstand terwijl de bouwwagen een plek zoekt (normaal 22,5)
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
	query.hit_from_inside = true
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



var _snap_pose := false
var _base_fov := 45.0   # lens zonder schotstoot: 45° van boven, 58° (richten 52°) in third person


## Third person wanneer de speler dat koos, behalve op momenten die een overzicht van boven nodig hebben.
func _wants_third(p: Node3D) -> bool:
	if not combat_view:
		return false
	if is_instance_valid(VLIEGTUIG.driven_plane):
		return false
	var tree := get_tree()
	if not tree.get_nodes_in_group("mcv").is_empty() or tree.get_first_node_in_group("mcv_opbouw") != null:
		return false   # bouwwagen kiest een plek of het HK wordt opgebouwd: ruim beeld van boven
	if tree.get_first_node_in_group("bevelstand_actief") != null:
		return false   # troepenbevel: tikken en kaders trekken gaat van boven
	if NapalmPlace.armed:
		return false
	var combat := tree.get_first_node_in_group("combat_buttons")
	if combat != null and (bool(combat.get("kracht_stick_armed")) or String(combat.get("_wheel_kind")) == "support"):
		return false   # krachtenwiel en een kracht richten: van boven
	if bool(p.get("driving")) and _driven_vehicle(p) == null:
		return false   # helikopter of een onbekend voertuig: het vertrouwde bovenbeeld
	return true


## Het voertuig dat de speler zelf bestuurt (jeep, tank, auto, bus, vrachtwagen), of null.
func _driven_vehicle(p: Node3D) -> Node3D:
	if not bool(p.get("driving")):
		_vehicle = null
		return null
	if is_instance_valid(_vehicle) and bool(_vehicle.get("driven")):
		return _vehicle
	_vehicle = null
	for v in get_tree().get_nodes_in_group("voertuigen"):
		if v is Node3D and not v is Apache and bool(v.get("driven")):
			_vehicle = v
			break
	return _vehicle


func _vehicle_kind(v: Node3D) -> String:
	var path := String(v.get_script().resource_path) if v.get_script() != null else ""
	if path.ends_with("tank.gd"):
		return "tank"
	if path.ends_with("jeep.gd"):
		return "jeep"
	return ""


func _player_heading(p: Node3D) -> float:
	var v := _driven_vehicle(p)
	if v != null:
		var f := -v.global_transform.basis.z
		return atan2(f.x, f.z)
	return float(p.get("face"))


## 1A/2A/4A/5A/6A: boven-achter de soldaat of het voertuig, zacht meedraaiend.
func _third(delta: float, p: Node3D) -> void:
	var v := _driven_vehicle(p)
	var aiming: bool = not is_nan(Game.aim)
	var anchor: Vector3 = v.global_position if v != null else p.global_position
	var dist := TP_DISTANCE
	var lead := 2.0
	if v != null:
		dist = float(TP_VEHICLE_DISTANCE.get(_vehicle_kind(v), TP_VEHICLE_DEFAULT))
		lead = 3.5
	elif aiming:
		lead = 4.5   # 5A: bij richten verder vooruit kijken
	# 2A: draaien. Te voet alleen als je loopt en niet richt (anders drijft je richting weg onder je duim);
	# achteruit lopen draait de camera niet om. Een voertuig trekt de camera altijd zacht achter zich aan.
	var target := yaw
	var rate := 0.0
	if v != null:
		target = _player_heading(p)
		var spd := (v.get("velocity") as Vector3).length() if v.get("velocity") is Vector3 else 3.0
		rate = 2.2 if spd > 0.5 else 0.8
	elif not aiming and Game.move.length() > 0.2:
		target = float(p.get("face"))
		var d := absf(angle_difference(yaw, target))
		if d < deg_to_rad(135.0):
			rate = 1.6 * (0.35 + 0.65 * maxf(0.0, cos(d)))
	if _snap:
		yaw = _player_heading(p)
	else:
		var step := angle_difference(yaw, target) * (1.0 - exp(-rate * delta))
		yaw = wrapf(yaw + clampf(step, -TP_TURN_MAX * delta, TP_TURN_MAX * delta), -PI, PI)
	var fwd := Vector3(sin(yaw), 0.0, cos(yaw))
	var pitch := deg_to_rad(lerpf(TP_PITCH, TP_PITCH_BLOCKED, _tp_raise))
	var look := anchor + Vector3.UP * (1.9 if v != null else 1.5) + fwd * lead
	var wanted := look - fwd * cos(pitch) * dist + Vector3.UP * sin(pitch) * dist
	# 4A: muur, gebouw of bunker tussen speler en camera: de camera schuift naar voren en klimt zacht naar boven-achter
	var goal := _avoid_obstacles(anchor + Vector3.UP * 1.4, wanted, p)
	var blocked := goal.distance_to(wanted) > 0.3
	_tp_raise = lerpf(_tp_raise, 1.0 if blocked else 0.0, 1.0 - exp(-(3.0 if blocked else 1.2) * delta))
	var hard := _snap or _snap_pose
	var follow := 1.0 - exp(-10.0 * delta)
	_ppos = goal if hard else _ppos.lerp(goal, follow)
	_look = look if hard else _look.lerp(look, follow)
	_snap = false
	_snap_pose = false
	focus = look
	global_position = _ppos
	if _combat_shake_time > 0.0:
		var envelope := clampf(_combat_shake_time / 0.13, 0.0, 1.0) * _combat_shake_strength
		var t := float(Time.get_ticks_usec()) * 0.000001
		global_position += Vector3(sin(t * 97.0) * envelope, sin(t * 131.0) * envelope * 0.3, cos(t * 83.0) * envelope)
		_combat_shake_time = maxf(0.0, _combat_shake_time - delta)
		if _combat_shake_time == 0.0:
			_combat_shake_strength = 0.0
	if _fov_punch > 0.0:
		_fov_punch = maxf(0.0, _fov_punch - delta * 9.0)
	var want_fov := TP_FOV_AIM if (aiming and v == null) else TP_FOV
	_base_fov = lerpf(_base_fov, want_fov, 1.0 - exp(-6.0 * delta))
	fov = _base_fov - _fov_punch
	far = lerpf(far, TP_FAR, minf(1.0, delta * 3.0))
	_nlook = _look
	look_at(_look, Vector3.UP)
	_blend(delta)
	# blad tussen camera en speler (en de dichtstbijzijnde vijanden) wordt doorzichtig, net als in het bovenbeeld
	Foliage.update_visibility_focus(p.global_position, global_position, delta, true, _nearby_enemies(p))
	Foliage.update_pushers(p, get_tree())


## 8A: na een wissel van stand vliegt de camera vloeiend van de oude naar de nieuwe stand.
func _blend(delta: float) -> void:
	if _trans_t >= 1.0:
		return
	_trans_t = minf(1.0, _trans_t + delta / maxf(0.05, _trans_len))
	var s := _trans_t * _trans_t * (3.0 - 2.0 * _trans_t)
	global_transform = _trans_from.interpolate_with(global_transform, s)
