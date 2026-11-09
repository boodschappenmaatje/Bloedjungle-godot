extends StaticBody3D

func hit(dmg: float, _dir: Vector3, from_player: bool) -> void:
	if from_player:
		get_parent().damage(dmg)
