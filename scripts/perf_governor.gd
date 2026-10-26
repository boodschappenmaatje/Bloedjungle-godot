class_name PerfGovernor
extends Node
## Houdt het beeld op het doel (60 of 120 fps, zie GameSettings.target_fps): zakt het onder de ~93% daarvan, dan rendert het spel de 3D-wereld met minder pixels
## (HUD blijft scherp); is het weer vlot, dan gaat de resolutie stapje voor stapje terug omhoog tot de
## ingestelde grafiek-stand. Zo blijft het spelen soepel op elk toestel en tijdens drukke golven.

static var grace_until := 0  # ms; na het laden tellen de eerste paar seconden niet mee
static var paused := false   # de diagnose-run zet de regelaar even stil

const MIN_SCALE := 0.5
const DOWN_RATIO := 0.93  # van het doel; 56 bij 60 fps, 112 bij 120
const UP_RATIO := 0.98

var _cap := 0.8
var _quality := ""
var _acc := 0.0
var _frames := 0
var _good := 0.0
var _hold := 0.0  # na een verlaging eerst even wachten voor we weer omhoog proberen
var _low := 0.0   # seconden op de laagste resolutie en toch onder het doel
var _tier_wait := 0.0
const TIER_RATIO := 0.88  # van het doel: 53 bij 60 fps; daaronder gaat een onderdeel uit
const TIER_AFTER := 3.0   # zoveel seconden achter elkaar
const TIER_GAIN := 3.0    # een trap moet minstens zoveel fps opleveren
var _fps_at_step := 0.0
var _nogain := 0          # trappen achter elkaar zonder winst: dan ligt het niet aan het tekenen (bijvoorbeeld een 30 fps-limiet van iOS)
var _frozen := false
## Platform-limiet: lagere resolutie levert niets op (de diagnose-run op de iPhone liet zien dat zelfs een kaal beeld 19-26 ms
## duurt, door het tempo van iOS/Xogot). Dan blijft de resolutie op de gekozen stand in plaats van voor niets te zakken.
const PLAT_DROP := 0.16   # zoveel resolutie omlaag...
const PLAT_GAIN := 4.0    # ...zonder minstens zoveel fps winst = het ligt niet aan het tekenen
const PLAT_HOLD := 45.0   # seconden vasthouden voor we het opnieuw proberen
static var platform_limited := false
var _ref_scale := -1.0
var _ref_fps := 0.0
var _plat_hold := 0.0


func _process(delta: float) -> void:
	if paused:
		return
	var vp := get_viewport()
	var q: String = GameSettings.get_value("quality")
	if q != _quality:
		_quality = q
		_frozen = false
		_nogain = 0
		if Atmosphere.tier > 0:
			Atmosphere.tier = 0   # een nieuwe keuze begint weer bij de gekozen grafiek
			var atm0 := get_tree().get_first_node_in_group("atmosphere")
			if atm0 != null:
				atm0.apply_settings()
		var table: Dictionary = (load("res://scripts/atmosphere.gd") as GDScript).get("QUALITY")
		_cap = table[q].scale
		vp.scaling_3d_scale = _cap
	if GameSettings.get_value("t_res") == "small":
		vp.scaling_3d_scale = 0.3   # test: helpt dit, dan is de GPU het knelpunt; helpt het niet, dan de processor
		get_tree().root.set_meta("res_scale", 0.3)
		return
	# de eerste seconden (laden, shaders) tellen niet mee
	if Time.get_ticks_msec() < maxi(4000, grace_until) or Game.state == "menu":
		return
	_acc += delta
	_frames += 1
	_hold -= delta
	if _acc < 0.5:
		return
	var fps := _frames / _acc
	_acc = 0.0
	_frames = 0
	# onthoud het hoogste tempo dat echt gehaald wordt (zakt langzaam terug), voor schermen die hun snelheid niet melden
	GameSettings.observed_peak = maxf(60.0, maxf(fps, GameSettings.observed_peak - 0.5))
	var s := vp.scaling_3d_scale
	var target := GameSettings.target_fps()
	if _plat_hold > 0.0:
		_plat_hold -= 0.5
		platform_limited = _plat_hold > 0.0
		_low = 0.0
		get_tree().root.set_meta("res_scale", vp.scaling_3d_scale)
		return
	# op de laagste resolutie en nog steeds te traag: de duurste onderdelen uit (trap voor trap, nooit terug omhoog)
	_tier_wait -= 0.5
	if s <= MIN_SCALE + 0.01 and fps < target * TIER_RATIO:
		_low += 0.5
		if _low >= TIER_AFTER and _tier_wait <= 0.0 and not _frozen:
			_low = 0.0
			_tier_wait = 4.0
			if Atmosphere.tier > 0:
				_nogain = _nogain + 1 if fps < _fps_at_step + TIER_GAIN else 0
				if _nogain >= 2:
					_frozen = true   # twee trappen zonder winst: verder lager zetten heeft geen zin
					PerfMonitor.note("kwaliteit blijft op trap %d: geen winst" % Atmosphere.tier)
			if not _frozen:
				var atm := get_tree().get_first_node_in_group("atmosphere")
				if atm != null:
					_fps_at_step = fps
					atm.step_down()
	else:
		_low = 0.0
	if fps < target * DOWN_RATIO:
		_good = 0.0
		if _ref_scale < 0.0:
			_ref_scale = s
			_ref_fps = fps
		elif fps >= _ref_fps + PLAT_GAIN:
			_ref_scale = s   # het helpt: opnieuw tellen vanaf hier
			_ref_fps = fps
		elif s <= _ref_scale - PLAT_DROP:
			_plat_hold = PLAT_HOLD
			platform_limited = true
			_ref_scale = -1.0
			vp.scaling_3d_scale = _cap
			PerfMonitor.note("platform-limiet: minder pixels helpt niet, resolutie terug")
			get_tree().root.set_meta("res_scale", _cap)
			return
		vp.scaling_3d_scale = maxf(MIN_SCALE, s - (0.08 if fps < target * 0.75 else 0.04))
		_hold = 8.0
	elif fps >= target * UP_RATIO and s < _cap and _hold <= 0.0:
		_good += 0.5
		if _good >= 4.0:
			_good = 0.0
			vp.scaling_3d_scale = minf(_cap, s + 0.03)
	else:
		_good = 0.0
	if fps >= target * DOWN_RATIO:
		_ref_scale = -1.0
	get_tree().root.set_meta("res_scale", vp.scaling_3d_scale)
