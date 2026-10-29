extends Node
## Geluid (autoload "Sfx"): alle effecten van de web-versie (11-audio.js) worden bij het opstarten zelf
## gemaakt uit ruis door een filter dat dichtgaat, plus een zware dreun voor de laagste tonen.

const RATE := 22050
# f = filterfrequentie waarmee het begint, d = duur in seconden, v = volume, b = dreunfrequentie (0 = geen)
const DEFS := {
	"pistol": {"f": 2400, "d": 0.2, "v": 0.7, "b": 120}, "smg": {"f": 2600, "d": 0.13, "v": 0.5, "b": 95},
	"rifle": {"f": 1900, "d": 0.4, "v": 0.95, "b": 80}, "shotgun": {"f": 1300, "d": 0.5, "v": 1.1, "b": 60},
	"mg": {"f": 2100, "d": 0.15, "v": 0.55, "b": 85}, "rocket": {"f": 800, "d": 0.7, "v": 0.8, "b": 50},
	"enemy": {"f": 1600, "d": 0.16, "v": 0.32, "b": 0}, "ak": {"f": 2200, "d": 0.14, "v": 0.4, "b": 90},
	"boom": {"f": 600, "d": 1.3, "v": 1.3, "b": 42}, "splat": {"f": 450, "d": 0.14, "v": 0.45, "b": 0},
	"hurt": {"f": 700, "d": 0.2, "v": 0.6, "b": 70}, "click": {"f": 5000, "d": 0.04, "v": 0.25, "b": 0},
	"reload": {"f": 3500, "d": 0.08, "v": 0.3, "b": 0}, "buy": {"f": 3000, "d": 0.1, "v": 0.35, "b": 400},
	"knife": {"f": 900, "d": 0.1, "v": 0.4, "b": 0}, "thud": {"f": 400, "d": 0.15, "v": 0.5, "b": 60},
	"sentry": {"f": 2500, "d": 0.11, "v": 0.3, "b": 0}, "ping": {"f": 4200, "d": 0.05, "v": 0.18, "b": 0}, "gate": {"f": 520, "d": 0.6, "v": 0.3, "b": 46},
	"spuit": {"f": 5200, "d": 1.1, "v": 0.5, "b": 0},
	"straal": {"f": 1500, "d": 2.4, "v": 0.5, "b": 75}, "napalm": {"f": 900, "d": 1.7, "v": 0.95, "b": 52}, "wuuf": {"f": 420, "d": 0.6, "v": 0.8, "b": 38},
	"claxon": {"f": 900, "d": 0.45, "v": 0.5, "b": 0, "tone": 410.0}, "alarm": {"f": 900, "d": 0.3, "v": 0.45, "b": 0, "tone": 1250.0},
}
const VOICES := 20
const MASTER := 0.6

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _rain: AudioStreamPlayer
var _jet: AudioStreamPlayer
var fluit: AudioStreamWAV   # fluitende val van een bom (napalm): glijdende toon met wat ruis


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for k in DEFS:
		_streams[k] = _make(DEFS[k])
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	fluit = _make_fluit()
	_rain = AudioStreamPlayer.new()
	_rain.stream = _make_rain()
	_rain.volume_db = linear_to_db(0.22)
	add_child(_rain)


## Speelt een effect. pos = waar het klinkt (zacht als het ver van de speler is); zonder pos klinkt het overal even hard.
func play(name: String, vol := 1.0, pos = null) -> void:
	if not _streams.has(name):
		return
	JungleGeluid.verstoor(name, vol)
	if pos != null and Game.player:
		var d: float = (pos as Vector3).distance_to(Game.player.global_position)
		vol *= clampf(1.2 - d / 35.0, 0.05, 1.0)
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _streams[name]
	p.pitch_scale = randf_range(0.88, 1.14)
	p.volume_db = linear_to_db(maxf(0.001, vol * MASTER))
	p.play()


## Straaljager: een lus van turbinegeluid (brullende ruis, gillende turbine, diepe dreun) die jet_set elke beeld luider/zachter
## en hoger/lager zet (afstand en dopplereffect). jet_on start hem, jet_off stopt hem.
func jet_on() -> void:
	if _jet == null:
		_jet = AudioStreamPlayer.new()
		_jet.stream = _make_jet()
		add_child(_jet)
	_jet.volume_db = -80.0
	_jet.play()


func jet_set(vol: float, pitch: float) -> void:
	if _jet == null or not _jet.playing:
		return
	_jet.volume_db = linear_to_db(maxf(0.0005, vol * MASTER))
	_jet.pitch_scale = clampf(pitch, 0.5, 1.6)


func jet_off() -> void:
	if _jet != null:
		_jet.stop()


func _make_jet() -> AudioStreamWAV:
	var n := RATE * 2                # 2 s lus: hele aantallen perioden van de turbinetonen, ruis met overvloeiing
	var fade := 2400
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var raw := PackedFloat32Array()
	raw.resize(n + fade)
	var lp1 := 0.0
	var lp2 := 0.0
	var lp3 := 0.0
	for i in n + fade:
		var w := rng.randf_range(-1.0, 1.0)
		lp1 += 0.30 * (w - lp1)          # brul (tot ~1,6 kHz)
		lp2 += 0.06 * (w - lp2)          # laag brommen
		lp3 += 0.012 * (w - lp3)         # diepe dreun
		var hiss := w - lp1              # sissende hoge ruis
		raw[i] = lp1 * 1.1 + lp2 * 2.2 + lp3 * 5.0 + hiss * 0.45
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var v: float = raw[i]
		if i < fade:   # lusnaad: het eind (raw[n+i]) loopt over in het begin
			var k := float(i) / fade
			v = lerpf(raw[n + i], raw[i], k)
		var am := 1.0 + 0.18 * sin(TAU * 5.0 * t / 2.0) + 0.08 * sin(TAU * 13.0 * t / 2.0)
		var whine := sin(TAU * 1760.0 * t) * 0.16 + sin(TAU * 2640.0 * t + 1.0) * 0.12 + sin(TAU * 3520.0 * t) * 0.07
		var out := (v * 0.55 + whine) * am
		data.encode_s16(i * 2, clampi(roundi(tanh(out * 1.6) * 31000.0), -32768, 32767))   # zacht afkappen: hard en overweldigend
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w


func rain(on: bool) -> void:
	if on and not _rain.playing:
		_rain.play()
	elif not on:
		_rain.stop()


func _make(s: Dictionary) -> AudioStreamWAV:
	var n := int(RATE * (s.d + 0.03))
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(s))
	for i in n:
		var t := float(i) / RATE
		var u := minf(1.0, t / s.d)
		# het filter gaat van f naar bijna dicht (exponentieel), de toon sterft uit
		var cutoff := maxf(60.0, s.f * pow(0.12, u))
		var a := 1.0 - exp(-TAU * cutoff / RATE)
		lp += a * (rng.randf_range(-1.0, 1.0) - lp)
		var env := pow(0.001, u) if t < s.d else 0.0
		var v: float = lp * 3.0 * s.v * env
		if s.b > 0:
			var fr: float = s.b * 2.0 * pow(0.25, minf(1.0, t / (s.d * 0.6)))
			phase += TAU * fr / RATE
			v += sin(phase) * s.v * 0.9 * (pow(0.001, minf(1.0, t / (s.d * 0.7))) if t < s.d * 0.7 else 0.0)
		var tone: float = s.get("tone", 0.0)
		if tone > 0.0:   # toeter en alarm: een toon met een boventoon die aan- en uitzwelt
			var te := clampf(minf(t * 60.0, (s.d - t) * 40.0), 0.0, 1.0)
			v = lp * 0.2 * s.v * te + (sin(TAU * tone * t) + 0.5 * sin(TAU * tone * 2.01 * t)) * s.v * 0.5 * te
		data.encode_s16(i * 2, clampi(roundi(tanh(v * 0.8) * 32000.0), -32768, 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w


func _make_fluit() -> AudioStreamWAV:
	var dur := 2.0
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var lp := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in n:
		var t := float(i) / RATE
		var u := t / dur
		phase += TAU * lerpf(1900.0, 950.0, u) / RATE
		lp += 0.2 * (rng.randf_range(-1.0, 1.0) - lp)
		var v := (sin(phase) * 0.5 + sin(phase * 2.01) * 0.12 + lp * 0.25) * minf(1.0, t * 12.0)
		data.encode_s16(i * 2, clampi(roundi(v * 20000.0), -32768, 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w


func _make_rain() -> AudioStreamWAV:
	var n := RATE * 3
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	for i in n:
		lp += 0.35 * (randf_range(-1.0, 1.0) - lp)
		data.encode_s16(i * 2, roundi(lp * 9000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = n
	return w
