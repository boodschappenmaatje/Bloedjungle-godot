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
var upg := {"maxhp": 0, "armor": 0, "speed": 0, "fort": 0}

# Aanvalsrichting (N/O/Z/W) -> seconden dat de rand nog oplicht; gevuld door vijanden die schieten of steken.
var attack := {"N": 0.0, "O": 0.0, "Z": 0.0, "W": 0.0}

var player  # de speler (player.gd)
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
	upg = {"maxhp": 0, "armor": 0, "speed": 0, "fort": 0}


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
