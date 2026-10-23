extends StaticBody3D
## De bunker: vijandelijke kogels doen 80% van hun schade aan de basis (zoals 19-bullets.js).
## Is de basis bijna kapot, dan komt er rook uit en onder de 20% ook vuur.

var _smoke: Node3D
var _fire: Node3D
var _check := 0.0


func hit(dmg: float, _dir: Vector3, from_player: bool) -> void:
	if not from_player:
		Game.damage_base(dmg * 0.8)


func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.5
	var ratio: float = Game.base_hp / Game.base_max
	if ratio < 0.4 and _smoke == null:
		_smoke = Fx.burning(self, global_position + Vector3(1.3, 2.5, -1.1), false)
	elif ratio >= 0.4 and _smoke != null:
		_smoke.queue_free()
		_smoke = null
	if ratio < 0.2 and _fire == null:
		_fire = Fx.burning(self, global_position + Vector3(-1.2, 2.5, 0.9), true)
	elif ratio >= 0.2 and _fire != null:
		_fire.queue_free()
		_fire = null
