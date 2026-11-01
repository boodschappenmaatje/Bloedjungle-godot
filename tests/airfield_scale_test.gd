extends Node
## Generals-verhoudingen (AirfieldHQ23.SCALE): de hele vliegveldscène is uniform verkleind. Dit test dat de verkleining
## het ontwerp, de animaties en de botsing niet kapot maakt: wereldmaten, hangardeur voor het toestel, trapbreedte voor de speler,
## torendeur-animatie, windzak-lus en dat de baan nog steeds drie dekplaten heeft.

var failures := 0

func _check(name: String, ok: bool) -> void:
	print(("OK    " if ok else "FAIL  ") + name)
	if not ok:
		failures += 1

func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame

func _ready() -> void:
	call_deferred("_run")

func _mesh_bounds(root: Node3D, name_prefix: String) -> AABB:
	var out := AABB()
	var first := true
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not mi.name.begins_with(name_prefix) or mi.mesh == null:
			continue
		var bb := mi.global_transform * mi.get_aabb()
		out = bb if first else out.merge(bb)
		first = false
	return out

func _run() -> void:
	var s := AirfieldHQ23.SCALE
	var body := AirfieldHQ23.make_complex()
	body.position = Vector3(0, 0, 400)
	get_tree().root.add_child(body)
	var showcase := body.get_node("AirfieldHQ23CompactCore") as AirfieldHQ23CompactShowcase
	var far := Node3D.new()
	get_tree().root.add_child(far)
	far.global_position = Vector3(0, 0, -400)
	Game.player = far
	await _frames(5)

	# --- maten in de wereld
	_check("scène is uniform geschaald met %.2f" % s, showcase.scale.is_equal_approx(Vector3.ONE * s))
	var lod0 := showcase.get_node("Airfield_HQ_23_Compact_LOD0") as Node3D
	var shell := _mesh_bounds(lod0, "Hangar HQ 22")
	_check("hangarschil in de wereld %.1f x %.1f m (ontwerp 22,5 x 21 x %.2f)" % [shell.size.x, shell.size.z, s], absf(shell.size.x - 22.5 * s) < 1.0 and absf(shell.size.z - 21.0 * s) < 1.0)
	var door_world := AirfieldFlightIntegration.DOOR_CLEAR_WIDTH_M * s
	var jet_span := 9.4 * 0.55
	_check("hangaropening %.1f m laat de jager (%.1f m breed) ruim door" % [door_world, jet_span], door_world >= jet_span + 2.0)
	var door_h := AirfieldFlightIntegration.DOOR_CLEAR_HEIGHT_M * s
	_check("deurhoogte %.1f m: speler (2,2 m) en jager (3,0 m) kunnen erdoor" % door_h, door_h >= 3.2)
	_check("baan is drie dekplaten (%d m)" % int(AirfieldHQ23.RUNWAY_LENGTH_M), is_equal_approx(AirfieldHQ23.RUNWAY_LENGTH_M, 45.0) and body.find_children("Runway slab collision *", "StaticBody3D", true, false).size() == 3)
	var span_x := 0.0
	var span_z := 0.0
	var minx := INF
	var maxx := -INF
	var minz := INF
	var maxz := -INF
	for region in AirfieldHQ23.site_regions():
		var corners := AirfieldHQ23._region_corners(region)
		for c in corners:
			minx = minf(minx, c.x)
			maxx = maxf(maxx, c.x)
			minz = minf(minz, c.y)
			maxz = maxf(maxz, c.y)
	span_x = maxx - minx
	span_z = maxz - minz
	_check("hele vliegveld past in %.1f x %.1f m (kleiner dan de basis van 56 x 56 m)" % [span_x, span_z], span_x < 42.0 and span_z < 36.0)

	# --- botsing volgt de schaal
	var walker := CharacterBody3D.new()
	walker.collision_layer = 0
	walker.collision_mask = 250
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 2.15
	shape.shape = cap
	walker.add_child(shape)
	walker.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	get_tree().root.add_child(walker)
	# zoals in het spel: de deuren gaan open omdat de speler ervoor staat (Game.player)
	Game.player = walker
	walker.global_position = showcase.to_global(Vector3(0, 1.1, 14.0))
	await _frames(240)
	for _i in 120:
		walker.velocity = (showcase.to_global(Vector3(0, 1.1, -5.0)) - walker.global_position).normalized() * 4.0
		walker.move_and_slide()
		await get_tree().physics_frame
	var z_in := showcase.to_local(walker.global_position).z
	_check("speler loopt door de geopende deur de hangar in (z=%.1f)" % z_in, z_in < 5.0)
	# jager-breed pad: zijdelings 1,4 m naast het midden moet ook nog door de opening kunnen
	walker.global_position = showcase.to_global(Vector3(2.3 / s, 1.1, 14.0))
	await _frames(240)
	for _i in 120:
		walker.velocity = showcase.global_transform.basis * Vector3(0, 0, -1).normalized() * 4.0
		walker.move_and_slide()
		await get_tree().physics_frame
	_check("ook 2,3 m naast het midden kom je nog door de opening (z=%.1f)" % showcase.to_local(walker.global_position).z, showcase.to_local(walker.global_position).z < 8.0)

	# --- trap van de toren: tredes breed genoeg voor de spelercapsule (0,9 m)
	var stair := body.find_child("HQ23 Tower stair and level collisions", true, false) as Node3D
	var widths_ok := true
	var count := 0
	if stair != null:
		for child in stair.get_children():
			var cs := child as CollisionShape3D
			if cs == null or cs.shape == null:
				continue
			count += 1
			var box := cs.shape as BoxShape3D
			if box.size.x * s < 0.95 and box.size.z * s < 0.95:
				widths_ok = false
	_check("trapbotsing aanwezig (%d vormen) en minstens 0,95 m breed in de wereld" % count, stair != null and count > 50 and widths_ok)

	# --- animaties blijven werken
	var tower_collision := showcase.get_node("GameplayCollisions/TowerDoorCollision") as Node3D
	var closed_y := tower_collision.rotation.y
	showcase.open_tower_door()
	await _frames(120)
	_check("torendeur-animatie: botsing draait mee open (%.2f -> %.2f rad)" % [closed_y, tower_collision.rotation.y], absf(tower_collision.rotation.y - closed_y) > 1.0)
	showcase.close_tower_door()
	var motion_root := showcase.get_node_or_null("HQ22 Approved Tower Motion Details")
	var wind := motion_root.get_node_or_null("HQ22 Wind Sock Loop") as AnimationPlayer if motion_root != null else null
	_check("windzak-lus speelt (Wind_Sock_Gust)", wind != null and wind.is_playing() and wind.current_animation == "Wind_Sock_Gust")
	var door_ok := true
	for side in [&"left", &"right"]:
		door_ok = door_ok and showcase._door_meshes(side).size() == 3
	_check("hangardeuren: meshes in alle 3 LODs bereikbaar voor de animatie", door_ok)

	print("AIRFIELD SCALE TEST fouten: ", failures)
	get_tree().quit(1 if failures > 0 else 0)
