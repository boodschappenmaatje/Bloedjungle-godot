extends SceneTree
## Test van Aanvallen op de vijandbasis (Generals-plan, stap 5a-3a): rood vlakje op de radar, de tik op het vlakje in het teamwiel,
## de mars van je soldaten over de brug en door de stad naar zijn poort, en het beschieten van het hoofdkwartier zodra jij erbij komt.
## godot --headless --path . -s tests/aanval_basis_test.gd --fixed-fps 60
## Stap 5a-3a, keuze B: zonder jou rekent Beleg het beleg uit (HK-schade, terugschietende basis, meldingen); met jou erbij vechten ze echt.
## Duurt ruim 6000 beeldjes: de soldaat uit de bunker loopt het hele eind (ver van jou onzichtbaar, op de route).

const STAP_BUNKER_KLAAR := 5300   # beeldje waarop de soldaat uit de bunker aan het eind moet zijn (330 m op 4,6 m/s = 72 s = 4300 beeldjes)

var main: Node
var frames := 0
var fails := 0
var allies: Array = []
var world: Node
var hk_hp0 := 0.0
var hk_hp1 := 0.0
var hk_hp2 := 0.0
var banners: Array = []
var seen_far := false
# Scripts die `Game` gebruiken laden we pas in _initialize(): bij het compileren van dit testbestand bestaat de autoload nog niet.
var vb: GDScript
var ar: GDScript
var dt: GDScript
var ally_s: GDScript
var bl: GDScript
var P: Vector3
var HALF: Vector2
var GATE: float
var RANGE: float


func _initialize() -> void:
	vb = load("res://scripts/vijand_basis.gd")
	ar = load("res://scripts/aanval_routes.gd")
	dt = load("res://scripts/data.gd")
	ally_s = load("res://scripts/ally.gd")
	bl = load("res://scripts/beleg.gd")
	P = dt.get_script_constant_map()["VIJAND_POS"]
	HALF = dt.get_script_constant_map()["VIJAND_HALF"]
	GATE = dt.get_script_constant_map()["VIJAND_GATE"]
	RANGE = ally_s.get_script_constant_map()["RANGE"]
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


func _tc() -> Node:
	return get_first_node_in_group("team_commands")


func _hk() -> Node:
	return get_first_node_in_group("vijand_hk")


func _hud() -> Node:
	return get_first_node_in_group("hud_extra")


## Elke soldaat tijdens de mars: nooit in de rivier buiten brug of ondiepte, nooit door de muur van de vijandbasis buiten de poort.
func _watch(a, tag: String) -> void:
	var p: Vector3 = a.global_position
	var in_river: bool = absf(p.z - dt.river_z(p.x)) < dt.get_script_constant_map()["RIVER_HALF"] - 0.2
	var on_crossing: bool = absf(p.x - dt.get_script_constant_map()["BRIDGE_X"]) < 3.6 or absf(p.x - float(dt.get("FORD_X"))) < 4.5
	if in_river and not on_crossing:
		_check("%s loopt niet door de rivier (%s)" % [tag, str(p)], false)
		allies.erase(a)   # één melding is genoeg
	var in_wall_band: bool = absf(p.z - (P.z + HALF.y)) < 0.45 and absf(p.x - P.x) < HALF.x
	if in_wall_band and absf(p.x - P.x) > GATE - 0.2:
		_check("%s gaat alleen door de poort (%s)" % [tag, str(p)], false)
		allies.erase(a)


func _process(_d: float) -> bool:
	frames += 1
	var g = root.get_node("Game")
	var p = g.player
	if frames == 2:
		main.get_node("Hud/Sticks").set_process(false)
	if frames == 4:
		main.begin()
	if frames == 8:
		g.prep_t = 99999.0   # geen aanvalsgroep tijdens de test
		bl.vuur_factor = 0.0   # tijdens de mars schiet de basis niet terug; dat zetten we later aan
		g.banner.connect(func(big: String, _small: String, _time: float): banners.append(big))
		# 1. de hulpfuncties
		var path: Array = ar.march_path()
		_check("mars begint bij de noordkant van de brug", (path[0] as Vector3).is_equal_approx(Vector3(0, 0, -104)))
		_check("mars eindigt binnen de poort", (path[path.size() - 1] as Vector3).is_equal_approx(vb.gate_inside()))
		_check("mars gaat langs de poort vanbuiten", path.has(vb.gate_outside()))
		_check("plek 0 ligt vlak voor het HK", vb.hk_distance(vb.attack_spot(0)) < RANGE)
		_check("plek 6 ligt vlak voor het HK", vb.hk_distance(vb.attack_spot(6)) < RANGE)
		_check("rij 3 ligt ook binnen bereik", vb.hk_distance(vb.attack_spot(27)) < RANGE)
		_check("plekken liggen binnen de muur", vb.contains(vb.attack_spot(13), -2.0))
		_check("verschillende soldaten, verschillende plekken", not vb.attack_spot(0).is_equal_approx(vb.attack_spot(1)))
		_check("wie bij de brug staat, begint bij het begin", ar.march_start(Vector3(0, 0, 10)) == 0)
		_check("wie in de stad staat, slaat het begin over", ar.march_start(Vector3(-30, 0, -120)) >= 2)
		_check("wie al bij de poort staat, begint bij de poort", ar.march_start(vb.gate_outside()) >= path.size() - 2)
		_check("wie al in de vijandbasis staat, gaat rechtstreeks naar zijn plek", ar.march_start(vb.attack_spot(3)) == path.size())
		hk_hp0 = _hk().hp if _hk() != null else -1.0
		_check("het vijandelijke HK staat er", _hk() != null and hk_hp0 > 0.0)
		# 2. drie soldaten: uit de bunker, uit de stad, bij de poort
		world = p.get_parent()
		var starts := [Vector3(8, 0, 8), Vector3(-30, 0, -118), vb.gate_outside() + Vector3(2, 0, 2)]
		for i in starts.size():
			var a = ally_s.new()
			world.add_child(a)
			a.global_position = starts[i]
			a.setup(100.0, 16.0, i)
			g.allies.append(a)
			allies.append(a)
		# 3. het teamwiel: Aanvallen + tik op de basis geeft het bevel "basis"
		p.global_position = Vector3(0, 0, 4)
	if frames == 12:
		var tc := _tc()
		_check("teamwiel is er", tc != null)
		_check("radar kent de vijandbasis", _hud() != null)
		var hud := _hud()
		if hud != null and tc != null:
			var rect: Rect2 = hud._radar.get_global_rect()
			_check("radar is zichtbaar tijdens het spel", hud._radar.visible)
			_check("tik op de radar telt als radar", hud.radar_hit(rect.get_center()))
			_check("tik ver van de radar telt niet", not hud.radar_hit(rect.position - Vector2(200, 0)))
			# een andere keuze dan Aanvallen: de radartik opent de grote kaart, maar dat stuurt niemand naar de basis
			# (de kaart zelf, met tikken op het rode vlak, staat in grote_kaart_test: dit venster is hier te klein voor)
			tc.controller.pending_order = "move"
			tc.controller.target_pointer = -1
			tc._try_select_world(rect.get_center())
			_check("Verplaatsen: een tik op de radar opent de grote kaart", hud.map_is_open())
			_check("de kaart wacht dan op een doel en het bevel blijft staan", hud._map._target and tc.controller.pending_order == "move")
			hud._map.close_map()
			tc.cancel_input()
			tc.reset_squad()
			_check("Verplaatsen stuurt niet naar de basis", g.squad_order != "basis")
			# Aanvallen: wacht op een doel, de tik op de radar opent de kaart en de keuze van het rode vlak geeft het bevel "basis"
			tc.controller.pending_order = "attack"
			_check("Aanvallen wacht op een doel", hud._attack_pending())
			tc.controller.target_pointer = -1
			tc._try_select_world(rect.get_center())
			_check("Aanvallen: een tik op de radar opent de grote kaart", hud.map_is_open() and tc.controller.pending_order == "attack")
			hud._map.close_map()
			_check("het bevel wacht na het sluiten van de kaart op een doel", tc.controller.pending_order == "attack")
			_check("de keuze van de vijandbasis geeft het bevel", tc.pick_from_map(vb.gate_outside(), true))
			_check("bevel is basis", g.squad_order == "basis")
			_check("soldaten blijven op hun plek in 'hold' modus", g.troop_mode == "hold")
			_check("wacht niet meer op een doel", tc.controller.pending_order == "")
			var all_basis := true
			for a in allies:
				if a.command != "basis":
					all_basis = false
			_check("alle drie de soldaten kregen het bevel", all_basis)
			_check("soldaat uit de stad begint halverwege (leg %d)" % allies[1]._march_i, allies[1]._march_i >= 2)
			_check("soldaat bij de poort begint bij de poort (leg %d)" % allies[2]._march_i, allies[2]._march_i >= ar.march_path().size() - 2)
	if frames > 12 and frames < STAP_BUNKER_KLAAR + 60:
		for a in allies.duplicate():
			_watch(a, "soldaat %d" % a.idx)
		if frames % 60 == 0:
			for a in allies:
				if a._far:
					seen_far = true
	if frames == 1200:
		var a2 = allies[2] if allies.size() > 2 else null
		_check("soldaat bij de poort staat op zijn plek (%.1f m ervan)" % (a2.global_position.distance_to(vb.attack_spot(2)) if a2 else -1.0), a2 != null and a2.global_position.distance_to(vb.attack_spot(2)) < 1.0)
	if frames == 2600:
		var a1 = allies[1] if allies.size() > 1 else null
		_check("soldaat uit de stad staat op zijn plek (%.1f m ervan)" % (a1.global_position.distance_to(vb.attack_spot(1)) if a1 else -1.0), a1 != null and a1.global_position.distance_to(vb.attack_spot(1)) < 1.0)
	if frames == STAP_BUNKER_KLAAR:
		var a0 = allies[0] if allies.size() > 0 else null
		_check("soldaat uit de bunker staat op zijn plek (%.1f m ervan)" % (a0.global_position.distance_to(vb.attack_spot(0)) if a0 else -1.0), a0 != null and a0.global_position.distance_to(vb.attack_spot(0)) < 1.0)
		_check("onderweg waren ze onzichtbaar (ver van jou)", seen_far)
		var all_far := true
		var all_beleg := true
		for a in allies:
			if not a._far:
				all_far = false
			if not a.beleg_bezig():
				all_beleg = false
		_check("ze wachten onzichtbaar zolang jij er niet bent", all_far)
		_check("ze tellen mee in het beleg (B)", all_beleg and bl.aantal == 3 and bl.actief())
		hk_hp1 = _hk().hp
		_check("het HK is beschadigd zonder jou (%.0f van %.0f over)" % [hk_hp1, hk_hp0], hk_hp1 < hk_hp0 - 1.0)
		_check("aankomst van het leger is gemeld", banners.has("LEGER BIJ DE VIJANDBASIS"))
		_check("nog niemand gesneuveld zolang de basis niet terugschiet", g.allies.size() == 3 and bl.verloren == 0)
		# 4. de basis schiet terug: ze sneuvelen één voor één
		bl.vuur_factor = 5.0
	if frames == STAP_BUNKER_KLAAR + 400:
		_check("een soldaat is gesneuveld (%d over, %d verloren)" % [g.allies.size(), bl.verloren], bl.verloren >= 1 and g.allies.size() <= 2 and g.allies.size() >= 1)
		_check("het sneuvelen is gemeld", banners.has("SOLDAAT GESNEUVELD"))
		_check("het HK werd verder beschadigd", _hk().hp < hk_hp1)
		bl.vuur_factor = 0.0
		allies = allies.filter(func(a): return is_instance_valid(a) and not a.is_queued_for_deletion())
		hk_hp2 = _hk().hp
		# 5. jij komt dichtbij: de rest verschijnt en schiet echt
		p.hp = 10000.0   # deze routetest meet geen spelergevecht; vier nieuwe MG's mogen de omschakeling niet afbreken
		p.global_position = P + Vector3(0, 0, 14)
	if frames == STAP_BUNKER_KLAAR + 405:
		var all_near := true
		var visible_all := true
		for a in allies:
			if a._far:
				all_near = false
			if not a.model.visible:
				visible_all = false
		_check("als jij dichtbij komt zijn ze echt", all_near)
		_check("hun model is weer zichtbaar", visible_all)
	if frames == STAP_BUNKER_KLAAR + 650:
		var hp: float = _hk().hp
		_check("de soldaten beschieten het HK echt (%.0f van %.0f over)" % [hp, hk_hp2], hp < hk_hp2 - 3.0)
		# 6. Volgen roept ze terug, daarna weer naar de basis en jij gaat weg: het beleg gaat verder
		_tc()._issue("follow", Vector3.ZERO, null)
		var back := true
		for a in allies:
			if a.command != "follow":
				back = false
		_check("Volgen haalt het bevel weg", back and g.squad_order == "follow" and g.troop_mode == "follow")
		_tc()._issue("basis", vb.gate_outside(), null)
		p.global_position = Vector3(0, 0, 4)
	if frames == STAP_BUNKER_KLAAR + 900:
		var n := 0
		for a in allies:
			if a.beleg_bezig():
				n += 1
		_check("als jij weggaat beleggen ze opnieuw (%d van %d)" % [n, allies.size()], n == allies.size() and bl.actief())
		# 7. de basis is te sterk: het hele leger sneuvelt
		bl.vuur_factor = 100.0
	if frames == STAP_BUNKER_KLAAR + 1100:
		_check("het hele leger is gesneuveld (%d over)" % g.allies.size(), g.allies.size() == 0 and bl.verloren == 3)
		_check("dat is gemeld", banners.has("LEGER VERSLAGEN"))
		_check("het beleg is voorbij", not bl.actief() or bl.aantal == 0)
		bl.vuur_factor = 1.0
	if frames == STAP_BUNKER_KLAAR + 1110:
		print("klaar, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false
