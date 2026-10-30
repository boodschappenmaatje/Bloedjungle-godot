extends Node3D
## Speelbaar gevecht buiten de bunker: Run Current Scene. Echte AI, tank, speler en HUD.

const TANK := preload("res://scenes/tank.tscn")
const ENEMY := preload("res://scenes/enemy.tscn")


func _enter_tree() -> void:
	GameSettings.get_value("soldaat")
	GameSettings.values["soldaat"] = "meshy"  # Alleen in dit proces; verander de bewaarde iPhone-instelling niet.


func _ready() -> void:
	await $Main.begin()
	for menu in get_tree().get_nodes_in_group("menus"):
		menu._show("")
	Game.state = "play"
	Game.routes.clear()
	$Main.queue.clear()
	$Main.clear_t = INF  # deze handmatig geplaatste gevechtsgroep sluit geen golf af
	var player := Game.player as Node3D
	player.position = Vector3(0.0, 0.0, -52.0)
	player.face = PI
	player.rotation.y = PI
	var tank := TANK.instantiate() as Node3D
	tank.position = player.position + Vector3(-7.0, 0.0, -2.0)
	$Main.add_child(tank)
	tank.set_physics_process(false)
	for i in 2:
		var ally := Ally.new()
		ally.setup(100.0, 16.0, i)
		ally.position = player.position + Vector3(3.0 + i * 2.5, 0.0, -1.0 - i * 2.0)
		$Main.add_child(ally)
		ally.set_physics_process(false)
		Game.allies.append(ally)
	for i in 4:
		var enemy := ENEMY.instantiate()
		enemy.setup("rifle", 1)
		var enemy_x: float = [-8.0, -2.0, 5.0, 10.0][i]
		var enemy_z: float = [-17.0, -20.0, -18.0, -22.0][i]
		enemy.position = player.position + Vector3(enemy_x, 0.0, enemy_z)
		$Main.add_child(enemy)
	Game.changed.emit()
