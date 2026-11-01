class_name Radio
extends Node
## Radiomeldingen in het Engels (Generals-plan, G1). Stem van Dennis, met tools/radio_stem.sh tot onherkenbare
## veldradio omgebouwd (met klik ervoor en erna). Geen tekstbalk. Meldingen lopen nooit door elkaar:
## wat tijdens een melding binnenkomt wacht (alleen de laatste) en klinkt daarna.
## Dit script verwijst bewust niet naar autoloads, zodat het ook in tests laadt.

const DIR := "res://assets/geluid/radio/"
const POOLS := {
	"bouw_klaar": ["bouw_klaar_1", "bouw_klaar_2"],
	"gebouw_vernield": ["gebouw_vernield_1", "gebouw_vernield_2"],
	"basis_aanval": ["basis_aanval_1", "basis_aanval_2", "basis_aanval_3"],
	"eenheid_klaar": ["eenheid_klaar_1", "eenheid_klaar_2"],
}
## Minimaal aantal seconden tussen twee meldingen van dezelfde soort (zodat een gevecht niet blijft roepen).
const COOLDOWN := {"bouw_klaar": 0.0, "gebouw_vernield": 4.0, "basis_aanval": 25.0, "eenheid_klaar": 3.0}
const VOLUME_DB := -3.0

var _player: AudioStreamPlayer
var _streams := {}
var _last := {}
var _pending := ""
var _t := 0.0
var _last_pick := {}


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.volume_db = VOLUME_DB
	_player.finished.connect(_on_finished)
	add_child(_player)
	for kind in POOLS:
		for n in POOLS[kind]:
			var res: String = DIR + String(n) + ".wav"
			if ResourceLoader.exists(res):
				_streams[n] = load(res)


func _process(delta: float) -> void:
	_t += delta


## Zegt een melding van deze soort (zie POOLS). Geeft true als hij klinkt of in de wachtrij staat.
func say(kind: String) -> bool:
	if not POOLS.has(kind) or _player == null:
		return false
	if _t - float(_last.get(kind, -1000.0)) < float(COOLDOWN[kind]):
		return false
	_last[kind] = _t
	if _player.playing:
		_pending = kind
		return true
	_play(kind)
	return true


func _play(kind: String) -> void:
	var pool: Array = POOLS[kind]
	var i := randi() % pool.size()
	if pool.size() > 1 and i == int(_last_pick.get(kind, -1)):
		i = (i + 1) % pool.size()  # niet twee keer dezelfde variant achter elkaar
	_last_pick[kind] = i
	var st = _streams.get(pool[i])
	if st == null:
		return
	_player.stream = st
	_player.play()


func _on_finished() -> void:
	if _pending != "":
		var k := _pending
		_pending = ""
		_play(k)
