extends Node
## Spelstatus (autoload "Game"): golf, punten, bunker en de besturing die de sticks doorgeven.

signal changed
signal banner(big: String, small: String, time: float)
signal over(reason: String)

var state := "menu"  # "prep" (pauze tussen golven), "play" (golf bezig), "over"
var wave := 0
var points := 0
var score := 0
var kills := 0
var base_hp := Data.BASE_HP
var rocket_seen := false
var base_max := Data.BASE_HP
var prep_t := 0.0
var routes: Array = []  # vaste aanvalsroutes van de komende of lopende golf (AanvalRoutes)
var bonus := 0  # bonus van de laatste overleefde golf, getoond in de wapenkamer

# Wat je bezit: per wapen de upgradeniveaus en de kogels in het magazijn, en de uitrusting-upgrades.
var owned := _fresh_owned()
var cur := "m1911"
const LOADOUT_MAX := 5  # zoveel wapens neem je mee de strijd in; de rest blijft in de wapenkamer
var loadout: Array = ["m1911"]
var upg := {"maxhp": 0, "armor": 0, "speed": 0, "fort": 0, "sentry": 0, "gate": 0}
# spullen in je tas om neer te zetten (Defenses)
var inv := {"bags": 0, "trench": 0, "mine": 0, "wire": 0, "sentry": 0}
var place_sel := "bags"
var grenades := 3  # handgranaten (werpknop); te koop in de wapenkamer, maximaal GRENADE_MAX
const GRENADE_MAX := 9
var equipment_sel := "grenade"  # uitrusting op de HUD: grenade, mine of c4 (C4 is nog niet beschikbaar)
var place_armed := false  # spookbeeld en neerzetten aan/uit
# bouwen (Buildings): het bouwtegoed ga je eerst uitgeven, daarna je punten
const BUILD_CREDIT := 1000
var build_credit := BUILD_CREDIT
var builds: Buildings
var gates: Gates
var bridge  # de ophaalbrug (bridge.gd)
var build_mode := false  # bouwscherm open: camera hoog boven de basis
var bcam := Vector3(0.0, 0.0, 1.0)  # bouwcamera: x, z en zoom
var editing := false  # stadseditor open (stad_editor.gd): bouwmodus staat dan ook aan
var ecam := Vector3(6.0, -108.0, 1.0)  # editorcamera recht van boven: x, z en zoom
var buildings: Array = []
var allies: Array = []
var troop_mode := "follow"  # follow of hold

# Aanvalsrichting (N/O/Z/W) -> seconden dat de rand nog oplicht; gevuld door vijanden die schieten of steken.
var attack := {"N": 0.0, "O": 0.0, "Z": 0.0, "W": 0.0}

var player  # de speler (player.gd)
var defs  # verdediging die je neerzet (defenses.gd)
var enemies: Array = []
var barrels: Array = []  # explosieve vaten (barrel.gd)
var blast_at := Vector3.ZERO  # de laatste explosie: wie er kort daarna door sterft, wordt weggeslingerd
var blast_t := -100000
var blast_r := 0.0


func note_blast(at: Vector3, radius: float) -> void:
	Brandkraan.catch_blast(at, radius)   # een kraan vlakbij knalt open
	Auto.catch_blast(at, radius)         # auto's vlakbij raken beschadigd, of ontploffen
	Bus.catch_blast(at, radius)          # bussen ook (zwaarder: er is veel nodig)
	blast_at = at
	blast_r = radius
	blast_t = Time.get_ticks_msec()
	# wie er net buiten de straal bij staat schrikt en zoekt dekking
	for e in enemies:
		if is_instance_valid(e) and not e.dead:
			var d: float = e.global_position.distance_to(at)
			if d > radius + 0.5 and d < radius * 2.4 + 3.0:
				e.flinch(at)


## Was er net (binnen een kwart seconde) een explosie waar iemand op deze plek binnen de straal viel? Geeft {at, r} of een leeg woordenboek.
func blast_near(pos: Vector3) -> Dictionary:
	if Time.get_ticks_msec() - blast_t > 250 or pos.distance_to(blast_at) > blast_r + 1.0:
		return {}
	return {"at": blast_at, "r": blast_r}
var _slot_n := 0


## Volgnummer voor elke nieuwe vijand, zodat hun gedrag (poort, afstand, flankeren) netjes verdeeld wordt.
func next_slot() -> int:
	_slot_n += 1
	return _slot_n


## Een kreet, ontploffing of dode maat: vijanden binnen de straal letten even extra op de speler.
func alert(pos: Vector3, radius: float, secs: float) -> void:
	for e in enemies:
		if is_instance_valid(e) and not e.dead and e.global_position.distance_to(pos) < radius:
			e.alert_t = maxf(e.alert_t, secs)

# Besturing, ingevuld door touch_sticks.gd (of toetsenbord en muis):
# move = looprichting op de grond (x, z), aim = kijkhoek of NAN, fire = schieten
var move := Vector2.ZERO
var aim := NAN
var fire := false


func reset() -> void:
	state = "prep"
	wave = 0
	rocket_seen = false
	points = Data.START_POINTS
	score = 0
	kills = 0
	bonus = 0
	base_hp = Data.BASE_HP
	base_max = Data.BASE_HP
	enemies.clear()
	barrels.clear()
	if is_inside_tree():
		for c in get_tree().get_nodes_in_group("craters"):
			c.queue_free()  # een nieuw spel begint met een heel terrein
	_slot_n = 0
	owned = _fresh_owned()
	loadout = ["m1911"]
	cur = "m1911"
	upg = {"maxhp": 0, "armor": 0, "speed": 0, "fort": 0, "sentry": 0, "gate": 0}
	inv = {"bags": 0, "trench": 0, "mine": 0, "wire": 0, "sentry": 0}
	place_sel = "bags"
	grenades = 3
	equipment_sel = "grenade"
	place_armed = false
	build_credit = BUILD_CREDIT
	build_mode = false
	editing = false
	bcam = Vector3(0.0, 0.0, 1.0)
	buildings.clear()
	allies.clear()
	troop_mode = "follow"


func can_afford_build(c: int) -> bool:
	return build_credit + points >= c


## Betaalt een gebouw: eerst van het bouwtegoed, de rest van je punten.
func pay_build(c: int) -> bool:
	if not can_afford_build(c):
		return false
	var k := mini(build_credit, c)
	build_credit -= k
	points -= c - k
	Sfx.play("buy")
	changed.emit()
	return true


func pay_points(c: int) -> bool:
	if points < c:
		return false
	points -= c
	Sfx.play("buy")
	changed.emit()
	return true


func add_points(n: int) -> void:
	n = roundi(n * Progress.bonus().points)
	points += n
	score += n
	changed.emit()


func damage_base(dmg: float) -> void:
	if state != "play":
		return
	base_hp = maxf(0.0, base_hp - dmg)
	changed.emit()
	if base_hp <= 0.0:
		end_game("De bunker is gevallen in golf %d" % wave)


func end_game(reason: String) -> void:
	if state == "over":
		return
	state = "over"
	Progress.stats.games += 1
	Progress.save()
	over.emit(reason)
	changed.emit()


## Waarden van een wapen met zijn upgrades erop (wstat in de web-versie).
func wstat(id: String) -> Dictionary:
	var w: Dictionary = Data.WEAPONS[id].duplicate()
	var u: Dictionary = owned[id].up if owned.has(id) else {"dmg": 0, "rate": 0, "mag": 0, "rel": 0}
	w.dmg *= 1.0 + 0.3 * u.dmg
	w.rate *= pow(0.86, u.rate)
	w.mag = roundi(w.mag * (1.0 + 0.3 * u.mag))
	w.reload *= pow(0.82, u.rel)
	return w


func max_hp() -> float:
	return Data.PLAYER_HP + 25.0 * upg.maxhp + Progress.bonus().hp


func buy(cost: int) -> bool:
	if points < cost:
		return false
	points -= cost
	Sfx.play("buy")
	changed.emit()
	return true


func loadout_full() -> bool:
	return loadout.size() >= LOADOUT_MAX


func carries(id: String) -> bool:
	return loadout.has(id)


## Een gekocht wapen in de loadout zetten (als er plek is). Gekochte wapens blijven altijd van jou.
func take_weapon(id: String) -> bool:
	if not owned.has(id) or loadout.has(id) or loadout_full():
		return false
	loadout.append(id)
	changed.emit()
	return true


## Een wapen uit de loadout terug in de wapenkamer zetten; het blijft van jou, met al zijn upgrades.
func leave_weapon(id: String) -> void:
	if not loadout.has(id) or loadout.size() < 2:
		return
	loadout.erase(id)
	if cur == id:
		cur = Data.WEAPON_ORDER.filter(func(w): return loadout.has(w))[0]
	changed.emit()


static func _fresh_owned() -> Dictionary:
	return {"m1911": {"up": {"dmg": 0, "rate": 0, "mag": 0, "rel": 0}, "ammo": Data.WEAPONS.m1911.mag}}


## Een vijand valt aan vanaf pos: licht de bijbehorende kant van het scherm op (markAttack in 23-hud.js).
func mark_attack(pos: Vector3) -> void:
	var k := "O" if pos.x > 0 else "W"
	if absf(pos.x) <= absf(pos.z):
		k = "Z" if pos.z > 0 else "N"
	attack[k] = 2.5
