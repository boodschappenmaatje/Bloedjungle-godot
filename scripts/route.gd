class_name Route
## Eenvoudige wegzoeker: alleen de rivier. Staan soldaat en doel aan verschillende kanten van de rivier, dan eerst naar de brug of de doorwaadbare plek en
## erover; verder gaat het rechtdoor. (Sinds stap 4b is er geen vierkant kamp met poorten meer: muren houden mensen fysiek tegen en vijanden slaan ze kapot,
## zie enemy.gd; de web-versie had een looprooster met stroomkaarten, 14b-nav.js.)


static func waypoint(from: Vector3, goal: Vector3) -> Vector3:
	var over: Variant = _river(from, goal)
	return over if over != null else goal


## Kant van de rivier: -1 noord, +1 zuid, 0 in de rivierstrook (op de brug of de doorwaadbare plek).
static func _side(p: Vector3) -> int:
	var off := p.z - Data.river_z(p.x)
	if absf(off) < Data.RIVER_HALF + 0.6:
		return 0
	return 1 if off > 0.0 else -1


## Staan soldaat en doel aan verschillende kanten van de rivier, dan eerst naar de brug of de doorwaadbare plek en erover.
static func _river(from: Vector3, goal: Vector3) -> Variant:
	var sf := _side(from)
	var sg := _side(goal)
	if sf == sg and sf != 0:
		return null
	var cx := Data.BRIDGE_X
	if sf == 0:
		cx = Data.FORD_X if absf(from.x - Data.FORD_X) < absf(from.x - Data.BRIDGE_X) else Data.BRIDGE_X
	else:
		var best := INF
		for x in [Data.BRIDGE_X, Data.FORD_X]:
			if x == Data.BRIDGE_X and Game.bridge != null and is_instance_valid(Game.bridge) and not Game.bridge.is_down():
				continue  # de brug staat omhoog: dan alleen de ondiepte
			var rz := Data.river_z(x)
			var cost := Vector2(from.x - x, from.z - rz).length() + Vector2(goal.x - x, goal.z - rz).length()
			if cost < best:
				best = cost
				cx = x
	var rz := Data.river_z(cx)
	var far := 1 if sg == 0 else sg
	if sf == 0:
		return Vector3(cx, 0, rz + far * (Data.RIVER_HALF + 3.5))
	var entry := Vector3(cx, 0, rz + sf * (Data.RIVER_HALF + 3.5))
	if absf(from.x - cx) > 1.2:
		return entry  # eerst op de lijn van de brug komen; daarna rechtdoor, zonder heen en weer te schakelen
	return Vector3(cx, 0, rz)
