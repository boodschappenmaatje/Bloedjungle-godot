extends Camera3D
## Schuin van boven meekijkende camera (22-camera.js): staand scherm hoger, liggend dichterbij,
## en een stukje vooruit in de kijkrichting, verder als je richt.

var _lead := Vector3.ZERO


func _process(delta: float) -> void:
	var p = Game.player
	if p == null:
		return
	var size := get_viewport().get_visible_rect().size
	var portrait := size.x < size.y
	var h := 31.0 if portrait else 20.0
	var back := 14.0 if portrait else 11.5
	var aiming := not is_nan(Game.aim)
	var want := Vector3(sin(p.face), 0, cos(p.face)) * ((2.5 if portrait else 4.0) if aiming else 1.2)
	_lead = _lead.lerp(want, 1.0 - exp(-3.0 * delta))
	var target: Vector3 = p.global_position + _lead
	var goal := target + Vector3(0, h, back)
	global_position = global_position.lerp(goal, minf(1.0, delta * 8.0))
	look_at(global_position - Vector3(0, h, back), Vector3.UP)
