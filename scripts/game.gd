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
	base_hp = Data.BASE_HP
	base_max = Data.BASE_HP
	enemies.clear()


func add_points(n: int) -> void:
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
	over.emit(reason)
	changed.emit()
