class_name VoorraadVerkeer
extends RefCounted
## Verkeersregels voor de voorraadtrucks (scripts/voorraad_truck.gd): trucks rijden niet door elkaar heen, wachten op elkaar en blokkeren de poort niet.
##  - Rijstrook: een truck rijdt rechts van het midden van de weg (VoorraadBaan.rijstrook), dus een tegenligger passeert zonder dat iemand hoeft te
##    wachten. Op de brug en in de stad (SMAL) is de weg te smal: daar rijdt hij over het midden en mag er maar één truck tegelijk zijn.
##  - Laad- en losplek: bij een stapel kan één truck tegelijk laden en bij een depot één tegelijk lossen. Wie later komt, blijft op een wachtplek vóór de plek
##    staan (recht stuk, QUEUE_D meter ervoor, nooit in of vlak voor de poort) tot de plek vrij is. Dat is een "sleutel" in Voorraad (claim_resource).
##  - Kruispunt bij de poort: de depots, het stuk ertussen en de poort zijn voor één truck tegelijk (sleutel "poort:n" / "poort:z"). Een truck die terugkomt
##    pakt eerst de losplek en dan die sleutel, houdt hem tot hij gelost heeft en weer weg is. Anders zwaaien trucks van twee depots in elkaar.
##  - Eén truck per stapel: Voorraad.pick_slot stuurt niet meer dan QUEUE_MAX trucks naar dezelfde stapel, dus er staat geen rij op de weg.
##  - Afstand houden: elke truck kijkt langs zijn eigen baan vooruit. Staat er een truck (te dicht) op die baan, dan remt hij op tijd en houdt GAP vrij.
##    Bij een kruising of een tegenligger heeft de truck met de lading terug (en daarna de oudste) voorrang; de ander blijft staan.
##  - Poort: een wachtende truck blijft nooit in de poort staan (GATE-vak); hij stopt ervoor, ook als de truck voor hem pas voorbij de poort staat.
##  - Vastzitten: wachten is normaal (achter een truck die laadt, voor een bezette plek). Alleen een kring (A wacht op B, B op A, of via een bezette plek) is
##    een noodgeval: de truck die op een plek wacht (anders die met de laagste voorrang) rijdt dan een stukje achteruit over zijn eigen baan (en de trucks
##    die achter hem staan ook, als hij anders niet weg kan). Helpt dat na GHOST_AFTER seconden nog niet, dan rijdt hij kort door de ander heen (teller
##    `ghosts`: hoort in de tests 0 te blijven).
## Bewust niet: wrakken blokkeren de weg niet (een wrak is uit het spel).
## De meetkunde (vakken, overlap) is rekenwerk zonder scène en dus testbaar; de rest is per truck één instantie.

const HL := 3.3             # halve lengte van een truck (botsvak, zie voorraad_truck.gd)
const HW := 1.1             # halve breedte
const GAP := 1.6            # m: zoveel ruimte houdt een truck vrij voor de truck voor hem
const SAME_LANE := 2.4      # m: een truck die zo dicht naast mijn rijlijn rijdt (dezelfde kant op) zit in dezelfde rij
const GAP_X := 0.5          # m: zoveel ruimte houdt een truck vrij voor een truck die dwars of tegen staat (voor een truck in dezelfde rij blijft het GAP)
const SIDE := 0.15          # m: extra ruimte opzij bij het kijken of er iets in de weg staat
const LANE := 1.8           # m rechts van het midden van de weg (de weg is 6 m vrijgemaakt, een truck 2,2 m breed: twee trucks passeren elkaar met 1,4 m tussenruimte)
const TAPER := 10.0         # m waarover de rijstrook naar het midden loopt bij een laad- of losplek
const SMAL_TAPER := 6.0     # m waarover de rijstrook naar het midden loopt bij een smal stuk weg
const GATE_QUEUE := 16.0    # m voorbij de poort (buiten): zo ver staat een wachtende truck voor een stapel minstens van de poort
const QUEUE_D := 15.0       # m voor de laad-/losplek waar een wachtende truck blijft staan
const STEP := 0.9           # m tussen twee gecontroleerde plekken langs de baan
const A_SOFT := 3.2         # m/s²: zo rustig remt een truck voor een andere truck (hij kan harder: voorraad_truck.gd BRAKE)
const FAST := 1.5           # m/s: sneller is 'rijdt echt'; een tegenligger met minder dan dit wordt als stilstaand gezien
const AHEAD_T := 1.0        # s: zo ver vooruit kijkt een truck naar een tegenligger of kruisende truck
const LOOK_STAT := 30.0     # m: zo ver kijkt een truck vooruit naar een truck die stilstaat (om de poort vrij te houden)
const RELEASE_D := 11.0     # m: zo ver van de plek is een truck weg en komt de plek voor de volgende vrij
const BACK_AFTER := 3.0     # s stilstaan voor een truck die ook niet verder kan, daarna rijdt de truck met de laagste voorrang achteruit
const BACK_M := 8.0         # m achteruit
const BACK_V := 2.0         # m/s achteruit
const GHOST_AFTER := 20.0   # s: daarna rijdt hij door de ander heen (noodgeval)
const GHOST_T := 4.0
const GATE_HALF_Z := 3.2    # m: het vak bij een poort is 3,2 m diep aan elke kant van de muur
const GATE_EXTRA_X := 1.0
const GATE_RELEASE := 3.0   # m binnen de poort: een truck die zover is heeft het kruispunt tussen de depots achter zich
const SMAL := [Rect2(-80.0, -175.0, 160.0, 85.0)]   # de brug en de stad achter de brug (x, z, breedte, diepte)

static var _gates: Array = []

var truck: VoorraadTruck
var needs: Array = []       # wat de truck op de wachtplek moet pakken, in deze volgorde: {key, st (in welke staat komt hij vrij), pos, smal, gate}
var tok_n := 0              # hoeveel daarvan hij al heeft
var start_need: Dictionary = {}   # vóór hij uit het depot rijdt: de sleutel van de poort (alleen heen)
var start_ok := true
var wp_u := -1.0            # afstand langs de baan van de wachtplek (-1: geen)
var waiting := false        # wacht op een laad-/losplek
var blocker: VoorraadTruck = null
var need_room := false      # wil achteruit (kring) maar kan niet: de truck achter hem moet eerst achteruit
var stop_t := 0.0
var room_t := 0.0
var back_left := 0.0
var ghost_left := 0.0
var ghosts := 0
var backoffs := 0
var held: Array = []        # {key, st (in welke staat komt hij vrij), pos, smal}
var _acc := 0.0
var _dt := 0.05
var _probe := INF


# ---------------------------------------------------------------- meetkunde

## Een vak (rechthoek) met middelpunt c, kijkrichting psi, halve lengte hl en halve breedte hw: [c, voor, rechts, hl, hw].
static func box(c: Vector2, psi: float, hl: float, hw: float) -> Array:
	var f := Vector2(sin(psi), cos(psi))
	return [c, f, Vector2(f.y, -f.x), hl, hw]


## Overlappen twee vakken? (scheidende-as-test)
static func overlap(a: Array, b: Array) -> bool:
	var d: Vector2 = (b[0] as Vector2) - (a[0] as Vector2)
	var reach: float = float(a[3]) + float(a[4]) + float(b[3]) + float(b[4])
	if d.length_squared() > reach * reach:
		return false
	for ax: Vector2 in [a[1], a[2], b[1], b[2]]:
		var ra: float = absf((a[1] as Vector2).dot(ax)) * float(a[3]) + absf((a[2] as Vector2).dot(ax)) * float(a[4])
		var rb: float = absf((b[1] as Vector2).dot(ax)) * float(b[3]) + absf((b[2] as Vector2).dot(ax)) * float(b[4])
		if absf(d.dot(ax)) > ra + rb:
			return false
	return true


## Het vak van een truck.
static func truck_box(c: Vector2, psi: float, extra_l := 0.0, extra_w := 0.0) -> Array:
	return box(c, psi, HL + extra_l, HW + extra_w)


## De vakken bij de twee poorten (de poortopening plus de ruimte waarin de poort schuift).
static func gate_boxes() -> Array:
	return []   # er zijn geen vaste poorten meer (alleen de poorten die je zelf in je muur zet; een truck rijdt daar kinematisch doorheen)


## Staat een truck op deze plek (en met deze richting) in een poort?
static func in_gate(c: Vector2, psi: float) -> bool:
	var b := truck_box(c, psi)
	for g in gate_boxes():
		if overlap(b, g):
			return true
	return false


## Ligt het punt in het smalle stuk (de brug en de stad), met `extra` meter marge?
static func in_smal(p: Vector2, extra := 0.0) -> bool:
	for r: Rect2 in SMAL:
		if r.grow(extra).has_point(p):
			return true
	return false


## Voorrang: een truck die met lading naar het depot rijdt gaat voor, daarna de oudste.
static func prio(t: VoorraadTruck) -> float:
	return (1.0e12 if t.state == VoorraadTruck.S.TERUG and t.cargo > 0 else 0.0) - float(t.get_instance_id())


# ---------------------------------------------------------------- per truck

func setup(t: VoorraadTruck) -> void:
	truck = t


## Een nieuwe baan (heen of terug): waar moet de truck wachten tot de laad- of losplek vrij is, en welke sleutels heeft hij daarvoor nodig?
## Volgorde (voorkomt dat twee trucks op elkaars sleutel wachten): eerst de plek zelf (stapel of depot), dan de poort.
func begin(main: VoorraadBaan.Leg) -> void:
	waiting = false
	needs = []
	tok_n = 0
	start_need = {}
	start_ok = true
	wp_u = -1.0
	back_left = 0.0
	stop_t = 0.0
	if main == null or truck == null or not is_instance_valid(truck.sup):
		return
	var sup: Voorraad = truck.sup
	var L := main.length
	var wp := L - QUEUE_D
	if truck.state == VoorraadTruck.S.HEEN:
		var smal := sup.is_smal(truck.site_id)
		needs.append({"key": "stapel:" + truck.site_id, "st": VoorraadTruck.S.TERUG, "pos": truck.stop_pos, "smal": smal, "gate": false})
		if smal:
			for i in main.p.size():   # voor het smalle stuk: wacht op de gewone weg ervoor
				if in_smal(main.p[i], SMAL_TAPER):
					wp = minf(wp, main.s[i] - 12.0)
					break
		var gk := sup.gate_key(truck.depot)
		if not held_has(gk):
			start_need = {"key": gk, "st": VoorraadTruck.S.HEEN, "pos": Vector2.ZERO, "smal": false, "gate": true}
			start_ok = false
	elif truck.state == VoorraadTruck.S.TERUG:
		var dock := sup.dock_point(truck.depot)
		needs.append({"key": "dock:" + sup.depot_key(truck.depot), "st": VoorraadTruck.S.HEEN, "pos": dock, "smal": false, "gate": false})
		needs.append({"key": sup.gate_key(truck.depot), "st": VoorraadTruck.S.HEEN, "pos": dock, "smal": false, "gate": true})
	else:
		return
	wp_u = _wait_spot(main, wp)
	while tok_n < needs.size() and held_has(String(needs[tok_n].key)):
		tok_n += 1


## De wachtplek: vanaf `from_u` terug langs de baan de eerste plek die buiten de poort ligt en recht is (niet in een bocht of bij een afslag, daar zou hij de
## weg voor een tegenligger versperren). Is er geen recht stuk (een kronkelpad), dan de plek met de minste bocht. Hij wacht pas voorbij RELEASE_D van de
## plek waar hij vandaan komt, zodat hij die niet bezet houdt.
func _wait_spot(main: VoorraadBaan.Leg, from_u: float) -> float:
	var lo := minf(RELEASE_D + HL, main.length * 0.5)   # pas voorbij de plek waar hij vandaan komt, anders houdt hij die bezet
	# bij de poort buiten staat de rij van trucks die naar het depot terugkomen: de wachtplek voor de stapel ligt daar minstens GATE_QUEUE meter voorbij
	var gate_entry := -1.0
	var gate_exit := -1.0
	var w := 0.0
	while w <= main.length:
		var g := in_gate(main.pos(w), main.head(w))
		if g and gate_entry < 0.0:
			gate_entry = w
		elif not g and gate_entry >= 0.0:
			gate_exit = w
			break
		w += 1.0
	if gate_exit >= 0.0 and gate_exit < from_u:
		lo = maxf(lo, minf(gate_exit + GATE_QUEUE, from_u))
	elif gate_entry >= 0.0 and gate_entry >= from_u - 25.0:   # de poort ligt aan het eind van deze baan (terug naar het depot): niet vlak voor de poort wachten
		from_u = maxf(minf(from_u, gate_entry - GATE_QUEUE), lo)
	var best := -1.0
	var best_score := INF
	var u := maxf(from_u, lo)
	while u >= lo:
		if not in_gate(main.pos(u), main.head(u)):
			var bend := _bend(main, u)
			if bend < 0.5:
				return u
			var score := bend + (from_u - u) * 0.004   # liever dichtbij de plek
			if score < best_score:
				best_score = score
				best = u
		u -= 0.5
	return maxf(best, lo)


## Hoeveel bocht zit er rond deze plek (de lengte van een truck plus wat marge)? Rad; < 0,5 is vrijwel recht (een afslag of scherpe bocht is veel meer).
static func _bend(leg: VoorraadBaan.Leg, u: float) -> float:
	var a := maxf(u - (HL + 2.5), 0.0)
	var b := minf(u + (HL + 2.5), leg.length)
	var ha := leg.head(a)
	var hm := leg.head((a + b) * 0.5)
	var hb := leg.head(b)
	return maxf(absf(hm - ha), maxf(absf(hb - hm), absf(hb - ha)))


func held_has(key: String) -> bool:
	for h in held:
		if h.key == key:
			return true
	return false


## Pakt een sleutel (direct als hij vrij is).
func take_key(key: String, st: int, pos: Vector2, smal: bool, gate := false) -> bool:
	if truck.sup.claim_resource(key, truck):
		if not held_has(key):
			held.append({"key": key, "st": st, "pos": pos, "smal": smal, "gate": gate})
		return true
	return false


## Laat sleutels los waar de truck ver genoeg van weg is (of de poort uit is, of bij het depot is aangekomen).
func release_check() -> void:
	if held.is_empty():
		return
	var p := Vector2(truck.global_position.x, truck.global_position.z)
	for i in range(held.size() - 1, -1, -1):
		var h: Dictionary = held[i]
		if truck.state != int(h.st):
			continue
		var far: bool
		if bool(h.gate):
			# de uitrit-sleutel komt vrij als de truck weer vertrokken is: het stuk voor het depot is vrij als hij 16 m weg is
			far = p.distance_to(truck.sup.dock_point(truck.depot)) > 16.0
		elif bool(h.smal):
			far = not in_smal(p, 8.0)
		else:
			# bij een korte rit (een stapel vlak bij het depot) ligt de wachtplek minder dan RELEASE_D van de plek: dan lost hij eerder af,
			# anders wachten de trucks eeuwig op elkaar (de een houdt de stapel, de ander de uitrit)
			var leg_len: float = RELEASE_D / 0.4
			if not truck._legs.is_empty():
				leg_len = (truck._legs[truck._legs.size() - 1] as VoorraadBaan.Leg).length
			far = p.distance_to(h.pos) > minf(RELEASE_D, leg_len * 0.4)
		if far:
			truck.sup.release_resource(String(h.key), truck)
			held.remove_at(i)


func release_all() -> void:
	if truck != null and is_instance_valid(truck.sup):
		for h in held:
			truck.sup.release_resource(String(h.key), truck)
	held.clear()


## Is de sleutel van deze truck? (voor de tests en het paneel)
func owns(key: String) -> bool:
	return held_has(key)


## Hoe hard mag de truck rijden (m/s) vanwege de andere trucks en de wachtplek? `main`: de gewone baan (niet de keer).
func cap(delta: float, leg: VoorraadBaan.Leg, u: float, v: float, main: bool) -> float:
	var out := INF
	waiting = false
	if not start_ok:
		out = _start_cap()
	elif main:
		out = _token_cap(u, v)
	_acc += delta
	if _acc >= 0.05:
		_dt = _acc
		_acc = 0.0
		_probe = _scan(leg, u, v, main)
	return minf(out, _probe)


## Voor hij uit het depot rijdt moet de poort-sleutel vrij zijn (een truck van een ander depot of die terugkomt zit dan niet in het kruispunt).
## Een truck die terugkomt pakt hem al op zijn wachtplek en houdt hem tot hij gelost heeft en de poort weer uit is.
func _start_cap() -> float:
	if take_key(String(start_need.key), int(start_need.st), start_need.pos, false, true):
		start_ok = true
		return INF
	waiting = true
	return 0.0


func _token_cap(u: float, v: float) -> float:
	if tok_n >= needs.size() or wp_u < 0.0:
		return INF
	var ahead := wp_u - u
	if ahead > v * v / (2.0 * A_SOFT) + 2.0:
		return INF
	while tok_n < needs.size():
		var n: Dictionary = needs[tok_n]
		if take_key(String(n.key), int(n.st), n.pos, bool(n.smal), bool(n.gate)):
			tok_n += 1
		else:
			waiting = true
			return sqrt(2.0 * A_SOFT * maxf(ahead, 0.0))
	return INF


## De sleutel waar de truck nu op wacht ("" als hij niet wacht).
func wait_key() -> String:
	if not start_ok:
		return String(start_need.key)
	if tok_n < needs.size():
		return String(needs[tok_n].key)
	return ""


func _scan(leg: VoorraadBaan.Leg, u: float, v: float, main: bool) -> float:
	var me := truck
	blocker = null
	if ghost_left > 0.0:
		ghost_left -= _dt
		stop_t = 0.0
		return INF
	var c0 := leg.pos(u)
	var h0 := leg.head(u)
	var fwd := Vector2(sin(h0), cos(h0)) * float(leg.gear)
	var look := clampf(v * v / (2.0 * A_SOFT) + GAP + 5.0, 8.0, 24.0)
	var my_prio := prio(me)
	var in_gate_now := in_gate(c0, h0)
	var best := INF
	for o in me.get_tree().get_nodes_in_group("voorraadtruck"):
		var ot := o as VoorraadTruck
		if ot == null or ot == me or not is_instance_valid(ot) or ot.state == VoorraadTruck.S.WRAK:
			continue
		var oc := Vector2(ot.global_position.x, ot.global_position.z)
		var rel := oc - c0
		if rel.length() > LOOK_STAT + 2.0 * HL:
			continue
		var behind := fwd.dot(rel)
		if behind < -(2.0 * HL + GAP + 1.0):
			continue   # ver achter me
		if behind < -1.0 and Vector2(sin(ot.rotation.y), cos(ot.rotation.y)).dot(Vector2(sin(h0), cos(h0))) > 0.3:
			continue   # achter me en dezelfde kant op: die let zelf op mij (maar een tegenligger of kruisende truck die achter me zwaait niet)
		var od := Vector2(sin(ot.rotation.y), cos(ot.rotation.y)) * ot._vel_signed
		var vo := od.length()
		var moving := vo > 0.3
		var lat := absf(fwd.x * rel.y - fwd.y * rel.x)   # hoe ver de ander opzij van mijn rijlijn zit
		# in dezelfde rij: dezelfde kant op, dicht naast mijn rijlijn en echt vóór mij (en ik achter hem); anders rijdt hij in of kruist hij en geldt de voorrang
		var same := moving and od.normalized().dot(fwd) > 0.5 and lat < SAME_LANE and rel.dot(fwd) > 0.0 and rel.dot(od.normalized()) > 0.0
		if moving and not same and vo > FAST and my_prio > prio(ot):
			continue   # voorrang: de ander remt wel
		var vlead := maxf(0.0, od.dot(fwd)) if same else 0.0
		var dmax := look if moving else LOOK_STAT
		var ob := truck_box(oc, ot.rotation.y)
		if moving and not same:   # een tegenligger of kruisende truck komt nog verder: kijk een seconde vooruit
			ob = box(oc + od * (0.5 * AHEAD_T), ot.rotation.y, HL + vo * 0.5 * AHEAD_T, HW)
		var gap := GAP if Vector2(sin(ot.rotation.y), cos(ot.rotation.y)).dot(Vector2(sin(h0), cos(h0))) > 0.7 else GAP_X
		var side := SIDE
		if ot._vk.blocker == me and my_prio > prio(ot) and not same:   # de ander wacht op mij (voorrang): alleen echte botsing telt, anders wachten we op elkaar
			gap = 0.0
			side = 0.0
		var hit := -1
		var steps := int(dmax / STEP)
		for k in range(steps + 1):
			var uu := minf(u + float(k) * STEP, leg.length)
			if overlap(_probe_box(leg, uu, gap, side), ob):
				hit = k
				break
			if uu >= leg.length:
				break
		if hit < 0:
			continue
		var d_free := maxf(0.0, float(hit - 1) * STEP)
		if vlead < 1.0 and not in_gate_now:   # een truck die stilstaat: niet in de poort blijven staan maar ervoor
			while d_free > 0.0:
				var ue := minf(u + d_free, leg.length)
				if not in_gate(leg.pos(ue), leg.head(ue)):
					break
				d_free = maxf(0.0, d_free - STEP)
		var cp := sqrt(vlead * vlead + 2.0 * A_SOFT * d_free)
		if cp < best:
			best = cp
			blocker = ot
	# vastzitten: alleen een kring van trucks die op elkaar wachten is een probleem
	need_room = false
	if v < 0.2 and (blocker != null or waiting):
		var cyc := _cycle()
		if not cyc.is_empty():
			stop_t += _dt
			if stop_t > BACK_AFTER and _yielder(cyc) == me:
				if main and u > 2.0 and _rear_clear(leg, u):
					_start_back(u)
				else:
					need_room = true
					if stop_t > GHOST_AFTER:
						ghost_left = GHOST_T
						ghosts += 1
						stop_t = 0.0
		else:
			stop_t = 0.0
		# een truck voor mij kan niet achteruit omdat ik achter hem sta: dan eerst ik
		if blocker != null and blocker._vk.need_room and main and u > 2.0 and v < 0.2:
			room_t += _dt
			if room_t > 1.0:
				if _rear_clear(leg, u):
					_start_back(u)
				else:
					need_room = true
	else:
		stop_t = 0.0
		room_t = 0.0
	return best


## Het vak dat de truck op plek `uu` van zijn baan inneemt, met GAP extra ruimte vóór zich (in rijrichting) en SIDE opzij.
static func _probe_box(leg: VoorraadBaan.Leg, uu: float, gap := GAP, side := SIDE) -> Array:
	var h := leg.head(uu)
	var dir := Vector2(sin(h), cos(h)) * float(leg.gear)
	return box(leg.pos(uu) + dir * (gap * 0.5), h, HL + gap * 0.5, HW + side)


func _start_back(u: float) -> void:
	back_left = minf(BACK_M, u)
	stop_t = 0.0
	room_t = 0.0
	backoffs += 1


## Op wie wacht deze truck (die stilstaat): de truck die in de weg staat, of de truck die de laad-/losplek bezet houdt.
func waits_for() -> VoorraadTruck:
	if blocker != null and is_instance_valid(blocker) and blocker._speed_now < 0.3:
		return blocker
	if waiting and wait_key() != "":
		var o: Variant = truck.sup.resource_owner(wait_key())
		if o != null and o != truck and (o as VoorraadTruck)._speed_now < 0.3:
			return o
	return null


## De trucks die elkaar in een kring tegenhouden (A wacht op B, B op C, C op A), of leeg als er geen kring is.
func _cycle() -> Array:
	var chain: Array = [truck]
	var cur: VoorraadTruck = truck
	for _i in 6:
		var nxt: VoorraadTruck = cur._vk.waits_for()
		if nxt == null:
			return []
		if nxt == truck:
			return chain
		if chain.has(nxt):
			return []
		chain.append(nxt)
		cur = nxt
	return []


## Wie moet in een kring uit de weg: een truck die op een laad-/losplek wacht (die gaat toch nergens heen), anders de truck met de laagste voorrang.
static func _yielder(list: Array) -> VoorraadTruck:
	var waiters: Array = []
	for t: VoorraadTruck in list:
		if t._vk.waiting and t._vk.start_ok:
			waiters.append(t)
	return _lowest(waiters if not waiters.is_empty() else list)


## De truck met de laagste voorrang in een lijst.
static func _lowest(list: Array) -> VoorraadTruck:
	var low: VoorraadTruck = list[0]
	for t: VoorraadTruck in list:
		if prio(t) < prio(low):
			low = t
	return low


## Staat er niets vlak achter de truck (op zijn eigen baan), zodat hij achteruit kan?
func _rear_clear(leg: VoorraadBaan.Leg, u: float) -> bool:
	var back := maxf(u - 5.0, 0.0)
	var b := truck_box(leg.pos(back), leg.head(back), 0.6, 0.2)
	for o in truck.get_tree().get_nodes_in_group("voorraadtruck"):
		var ot := o as VoorraadTruck
		if ot == null or ot == truck or ot.state == VoorraadTruck.S.WRAK:
			continue
		if overlap(b, truck_box(Vector2(ot.global_position.x, ot.global_position.z), ot.rotation.y)):
			return false
	return true
