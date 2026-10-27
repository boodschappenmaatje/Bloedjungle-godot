class_name Patrouille
extends Node
## Wachten op de basis: drie soldaten lopen tijdens de pauze heen en weer langs de binnenkant van de muur en blijven af en toe
## staan. Begint een golf, dan gaat het alarm (sirene) en rennen ze naar hun post langs de muur om te schieten (zie Ally, guard).
## Het zijn gewone Ally-soldaten die niet bij de kazerne horen (niet in Game.allies), dus altijd aanwezig.

const GUARDS := 3
const SIREN_BEEPS := 8
const SIREN_GAP := 0.42

## De wandellijn van wacht i: twee punten langs de binnenkant van de muur (halve breedte van de basis = Data.COMPOUND).
static func line(i: int) -> Array:
	var c := Data.COMPOUND
	var o := c - 5.0
	match i % GUARDS:
		0:
			return [Vector3(-c + 9.0, 0, -o), Vector3(c - 9.0, 0, -o)]   # noordmuur
		1:
			return [Vector3(-c + 9.0, 0, o), Vector3(c - 9.0, 0, o)]     # zuidmuur
		_:
			return [Vector3(-o, 0, -c + 11.0), Vector3(-o, 0, c - 11.0)] # westmuur


var guards: Array = []
var alarm_t := 0.0
var _beeps := 0
var _last_state := "menu"
var _spawned := false


func _process(delta: float) -> void:
	var st: String = Game.state
	if not _spawned and (st == "prep" or st == "play"):
		_spawned = true
		_spawn()
	if _last_state == "prep" and st == "play":
		alarm()
	_last_state = st
	if _beeps > 0:
		alarm_t -= delta
		if alarm_t <= 0.0:
			_beeps -= 1
			alarm_t = SIREN_GAP
			Sfx.play("claxon" if _beeps % 2 == 0 else "alarm", 0.4)


## Sirene en wachten rennen naar hun post.
func alarm() -> void:
	_beeps = SIREN_BEEPS
	alarm_t = 0.0


func _spawn() -> void:
	var parent: Node = get_parent().get_node_or_null("Level")
	if parent == null:
		parent = get_parent()
	for i in GUARDS:
		var a := Ally.new()
		a.guard = true
		parent.add_child(a)
		a.global_position = (line(i)[0] as Vector3).lerp(line(i)[1], 0.5 * float(i % 2) + 0.15)
		a.setup(120.0, 16.0, i)
		guards.append(a)
