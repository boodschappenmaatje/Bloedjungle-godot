extends SceneTree
## Test van de grote kaart (tik op de radar) en het commandowiel boven je duim, in de echte game.
## godot --headless --path . -s tests/grote_kaart_test.gd --fixed-fps 60
## Aanrakingen gaan via root.push_input(): dezelfde weg als een echte vinger (TouchSticks, TeamCommands, HudExtra, GroteKaart).

var main: Node
var frames := 0
var fails := 0
var banners: Array = []
# Scripts die `Game` gebruiken laden we pas in _initialize(): bij het compileren van dit testbestand bestaat de autoload nog niet.
var OUTER := 0.0
var INNER := 0.0


func _initialize() -> void:
	var wheel: GDScript = load("res://scripts/wheel_art.gd")
	OUTER = wheel.get_script_constant_map()["OUTER"]
	INNER = wheel.get_script_constant_map()["INNER"]
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	root.push_input(e)


func _tap(pos: Vector2, index := 5) -> void:
	_touch(index, pos, true)
	_touch(index, pos, false)


func _hud() -> Node:
	return get_first_node_in_group("hud_extra")


func _tc() -> Node:
	return get_first_node_in_group("team_commands")


func _process(_d: float) -> bool:
	frames += 1
	var g = root.get_node("Game")
	if frames == 2:
		root.size = Vector2i(932, 430)
	if frames == 4:
		main.begin()
	if frames == 8:
		g.prep_t = 99999.0
		g.banner.connect(func(big: String, _small: String, _time: float): banners.append(big))
	if frames == 12:
		var hud := _hud()
		var tc := _tc()
		_check("HUD en teamwiel zijn er", hud != null and tc != null)
		if hud == null or tc == null:
			return _klaar()
		var radar: Rect2 = hud._radar.get_global_rect()
		_check("radar staat rechtsboven (%s)" % str(radar), radar.position.x > 932.0 * 0.6 and radar.position.y < 100.0)
		_check("tik op de radar telt als radar", hud.radar_hit(radar.get_center()))
		_check("tik ver van de radar telt niet", not hud.radar_hit(Vector2(100, 300)))
		_check("het pauzeknopje blijft een pauzeknopje", not hud.radar_hit(hud._menu_button.get_global_rect().get_center()))
		_check("de grote kaart is dicht", not hud.map_is_open() and get_first_node_in_group("kaart_open") == null)
		# 1. overzicht: tik op de radar opent de kaart, de losgelaten vinger doet verder niets
		g.fire = true
		_touch(3, radar.get_center(), true)
		_check("tik op de radar opent de grote kaart", hud.map_is_open())
		_check("de kaart staat in de overzichtsstand", not hud._map._target)
		_check("lopen en schieten staan stil achter de kaart", get_first_node_in_group("kaart_open") != null)
		_touch(3, radar.get_center(), false)
		_check("de vinger die de kaart opende sluit hem niet", hud.map_is_open())
		var m: Rect2 = hud._map.map_rect()
		_check("de kaart is veel groter dan de radar (%.0f x %.0f tegen %.0f x %.0f)" % [m.size.x, m.size.y, radar.size.x, radar.size.y], m.size.y > radar.size.y * 2.6)
		_check("de kaart past in het scherm", Rect2(Vector2.ZERO, Vector2(932, 430)).encloses(m))
		_check("de kaart houdt de verhouding van de wereld", absf(m.size.x / m.size.y - (2.0 * 190.0) / (285.0 + 180.0)) < 0.01)
		_touch(4, Vector2(90, 350), true)
		_check("een vinger in de stickzone start niets achter de kaart", _stick_empty())
		_touch(4, Vector2(90, 350), false)
		return false
	if frames == 14:
		var hud := _hud()
		var tc := _tc()
		var radar: Rect2 = hud._radar.get_global_rect()
		_check("het schieten is uitgezet zolang de kaart open is", not g.fire and g.move == Vector2.ZERO)
		var m: Rect2 = hud._map.map_rect()
		_tap(m.get_center())
		_check("tik op de kaart sluit het overzicht", not hud.map_is_open() and get_first_node_in_group("kaart_open") == null)
		# 2. Aanvallen: tik op de radar, de kaart wacht op een doel
		tc.controller.pending_order = "attack"
		_touch(2, radar.get_center(), true)
		_check("tijdens Aanvallen opent de radartik de kaart", hud.map_is_open())
		_check("de kaart staat in de doelstand", hud._map._target)
		_check("het bevel blijft wachten", tc.controller.pending_order == "attack" and tc.controller.target_pointer == -2)
		_touch(2, radar.get_center(), false)
		_check("de loslating van de radartik kiest nog niets", g.squad_order != "basis" and hud.map_is_open())
		m = hud._map.map_rect()
		var patch: Rect2 = hud._base_patch(m)
		_check("het rode vlak is groot genoeg voor een duim (%.0f x %.0f)" % [patch.size.x, patch.size.y], patch.size.x >= 40.0 and patch.size.y >= 30.0)
		_check("het rode vlak ligt bovenaan de kaart", patch.get_center().y < m.position.y + m.size.y * 0.25)
		_tap(patch.get_center())
		_check("tik op het rode vlak op de grote kaart stuurt het leger", g.squad_order == "basis")
		_check("de kaart sluit na de keuze", not hud.map_is_open())
		_check("het bevel is uitgegeven", tc.controller.pending_order == "")
		_check("geen soldaten: dat wordt gemeld", banners.has("GEEN SOLDATEN"))
		tc.reset_squad()
		# 3. Verplaatsen: een punt op de grond
		tc.controller.pending_order = "move"
		hud.open_map(true)
		m = hud._map.map_rect()
		var want := Vector3(60.0, 0.0, 70.0)
		var scr: Vector2 = hud._radar_point(want, m)
		_tap(scr)
		_check("Verplaatsen via de kaart geeft dat punt (%s)" % str(g.squad_target), g.squad_order == "move" and Vector2(g.squad_target.x - want.x, g.squad_target.z - want.z).length() < 3.0)
		tc.reset_squad()
		# 4. Verplaatsen naar de vijandbasis wordt geweigerd, de kaart blijft open
		tc.controller.pending_order = "move"
		hud.open_map(true)
		m = hud._map.map_rect()
		patch = hud._base_patch(m)
		_tap(patch.get_center())
		_check("Verplaatsen in de vijandbasis kan niet", g.squad_order != "move" and hud.map_is_open() and tc.controller.pending_order == "move")
		# 5. SLUIT laat het bevel wachten
		var close: Rect2 = hud._map._close
		_tap(close.get_center())
		_check("SLUIT sluit de kaart", not hud.map_is_open())
		_check("het bevel blijft wachten na SLUIT", tc.controller.pending_order == "move")
		tc.cancel_input()
		# 6. niet tijdens bouwen
		g.build_mode = true
		_check("tijdens bouwen opent de kaart niet", not hud.open_map(false))
		g.build_mode = false
		_check("daarna wel weer", hud.open_map(false))
		hud._map.close_map()
		# 7. het wiel hangt boven je duim
		var origin: Vector2 = tc.button.get_global_rect().get_center()
		tc.controller.begin(7, origin)
		tc.controller.wheel_open = true
		var c: Vector2 = tc._wheel_center()
		var icons_ok := true
		var worst := 999.0
		for i in 4:
			var a := float(i) * PI * 0.5   # rechts, onder, links, boven
			var icon := c + Vector2(cos(a), sin(a)) * (OUTER + INNER) * 0.5
			worst = minf(worst, icon.distance_to(origin))
			if icon.distance_to(origin) < 40.0:
				icons_ok = false
		_check("je duim ligt op geen enkel pictogram van het wiel (dichtstbij %.0f punten)" % worst, icons_ok)
		_check("het wiel past op het scherm", Rect2(Vector2.ZERO, Vector2(932, 430)).encloses(Rect2(c - Vector2(OUTER, OUTER), Vector2(OUTER, OUTER) * 2.0)))
		tc.controller.move(7, origin, c)
		_check("zolang je vinger blijft liggen is er nog geen keuze", tc.controller.selected_sector == -1)
		tc.controller.move(7, c + Vector2(80, 0), c)
		_check("sleep naar rechts kiest Aanvallen", tc.controller.selected_sector == 0)
		tc.cancel_input()
		return _klaar()
	return false


func _stick_empty() -> bool:
	var sticks := get_first_node_in_group("touch_sticks")
	return sticks != null and sticks._sticks.is_empty()


func _klaar() -> bool:
	print("Grote kaart-test klaar, fouten: %d" % fails)
	quit(1 if fails > 0 else 0)
	return true
