class_name Voorraad
extends Node3D
## Generals-plan stap 4 (A1, docs/GENERALS_PLAN.md): geld komt uit voorraad. Op de kaart liggen vier voorraadstapels, in je basis staat een
## voorraaddepot en voorraadtrucks rijden over vaste wegen (wegpunten) heen en weer. Kills geven geen punten meer (alleen score).
##  - Stapel: 2.500 punten voorraad, raakt op; daarna verschijnt er een nieuwe op een plek verder weg (SITES).
##  - Depot: het eerste staat er vanaf het begin met één gratis truck; extra depots koop je in het bouwscherm (Buildings.DEFS.depot).
##  - Truck: 600 punten per extra truck, hoogstens 3 per depot. Rijdt zelf, of naar de stapel die je in het depotpaneel kiest.
##  - Wegen: langs elke route zijn bomen, struiken en rotsen weggehaald (Foliage.clear_for_building), want voertuigen kunnen er niet doorheen.
## 4a: eenvoudige blokken en een eenvoudige kraan; de echte modellen komen in 4b.
## Verkeer (scripts/voorraad_verkeer.gd): trucks rijden niet door elkaar. Bij elke stapel laadt één truck tegelijk en bij elk depot lost er één tegelijk: een
## truck die later komt wacht QUEUE_D meter ervoor (claim_resource / release_resource), buiten de poort. Een nieuwe truck verschijnt pas als de laadplek van het depot vrij is.

const STACK := 2500            # punten voorraad op een nieuwe stapel
const SLOTS := 4               # stapels tegelijk op de kaart
const TRUCK_COST := 600
const TRUCKS_MAX := 3          # per depot
const TRIP_BASE := 100         # punten per rit, plus TRIP_PER_M per meter enkele reis
const TRIP_PER_M := 0.5
const ROAD_W := 7.0            # breedte (m) van de vrijgemaakte weg
const STOP_BEFORE := 7.70      # de truck stopt zoveel meter voor het midden van de stapel: zijn grijper (4,90 m voor de truck) staat dan op de afhaalkist (2,8 m voor de stapel)
const DOCK_OFFSET := 3.65      # m voor de voorkant van het depot staat de truck bij het lossen: de grijper (4,90 m) zet de kist dan op de laadplaat (2 m in het depot)
const SWING_ANGLE := 1.75       # rad: wijst de bestemming meer dan dit van de uitrit af, dan maakt de weg een ruime lus
const SWING_FWD := 6.0          # m: de lus gaat eerst zoveel voorbij het eind van de uitrit
const SWING_SIDE := 11.0        # m: en zoveel opzij, naar de kant van de bestemming
const PRE_DOCK := 20.0          # m: de vaste uitrit, een rechte weg van deze lengte recht voor het depot. Alle routes beginnen en eindigen aan het eind ervan
const STEM_MIN := 6.0           # m: korter mag de uitrit niet worden (bijvoorbeeld door een muur ervoor): daar draait een truck niet meer om
const STEM_W := 6.4             # m: breedte van het wegdek van de uitrit
const FIRE_RANGE := 13.0       # vijanden schieten op trucks binnen dit bereik
const FIRE_TAKE := 0.5         # en doen zoveel van hun normale schade (er is geen echt richten op een truck)
const QUEUE_MAX := 1           # zoveel trucks tegelijk op weg naar (of aan het laden bij) één stapel: er staat dus nooit een rij op de weg; een volgende kiest een andere stapel of wacht in het depot
## Plekken voor een stapel. De eerste vier liggen er aan het begin; de rest komt erbij als een stapel leeg is (altijd verder weg).
## "via" (alleen de stad, aan de overkant van de rivier) is het knooppunt van de stadsstraat waar de weg naar de stapel eindigt.
const SITES := [
	{"id": "bos", "name": "Bosrand", "pos": Vector2(24, -60)},
	{"id": "zuid", "name": "Zuidveld", "pos": Vector2(-72, 88)},
	{"id": "stad", "name": "Stad", "pos": Vector2(51, -126), "via": "stad6", "smal": true},   # smal: de brug en de stadsstraat, één truck tegelijk
	{"id": "oost", "name": "Oostveld", "pos": Vector2(128, 22)},
	{"id": "west", "name": "Westveld", "pos": Vector2(-110, -4)},
	{"id": "noordoost", "name": "Noordoost", "pos": Vector2(150, -50)},
	{"id": "zuidoost", "name": "Zuidoost", "pos": Vector2(120, 110)},
	{"id": "zuidwest", "name": "Zuidwest", "pos": Vector2(-120, 120)},
]

var stapels: Array = []        # SLOTS stuks: VoorraadStapel of null
var income_total := 0
var trips := 0
var started := false
var _astar := AStar2D.new()
var _ids := {}                 # knooppuntnaam -> id
var _pos := {}                 # knooppuntnaam -> Vector2 (x, z)
var _used := {}                # plek-id -> true: ligt er, of is leeg gegaan
var _claims := {}              # slot -> aantal trucks onderweg
var _roads := {}               # plek-id -> Node3D (eigenaar van de vrijgemaakte weg)
var _owners := {}              # sleutel ("stapel:<plek>", "dock:<depot>") -> de truck die de laad-/losplek bezet houdt
var _stems := {}     # depot_key -> {node, length, yaw}: het wegdek van de uitrit
var _waiters := {}   # sleutel -> [{truck, ts}]: de rij wachtende trucks
var _pending: Array = []       # depots waar een gekochte truck wacht tot de laadplek vrij is
var _engine: AudioStreamWAV
var _tick := 0.0


func _ready() -> void:
	name = "Voorraad"
	_build_graph()
	for _i in SLOTS:
		stapels.append(null)
	Game.changed.connect(_cleanup_trucks)


# ---------------------------------------------------------------- wegennet

func _node(n: String, p: Vector2) -> void:
	_pos[n] = p
	_ids[n] = _astar.get_available_point_id()
	_astar.add_point(_ids[n], p)


func _link(a: String, b: String) -> void:
	_astar.connect_points(_ids[a], _ids[b], true)


func _build_graph() -> void:
	# alleen de weg over de brug en door de stad (de stapel in de stad ligt aan de overkant van de rivier); alle andere wegen zijn vrije routes (_route_free)
	_node("brug", Vector2(0, -93.0))
	# de hoofdstraat (rond de wrakken en lantaarns) en de dwarsstraat naar het oosten
	var stad := [Vector2(-1.6, -99.5), Vector2(-1.6, -119.5), Vector2(1.8, -122.0), Vector2(4.0, -126.0), Vector2(20.0, -126.0), Vector2(46.0, -126.0)]
	var last := "brug"
	for i in stad.size():
		var n2 := "stad%d" % (i + 1)
		_node(n2, stad[i])
		_link(last, n2)
		last = n2


## Het dichtstbijzijnde knooppunt bij de weg: een los knooppunt (een plek of een pad-knoop) uit het net halen.
func _via_pos(via: String) -> Vector2:
	return _pos[via]


# ---------------------------------------------------------------- begin van het spel

## Zet een nieuw spel neer: het eerste depot met een gratis truck, en de eerste vier stapels met hun wegen.
func start_game() -> void:
	if started:
		return
	started = true
	income_total = 0
	trips = 0
	_used.clear()
	_claims.clear()
	_owners.clear()
	_pending.clear()
	for i in SLOTS:
		if i < SITES.size():
			_spawn_stapel(i, SITES[i])
	# het depot zet de speler zelf neer (gratis, Game.free_depot); de eerste truck verschijnt als het klaar is


func reset() -> void:
	started = false
	for i in stapels.size():
		if stapels[i] != null and is_instance_valid(stapels[i]):
			stapels[i].queue_free()
		stapels[i] = null
	for t in get_tree().get_nodes_in_group("voorraadtruck"):
		t.queue_free()
	_used.clear()
	_claims.clear()
	_owners.clear()
	_pending.clear()
	for k in _roads.keys():
		if is_instance_valid(_roads[k]):
			_roads[k].queue_free()
	_roads.clear()


func _spawn_stapel(slot: int, site: Dictionary) -> void:
	var s := VoorraadStapel.new()
	add_child(s)
	s.setup(site, slot, STACK, _face_of(site))
	stapels[slot] = s
	_used[site.id] = true
	Game.changed.emit()


## Waar de truck bij een plek stopt: STOP_BEFORE meter voor de stapel, aan de kant waar hij vandaan komt.
func stop_point(site: Dictionary, via: Vector2) -> Vector2:
	var dir: Vector2 = (site.pos - via)
	if dir.length() < 0.1:
		return site.pos
	return site.pos - dir.normalized() * STOP_BEFORE


# ---------------------------------------------------------------- depots en trucks

func depots() -> Array:
	var out: Array = []
	for b in Game.buildings:
		if b.kind == "depot":
			out.append(b)
	return out


## Het punt aan de voorkant van het depot waar de trucks beginnen en eindigen.
func dock_point(b: Dictionary) -> Vector2:
	var sz: Vector3 = Buildings.DEFS["depot"].size
	var front := Vector2(sin(float(b.yaw)), cos(float(b.yaw)))
	var p := Vector2(b.at.x, b.at.z) + front * (sz.z * 0.5 + DOCK_OFFSET)
	return p


## Een punt PRE_DOCK meter vóór het depot op de as van de voorkant: de truck rijdt van daar recht op het depot af.
func pre_dock_point(b: Dictionary) -> Vector2:
	return stem_end(dock_point(b), float(b.yaw))


## Het eind van de uitrit: PRE_DOCK meter recht voor het dock, of korter als er een muur (zonder poort) voor staat (dan 2,5 m ervoor).
func stem_end(dock: Vector2, yaw: float) -> Vector2:
	var front := Vector2(sin(yaw), cos(yaw))
	var far := dock + front * PRE_DOCK
	var best := PRE_DOCK
	for sg in _wall_segments():
		var hit: Variant = Geometry2D.segment_intersects_segment(dock, far, sg[0], sg[1])
		if hit != null:
			best = minf(best, dock.distance_to(hit as Vector2) - 2.5)
	return dock + front * maxf(best, 0.0)


## Waarom kan de uitrit van een depot op `at` met voorkant `yaw` niet (naam van wat ervoor staat), of "" als hij vrij is? Voor het plaatsen van een depot
## (`me`: het depot dat wordt verplaatst) en voor de weg van de trucks.
func stem_blocker(at: Vector3, yaw: float, me: Variant = null) -> String:
	var sz: Vector3 = Buildings.DEFS["depot"].size
	var front := Vector2(sin(yaw), cos(yaw))
	var dock := Vector2(at.x, at.z) + front * (sz.z * 0.5 + DOCK_OFFSET)
	var k := stem_end(dock, yaw)
	if dock.distance_to(k) < STEM_MIN:
		return "een muur vlak voor het depot"
	if Game.mcv_deployed:
		for i in 5:
			var p := dock.lerp(k, float(i) / 4.0)
			var p3 := Vector3(p.x, 0.0, p.y)
			if not Mcv.in_play_area(p3, 2.0):
				return "buiten het speelbare gebied"
			if not Mcv.dry_side(p3, 2.0):
				return "de rivier"
	var skip: Dictionary = me if me is Dictionary else {}
	for o in _obstacles(skip):
		for i in 11:
			var p := dock.lerp(k, float(i) / 10.0)
			var local: Vector2 = (p - (o[0] as Vector2)).rotated(float(o[1]))
			var half: Vector2 = o[2]
			if absf(local.x) <= half.x and absf(local.y) <= half.y:
				return String(o[3])
	return ""


## De richting (x, z) van een stapel naar de kant waar de truck vandaan komt: de voorkant van de stapel.
func _face_of(site: Dictionary) -> Vector2:
	# naar je kamp (of de startplek van de wagen); zodra een truck een rit begint draait de stapel naar zijn kant (prepare_trip)
	var t := Vector2(Game.base_pos.x, Game.base_pos.z) if Game.mcv_deployed else Vector2(Mcv.START_POS.x, Mcv.START_POS.z)
	var dd: Vector2 = t - (site.pos as Vector2)
	return dd.normalized() if dd.length() > 0.1 else Vector2(0, 1)


func trucks_of(b: Dictionary) -> Array:
	var out: Array = []
	for t in get_children():
		if t is VoorraadTruck and t.depot == b and is_instance_valid(t):
			out.append(t)
	return out


## Hoeveel trucks heeft dit depot (de gekochte die nog op een vrije laadplek wachten tellen mee; wrakken niet).
func alive_trucks_of(b: Dictionary) -> int:
	var n := pending_of(b)
	for t in trucks_of(b):
		if t.state != VoorraadTruck.S.WRAK:
			n += 1
	return n


## Gekochte trucks die nog niet verschenen zijn omdat de laadplek van het depot bezet is.
func pending_of(b: Dictionary) -> int:
	var n := 0
	for d in _pending:
		if d == b:
			n += 1
	return n


func can_buy_truck(b: Dictionary) -> bool:
	return Game.points >= TRUCK_COST and alive_trucks_of(b) < TRUCKS_MAX and not b.down and not Buildings.under_construction(b)


func buy_truck(b: Dictionary) -> bool:
	if not can_buy_truck(b) or not Game.buy(TRUCK_COST):
		return false
	_pending.append(b)
	Game.changed.emit()
	_service_pending()   # staat de laadplek vrij, dan staat de truck er meteen
	return true


func _spawn_truck(b: Dictionary) -> VoorraadTruck:
	var t := VoorraadTruck.new()
	add_child(t)
	t.setup(self, b, trucks_of(b).size())
	Game.changed.emit()
	return t


## Een gekochte truck verschijnt in het depot zodra de laadplek vrij is (niemand staat of rijdt er vlakbij en niemand wacht er op de plek).
func _service_pending() -> void:
	for i in range(_pending.size() - 1, -1, -1):
		var b: Dictionary = _pending[i]
		if not Game.buildings.has(b):
			_pending.remove_at(i)
			continue
		if Buildings.under_construction(b) or not dock_free(b):
			continue
		_pending.remove_at(i)
		_spawn_truck(b)


## Is de laadplek van dit depot vrij: niet in gebruik en geen truck binnen 9 m?
func dock_free(b: Dictionary) -> bool:
	if not resource_free("dock:" + depot_key(b)) or not resource_free(gate_key(b)):
		return false
	var at := dock_point(b)
	for t in get_tree().get_nodes_in_group("voorraadtruck"):
		var truck := t as VoorraadTruck
		if truck != null and is_instance_valid(truck) and truck.state != VoorraadTruck.S.WRAK and Vector2(truck.global_position.x, truck.global_position.z).distance_to(at) < 9.0:
			return false
	return true


# ---------------------------------------------------------------- verkeer: laad- en losplekken

## Sleutel van de uitrit van dit depot: het stuk vlak voor het depot is voor één truck tegelijk.
func gate_key(b: Dictionary) -> String:
	return "uitrit:" + depot_key(b)   # het stuk voor het depot is voor één truck tegelijk


## Sleutel van het depot (zijn plek): per depot kan één truck tegelijk lossen.
func depot_key(b: Dictionary) -> String:
	return "%d_%d" % [roundi(float(b.at.x) * 10.0), roundi(float(b.at.z) * 10.0)]


## Is de weg naar deze plek te smal om te passeren (de brug en de stad): één truck tegelijk, ook op de weg erheen?
func is_smal(site_id: String) -> bool:
	for s in SITES:
		if s.id == site_id:
			return bool(s.get("smal", false))
	return false


func _owner_of(key: String) -> Variant:
	var o: Variant = _owners.get(key)
	if o != null and is_instance_valid(o) and not (o as Node).is_queued_for_deletion() and (o as VoorraadTruck).state != VoorraadTruck.S.WRAK:
		return o
	return null


func resource_free(key: String) -> bool:
	return _owner_of(key) == null


## Pakt een laad- of losplek voor een truck: lukt als hij vrij is (of al van deze truck is) en er niemand eerder op wacht. Wie niet kan, komt achteraan
## in de rij van die sleutel (eerlijk: de truck die het eerst wachtte, staat ook voorop in de rijstrook, dus de ander kan er toch niet langs).
func claim_resource(key: String, t: VoorraadTruck) -> bool:
	var o: Variant = _owner_of(key)
	var q := _wait_queue(key)
	if (o != null and o != t) or (not q.is_empty() and q[0].truck != t and o != t):
		var found := false
		for e in q:
			if e.truck == t:
				e.ts = Time.get_ticks_msec()
				found = true
		if not found:
			q.append({"truck": t, "ts": Time.get_ticks_msec()})
		return false
	for i in range(q.size() - 1, -1, -1):
		if q[i].truck == t:
			q.remove_at(i)
	_owners[key] = t
	return true


## De rij trucks die op deze sleutel wacht (oudste voorop). Wie al een tijdje niet meer probeert, valt eruit.
func _wait_queue(key: String) -> Array:
	if not _waiters.has(key):
		_waiters[key] = []
	var q: Array = _waiters[key]
	var now := Time.get_ticks_msec()
	for i in range(q.size() - 1, -1, -1):
		var tr: Variant = q[i].truck
		if not is_instance_valid(tr) or (tr as VoorraadTruck).state == VoorraadTruck.S.WRAK or now - int(q[i].ts) > 400:
			q.remove_at(i)
	return q


func release_resource(key: String, t: VoorraadTruck) -> void:
	if _owners.get(key) == t:
		_owners.erase(key)


func resource_owner(key: String) -> Variant:
	return _owner_of(key)


func _cleanup_trucks() -> void:
	# een depot dat verkocht is, neemt zijn trucks mee
	for t in get_children():
		if t is VoorraadTruck and is_instance_valid(t) and not Game.buildings.has(t.depot):
			t.queue_free()


## Kiest de plek waar een truck heen rijdt: de bestemming van het depot, of automatisch de dichtstbijzijnde met voorraad.
func pick_slot(truck: VoorraadTruck) -> int:
	var d: Dictionary = truck.depot
	var want: int = int(d.get("dest", -1))
	if want >= 0 and want < SLOTS and stapels[want] != null and stapels[want].left > 0 and blocked_by(d, want) == "":
		return want
	var best := -1
	var bs := INF
	for i in SLOTS:
		if stapels[i] == null or stapels[i].left <= 0:
			continue
		if blocked_by(d, i) != "":
			continue   # de weg erheen is versperd door een gebouw
		if int(_claims.get(i, 0)) >= QUEUE_MAX:
			continue   # er laadt er al een en er wacht er een: een derde zou op de weg moeten blijven staan
		var score := route_length(d, i) + 40.0 * float(_claims.get(i, 0))
		if _owner_of("stapel:" + String(stapels[i].site.id)) != null:
			score += 60.0   # er wordt nu geladen: liever een stapel waar je meteen terecht kunt
		if score < bs:
			bs = score
			best = i
	return best


func claim(slot: int, delta: int) -> void:
	_claims[slot] = maxi(0, int(_claims.get(slot, 0)) + delta)


## De route van het depot naar een stapel: punten (x, z) van het depot via de poort en het net tot het stoppunt bij de stapel.
func route(d: Dictionary, slot: int) -> Array:
	return _route_free(d, slot)


# ---------------------------------------------------------------- vrije wegen zonder vast wegennet

## De weg van het depot naar een stapel zonder vaste poorten en wegen: recht vooruit het depot uit, dan rechtdoor naar de stapel. Ligt de stapel aan de
## overkant van de rivier (de stad), dan eerst naar de brug en door de stadsstraat (dezelfde knooppunten als altijd).
func _route_free(d: Dictionary, slot: int) -> Array:
	var site: Dictionary = stapels[slot].site
	var mids := _route_mids(site)
	var goal: Vector2 = mids[0] if not mids.is_empty() else site.pos
	var out: Array = _route_head(d, goal)
	var prev: Vector2 = out[out.size() - 1] if out.size() > 2 else out[1]
	if not mids.is_empty():
		prev = mids[mids.size() - 1]
	for m in mids:
		out.append(m)
	out.append(stop_point(site, prev))
	return _merge_close(out)


## De tussenpunten naar een stapel: bij een stapel aan de overkant van de rivier eerst naar de brug en door de stadsstraat, anders geen.
func _route_mids(site: Dictionary) -> Array:
	var sp: Vector2 = site.pos
	var mids: Array = []
	if sp.y < Data.river_z(sp.x) - Data.RIVER_HALF:
		mids.append(Vector2(Data.BRIDGE_X, Data.river_z(Data.BRIDGE_X) + 10.0))
		for id in _astar.get_id_path(_ids["brug"], _ids[site.via]):
			mids.append(_astar.get_point_position(id))
	return mids


## Het begin van elke route: het dock, het eind van de uitrit, een eventuele lus en (bij een omheining) de weg door de poort. `goal`: het eerste punt daarna.
func _route_head(d: Dictionary, goal: Vector2) -> Array:
	var out: Array = [dock_point(d), pre_dock_point(d)]
	# wijst de uitrit van de bestemming af, dan maakt de weg aan het eind een ruime lus (anders draaien heen en terug in dezelfde bocht om elkaar heen)
	var front := Vector2(sin(float(d.yaw)), cos(float(d.yaw)))
	var turn := front.angle_to((goal - (out[1] as Vector2)).normalized())
	if absf(turn) > SWING_ANGLE:
		var side := front.rotated(signf(turn) * PI * 0.5)
		var swing: Vector2 = (out[1] as Vector2) + front * SWING_FWD + side * SWING_SIDE
		if not _crosses_wall(out[1], swing, _wall_segments()):   # staat er een muur in de weg (je omheining), dan geen lus: de weg gaat dan via de poort
			out.append(swing)
	# staat er een muur tussen (je hebt een omheining), dan door de poort
	for pt in _gate_detour(out[out.size() - 1], goal):
		out.append(pt)
	return out


## Muurstukken (geen poorten) als lijnstukken (x, z) -> (x, z).
func _wall_segments() -> Array:
	var out: Array = []
	var walls := Kampmuur.existing()
	for k in walls:
		var w: Dictionary = walls[k]
		if str(w.get("kind", "")) != "kampmuur":
			continue
		var v1 := Kampmuur.vertex(Vector2i(k.x, k.y))
		var v2 := Kampmuur.vertex(Vector2i(k.z, k.w))
		out.append([Vector2(v1.x, v1.z), Vector2(v2.x, v2.z)])
	return out


## Kruist dit lijnstuk een muurstuk (een poort telt als opening)?
func _crosses_wall(a: Vector2, b: Vector2, segs: Array) -> bool:
	for s in segs:
		if Geometry2D.segment_intersects_segment(a, b, s[0], s[1]) != null:
			return true
	return false


## Staat er een muur tussen a en b, dan de punten van de weg door de dichtstbijzijnde poort (binnenkant, poort, buitenkant); anders niets.
func _gate_detour(a: Vector2, b: Vector2) -> Array:
	if Game.gates == null or not is_instance_valid(Game.gates):
		return []
	var segs := _wall_segments()
	if segs.is_empty() or not _crosses_wall(a, b, segs):
		return []
	var best: Variant = null
	var best_len := INF
	for g in Game.gates.list:
		if g.get("edge") == null or g.broken:
			continue
		var gp := Vector2(g.at.x, g.at.z)
		var l := a.distance_to(gp) + gp.distance_to(b)
		if l < best_len:
			best_len = l
			best = g
	if best == null:
		return []
	var gp2 := Vector2(best.at.x, best.at.z)
	var n := Vector2(sin(float(best.yaw)), cos(float(best.yaw)))
	var p1 := gp2 - n * 8.0
	var p2 := gp2 + n * 8.0
	if a.distance_to(p2) < a.distance_to(p1):
		var tmp := p1
		p1 = p2
		p2 = tmp
	return [p1, gp2, p2]


## De rechthoeken (middelpunt, draaiing, halve maten, naam) die een weg niet mag doorsnijden: je gebouwen en het hoofdkwartier met zijn voorplein, met de
## halve wegbreedte en een marge erbij. `skip` is het depot waar de weg begint.
func _obstacles(skip: Dictionary) -> Array:
	var out: Array = []
	for b in Game.buildings:
		if b == skip or b.down or b.kind == "kampmuur":
			continue   # muren worden apart gecontroleerd (een weg kruist ze alleen via een poort)
		var sz: Vector3 = Buildings.DEFS[b.kind].size
		out.append([Vector2(b.at.x, b.at.z), float(b.yaw), Vector2(sz.x, sz.z) * 0.5 + Vector2.ONE * 3.2, String(Buildings.DEFS[b.kind].name)])
	if Game.mcv_deployed:
		var c: Vector3 = Game.base_point(Vector3(0, 0, 3.0))
		out.append([Vector2(c.x, c.z), Game.base_yaw, Vector2(6.5, 6.0) + Vector2.ONE * 3.2, "het hoofdkwartier"])
	return out


## Welk gebouw versperrt de weg van dit depot naar deze stapel (naam), of "" als hij vrij is? Alleen in de MCV-modus (zonder vast net rijden trucks rechtdoor).
func blocked_by(d: Dictionary, slot: int) -> String:
	if slot < 0 or slot >= SLOTS or stapels[slot] == null:
		return ""
	var pts := route(d, slot)
	if pts.size() >= 2 and (pts[0] as Vector2).distance_to(stapels[slot].site.pos) < 20.0:
		return "te dicht bij de stapel"
	var segs := _wall_segments()
	if not segs.is_empty():
		for i in range(1, pts.size() - 1):
			if _crosses_wall(pts[i], pts[i + 1], segs):
				return "een muur zonder poort"
	var obs := _obstacles(d)
	for i in range(0, pts.size() - 1):   # ook de uitrit zelf (van het dock naar het eerste wegpunt)
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n := maxi(1, int(a.distance_to(b) / 1.5))
		for k in n + 1:
			var p: Vector2 = a.lerp(b, float(k) / float(n))
			for o in obs:
				var local: Vector2 = (p - (o[0] as Vector2)).rotated(float(o[1]))
				var half: Vector2 = o[2]
				if absf(local.x) <= half.x and absf(local.y) <= half.y:
					return String(o[3])
	return ""


## Maakt de weg vrij voor een rit (bomen, struiken, varens, gras en rotsen langs de route) en draait de stapel naar de kant waar de truck vandaan komt.
## Doet niets buiten de MCV-modus (daar liggen vaste wegen) en maar één keer per weg.
func prepare_trip(d: Dictionary, slot: int) -> void:
	if slot < 0 or stapels[slot] == null:
		return
	var s: VoorraadStapel = stapels[slot]
	var pts := route(d, slot)
	if pts.size() >= 2 and _owner_of("stapel:" + String(s.site.id)) == null:
		var from: Vector2 = pts[pts.size() - 2]
		var f: Vector2 = from - (s.site.pos as Vector2)
		if f.length() > 0.1:
			s.rotation.y = atan2(f.x, f.y)
	var key := "mcv:%s:%s" % [depot_key(d), String(s.site.id)]
	if _roads.has(key) and is_instance_valid(_roads[key]):
		return
	var holder := Node3D.new()
	holder.name = "Weg_" + key.replace(":", "_")
	add_child(holder)
	_roads[key] = holder
	var regions: Array = []
	for i in range(0, pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		if a.distance_to(b) < 0.5:
			continue
		regions.append({"name": "weg", "center": (a + b) * 0.5, "size": Vector2(a.distance_to(b) + 2.0, ROAD_W), "yaw": -atan2((b - a).y, (b - a).x)})
	holder.set_meta("cleared", Foliage.clear_for_building(holder.get_instance_id(), regions, Vector3.ZERO, 0.0, 0.5, true))


## Twee wegpunten die vlak bij elkaar liggen (bv. het eind van de poortas en het begin van het bospad, 1,5 m) worden één punt, in het midden. Zo is de
## baan heen en terug precies dezelfde lijn: VoorraadBaan._clean laat anders heen en terug een ander punt vallen, en de twee rijstroken liggen dan scheef
## over elkaar. De eerste twee en de laatste twee punten blijven (de aanloop naar het depot en de stapel).
func _merge_close(pts: Array) -> Array:
	var out: Array = []
	var i := 0
	while i < pts.size():
		var p: Vector2 = pts[i]
		var protected := i < 2 or i >= pts.size() - 2
		if not protected and i + 1 < pts.size() - 2 and p.distance_to(pts[i + 1]) < VoorraadBaan.KORT:
			out.append((p + (pts[i + 1] as Vector2)) * 0.5)
			i += 2
			continue
		out.append(p)
		i += 1
	return out


func route_length(d: Dictionary, slot: int) -> float:
	var r := route(d, slot)
	var len := 0.0
	for i in range(1, r.size()):
		len += (r[i] as Vector2).distance_to(r[i - 1])
	return len


## Wat een rit van dit depot naar deze stapel oplevert.
func trip_value(d: Dictionary, slot: int) -> int:
	return roundi((TRIP_BASE + TRIP_PER_M * route_length(d, slot)) / 10.0) * 10


func has_stock(slot: int, site_id: String) -> bool:
	return slot >= 0 and slot < SLOTS and stapels[slot] != null and stapels[slot].site.id == site_id and stapels[slot].left > 0


## Een truck laadt: haalt voorraad van de stapel. Leeg? Dan verschijnt er een nieuwe plek.
func take(slot: int, site_id: String, amount: int) -> int:
	if not has_stock(slot, site_id):
		return 0
	var s: VoorraadStapel = stapels[slot]
	var got := s.take(amount)
	if s.left <= 0:
		_stapel_leeg(slot)
	Game.changed.emit()
	return got


func _stapel_leeg(slot: int) -> void:
	var old: VoorraadStapel = stapels[slot]
	var old_site: Dictionary = old.site
	old.vanish()
	stapels[slot] = null
	var next: Variant = _next_site(old_site)
	Game.banner.emit("STAPEL %d OP" % (slot + 1), ("Nieuwe voorraad: %s" % next.name) if next != null else "Er is geen voorraad meer te vinden", 2.5)
	if next != null:
		_spawn_stapel(slot, next)


## De volgende plek: de dichtstbijzijnde onbezette die verder weg ligt dan de lege; anders de dichtstbijzijnde onbezette.
func _next_site(old: Dictionary) -> Variant:
	var d_old: float = (old.pos as Vector2).length()
	var best: Variant = null
	var best_d := INF
	for s in SITES:
		if _used.has(s.id):
			continue
		var d: float = (s.pos as Vector2).length()
		if d > d_old and d < best_d:
			best_d = d
			best = s
	if best != null:
		return best
	for s in SITES:
		if _used.has(s.id):
			continue
		var d2: float = (s.pos as Vector2).length()
		if d2 < best_d:
			best_d = d2
			best = s
	return best


## Een truck levert af in het depot: de punten komen binnen.
func deliver(amount: int, at: Vector3) -> void:
	if amount <= 0:
		return
	Game.add_income(amount)
	income_total += amount
	trips += 1
	Sfx.play("buy", 0.5, at)


func truck_lost(_t: VoorraadTruck) -> void:
	Game.changed.emit()


func set_dest(b: Dictionary, slot: int) -> void:
	if slot >= 0 and slot < SLOTS and stapels[slot] != null:
		var why := blocked_by(b, slot)
		if why != "":
			Game.banner.emit("WEG VERSPERD", why, 2.4)
			return
	b["dest"] = slot
	Game.changed.emit()


# ---------------------------------------------------------------- het wegdek van de uitrit

const ROAD_TAIL := 8.0          # m: het wegdek loopt zoveel voorbij het laatste punt (de poort of het eind van de uitrit) in de richting van de bestemming

## Elk depot krijgt zijn wegdek (donker asfalt met een onderbroken middenstreep en randlijnen): de uitrit en, per bestemming, de weg tot en door de poort.
## Zo zie je waar de trucks rijden en waar niets mag staan. Het wegdek verdwijnt met het depot en past zich aan als de muren, poorten of het depot veranderen.
func _sync_stems() -> void:
	var live := {}
	for b in depots():
		if b.down or not Game.buildings.has(b):
			continue
		var key := depot_key(b)
		live[key] = true
		var branches := road_branches(b)
		var sig := str(float(b.yaw)) + "|" + str(branches.map(func(br): return (br as Array).map(func(q): return Vector2(snappedf(q.x, 0.1), snappedf(q.y, 0.1)))))
		var cur: Variant = _stems.get(key)
		if cur != null and is_instance_valid(cur.node) and String(cur.sig) == sig:
			continue
		if cur != null and is_instance_valid(cur.node):
			(cur.node as Node).queue_free()
		var node := _road_node(b, branches)
		add_child(node)
		_stems[key] = {"node": node, "sig": sig}
		if b.has("node") and is_instance_valid(b.node):   # bomen, struiken en rotsen op het wegdek verdwijnen (samen met het stuk onder het depot zelf)
			var sz: Vector3 = Buildings.DEFS["depot"].size
			var regions: Array = [{"name": "depot", "center": Vector2.ZERO, "size": Vector2(sz.x, sz.z), "yaw": 0.0}]
			var world_regions: Array = []
			for br: Array in branches:
				for i in range(0, br.size() - 1):
					var p0: Vector2 = br[i]
					var p1: Vector2 = br[i + 1]
					if p0.distance_to(p1) < 0.5:
						continue
					world_regions.append({"name": "weg", "center": (p0 + p1) * 0.5, "size": Vector2(p0.distance_to(p1) + 2.0, STEM_W + 1.0), "yaw": -atan2((p1 - p0).y, (p1 - p0).x)})
			Foliage.clear_for_building((b.node as Node).get_instance_id(), regions, Vector3(b.at.x, 0.0, b.at.z), float(b.yaw), Foliage.BUILD_CLEAR_MARGIN, true)
			Foliage.clear_for_building(node.get_instance_id(), world_regions, Vector3.ZERO, 0.0, 0.25, true)
	for key in _stems.keys().duplicate():
		if not live.has(key):
			var gone: Variant = _stems[key]
			if is_instance_valid(gone.node):
				(gone.node as Node).queue_free()
			_stems.erase(key)


## De wegen van een depot als lijsten punten (Vector2, wereld): elke lijst begint bij het dock en loopt over de uitrit, een eventuele lus en de poort naar een
## bestemming. Bestemmingen met dezelfde weg staan er één keer in; geblokkeerde bestemmingen niet. Zonder bestemming: alleen de uitrit.
func road_branches(d: Dictionary) -> Array:
	var out: Array = []
	var seen := {}
	for i in SLOTS:
		if stapels[i] == null or blocked_by(d, i) != "":
			continue
		var site: Dictionary = stapels[i].site
		var mids := _route_mids(site)
		var goal: Vector2 = mids[0] if not mids.is_empty() else site.pos
		var pts: Array = _route_head(d, goal)
		var last: Vector2 = pts[pts.size() - 1]
		var dir := (goal - last)
		if dir.length() > 0.5:
			pts.append(last + dir.normalized() * ROAD_TAIL)
		var sig := str(pts.map(func(q): return Vector2(snappedf(q.x, 0.1), snappedf(q.y, 0.1))))
		if not seen.has(sig):
			seen[sig] = true
			out.append(pts)
	if out.is_empty():
		var front := Vector2(sin(float(d.yaw)), cos(float(d.yaw)))
		var k := pre_dock_point(d)
		out.append([dock_point(d), k, k + front * 3.0])
	return out


## Het wegdek: een lint langs de (afgeronde) weg, breed STEM_W, met randlijnen en een onderbroken middenstreep. Het gedeelde stuk (de uitrit) wordt maar één
## keer getekend. Alles staat op wereldcoördinaten.
func _road_node(d: Dictionary, branches: Array) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var front := Vector2(sin(float(d.yaw)), cos(float(d.yaw)))
	var start: Vector2 = (branches[0][0] as Vector2) - front * (DOCK_OFFSET + 0.4)   # een stuk onder de voorkant van het depot
	var stem_len := start.distance_to(branches[0][1])
	for bi in branches.size():
		var raw: Array = [start]
		raw.append_array(branches[bi])
		var poly: Array = VoorraadBaan._clean(raw[0], raw.slice(1))
		if poly.size() < 2:
			continue
		var leg: VoorraadBaan.Leg = VoorraadBaan._bochten(poly)
		if leg == null or leg.length < 1.0:
			continue
		var u0 := 0.0 if bi == 0 else stem_len + 1.0   # de volgende wegen delen de uitrit met de eerste
		var u := u0
		var prev_c := Vector2.ZERO
		var prev_n := Vector2.ZERO
		var have_prev := false
		while u <= leg.length:
			var pc: Vector2 = leg.pos(u)
			var h: float = leg.head(u)
			var n := Vector2(cos(h), -sin(h))   # rechts van de rijrichting
			if have_prev:
				_band(st, prev_c, prev_n, pc, n, -STEM_W * 0.5, STEM_W * 0.5, 0.035, Color(0.17, 0.17, 0.16))
				var e := STEM_W * 0.5 - 0.45
				for sg in [-1.0, 1.0]:   # randlijnen
					_band(st, prev_c, prev_n, pc, n, sg * e - 0.07, sg * e + 0.07, 0.045, Color(0.62, 0.6, 0.55))
				if fmod(u, 3.4) < 1.6:   # onderbroken middenstreep
					_band(st, prev_c, prev_n, pc, n, -0.07, 0.07, 0.045, Color(0.78, 0.7, 0.4))
			prev_c = pc
			prev_n = n
			have_prev = true
			u += 0.7
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.96
	mat.metallic_specular = 0.1
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_to_group("uitrit")
	return mi


## Een band langs de weg tussen twee punten (met hun rechterkant n): van x0 tot x1 dwars op de weg (negatief = links), op hoogte y.
func _band(st: SurfaceTool, c0: Vector2, n0: Vector2, c1: Vector2, n1: Vector2, x0: float, x1: float, y: float, col: Color) -> void:
	st.set_color(col)
	st.set_normal(Vector3.UP)
	var a := c0 + n0 * x0   # begin, links
	var b := c0 + n0 * x1   # begin, rechts
	var c := c1 + n1 * x1   # eind, rechts
	var d := c1 + n1 * x0   # eind, links
	for v in [a, b, c, a, c, d]:
		st.add_vertex(Vector3(v.x, y, v.y))


# ---------------------------------------------------------------- vijanden schieten op trucks

func _physics_process(delta: float) -> void:
	for b in depots():
		if b.get("gratis_truck", false) and not Buildings.under_construction(b) and not b.down:
			b["gratis_truck"] = false   # het gratis depot is klaar: de eerste truck is gratis
			_pending.append(b)
	if not _pending.is_empty():
		_service_pending()
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
	_sync_stems()
	if Game.state != "play":
		return
	for t in get_tree().get_nodes_in_group("voorraadtruck"):
		var truck := t as VoorraadTruck
		if truck == null or truck.state == VoorraadTruck.S.WRAK:
			continue
		for e in Game.enemies:
			if not is_instance_valid(e) or e.dead:
				continue
			var ty: Dictionary = e.t
			var melee: bool = bool(ty.get("melee", false))
			var reach: float = 2.6 if melee else minf(float(ty.get("range", 10.0)), FIRE_RANGE)
			if e.global_position.distance_to(truck.global_position) > reach:
				continue
			var burst := float(ty.get("burst", 1))
			var cycle := float(ty.get("rate", 1.0)) * burst + float(ty.get("pause", 0.0))
			var dps := float(ty.get("dmg", 5.0)) * burst / maxf(cycle, 0.2)
			truck.take(dps * FIRE_TAKE * 0.5)


# ---------------------------------------------------------------- motorgeluid

## Een zacht dieselgebrom (korte lus) voor alle trucks.
func engine_stream() -> AudioStreamWAV:
	if _engine != null:
		return _engine
	var rate := 22050
	var n := rate
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		var rumble := sin(TAU * 38.0 * t) * 0.5 + sin(TAU * 76.0 * t + 0.6) * 0.28 + sin(TAU * 114.0 * t) * 0.12
		var tick := 0.5 + 0.5 * sin(TAU * 19.0 * t)   # de cilinders: 19 klopjes per seconde, een hele getal per lus
		lp = lp * 0.9 + (rng.randf() * 2.0 - 1.0) * 0.1
		var s := clampf((rumble * (0.7 + 0.3 * tick) + lp * 0.5) * 0.5, -1.0, 1.0)
		data.encode_s16(i * 2, int(s * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	_engine = w
	return w
