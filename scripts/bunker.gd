extends StaticBody3D
## De bunker: vijandelijke kogels doen 80% van hun schade aan de basis (zoals 19-bullets.js).


func hit(dmg: float, _dir: Vector3, from_player: bool) -> void:
	if not from_player:
		Game.damage_base(dmg * 0.8)
