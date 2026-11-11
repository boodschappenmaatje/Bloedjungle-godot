class_name Artillerie
extends Node3D
## Fixture-only artillery stub for HUD static typing and input tests.
## Not used by the production game.

static func call_in(_parent: Node, _at: Vector3, _shells := 5) -> Artillerie:
	return null

static func tap_target(from: Vector3, _facing: Vector3) -> Vector3:
	return from

static func drag_target(from: Vector3, _dir: Vector3, _k: float) -> Vector3:
	return from
