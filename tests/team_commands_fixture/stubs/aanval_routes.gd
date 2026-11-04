class_name AanvalRoutes
extends RefCounted
## Stub voor de mars naar de vijandbasis (Ally order "basis").

static func march_path() -> Array:
	return [Vector3(0, 0, 50), Vector3(0, 0, 100)]


static func march_start(_from: Vector3) -> int:
	return 0
