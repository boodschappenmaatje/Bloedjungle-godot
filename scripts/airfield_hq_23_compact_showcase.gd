extends Node3D
class_name AirfieldHQ23CompactShowcase
## Runtime driver for the compact, derived HQ 2.3 hangar.

@onready var lod0: Node3D = $Airfield_HQ_23_Compact_LOD0
@onready var lod1: Node3D = $Airfield_HQ_23_Compact_LOD1
@onready var lod2: Node3D = $Airfield_HQ_23_Compact_LOD2
@onready var left_collision: Node3D = $GameplayCollisions/LeftDoorCollision
@onready var right_collision: Node3D = $GameplayCollisions/RightDoorCollision

# LOD0 keeps the modelled corrugation only for close views. Beyond ~32 m the
# ridges are thinner than a screen pixel (moire/flicker on iPhone), so the
# LOD1/LOD2 shell uses filtered shading normals (see _filter_corrugation_normals).
const LOD0_END := 32.0
const LOD1_END := 125.0
const CORRUGATED_MATERIALS := ["USAAF olive drab painted steel", "Weathered galvanized steel"]
const NORMAL_FILTER_CELL_M := 1.2
const DOOR_CLOSED_X := 3.75
const DOOR_OPEN_X := 11.25
var _door_tweens: Dictionary = {}
var _tower_door_closed_y := 0.0

# Hangar gameplay (showcase-local metres; the hangar floor centre is the origin, doors at z = +9.775).
const HANGAR_WALL_BODIES := ["LeftHangarWallCollision", "RightHangarWallCollision", "RearHangarWallCollision", "LeftHangarDoorJambCollision", "RightHangarDoorJambCollision", "LeftDoorCollision", "RightDoorCollision"]
const ROOF_MIN_Y := 5.3            # triangles of the hangar shell above this height belong to the roof
const INSIDE_HALF := Vector2(10.2, 9.6)   # standing inside the walls: roof fades away
const INSIDE_MARGIN := 1.5         # hysteresis so the roof does not flicker on the threshold
const DOOR_APPROACH_X := 9.5
const DOOR_APPROACH_Z := Vector2(9.0, 17.0)  # in front of the doors: they slide open
const PROXIMITY_STEP_S := 0.15
const ROOF_FADE_S := 0.45
var _roof_nodes: Array[MeshInstance3D] = []
var _roof_hidden := false
var _roof_tween: Tween
var _doors_open := false
var _proximity_clock := 0.0

func _ready() -> void:
	set_process(true)
	# Run after the nested glTF AnimationPlayer so this retargeted pose is the
	# final transform for the frame instead of being overwritten by its source
	# track earlier in the idle process cycle.
	process_priority = 100
	_make_hangar_walls_solid()
	for lod in [lod0, lod1, lod2]:
		_split_roof(lod)
	_set_range(lod0, 0.0, LOD0_END)
	_set_range(lod1, LOD0_END, LOD1_END)
	_set_range(lod2, LOD1_END, 0.0)
	_filter_corrugation_normals(lod1)
	_filter_corrugation_normals(lod2)
	_set_door_collisions(false)
	var tower_collision := $GameplayCollisions/TowerDoorCollision as Node3D
	_tower_door_closed_y = tower_collision.rotation.y
	var motion_root := get_node_or_null("HQ22 Approved Tower Motion Details")
	var wind_player := motion_root.get_node_or_null("HQ22 Wind Sock Loop") as AnimationPlayer if motion_root != null else null
	if wind_player != null and wind_player.has_animation("Wind_Sock_Gust"):
		wind_player.play("Wind_Sock_Gust")

func _process(delta: float) -> void:
	_proximity_clock += delta
	if _proximity_clock >= PROXIMITY_STEP_S:
		_proximity_clock = 0.0
		_update_hangar_proximity()
	# The source glTF clip is nested under the placed BuildingBody. Keep the exact
	# HQ2.2 quaternion keys, but explicitly apply its tower-door rotation track to
	# the retargeted compact detail so the animation also evaluates in this nested
	# runtime scene.
	var motion_root := get_node_or_null("HQ22 Approved Tower Motion Details")
	if motion_root == null:
		return
	for player in _animation_players(motion_root):
		if not player.is_playing() or player.current_animation != "Open_Tower_Door":
			continue
		var animation := player.get_animation("Open_Tower_Door")
		var animation_root := player.get_node_or_null(player.root_node)
		if animation_root == null:
			continue
		for track in animation.get_track_count():
			if animation.track_get_type(track) != Animation.TYPE_ROTATION_3D:
				continue
			var target := animation_root.get_node_or_null(animation.track_get_path(track)) as Node3D
			if target == null or target.name != "Tower access door | animated":
				continue
			var pose := animation.rotation_track_interpolate(track, player.current_animation_position)
			target.quaternion = pose
			break

func _set_range(root_node: Node, begin: float, end: float) -> void:
	for mesh in root_node.find_children("*", "MeshInstance3D", true, false):
		mesh.visibility_range_begin = begin
		mesh.visibility_range_end = end
		mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED

## Geometric corrugation on the distant hangar shell aliases into moire: each
## ridge alternates lit/unlit faces faster than the pixel grid. Replace the
## shading normals of the corrugated sheet surfaces by their ~1 m neighbourhood
## average (the sheet's macro orientation). Geometry, UVs and the PBR normal map
## stay unchanged, so the filtered corrugation texture still reads at distance.
static func _filter_corrugation_normals(root_node: Node) -> void:
	var filtered := {}
	for node in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var source := mesh_instance.mesh as ArrayMesh
		if source == null or not mesh_instance.visible or source.get_blend_shape_count() > 0:
			continue
		if filtered.has(source):
			mesh_instance.mesh = filtered[source]
			continue
		var touched := false
		var result := ArrayMesh.new()
		for surface in source.get_surface_count():
			var material := source.surface_get_material(surface)
			var arrays := source.surface_get_arrays(surface)
			if material != null and CORRUGATED_MATERIALS.has(String(material.resource_name)):
				_average_normals(arrays)
				touched = true
			result.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays)
			result.surface_set_material(surface, material)
			result.surface_set_name(surface, source.surface_get_name(surface))
		if not touched:
			filtered[source] = source
			continue
		result.resource_name = source.resource_name
		result.shadow_mesh = source.shadow_mesh
		filtered[source] = result
		mesh_instance.mesh = result

static func _average_normals(arrays: Array) -> void:
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	if positions.is_empty() or normals.size() != positions.size():
		return
	var sums := {}
	var keys := PackedInt64Array()
	keys.resize(positions.size())
	for i in positions.size():
		var p := positions[i] / NORMAL_FILTER_CELL_M
		var key := (int(floor(p.x)) + 4096) | ((int(floor(p.y)) + 4096) << 16) | ((int(floor(p.z)) + 4096) << 32)
		keys[i] = key
		sums[key] = sums.get(key, Vector3.ZERO) + normals[i]
	for i in normals.size():
		var averaged: Vector3 = sums[keys[i]]
		if averaged.length_squared() > 0.0001:
			normals[i] = averaged.normalized()
	arrays[Mesh.ARRAY_NORMAL] = normals
	var tangents = arrays[Mesh.ARRAY_TANGENT]
	if tangents is PackedFloat32Array and (tangents as PackedFloat32Array).size() == normals.size() * 4:
		var t := tangents as PackedFloat32Array
		for i in normals.size():
			var n := normals[i]
			var tangent := Vector3(t[i * 4], t[i * 4 + 1], t[i * 4 + 2])
			tangent = (tangent - n * n.dot(tangent))
			if tangent.length_squared() < 0.000001:
				continue
			tangent = tangent.normalized()
			t[i * 4] = tangent.x
			t[i * 4 + 1] = tangent.y
			t[i * 4 + 2] = tangent.z
		arrays[Mesh.ARRAY_TANGENT] = t

## The scene's hangar wall, jamb and door boxes were left on the default physics layer 1
## (ground), which the player and vehicles never collide with horizontally: you walked
## through the closed hangar. Put them on the wall layer like every other building.
func _make_hangar_walls_solid() -> void:
	for body_name in HANGAR_WALL_BODIES:
		var body := get_node_or_null("GameplayCollisions/" + body_name) as CollisionObject3D
		if body != null:
			body.collision_layer = Kit.LAYER_WALL
			body.collision_mask = 0

## Splits the hangar shell mesh into walls (kept) and roof (a separate MeshInstance3D that
## fades out when you stand inside). Runs on a copy: the imported shared mesh is untouched.
func _split_roof(lod: Node3D) -> void:
	for node in lod.find_children("Hangar HQ 22*", "MeshInstance3D", true, false):
		var shell := node as MeshInstance3D
		var source := shell.mesh as ArrayMesh
		if source == null or source.get_blend_shape_count() > 0:
			continue
		var to_local := global_transform.affine_inverse() * shell.global_transform
		var row := Vector3(to_local.basis.x.y, to_local.basis.y.y, to_local.basis.z.y)
		var walls := ArrayMesh.new()
		var roof := ArrayMesh.new()
		for surface in source.get_surface_count():
			if source.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var arrays := source.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				continue
			var wall_indices := PackedInt32Array()
			var roof_indices := PackedInt32Array()
			for t in range(0, indices.size() - 2, 3):
				var a := indices[t]
				var b := indices[t + 1]
				var c := indices[t + 2]
				var y := (row.dot(vertices[a]) + row.dot(vertices[b]) + row.dot(vertices[c])) / 3.0 + to_local.origin.y
				var target := roof_indices if y > ROOF_MIN_Y else wall_indices
				target.append(a)
				target.append(b)
				target.append(c)
			var material := source.surface_get_material(surface)
			for pair in [[walls, wall_indices], [roof, roof_indices]]:
				var part: ArrayMesh = pair[0]
				var part_indices: PackedInt32Array = pair[1]
				if part_indices.is_empty():
					continue
				arrays[Mesh.ARRAY_INDEX] = part_indices
				part.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				part.surface_set_material(part.get_surface_count() - 1, material)
		if roof.get_surface_count() == 0:
			continue
		shell.mesh = walls
		var roof_node := MeshInstance3D.new()
		roof_node.name = "Hangar HQ 22 roof (fades indoors)"
		roof_node.mesh = roof
		roof_node.transform = shell.transform
		roof_node.cast_shadow = shell.cast_shadow
		shell.get_parent().add_child(roof_node)
		_roof_nodes.append(roof_node)

func _update_hangar_proximity() -> void:
	var near_door := false
	var inside := false
	var watchers: Array = [Game.player]
	watchers.append_array(get_tree().get_nodes_in_group("voertuigen"))
	for who in watchers:
		var body := who as Node3D
		if body == null or not is_instance_valid(body):
			continue
		var p := to_local(body.global_position)
		if absf(p.x) < INSIDE_HALF.x and absf(p.z) < INSIDE_HALF.y:
			near_door = true  # never close the doors on someone standing inside
		elif absf(p.x) < DOOR_APPROACH_X and p.z > DOOR_APPROACH_Z.x and p.z < DOOR_APPROACH_Z.y:
			near_door = true
		if who == Game.player:
			var margin := INSIDE_MARGIN if _roof_hidden else 0.0
			inside = absf(p.x) < INSIDE_HALF.x + margin and absf(p.z) < INSIDE_HALF.y + margin and p.y < ROOF_MIN_Y
	if near_door != _doors_open:
		_doors_open = near_door
		for side in [&"left", &"right"]:
			if near_door:
				open_door(side)
			else:
				close_door(side)
	if inside != _roof_hidden:
		_set_roof_hidden(inside)

func _set_roof_hidden(hidden_now: bool) -> void:
	_roof_hidden = hidden_now
	if _roof_tween != null:
		_roof_tween.kill()
	if _roof_nodes.is_empty():
		return
	for roof in _roof_nodes:
		if not hidden_now:
			roof.visible = true
	_roof_tween = create_tween().set_parallel(true)
	for roof in _roof_nodes:
		_roof_tween.tween_property(roof, "transparency", 1.0 if hidden_now else 0.0, ROOF_FADE_S)
	if hidden_now:
		_roof_tween.chain().tween_callback(_hide_roof_nodes)

func _hide_roof_nodes() -> void:
	if _roof_hidden:
		for roof in _roof_nodes:
			roof.visible = false

func set_workshop_lights_enabled(enabled: bool) -> void:
	## A local, reversible toggle used by the paired visual comparison.
	for node in lod0.find_children("*", "OmniLight3D", true, false):
		if node.name.begins_with(AirfieldHQ23.UNWANTED_WORKSHOP_LIGHT_PREFIX):
			node.visible = enabled

func open_door(side: StringName) -> void:
	_toggle_door(side, true)

func close_door(side: StringName) -> void:
	_toggle_door(side, false)

func _set_door_collisions(opening: bool) -> void:
	left_collision.position.x = -DOOR_OPEN_X if opening else -DOOR_CLOSED_X
	right_collision.position.x = DOOR_OPEN_X if opening else DOOR_CLOSED_X

func _toggle_door(side: StringName, opening: bool) -> void:
	var label := "Left" if side == &"left" else "Right"
	var animation_name := "Open_%s_Door" % label
	var collision: Node3D = left_collision if side == &"left" else right_collision
	var sign := -1.0 if side == &"left" else 1.0
	var destination_x := sign * (DOOR_OPEN_X if opening else DOOR_CLOSED_X)
	for player in _animation_players(lod0):
		if not player.has_animation(animation_name):
			continue
		if opening:
			player.speed_scale = 1.0
			player.play(animation_name)
		else:
			player.play(animation_name)
			player.seek(player.get_animation(animation_name).length, true)
			player.speed_scale = -1.0
	var key := String(side)
	if _door_tweens.has(key):
		_door_tweens[key].kill()
	var tween := create_tween()
	tween.tween_property(collision, "position:x", destination_x, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_door_tweens[key] = tween

func open_tower_door() -> void:
	_set_legacy_tower_door(true)

func close_tower_door() -> void:
	_set_legacy_tower_door(false)

func _set_legacy_tower_door(opening: bool) -> void:
	var motion_root := get_node_or_null("HQ22 Approved Tower Motion Details")
	for player in _animation_players(motion_root):
		if player.has_animation("Open_Tower_Door"):
			player.speed_scale = 1.0
			player.play("Open_Tower_Door")
			if not opening:
				player.seek(player.get_animation("Open_Tower_Door").length, true)
				player.speed_scale = -1.0
	var collision := $GameplayCollisions/TowerDoorCollision as Node3D
	if _door_tweens.has("tower"):
		_door_tweens["tower"].kill()
	var tween := create_tween()
	tween.tween_property(collision, "rotation:y", _tower_door_closed_y + (deg_to_rad(95.0) if opening else 0.0), 1.2)
	_door_tweens["tower"] = tween

func _animation_players(root_node: Node) -> Array[AnimationPlayer]:
	var found: Array[AnimationPlayer] = []
	if root_node == null:
		return found
	if root_node is AnimationPlayer:
		found.append(root_node)
	for child in root_node.find_children("*", "AnimationPlayer", true, false):
		found.append(child)
	return found
