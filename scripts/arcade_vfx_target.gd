extends StaticBody3D
## Dummy collision surface for the isolated arcade VFX lab; records real Bullet contacts.

var impact_count := 0


func hit(_damage: float, _direction: Vector3, _from_player: bool) -> void:
	impact_count += 1
