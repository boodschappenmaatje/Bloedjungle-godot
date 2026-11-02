class_name VoorraadBaan
extends RefCounted
## Gladde rijbaan voor de voorraadtruck (scripts/voorraad_truck.gd). De route van het wegennet is een reeks wegpunten met scherpe hoeken; de truck
## rijdt daar niet recht naartoe, maar over een baan met afgeronde bochten (cirkelbogen die raken aan beide wegstukken), met een snelheid die
## past bij de bocht. Is de truck de verkeerde kant op gericht (bij het depot na het lossen, bij de stapel na het laden), dan begint de baan met
## een driepuntskeer: achteruit, vooruit, achteruit, zoals een echte vrachtwagen op een smalle weg. Alles is rekenwerk zonder scène (testbaar).
## Richting (ψ) is de draaiing rond Y van Godot: vooruit is (sin ψ, cos ψ) in (x, z).

const R_BOCHT := 5.5        # m: gewenste bochtstraal (bij flauwe bochten ruimer, tot R_RUIM)
const R_RUIM := 9.0
const R_KEER := 4.2         # m: straal van de streken van de driepuntskeer
const WIELBASIS := 4.1      # m: afstand voor- tot achteras (zie voorraad_truck.gd, alleen voor de stand van de voorwielen)
const V_MAX := 6.0          # m/s op een rechte weg
const V_KEER_VOOR := 3.0
const V_KEER_ACHTER := 2.4
const DWARS := 3.0          # m/s²: de dwarsversnelling die we in een bocht toelaten (bepaalt de bochtsnelheid)
const REM := 4.5            # m/s²: zo hard remt de truck af (voor bochten en de stop)
const STAP := 0.4           # m tussen twee bemonsterde punten in een bocht
const KEER_AB := 1.75       # rad (100 graden): zoveel moet de truck van richting verschillen om te gaan keren
const KORT := 3.0           # m: een wegpunt dichter dan dit bij het vorige valt weg (kronkelpad)


## Eén stuk baan dat in één rijrichting achter elkaar wordt gereden (gear +1 vooruit, -1 achteruit).
class Leg:
	extends RefCounted
	var gear := 1
	var p := PackedVector2Array()   # (x, z)
	var h := PackedFloat32Array()   # kijkrichting ψ van de truck
	var k := PackedFloat32Array()   # gestuurde kromming dψ/ds (ds met het teken van de rijrichting): de stand van de voorwielen
	var s := PackedFloat32Array()   # afgelegde weg vanaf het begin van dit stuk
	var v := PackedFloat32Array()   # snelheidslimiet in m/s
	var length := 0.0

	func _i(u: float) -> int:
		return clampi(s.bsearch(u) - 1, 0, maxi(p.size() - 2, 0))

	func _t(i: int, u: float) -> float:
		var d := s[i + 1] - s[i]
		return clampf((u - s[i]) / d, 0.0, 1.0) if d > 0.0001 else 0.0

	func pos(u: float) -> Vector2:
		if p.size() < 2:
			return p[0]
		var i := _i(u)
		return p[i].lerp(p[i + 1], _t(i, u))

	func head(u: float) -> float:
		if p.size() < 2:
			return h[0]
		var i := _i(u)
		return lerpf(h[i], h[i + 1], _t(i, u))

	func kap(u: float) -> float:
		if p.size() < 2:
			return k[0]
		var i := _i(u)
		return lerpf(k[i], k[i + 1], _t(i, u))

	func vmax(u: float) -> float:
		if p.size() < 2:
			return v[0]
		var i := _i(u)
		return lerpf(v[i], v[i + 1], _t(i, u))

	func add(q: Vector2, hd: float, kk: float) -> void:
		if p.is_empty():
			s.append(0.0)
		else:
			s.append(s[s.size() - 1] + p[p.size() - 1].distance_to(q))
		p.append(q)
		h.append(hd)
		k.append(kk)
		length = s[s.size() - 1]

	func end_pos() -> Vector2:
		return p[p.size() - 1]

	func end_head() -> float:
		return h[h.size() - 1]


## De hele baan voor een truck die op `start` staat, gericht op `psi`, en langs de wegpunten `pts` (Vector2) moet rijden.
## Geeft een lijst Leg's (eerst eventueel de keer, dan de gladde baan); leeg als er niets te rijden valt.
static func plan(start: Vector2, psi: float, pts: Array, side_hint := 1) -> Array:
	var poly := _clean(start, pts)
	var legs: Array = []
	if poly.size() < 2:
		return legs
	var first: Vector2 = poly[1]
	var want := atan2(first.x - start.x, first.y - start.y)
	var mis := angle_difference(psi, want)
	if absf(mis) > KEER_AB:
		var phi := mis
		if absf(phi) > PI - 0.05:
			phi = PI * float(side_hint)
		for _i in 4:   # het eindpunt van de keer schuift een beetje: de uiteindelijke kijkrichting moet op het eerste wegpunt wijzen
			var r := _keer(start, psi, phi)
			var e: Vector2 = r[1]
			phi = clampf(phi + angle_difference(psi + phi, atan2(first.x - e.x, first.y - e.y)), -3.6, 3.6)
		var res := _keer(start, psi, phi)
		legs = res[0]
		poly[0] = res[1]
		psi = psi + phi
	elif absf(mis) > 0.2:
		# schuin t.o.v. de weg: eerst een stukje rechtdoor, dan de bocht in
		var l0 := 3.0
		for _i in 5:
			var w := start + Vector2(sin(psi), cos(psi)) * l0
			var th := absf(angle_difference(psi, atan2(first.x - w.x, first.y - w.y)))
			l0 = clampf(R_BOCHT * tan(th * 0.5), 1.0, 12.0)
		poly.insert(1, start + Vector2(sin(psi), cos(psi)) * l0)
	var main := _bochten(poly)
	if main != null:
		_profiel(main, V_MAX)
		legs.append(main)
	return legs


## Ruimt de wegpunten op: dubbele en bijna-rechte punten weg, kleine kinkjes weg, en een einde dat terugwijst (een kopse kant) afkappen.
static func _clean(start: Vector2, pts: Array) -> Array:
	var out: Array = [start]
	for i in pts.size():
		var q: Vector2 = pts[i]
		var last := i == pts.size() - 1
		var d: float = (out[out.size() - 1] as Vector2).distance_to(q)
		if d < 0.3 or (d < KORT and not last and i != pts.size() - 2):   # het voorlaatste punt blijft: dat legt de laatste rechte aanloop vast
			if last and d < 0.3 and out.size() > 1:
				out[out.size() - 1] = q
			continue
		out.append(q)
	# bijna rechte hoekpunten weg
	var i := 1
	while i < out.size() - 1:
		var a: Vector2 = out[i] - out[i - 1]
		var b: Vector2 = out[i + 1] - out[i]
		if absf(angle_difference(atan2(a.x, a.y), atan2(b.x, b.y))) < 0.05:
			out.remove_at(i)
		else:
			i += 1
	# een einde dat bijna rechtsomkeert maakt: het eindpunt ligt dan op het vorige wegstuk, ga er direct heen
	while out.size() >= 3:
		var a2: Vector2 = out[out.size() - 2] - out[out.size() - 3]
		var b2: Vector2 = out[out.size() - 1] - out[out.size() - 2]
		if absf(angle_difference(atan2(a2.x, a2.y), atan2(b2.x, b2.y))) > 2.6:
			out.remove_at(out.size() - 2)
		else:
			break
	return out


## Zet de lijn met hoeken om in een baan met afgeronde bochten.
static func _bochten(poly: Array) -> Leg:
	var n := poly.size()
	var leg := Leg.new()
	var ln := PackedFloat32Array()
	var ps := PackedFloat32Array()
	for i in range(n - 1):
		var sg: Vector2 = poly[i + 1] - poly[i]
		ln.append(sg.length())
		ps.append(atan2(sg.x, sg.y))
	var tt := PackedFloat32Array()   # raaklijnlengte per hoekpunt
	var rr := PackedFloat32Array()
	tt.resize(n)
	rr.resize(n)
	for i in range(1, n - 1):
		var th := absf(angle_difference(ps[i - 1], ps[i]))
		if th < 0.03:
			continue
		var r := lerpf(R_RUIM, R_BOCHT, clampf(th / 1.2, 0.0, 1.0))
		var t := r * tan(th * 0.5)
		var cap := minf(ln[i - 1] * (1.0 if i == 1 else 0.48), ln[i] * (0.95 if i == n - 2 else 0.48))
		if t > cap:
			t = cap
			r = maxf(t / tan(th * 0.5), 0.5)
		tt[i] = t
		rr[i] = r
	var cur := float(ps[0])   # kijkrichting zonder sprong bij ±π (loopt door)
	leg.add(poly[0], cur, 0.0)
	for i in range(1, n - 1):
		var din := Vector2(sin(cur), cos(cur))
		var p_in: Vector2 = (poly[i] as Vector2) - din * tt[i]
		_lijn(leg, p_in, cur)
		var d_psi := angle_difference(ps[i - 1], ps[i])
		if tt[i] <= 0.0:
			cur += d_psi
			continue
		var sg := signf(d_psi)
		var th2 := absf(d_psi)
		var r2 := rr[i]
		var steps := maxi(2, ceili(th2 / (STAP / r2)))
		for j in range(1, steps + 1):
			var psi := cur + sg * th2 * float(j) / float(steps)
			var q := p_in + sg * r2 * Vector2(cos(cur) - cos(psi), sin(psi) - sin(cur))
			leg.add(q, psi, sg / r2)
		cur += d_psi
	_lijn(leg, poly[n - 1], cur)
	return leg


## Rechte stukken bemonsteren (om de 2 m), zodat de snelheidslimiet vloeiend doorloopt.
static func _lijn(leg: Leg, to: Vector2, hd: float) -> void:
	var from: Vector2 = leg.end_pos()
	var d := from.distance_to(to)
	if d < 0.001:
		return
	var steps := maxi(1, ceili(d / 2.0))
	for j in range(1, steps + 1):
		leg.add(from.lerp(to, float(j) / float(steps)), hd, 0.0)


## Snelheidslimiet langs een stuk: ruim in rechte stukken, begrensd door de dwarsversnelling in bochten, en op tijd afremmen voor het einde.
static func _profiel(leg: Leg, vcap: float) -> void:
	var n := leg.p.size()
	leg.v.resize(n)
	for i in n:
		var kk := absf(leg.k[i])
		leg.v[i] = minf(vcap, sqrt(DWARS / kk)) if kk > 0.0001 else vcap
	leg.v[n - 1] = 0.0
	for i in range(n - 2, -1, -1):
		var ds := leg.s[i + 1] - leg.s[i]
		leg.v[i] = minf(leg.v[i], sqrt(leg.v[i + 1] * leg.v[i + 1] + 2.0 * REM * ds))


## Eén streek van de keer: een cirkelboog met vaste stuurstand, in één rijrichting.
static func _streek(p0: Vector2, psi0: float, gear: int, kappa: float, length: float, vcap: float) -> Leg:
	var leg := Leg.new()
	leg.gear = gear
	var steps := maxi(2, ceili(length / STAP))
	for j in range(steps + 1):
		var u := length * float(j) / float(steps)
		var sg := float(gear) * u                    # afstand met teken
		var psi := psi0 + kappa * sg
		var q := p0 + Vector2(cos(psi0) - cos(psi), sin(psi) - sin(psi0)) / kappa
		leg.add(q, psi, kappa)
	_profiel(leg, vcap)
	return leg


## De driepuntskeer: achteruit, vooruit, achteruit, samen `phi` rad draaien. Geeft [legs, eindpunt]; de kijkrichting aan het eind is psi0 + phi.
static func _keer(p0: Vector2, psi0: float, phi: float) -> Array:
	var sigma := signf(phi)
	var a := absf(phi) / 3.0
	var l := R_KEER * a
	var kp := sigma / R_KEER
	var s1 := _streek(p0, psi0, -1, -kp, l, V_KEER_ACHTER)
	var s2 := _streek(s1.end_pos(), s1.end_head(), 1, kp, l, V_KEER_VOOR)
	var s3 := _streek(s2.end_pos(), s2.end_head(), -1, -kp, l, V_KEER_ACHTER)
	return [[s1, s2, s3], s3.end_pos()]
