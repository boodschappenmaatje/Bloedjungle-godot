class_name SoldierModel
extends Node3D

func setup(_color: Color, _weapon: String) -> void:
	pass

func set_shoot_pose(_enabled: bool, _weapon: String, _amount: float) -> void:
	pass

func shoot_recoil(_weapon: String) -> void:
	pass

func muzzle_position() -> Vector3:
	return Vector3.ZERO

func casing_axes() -> Array:
	return [Vector3.RIGHT, Vector3.FORWARD]

func casing_position() -> Vector3:
	return Vector3.ZERO

func play(_animation: String, _blend: float = 0.18, _speed: float = 1.0) -> void:
	pass
