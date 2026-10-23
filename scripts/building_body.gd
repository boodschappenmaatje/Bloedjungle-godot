class_name BuildingBody
extends StaticBody3D
## Collider van een bouwstuk (kazerne, muur, zandzak, ...). Kogels van vijanden beschadigen het gebouw
## (hit() zoals bij GateBody); de schade zelf staat in Buildings.damage().

var ref: Dictionary = {}


func hit(dmg: float, _dir: Vector3, from_player: bool) -> void:
	if from_player or ref.is_empty() or Game.builds == null:
		return
	# 16f-buildings.js: een muur of zandzak krijgt de volle schade van een kogel, een gebouw een vijfde
	Game.builds.damage(ref, dmg * (1.0 if Game.builds.is_piece(ref.kind) else 0.2))
