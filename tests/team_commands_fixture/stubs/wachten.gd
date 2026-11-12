class_name Wachten
extends RefCounted
## Stub voor de fixture: ally.gd vraagt bij een wacht van de kazerne naar zijn doel; hier staat hij gewoon stil.

static func goal(a: Node3D) -> Vector3:
	return a.global_position
