class_name BazookaAimFeedback
extends RefCounted
## Schietsysteem 2.0, phase 3A. Approximate CENTERLINE preview of the current
## player bazooka projectile. Never changes Bullet physics, damage or ammo.
## No ring is shown at maximum range: player rockets silently expire there.

static func predict(space: PhysicsDirectSpaceState3D, origin: Vector3, angle: float, max_range: float, over_wall: bool, radius: float) -> Dictionary:
	var reach := maxf(max_range, 0.01)
	var end := origin + Vector3(sin(angle), 0.0, cos(angle)) * reach
	# Use the exact masks from Bullet.fire(), not the gunner's aim-assist masks.
	var mask: int = Bullet.MASK_ENEMY | Bullet.MASK_BUNKER | Bullet.MASK_VEHICLE | Bullet.MASK_NATURE | Bullet.MASK_FORTIFICATION
	if not over_wall:
		mask |= Bullet.MASK_WALL
	var first := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, end, mask))
	var point: Vector3 = first.position if not first.is_empty() else end
	var has_impact := not first.is_empty()

	# Bullet._physics_process performs this EXTRA height-1.5 sweep for the
	# high base-wall collider, even when low cover is intentionally ignored.
	if origin.y < Data.BASE_WALL_H:
		var wall_start := Vector3(origin.x, 1.5, origin.z)
		var wall_end := Vector3(end.x, 1.5, end.z)
		var wall_query := PhysicsRayQueryParameters3D.create(wall_start, wall_end, Bullet.MASK_FORTIFICATION)
		wall_query.hit_from_inside = true
		var high_wall := space.intersect_ray(wall_query)
		if not high_wall.is_empty():
			var wall_dist := Vector2(high_wall.position.x - origin.x, high_wall.position.z - origin.z).length()
			var hit_dist := Vector2(point.x - origin.x, point.z - origin.z).length()
			if wall_dist <= hit_dist + 0.0001:
				point = high_wall.position
				has_impact = true

	# Real projectiles also perform a swept vehicle-segment check because the
	# car/bus body collider alone does not reliably catch shoulder-height shots.
	# Compare the SAME first hit distance; do not draw a ring behind the vehicle.
	var vehicle: Dictionary = Bullet.vehicle_on_path(origin, end)
	if not vehicle.is_empty():
		var car_point: Vector3 = vehicle.pos
		if not has_impact or origin.distance_to(car_point) <= origin.distance_to(point) + 0.01:
			point = car_point
			has_impact = true

	# The real shot includes small random spread and speed/lifetime variation.
	# A preview is an estimate, not a guarantee, and must never confirm damage.
	return {
		"state": "blocked" if has_impact else "range",
		"point": point,
		"origin": origin,
		"target": null,
		"can_explode": has_impact,
		"blast_radius": maxf(radius, 0.0) if has_impact else 0.0
	}
