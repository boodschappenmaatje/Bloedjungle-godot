class_name GateBody
extends StaticBody3D
## Botsblok van een poort: vijandelijke kogels beschadigen de poort, jouw eigen kogels niet.

var index := 0


func hit(dmg: float, _dir: Vector3, from_player: bool) -> void:
	if not from_player and Game.gates:
		Game.gates.damage(index, dmg, "bullet")
