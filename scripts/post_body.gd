class_name PostBody
extends StaticBody3D
## Botsblok van een wachthuisje of een slagboomkast: vijandelijke kogels beschadigen het onderdeel, jouw eigen kogels niet (zoals GateBody).

var post: Dictionary = {}
var part := "hut"   # "hut" of "boom"


func hit(dmg: float, _dir: Vector3, from_player: bool) -> void:
	if not from_player and Wachtpost.inst != null:
		Wachtpost.inst.damage(post, part, dmg, "bullet")
