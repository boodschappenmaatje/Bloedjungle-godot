class_name Garnizoen
extends Node3D
## Garnizoen in de stad (Generals-plan F2, keuzes van Dennis 12 november 2026: 1A 2A 3A 4A 5A 6A 7A 8A 9B).
## Elk stadsgebouw (Woonhuis) krijgt één garnizoen-knoop. Daarin zitten soldaten van de vijand of van jou; ze zijn geen lopende
## soldaten zolang ze binnen zitten (geen animatie, botsing of route), dus het kost bijna niets.
## - Schietplekken zijn de echte ramen uit het model: elk muurstuk met een glasvlak (Glas, GlasLood, Vuil glas) is een raam,
##   plus de voordeuren en bij de kerk één plek boven in de toren (de sluipschutter). Een schot komt uit het raam dat naar het doel kijkt,
##   met een mondingsflits en een kogelspoor (3A). Boven het dak staat per bewoner een stip in partijkleur; radar en kaart tekenen een rand (hud_extra.gd).
## - Bewoners krijgen 70% minder kogelschade en schieten 20% verder (6A). Granaten, raketten, tankgranaten, napalm en artillerie doen
##   volle schade; een ontploffing in het gebouw of vlak bij een raam het meest (5A). Wie binnen zit als het gebouw (of zijn verdieping)
##   instort, sneuvelt (9B).
## - Loop jij een vijandelijk gebouw binnen, dan worden de bewoners echte vijanden op de begane grond (5A).
## - Jouw soldaten gaan erin via de bevelstand: tik op een gebouw met VERPLAATS of VERDEDIG (4A); ERUIT haalt ze eruit.
## - Bij de start bezet de vijand de kerk, het hotel, het magazijn en het benzinestation (7A). Een vrijgemaakt gebouw geeft
##   de melding GEBOUW VRIJ en 150 voorraad (8A), en jij kunt het daarna zelf bezetten.
## Ver van jou (meer dan 62 m) vliegen er geen echte kogels: de schade wordt dan uitgerekend, zoals het beleg op afstand.

const PLAATSEN := {"woonhuis": 3, "benzine": 2, "magazijn": 4, "winkel": 5, "hotel": 6, "kerk": 6}   # 2A
const START_VIJAND := ["kerk", "hotel", "magazijn", "benzine"]   # 7A: het eerste gebouw van elke soort
const GLAS := ["Glas", "GlasLood", "Vuil glas"]
const KOGEL_DOOR := 0.3      # 6A: een bewoner krijgt 30% van de kogelschade (70% minder)
const KOGEL_KANS := 0.5      # een kogel op een muurstuk met een raam raakt zo vaak een bewoner
const BEREIK := 1.2          # 6A: schutters in een gebouw schieten 20% verder
const VER := 62.0            # zo ver van jou: geen echte kogels meer, de schade wordt uitgerekend
const VER_RAAK := 0.55       # kans dat een uitgerekend schot raak is
const BUIT := 150            # 8A
const INSTAP := 1.5          # m van de deur: hier gaat een soldaat naar binnen
const BINNEN_R := 2.4        # m van de deur (of binnen): de vijandelijke bewoners worden echte vijanden (5A)
const RAAM_VOL := 1.8        # m: een ontploffing zo dicht bij een raam (of in het gebouw) doet volle schade aan iedereen binnen
const BUITEN_K := 0.5        # verder weg, maar binnen de straal: dit deel van de schade
const BRAND_DPS := 22.0      # napalm per seconde per bewoner
const ZOEK_T := 0.25         # zo vaak kiest het garnizoen een doel
const VIJAND := {"hp": 65.0, "dmg": 7.0, "rate": 1.6, "range": 12.0, "pts": 60}   # zoals Data.ETYPES.assault
const TOREN := {"hp": 65.0, "dmg": 22.0, "rate": 2.6, "range": 34.0, "pts": 90}   # sluipschutter boven in de kerktoren
const C_VIJAND := Color(1.0, 0.3, 0.2)
const C_EIGEN := Color(0.45, 0.88, 0.36)

static var all: Array = []
static var _plek_cache := {}   # soort -> [plekken] (lokale maten, alle gebouwen van een soort zijn gelijk)
static var _mat := {}

var huis: Woonhuis
var partij := ""             # "", "vijand" of "eigen"
var bewoners: Array = []     # {hp, max, dmg, rate, range, pts, toren, t, ally}
var plekken: Array = []      # {pos, out (lokaal, plat), laag, seg, toren, deur}
var deur_lokaal := Vector3.ZERO
var gedood := 0              # bewoners van de vijand die hier gesneuveld zijn (test en melding)
var _mik: Array = []         # per plek een knoop waar soldaten en vijanden op mikken
var _doel: Node3D
var _doel_t := 0.0
var _stippen: Node3D
var _dots: Array = []
var _binnen_vijanden: Array = []   # na 5A: de echte vijanden die uit dit gebouw kwamen
var _wacht_vrij := false


static func voor(h: Woonhuis) -> Garnizoen:
	var g := Garnizoen.new()
	g.name = "Garnizoen"
	g.huis = h
	h.add_child(g)
	return g


func _ready() -> void:
	all.append(self)
	add_to_group("garnizoen")
	plekken = _plekken()
	for p in plekken:
		var m := Node3D.new()
		m.name = "Raam"
		m.position = (p.pos as Vector3) + (p.out as Vector3) * 0.35
		add_child(m)
		_mik.append(m)
	_stippen = Node3D.new()
	_stippen.name = "Stippen"
	_stippen.position = Vector3(0.0, _dak_y(), 0.0)
	add_child(_stippen)
	_stippen.visible = false


func _exit_tree() -> void:
	all.erase(self)


func plaatsen() -> int:
	return int(PLAATSEN.get(huis.kind, 3))


func vol() -> bool:
	return bewoners.size() >= plaatsen()


func ruine() -> bool:
	return huis == null or not is_instance_valid(huis) or huis._ruin


## Een punt vlak voor de voordeur, buiten (y = 0). Hier gaan soldaten naar binnen.
func deur() -> Vector3:
	var p := huis.to_global(deur_lokaal)
	p.y = 0.0
	return p


# ---------------------------------------------------------------- de ramen uit het model

func _plekken() -> Array:
	if not _plek_cache.has(huis.kind):
		_plek_cache[huis.kind] = _zoek_plekken()
	var out: Array = []
	for p in _plek_cache[huis.kind]:
		var q: Dictionary = p.duplicate()
		q.seg = null
		for s in huis.segs:
			if s.name == p.seg_naam:
				q.seg = s
		out.append(q)
	_zoek_deur()
	return out


func _zoek_plekken() -> Array:
	var out: Array = []
	var inv := huis.global_transform.affine_inverse()
	for s in huis.segs:
		var mi: MeshInstance3D = s.heel
		if mi.mesh == null:
			continue
		var outward: Vector3 = inv.basis * huis.seg_outward(s)
		outward.y = 0.0
		if outward.length() < 0.1:
			continue
		outward = outward.normalized()
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i)
			if mat == null or not GLAS.has(String(mat.resource_name)):
				continue
			var arr := mi.mesh.surface_get_arrays(i)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			if verts.is_empty():
				continue
			var lo := verts[0]
			var hi := verts[0]
			for v in verts:
				lo = lo.min(v)
				hi = hi.max(v)
			var c: Vector3 = inv * (mi.global_transform * ((lo + hi) * 0.5))
			out.append({"pos": c, "out": outward, "laag": int(s.floor), "seg_naam": String(s.name), "toren": false, "deur": false})
	# de voordeuren (vooral het magazijn heeft weinig ramen)
	for nm in huis.spec.doors:
		if String(nm).begins_with("DeurBinnen") or String(nm).begins_with("DeurAchter"):
			continue
		var d: Node3D = huis.model.find_child(nm, true, false)
		if d == null:
			continue
		var lp: Vector3 = inv * d.global_position
		var o := Vector3(lp.x, 0.0, lp.z)
		if o.length() < 0.1:
			continue
		out.append({"pos": Vector3(lp.x, float(huis.levels[0]) + 1.5, lp.z), "out": o.normalized(), "laag": 0, "seg_naam": "", "toren": false, "deur": true})
	if huis.kind == "kerk":
		# boven in de toren, tussen de kantelen: kijkt alle kanten op
		out.append({"pos": Vector3(0.0, float(huis.levels[huis.levels.size() - 1]) + 1.2, 7.0), "out": Vector3.ZERO, "laag": huis.levels.size() - 1,
			"seg_naam": "", "toren": true, "deur": false})
	return out


func _zoek_deur() -> void:
	var inv := huis.global_transform.affine_inverse()
	for nm in ["DeurVoor", "DeurVoorL", "DeurVoorR"]:
		var d: Node3D = huis.model.find_child(nm, true, false)
		if d != null:
			var lp: Vector3 = inv * d.global_position
			var o := Vector3(lp.x, 0.0, lp.z).normalized()
			deur_lokaal = Vector3(lp.x, 0.0, lp.z) + o * 1.2
			if nm == "DeurVoorL":
				var r: Node3D = huis.model.find_child("DeurVoorR", true, false)
				if r != null:
					var rp: Vector3 = inv * r.global_position
					deur_lokaal = (Vector3(lp.x, 0.0, lp.z) + Vector3(rp.x, 0.0, rp.z)) * 0.5 + o * 1.4
			return
	deur_lokaal = Vector3(0.0, 0.0, float(huis.spec.hz) + 1.2)


func _dak_y() -> float:
	var top := float(huis.levels[huis.levels.size() - 1])
	if huis.kind == "kerk":
		return top + 3.2
	return maxf(float(huis.spec.get("roof_y", top + 3.0)), top + 2.6) + 1.4


## Een plek is bruikbaar zolang zijn verdieping er nog staat (bij de kerk: de toren of het schip).
func _plek_ok(p: Dictionary) -> bool:
	if ruine():
		return false
	if int(p.laag) >= huis._fall:
		return false
	if p.toren and huis._ruined.has("Toren"):
		return false
	if not p.toren and huis.kind == "kerk" and not p.deur and huis._ruined.has("Schip"):
		return false
	return true


func _wereld(p: Dictionary) -> Vector3:
	return huis.to_global((p.pos as Vector3) + (p.out as Vector3) * 0.35)


# ---------------------------------------------------------------- start en einde van een spel

## Een nieuw spel: iedereen eruit, en de vijand bezet zijn vier sleutelgebouwen (7A).
static func start_game() -> void:
	var gehad := {}
	for g: Garnizoen in all:
		if not is_instance_valid(g):
			continue
		g._leeg()
		if g.ruine():
			continue
		var k: String = g.huis.kind
		if START_VIJAND.has(k) and not gehad.has(k):
			gehad[k] = true
			g.vul_vijand(g.plaatsen())


func _leeg() -> void:
	for b in bewoners:
		var a = b.get("ally")
		if a != null and is_instance_valid(a):
			a.set("binnen", null)
	bewoners.clear()
	_binnen_vijanden.clear()
	_wacht_vrij = false
	partij = ""
	gedood = 0
	_doel = null
	_stippen_bij()


func vul_vijand(n: int) -> void:
	partij = "vijand"
	for i in n:
		var toren := huis.kind == "kerk" and i == 0
		var d: Dictionary = (TOREN if toren else VIJAND).duplicate()
		bewoners.append({"hp": d.hp, "max": d.hp, "dmg": d.dmg, "rate": d.rate, "range": d.range * BEREIK, "pts": d.pts,
			"toren": toren, "t": randf_range(0.4, 1.6), "ally": null})
	_stippen_bij()


# ---------------------------------------------------------------- jouw soldaten erin en eruit

## Een soldaat staat bij de deur: naar binnen als er plek is en het gebouw niet van de vijand is. Geeft true als hij binnen is.
func binnen_gaan(a: Node) -> bool:
	if ruine() or partij == "vijand" or vol() or not is_instance_valid(a):
		return false
	var eerste := partij == ""
	partij = "eigen"
	var ty: Dictionary = Data.SOLDIER_TYPES.get(String(a.get("kind")), Data.SOLDIER_TYPES.geweer)
	bewoners.append({"hp": 0.0, "max": 0.0, "dmg": float(a.get("dmg")), "rate": maxf(float(ty.rate), 0.3), "range": float(ty.range) * BEREIK,
		"pts": 0, "toren": false, "t": 0.6, "ally": a, "wep": String(ty.wep), "wclass": String(ty.wclass)})
	a.set("binnen", self)
	(a as Node3D).visible = false
	a.process_mode = Node.PROCESS_MODE_DISABLED
	_stippen_bij()
	if eerste:
		Game.banner.emit("GEBOUW BEZET", "%s · %d van %d plaatsen" % [_naam(), bewoners.size(), plaatsen()], 1.6)
	Game.changed.emit()
	return true


## Iedereen eruit (knop ERUIT in de bevelstand): ze komen naar buiten bij de deur en blijven daar staan. Geeft de soldaten terug.
func eruit() -> Array:
	var out: Array = []
	for b in bewoners.duplicate():
		var a = b.get("ally")
		if a != null and is_instance_valid(a):
			uit(a)
			out.append(a)
	return out


## Eén soldaat naar buiten (ERUIT, of hij kreeg een ander bevel uit het teamwiel).
func uit(a: Node) -> void:
	for b in bewoners:
		if b.get("ally") == a:
			bewoners.erase(b)
			break
	if not is_instance_valid(a):
		return
	a.set("binnen", null)
	a.process_mode = Node.PROCESS_MODE_INHERIT
	(a as Node3D).visible = true
	var i := posmod(int(a.get("idx")), 6)
	var off := Vector3(cos(i * 1.05), 0.0, sin(i * 1.05)) * 1.1
	(a as Node3D).global_position = deur() + off
	a.set("command", "hold")
	a.set("command_hold_position", (a as Node3D).global_position)
	if bewoners.is_empty() and partij == "eigen":
		partij = ""
	_stippen_bij()
	Game.changed.emit()


func eigen_soldaten() -> Array:
	var out: Array = []
	for b in bewoners:
		if b.get("ally") != null and is_instance_valid(b.ally):
			out.append(b.ally)
	return out


# ---------------------------------------------------------------- elk beeld

func _physics_process(delta: float) -> void:
	if partij == "" or bewoners.is_empty():
		if _wacht_vrij:
			_check_binnen_vijanden()
		return
	if ruine():
		instort(0)
		return
	if Game.state != "play" and Game.state != "prep":
		return
	if partij == "vijand":
		_check_binnenlopen()
		if partij != "vijand":
			return
	_doel_t -= delta
	if _doel_t <= 0.0:
		_doel_t = ZOEK_T
		_doel = _zoek_doel()
	if _doel == null or not is_instance_valid(_doel) or _doel.get("dead") == true:
		_doel = null
		return
	var dichtbij := _speler_dichtbij()
	for b in bewoners.duplicate():
		b.t -= delta
		if b.t > 0.0 or float(b.dmg) <= 0.0:
			continue
		var p: Variant = _plek_voor(b, _doel)
		if p == null:
			continue
		b.t = float(b.rate) * randf_range(0.9, 1.25)
		_schiet(b, p, _doel, dichtbij)


func _speler_dichtbij() -> bool:
	var pl = Game.player
	if pl == null or not is_instance_valid(pl):
		return false
	var d: Vector3 = pl.global_position - global_position
	return Vector2(d.x, d.z).length() < VER


func _bereik_max() -> float:
	var r := 0.0
	for b in bewoners:
		r = maxf(r, float(b.range))
	return r


## Wie het dichtstbij is binnen bereik, met vrij zicht vanuit een raam: de vijand mikt op jou, je soldaten en je voertuigen;
## jouw garnizoen op vijanden.
func _zoek_doel() -> Node3D:
	var reach := _bereik_max()
	var c := global_position
	var lijst: Array = []
	if partij == "vijand":
		var pl = Game.player
		if pl != null and is_instance_valid(pl) and not pl.dead and not bool(pl.get("driving")):
			lijst.append(pl)
		for a in Game.allies:
			if is_instance_valid(a) and a.get("binnen") == null and not a.beleg_bezig():
				lijst.append(a)
		lijst.append_array(VoertuigSchade.doelen())
	else:
		for e in Game.enemies:
			if is_instance_valid(e) and e.get("dead") != true:
				lijst.append(e)
	var kand: Array = []
	for n in lijst:
		var d: Vector3 = (n as Node3D).global_position - c
		var l := Vector2(d.x, d.z).length()
		if l < reach + float(huis.spec.hx):
			kand.append([l, n])
	kand.sort_custom(func(a, b): return a[0] < b[0])
	for i in mini(kand.size(), 4):
		var n: Node3D = kand[i][1]
		for b in bewoners:
			if _plek_voor(b, n) != null:
				return n
	return null


## Het raam waaruit deze bewoner op het doel kan schieten: kijkt zijn kant op, binnen bereik en met vrij zicht. null = geen.
func _plek_voor(b: Dictionary, doel: Node3D) -> Variant:
	var aim := doel.global_position + Vector3.UP * 1.2
	var best: Variant = null
	var bs := -2.0
	for i in plekken.size():
		var p: Dictionary = plekken[i]
		if bool(p.toren) != bool(b.toren) or not _plek_ok(p):
			continue
		var w := _wereld(p)
		var dir := aim - w
		var flat := Vector2(dir.x, dir.z)
		if flat.length() > float(b.range):
			continue
		var gout: Vector3 = huis.global_basis * (p.out as Vector3)
		var dot := 1.0 if p.toren else Vector2(gout.x, gout.z).dot(flat.normalized())
		if dot < 0.25:
			continue
		if dot > bs:
			bs = dot
			best = i
	if best == null:
		return null
	var wp := _wereld(plekken[best])
	var q := PhysicsRayQueryParameters3D.create(wp, aim, Bullet.MASK_WALL | Bullet.MASK_BUNKER | Bullet.MASK_FORTIFICATION)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and (hit.collider as Node) != doel:
		return null
	return best


func _schiet(b: Dictionary, pi: int, doel: Node3D, echt: bool) -> void:
	var from := _wereld(plekken[pi])
	var aim := doel.global_position + Vector3.UP * 1.2
	var d := aim - from
	var flat := maxf(Vector2(d.x, d.z).length(), 0.5)
	var angle := atan2(d.x, d.z)
	var vijand := partij == "vijand"
	if not echt:
		# ver van jou: uitgerekend (zoals het beleg), geen kogel en geen flits
		if randf() < VER_RAAK:
			_raak_ver(doel, float(b.dmg), vijand)
		return
	var spread := 0.012 if b.toren else (0.08 * float(Progress.bonus().enemySpread) if vijand else 0.05)   # zo nauwkeurig als een vijand op straat
	var wep: String = "garand" if vijand else String(b.get("wep", "thompson"))
	var rise := d.y / flat
	if not vijand and wep == "bazooka":
		var rk := Bullet.fire(huis.get_parent(), from, angle, 26.0, float(b.dmg), 1.4, true, true, 0, 2.8, 0.0, rise, "bazooka")
		rk.src = "soldaat"
		rk.wclass = String(b.get("wclass", "raket"))
		Sfx.play("rocket", 0.5, from)
		return
	var speed := 120.0 if b.toren else 75.0
	var life := (float(b.range) + 4.0) / speed
	var bl := Bullet.fire(huis.get_parent(), from, angle + randf_range(-spread, spread), speed, float(b.dmg), life, not vijand, true, 0, 0.0, 0.0, rise, wep)
	if vijand:
		bl.src = "m2"   # zo raakt hij ook je soldaten (die hebben geen botslaag), zoals de M2-torens
	else:
		bl.src = "soldaat"
		bl.wclass = String(b.get("wclass", "kogel"))
	Fx.muzzle(huis.get_parent(), from, wep, angle)
	Sfx.play("enemy" if vijand else "ak", 0.8 if vijand else 0.45, from)
	if vijand:
		Game.mark_attack(from)


func _raak_ver(doel: Node3D, dmg: float, vijand: bool) -> void:
	if vijand:
		if doel is Ally:
			var a: Ally = doel
			a.hp -= dmg
			if a.hp <= 0.0:
				Game.allies.erase(a)
				a.queue_free()
				Game.changed.emit()
		elif doel.has_method("hit"):
			doel.hit(dmg, Vector3.FORWARD, false)
	else:
		Game.hit_src = "soldaat"
		doel.hit(dmg, (doel.global_position - global_position).normalized(), true)
		Game.hit_src = "speler"


# ---------------------------------------------------------------- schade aan de bewoners

## Een kogel op een muurstuk van dit gebouw (HouseBody). Alleen een muurstuk met een raam laat iets door, en dan 30% (6A).
func kogel(seg: Dictionary, dmg: float, van_speler: bool) -> void:
	if bewoners.is_empty() or (van_speler and partij != "vijand") or (not van_speler and partij != "eigen"):
		return
	var raam := false
	for p in plekken:
		if p.seg == seg:
			raam = true
			break
	if not raam or randf() > KOGEL_KANS:
		return
	var laag := int(seg.get("floor", 0))
	var kies: Array = bewoners.filter(func(b): return not b.toren)
	if kies.is_empty():
		return
	var b: Dictionary = kies[randi() % kies.size()]
	_raak(b, dmg * KOGEL_DOOR)
	if laag >= 0:
		Fx.dust(huis.get_parent(), _center_seg(seg))


func _center_seg(seg: Dictionary) -> Vector3:
	return huis.seg_center(seg)


## Een ontploffing: in het gebouw of vlak bij een raam volle schade aan iedereen binnen, verder weg (binnen de straal) de helft
## en minder met de afstand. `tegen`: "vijand" (jouw wapens), "eigen" (wapens van de vijand) of "" (allebei).
func ontploffing(at: Vector3, r: float, dmg: float, tegen := "") -> void:
	if bewoners.is_empty() or (tegen != "" and tegen != partij):
		return
	var lp := huis.to_local(at)
	var binnen := huis._in_foot(lp, 0.2) and lp.y < _dak_y() + 1.0
	var raam_d := INF
	for p in plekken:
		if _plek_ok(p):
			raam_d = minf(raam_d, (p.pos as Vector3).distance_to(lp))
	var k := 0.0
	if binnen or raam_d < RAAM_VOL:
		k = 1.0
	else:
		var hx := float(huis.spec.hx)
		var hz := float(huis.spec.hz)
		var d := Vector2(maxf(absf(lp.x) - hx, 0.0), maxf(absf(lp.z) - hz, 0.0)).length()
		if d < r:
			k = BUITEN_K * (1.0 - d / r)
	if k <= 0.0:
		return
	for b in bewoners.duplicate():
		if b.toren and not binnen and raam_d >= RAAM_VOL:
			continue   # de toren is hoog: alleen een voltreffer haalt de sluipschutter neer
		_raak(b, dmg * k)


## Napalm (keuze 5A): wie in een gebouw zit dat in de brandende strook ligt, verbrandt langzaam. `in_strook` is een Callable(Vector3) -> bool.
static func brand(in_strook: Callable, tick: float) -> void:
	for g: Garnizoen in all:
		if not is_instance_valid(g) or g.partij != "vijand" or g.bewoners.is_empty():
			continue
		var raak: bool = in_strook.call(g.global_position)
		if not raak:
			for p in g.plekken:
				if not p.toren and in_strook.call(g._wereld(p)):
					raak = true
					break
		if raak:
			for b in g.bewoners.duplicate():
				if not b.toren:
					g._raak(b, BRAND_DPS * tick)


## Alle ontploffingen: één aanroep per explosie, met de kant die schade krijgt.
static func blast(at: Vector3, r: float, dmg: float, tegen := "") -> void:
	for g: Garnizoen in all:
		if not is_instance_valid(g) or g.bewoners.is_empty():
			continue
		if g.global_position.distance_to(at) < r + 14.0:
			g.ontploffing(at, r, dmg, tegen)


func _raak(b: Dictionary, dmg: float) -> void:
	var a = b.get("ally")
	if a != null:
		if not is_instance_valid(a):
			bewoners.erase(b)
			_na_dood()
			return
		a.hp -= dmg
		if a.hp <= 0.0:
			bewoners.erase(b)
			Game.allies.erase(a)
			a.queue_free()
			Game.changed.emit()
			_na_dood()
		return
	b.hp -= dmg
	if b.hp <= 0.0:
		bewoners.erase(b)
		_dood_vijand(b)
		_na_dood()


func _dood_vijand(b: Dictionary) -> void:
	gedood += 1
	Game.kills += 1
	Progress.stats.kills += 1
	Game.add_score(int(b.get("pts", 60)))
	if _speler_dichtbij():
		var p: Variant = null
		for pp in plekken:
			if bool(pp.toren) == bool(b.toren) and _plek_ok(pp):
				p = pp
				break
		if p != null:
			Fx.blood(huis.get_parent(), _wereld(p), Vector3.UP, 10)
			Sfx.play("splat", 0.8, _wereld(p))


func _na_dood() -> void:
	_stippen_bij()
	if not bewoners.is_empty():
		return
	if partij == "vijand":
		_vrij()
	partij = ""


func _vrij() -> void:
	partij = ""
	_wacht_vrij = false
	Game.add_income(BUIT)
	Game.banner.emit("GEBOUW VRIJ", "%s · +%d voorraad · je kunt het nu zelf bezetten" % [_naam(), BUIT], 2.2)
	if Game.builds != null and is_instance_valid(Game.builds) and Game.builds.get("radio") != null:
		Game.builds.radio.say("gebouw_vrij")
	_stippen_bij()


func _naam() -> String:
	return {"woonhuis": "WOONHUIS", "benzine": "BENZINESTATION", "magazijn": "MAGAZIJN", "winkel": "WINKEL", "hotel": "HOTEL", "kerk": "KERK"}.get(huis.kind, "GEBOUW")


## Het gebouw (of verdieping `vanaf` en hoger, of een deel) stort in: wie daar binnen zit sneuvelt (9B).
## vanaf = 0: iedereen. `deel` = "Toren" of "Schip" bij de kerk.
func instort(vanaf: int, deel := "") -> void:
	if bewoners.is_empty():
		return
	for b in bewoners.duplicate():
		var weg := vanaf <= 0
		if not weg and deel == "":
			weg = vanaf <= 1 or randf() < 0.5   # een verdieping zakt in: de bewoners zitten verspreid
		if deel == "Toren":
			weg = b.toren
		elif deel == "Schip":
			weg = not b.toren
		if weg:
			_raak(b, 99999.0)


# ---------------------------------------------------------------- 5A: jij loopt naar binnen

func _check_binnenlopen() -> void:
	var pl = Game.player
	if pl == null or not is_instance_valid(pl) or pl.dead or bool(pl.get("driving")):
		return
	var binnen: bool = huis._inside >= 0
	if not binnen:
		var d: Vector3 = pl.global_position - deur()
		binnen = Vector2(d.x, d.z).length() < BINNEN_R
	if binnen:
		naar_binnen()


## Alle bewoners van de vijand worden echte vijanden op de begane grond van dit gebouw (zij komen naar beneden).
func naar_binnen() -> Array:
	var scene: PackedScene = load("res://scenes/enemy.tscn")
	var world: Node = huis.get_parent()
	var pl = Game.player
	if pl != null and is_instance_valid(pl) and pl.get_parent() != null:
		world = pl.get_parent()
	var out: Array = []
	var plek_i := 0
	var grond: Array = plekken.filter(func(p): return int(p.laag) == 0 and not p.toren and _plek_ok(p))
	for b in bewoners.duplicate():
		var e = scene.instantiate()
		e.setup("assault", 1)
		e.max_hp = float(b.max)
		e.hp = float(b.hp)
		var at := Vector3.ZERO
		if not grond.is_empty():
			var p: Dictionary = grond[plek_i % grond.size()]
			plek_i += 1
			at = (p.pos as Vector3) - (p.out as Vector3) * 1.1
		else:
			at = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
		at.y = 0.0
		world.add_child(e)
		e.global_position = huis.to_global(at)
		e.alert_t = 8.0
		out.append(e)
	bewoners.clear()
	partij = ""
	_binnen_vijanden = out
	_wacht_vrij = not out.is_empty()
	_stippen_bij()
	Game.banner.emit("VIJAND BINNEN!", "Vecht ze eruit", 1.4)
	return out


func _check_binnen_vijanden() -> void:
	for e in _binnen_vijanden:
		if is_instance_valid(e) and e.get("dead") != true:
			return
	_binnen_vijanden.clear()
	_vrij()


# ---------------------------------------------------------------- waar mik je op

## Voor een vijand op straat: het raam van een gebouw met jouw soldaten dat zijn kant op kijkt, binnen `reach`. null = geen.
static func eigen_doel(from: Vector3, reach: float) -> Variant:
	return _doel_van("eigen", from, reach)


## Voor een eigen soldaat op straat: het raam van een vijandelijk gebouw (een knoop om op te mikken). null = geen.
static func vijand_doel(from: Vector3, reach: float) -> Node3D:
	return _doel_van("vijand", from, reach)


static func _doel_van(kant: String, from: Vector3, reach: float) -> Node3D:
	var best: Node3D = null
	var bd := reach
	for g: Garnizoen in all:
		if not is_instance_valid(g) or g.partij != kant or g.bewoners.is_empty():
			continue
		var gd: Vector3 = g.global_position - from
		if Vector2(gd.x, gd.z).length() > reach + 12.0:
			continue
		for i in g.plekken.size():
			var p: Dictionary = g.plekken[i]
			if p.toren or not g._plek_ok(p):
				continue
			var w: Vector3 = (g._mik[i] as Node3D).global_position
			var d := w - from
			var l := Vector2(d.x, d.z).length()
			var gout: Vector3 = g.huis.global_basis * (p.out as Vector3)
			if l < bd and Vector2(gout.x, gout.z).dot(Vector2(-d.x, -d.z).normalized()) > 0.3:
				bd = l
				best = g._mik[i]
	return best


## Het garnizoen van het gebouw op dit punt (op de grond, binnen het grondvlak), of null.
static func at(world: Vector3, marge := 0.6) -> Garnizoen:
	for g: Garnizoen in all:
		if not is_instance_valid(g) or g.ruine():
			continue
		if g.huis._in_foot(g.huis.to_local(Vector3(world.x, 0.0, world.z)), marge):
			return g
	return null


# ---------------------------------------------------------------- stippen boven het dak (3A)

func _stippen_bij() -> void:
	if _stippen == null:
		return
	var n := bewoners.size() if partij != "" else 0
	_stippen.visible = n > 0
	while _dots.size() < n:
		var m := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.62, 0.62)
		m.mesh = q
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_stippen.add_child(m)
		_dots.append(m)
	var col := C_VIJAND if partij == "vijand" else C_EIGEN
	var w := 0.85
	for i in _dots.size():
		var m: MeshInstance3D = _dots[i]
		m.visible = i < n
		m.material_override = _stip_mat(col)
		m.position = Vector3((i - (n - 1) * 0.5) * w, 0.0, 0.0)


static func _stip_mat(col: Color) -> StandardMaterial3D:
	var key := col.to_html()
	if not _mat.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = _stip_tex()
		m.albedo_color = col
		m.no_depth_test = true
		m.render_priority = 2
		_mat[key] = m
	return _mat[key]


static var _tex: Texture2D


## Een ronde stip met een donkere rand (één keer gemaakt, 32 x 32).
static func _stip_tex() -> Texture2D:
	if _tex != null:
		return _tex
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length()
			var a := clampf(15.5 - d, 0.0, 1.0)
			var c := Color(1, 1, 1, a) if d < 11.5 else Color(0.05, 0.05, 0.04, a * 0.9)
			img.set_pixel(x, y, c)
	_tex = ImageTexture.create_from_image(img)
	return _tex
