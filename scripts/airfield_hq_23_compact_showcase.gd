extends Node3D
class_name AirfieldHQ23CompactShowcase
## Runtime driver for the compact, derived HQ 2.3 hangar.

@onready var lod0: Node3D = $Airfield_HQ_23_Compact_LOD0
@onready var lod1: Node3D = $Airfield_HQ_23_Compact_LOD1
@onready var lod2: Node3D = $Airfield_HQ_23_Compact_LOD2
@onready var left_collision: Node3D = $GameplayCollisions/LeftDoorCollision
@onready var right_collision: Node3D = $GameplayCollisions/RightDoorCollision

const LOD0_END := 70.0
const LOD1_END := 125.0
const DOOR_CLOSED_X := 3.75
const DOOR_OPEN_X := 11.25
var _door_tweens: Dictionary = {}
var _tower_door_closed_y := 0.0

func _ready() -> void:
	set_process(true)
	# Run after the nested glTF AnimationPlayer so this retargeted pose is the
	# final transform for the frame instead of being overwritten by its source
	# track earlier in the idle process cycle.
	process_priority = 100
	_set_range(lod0, 0.0, LOD0_END)
	_set_range(lod1, LOD0_END, LOD1_END)
	_set_range(lod2, LOD1_END, 0.0)
	_set_door_collisions(false)
	var tower_collision := $GameplayCollisions/TowerDoorCollision as Node3D
	_tower_door_closed_y = tower_collision.rotation.y
	var motion_root := get_node_or_null("HQ22 Approved Tower Motion Details")
	var wind_player := motion_root.get_node_or_null("HQ22 Wind Sock Loop") as AnimationPlayer if motion_root != null else null
	if wind_player != null and wind_player.has_animation("Wind_Sock_Gust"):
		wind_player.play("Wind_Sock_Gust")

func _process(_delta: float) -> void:
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
