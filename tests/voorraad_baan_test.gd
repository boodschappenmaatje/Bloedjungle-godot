extends SceneTree
## De gladde rijbaan van de voorraadtruck (scripts/voorraad_baan.gd): afgeronde bochten, snelheid per bocht, driepuntskeer, einde van de baan op het
## wegpunt, en de echte routes van het spel (heen en terug) blijven op de weg.
## godot --headless --path . --script tests/voorraad_baan_test.gd --fixed-fps 60

var main: Node
var frames := 0
var fails := 0


func _initialize() -> void:
	root.size = Vector2i(932, 430)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


func _process(_d: float) -> bool:
	frames += 1
	var g = root.get_node("Game")
	if frames == 2:
		main.get_node("Hud/Sticks").set_process(false)
	if frames == 4:
		main.begin()
		for m in get_nodes_in_group("menus"):
			m._show("")
	if frames > 4 and g.state == "prep":
		g.prep_t = 1e9
	if frames == 40:
		_pure()
		# een depot in je kamp, voorkant naar het noorden (het eerste depot is gratis na het uitklappen)
		var dep = g.builds.place("depot", Vector3(20.0, 0.0, 16.0), PI, false)
		_check("depot geplaatst", dep != null)
		_routes(g)
		print("klaar, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false


## Grootste sprong tussen twee bemonsterde punten, grootste kromming en grootste richtingssprong van een stuk.
func _stats(leg) -> Dictionary:
	var jump := 0.0
	var kmax := 0.0
	var hjump := 0.0
	for i in range(1, leg.p.size()):
		jump = maxf(jump, leg.p[i].distance_to(leg.p[i - 1]))
		hjump = maxf(hjump, absf(leg.h[i] - leg.h[i - 1]))
	for k in leg.k:
		kmax = maxf(kmax, absf(k))
	return {"jump": jump, "k": kmax, "h": hjump}


func _pure() -> void:
	# 1. rechtdoor, 90 graden bocht, rechtdoor
	var legs: Array = VoorraadBaan.plan(Vector2(0, 0), 0.0, [Vector2(0, 30), Vector2(30, 30)])
	_check("een gewone route geeft één baanstuk", legs.size() == 1)
	var l = legs[0]
	var st := _stats(l)
	_check("de baan heeft geen sprongen (grootste stap %.2f m)" % st.jump, st.jump <= 2.05)
	_check("de richting verspringt nergens (grootste stap %.2f rad)" % st.h, st.h <= 0.12)
	_check("de bocht is een ronde boog met een straal vanaf 5 m (kromming %.3f)" % st.k, st.k <= 1.0 / 5.0 + 0.001 and st.k > 0.1)
	_check("de baan eindigt op het laatste wegpunt", l.end_pos().distance_to(Vector2(30, 30)) < 0.05)
	_check("hij eindigt gericht langs het laatste stuk", absf(angle_difference(l.end_head(), PI / 2.0)) < 0.01)
	_check("de snelheid in de bocht is begrensd",  _max_in_bend(l) <= sqrt(VoorraadBaan.DWARS * 5.5) + 0.05)
	_check("op de rechte weg mag hij 6 m/s", _max_v(l) > 5.9)
	_check("aan het einde staat hij stil", l.vmax(l.length) < 0.01)
	# 2. driepuntskeer: de truck kijkt van het doel af
	var kl: Array = VoorraadBaan.plan(Vector2(10, 5), 0.0, [Vector2(10, -35)])
	_check("richting van het doel af: drie streken en daarna de baan", kl.size() == 4)
	if kl.size() == 4:
		_check("achteruit, vooruit, achteruit, vooruit", kl[0].gear == -1 and kl[1].gear == 1 and kl[2].gear == -1 and kl[3].gear == 1)
		var back: Vector2 = kl[0].end_pos() - Vector2(10, 5)
		_check("de eerste streek gaat echt achteruit (tegen de kijkrichting in)", back.dot(Vector2(0, 1)) < -1.0)
		var excursion := 0.0
		var reach := 0.0
		for i in 3:
			for q in kl[i].p:
				excursion = maxf(excursion, absf(q.x - 10.0))
				reach = maxf(reach, absf(q.y - 5.0))
		_check("de keer past in een weg van 6 m (zijwaarts %.1f m, lengte %.1f m)" % [excursion, reach], excursion <= 3.0 and reach <= 5.0)
		var e3: Vector2 = kl[2].end_pos()
		_check("na de keer staat hij weer ongeveer op zijn plek (%.2f m ernaast)" % e3.distance_to(Vector2(10, 5)), e3.distance_to(Vector2(10, 5)) < 1.5)
		_check("en kijkt hij naar het doel (verschil %.3f rad)" % absf(angle_difference(kl[2].end_head(), PI)), absf(angle_difference(kl[2].end_head(), PI)) < 0.05)
		_check("de baan begint waar de keer eindigt", kl[3].p[0].distance_to(e3) < 0.05 and absf(angle_difference(kl[3].h[0], kl[2].end_head())) < 0.05)
		_check("elke streek eindigt in stilstand", kl[0].vmax(kl[0].length) < 0.01 and kl[1].vmax(kl[1].length) < 0.01 and kl[2].vmax(kl[2].length) < 0.01)
		for i in 3:
			var ks := _stats(kl[i])
			_check("streek %d: geen sprongen en kromming 1/%.1f m" % [i + 1, 1.0 / maxf(ks.k, 0.0001)], ks.jump <= 0.45 and absf(ks.k - 1.0 / VoorraadBaan.R_KEER) < 0.01)
	# 3. de andere kant op ook
	var kr: Array = VoorraadBaan.plan(Vector2(0, 0), 0.0, [Vector2(0, -40)], -1)
	_check("de keer kan ook de andere kant op", kr.size() == 4 and signf(kr[0].end_pos().x) != signf(kl[0].end_pos().x - 10.0))
	# 4. schuin beginnen: een stukje rechtdoor en dan de bocht
	var sk: Array = VoorraadBaan.plan(Vector2(0, 0), 0.0, [Vector2(20, 20), Vector2(60, 20)])
	_check("schuin begin (45 graden): één baanstuk zonder keer", sk.size() == 1)
	if sk.size() == 1:
		var ss := _stats(sk[0])
		_check("schuin begin: geen sprongen en geen richtingssprong (%.2f rad)" % ss.h, ss.jump <= 2.05 and ss.h <= 0.12)
		_check("schuin begin: begint met de kijkrichting van de truck", absf(angle_difference(sk[0].h[0], 0.0)) < 0.01)
	# 5. een einde dat terugwijst (stad): direct naar het eindpunt
	var cu: Array = VoorraadBaan.plan(Vector2(0, 0), 0.0, [Vector2(0, 30), Vector2(0, 40), Vector2(0, 35)])
	_check("een kopse kant aan het eind wordt afgekapt", cu.size() == 1 and cu[0].end_pos().distance_to(Vector2(0, 35)) < 0.05 and _max_h_jump_total(cu[0]) < 0.01)
	# 6. kink van 1,5 m (kronkelpad) geeft geen krappe bocht
	var kk: Array = VoorraadBaan.plan(Vector2(0, 0), 0.0, [Vector2(0, 12), Vector2(1.5, 12), Vector2(8, 22), Vector2(4, 34)])
	_check("kinkjes korter dan 3 m vallen weg: geen bocht krapper dan 4 m", kk.size() == 1 and _stats(kk[0]).k <= 1.0 / 4.0 + 0.001)
	# 7. niets te rijden
	_check("zonder wegpunten geen baan", VoorraadBaan.plan(Vector2(0, 0), 0.0, []).is_empty())
	_rijstrook()


## De rijstrook: rechts van het midden van de weg, aan de uiteinden (laad-/losplek) precies op het midden, en glad.
func _rijstrook() -> void:
	var heen: VoorraadBaan.Leg = VoorraadBaan.plan(Vector2(0, 0), 0.0, [Vector2(0, 80)])[0]
	var terug: VoorraadBaan.Leg = VoorraadBaan.plan(Vector2(0, 80), PI, [Vector2(0, 0)])[0]
	var lh := VoorraadBaan.rijstrook(heen, 1.8, 10.0)
	var lt := VoorraadBaan.rijstrook(terug, 1.8, 10.0)
	_check("rijstrook: begint en eindigt precies op de plek (%.3f / %.3f m)" % [lh.p[0].distance_to(Vector2(0, 0)), lh.end_pos().distance_to(Vector2(0, 80))], lh.p[0].distance_to(Vector2(0, 0)) < 0.01 and lh.end_pos().distance_to(Vector2(0, 80)) < 0.01)
	_check("rijstrook: de kijkrichting bij de plek blijft zoals hij was", absf(angle_difference(lh.h[0], 0.0)) < 0.01 and absf(angle_difference(lh.end_head(), 0.0)) < 0.01)
	var mid_h: Vector2 = lh.pos(40.0)
	var mid_t: Vector2 = lt.pos(40.0)
	_check("rijstrook: in het midden %.1f m naast de weg (rechts van de rijrichting)" % absf(mid_h.x), absf(absf(mid_h.x) - 1.8) < 0.05)
	_check("rijstrook: heen en terug zitten aan weerskanten (%.1f m uit elkaar)" % absf(mid_h.x - mid_t.x), absf(mid_h.x - mid_t.x) > 3.4)
	var sh := _stats(lh)
	_check("rijstrook: glad (stap %.2f m, richting %.3f rad, kromming 1/%.1f m)" % [sh.jump, sh.h, 1.0 / maxf(sh.k, 0.0001)], sh.jump <= 2.1 and sh.h < 0.2 and sh.k <= 1.0 / 8.0)
	_check("rijstrook: bij de plek loopt hij geleidelijk naar het midden (5 m: %.2f m opzij)" % absf(lh.pos(5.0).x), absf(lh.pos(5.0).x) < 1.0 and absf(lh.pos(5.0).x) > 0.1)
	var ls := VoorraadBaan.rijstrook(heen, 1.8, 10.0, [Rect2(-10, 30, 20, 20)], 6.0)
	_check("rijstrook: in een smal stuk over het midden (%.2f m opzij)" % absf(ls.pos(40.0).x), absf(ls.pos(40.0).x) < 0.01)
	_check("rijstrook: en weer op de strook buiten het smalle stuk (%.2f m opzij)" % absf(ls.pos(70.0).x), absf(absf(ls.pos(70.0).x) - 1.8) < 0.3)


func _max_h_jump_total(leg) -> float:
	var m := 0.0
	for i in range(1, leg.h.size()):
		m = maxf(m, absf(leg.h[i] - leg.h[0]))
	return m


func _max_in_bend(leg) -> float:
	var m := 0.0
	for i in leg.p.size():
		if absf(leg.k[i]) > 0.01:
			m = maxf(m, leg.v[i])
	return m


func _max_v(leg) -> float:
	var m := 0.0
	for x in leg.v:
		m = maxf(m, x)
	return m


## Afstand van een punt tot de lijn door de wegpunten.
func _dist_to_poly(q: Vector2, pts: Array) -> float:
	var best := INF
	for i in range(pts.size() - 1):
		var c := Geometry2D.get_closest_point_to_segment(q, pts[i], pts[i + 1])
		best = minf(best, q.distance_to(c))
	return best


func _routes(g) -> void:
	var sup = g.supply
	var depot: Dictionary = sup.depots()[0]
	var dock: Vector2 = sup.dock_point(depot)
	var yaw := float(depot.yaw)
	var front := Vector2(sin(yaw), cos(yaw))
	var tested := 0
	for s in sup.stapels:
		var r: Array = sup.route(depot, s.slot)
		var dir0: Vector2 = ((r[r.size() - 1] as Vector2) - dock).normalized()
		if dir0.dot(front) < 0.4:
			continue   # deze stapel ligt achter het depot: de truck moet eerst keren (dat doet de baan apart, zie hieronder)
		tested += 1
		# heen: de truck staat op het depotplein, kijkt van het depot af
		var out: Array = r.duplicate()
		out.pop_front()
		var legs: Array = VoorraadBaan.plan(dock, yaw, out, 1)
		var stop: Vector2 = r[r.size() - 1]
		var site_dir: Vector2 = (s.site.pos as Vector2 - stop).normalized()
		_check("stapel %d heen: er is een baan" % (s.slot + 1), legs.size() == 1)
		if legs.size() == 1:
			var l = legs[0]
			var st := _stats(l)
			var dev := 0.0
			for q in l.p:
				dev = maxf(dev, _dist_to_poly(q, r))
			_check("stapel %d heen: eindigt op het stoppunt (%.2f m ernaast)" % [s.slot + 1, l.end_pos().distance_to(stop)], l.end_pos().distance_to(stop) < 0.1)
			_check("stapel %d heen: grijper kijkt naar de stapel (verschil %.3f rad)" % [s.slot + 1, absf(angle_difference(l.end_head(), atan2(site_dir.x, site_dir.y)))], absf(angle_difference(l.end_head(), atan2(site_dir.x, site_dir.y))) < 0.05)
			_check("stapel %d heen: blijft op de weg (afwijking %.1f m van de wegas, weg is 6 m breed)" % [s.slot + 1, dev], dev <= 3.0)
			_check("stapel %d heen: gladde baan (stap %.2f m, richting %.2f rad, kromming 1/%.1f m)" % [s.slot + 1, st.jump, st.h, 1.0 / maxf(st.k, 0.0001)], st.jump <= 2.05 and st.h <= 0.18 and st.k <= 1.0 / 2.0)   # 0,18 rad per 2 m: Voorraad.route voegt wegpunten vlak bij elkaar samen (heen en terug dezelfde lijn)
		# terug: de truck staat bij de stapel, kijkt naar de stapel
		var back: Array = r.duplicate()
		back.reverse()
		back.pop_front()
		var l2: Array = VoorraadBaan.plan(stop, atan2(site_dir.x, site_dir.y), back, 1)
		_check("stapel %d terug: keer en daarna de baan" % (s.slot + 1), l2.size() == 4)
		if l2.size() == 4:
			var l = l2[3]
			var home_head := atan2(-front.x, -front.y)   # naar het depot toe
			_check("stapel %d terug: eindigt op de laadplek (%.2f m ernaast)" % [s.slot + 1, l.end_pos().distance_to(dock)], l.end_pos().distance_to(dock) < 0.1)
			_check("stapel %d terug: staat recht voor het depot (verschil %.3f rad)" % [s.slot + 1, absf(angle_difference(l.end_head(), home_head))], absf(angle_difference(l.end_head(), home_head)) < 0.05)
			var dev2 := 0.0
			for i in 4:
				for q in l2[i].p:
					dev2 = maxf(dev2, _dist_to_poly(q, [stop] + back))
			_check("stapel %d terug: keer en baan blijven binnen 4 m van de wegas (%.1f m)" % [s.slot + 1, dev2], dev2 <= 4.0)
		# bij het depot: keren van het depot af
		var l3: Array = VoorraadBaan.plan(dock, yaw + PI, out, 1)
		_check("stapel %d: keren bij het depot en daarna de baan" % (s.slot + 1), l3.size() == 4)
		if l3.size() == 4:
			var away := dock - (l3[0].end_pos() as Vector2)
			var ex := 0.0
			for i in 3:
				for q in l3[i].p:
					ex = maxf(ex, q.distance_to(dock))
			_check("stapel %d: de keer bij het depot gaat eerst weg van het depot en blijft binnen 6 m" % (s.slot + 1), l3[0].end_pos().distance_to(dock) > 1.0 and (l3[0].end_pos() - dock).dot(front) > 1.0 and ex <= 6.0)
	_check("minstens één stapel ligt voor het depot en is getest (%d)" % tested, tested >= 1)
