extends SceneTree
## Test van het garnizoen in de stad (Generals-plan F2, keuzes 1A-8A en 9B van Dennis, 12 november 2026).
## godot --headless --path . -s tests/garnizoen_test.gd --fixed-fps 60
## Raamplekken uit de modellen, de vier vijandelijke gebouwen bij de start, schieten uit de ramen (op jou en op je soldaten),
## kogels doen weinig en ontploffingen veel, GEBOUW VRIJ met buit, je soldaten erin via de bevelstand en ERUIT, een vol gebouw,
## schieten van jouw garnizoen en terugschieten van de vijand, naar binnen lopen (5A), instorten = iedereen dood (9B), napalm, prestaties.

var main: Node
var frames := 0
var fails := 0
var banners: Array = []
var gz: GDScript
var ally_s: GDScript
var enemy_scene: PackedScene
var allies: Array = []
var wh: Variant = null       # het woonhuis waar jouw soldaten in gaan
var hp_voor := 0.0
var points_voor := 0
var vijand: Node = null
var fase := 0
var fase_t := 0
var zag_mikken := false


func _initialize() -> void:
	load("res://scripts/data.gd").set("mcv_autodeploy", true)
	gz = load("res://scripts/garnizoen.gd")
	ally_s = load("res://scripts/ally.gd")
	enemy_scene = load("res://scenes/enemy.tscn")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


func _g(kind: String) -> Variant:
	for g in gz.get("all"):
		if is_instance_valid(g) and g.huis.kind == kind:
			return g
	return null


func _alle(kind: String) -> Array:
	return (gz.get("all") as Array).filter(func(g): return is_instance_valid(g) and g.huis.kind == kind)


func _ts() -> Node:
	return get_first_node_in_group("troep_selectie")


func _process(_d: float) -> bool:
	frames += 1
	var g = root.get_node("Game")
	var p = g.player
	if frames == 2:
		main.get_node("Hud/Sticks").set_process(false)
	if frames == 4:
		main.begin()
	if frames == 30:
		g.prep_t = 99999.0   # geen aanvalsgroep tijdens de test
		g.banner.connect(func(big: String, _small: String, _time: float): banners.append(big))
		var all: Array = gz.get("all")
		var huizen := get_nodes_in_group("huis")
		_check("elk stadsgebouw heeft een garnizoen (%d van %d)" % [all.size(), huizen.size()], all.size() == huizen.size() and all.size() >= 13)
		for k in ["woonhuis", "kerk", "hotel", "winkel", "magazijn", "benzine"]:
			var gk = _g(k)
			_check("%s: raamplekken gevonden (%d)" % [k, gk.plekken.size() if gk else -1], gk != null and gk.plekken.size() >= 3)
		var kerk = _g("kerk")
		_check("kerk heeft een plek boven in de toren", kerk != null and kerk.plekken.any(func(q): return q.toren))
		_check("woonhuis: 17 ramen plus de voordeur", _g("woonhuis") != null and _g("woonhuis").plekken.size() == 18)
		# 7A: de vier sleutelgebouwen
		var n := 0
		for k in ["kerk", "hotel", "magazijn", "benzine"]:
			var gk = _g(k)
			_check("%s is bezet door de vijand" % k, gk != null and gk.partij == "vijand" and gk.bewoners.size() == gk.plaatsen())
			n += gk.bewoners.size() if gk else 0
		_check("samen 18 vijanden in gebouwen (%d)" % n, n == 18)
		var leeg := true
		for gk in _alle("woonhuis") + _alle("winkel"):
			leeg = leeg and gk.partij == ""
		_check("woonhuizen en winkel zijn leeg bij de start", leeg)
		_check("de sluipschutter zit in de toren", kerk.bewoners.filter(func(b): return b.toren).size() == 1)
		_check("stippen boven het hotel zichtbaar", _g("hotel")._stippen.visible and _g("hotel")._dots.filter(func(m): return m.visible).size() == 6)
		_check("woonhuis heeft geen stippen", not _g("woonhuis")._stippen.visible)
		_check("plaatsen naar grootte (2A)", _g("woonhuis").plaatsen() == 3 and _g("hotel").plaatsen() == 6 and _g("benzine").plaatsen() == 2 and _g("magazijn").plaatsen() == 4 and _g("winkel").plaatsen() == 5)
		# 3. de vijand schiet uit de ramen op jou
		var hotel = _g("hotel")
		p.global_position = hotel.deur() + Vector3(0, 0, 9.0)
		hp_voor = p.hp
		fase = 1
		fase_t = frames
	if fase == 1 and frames - fase_t == 240:
		var t1 := Time.get_ticks_usec()
		for i in 120:
			for gg in gz.get("all"):
				gg._physics_process(1.0 / 60.0)
		var per1 := float(Time.get_ticks_usec() - t1) / 120.0 / 1000.0
		print("garnizoen (18 vijanden, jij voor het hotel): %.3f ms per beeld" % per1)
		_check("garnizoen in gevecht kost minder dan 0,5 ms per beeld (%.3f)" % per1, per1 < 0.5)
		_check("de vijand in het hotel schiet op jou (hp %.0f -> %.0f)" % [hp_voor, p.hp], p.hp < hp_voor)
		p.hp = g.max_hp()
		# 4. kogels doen weinig: 20 kogels van 100 op een muurstuk met een raam
		var hotel = _g("hotel")
		var seg: Dictionary = {}
		for q in hotel.plekken:
			if q.seg != null:
				seg = q.seg
				break
		var voor := 0.0
		for b in hotel.bewoners:
			voor += b.hp
		var stuk := 0.0
		seed(4)
		for i in 6:
			hotel.kogel(seg, 20.0, true)
		var na := 0.0
		for b in hotel.bewoners:
			na += b.hp
		_check("kogels op een raam doen 30%% (verloren %.0f van hooguit 36)" % (voor - na), voor - na <= 36.01 and voor - na > 0.0)
		hotel.kogel(seg, 999.0, false)
		var na2 := 0.0
		for b in hotel.bewoners:
			na2 += b.hp
		_check("een vijandelijke kogel raakt zijn eigen mensen niet", absf(na2 - na) < 0.01)
		# 5. een granaat in het hotel: iedereen dood, GEBOUW VRIJ met buit
		points_voor = g.points
		banners.clear()
		gz.call("blast", hotel.global_position + Vector3(0, 1.0, 0), 4.5, 150.0, "vijand")
		_check("granaat in het hotel: alle bewoners dood", hotel.bewoners.is_empty() and hotel.partij == "")
		_check("melding GEBOUW VRIJ", banners.has("GEBOUW VRIJ"))
		_check("150 voorraad buit (%d -> %d)" % [points_voor, g.points], g.points >= points_voor + 150)
		_check("stippen weg", not hotel._stippen.visible)
		# napalm op de kerk: de toren blijft
		var kerk = _g("kerk")
		for i in 40:
			gz.call("brand", func(q: Vector3): return q.distance_to(kerk.global_position) < 12.0, 0.25)
		_check("napalm: alleen de sluipschutter in de toren leeft nog", kerk.bewoners.size() == 1 and kerk.bewoners[0].toren)
		# een ontploffing ver weg doet niets
		var benz = _g("benzine")
		gz.call("blast", benz.global_position + Vector3(0, 0, 40.0), 4.0, 999.0, "vijand")
		_check("een ontploffing ver weg doet niets", benz.bewoners.size() == 2)
		gz.call("blast", benz.global_position, 4.0, 999.0, "eigen")
		_check("een ontploffing van de vijand raakt zijn eigen mensen niet", benz.bewoners.size() == 2)
		# 9B: instorten = iedereen dood
		banners.clear()
		benz.huis._ruin_all()
		_check("instorten: alle bewoners van het benzinestation dood (9B)", benz.bewoners.is_empty())
		_check("instorten telt als vrijgemaakt", banners.has("GEBOUW VRIJ"))
		_check("het garnizoen bestaat nog na de ruïne", is_instance_valid(benz))
		# 6. jouw soldaten via de bevelstand in een woonhuis (4A), het vierde past niet
		wh = _g("woonhuis")
		p.global_position = wh.deur() + Vector3(0, 0, 14.0)
		var ts := _ts()
		_check("troepselectie is er", ts != null)
		var world: Node = p.get_parent()
		for i in 4:
			var a = ally_s.new()
			world.add_child(a)
			a.global_position = wh.deur() + Vector3(-3.0 + i * 2.0, 0, 6.0)
			a.setup(100.0, 16.0, i)
			g.allies.append(a)
			allies.append(a)
		ts.select(allies)
		var res: String = ts.apply_tap(wh.huis.global_position, null, null)
		_check("tik op het woonhuis = bevel bezet", res == "issued" and allies.all(func(a): return a.command == "bezet"))
		_check("tik op de kerk (vijand) wordt geweigerd", ts.apply_tap(_g("kerk").huis.global_position, null, null) == "geweigerd")
		fase = 2
		fase_t = frames
	if fase == 2 and frames - fase_t == 600:
		var binnen := allies.filter(func(a): return is_instance_valid(a) and a.binnen != null)
		_check("drie soldaten zijn binnen (%d)" % binnen.size(), binnen.size() == 3 and wh.bewoners.size() == 3 and wh.partij == "eigen")
		_check("binnen zijn ze onzichtbaar en rekenen ze niet", binnen.all(func(a): return not a.visible and a.process_mode == Node.PROCESS_MODE_DISABLED))
		var buiten := allies.filter(func(a): return is_instance_valid(a) and a.binnen == null)
		_check("de vierde past niet en verdedigt de deur", buiten.size() == 1 and buiten[0].command == "defend")
		_check("melding GEBOUW BEZET", banners.has("GEBOUW BEZET"))
		_check("wie binnen zit, kun je niet kiezen", binnen.all(func(a): return not load("res://scripts/troep_selectie.gd").commandable(a)))
		_check("wie binnen zit, is niet te raken voor M2 en tanks", binnen.all(func(a): return a.onraakbaar()))
		_check("groene stippen boven het woonhuis", wh._stippen.visible and wh._dots.filter(func(m): return m.visible).size() == 3)
		# 7. een vijand op straat voor het woonhuis: jouw garnizoen schiet, hij schiet terug op het raam
		buiten[0].set_command("hold", buiten[0].global_position)
		buiten[0].global_position = wh.deur() + Vector3(-30, 0, 30)
		vijand = enemy_scene.instantiate()
		vijand.setup("assault", 1)
		p.get_parent().add_child(vijand)
		vijand.global_position = wh.deur() + Vector3(0, 0, 9.0)
		hp_voor = vijand.hp
		var doel = gz.call("eigen_doel", vijand.global_position, 12.0)
		_check("de vijand op straat ziet een raam om op te schieten", doel != null)
		p.global_position = wh.deur() + Vector3(18, 0, 6.0)
		fase = 3
		fase_t = frames
	if fase == 3 and is_instance_valid(vijand) and vijand.get("_aim_pt") != null:
		zag_mikken = true
	if fase == 3 and frames - fase_t == 360:
		_check("de vijand op straat schoot terug op een raam", zag_mikken)
		_check("jouw garnizoen schiet de vijand op straat neer (hp %.0f -> %s)" % [hp_voor, str(vijand.hp) if is_instance_valid(vijand) else "weg"], not is_instance_valid(vijand) or vijand.dead or vijand.hp < hp_voor)
		# ERUIT
		var out: Array = wh.eruit()
		_check("ERUIT: drie soldaten naar buiten", out.size() == 3 and wh.bewoners.is_empty() and wh.partij == "")
		_check("buiten weer zichtbaar, bij de deur, en ze houden hun plek", out.all(func(a): return a.visible and a.binnen == null and a.command == "hold" and Vector2(a.global_position.x - wh.deur().x, a.global_position.z - wh.deur().z).length() < 2.5))
		# terug erin en het huis stort in: ze sneuvelen (9B)
		for a in out:
			wh.binnen_gaan(a)
		var n0: int = g.allies.size()
		wh.huis._ruin_all()
		_check("instorten met jouw soldaten erin: ze sneuvelen (9B)", wh.bewoners.is_empty() and g.allies.size() == n0 - 3)
		# 5A: jij loopt het magazijn in
		var mag = _g("magazijn")
		var e0: int = g.enemies.size()
		p.global_position = mag.deur()
		fase = 4
		fase_t = frames
	if fase == 4 and frames - fase_t == 20:
		var mag = _g("magazijn")
		_check("5A: bij de deur worden de bewoners echte vijanden", mag.bewoners.is_empty() and mag._binnen_vijanden.size() == 4)
		var in_huis: bool = mag._binnen_vijanden.all(func(e): return is_instance_valid(e) and mag.huis._in_foot(mag.huis.to_local(e.global_position), 0.6))
		_check("ze staan binnen in het magazijn", in_huis)
		_check("melding VIJAND BINNEN", banners.has("VIJAND BINNEN!"))
		banners.clear()
		for e in mag._binnen_vijanden:
			if is_instance_valid(e) and not e.dead:
				e.hit(9999.0, Vector3.FORWARD, true)
		p.global_position = Vector3(0, 0, 10)
		fase = 5
		fase_t = frames
	if fase == 5 and frames - fase_t == 10:
		_check("alle vier verslagen: GEBOUW VRIJ", banners.has("GEBOUW VRIJ") and _g("magazijn").partij == "")
		# radar en kaart tekenen zonder fouten
		var hud := get_first_node_in_group("hud_extra")
		if hud != null:
			hud._radar.queue_redraw()
		# prestaties: 13 garnizoenen een beeld rekenen, met de kerk nog bezet
		var t0 := Time.get_ticks_usec()
		for i in 300:
			for gg in gz.get("all"):
				gg._physics_process(1.0 / 60.0)
		var per := float(Time.get_ticks_usec() - t0) / 300.0 / 1000.0
		print("garnizoen: %.3f ms per beeld voor alle gebouwen" % per)
		_check("garnizoen kost minder dan 0,5 ms per beeld (%.3f)" % per, per < 0.5)
		print("klaar: %d fouten" % fails)
		quit(1 if fails > 0 else 0)
	if frames > 4000:
		_check("test liep niet vast", false)
		quit(1)
	return false
