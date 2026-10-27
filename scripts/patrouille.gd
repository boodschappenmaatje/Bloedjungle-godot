class_name Patrouille
extends Node
## Wachten op de basis: drie soldaten lopen tijdens de pauze heen en weer langs de binnenkant van de muur en blijven af en toe
## staan. Begint een golf, dan gaat het alarm (sirene) en rennen ze naar hun post langs de muur om te schieten (zie Ally, guard).
## Het zijn gewone Ally-soldaten die niet bij de kazerne horen (niet in Game.allies), dus altijd aanwezig.

const GUARDS := 3
const ALARM_STREAM := preload("res://assets/geluid/alarm.mp3")

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
var _sirene: AudioStreamPlayer
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


## Het alarmbestand speelt één keer en de wachten rennen naar hun post.
func alarm() -> void:
	if _sirene == null:
		_sirene = AudioStreamPlayer.new()
		_sirene.stream = ALARM_STREAM
		_sirene.volume_db = -3.0
		add_child(_sirene)
	_sirene.play()


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
