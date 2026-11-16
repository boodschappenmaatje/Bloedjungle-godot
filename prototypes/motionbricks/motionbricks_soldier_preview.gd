extends Node3D
## Isolated target-rig preview. It intentionally plays an existing clip until
## MotionBricks G1 output has a validated retarget mapping for this rig.

const SOURCE_CLIPS := {
	KEY_1: "stil",
	KEY_2: "lopen",
	KEY_3: "rennen",
}

@onready var _soldier: Node3D = $Soldier
@onready var _camera: Camera3D = $Camera3D
@onready var _status: Label = $Overlay/Status

var _animation_player: AnimationPlayer


func _ready() -> void:
	_camera.look_at(Vector3(0.0, 0.95, 0.0), Vector3.UP)
	_animation_player = _soldier.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _animation_player == null:
		_status.text = "PREVIEW FOUT: geen AnimationPlayer in bestaand commando-model"
		push_error(_status.text)
		return
	_play_source_clip("lopen")


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var clip: String = SOURCE_CLIPS.get(event.keycode, "")
	if not clip.is_empty():
		_play_source_clip(clip)


func _play_source_clip(clip: String) -> void:
	if not _animation_player.has_animation(clip):
		_status.text = "PREVIEW FOUT: bestaand clip '%s' ontbreekt" % clip
		push_error(_status.text)
		return
	_animation_player.play(clip)
	_status.text = "Bestaand soldaat_jungle_commando.glb · bronclip: %s · 1 stil / 2 lopen / 3 rennen\nMotionBricks G1 (34 gewrichten) is nog niet geretarget naar dit DEF-skelet (53 botten)." % clip
