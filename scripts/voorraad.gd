class_name Voorraad
extends Node3D
## Generals-plan stap 4 (A1, docs/GENERALS_PLAN.md): geld komt uit voorraad. Op de kaart liggen vier voorraadstapels, in je basis staat een
## voorraaddepot en voorraadtrucks rijden over vaste wegen (wegpunten) heen en weer. Kills geven geen punten meer (alleen score).
##  - Stapel: 2.500 punten voorraad, raakt op; daarna verschijnt er een nieuwe op een plek verder weg (SITES).
##  - Depot: het eerste staat er vanaf het begin met één gratis truck; extra depots koop je in het bouwscherm (Buildings.DEFS.depot).
##  - Truck: 600 punten per extra truck, hoogstens 3 per depot. Rijdt zelf, of naar de stapel die je in het depotpaneel kiest.
##  - Wegen: langs elke route zijn bomen, struiken en rotsen weggehaald (Foliage.clear_for_building), want voertuigen kunnen er niet doorheen.
## 4a: eenvoudige blokken en een eenvoudige kraan; de echte modellen komen in 4b.

const STACK := 2500            # punten voorraad op een nieuwe stapel
const SLOTS := 4               # stapels tegelijk op de kaart
const TRUCK_COST := 600
const TRUCKS_MAX := 3          # per depot
const TRIP_BASE := 100         # punten per rit, plus TRIP_PER_M per meter enkele reis
const TRIP_PER_M := 0.5
const ROAD_W := 6.0            # breedte (m) van de vrijgemaakte weg
const STOP_BEFORE := 9.44      # de truck stopt zoveel meter voor het midden van de stapel: zijn grijper (6,64 m voor de truck) staat dan op de afhaalkist (2,8 m voor de stapel)
const DOCK_OFFSET := 4.39      # m voor de voorkant van het depot staat de truck bij het lossen: de grijper (5,64 m) zet de kist dan op de laadplaat (2 m in het depot)
const PRE_DOCK := 9.0          # m voor het depot ligt een punt op de as, zodat de truck recht op het depot af komt
const FIRE_RANGE := 13.0       # vijanden schieten op trucks binnen dit bereik
const FIRE_TAKE := 0.5         # en doen zoveel van hun normale schade (er is geen echt richten op een truck)
const START_SPOTS := [         # waar het eerste depot komt (het eerste dat vrij is), met de voorkant naar de dichtstbijzijnde poort
	[Vector3(13, 0, -17), -PI / 2.0],
	[Vector3(-13, 0, -17), PI / 2.0],
	[Vector3(13, 0, 17), -PI / 2.0],
	[Vector3(-13, 0, 17), PI / 2.0],
]

## Plekken voor een stapel. De eerste vier liggen er aan het begin; de rest komt erbij als een stapel leeg is (altijd verder weg).
## "via" is het knooppunt van het wegennet waar de weg naar de stapel aftakt.
const SITES := [
	{"id": "bos", "name": "Bosrand", "pos": Vector2(24, -60), "via": "pad-58"},
	{"id": "zuid", "name": "Zuidveld", "pos": Vector2(-72, 88), "via": "poort_z_uit"},
	{"id": "stad", "name": "Stad", "pos": Vector2(51, -126), "via": "stad6"},
	{"id": "oost", "name": "Oostveld", "pos": Vector2(128, 22), "via": "poort_z_uit"},
	{"id": "west", "name": "Westveld", "pos": Vector2(-110, -4), "via": "west_m"},
	{"id": "noordoost", "name": "Noordoost", "pos": Vector2(150, -50), "via": "poort_n_uit"},
	{"id": "zuidoost", "name": "Zuidoost", "pos": Vector2(120, 110), "via": "poort_z_uit"},
	{"id": "zuidwest", "name": "Zuidwest", "pos": Vector2(-120, 120), "via": "poort_z_uit"},
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
	var c := Data.COMPOUND
	_node("poort_n_in", Vector2(0, -c + 6.0))
	_node("poort_n_uit", Vector2(0, -c - 6.0))
	_node("poort_z_in", Vector2(0, c - 6.0))
	_node("poort_z_uit", Vector2(0, c + 6.0))
	_link("poort_n_in", "poort_n_uit")
	_link("poort_z_in", "poort_z_uit")
	# rond de muur aan de westkant: van de noordpoort naar de zuidpoort
	_node("west_nw", Vector2(-c - 8.0, -c - 6.0))
	_node("west_m", Vector2(-c - 8.0, 0.0))
	_node("west_zw", Vector2(-c - 8.0, c + 6.0))
	_link("poort_n_uit", "west_nw")
	_link("west_nw", "west_m")
	_link("west_m", "west_zw")
	_link("west_zw", "poort_z_uit")
	# het kronkelpad door het bos naar de brug (Data.path_x): hier staan geen bomen
	var prev := "poort_n_uit"
	var z := -c - 6.0
	while z >= -90.0:
		var n := "pad%d" % int(z)
		_node(n, Vector2(Data.path_x(z), z))
		_link(prev, n)
		prev = n
		z -= 8.0
	_node("brug", Vector2(0, -93.0))
	_link(prev, "brug")
	# de stad achter de brug: de hoofdstraat (rond de wrakken en lantaarns) en de dwarsstraat naar het oosten
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
	for i in SLOTS:
		if i < SITES.size():
			_spawn_stapel(i, SITES[i])
	var d: Variant = Game.builds.place_start_depot()
	if d != null:
		_spawn_truck(d)


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


func _spawn_stapel(slot: int, site: Dictionary) -> void:
	var s := VoorraadStapel.new()
	add_child(s)
	s.setup(site, slot, STACK, _face_of(site))
	stapels[slot] = s
	_used[site.id] = true
	_make_road(site)
	Game.changed.emit()


## Haalt bomen, struiken en rotsen weg langs de weg naar deze plek (vanaf de beide poorten, want het net is vast).
func _make_road(site: Dictionary) -> void:
	if _roads.has(site.id) and is_instance_valid(_roads[site.id]):
		return
	var holder := Node3D.new()
	holder.name = "Weg_" + site.id
	add_child(holder)
	_roads[site.id] = holder
	var cleared := Foliage.clear_for_building(holder.get_instance_id(), road_regions(site), Vector3.ZERO, 0.0, 0.5, true)
	holder.set_meta("cleared", cleared)


## De vlakken (voor Foliage) van de weg naar een plek, vanaf beide poorten: elk wegstuk is een rechthoek (middelpunt, hoek, lengte, breedte).
func road_regions(site: Dictionary) -> Array:
	var regions: Array = []
	var seen := {}
	for gate in ["poort_n_in", "poort_z_in"]:
		var pts: Array = _polyline(gate, site)
		for i in range(0, pts.size() - 1):
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			if a.distance_to(b) < 0.5 or seen.has("%s>%s" % [a, b]):
				continue
			seen["%s>%s" % [a, b]] = true
			var mid := (a + b) * 0.5
			var ang := atan2((b - a).y, (b - a).x)
			regions.append({"name": "weg", "center": mid, "size": Vector2(a.distance_to(b) + 2.0, ROAD_W), "yaw": -ang})
	return regions


## De punten van de weg van een poort (binnenkant) naar een plek, in volgorde.
func _polyline(gate_in: String, site: Dictionary) -> Array:
	var out: Array = []
	var ids := _astar.get_id_path(_ids[gate_in], _ids[site.via])
	for id in ids:
		out.append(_astar.get_point_position(id))
	var via: Vector2 = _pos[site.via]
	var stop := stop_point(site, via)
	out.append(stop)
	return out


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
	var front := Vector2(sin(float(b.yaw)), cos(float(b.yaw)))
	return dock_point(b) + front * PRE_DOCK


## De richting (x, z) van een stapel naar de kant waar de truck vandaan komt: de voorkant van de stapel.
func _face_of(site: Dictionary) -> Vector2:
	var via: Vector2 = _pos[site.via]
	var d: Vector2 = via - site.pos
	return d.normalized() if d.length() > 0.1 else Vector2(0, 1)


func trucks_of(b: Dictionary) -> Array:
	var out: Array = []
	for t in get_children():
		if t is VoorraadTruck and t.depot == b and is_instance_valid(t):
			out.append(t)
	return out


func alive_trucks_of(b: Dictionary) -> int:
	var n := 0
	for t in trucks_of(b):
		if t.state != VoorraadTruck.S.WRAK:
			n += 1
	return n


func can_buy_truck(b: Dictionary) -> bool:
	return Game.points >= TRUCK_COST and alive_trucks_of(b) < TRUCKS_MAX and not b.down and not Buildings.under_construction(b)


func buy_truck(b: Dictionary) -> bool:
	if not can_buy_truck(b) or not Game.buy(TRUCK_COST):
		return false
	_spawn_truck(b)
	return true


func _spawn_truck(b: Dictionary) -> VoorraadTruck:
	var t := VoorraadTruck.new()
	add_child(t)
	t.setup(self, b, trucks_of(b).size())
	Game.changed.emit()
	return t


func _cleanup_trucks() -> void:
	# een depot dat verkocht is, neemt zijn trucks mee
	for t in get_children():
		if t is VoorraadTruck and is_instance_valid(t) and not Game.buildings.has(t.depot):
			t.queue_free()


## Kiest de plek waar een truck heen rijdt: de bestemming van het depot, of automatisch de dichtstbijzijnde met voorraad.
func pick_slot(truck: VoorraadTruck) -> int:
	var d: Dictionary = truck.depot
	var want: int = int(d.get("dest", -1))
	if want >= 0 and want < SLOTS and stapels[want] != null and stapels[want].left > 0:
		return want
	var best := -1
	var bs := INF
	for i in SLOTS:
		if stapels[i] == null or stapels[i].left <= 0:
			continue
		var score := route_length(d, i) + 40.0 * float(_claims.get(i, 0))
		if score < bs:
			bs = score
			best = i
	return best


func claim(slot: int, delta: int) -> void:
	_claims[slot] = maxi(0, int(_claims.get(slot, 0)) + delta)


## De route van het depot naar een stapel: punten (x, z) van het depot via de poort en het net tot het stoppunt bij de stapel.
func route(d: Dictionary, slot: int) -> Array:
	var site: Dictionary = stapels[slot].site
	var dock := dock_point(d)
	var gate := "poort_n_in" if dock.distance_to(_pos["poort_n_in"]) <= dock.distance_to(_pos["poort_z_in"]) else "poort_z_in"
	var out: Array = [dock, pre_dock_point(d)]
	for p in _polyline(gate, site):
		if out[out.size() - 1].distance_to(p) > 0.3:
			out.append(p)
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
	b["dest"] = slot
	Game.changed.emit()


# ---------------------------------------------------------------- vijanden schieten op trucks

func _physics_process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
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
