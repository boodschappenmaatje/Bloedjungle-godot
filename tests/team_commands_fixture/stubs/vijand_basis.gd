class_name VijandBasis
extends RefCounted
## Stub: de testproject heeft geen vijandbasis; alleen wat Ally en TeamCommands aanroepen.

static func gate_outside() -> Vector3:
	return Vector3(0, 0, 100)


static func attack_spot(_i: int) -> Vector3:
	return Vector3(0, 0, 90)


static func hk_distance(_p: Vector3) -> float:
	return 999.0


static func contains(_p: Vector3, _margin := 0.0) -> bool:
	return false
