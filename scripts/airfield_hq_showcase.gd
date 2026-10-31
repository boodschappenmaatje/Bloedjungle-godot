extends Node3D
class_name AirfieldHQShowcase
## Isolated preview scene: runtime models and collision proxies stay out of the
## core gameplay scene until visual approval. Mesh LOD switches at 480 m.

@onready var lod0: Node3D = $Airfield_HQ_2
@onready var lod1: Node3D = $Airfield_HQ_LOD1
@onready var left_collision: Node3D = $GameplayCollisions/LeftDoorCollision
@onready var right_collision: Node3D = $GameplayCollisions/RightDoorCollision

var _door_tweens: Dictionary = {}

func _ready() -> void:
	for mesh in _mesh_instances(lod0):
		mesh.visibility_range_begin = 0.0
		mesh.visibility_range_end = 500.0
		mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	for mesh in _mesh_instances(lod1):
		mesh.visibility_range_begin = 480.0
		mesh.visibility_range_end = 0.0
		mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED

func open_door(side: StringName) -> void:
	_toggle_door(side, true)

func close_door(side: StringName) -> void:
	_toggle_door(side, false)

func _toggle_door(side: StringName, opening: bool) -> void:
	var label := "Left" if side == &"left" else "Right"
	var animation_name := "Open_%s_Door" % label
	var collision: Node3D = left_collision if side == &"left" else right_collision
	var destination_x := (-31.4 if side == &"left" else 31.4) if opening else (-10.2 if side == &"left" else 10.2)
	for player in _animation_players(lod0) + _animation_players(lod1):
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
	if _door_tweens.has(key): _door_tweens[key].kill()
	var tween := create_tween()
	tween.tween_property(collision, "position:x", destination_x, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_door_tweens[key] = tween

func _mesh_instances(root_node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for child in root_node.find_children("*", "MeshInstance3D", true, false): found.append(child)
	return found

func _animation_players(root_node: Node) -> Array[AnimationPlayer]:
	var found: Array[AnimationPlayer] = []
	if root_node is AnimationPlayer: found.append(root_node)
	for child in root_node.find_children("*", "AnimationPlayer", true, false): found.append(child)
	return found
