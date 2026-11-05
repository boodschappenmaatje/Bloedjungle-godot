class_name BaseWallRules
extends RefCounted
## Fixture-only: this test has no world geometry or base-wall collision.
## The wall LOS implementation is tested in the full Godot game instead.

static func blocks_ground_fire(_origin: Vector3, _target: Vector3) -> bool:
	return false
