extends Node

const Recruit = preload("res://ally.gd")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var player := Node3D.new()
	add_child(player)
	get_tree().root.get_node("Game").player = player
	var ally: CharacterBody3D = Recruit.new()
	add_child(ally)
	ally.setup(100.0, 16.0, 0)
	_check(ally.model != null, "barracks recruit initializes its soldier model")
	_check(ally._goal().distance_to(player.global_position) > 0.0, "new recruit receives its initial follow goal")
	ally.free()
	player.free()
	print("BARRACKS_RECRUIT_SCRIPT_TESTS: 2 checks passed")
	get_tree().quit()

func _check(ok: bool, label: String) -> void:
	if not ok:
		push_error(label)
		get_tree().quit(1)
