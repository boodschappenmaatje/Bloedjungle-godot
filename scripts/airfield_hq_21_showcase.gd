extends Node3D
class_name AirfieldHQ21Showcase
## Isolated 2.1 preview; does not replace the production Airfield HQ 2.0 scene.
## Camera far plane is 170 m in scenes/main.tscn, so LOD ranges fit the actual game.

@onready var lod0: Node3D = $Airfield_HQ_21_LOD0
@onready var lod1: Node3D = $Airfield_HQ_21_LOD1
@onready var lod2: Node3D = $Airfield_HQ_LOD2
@onready var left_collision: Node3D = $GameplayCollisions/LeftDoorCollision
@onready var right_collision: Node3D = $GameplayCollisions/RightDoorCollision

const LOD0_END := 52.0
const LOD1_END := 122.0
var _door_tweens: Dictionary = {}

func _ready() -> void:
	_set_range(lod0, 0.0, LOD0_END)
	_set_range(lod1, LOD0_END, LOD1_END)
	_set_range(lod2, LOD1_END, 0.0)

func _set_range(root_node: Node, begin: float, end: float) -> void:
	for mesh in _mesh_instances(root_node):
		mesh.visibility_range_begin = begin
		mesh.visibility_range_end = end
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
	for player in _animation_players(lod0):
		if not player.has_animation(animation_name): continue
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
