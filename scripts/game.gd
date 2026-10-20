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
var base_max := Data.BASE_HP
var prep_t := 0.0
var bonus := 0  # bonus van de laatste overleefde golf, getoond in de wapenkamer

# Wat je bezit: per wapen de upgradeniveaus en de kogels in het magazijn, en de uitrusting-upgrades.
var owned := _fresh_owned()
var cur := "m1911"
var upg := {"maxhp": 0, "armor": 0, "speed": 0, "fort": 0, "sentry": 0}
# spullen in je tas om neer te zetten (Defenses)
var inv := {"bags": 0, "trench": 0, "mine": 0, "wire": 0, "sentry": 0}
var place_sel := "bags"
var place_armed := false  # spookbeeld en neerzetten aan/uit
# bouwen (Buildings): het bouwtegoed ga je eerst uitgeven, daarna je punten
const BUILD_CREDIT := 1000
var build_credit := BUILD_CREDIT
var builds: Buildings
var build_arm := ""  # gebouw dat je aan het neerzetten bent ("" = niets)
var buildings: Array = []
var allies: Array = []
var troop_mode := "follow"  # follow of hold

# Aanvalsrichting (N/O/Z/W) -> seconden dat de rand nog oplicht; gevuld door vijanden die schieten of steken.
var attack := {"N": 0.0, "O": 0.0, "Z": 0.0, "W": 0.0}

var player  # de speler (player.gd)
var defs  # verdediging die je neerzet (defenses.gd)
var enemies: Array = []

# Besturing, ingevuld door touch_sticks.gd (of toetsenbord en muis):
# move = looprichting op de grond (x, z), aim = kijkhoek of NAN, fire = schieten
var move := Vector2.ZERO
var aim := NAN
var fire := false


func reset() -> void:
	state = "prep"
	wave = 0
	points = Data.START_POINTS
	score = 0
	kills = 0
	bonus = 0
	base_hp = Data.BASE_HP
	base_max = Data.BASE_HP
	enemies.clear()
	owned = _fresh_owned()
	cur = "m1911"
	upg = {"maxhp": 0, "armor": 0, "speed": 0, "fort": 0, "sentry": 0}
	inv = {"bags": 0, "trench": 0, "mine": 0, "wire": 0, "sentry": 0}
	place_sel = "bags"
	place_armed = false
	build_credit = BUILD_CREDIT
	build_arm = ""
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


static func _fresh_owned() -> Dictionary:
	return {"m1911": {"up": {"dmg": 0, "rate": 0, "mag": 0, "rel": 0}, "ammo": Data.WEAPONS.m1911.mag}}


## Een vijand valt aan vanaf pos: licht de bijbehorende kant van het scherm op (markAttack in 23-hud.js).
func mark_attack(pos: Vector3) -> void:
	var k := "O" if pos.x > 0 else "W"
	if absf(pos.x) <= absf(pos.z):
		k = "Z" if pos.z > 0 else "N"
	attack[k] = 2.5
