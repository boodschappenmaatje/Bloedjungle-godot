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
}
const VOICES := 20
const MASTER := 0.6

var _streams := {}
var _m1911_shots: Array[AudioStreamWAV] = []
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _rain: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for k in DEFS:
		_streams[k] = _make(DEFS[k])
	# Drie originele, vooraf gesynthetiseerde pistoolknallen: geen externe audio-assets.
	for variant in 3:
		_m1911_shots.append(_make_m1911_shot(variant))
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_rain = AudioStreamPlayer.new()
	_rain.stream = _make_rain()
	_rain.volume_db = linear_to_db(0.22)
	add_child(_rain)


## Speelt een effect. pos = waar het klinkt (zacht als het ver van de speler is); zonder pos klinkt het overal even hard.
func play(name: String, vol := 1.0, pos = null) -> void:
	if not _streams.has(name):
		return
	if pos != null and Game.player:
		var d: float = (pos as Vector3).distance_to(Game.player.global_position)
		vol *= clampf(1.2 - d / 35.0, 0.05, 1.0)
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	if name == "pistol" and not _m1911_shots.is_empty():
		p.stream = _m1911_shots[randi() % _m1911_shots.size()]
		p.pitch_scale = randf_range(0.97, 1.04)
	else:
		p.stream = _streams[name]
		p.pitch_scale = randf_range(0.88, 1.14)
	p.volume_db = linear_to_db(maxf(0.001, vol * MASTER))
	p.play()


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
		data.encode_s16(i * 2, clampi(roundi(tanh(v * 0.8) * 32000.0), -32768, 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w


## Een droge, krachtige .45 ACP-achtige gameknal: snelle crack, lage body,
## korte nagalm en een zachte mechanische klik. Volledig zelf gegenereerd
## tijdens opstarten: sample-accuraat synchroon via Sfx.play("pistol").
func _make_m1911_shot(variant: int) -> AudioStreamWAV:
	var count := int(RATE * 0.25)
	var pcm := PackedByteArray()
	pcm.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 191100 + variant * 4099
	var lowpass := 0.0
	var phase := 0.0
	for i in count:
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		lowpass += 0.28 * (noise - lowpass)
		phase += TAU * (155.0 * exp(-t * 11.0) + 63.0) / RATE
		var crack := noise * exp(-t * 120.0) * 0.9
		var punch := sin(phase) * exp(-t * 23.0) * 0.58
		var tail := lowpass * exp(-t * 19.0) * 0.48
		var action_click := 0.0
		if t >= 0.045 and t < 0.09:
			var mech_t := t - 0.045
			action_click = noise * exp(-mech_t * 105.0) * 0.17
		var sample_value := tanh((crack + punch + tail + action_click) * 1.15)
		pcm.encode_s16(i * 2, clampi(roundi(sample_value * 30700.0), -32768, 32767))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = RATE
	sound.data = pcm
	return sound


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
