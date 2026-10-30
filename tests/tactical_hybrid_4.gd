extends Node3D
## Speelbare camerascène: open deze scène in Godot en kies Run Current Scene.

const TANK := preload("res://scenes/tank.tscn")
const ENEMY := preload("res://scenes/enemy.tscn")


func _enter_tree() -> void:
	GameSettings.get_value("soldaat")
	GameSettings.values["soldaat"] = "meshy"  # Alleen in dit proces; verander de bewaarde iPhone-instelling niet.


func _ready() -> void:
	await $Main.begin()
	for menu in get_tree().get_nodes_in_group("menus"):
		menu._show("")
	Game.prep_t = 60.0
	var player := Game.player as Node3D
	Game.aim = PI
	var tank := TANK.instantiate() as Node3D
	tank.position = player.position + Vector3(6.0, 0.0, 2.0)
	$Main.add_child(tank)
	for i in 2:
		var ally := Ally.new()
		ally.setup(100.0, 16.0, i)
		ally.position = player.position + Vector3(-4.0 - i * 3.0, 0.0, -2.0 - i * 2.0)
		$Main.add_child(ally)
		ally.set_physics_process(false)
		Game.allies.append(ally)
	for i in 3:
		var enemy := ENEMY.instantiate()
		enemy.setup("rifle", 1)
		var enemy_x: float = [-7.0, 0.0, 8.0][i]
		var enemy_z: float = [-13.0, -16.0, -18.0][i]
		enemy.position = player.position + Vector3(enemy_x, 0.0, enemy_z)
		$Main.add_child(enemy)
		enemy.set_physics_process(false)
	Game.changed.emit()
