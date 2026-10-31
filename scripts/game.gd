extends Node
## Spelstatus (autoload "Game"): golf, punten, bunker en de besturing die de sticks doorgeven.

signal changed
signal banner(big: String, small: String, time: float)
signal power_changed
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

# Killstreak (luchtsteun): kills op rij binnen deze golf, beloningen die klaarstaan (opsparen kan), en wie de laatste treffer deed
var streak := 0
var streak_sel := ""             # door de speler gekozen beloning (leeg of niet meer klaarstaand = de nieuwste)
var streak_bank: Array = []     # ids uit Streak.LADDER die klaarstaan, oudste eerst
var streak_given := {}          # id -> true: deze streak al uitgereikt
var streak_t := -100.0          # tijd (s) van de laatste streak-kill: de teller komt dan even in beeld
var streak_air := {"truck": 0, "napalm": 0}  # beloningen die je dit spel hebt gebruikt (voor de samenvatting)
var power := true:   # stroom in de basis en de straatlantaarns; valt uit als de generator kapot is (Generator)
	set(v):
		if v != power:
			power = v
			power_changed.emit()
var hit_src := "speler"         # wie schiet er nu: speler, soldaat of lucht; alleen speler-kills tellen voor de streak

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
	Foliage.fell_near(at, radius)   # bomen vlakbij vallen om
	blast_at = at
	blast_r = radius
	blast_t = Time.get_ticks_msec()
	# wie er net buiten de straal bij staat schrikt en zoekt dekking
	for e in enemies:
		if is_instance_valid(e) and not e.dead:
			var d: float = e.global_position.distance_to(at)
			if d > radius + 0.5 and d < radius * 2.4 + 3.0:
				e.flinch(at)


## Wat het kost om de generator te repareren (0 = heel).
func generator_cost() -> int:
	return Generator.inst.repair_cost() if Generator.inst != null else 0


## Wat het kost om de wachthuisjes en slagbomen te repareren (0 = alles heel).
func wachtpost_cost() -> int:
	return Wachtpost.inst.total_repair_cost() if Wachtpost.inst != null else 0


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
	airfield_build_view = false
	editing = false
	bcam = Vector3(0.0, 0.0, 1.0)
	buildings.clear()
	allies.clear()
	troop_mode = "follow"
	squad_order = "follow"
	squad_target = Vector3.ZERO
	squad_target_enemy = null
	streak = 0
	streak_bank.clear()
	streak_sel = ""
	streak_given.clear()
	streak_t = -100.0
	hit_src = "speler"


## Een vijand is door jou (of jouw voertuig) gevallen: de streak loopt op en een beloning kan klaarstaan.
func streak_kill() -> void:
	streak += 1
	streak_t = Time.get_ticks_msec() / 1000.0
	for r in Streak.LADDER:
		if streak >= int(r.kills) and not streak_given.has(r.id):
			streak_given[r.id] = true
			streak_bank.append(r.id)
			Sfx.play("buy")
			banner.emit(String(r.klaar), "Tik op de luchtsteun-knop", 1.5)
	changed.emit()


## Einde van de golf: de teller begint opnieuw. Wat klaarstaat blijft beschikbaar tot je het gebruikt.
func streak_reset() -> void:
	streak = 0
	streak_given.clear()
	changed.emit()


## Testschakelaar (Instellingen): alle beloningen staan altijd klaar en raken niet op.
func streak_test() -> bool:
	return GameSettings.get_value("t_streak") == "on"


func streak_fill() -> void:
	for r in Streak.LADDER:
		if not streak_bank.has(r.id):
			streak_bank.push_front(r.id)


## De beloning die de luchtsteun-knop nu toont: je keuze, of anders de nieuwste die klaarstaat. "" als er niets klaarstaat.
func streak_current() -> String:
	if streak_test():
		streak_fill()
	if streak_bank.is_empty():
		return ""
	return streak_sel if streak_bank.has(streak_sel) else String(streak_bank.back())


## Andere beloningen (één per soort) waaruit de speler kan kiezen.
func streak_others() -> Array:
	var cur := streak_current()
	var out: Array = []
	for id in streak_bank:
		if id != cur and not out.has(id):
			out.append(id)
	return out


## Gebruikt de gekozen beloning. Geeft het id terug, of "" als er niets klaarstaat. In de testmodus raakt hij niet op.
func streak_take() -> String:
	var id := streak_current()
	if id == "":
		return ""
	if not streak_test():
		streak_bank.erase(id)
	changed.emit()
	return id


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
