extends Node
## Spelstatus (autoload "Game"): golf, punten, bunker en de besturing die de sticks doorgeven.

signal changed
## Real damage confirmation for player-driven shots; not emitted by aim previews.
signal combat_hit_confirmed(world_pos: Vector3, amount: float, source: String)
signal banner(big: String, small: String, time: float)
signal power_changed
signal over(reason: String)

## Laadt eerst de vervolgstukken van de OTA-keten (user://ota/keten.json); dat kan niet eerder (dit is de eerste autoload na de Updater).
func _init() -> void:
	preload("res://scripts/ota_keten.gd").laad()
	_warm_up()


## Het foutenlogboek (scripts/logboek.gd) hangt onder Game: een nieuwe autoload in project.godot zou niet met een OTA-update meekomen.
func _ready() -> void:
	add_child(load("res://scripts/logboek.gd").new())


## Zware modellen worden niet meer met preload bij het compileren geladen (de OTA-keten komt daarna), maar met load() als ze nodig zijn.
## Om haperingen bij het eerste gebruik te voorkomen vragen we de grootste alvast in een achtergrond-thread aan.
static func _warm_up() -> void:
	for pad in ["res://assets/soldaat_jungle_commando.glb", "res://assets/soldaat_vq2.glb", "res://assets/wapens.glb", "res://assets/uitrusting.glb",
			"res://assets/klimmen.glb", "res://assets/zitten.glb", "res://assets/acties.glb"]:
		if ResourceLoader.exists(pad):
			ResourceLoader.load_threaded_request(pad)


var state := "menu"  # "prep" (geen aanvalsgroep onderweg), "play" (een groep loopt of vecht), "over" (verloren of gewonnen)
var wave := 0  # aantal aanvalsgroepen dat de vijand tot nu toe heeft gestuurd (vanaf stap 5a-2 geen golven meer, de naam bleef)
var won := false  # het vijandelijke hoofdkwartier is gesloopt: de missie is geslaagd (state "over")
var points := 0
var score := 0
var kills := 0
var base_hp := Data.BASE_HP
var rocket_seen := false
var soort_gezien := {}   # v236: welke soorten schutter (schild, granaat, flank) je al hebt gezien: de melding komt één keer
var base_max := Data.BASE_HP
var hq_level := 1   # niveau van het hoofdkwartier (1..3)
var prep_t := 0.0
var mcv_deployed := false   # MCV-start: de wagen is uitgeklapt, het hoofdkwartier staat en de klok loopt
var base_pos := Vector3.ZERO   # midden van het hoofdkwartier; in het oude spel de oorsprong
var free_wall := true          # MCV-start: de eerste complete omheining rond het hoofdkwartier is gratis (Kampmuur); false zodra hij af is
var free_towers := 0          # MCV-start: gratis wachttorens die je nog mag neerzetten (4 na het uitklappen), daarna 100 per stuk
var free_depot := 0            # MCV-start: gratis voorraaddepots die je nog mag neerzetten (1 na het uitklappen); met een gratis eerste truck
var base_yaw := 0.0            # draaiing van het hoofdkwartier (rotation.y); zijn deur (terugkomplek) ligt op +Z
var routes: Array = []  # vaste aanvalsroutes van de groep die nu uitrukt, of anders van de komende groep (AanvalRoutes): de rode pijlen
var next_routes: Array = []  # routes van de komende groep: staan er al tijdens het aftellen op de golfplaat
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
var supply: Voorraad   # voorraadstapels, depot en trucks (voorraad.gd, Generals-plan stap 4)
var gates: Gates
var bridge  # de ophaalbrug (bridge.gd)
var airfield_build_view := false
var build_mode := false  # bouwscherm open: camera hoog boven de basis
var bcam := Vector3(0.0, 0.0, 1.0)  # bouwcamera: x, z en zoom
var editing := false  # stadseditor open (stad_editor.gd): bouwmodus staat dan ook aan
var ecam := Vector3(6.0, -108.0, 1.0)  # editorcamera recht van boven: x, z en zoom
var buildings: Array = []
var allies: Array = []
var troop_mode := "follow"  # follow of hold
var squad_order := "follow" # follow, defend, attack, move
var squad_target := Vector3.ZERO
var squad_target_enemy: Node3D

# Aanvalsrichting (N/O/Z/W) -> seconden dat de rand nog oplicht; gevuld door vijanden die schieten of steken.
var attack := {"N": 0.0, "O": 0.0, "Z": 0.0, "W": 0.0}

# Generaalsrang (scripts/rang.gd, Generals-plan E1): score geeft sterren, elke ster een punt voor een kracht of een upgrade
var rang := 0                    # 0 tot 5 sterren
var rang_punten := 0             # punten die je nog niet hebt uitgegeven
var krachten := {}               # id -> niveau 1 tot 3 van de krachten die je hebt gekozen (Rang.KRACHTEN)
var kracht_cd := {}              # id -> seconden afkoeling die nog resten (loopt in Game._process)
var kracht_sel := ""             # de kracht die de KRACHTEN-knop toont (leeg of niet meer beschikbaar = de eerste die je hebt)
var krachten_gebruikt := {}      # id -> hoe vaak je hem dit spel gebruikte
var satelliet_t := 0.0           # s dat de spionagesatelliet nog alle vijanden op radar en kaart toont
var power := true:   # stroom in de basis en de straatlantaarns (de generator komt later terug als gebouw: Generals-plan A4)
	set(v):
		if v != power:
			power = v
			power_changed.emit()
var hit_class := ""          # soort schade van de kogel of raket die nu raakt (Data.ARMOR_MULT); "" = neutraal
var hit_src := "speler"         # wie schiet er nu: speler, soldaat of lucht (voor bevestigde treffers en bosbrand)

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
	VoorraadTruck.catch_blast(at, radius)   # voorraadtrucks ook
	Bus.catch_blast(at, radius)          # bussen ook (zwaarder: er is veel nodig)
	Foliage.fell_near(at, radius)   # bomen vlakbij vallen om
	Bosbrand.catch_blast(at, radius)   # planten vlakbij vatten vlam: het vuur loopt door het bos
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
	if is_inside_tree():
		var team_commands := get_tree().get_first_node_in_group("team_commands")
		if team_commands != null:
			team_commands.cancel_input()
	state = "prep"
	wave = 0
	won = false
	routes = []
	next_routes = []
	rocket_seen = false
	soort_gezien = {}
	points = Data.START_POINTS
	score = 0
	kills = 0
	bonus = 0
	base_hp = Data.BASE_HP
	base_max = Data.BASE_HP
	hq_level = 1
	mcv_deployed = false
	free_wall = true
	free_towers = 0
	free_depot = 0
	base_pos = Vector3.ZERO
	base_yaw = 0.0
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
	airfield_build_view = false
	editing = false
	bcam = Vector3(0.0, 0.0, 1.0)
	buildings.clear()
	if supply != null and is_instance_valid(supply):
		supply.reset()
	allies.clear()
	troop_mode = "follow"
	squad_order = "follow"
	squad_target = Vector3.ZERO
	squad_target_enemy = null
	rang = 0
	rang_punten = 0
	krachten.clear()
	kracht_cd.clear()
	kracht_sel = ""
	krachten_gebruikt.clear()
	satelliet_t = 0.0
	hit_src = "speler"


## Een punt in het hoofdkwartier-stelsel (x = rechts, z = naar de deur) als wereldpunt. In het oude spel is dat gewoon het punt zelf.
func base_point(local: Vector3) -> Vector3:
	return base_pos + Basis(Vector3.UP, base_yaw) * local


## Waar de speler terugkomt na sneuvelen: 4 m voor de deur van het hoofdkwartier (de oude bunkerstart was (0, 0, 4)).
func base_home() -> Vector3:
	return base_point(Vector3(0.0, 0.0, 4.0))


## Afkoeltijden van de krachten en de seconden van de satelliet lopen tijdens het spel.
func _process(delta: float) -> void:
	if state == "play" or state == "prep":
		Rang.tick(delta)


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
	Rang.check()
	changed.emit()


## Alleen score, geen geld: vijanden die je neerhaalt geven sinds Generals-stap 4 geen punten meer; geld komt uit voorraad (voorraad.gd).
func add_score(n: int) -> void:
	score += roundi(n * Progress.bonus().points)
	Rang.check()
	changed.emit()


## Geld uit voorraad: een truck levert af in het depot. Telt niet mee voor je score.
func add_income(n: int) -> void:
	points += roundi(n * Progress.bonus().points)
	changed.emit()


func damage_base(dmg: float) -> void:
	if state != "play":
		return
	base_hp = maxf(0.0, base_hp - dmg)
	changed.emit()
	if base_hp <= 0.0:
		end_game("Het hoofdkwartier is gevallen in golf %d" % wave)


## Het vijandelijke hoofdkwartier is gesloopt: gewonnen. Daarna werkt alles zoals na een verloren missie (state "over").
func win(reason: String) -> void:
	if state == "over":
		return
	won = true
	end_game(reason)


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
	# The M1911 uses a physical seven-round magazine; its legacy mag upgrade
	# must never turn it into a fictional 9/11-round magazine.
	if id == "m1911":
		w.mag = 7
	else:
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


## Wat de volgende upgrade van het hoofdkwartier kost (0 = het staat al op niveau 3).
func hq_upgrade_cost() -> int:
	return 0 if hq_level >= 3 else [0, 1500, 2500][clampi(hq_level, 1, 2)]


## Koopt de volgende upgrade van het hoofdkwartier (wapenkamer en tikmenu op het hoofdkwartier gebruiken dit).
## Niveau 2: +400 sterkte, niveau 3: +500; de structuur is daarna weer vol. false = te weinig punten of al niveau 3.
func upgrade_hq() -> bool:
	var cost := hq_upgrade_cost()
	if cost <= 0 or not buy(cost):
		return false
	hq_level += 1
	base_max += 400.0 if hq_level == 2 else 500.0
	base_hp = base_max
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
	return {"m1911": {"up": {"dmg": 0, "rate": 0, "mag": 0, "rel": 0}, "ammo": Data.WEAPONS.m1911.mag + 1}}


## Een vijand valt aan vanaf pos: licht de bijbehorende kant van het scherm op (markAttack in 23-hud.js).
func mark_attack(pos: Vector3) -> void:
	var k := "O" if pos.x > 0 else "W"
	if absf(pos.x) <= absf(pos.z):
		k = "Z" if pos.z > 0 else "N"
	attack[k] = 2.5


## v234 (7A): een korte stop op een zware of dodelijke treffer, zodat een schot gewicht heeft. Duurt in echte tijd (niet in spelseconden),
## niet vaker dan eens per kwart seconde en nooit tijdens pauze, zodat snelvuur (MG) er geen stroperig spel van maakt.
var _hitstop_until := 0.0


func hitstop(seconds: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _hitstop_until or get_tree().paused or Engine.time_scale != 1.0 or seconds <= 0.0:
		return
	_hitstop_until = now + 0.25
	Engine.time_scale = 0.08
	await get_tree().create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0
