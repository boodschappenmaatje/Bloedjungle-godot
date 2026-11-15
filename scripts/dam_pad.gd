class_name DamPad
extends RefCounted
## Het bergpad en de kloof naar de dam (dambreuk stap 3a, Dennis koos 1B 2A 7A): een pad langs de noordrand van de kaart, buiten de
## vijandelijke basis om, loopt de kloof in tot aan de voet van de dam. Een helling in de rotswand brengt je (te voet) naar de kroon,
## de trap naar de loopbrug zit in het dammodel zelf. Er is geen echte terreinbotsing buiten de plaat: de begaanbare strook wordt
## als een stel "capsules" (lijnstuk met straal) bijgehouden; Data.clamp_world laat alleen zulke plekken toe buiten de kaartrechthoek.
##
## Maten volgen bron/dam/maak_dam.py: kroon 14 m boven de kloofbodem, kroon y -3..3 (Godot z = DAM_Z - y), trap op x = +-28,4 tot +-20,
## loopbrug op 18,6 (+0,26) boven de bodem, sluisdeuren op x = -10, 0, 10 (bovenstrooms, y 1,5).

const PAD_HW := 8.0            # halve breedte van het pad
const GORGE_HW := 17.0         # halve breedte van de kloofbodem waar je mag lopen
const RAMP_HW := 3.2           # halve breedte van de helling naar de kroon
const CROWN_Y := 14.0          # kroon boven de kloofbodem (DAM_FLOOR)
const WALK_Y := 18.86          # loopbrug (boven DAM_FLOOR)
const STAIR_X0 := 20.0         # trap loopt van |dx| 28,4 (kroonhoogte) naar 20 (loopbrughoogte)
const STAIR_X1 := 28.4
const CROWN_HALF_X := 30.0
const CROWN_HALF_Z := 3.1
const GATE_DX := [-10.0, 0.0, 10.0]
const GATE_DZ := -1.5          # sluisdeuren: bovenstrooms (Godot -z) van het midden van de kroon
const TOE_DZ := 13.0           # de dam begint 13 m voor de kroon (voet van de achterkant)

static var _segs: Array = []


static func dam_x() -> float:
	return Bergland.gorge_x(Bergland.DAM_Z)


static func gate_pos(i: int) -> Vector3:
	return Vector3(dam_x() + float(GATE_DX[i]), Bergland.DAM_FLOOR + 12.5, Bergland.DAM_Z + GATE_DZ)


## Lijnstukken {a, b, hw, voet}: voet = alleen te voet (de helling en de kroon), de rest ook voor voertuigen.
static func segments() -> Array:
	if not _segs.is_empty():
		return _segs
	var dx := dam_x()
	var z0 := Bergland.DAM_Z
	var gz := func(z: float) -> Vector2: return Vector2(Bergland.gorge_x(z), z)
	# het pad: van de westkant van de kaart langs de noordrand tot de ingang van de kloof, dan de kloof in tot 17 m voor de voet van de dam
	var pad := [Vector2(-168.0, -214.0), Vector2(-132.0, -262.0), Vector2(-108.0, -291.0), Vector2(-74.0, -294.0), gz.call(-297.0), gz.call(z0 + TOE_DZ + 17.0)]
	for i in pad.size() - 1:
		var kloof: bool = i >= pad.size() - 2
		_segs.append({"a": pad[i], "b": pad[i + 1], "hw": GORGE_HW if kloof else PAD_HW, "voet": false})
	# helling in de rotswand naar de kroon (alleen te voet), daarna de kroon zelf
	for r in _ramp_pts().size() - 1:
		_segs.append({"a": Vector2(dx + _ramp_pts()[r].x, z0 + _ramp_pts()[r].y), "b": Vector2(dx + _ramp_pts()[r + 1].x, z0 + _ramp_pts()[r + 1].y), "hw": RAMP_HW, "voet": true})
	_segs.append({"a": Vector2(dx - CROWN_HALF_X, z0), "b": Vector2(dx + CROWN_HALF_X, z0), "hw": CROWN_HALF_Z, "voet": true})
	return _segs


## Helling: (dx, dz, hoogte boven de kloofbodem). Begint op de bodem, klimt langs de oostwand en komt uit op het oostelijke kroonuiteinde.
static func _ramp_pts() -> Array:
	return [Vector3(12.0, 36.0, 0.0), Vector3(30.0, 14.0, 12.0), Vector3(30.0, 3.0, CROWN_Y)]


static func _dist_seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))


## Past een plek buiten de kaartrechthoek aan op het begaanbare net: binnen een capsule blijft hij, anders gaat hij naar de dichtstbijzijnde van
## (de rechthoekrand, het net). `rect` is de al afgeknepen plek; `voet` = ook de plekken die alleen te voet zijn.
static func clamp_walk(p: Vector2, rect: Vector2, voet: bool) -> Vector2:
	var best := rect
	var best_d := p.distance_to(rect)
	for s in segments():
		if bool(s.voet) and not voet:
			continue
		var a: Vector2 = s.a
		var b: Vector2 = s.b
		var hw: float = s.hw
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		var d := p.distance_to(q)
		if d <= hw:
			return p
		var cand := q + (p - q).normalized() * hw * 0.98
		var cd := p.distance_to(cand)
		if cd < best_d:
			best_d = cd
			best = cand
	return best


## Hoogte van het begaanbare dek (kroon, trap, loopbrug) of de helling bij (x, z): `terrain` is de hoogte van het terrein zelf. Geeft terrain terug waar geen dek is.
static func height(x: float, z: float, terrain: float) -> float:
	var dx := x - dam_x()
	var dz := z - Bergland.DAM_Z
	var fl := Bergland.DAM_FLOOR
	if absf(dz) > 40.0 or absf(dx) > 40.0:
		return terrain
	var h := terrain
	var pts := _ramp_pts()
	var total := 0.0
	var lens := []
	for i in pts.size() - 1:
		var l := Vector2(pts[i].x, pts[i].y).distance_to(Vector2(pts[i + 1].x, pts[i + 1].y))
		lens.append(l)
		total += l
	var acc := 0.0
	var best_w := 0.0
	var best_y := terrain
	for i in pts.size() - 1:
		var a := Vector2(pts[i].x, pts[i].y)
		var b := Vector2(pts[i + 1].x, pts[i + 1].y)
		var q := Geometry2D.get_closest_point_to_segment(Vector2(dx, dz), a, b)
		var t := 0.0 if a == b else clampf(a.distance_to(q) / a.distance_to(b), 0.0, 1.0)
		var yl := lerpf(pts[i].z, pts[i + 1].z, t)
		var d := Vector2(dx, dz).distance_to(q)
		var w := smoothstep(RAMP_HW + 2.5, RAMP_HW, d)
		var start := smoothstep(0.0, 6.0, acc + t * float(lens[i]))   # aan de voet sluit de helling aan op het terrein
		w *= start
		if w > best_w:
			best_w = w
			best_y = fl + yl
		acc += float(lens[i])
	h = lerpf(h, best_y, best_w)
	# kroon, trap en loopbrug
	if absf(dx) <= CROWN_HALF_X and absf(dz) <= CROWN_HALF_Z:
		var y := fl + CROWN_Y
		if dz < -1.3 and absf(dx) < STAIR_X1:   # de strook bovenstrooms: trap en loopbrug
			y = fl + lerpf(CROWN_Y, WALK_Y, clampf((STAIR_X1 - absf(dx)) / (STAIR_X1 - STAIR_X0), 0.0, 1.0))
		h = y
	return h
