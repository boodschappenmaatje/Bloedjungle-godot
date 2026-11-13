class_name AanvalAI
extends Node
## Slimme vijandaanval (Generals-plan stap D2, keuze F; keuzes van Dennis 13 november 2026: 1A t/m 10A).
## Eén brein voor alle aanvalsgroepen van de vijand, geen brein per soldaat: twee keer per seconde telt het de verdediging per kant van jouw
## kamp, stuurt het de groepen en kiest het doelen. De soldaten blijven gewone enemy.gd-vijanden (dekking, flankeren, schieten); ze krijgen alleen
## een opdracht: een pad (path), een plek om te wachten (ai_hold), dekkingsvuur (ai_vuur) of een doel (ai_doel).
##  1A zwakste kant met een dobbelsteen: score per kant (N, O, Z, W) uit torens, M2's, wachten, soldaten, voertuigen, jij; gaten in de muur tellen zwak.
##  2A drie wegen: Center (brug), Flank (ondiepte) en Backdoor (een smalle derde oversteek, Data.BACKDOOR_X); na de rivier om je kamp heen.
##  3A verzamelen op RING_R m van het HK, dan vuur en beweging in twee ploegen, met een rookgordijn voor het open stuk.
##  4A doelgewichten: eerst wat terugschiet, dan productie (kazerne, garage, depot, trucks), het HK als laatste.
##  5A vanaf groep 4 soms een overvalteam van 3 man naar een truck, depot of eenzame toren, van een andere kant.
##  6A leren per kant (mislukt minder kans, doorgedrongen meer) en fasen: elke 3 verslagen groepen een fase hoger (2 rook en lichtkogel,
##     3 wachten op tank en jeep, 4 twee kanten tegelijk).
##  7A terugtrekken bij meer dan 60% verlies, terugroepen als jouw leger bij zijn basis staat, najagen als een kant van jou helemaal weg is.
##  8A heroveren: een ploeg van 3 neemt een stadsgebouw terug dat jij vrijmaakte of bezette.
##  9A verkenning: de kant zie je pas als iets van jou de groep ziet (toren, soldaat, voertuig, jij, satelliet): melding CONTACT en een lijn op de radar.
## 10A niveau Makkelijk/Normaal/Moeilijk (instelling "ai_niveau").

const KANTEN := ["N", "O", "Z", "W"]
const KANT_HOEK := {"N": PI, "O": PI * 0.5, "Z": 0.0, "W": -PI * 0.5}   # hoek zoals atan2(x, z): richting vanaf het HK
const KOMPAS := ["ZUID", "ZUIDOOST", "OOST", "NOORDOOST", "NOORD", "NOORDWEST", "WEST", "ZUIDWEST"]
const TEL_R := 55.0        # m: verdediging binnen deze straal van het HK telt mee
const RING_R := 70.0       # m: verzamelpunt, buiten jouw zicht
const STORM_R := 26.0      # m van het HK: hier houdt vuur en beweging op en stormen ze
const SPRONG := 9.0        # m per sprong van de oprukkende ploeg
const PLOEG_T := 3.2       # s per beurt van een ploeg
const DENK := 0.5          # s tussen twee denkstappen
const WACHT_MAX := 14.0    # s wachten op achterblijvers (fase 3: op voertuigen 28 s)
const VERLIES := 0.6       # meer verlies: terugtrekken
const ZICHT := {"speler": 40.0, "soldaat": 30.0, "toren": 45.0, "voertuig": 35.0}
const DOEL_R := 30.0       # m: zo ver kijkt een stormende soldaat naar een doel
const DREIG_R := 80.0      # m van de vijandbasis: jouw leger telt als dreiging
const NIVEAUS := {
	"makkelijk": {"temp": 3.0, "fase_max": 2, "fase_per": 3, "overval": 3},
	"normaal": {"temp": 1.6, "fase_max": 4, "fase_per": 3, "overval": 3},
	"moeilijk": {"temp": 0.8, "fase_max": 4, "fase_per": 2, "overval": 2},
}
const FASE_UITLEG := {2: "ROOK EN LICHTKOGELS", 3: "TANK EN INFANTERIE SAMEN", 4: "TWEE KANTEN TEGELIJK"}

static var aan := true     # tests kunnen het oude gedrag (vaste routes) terugzetten
static var ik: AanvalAI

var geheugen := {"N": 1.0, "O": 1.0, "Z": 1.0, "W": 1.0}
var verslagen := 0
var fase := 1
var groepen: Array = []
var contacten: Array = []   # {van, naar, t}: lijnen op de radar na contact
var laatste_score := {}
var _vorige_score := {}
var _denk_t := 0.0
var _najaag_cd := 30.0
var _dreiging_t := 0.0
var _herover_kandidaten: Array = []


func _ready() -> void:
	ik = self
	add_to_group("aanval_ai")


func _exit_tree() -> void:
	if ik == self:
		ik = null


static func niveau() -> Dictionary:
	return NIVEAUS.get(GameSettings.get_value("ai_niveau"), NIVEAUS["normaal"])


## Nieuw spel: alles vergeten.
func reset() -> void:
	geheugen = {"N": 1.0, "O": 1.0, "Z": 1.0, "W": 1.0}
	verslagen = 0
	fase = 1
	groepen.clear()
	contacten.clear()
	_vorige_score.clear()
	laatste_score.clear()
	_najaag_cd = 30.0
	_dreiging_t = 0.0
	_herover_kandidaten.clear()
	for g: Garnizoen in Garnizoen.all:
		if is_instance_valid(g) and g.partij == "vijand":
			_herover_kandidaten.append(g)


# ---------------------------------------------------------------- 1A: verdediging per kant

## Score per kant van jouw kamp. Hoger = sterker. Gaten in de muur (kapotte poort of stuk) maken een kant zwakker.
func scores() -> Dictionary:
	var s := {"N": 0.0, "O": 0.0, "Z": 0.0, "W": 0.0}
	var muren := {"N": 0, "O": 0, "Z": 0, "W": 0}
	var gaten := {"N": 0, "O": 0, "Z": 0, "W": 0}
	var p = Game.player
	if p != null and is_instance_valid(p) and not p.dead:
		_tel(s, p.global_position, 4.0)
	for a in Game.allies:
		if is_instance_valid(a) and a.binnen == null:
			_tel(s, a.global_position, 1.5)
	for w in get_tree().get_nodes_in_group("wacht"):
		_tel(s, (w as Node3D).global_position, 1.5)
	for v in VoertuigSchade.doelen():
		_tel(s, (v as Node3D).global_position, 5.0 if str(v.get_script().resource_path).ends_with("tank.gd") else 3.0)
	if Game.defs != null:
		for t in Game.defs.towers:
			if t.mg and is_instance_valid(t.node):
				_tel(s, t.pos, 3.0)
	for b in Game.buildings:
		if b.kind == "wachttoren" and not b.down:
			_tel(s, b.at, 2.0)
		elif b.kind == "kampmuur":
			var k := kant_van(b.at)
			if _flat(b.at - Game.base_pos).length() < TEL_R:
				if b.down:
					gaten[k] += 1
				else:
					muren[k] += 1
	if Game.gates != null:
		for g in Game.gates.list:
			var at: Vector3 = Game.gates.pos_of(g)
			if _flat(at - Game.base_pos).length() < TEL_R and float(g.get("hp", 1.0)) <= 0.0:
				gaten[kant_van(at)] += 2
	var omheind := 0
	for k in KANTEN:
		omheind += muren[k]
	for k in KANTEN:
		s[k] += minf(3.0, muren[k] * 0.12)
		s[k] -= gaten[k] * 1.0
		if omheind > 8 and muren[k] == 0:
			s[k] -= 1.0   # de rest is ommuurd, deze kant niet: een open kant
		s[k] = maxf(0.0, s[k])
	laatste_score = s
	return s


func _tel(s: Dictionary, at: Vector3, w: float) -> void:
	var d := _flat(at - Game.base_pos).length()
	if d > TEL_R:
		return
	if d < 9.0:
		for k in KANTEN:
			s[k] += w * 0.5   # midden in het kamp: helpt aan elke kant een beetje
		return
	s[kant_van(at)] += w


static func kant_van(at: Vector3) -> String:
	var v := _flat(at - Game.base_pos)
	if absf(v.x) > absf(v.y):
		return "O" if v.x > 0.0 else "W"
	return "Z" if v.y > 0.0 else "N"


## Kies een kant: de zwakste heeft de grootste kans (exp(-score / temp)), maal het geheugen (6A). Niet altijd: een dobbelsteen.
func kies_kant(sluit_uit := "") -> String:
	var s := scores()
	var temp: float = niveau().temp
	var gewicht := {}
	var som := 0.0
	for k in KANTEN:
		if k == sluit_uit:
			continue
		var w: float = exp(-float(s[k]) / temp) * float(geheugen[k])
		gewicht[k] = w
		som += w
	var r := randf() * som
	for k in gewicht:
		r -= gewicht[k]
		if r <= 0.0:
			return k
	return gewicht.keys()[0]


# ---------------------------------------------------------------- 2A: de weg

static func richting(kant: String) -> Vector3:
	var a: float = KANT_HOEK[kant]
	return Vector3(sin(a), 0.0, cos(a))


## Welke oversteek: de oversteek die het dichtst bij het verzamelpunt uitkomt, met een kans op een andere (verrassen).
static func kies_oversteek(rally: Vector3, anders_dan := "") -> String:
	var opties := {"brug": Data.BRIDGE_X, "ondiepte": Data.FORD_X, "achterdeur": Data.BACKDOOR_X}
	var best := "brug"
	var bd := INF
	for id in opties:
		if id == anders_dan:
			continue
		var x: float = opties[id]
		var d := Vector2(rally.x - x, rally.z - Data.river_z(x)).length() + randf_range(0.0, 25.0)
		if d < bd:
			bd = d
			best = id
	return best


## Het pad van de vijandbasis tot vlak over de rivier (zuidkant) via deze oversteek.
static func stad_pad(oversteek: String) -> Array:
	var out: Array = []
	match oversteek:
		"ondiepte":
			out = AanvalRoutes.path_from_base("industrie" if Data.FORD_X > 0.0 else "kade")
			var fx := Data.FORD_X
			var rz := Data.river_z(fx)
			out.append(Vector3(fx, 0.0, rz - 8.0))
			out.append(Vector3(fx, 0.0, rz))
			out.append(Vector3(fx, 0.0, rz + 8.0))
		"achterdeur":
			var bx := Data.BACKDOOR_X
			var rz := Data.river_z(bx)
			out = [VijandBasis.gate_outside() + Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(0.0, 3.0))]
			out.append(Vector3(bx * 0.6, 0.0, -212.0))
			out.append(Vector3(bx, 0.0, -170.0))
			out.append(Vector3(bx, 0.0, rz - 9.0))
			out.append(Vector3(bx, 0.0, rz))
			out.append(Vector3(bx, 0.0, rz + 8.0))
		_:
			out = AanvalRoutes.path_from_base(["brug", "wijk", "kade"].pick_random())
			var rz := Data.river_z(Data.BRIDGE_X)
			out.append(Vector3(Data.BRIDGE_X, 0.0, rz + 8.0))
	return out


## Om het kamp heen: punten op de ring rond het HK, in stappen van 45 graden, van de hoek waar je binnenkomt tot de gekozen kant.
static func ring_pad(van: Vector3, kant: String, r := RING_R) -> Array:
	var b := Game.base_pos
	var a0 := atan2(van.x - b.x, van.z - b.z)
	var a1: float = KANT_HOEK[kant]
	var diff := wrapf(a1 - a0, -PI, PI)
	var n := ceili(absf(diff) / (PI * 0.25))
	var out: Array = []
	for i in range(0, n + 1):
		var a := a0 + diff * (float(i) / maxf(1.0, float(n)))
		out.append(veilig(b + Vector3(sin(a), 0.0, cos(a)) * r))
	return out


## Een punt aan jouw kant van de rivier en binnen de kaart.
static func veilig(p: Vector3) -> Vector3:
	var c := Data.clamp_world(Vector2(p.x, p.z))
	var q := Vector3(c.x, 0.0, c.y)
	var rz := Data.river_z(q.x) + Data.RIVER_HALF + 5.0
	if q.z < rz:
		q.z = rz
	return q


## Het hele pad van een soldaat: stad, oversteek, ring, plek in de waaier op het verzamelpunt.
func pad_voor(g: Dictionary, idx: int, kant: String) -> Array:
	var out := stad_pad(g.oversteek)
	var laatste: Vector3 = out[out.size() - 1]
	var ring := ring_pad(laatste, kant)
	out.append_array(ring.slice(0, ring.size() - 1))
	out.append(waaier(rally_van(kant), kant, idx))
	return out


func rally_van(kant: String) -> Vector3:
	return veilig(Game.base_pos + richting(kant) * RING_R)


## Waaier op het verzamelpunt: rijen van vijf, 2 m uit elkaar, de rug naar buiten.
static func waaier(rally: Vector3, kant: String, idx: int) -> Vector3:
	var naar_hk := -richting(kant)
	var dwars := Vector3(-naar_hk.z, 0.0, naar_hk.x)
	var rij := idx / 5
	var kol := idx % 5 - 2
	return veilig(rally + dwars * (kol * 2.1 + (0.9 if rij % 2 else 0.0)) - naar_hk * rij * 2.0)


# ---------------------------------------------------------------- groepen

## Een nieuwe aanvalsgroep (main._launch_group): geeft de wachtrij-items terug. Kiest de kant, de oversteek en de extra ploegen (5A, 8A).
func nieuwe_groep(n: int, soorten: Array) -> Array:
	var kant := kies_kant()
	var g := _maak_groep(n, "hoofd", kant)
	if fase >= 4 and soorten.size() >= 6:
		g.kant2 = kies_kant(kant)   # 6A fase 4: twee kanten tegelijk
	var items: Array = []
	for kind in soorten:
		items.append({"kind": kind, "n": n, "groep": g})
	var nv: Dictionary = niveau()
	if n >= 4 and (n - 4) % int(nv.overval) == 0:
		var doel: Variant = _overval_doel()
		if doel != null:
			var o := _maak_groep(n, "overval", kant_van((doel as Node3D).global_position))
			o.doel = doel
			o.oversteek = kies_oversteek(rally_van(o.kant), g.oversteek)
			for i in 3:
				items.append({"kind": "assault", "n": n, "groep": o})
	if n >= 2 and n % 2 == 0:
		var gz: Variant = _herover_doel()
		if gz != null:
			var h := _maak_groep(n, "herover", kant)
			h.garnizoen = gz
			for i in 3:
				items.append({"kind": "assault", "n": n, "groep": h})
	return items


func _maak_groep(n: int, soort: String, kant: String) -> Dictionary:
	var g := {"n": n, "soort": soort, "kant": kant, "kant2": "", "leden": [], "start": 0, "staat": "mars", "t": 0.0, "wacht_t": -1.0,
		"ploeg": 0, "ploeg_t": 0.0, "gezien": false, "bereikt": false, "rook": false, "doel": null, "garnizoen": null,
		"oversteek": "brug", "voertuigen": [], "terug_t": 0.0}
	g.oversteek = kies_oversteek(rally_van(kant))
	groepen.append(g)
	return g


## Een vijand uit de wachtrij is net neergezet (main._spawn): hoort bij groep g.
func lid_erbij(g: Dictionary, e: Node3D) -> void:
	var idx: int = g.start
	g.start += 1
	g.leden.append(e)
	e.set("ai_groep", g)
	e.set("ai_ploeg", idx % 2)
	var kant: String = g.kant
	if g.kant2 != "" and idx % 2 == 1:
		kant = g.kant2
	e.set("ai_kant", kant)
	match g.soort:
		"herover":
			var gz: Garnizoen = g.garnizoen
			var pad: Array = AanvalRoutes.path_from_base(["brug", "wijk", "kade"].pick_random())
			pad.resize(mini(pad.size(), 2))
			pad.append(gz.deur() + Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(-1.5, 1.5)))
			e.set("path", pad)
		"overval":
			var pad2: Array = stad_pad(g.oversteek)
			var laatste: Vector3 = pad2[pad2.size() - 1]
			var ring := ring_pad(laatste, g.kant, 48.0)
			pad2.append_array(ring.slice(0, ring.size() - 1))
			e.set("path", pad2)
			e.set("ai_doel", g.doel)
		_:
			e.set("path", pad_voor(g, idx, kant))
			e.set("ai_hold", waaier(rally_van(kant), kant, idx))


## Een voertuig van deze groep (fase 3: de groep wacht erop).
func voertuig_erbij(n: int, v: Node3D) -> void:
	for g in groepen:
		if g.n == n and g.soort == "hoofd":
			g.voertuigen.append(v)
			return


func _levend(g: Dictionary) -> Array:
	var out: Array = []
	for e in g.leden:
		if is_instance_valid(e) and not e.dead:
			out.append(e)
	return out


# ---------------------------------------------------------------- denken

func _physics_process(delta: float) -> void:
	if not aan or Game.state == "over" or Game.state == "menu":
		return
	for c in contacten:
		c.t -= delta
	contacten = contacten.filter(func(c): return c.t > 0.0)
	for g in groepen:
		g.t += delta
		g.ploeg_t += delta
	_denk_t -= delta
	if _denk_t > 0.0:
		return
	_denk_t = DENK
	_najaag_cd -= DENK
	_check_dreiging()
	for g in groepen.duplicate():
		_denk_groep(g)
	_check_najagen()


func _denk_groep(g: Dictionary) -> void:
	var levend := _levend(g)
	var main := get_parent()
	var nog_in_rij := false
	if main != null and "queue" in main:
		for it in main.queue:
			if it is Dictionary and it.get("groep") == g:
				nog_in_rij = true
				break
	if levend.is_empty():
		if not nog_in_rij and g.start > 0:
			_groep_weg(g)
		return
	if not g.gezien:
		_verken(g, levend)
	for e in levend:
		if _flat(e.global_position - Game.base_pos).length() < 14.0:
			g.bereikt = true
	match g.soort:
		"herover":
			_denk_herover(g, levend)
			return
		"overval", "najaag":
			for e in levend:
				if e.get("path_i") >= (e.get("path") as Array).size():
					_zet_storm(e, g)
			return
	match g.staat:
		"mars":
			var aangekomen := 0
			for e in levend:
				var h: Variant = e.get("ai_hold")
				if h != null and _flat((h as Vector3) - e.global_position).length() < 3.0:
					aangekomen += 1
			if aangekomen > 0 and g.wacht_t < 0.0:
				g.wacht_t = 0.0
				g.staat = "verzamelen"
		"verzamelen":
			g.wacht_t += DENK
			var aangekomen := 0
			for e in levend:
				var h: Variant = e.get("ai_hold")
				if h != null and _flat((h as Vector3) - e.global_position).length() < 3.0:
					aangekomen += 1
			var max_t := WACHT_MAX
			var voertuig_klaar := true
			if fase >= 3:
				max_t = WACHT_MAX * 2.0
				for v in g.voertuigen:
					if is_instance_valid(v) and not bool(v.get("dead")) and (v as Node3D).global_position.z < Data.river_z((v as Node3D).global_position.x) + 6.0:
						voertuig_klaar = false   # fase 3: de tank of jeep is nog niet over de rivier
			var genoeg := not nog_in_rij and aangekomen >= ceili(levend.size() * 0.8)
			if (genoeg and voertuig_klaar) or g.wacht_t > max_t:
				_start_aanval(g, levend)
		"aanval":
			_denk_aanval(g, levend)
		"storm":
			for e in levend:
				_kies_doel(e)
		"terug":
			for e in levend:
				e.set("ai_vuur", false)
		"teruggeroepen":
			pass
	if g.staat in ["aanval", "storm"] and levend.size() <= int(floor(g.start * (1.0 - VERLIES))) and not nog_in_rij:
		_trek_terug(g, levend)


## 3A: de groep is compleet: rook voor het open stuk (en in fase 2 een lichtkogel), dan vuur en beweging.
func _start_aanval(g: Dictionary, levend: Array) -> void:
	g.staat = "aanval"
	g.ploeg = 0
	g.ploeg_t = PLOEG_T
	var kant: String = g.kant
	var rally := rally_van(kant)
	var midden := rally.lerp(Game.base_pos, 0.55)
	if not g.rook:
		g.rook = true
		var werper: Node3D = levend[0]
		AanvalFx.rookgranaat(get_parent(), werper.global_position + Vector3.UP * 1.4, midden, -richting(kant))
		if fase >= 2:
			AanvalFx.rookgranaat(get_parent(), werper.global_position + Vector3.UP * 1.4, rally.lerp(Game.base_pos, 0.75), -richting(kant))
			AanvalFx.lichtkogel(get_parent(), rally)
		if g.kant2 != "":
			var r2 := rally_van(g.kant2)
			AanvalFx.rookgranaat(get_parent(), r2 + Vector3.UP * 1.4, r2.lerp(Game.base_pos, 0.55), -richting(g.kant2))
	for e in levend:
		e.set("path", [])
		e.set("path_i", 0)


## Vuur en beweging: de ene ploeg rukt een sprong op (naar dekking als die er is), de andere geeft dekkingsvuur; dan wisselen.
func _denk_aanval(g: Dictionary, levend: Array) -> void:
	if g.ploeg_t >= PLOEG_T:
		g.ploeg_t = 0.0
		g.ploeg = 1 - int(g.ploeg)
		var dichtbij := false
		for e in levend:
			var kant: String = e.get("ai_kant")
			var naar := _flat(Game.base_pos - e.global_position)
			if naar.length() < STORM_R + 4.0:
				dichtbij = true
			var hk3 := Vector3(naar.x, 0.0, naar.y).normalized()
			if int(e.get("ai_ploeg")) == g.ploeg:
				var stap := minf(SPRONG, maxf(0.0, naar.length() - STORM_R + 2.0))
				var doel: Vector3 = e.global_position + hk3 * stap + Vector3(-hk3.z, 0.0, hk3.x) * randf_range(-1.5, 1.5)
				var dekking: Variant = e.call("_find_cover", Game.base_pos)
				if dekking != null and _flat((dekking as Vector3) - Game.base_pos).length() < naar.length() - 2.0 and _flat((dekking as Vector3) - e.global_position).length() < SPRONG * 1.4:
					doel = dekking
				e.set("ai_hold", veilig(doel) if kant != "" else doel)
				e.set("ai_vuur", false)
				e.set("ai_snel", true)
			else:
				e.set("ai_vuur", true)
				e.set("ai_snel", false)
			_kies_doel(e)
		if dichtbij:
			g.staat = "storm"
			for e in levend:
				_zet_storm(e, g)


func _zet_storm(e: Node, g: Dictionary) -> void:
	e.set("ai_hold", null)
	e.set("ai_vuur", false)
	e.set("ai_snel", false)
	e.set("ai_order", "storm")
	if g.soort != "overval" or not is_instance_valid(g.doel):
		_kies_doel(e)


## 4A: het beste doel binnen DOEL_R m van deze soldaat: gewicht per soort, minder op afstand. Niets: het HK (ai_doel = null).
func _kies_doel(e: Node) -> void:
	var at: Vector3 = (e as Node3D).global_position
	var best: Node3D = null
	var bs := 0.0
	var opties: Array = []
	var p = Game.player
	if p != null and is_instance_valid(p) and not p.dead:
		opties.append([p, 3.0])
	for a in Game.allies:
		if is_instance_valid(a) and not a.onraakbaar():
			opties.append([a, 3.0])
	for w in get_tree().get_nodes_in_group("wacht"):
		opties.append([w, 3.0])
	for v in VoertuigSchade.doelen():
		opties.append([v, 3.0])
	if Game.defs != null:
		for t in Game.defs.towers:
			if t.mg and is_instance_valid(t.node):
				opties.append([t.node, 3.0])
	for b in Game.buildings:
		if b.down or not is_instance_valid(b.node):
			continue
		if b.kind == "wachttoren":
			opties.append([b.node, 2.5])
		elif b.kind in ["kazerne", "garage", "depot", "helipad", "airfield"]:
			opties.append([b.node, 2.0])
	for t in get_tree().get_nodes_in_group("voorraadtruck"):
		opties.append([t, 2.0])
	for o in opties:
		var n: Node3D = o[0]
		var d := _flat(n.global_position - at).length()
		if d > DOEL_R:
			continue
		var sc: float = float(o[1]) * 10.0 / (10.0 + d)
		if sc > bs:
			bs = sc
			best = n
	e.set("ai_doel", best)


## 7A: zware verliezen: de rest trekt terug naar het verzamelpunt en sluit aan bij de volgende groep.
func _trek_terug(g: Dictionary, levend: Array) -> void:
	g.staat = "terug"
	_leer(g, false)
	var rally := rally_van(g.kant)
	for i in levend.size():
		var e: Node = levend[i]
		e.set("ai_order", "")
		e.set("ai_doel", null)
		e.set("ai_vuur", false)
		e.set("ai_snel", true)
		e.set("ai_hold", waaier(rally, g.kant, i))
	if g.gezien:
		Game.banner.emit("VIJAND TREKT TERUG", "Ze hergroeperen bij %s en sluiten aan bij de volgende groep" % KOMPAS[_kompas(rally)].to_lower(), 2.2)
	for ander in groepen:
		if ander != g and ander.soort == "hoofd" and ander.staat in ["mars", "verzamelen"]:
			_voeg_samen(g, ander)
			return


func _voeg_samen(van: Dictionary, naar: Dictionary) -> void:
	for e in _levend(van):
		var idx: int = naar.start
		naar.start += 1
		naar.leden.append(e)
		e.set("ai_groep", naar)
		e.set("ai_ploeg", idx % 2)
		e.set("ai_kant", naar.kant)
		e.set("ai_snel", false)
		var pad := ring_pad((e as Node3D).global_position, naar.kant)
		e.set("path", pad.slice(0, pad.size() - 1))
		e.set("path_i", 0)
		e.set("ai_hold", waaier(rally_van(naar.kant), naar.kant, idx))
	van.leden.clear()


## Een groep is weg (allemaal gesneuveld): leren, tellen, fase.
func _groep_weg(g: Dictionary) -> void:
	groepen.erase(g)
	if g.soort != "hoofd":
		return
	if g.staat != "terug":
		_leer(g, g.bereikt)
	verslagen += 1
	var nv: Dictionary = niveau()
	var nieuw := mini(int(nv.fase_max), 1 + verslagen / int(nv.fase_per))
	if nieuw > fase:
		fase = nieuw
		Game.banner.emit("VIJAND WISSELT VAN TACTIEK", "Fase %d: %s" % [fase, FASE_UITLEG.get(fase, "").to_lower()], 2.6)


## 6A: een kant waar hij doordrong krijgt meer kans, een kant waar hij faalde minder.
func _leer(g: Dictionary, gelukt: bool) -> void:
	for k in [g.kant, g.kant2]:
		if k == "":
			continue
		geheugen[k] = clampf(float(geheugen[k]) * (1.4 if gelukt else 0.6), 0.25, 3.0)


# ---------------------------------------------------------------- 9A: verkenning

func _verken(g: Dictionary, levend: Array) -> void:
	var zien: Array = []
	var p = Game.player
	if p != null and is_instance_valid(p) and not p.dead:
		zien.append([p.global_position, ZICHT.speler])
	for a in Game.allies:
		if is_instance_valid(a):
			zien.append([a.global_position, ZICHT.soldaat])
	for w in get_tree().get_nodes_in_group("wacht"):
		zien.append([(w as Node3D).global_position, ZICHT.soldaat])
	for v in VoertuigSchade.doelen():
		zien.append([(v as Node3D).global_position, ZICHT.voertuig])
	for b in Game.buildings:
		if b.kind == "wachttoren" and not b.down:
			zien.append([b.at, ZICHT.toren])
	if Game.defs != null:
		for t in Game.defs.towers:
			if is_instance_valid(t.node):
				zien.append([t.pos, ZICHT.toren])
	var satelliet := Game.satelliet_t > 0.0
	for e in levend:
		var at: Vector3 = e.global_position
		var gezien := satelliet
		if not gezien:
			for z in zien:
				if _flat((z[0] as Vector3) - at).length() < float(z[1]) and not AanvalFx.rook_blokkeert(at, z[0]):
					gezien = true
					break
		if gezien:
			_contact(g, at)
			return


func _contact(g: Dictionary, at: Vector3) -> void:
	g.gezien = true
	var naar: Vector3 = rally_van(g.kant) if g.soort == "hoofd" else at.lerp(Game.base_pos, 0.6)
	if g.soort == "herover" and g.garnizoen != null and is_instance_valid(g.garnizoen):
		naar = (g.garnizoen as Garnizoen).deur()
	contacten.append({"van": at, "naar": naar, "t": 45.0})
	Game.attack[kant_van(at) if _flat(at - Game.base_pos).length() < 90.0 else g.kant] = 6.0
	var wie := {"hoofd": "VIJANDELIJKE GROEP %d" % g.n, "overval": "OVERVALTEAM", "herover": "PLOEG NAAR DE STAD", "najaag": "VIJANDELIJKE PLOEG"}
	Game.banner.emit("CONTACT %s" % KOMPAS[_kompas(at)], "%s · ±%d man" % [wie.get(g.soort, "VIJAND"), _levend(g).size()], 2.4)
	if Game.builds != null and Game.builds.radio != null and _flat(at - Game.base_pos).length() < 90.0:
		Game.builds.radio.say("basis_aanval")


## 8 windrichtingen vanaf het HK.
static func _kompas(at: Vector3) -> int:
	var v := _flat(at - Game.base_pos)
	return posmod(roundi(atan2(v.x, v.y) / (PI * 0.25)), 8)


# ---------------------------------------------------------------- 5A overval, 8A heroveren, 7A terugroepen en najagen

func _overval_doel() -> Variant:
	var trucks := get_tree().get_nodes_in_group("voorraadtruck")
	if not trucks.is_empty():
		return trucks.pick_random()
	for b in Game.buildings:
		if b.kind == "depot" and not b.down and is_instance_valid(b.node):
			return b.node
	var s := scores()
	var best: Node3D = null
	var bs := INF
	for b in Game.buildings:
		if b.kind == "wachttoren" and not b.down and is_instance_valid(b.node):
			var sc: float = s[kant_van(b.at)]
			if sc < bs:
				bs = sc
				best = b.node
	return best


func _herover_doel() -> Variant:
	var opties: Array = []
	for gz: Garnizoen in Garnizoen.all:
		if not is_instance_valid(gz) or gz.ruine():
			continue
		if gz.partij == "eigen" or (gz.partij == "" and _herover_kandidaten.has(gz)):
			opties.append(gz)
	return null if opties.is_empty() else opties.pick_random()


func _denk_herover(g: Dictionary, levend: Array) -> void:
	var gz: Garnizoen = g.garnizoen
	if gz == null or not is_instance_valid(gz) or gz.ruine() or gz.partij == "vijand":
		_naar_hoofdgroep(g, levend)
		return
	var deur := gz.deur()
	var bij: Array = []
	for e in levend:
		if _flat(e.global_position - deur).length() < 3.5:
			bij.append(e)
	if gz.partij == "eigen":
		for e in levend:
			if e.get("path_i") >= (e.get("path") as Array).size():
				e.set("ai_hold", deur + _flat3(e.global_position - deur).normalized() * 7.0)
				e.set("ai_vuur", true)
		return
	if bij.size() >= mini(2, levend.size()):
		var n := 0
		for e in levend:
			if _flat(e.global_position - deur).length() < 9.0:
				Game.enemies.erase(e)
				e.queue_free()
				n += 1
		gz.vul_vijand(mini(n, gz.plaatsen()))
		g.leden.clear()
		groepen.erase(g)
		Game.banner.emit("VIJAND HEROVERT %s" % gz._naam(), "%d man in het gebouw" % n, 2.2)
		Game.changed.emit()


func _naar_hoofdgroep(g: Dictionary, levend: Array) -> void:
	for ander in groepen:
		if ander != g and ander.soort == "hoofd" and ander.staat in ["mars", "verzamelen"]:
			_voeg_samen(g, ander)
			groepen.erase(g)
			return
	g.soort = "najaag"
	for e in levend:
		var pad := stad_pad("brug")
		e.set("path", pad.slice(pad.size() - 2))
		e.set("path_i", 0)


## 7A: jouw leger bij zijn basis: groepen die nog aan zijn kant van de rivier lopen, keren om en verdedigen. Weg dreiging (25 s): weer aanvallen.
func _check_dreiging() -> void:
	var dreiging := 0.0
	var vb := Data.VIJAND_POS
	var p = Game.player
	if p != null and is_instance_valid(p) and not p.dead and _flat(p.global_position - vb).length() < DREIG_R:
		dreiging += 3.0
	for a in Game.allies:
		if is_instance_valid(a) and _flat(a.global_position - vb).length() < DREIG_R:
			dreiging += 1.0
	for v in VoertuigSchade.doelen():
		if _flat((v as Node3D).global_position - vb).length() < DREIG_R:
			dreiging += 2.0
	var bedreigd := dreiging >= 3.0
	if bedreigd:
		_dreiging_t = 25.0
		var geroepen := 0
		for g in groepen:
			if g.staat == "teruggeroepen" or g.soort == "herover":
				continue
			var levend := _levend(g)
			var noord := 0
			for e in levend:
				if e.global_position.z < Data.river_z(e.global_position.x) - 4.0:
					noord += 1
			if levend.is_empty() or noord < levend.size() * 0.5:
				continue
			g.staat = "teruggeroepen"
			for i in levend.size():
				var e: Node = levend[i]
				e.set("path", [VijandBasis.gate_outside(), VijandBasis.gate_inside()])
				e.set("path_i", 0)
				e.set("ai_hold", VijandBasis.attack_spot(i) + Vector3(0.0, 0.0, -4.0))
				e.set("ai_order", "")
				e.set("ai_vuur", true)
				e.set("ai_snel", true)
			geroepen += levend.size()
		if geroepen > 0:
			Game.banner.emit("VIJAND ROEPT ZIJN GROEPEN TERUG", "%d man gaan zijn basis verdedigen" % geroepen, 2.4)
	else:
		_dreiging_t -= DENK
		if _dreiging_t <= 0.0:
			for g in groepen:
				if g.staat == "teruggeroepen":
					_hervat(g)


func _hervat(g: Dictionary) -> void:
	g.staat = "mars"
	g.wacht_t = -1.0
	g.kant = kies_kant()
	g.oversteek = kies_oversteek(rally_van(g.kant))
	var levend := _levend(g)
	for i in levend.size():
		var e: Node = levend[i]
		e.set("path", pad_voor(g, i, g.kant))
		e.set("path_i", 0)
		e.set("ai_hold", waaier(rally_van(g.kant), g.kant, i))
		e.set("ai_kant", g.kant)
		e.set("ai_vuur", false)
		e.set("ai_snel", false)


## 7A najagen: een kant die sterk was is nu helemaal weg: er gaat meteen een ploeg van 3 heen.
func _check_najagen() -> void:
	if not Game.mcv_deployed or Game.state not in ["prep", "play"]:
		return
	var s := laatste_score if not laatste_score.is_empty() else scores()
	if _najaag_cd <= 0.0 and not _vorige_score.is_empty():
		for k in KANTEN:
			if float(_vorige_score.get(k, 0.0)) >= 3.0 and float(s[k]) <= 0.5:
				_najaag_cd = 75.0
				var main := get_parent()
				if main != null and main.has_method("ploeg_uitsturen"):
					var g := _maak_groep(maxi(1, Game.wave), "najaag", k)
					main.ploeg_uitsturen(g, 3)
				break
	_vorige_score = s.duplicate()


## Najaag-ploeg: pad naar de kant via de ring (op 40 m), dan stormen.
func najaag_pad(g: Dictionary) -> Array:
	var pad := stad_pad(g.oversteek)
	var laatste: Vector3 = pad[pad.size() - 1]
	var ring := ring_pad(laatste, g.kant, 40.0)
	pad.append_array(ring)
	return pad


# ---------------------------------------------------------------- hulp

static func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


static func _flat3(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
