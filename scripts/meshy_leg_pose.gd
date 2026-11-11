class_name MeshyLegPose
extends SkeletonModifier3D
## Laat de Meshy-benen de looprichting volgen terwijl borst en wapen blijven richten.

const TURN_RATE := 11.0

var leg_yaw := 0.0
var _current_yaw := 0.0
var _skel: Skeleton3D
var _hips := -1
var _spine: Array[int] = []

func setup_skeleton(skel: Skeleton3D) -> void:
	_skel = skel
	_hips = skel.find_bone("mixamorig_Hips")
	_spine.clear()
	for bone in ["mixamorig_Spine", "mixamorig_Spine1", "mixamorig_Spine2"]:
		_spine.append(skel.find_bone(bone))

func _process(delta: float) -> void:
	_current_yaw = move_toward(_current_yaw, leg_yaw, TURN_RATE * delta)

func _rotate_bone(bone: int, angle: float) -> void:
	if bone < 0 or absf(angle) < 0.0001:
		return
	var pose := _skel.get_bone_global_pose(bone)
	pose.basis = Basis(Vector3.UP, angle) * pose.basis
	_skel.set_bone_global_pose(bone, pose)

func _process_modification() -> void:
	if _skel == null or _hips < 0 or absf(_current_yaw) < 0.001:
		return
	_rotate_bone(_hips, _current_yaw)
	for i in _spine.size():
		_rotate_bone(_spine[i], -_current_yaw * [0.4, 0.3, 0.3][i])
