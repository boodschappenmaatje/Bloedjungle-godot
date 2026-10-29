extends Node3D

const GLB_PATH := "res://assets/apache_showcase/Apache_Showcase_Mobile.glb"
const CLIPS := ["Grond", "Opstijgen", "Zweven", "Vliegen", "Bocht"]
var _player: AnimationPlayer

func _ready() -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var err := document.append_from_file(GLB_PATH, state)
	if err != OK:
		push_error("Could not load Apache showcase GLB: %s" % error_string(err))
		return
	var model := document.generate_scene(state)
	if model == null:
		push_error("Could not create Apache showcase scene")
		return
	add_child(model)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		push_error("Apache showcase GLB has no imported AnimationPlayer")
		return
	_player = players[0] as AnimationPlayer
	if _player.has_animation("Grond"):
		_player.play("Grond")

func _unhandled_key_input(event: InputEvent) -> void:
	if _player == null or not event is InputEventKey or not event.pressed or event.echo:
		return
	var idx := -1
	match event.keycode:
		KEY_1: idx = 0
		KEY_2: idx = 1
		KEY_3: idx = 2
		KEY_4: idx = 3
		KEY_5: idx = 4
	if idx >= 0 and idx < CLIPS.size() and _player.has_animation(CLIPS[idx]):
		_player.play(CLIPS[idx])
