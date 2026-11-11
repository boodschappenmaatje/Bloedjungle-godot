class_name NapalmPlace
extends Control
## Fixture stub for scripts/napalm_plaats.gd: the team-command tests never arm napalm.
static var armed := false
static func open(parent: Control, _target: Vector3, _dir: Vector3) -> NapalmPlace:
	var n := NapalmPlace.new()
	parent.add_child(n)
	return n
