class_name JungleGeluid
extends Node
## Jungle-geluiden die meeleven: een achtergrondlus (overdag cicaden en wind, 's nachts krekels en kikkers), water bij de
## rivier en losse roepen tussen de bomen (vogels, duif, brulaap; 's nachts uil en nachtzwaluw). Schoten en explosies
## maken de jungle stil; daarna komt het geluid langzaam terug. Alle bestanden in assets/geluid/jungle/ worden gemaakt
## door bron/geluid/maak_jungle_geluid.py; een echte opname met dezelfde naam-begin (roep_fluit_4.ogg, achter_dag.ogg)
## wordt vanzelf meegenomen.

const MAP := "res://assets/geluid/jungle/"
const MASTER := 0.6
const BG_VOL := 0.13
const WATER_VOL := 0.16
const CALL_VOL := 0.22
const CALM_RECOVER := 18.0   # seconden om na een schot weer helemaal tot rust te komen
const FADE := 1.2            # seconden voor in- en uitfaden van een lus
const BASE_ZONE := 0.18      # zo hard klinkt de jungle midden op de basis (1 = in het bos)
const WATER_RANGE := 26.0    # tot zover van de oever hoor je de rivier

## per tijdstip: welke roepen er klinken
const CALLS := {
	"day": ["fluit", "triller", "krijs", "koer", "fluit", "triller", "brulaap"],
	"dusk": ["fluit", "koer", "krijs", "uil", "brulaap"],
	"night": ["uil", "nachtzwaluw", "nachtzwaluw", "uil"],
}

## Welke geluiden de jungle storen, en hoe sterk (1 = alles meteen stil). Sfx.play meldt ze via verstoor().
const DISTURB := {
	"pistol": 0.45, "smg": 0.5, "rifle": 0.6, "shotgun": 0.7, "mg": 0.55, "ak": 0.45, "rocket": 0.9, "boom": 1.0,
	"enemy": 0.2, "sentry": 0.3, "straal": 1.0, "napalm": 1.0, "claxon": 0.3, "alarm": 0.5,
}

static var calm := 1.0   # 1 = rustig, 0 = net geschoten
static var _loops := {}  # naam -> AudioStream (lus)
static var _calls := {}  # soort -> Array[AudioStream]

var _bg_day: AudioStreamPlayer
var _bg_night: AudioStreamPlayer
var _water: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _next_call := 6.0
var _fade := 0.0         # 0 = uit (menu), 1 = aan
var _level := {"day": 0.0, "night": 0.0, "water": 0.0}   # huidige volumes (zacht bijgestuurd)
var last_call := ""      # voor tests: de laatst gespeelde roep


## Meldt een geluid dat de jungle stoort (aangeroepen door Sfx.play).
static func verstoor(sound: String, vol := 1.0) -> void:
	calm = minf(calm, 1.0 - clampf(float(DISTURB.get(sound, 0.0)) * vol, 0.0, 1.0))


static func load_all() -> void:
	if not _loops.is_empty():
		return
	for f in DirAccess.get_files_at(MAP):
		var base := f.trim_suffix(".import").trim_suffix(".remap")
		var ext := base.get_extension()
		if ext != "wav" and ext != "ogg":
			continue
		var res := MAP + base
		if not ResourceLoader.exists(res):
			continue
		var st = load(res)
		if not st is AudioStream:
			continue
		var name := base.get_basename()
		if name.begins_with("achter_"):
			st = st.duplicate()
			if st is AudioStreamWAV:
				st.loop_mode = AudioStreamWAV.LOOP_FORWARD
				st.loop_begin = 0
				st.loop_end = int(st.get_length() * st.mix_rate)
			else:
				st.loop = true
			_loops[name.trim_prefix("achter_")] = st
		elif name.begins_with("roep_"):
			var kind := name.trim_prefix("roep_").rsplit("_", true, 1)[0]
			if not _calls.has(kind):
				_calls[kind] = []
			_calls[kind].append(st)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	load_all()
	_bg_day = _lus("dag")
	_bg_night = _lus("nacht")
	_water = _lus("water")
	for i in 3:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		_voices.append(p)


func _lus(name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = _loops.get(name)
	p.volume_db = -80.0
	add_child(p)
	return p


## Wat er klinkt: overdag/schemer/nacht en regen bepalen de mix.
func _mix() -> Dictionary:
	var t := GameSettings.get_value("time")
	var rain := GameSettings.get_value("weather") == "rain"
	var day: float = {"day": 1.0, "dusk": 0.5, "night": 0.0}[t]
	var night: float = {"day": 0.0, "dusk": 0.55, "night": 1.0}[t]
	var quiet := 0.55 if rain else 1.0   # regen overstemt insecten
	return {"day": day * quiet, "night": night * quiet}


## Hoeveel jungle er hoorbaar is waar de speler staat: 1 in het bos, een klein beetje op de basis, niets in de stad.
func zone(p: Vector3) -> float:
	var out := maxf(absf(p.x), absf(p.z)) - Data.COMPOUND   # meters buiten de basismuur
	var base := lerpf(BASE_ZONE, 1.0, clampf(out / 12.0, 0.0, 1.0))
	var past := (Data.river_z(p.x) - Data.RIVER_HALF) - p.z   # meters voorbij de rivier, de stad in
	return base * (1.0 - clampf(past / 6.0, 0.0, 1.0))


func _water_level(z: float) -> float:
	if Game.player == null:
		return 0.0
	var p: Vector3 = Game.player.global_position
	var d := absf(p.z - Data.river_z(p.x)) - Data.RIVER_HALF
	return clampf(1.0 - d / WATER_RANGE, 0.0, 1.0) * z


func _process(delta: float) -> void:
	var live := (Game.state == "play" or Game.state == "prep") and Game.player != null
	_fade = move_toward(_fade, 1.0 if live else 0.0, delta / FADE)
	calm = minf(1.0, calm + delta / CALM_RECOVER)
	var mix := _mix()
	var z := zone(Game.player.global_position) if Game.player != null else 0.0
	# na een schot zakken de lussen (insecten en vogels zwijgen); water en wind blijven
	var hush := 0.25 + 0.75 * calm
	var target := {"day": mix["day"] * hush * z, "night": mix["night"] * hush * z, "water": _water_level(z)}
	var k := clampf(delta * 2.5, 0.0, 1.0)
	for key in _level:
		_level[key] = lerpf(_level[key], target[key], k)
	_zet(_bg_day, _level["day"] * BG_VOL)
	_zet(_bg_night, _level["night"] * BG_VOL)
	_zet(_water, _level["water"] * WATER_VOL)
	if live and z > 0.6 and calm > 0.6 and GameSettings.get_value("weather") != "rain":
		_next_call -= delta
		if _next_call <= 0.0:
			_roep()
			_next_call = randf_range(3.5, 9.0) * lerpf(1.6, 1.0, calm)


func _zet(p: AudioStreamPlayer, vol: float) -> void:
	vol *= _fade * MASTER
	if vol < 0.002:
		if p.playing:
			p.stop()
		return
	if not p.playing and p.stream != null:
		p.play()
	p.volume_db = linear_to_db(vol)


## Speelt één losse roep van een soort die bij het tijdstip past.
func _roep() -> void:
	var kinds: Array = CALLS[GameSettings.get_value("time")]
	var kind: String = kinds[randi() % kinds.size()]
	var pool: Array = _calls.get(kind, [])
	if pool.is_empty():
		return
	for p in _voices:
		if not p.playing:
			p.stream = pool[randi() % pool.size()]
			p.pitch_scale = randf_range(0.92, 1.08)
			p.volume_db = linear_to_db(CALL_VOL * randf_range(0.5, 1.0) * MASTER * _fade)
			p.play()
			last_call = kind
			return
