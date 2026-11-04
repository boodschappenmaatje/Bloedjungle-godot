class_name BaseWallRules
## Ground-level line of sight through the 3 m own-base wall and closed gates.
## Overhead artillery keeps its separate area-damage rule in artillerie.gd.

static func blocks_blast(origin: Vector3, target: Vector3) -> bool:
	var world := _world()
	if world == null:
		return false
	var start := origin + Vector3.UP * 0.15
	var finish := target + Vector3.UP * 0.9
	if start.distance_squared_to(finish) < 0.01:
		return false
	var query := PhysicsRayQueryParameters3D.create(start, finish, Kit.LAYER_FORTIFICATION)
	query.collide_with_areas = false
	query.hit_from_inside = true
	return not world.direct_space_state.intersect_ray(query).is_empty()


## Ground shooters keep a horizontal sight line below the wall top, even when
## aiming at an elevated target. Elevated tower weapons retain their normal LOS.
static func blocks_ground_fire(origin: Vector3, target: Vector3) -> bool:
	if origin.y >= Data.BASE_WALL_H:
		return false
	var world := _world()
	if world == null:
		return false
	var height := clampf(origin.y, 0.1, Data.BASE_WALL_H - 0.1)
	var start := Vector3(origin.x, height, origin.z)
	var finish := Vector3(target.x, height, target.z)
	if start.distance_squared_to(finish) < 0.01:
		return false
	var query := PhysicsRayQueryParameters3D.create(start, finish, Kit.LAYER_FORTIFICATION)
	query.collide_with_areas = false
	query.hit_from_inside = true
	return not world.direct_space_state.intersect_ray(query).is_empty()


static func _world() -> World3D:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	if is_instance_valid(Game.player) and Game.player.is_inside_tree():
		return Game.player.get_world_3d()
	if is_instance_valid(Game.gates) and Game.gates.is_inside_tree():
		return Game.gates.get_world_3d()
	if tree.current_scene is Node3D:
		return (tree.current_scene as Node3D).get_world_3d()
	return null
