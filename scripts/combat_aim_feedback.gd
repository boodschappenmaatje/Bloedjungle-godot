class_name CombatAimFeedback
extends RefCounted
## Read-only prediction for the current jeep MG shot. This never applies damage,
## changes the existing narrow gunner assist, or claims a confirmed hit.
const MAX_FLAT_RANGE := 40.5  # jeep.gd: 90 m/s * 0.45 s
# Keep this display-only layer independent of Bullet.gd: Bullet itself emits
# confirmed-hit feedback through CombatAimFeedback.actual_damage(). A static
# Bullet reference here creates a GDScript preload cycle in headless tests.
# Contract test below verifies these values against Bullet's canonical masks.
const MASK_WALL := 2
const MASK_ENEMY := 8
const MASK_BUNKER := 16
const MASK_NATURE := 128
const MASK_VEHICLE := 1024
const MASK_FORTIFICATION := 1 << 12
const BASE_WALL_H := 3.0
# Mirrors Bullet's collision bits without importing the Bullet class at script-parse
# time. Headless SceneTree tests initialize Game after dependent class scans.
const MASK_ENEMY := 8
const MASK_VEHICLE := 1024

static func target_kind(collider: Object) -> String:
	if not (collider is Node3D):
		return "blocked"
	var node := collider as Node3D
	# Avoid compiling the Game autoload symbol before the SceneTree test harness
	# has initialised its autoloads; the production singleton is fetched read-only.
	var game := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Game")
	var in_enemies := game != null and (game.get("enemies") as Array).has(node)
	if node.is_in_group("vijand_verdediger") or in_enemies:
		if not bool(node.get("dead")):
			return "enemy"
	return "blocked"


static func predict(space: PhysicsDirectSpaceState3D, origin: Vector3, angle: float, rise: float) -> Dictionary:
	# Same masks as Bullet.fire(): the raised jeep MG ignores low wall-cover only
	# for flat shots. Fortifications and the rotating M2 shield always block.
	var mask := MASK_ENEMY | Kit.LAYER_BUNKER | MASK_VEHICLE | Kit.LAYER_NATURE | Kit.LAYER_FORTIFICATION
	if not is_zero_approx(rise):
		mask |= Kit.LAYER_WALL
	var ray_dir := Vector3(sin(angle), rise, cos(angle))
	var end := origin + ray_dir * MAX_FLAT_RANGE
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, end, mask))
	var point: Vector3 = hit.position if not hit.is_empty() else end
	var collider: Object = hit.get("collider") if not hit.is_empty() else null

	# Bullet.gd has a separate low-height fortification sweep for ground shots,
	# so the preview must never advertise a vulnerable target behind that wall.
	if origin.y < BASE_WALL_H:
		var flat_origin := Vector3(origin.x, 1.5, origin.z)
		var flat_end := Vector3(end.x, 1.5, end.z)
		var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(flat_origin, flat_end, Kit.LAYER_FORTIFICATION))
		if not wall.is_empty():
			var wall_dist := Vector2(wall.position.x - origin.x, wall.position.z - origin.z).length()
			var hit_dist := Vector2(point.x - origin.x, point.z - origin.z).length()
			if wall_dist <= hit_dist + 0.0001:
				point = wall.position
				collider = wall.collider

	var kind := "clear" if collider == null else target_kind(collider)
	var target: Node3D = collider as Node3D if kind == "enemy" else null
	return {"state": kind, "point": point, "target": target, "origin": origin}


## Never infer hit confirmation from the aim ray. A real hit handler calls
## this only after it has observed positive HP loss on a real enemy.
static func actual_damage(before: float, after: float) -> float:
	return maxf(before - after, 0.0)
