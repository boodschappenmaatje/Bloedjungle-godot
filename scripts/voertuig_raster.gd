class_name VoertuigRaster
extends RefCounted
## Het raster onder de routezoeker van je eigen jeep en tank (Generals-plan, stap "voertuigbevel", Dennis' wens van 11 november 2026: "een routezoeker zodat ze altijd hun weg vinden").
## Het bestrijkt het gebied ten zuiden van de rivier (jouw kamp, het bos en de weg naar de brug) in cellen van 2,5 m. Een cel is "vrij" als er een bol ter grootte van het voertuig
## (jeep 2,0 m, tank 2,9 m, ruim een halve lengte) op past zonder een muur, bunker, poort, boom, rots of stam te raken. Dat meten we met een vormvraag aan de natuurkunde-wereld, per cel
## pas als de routezoeker er langskomt (een cel kost ruim een microseconde) en we meten hem na 10 s opnieuw, want muren, gebouwen en bomen veranderen.
##
## - De rivierstrook en alles ten noorden ervan is dicht: de brug en de stad horen bij `VoertuigRoute` (vaste weg, keuze 6A).
## - Een tank rijdt palmen plat (`Foliage.hull_tree`): voor hem tellen alleen rotsen, stammen, muren en gebouwen. Een jeep gaat om palmen heen, maar als het niet anders kan rijdt hij er
##   doorheen (een snelle jeep velt een palm): een cel met alleen palmen is voor hem "zacht" (duur om te nemen, `SOFT_COST`), geen muur.
## - De opening van een poort van jouw kamp telt als vrij (de poort gaat vanzelf open voor een rijdend voertuig, `Gates`).
## - Zat een voertuig ergens vast, dan blokkeren de cellen vlak voor zijn neus 25 s (`block_ahead`), zodat de volgende zoekactie er omheen gaat.

const CELL := 2.5
const X0 := -190.0               # westrand van het raster
const Z0 := -110.0               # noordrand (de rivier kronkelt tot ongeveer -100)
const W := 152
const H := 116                   # tot z = 180 (de zuidrand van de kaart)
const BANK := Data.RIVER_HALF + 2.0   # m: zo dichtbij het midden van de rivier komt hij niet (de brug is een eigen stuk)
const EDGE := 4.0                # m: zo dichtbij de rand van de kaart komt hij niet
const MASK := Kit.LAYER_WALL | Kit.LAYER_BUNKER | Kit.LAYER_FORTIFICATION | Kit.LAYER_NATURE
const STALE := 10                # s: zo oud mag een gemeten cel zijn
const DYN_S := 25                # s: zo lang blijven cellen voor een vastzittend voertuig dicht
const RADIUS := {"jeep": 2.0, "tank": 2.9}
const FRAME_USEC := 1800         # µs rekentijd per beeld voor alle zoekacties samen
const PER_CALL_USEC := 900       # µs voor één zoekactie per beeld (zodat er één niet alles opeet)
const GATE_LATERAL := 1.3        # m: breedte (half) van het deel van een poortopening dat vrij telt
const GATE_ALONG := 3.2          # m: lengte (half) daarvan, door de dikte van de poort heen
const STUMP_H := 1.8             # m: een botsingszuil lager dan dit is een stronk, geen staande boom
const SOFT_COST := 14.0          # m: zoveel extra "afstand" kost een cel met alleen palmen voor een jeep (hij gaat liever een stuk om)

static var _rasters := {}
static var _frame := -1
static var _used := 0

var tank := false
var flags := PackedByteArray()   # 0 onbekend, 1 vrij, 2 dicht, 3 zacht (alleen palmen, voor een jeep)
var stamp := PackedInt32Array()  # seconde van de laatste meting
var dyn := {}                    # celnummer -> seconde tot wanneer hij dicht is (vastzittend voertuig)
var now_s := 0
var measured := 0                # aantal metingen (voor de test)
var _query: PhysicsShapeQueryParameters3D


static func raster(tank_: bool) -> VoertuigRaster:
	var k := "tank" if tank_ else "jeep"
	if not _rasters.has(k):
		_rasters[k] = VoertuigRaster.new(tank_)
	return _rasters[k]


## Vergeet alle metingen (bij een nieuw spel of in een test).
static func reset() -> void:
	_rasters.clear()


## Hoeveel µs mag een zoekactie in dit beeld nog rekenen?
static func take() -> int:
	var f := Engine.get_process_frames()
	if f != _frame:
		_frame = f
		_used = 0
	return mini(FRAME_USEC - _used, PER_CALL_USEC)


static func spent(us: int) -> void:
	_used += us


func _init(tank_ := false) -> void:
	tank = tank_
	flags.resize(W * H)
	stamp.resize(W * H)
	var sh := SphereShape3D.new()
	sh.radius = float(RADIUS["tank" if tank_ else "jeep"])
	_query = PhysicsShapeQueryParameters3D.new()
	_query.shape = sh
	_query.collision_mask = MASK


func tick() -> void:
	now_s = int(Time.get_ticks_msec() / 1000)


func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori((p.x - X0) / CELL), floori((p.z - Z0) / CELL))


func center(cx: int, cy: int) -> Vector3:
	return Vector3(X0 + (float(cx) + 0.5) * CELL, 0.0, Z0 + (float(cy) + 0.5) * CELL)


## De toestand van een cel voor dit soort voertuig: 1 vrij, 2 dicht, 3 zacht (alleen palmen: een jeep rijdt er liever omheen).
func cell_state(space: PhysicsDirectSpaceState3D, cx: int, cy: int) -> int:
	if cx < 0 or cy < 0 or cx >= W or cy >= H:
		return 2
	var i := cy * W + cx
	var f := flags[i]
	if f == 0 or now_s - stamp[i] > STALE:
		_measure(space, cx, cy, i)
		f = flags[i]
	if f != 2 and not dyn.is_empty() and dyn.has(i):
		if int(dyn[i]) > now_s:
			return 2
		dyn.erase(i)
	return f


## Kan een voertuig van dit soort in deze cel staan, zonder iets te raken en zonder palmen plat te rijden?
func is_free(space: PhysicsDirectSpaceState3D, cx: int, cy: int) -> bool:
	return cell_state(space, cx, cy) == 1


## Kan hij er desnoods in (vrij of zacht)?
func is_open(space: PhysicsDirectSpaceState3D, cx: int, cy: int) -> bool:
	return cell_state(space, cx, cy) != 2


func _measure(space: PhysicsDirectSpaceState3D, cx: int, cy: int, i: int) -> void:
	measured += 1
	stamp[i] = now_s
	var p := center(cx, cy)
	var st := 2
	if p.z - Data.river_z(p.x) >= BANK and absf(p.x) <= Data.WORLD_X - EDGE and p.z <= Data.WORLD_Z_S - EDGE:
		st = _hit(space, p)
		if st != 0 and _gate_open(p):
			st = 0
	flags[i] = 1 if st == 0 else (3 if st == 1 else 2)


## 0 = niets, 1 = alleen palmen (zacht, voor een jeep), 2 = iets dat hem tegenhoudt.
func _hit(space: PhysicsDirectSpaceState3D, p: Vector3) -> int:
	_query.transform = Transform3D(Basis.IDENTITY, Vector3(p.x, 0.9, p.z))
	var hits := space.intersect_shape(_query, 12)
	if hits.is_empty():
		return 0
	for h in hits:
		var c: Object = h.collider
		if c == null or String(c.get_meta("vegetation_kind", "")) != "palm":
			return 2   # een muur, bunker, rots of stam houdt elk voertuig tegen
		if _is_stump(c as CollisionObject3D, int(h.shape)):
			return 2   # een stronk (een omgevallen boom laat een lage zuil achter) is net zo hard als een rots
	return 0 if tank else 1   # alleen staande palmen: een tank rijdt erdoorheen, een jeep liever eromheen


## Een stronk heeft dezelfde meta als een palm maar een lage botsingszuil (0,8 of 1,3 m; een staande boom is 2,2 m).
func _is_stump(c: CollisionObject3D, shape_idx: int) -> bool:
	if c == null:
		return true
	var owner_id := c.shape_find_owner(shape_idx)
	if owner_id < 0:
		return false
	var sh := c.shape_owner_get_shape(owner_id, 0)
	return sh is CylinderShape3D and (sh as CylinderShape3D).height < STUMP_H


func _gate_open(p: Vector3) -> bool:
	if Game.gates == null or not is_instance_valid(Game.gates):
		return false
	for g in Game.gates.list:
		var rel: Vector3 = Basis(Vector3.UP, -float(g.yaw)) * (p - Vector3(g.at))
		if absf(rel.x) <= GATE_LATERAL and absf(rel.z) <= GATE_ALONG:
			return true
	return false


## De dichtstbijzijnde cel waar hij in kan (vrij of zacht) bij (cx, cy), tot `max_r` cellen ver; (-1, -1) als die er niet is.
func nearest_free(space: PhysicsDirectSpaceState3D, cx: int, cy: int, max_r: int) -> Vector2i:
	if is_open(space, cx, cy):
		return Vector2i(cx, cy)
	var best := Vector2i(-1, -1)
	var bd := INF
	for ring in range(1, max_r + 1):
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var d := float(dx * dx + dy * dy)
				if d < bd and is_open(space, cx + dx, cy + dy):
					bd = d
					best = Vector2i(cx + dx, cy + dy)
		if best.x >= 0:
			return best
	return best


## Kan een voertuig van dit soort in een rechte lijn van a naar b rijden? Elke cel onderweg moet vrij zijn, dus zonder palmen te raken (ook de twee buurcellen bij een hoek).
func line_free(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3) -> bool:
	var dx := b.x - a.x
	var dz := b.z - a.z
	var n := maxi(1, ceili(sqrt(dx * dx + dz * dz) / 0.7))
	var pc := cell_of(a)
	for k in range(1, n + 1):
		var t := float(k) / float(n)
		var c := cell_of(Vector3(a.x + dx * t, 0.0, a.z + dz * t))
		if c != pc:
			if not is_free(space, c.x, c.y):
				return false
			if c.x != pc.x and c.y != pc.y and not (is_free(space, c.x, pc.y) and is_free(space, pc.x, c.y)):
				return false
			pc = c
	return true


## Een voertuig zit vast: de cellen vlak voor zijn neus zijn een tijd dicht, zodat een nieuwe zoekactie er omheen gaat.
func block_ahead(pos: Vector3, dir: Vector3) -> void:
	tick()
	var d := Vector3(dir.x, 0.0, dir.z)
	if d.length() < 0.01:
		return
	d = d.normalized()
	for dist in [2.5, 4.5, 6.5]:
		var c := cell_of(pos + d * float(dist))
		if c.x >= 0 and c.y >= 0 and c.x < W and c.y < H:
			dyn[c.y * W + c.x] = now_s + DYN_S


func search(from: Vector3, to: Vector3) -> VoertuigZoek:
	return VoertuigZoek.new(self, from, to)
