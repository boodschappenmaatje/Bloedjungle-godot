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
const STRIP_HW := 10.0         # halve breedte van de brede strook langs de noordrand (z -301 tot -281)
const GORGE_HW := 18.0         # halve breedte van de kloofbodem waar je mag lopen
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
	# het pad: van de westflank langs de noordrand tot achter de vijandbasis, daar een brede strook (de hele noordrand tussen x -128 en x -36 is open),
	# en de kloof in tot 17 m voor de voet van de dam. De kloof is vanaf de kaartrand (z -285) breed open: recht naar het noorden lopen werkt ook.
	var pad := [Vector2(-168.0, -214.0), Vector2(-146.0, -250.0), Vector2(-128.0, -290.0), Vector2(-36.0, -291.0)]
	for i in pad.size() - 1:
		_segs.append({"a": pad[i], "b": pad[i + 1], "hw": STRIP_HW if i == pad.size() - 2 else PAD_HW, "voet": false})
	_segs.append({"a": gz.call(-284.0), "b": gz.call(z0 + TOE_DZ + 17.0), "hw": GORGE_HW, "voet": false})
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


## Een zichtbare weg (aangestampte aarde) over het pad en de kloofbodem, zodat je ziet waar je langs moet, plus een bord bij het begin.
static func build_road(parent: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in segments():
		if bool(s.voet):
			continue
		var a: Vector2 = s.a
		var b: Vector2 = s.b
		var hw: float = minf(float(s.hw) * 0.55, 6.0)
		var d := (b - a).normalized()
		var nrm := Vector2(-d.y, d.x)
		var len := a.distance_to(b)
		var n := maxi(int(len / 4.0), 1)
		for i in n:
			var p0 := a.lerp(b, float(i) / float(n))
			var p1 := a.lerp(b, float(i + 1) / float(n))
			var q := [p0 + nrm * hw, p0 - nrm * hw, p1 - nrm * hw, p1 + nrm * hw]
			var v: Array[Vector3] = []
			for c in q:
				v.append(Vector3(c.x, Bergland.height(c.x, c.y) + 0.07, c.y))
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_normal(Vector3.UP)
				st.add_vertex(v[k])
	var mi := MeshInstance3D.new()
	mi.name = "DamWeg"
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.17, 0.14, 0.1)
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var sign_ := Label3D.new()
	sign_.name = "DamBord"
	sign_.text = "DAM  >>>"
	sign_.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_.font_size = 96
	sign_.pixel_size = 0.02
	sign_.outline_size = 14
	sign_.modulate = Color(1.0, 0.88, 0.45)
	sign_.no_depth_test = true
	var a0: Vector2 = segments()[0].a
	sign_.position = Vector3(a0.x, Bergland.height(a0.x, a0.y) + 4.0, a0.y)
	parent.add_child(sign_)
