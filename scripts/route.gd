class_name Route
## Eenvoudige wegzoeker voor de basis: een vierkante muur met een poortopening in het noorden en zuiden.
## Staan soldaat en doel aan verschillende kanten van de muur, dan gaat hij via de beste poort;
## staat de muur buiten in de weg, dan eerst naar een hoek. (De web-versie heeft een looprooster
## met stroomkaarten, 14b-nav.js; dat komt later als de kaart groter wordt.)

const C := Data.COMPOUND
const OUT := Data.COMPOUND + 2.5
const IN := Data.COMPOUND - 2.5


static func waypoint(from: Vector3, goal: Vector3) -> Vector3:
	var cross: Variant = _river(from, goal)
	if cross != null:
		return cross
	var me_in := _inside(from)
	var goal_in := _inside(goal)
	if _in_gate(from):
		# in de poortopening: doorlopen naar de kant waar het doel is
		return Vector3(0, 0, signf(from.z) * (IN - 0.5 if goal_in else OUT + 0.5))
	if me_in == goal_in:
		if me_in:
			return _around_bunker(from, goal)
		if _clear(from, goal):
			return goal
		return _corner(from, goal)
	# andere kant van de muur: kies de poort met de kortste weg
	var s := 1.0
	if (from - Vector3(0, 0, -OUT)).length() + (goal - Vector3(0, 0, -OUT)).length() < (from - Vector3(0, 0, OUT)).length() + (goal - Vector3(0, 0, OUT)).length():
		s = -1.0
	var gate := Vector3(0, 0, s * (IN if me_in else OUT))
	if me_in:
		return _around_bunker(from, gate)
	if _clear(from, gate):
		return gate
	return _corner(from, gate)


static func _inside(p: Vector3) -> bool:
	return absf(p.x) < C and absf(p.z) < C


static func _in_gate(p: Vector3) -> bool:
	return absf(p.x) < Data.GATE_GAP - 0.5 and absf(p.z) > IN and absf(p.z) < OUT + 0.6


## Binnen de muur: om de bunker heen via een van zijn hoeken (niet als de bunker zelf het doel is).
static func _around_bunker(from: Vector3, goal: Vector3) -> Vector3:
	var e := Data.BUNKER_HALF + 0.5
	if maxf(absf(goal.x), absf(goal.z)) < e + 0.5 or _clear(from, goal, e):
		return goal
	var best := goal
	var bd := INF
	var k := Data.BUNKER_HALF + 1.4
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var c := Vector3(sx * k, 0, sz * k)
			if from.distance_to(c) < 0.8 or not _clear(from, c, e):
				continue
			# een hoek vanwaar hij het doel ziet gaat voor; anders eerst naar de volgende hoek
			var d := from.distance_to(c) + c.distance_to(goal) + (0.0 if _clear(c, goal, e) else 100.0)
			if d < bd:
				bd = d
				best = c
	return best


## Raakt de rechte lijn het vierkant met halve breedte e (standaard de muur met wat speling)?
static func _clear(a: Vector3, b: Vector3, e := C + 0.8) -> bool:
	for i in range(1, 16):
		var p := a.lerp(b, i / 16.0)
		if absf(p.x) < e and absf(p.z) < e:
			return false
	return true


static func _corner(from: Vector3, goal: Vector3) -> Vector3:
	var best := goal
	var bd := INF
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var c := Vector3(sx * OUT, 0, sz * OUT)
			if from.distance_to(c) < 0.8 or not _clear(from, c):
				continue
			var d := from.distance_to(c) + c.distance_to(goal) + (0.0 if _clear(c, goal) else 100.0)
			if d < bd:
				bd = d
				best = c
	return best


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
