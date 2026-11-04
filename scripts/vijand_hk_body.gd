class_name VijandHkBody
extends StaticBody3D
## Botsblok van het vijandelijke hoofdkwartier: kogels van jou, je soldaten en je voertuigen beschadigen het, die van vijanden niet.
## Het ligt op de muurlaag en op de bunkerlaag: laag 16 ziet ook de kogels van de Apache en de jeep, die over muren heen schieten.


func hit(dmg: float, _dir: Vector3, from_player: bool) -> void:
	if from_player and VijandHk.inst != null:
		VijandHk.inst.damage(dmg, "bullet")
