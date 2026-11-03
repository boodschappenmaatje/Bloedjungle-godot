extends SceneTree
## Verkeer van de voorraadtrucks (scripts/voorraad_verkeer.gd): trucks rijden niet door elkaar heen, wachten op elkaar bij de laad-/losplek, blijven niet in de
## poort staan en zitten niet vast.
##  1. rekenwerk zonder scène: vakken, overlap, poortvak, smal stuk
##  2. drie trucks bij één depot (automatische bestemming): geen overlap, geen vastlopers, er komt geld binnen
##  3. dezelfde trucks met de stad (smalle brug) als bestemming: nooit twee trucks tegelijk op de brug
##  4. een gekochte truck verschijnt pas als de laadplek van het depot vrij is
## godot --headless --path . --script tests/voorraad_verkeer_test.gd --fixed-fps 60
## (Dit test de klassen met load() en niet bij naam: de autoloads bestaan nog niet als het script wordt gecompileerd.)

var main: Node
var frames := 0
var fails := 0
var vv                         # res://scripts/voorraad_verkeer.gd
var sup
var depot: Dictionary
var overlap_frames := 0
var gate_still := {}           # truck -> seconden stil in de poort
var max_gate_still := 0.0
var max_smal := 0
var smal_on := false
var phase := 0
var trips_a := 0
var pending_seen := false
var dock_busy_at_buy := false

const PHASE_A := 60 * 80       # drie trucks, automatische bestemming
const PHASE_B := 60 * 90       # de stad als bestemming


func _initialize() -> void:
	root.size = Vector2i(932, 430)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


func _ghosts() -> int:
	var n := 0
	for t in get_nodes_in_group("voorraadtruck"):
		n += int(t._vk.ghosts)
	return n


func _process(_d: float) -> bool:
	frames += 1
	var g = root.get_node("Game")
	if frames < 60:
		root.size = Vector2i(932, 430)
	if frames == 2:
		main.get_node("Hud/Sticks").set_process(false)
	if frames == 4:
		main.begin()
		for m in get_nodes_in_group("menus"):
			m._show("")
	if frames > 4 and g.state == "prep":
		g.prep_t = 1e9
	if frames == 30:
		_pure()
	if frames == 40:
		vv = load("res://scripts/voorraad_verkeer.gd")
		sup = g.supply
		g.points = 99999
		depot = sup.depots()[0]
		# de laadplek is bezet (de eerste truck staat erin): een gekochte truck wacht tot hij vrij is
		dock_busy_at_buy = not sup.dock_free(depot)
		sup.buy_truck(depot)
		sup.buy_truck(depot)
		pending_seen = sup.pending_of(depot) > 0
		_check("kopen terwijl de laadplek bezet is: de truck wacht (%d wachtend)" % sup.pending_of(depot), (not dock_busy_at_buy) or pending_seen)
		_check("een wachtende truck telt mee voor het maximum van 3", sup.alive_trucks_of(depot) == 3)
	if frames > 40:
		_measure(g)
	if frames == 40 + PHASE_A:
		_end_phase_a()
	if frames == 40 + PHASE_A + PHASE_B:
		_end_phase_b()
		print("klaar, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false


func _measure(g) -> void:
	var ts := get_nodes_in_group("voorraadtruck")
	# een truck die stilstaat staat niet in de poort
	for t in ts:
		var p := Vector2(t.global_position.x, t.global_position.z)
		var still: bool = t._speed_now < 0.3 and t.state in [1, 3]
		if still and vv.in_gate(p, t.rotation.y):
			gate_still[t.name] = float(gate_still.get(t.name, 0.0)) + 1.0 / 60.0
			max_gate_still = maxf(max_gate_still, float(gate_still[t.name]))
		else:
			gate_still[t.name] = 0.0
	# geen twee trucks door elkaar
	for i in ts.size():
		var a = ts[i]
		if a.state == 5:
			continue
		var ba = vv.truck_box(Vector2(a.global_position.x, a.global_position.z), a.rotation.y)
		for j in range(i + 1, ts.size()):
			var b = ts[j]
			if b.state == 5:
				continue
			if vv.overlap(ba, vv.truck_box(Vector2(b.global_position.x, b.global_position.z), b.rotation.y)):
				overlap_frames += 1
	# op de brug en in de stad: één truck tegelijk
	var in_smal := 0
	for t in ts:
		if vv.in_smal(Vector2(t.global_position.x, t.global_position.z)):
			in_smal += 1
	max_smal = maxi(max_smal, in_smal)


func _end_phase_a() -> void:
	trips_a = sup.trips
	_check("drie trucks bij één depot", sup.trucks_of(depot).size() == 3)
	_check("trucks rijden niet door elkaar (%d beelden met overlap)" % overlap_frames, overlap_frames == 0)
	_check("niemand zit vast: geen noodgevallen (%d keer door elkaar heen gereden)" % _ghosts(), _ghosts() == 0)
	_check("geen truck blijft in de poort staan (langste %.1f s)" % max_gate_still, max_gate_still < 2.0)
	_check("de trucks leveren geld af (%d ritten in %d s)" % [trips_a, PHASE_A / 60], trips_a >= 1)
	_check("alle gekochte trucks zijn verschenen (%d wachtend)" % sup.pending_of(depot), sup.pending_of(depot) == 0)
	# nu allemaal naar de stad (smalle brug en straat)
	sup.set_dest(depot, 2)
	max_smal = 0
	overlap_frames = 0
	max_gate_still = 0.0
	for k in gate_still.keys():
		gate_still[k] = 0.0


func _end_phase_b() -> void:
	_check("stad: nooit meer dan één truck tegelijk op de brug (%d)" % max_smal, max_smal <= 1)
	_check("stad: trucks rijden niet door elkaar (%d beelden met overlap)" % overlap_frames, overlap_frames == 0)
	_check("stad: geen noodgevallen (%d)" % _ghosts(), _ghosts() == 0)
	_check("stad: geen truck blijft in de poort staan (langste %.1f s)" % max_gate_still, max_gate_still < 2.0)
	_check("stad: de trucks leveren nog steeds af (%d ritten erbij)" % (sup.trips - trips_a), sup.trips > trips_a)


func _pure() -> void:
	var v = load("res://scripts/voorraad_verkeer.gd")
	var cmp: float = load("res://scripts/data.gd").COMPOUND
	# vakken en overlap
	var a = v.box(Vector2(0, 0), 0.0, 3.3, 1.1)
	_check("vak: twee trucks achter elkaar met 1 m ertussen botsen niet", not v.overlap(a, v.box(Vector2(0, 7.6), 0.0, 3.3, 1.1)))
	_check("vak: twee trucks die elkaar raken botsen", v.overlap(a, v.box(Vector2(0, 6.0), 0.0, 3.3, 1.1)))
	_check("vak: naast elkaar met 0,5 m ertussen botsen niet", not v.overlap(a, v.box(Vector2(2.7, 0), 0.0, 3.3, 1.1)))
	_check("vak: dwars over elkaar botst", v.overlap(a, v.box(Vector2(0, 0), PI / 2.0, 3.3, 1.1)))
	_check("vak: schuin (45 graden) naast elkaar op 4 m botst niet, op 2 m wel", not v.overlap(a, v.box(Vector2(4.5, 0), PI / 4.0, 3.3, 1.1)) and v.overlap(a, v.box(Vector2(2.0, 1.0), PI / 4.0, 3.3, 1.1)))
	# poort: de noordpoort ligt op (0, -COMPOUND)
	_check("poort: een truck in de poort staat in het poortvak", v.in_gate(Vector2(0, -cmp), 0.0))
	_check("poort: een truck 12 m voor de poort niet", not v.in_gate(Vector2(0, -cmp - 12.0), 0.0))
	_check("poort: ook de zuidpoort heeft een vak", v.in_gate(Vector2(0, cmp), 0.0))
	_check("poort: een truck dwars op de weg met zijn zijkant in het poortvak wordt ook gezien", v.in_gate(Vector2(0, -cmp - 3.0), PI / 2.0) and not v.in_gate(Vector2(0, -cmp - 5.0), PI / 2.0))
	# smal stuk
	_check("smal: de brug is smal", v.in_smal(Vector2(0, -130)))
	_check("smal: het bospad niet", not v.in_smal(Vector2(0, -60)))
	_check("smal: met marge ook 6 m ervoor", v.in_smal(Vector2(0, -85), 6.0) and not v.in_smal(Vector2(0, -85)))
