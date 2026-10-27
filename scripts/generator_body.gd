class_name GeneratorBody
extends StaticBody3D
## Botsblok van de generator: kogels van vijanden en van jou beschadigen hem, die van soldaten (Game.hit_src "soldaat") niet.


func hit(dmg: float, _dir: Vector3, from_player: bool) -> void:
	if Generator.inst != null and not (from_player and Game.hit_src == "soldaat"):
		Generator.inst.damage(dmg, "bullet")
