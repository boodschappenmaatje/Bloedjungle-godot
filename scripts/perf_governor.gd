class_name PerfGovernor
extends Node
## Houdt het beeld op 60 fps: zakt het onder de ~56 fps, dan rendert het spel de 3D-wereld met minder pixels
## (HUD blijft scherp); is het weer vlot, dan gaat de resolutie stapje voor stapje terug omhoog tot de
## ingestelde grafiek-stand. Zo blijft het spelen soepel op elk toestel en tijdens drukke golven.

static var grace_until := 0  # ms; na het laden tellen de eerste paar seconden niet mee

const MIN_SCALE := 0.5
const DOWN_FPS := 56.0
const UP_FPS := 59.0

var _cap := 0.8
var _quality := ""
var _acc := 0.0
var _frames := 0
var _good := 0.0
var _hold := 0.0  # na een verlaging eerst even wachten voor we weer omhoog proberen


func _process(delta: float) -> void:
	var vp := get_viewport()
	var q: String = GameSettings.get_value("quality")
	if q != _quality:
		_quality = q
		var table: Dictionary = (load("res://scripts/atmosphere.gd") as GDScript).get("QUALITY")
		_cap = table[q].scale
		vp.scaling_3d_scale = _cap
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
	var s := vp.scaling_3d_scale
	if fps < DOWN_FPS:
		_good = 0.0
		vp.scaling_3d_scale = maxf(MIN_SCALE, s - (0.08 if fps < 45.0 else 0.04))
		_hold = 8.0
	elif fps >= UP_FPS and s < _cap and _hold <= 0.0:
		_good += 0.5
		if _good >= 4.0:
			_good = 0.0
			vp.scaling_3d_scale = minf(_cap, s + 0.03)
	else:
		_good = 0.0
	get_tree().root.set_meta("res_scale", vp.scaling_3d_scale)
