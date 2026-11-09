class_name Wachten
## Wachten van de MCV-start (Generals-plan "Stap 4a", keuzes van Dennis 8 november 2026): soldaten die je bij de kazerne koopt (250, hooguit 4) en die zelf patrouilleren.
##  - Ronde: aan de binnenkant van de gemaakte muur (de cellen langs de omheining rond het hoofdkwartier). Is er nog geen complete omheining, dan een cirkel van
##    FALLBACK_R m rond het hoofdkwartier.
##  - Aanval: ze rennen naar de dichtstbijzijnde poort waar de aanval vandaan komt en verdedigen daar, aan de binnenkant: over of door een muur kun je niet
##    schieten (Ally._nearest_enemy kijkt daar al naar), dus de poort is waar het gevecht is. Zonder poort: aan de binnenkant van de muur aan de kant van de aanval.
## Het zijn gewone Ally-soldaten (guard = true) die niet bij je team horen (niet in Game.allies) en je niet volgen.

const COST := 250
const MAX_PER_KAZERNE := 4
const FALLBACK_R := 14.0
const TTL := 1000   # ms: zo lang blijft de berekende ronde geldig (muren en poorten kunnen veranderen)
const GATE_DEPTH := 4.5   # m binnen de poort staat een wacht bij een aanval
const SPREAD := 1.8       # m tussen twee wachten bij de poort

static var _cache: Array = []
static var _cache_t := -100000


## Muren, poorten of gebouwen zijn veranderd: de ronde wordt opnieuw uitgerekend.
static func invalidate() -> void:
	_cache_t = -100000
	_cache = []


## Het volgende punt van de ronde voor deze wacht, of bij een aanval zijn post.
static func goal(a: Ally) -> Vector3:
	if Game.state == "play":
		var p: Variant = alarm_post(a)
		if p != null:
			return p
	var route := patrol_route()
	if route.is_empty():
		return Game.base_pos
	return route[(a.wacht_slot * maxi(1, route.size() / MAX_PER_KAZERNE) + a._leg) % route.size()]


## De ronde: punten langs de binnenkant van de omheining (iedere derde cel van de rand), of een cirkel rond het hoofdkwartier.
static func patrol_route() -> Array:
	var now := Time.get_ticks_msec()
	if now - _cache_t < TTL and not _cache.is_empty():
		return _cache
	_cache_t = now
	_cache = _compute_route()
	return _cache


static func _compute_route() -> Array:
	var walls := Kampmuur.existing()
	var region := Kampmuur.region(walls)
	var out: Array = []
	if not region.is_empty():
		var border := {}
		for c in region:
			for m in Kampmuur.cell_moves(c):
				if walls.has(m[1]):
					border[c] = true
					break
		# de randcellen in volgorde: vanaf de linkerbovenhoek steeds naar de dichtstbijzijnde nog niet gelopen randcel
		var cells: Array = border.keys()
		if cells.size() >= 4:
			cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
			var order: Array = [cells[0]]
			var left := {}
			for c in cells:
				left[c] = true
			left.erase(cells[0])
			var cur: Vector2i = cells[0]
			while not left.is_empty():
				var best: Variant = null
				var best_d := 1e9
				for c in left:
					var d := float(maxi(absi(c.x - cur.x), absi(c.y - cur.y))) + 0.01 * float(absi(c.x - cur.x) + absi(c.y - cur.y))
					if d < best_d:
						best_d = d
						best = c
				if best == null or best_d > 3.0:
					break   # het volgende stuk van de rand ligt te ver: stop de ronde hier (bv. een los hoekje)
				order.append(best)
				left.erase(best)
				cur = best
			for i in range(0, order.size(), 3):
				out.append(Kampmuur.cell_center(order[i]))
	if out.size() < 3:
		out.clear()
		for i in 8:
			var ang := TAU * float(i) / 8.0
			out.append(Game.base_pos + Vector3(cos(ang), 0.0, sin(ang)) * FALLBACK_R)
	return out


## Het middelpunt van de vijanden die nu onderweg zijn, of null.
static func attackers() -> Variant:
	var sum := Vector3.ZERO
	var n := 0
	for e in Game.enemies:
		if is_instance_valid(e) and e.get("dead") != true:
			sum += (e as Node3D).global_position
			n += 1
	if n == 0:
		return null
	return sum / float(n)


## De post van een wacht bij een aanval: aan de binnenkant van de poort die het dichtst bij de aanvallers ligt; zonder poort aan de binnenkant van de muur aan hun kant.
static func alarm_post(a: Ally) -> Variant:
	var c: Variant = attackers()
	if c == null:
		return null
	var base := Vector2(Game.base_pos.x, Game.base_pos.z)
	var enemy := Vector2(c.x, c.z)
	var spread := (float(a.wacht_slot) - 1.5) * SPREAD
	var gate: Variant = nearest_gate(enemy)
	if gate != null:
		var gp := Vector2(gate.at.x, gate.at.z)
		var n := Vector2(sin(float(gate.yaw)), cos(float(gate.yaw)))
		if n.dot(gp - base) < 0.0:
			n = -n   # n wijst naar buiten (weg van het hoofdkwartier)
		var inner := gp - n * GATE_DEPTH + Vector2(n.y, -n.x) * spread
		return Vector3(inner.x, 0.0, inner.y)
	var dir := (enemy - base).normalized() if enemy.distance_to(base) > 0.1 else Vector2(0, 1)
	var region := Kampmuur.region()
	if not region.is_empty():
		var best: Variant = null
		var best_dot := -2.0
		for cell in region:
			var cc := Kampmuur.cell_center(cell)
			var rel := (Vector2(cc.x, cc.z) - base)
			var d := rel.normalized().dot(dir) * minf(rel.length() / 10.0, 1.0)
			if d > best_dot:
				best_dot = d
				best = cc
		if best != null:
			return best + Vector3(dir.y, 0.0, -dir.x) * spread
	var p := base + dir * 8.0 + Vector2(dir.y, -dir.x) * spread
	return Vector3(p.x, 0.0, p.y)


## De poort (ook een kapotte: dat is een gat in de muur) die het dichtst bij dit punt ligt, of null.
static func nearest_gate(p: Vector2) -> Variant:
	if Game.gates == null or not is_instance_valid(Game.gates):
		return null
	var best: Variant = null
	var best_d := INF
	for g in Game.gates.list:
		if g.get("edge") == null:
			continue
		var d := Vector2(g.at.x, g.at.z).distance_to(p)
		if d < best_d:
			best_d = d
			best = g
	return best
