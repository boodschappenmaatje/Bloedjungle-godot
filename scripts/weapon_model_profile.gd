extends Resource
## Visuele afstemming van een wapen op de Meshy/Mixamo-speler. Gameplaywaarden blijven in Data.WEAPONS.

@export var model_node: StringName
@export var model_scene: PackedScene
@export var mount_position := Vector3(-0.14, 1.42, 0.05)
@export var mount_rotation := Vector3(0.0, PI, 0.0)
@export var model_scale := Vector3.ONE
@export var left_hand_grip := Vector3(-0.06, -0.02, -0.35)
@export var muzzle_local := Vector3(0.0, 0.07, -1.08)
@export var casing_local := Vector3(0.035, 0.11, -0.16)
@export var magazine_local := Vector3(-0.035, -0.10, -0.34)
@export var sight_local := Vector3(0.0, 0.11, -0.53)
@export var ejection_local := Vector3(0.055, 0.11, -0.18)
