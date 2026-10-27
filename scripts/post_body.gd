class_name PostBody
extends StaticBody3D
## Botsblok van een wachthuisje of een slagboomkast: kogels van vijanden en van jou beschadigen het onderdeel, die van soldaten (Game.hit_src "soldaat") niet.

var post: Dictionary = {}
var part := "hut"   # "hut" of "boom"


func hit(dmg: float, _dir: Vector3, from_player: bool) -> void:
	if Wachtpost.inst != null and not (from_player and Game.hit_src == "soldaat"):
		Wachtpost.inst.damage(post, part, dmg, "bullet")
