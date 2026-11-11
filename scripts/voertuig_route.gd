class_name VoertuigRoute
extends RefCounted
## De weg van je eigen jeep en tank als ze een bevel krijgen (Generals-plan, stap "voertuigbevel", Dennis' keuze 6A, 11 november 2026): vrij rijden in jouw gebied (ten zuiden van de
## rivier), over de brug naar de overkant, en in de stad en aan de vijandkant alleen over de vaste voertuigroute die de vijandelijke jeep en tank al rijden
## (`AanvalRoutes.voertuig_pad`, hier in omgekeerde richting). Een tik naast de weg betekent: rijden tot het dichtstbijzijnde stuk weg en daar stoppen.
## Alles hier is een rekensom zonder knopen in de scène (behalve de brug), zodat de test het zonder wereld kan nalopen.

const CROSS_D := Data.RIVER_HALF + 4.5   # m: afstand van het midden van de rivier tot het punt vlak voor of vlak achter de brug
const NEAR_ROAD := 4.0                  # m: dichterbij dan dit bij de weg telt een punt als "op de weg"


## 1 = ten zuiden van de rivier (jouw kant), -1 = ten noorden (stad en vijand), 0 = in de rivierstrook (op de brug).
static func side(p: Vector3) -> int:
	var off := p.z - Data.river_z(p.x)
	if absf(off) < Data.RIVER_HALF + 0.5:
		return 0
	return 1 if off > 0.0 else -1


## Staat de brug omhoog? Dan kan niemand eroverheen (zonder brug in de wereld, zoals in een test, is er niets te wachten).
static func bridge_up() -> bool:
	return Game.bridge != null and is_instance_valid(Game.bridge) and not Game.bridge.is_down()


## De drie punten van de oversteek, in rijrichting: vlak voor de brug, op de brug en vlak erachter.
static func crossing(to_north: bool) -> Array:
	var cx := Data.BRIDGE_X
	var rz := Data.river_z(cx)
	var pts := [Vector3(cx, 0.0, rz + CROSS_D), Vector3(cx, 0.0, rz), Vector3(cx, 0.0, rz - CROSS_D)]
	if not to_north:
		pts.reverse()
	return pts


## De vaste voertuigroute van de brug naar de poort van de vijandbasis (de weg van de vijandelijke voertuigen, omgekeerd).
static func north_line(tank: bool) -> Array:
	var line: Array = AanvalRoutes.voertuig_pad(tank)
	line.reverse()
	return line


## Het dichtstbijzijnde punt op de lijn bij p: {t: plek langs de lijn (geheel getal = hoekpunt, de breuk loopt naar het volgende), pos, d: afstand}.
static func project(line: Array, p: Vector3) -> Dictionary:
	var best := {"t": 0.0, "pos": line[0], "d": INF}
	for i in line.size() - 1:
		var a: Vector3 = line[i]
		var b: Vector3 = line[i + 1]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var f := 0.0
		if ab.length_squared() > 0.0001:
			f = clampf(Vector2(p.x - a.x, p.z - a.z).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var q := a.lerp(b, f)
		var d := Vector2(p.x - q.x, p.z - q.z).length()
		if d < float(best.d) - 0.001:
			best = {"t": float(i) + f, "pos": q, "d": d}
	return best


static func _at(line: Array, t: float) -> Vector3:
	var i := clampi(int(floor(t)), 0, line.size() - 2)
	return (line[i] as Vector3).lerp(line[i + 1], t - float(i))


## De punten van plek t0 naar plek t1 langs de lijn (beide kanten op), met de beide eindpunten erbij.
static func walk(line: Array, t0: float, t1: float) -> Array:
	var out: Array = [_at(line, t0)]
	if t0 < t1:
		var k := int(floor(t0)) + 1
		while float(k) < t1:
			out.append(line[k])
			k += 1
	else:
		var k := int(ceil(t0)) - 1
		while float(k) > t1:
			out.append(line[k])
			k -= 1
	out.append(_at(line, t1))
	return _dedupe(out)


static func _dedupe(pts: Array) -> Array:
	var out: Array = []
	for p in pts:
		if out.is_empty() or Vector2((p as Vector3).x - (out.back() as Vector3).x, (p as Vector3).z - (out.back() as Vector3).z).length() > 0.6:
			out.append(p)
	return out


## Het plan voor een rit van `from` naar `to`. Geeft {pts: de punten om af te rijden, reach: waar de rit echt eindigt, short: eindigt hij niet bij `to` (tik naast de weg),
## cross: de plek in `pts` van het punt op de brug (-1 = geen oversteek; het voertuig wacht daarvoor als de brug omhoog staat)}.
static func plan(from: Vector3, to: Vector3, tank: bool) -> Dictionary:
	var fs := side(from)
	var ts := side(to)
	if fs == 0:
		fs = ts if ts != 0 else 1   # op de brug: gewoon door naar de kant waar hij heen moet
	if ts == 0:
		ts = fs
		to = Vector3(to.x, 0.0, Data.river_z(to.x) + float(ts) * (Data.RIVER_HALF + 2.0))
	var line := north_line(tank)
	var pts: Array = []
	var cross := -1
	var reach := to
	var short := false
	if fs > 0 and ts > 0:
		pts = [to]
	elif fs > 0 and ts < 0:
		var c := crossing(true)   # voor de brug, op de brug, erachter: de weg begint vlak achter de brug
		pts = [c[0], c[1]]
		cross = 1
		var pr := project(line, to)
		pts.append_array(walk(line, 0.0, float(pr.t)))
		reach = pr.pos
		short = float(pr.d) > NEAR_ROAD
	elif fs < 0 and ts < 0:
		var p0 := project(line, from)
		var p1 := project(line, to)
		pts = walk(line, float(p0.t), float(p1.t))
		reach = p1.pos
		short = float(p1.d) > NEAR_ROAD
	else:
		var p0 := project(line, from)
		pts = walk(line, float(p0.t), 0.0)
		var c := crossing(false)
		cross = pts.size()
		pts.append(c[1])
		pts.append(c[2])
		pts.append(to)
	return {"pts": pts, "reach": reach, "short": short, "cross": cross}


## Waar een voertuig stopt als hij naar de vijandbasis rijdt: net buiten de poort, en (voor een tank die het hoofdkwartier wil beschieten) vlak erachter.
static func basis_points(inside: bool) -> Vector3:
	return VijandBasis.gate_inside() if inside else VijandBasis.gate_outside()
