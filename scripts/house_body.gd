class_name HouseBody
extends StaticBody3D
## Collider van een muurstuk van een huis in de stad (woonhuis.gd). Kogels slaan er stukken uit:
## vijanden de volle schade, jijzelf een derde (zodat je niet per ongeluk je eigen dekking wegschiet).

var house: Woonhuis
var seg: Dictionary = {}


func hit(dmg: float, _dir: Vector3, from_player: bool) -> void:
	if house == null or seg.is_empty():
		return
	house.damage(seg, dmg * (0.33 if from_player else 1.0))
