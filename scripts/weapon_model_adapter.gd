extends Node3D
## Scheidt het zichtbare wapen en benoemde grip/effectpunten van speler- en combatlogica.

const DEFAULT_WEAPONS := preload("res://assets/wapens.glb")
const PROFILE_SCRIPT := preload("res://scripts/weapon_model_profile.gd")

var profile: Resource
var weapon: Node3D
var right_hand_grip: Marker3D
var left_hand_grip: Marker3D
var muzzle: Marker3D
var casing_eject: Marker3D
var magazine: Marker3D
var sight: Marker3D
var ejection: Marker3D
var animation_player: AnimationPlayer


func configure(visual_name: String, profile_: Resource = null) -> bool:
	profile = profile_ if profile_ != null else _default_profile(visual_name)
	position = profile.mount_position
	rotation = profile.mount_rotation
	var source_scene: PackedScene = profile.model_scene if profile.model_scene is PackedScene else DEFAULT_WEAPONS
	var selected_name := String(profile.model_node) if String(profile.model_node) != "" else visual_name
	var holder := source_scene.instantiate()
	var selected := holder.find_child(selected_name, true, false) as Node3D
	if selected == null:
		holder.free()
		return false
	selected.get_parent().remove_child(selected)
	selected.owner = null
	selected.name = selected_name + "Mesh"
	selected.transform = Transform3D.IDENTITY
	selected.scale = profile.model_scale
	add_child(selected)
	weapon = selected
	animation_player = _weapon_animation_player(holder, selected, selected_name)
	if animation_player != null:
		weapon.add_child(animation_player)
	holder.free()
	right_hand_grip = _marker("RightHandGrip", Vector3.ZERO)
	left_hand_grip = _marker("LeftHandGrip", profile.left_hand_grip)
	muzzle = _marker("Muzzle", profile.muzzle_local)
	casing_eject = _marker("CasingEject", profile.casing_local)
	magazine = _marker("Magazine", profile.magazine_local)
	sight = _marker("Sight", profile.sight_local)
	ejection = _marker("Ejection", profile.ejection_local)
	return true


func _marker(marker_name: String, at: Vector3) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = marker_name
	marker.position = at
	weapon.add_child(marker)
	return marker


func _default_profile(visual_name: String) -> Resource:
	var result: Resource = PROFILE_SCRIPT.new()
	result.model_node = StringName(visual_name)
	result.model_scene = DEFAULT_WEAPONS
	# Model-specific values can be stored as .tres profiles without changing the controller.
	var left_grips := {
		"M1911": Vector3(-0.02, -0.01, -0.07), "Thompson": Vector3(-0.03, 0.0, -0.28),
		"Garand": Vector3(-0.06, -0.02, -0.35), "Trench": Vector3(-0.04, -0.02, -0.31),
		"MG42": Vector3(-0.06, -0.01, -0.34), "Bazooka": Vector3(-0.08, -0.04, -0.40),
	}
	result.left_hand_grip = left_grips.get(visual_name, result.left_hand_grip)
	return result


func _weapon_animation_player(holder: Node, gun: Node3D, gun_name: String) -> AnimationPlayer:
	var src := holder.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if src == null:
		return null
	var lib := AnimationLibrary.new()
	for clip in src.get_animation_list():
		if not String(clip).begins_with(gun_name + "_"):
			continue
		var animation := src.get_animation(clip).duplicate() as Animation
		for track in range(animation.get_track_count() - 1, -1, -1):
			var path := String(animation.track_get_path(track))
			if path == gun_name:
				# The merged weapon root becomes the AnimationPlayer root in Godot.
				animation.track_set_path(track, NodePath("."))
			elif path.begins_with(gun_name + "/"):
				animation.track_set_path(track, NodePath(path.substr(gun_name.length() + 1)))
			elif not path.begins_with(gun_name + "_") and path != gun_name:
				animation.remove_track(track)
		animation.loop_mode = Animation.LOOP_LINEAR if String(clip).ends_with("_rust") else Animation.LOOP_NONE
		lib.add_animation(String(clip).trim_prefix(gun_name + "_"), animation)
	if lib.get_animation_list().is_empty():
		return null
	var player := AnimationPlayer.new()
	player.name = "WeaponActionClips"
	player.root_node = NodePath("..")
	player.add_animation_library("", lib)
	return player
