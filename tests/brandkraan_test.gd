extends SceneTree
## Test: brandkraan (spuit na kogels, na een ontploffing en als een voertuig erover rijdt) en lantaarns (branden bij avond).
## Draaien: godot --headless --path . -s tests/brandkraan_test.gd --fixed-fps 60

var main: Node
var frames := 0
var Stad
var ks: Array = []
var ls: Array = []
var car: Node3D
var Bk


func _initialize() -> void:
	Stad = load("res://scripts/stad.gd")
	Bk = load("res://scripts/brandkraan.gd")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		main.begin()
	if frames == 10:
		var lines: Array = [["brandkraan", 0, -96, 0, 0], ["brandkraan", 8, -96, 0, 0], ["brandkraan", 16, -96, 0, 0], ["lantaarn", 0, -90, 0, 0], ["lantaarn", 4, -90, 0, 0]]
		Stad.current.set_items(Stad.from_lines(lines))
		for d in Stad.current.items:
			if d.k == "brandkraan":
				ks.append(d.node)
			else:
				ls.append(d.node)
		print("kranen ", ks.size(), " lantaarns ", ls.size(), " alle vlakken: ", ks[0]._water.size(), " waterdelen, animatie ", ks[0]._anim != null)
		print("clips: ", ks[0]._anim.get_animation_list() if ks[0]._anim else [])
	if frames == 20:
		# kogels
		for i in 3:
			ks[0].hit(12.0, Vector3.RIGHT, true)
		print("na 3 kogels spuit: ", ks[0].sprayed, " (verwacht true)")
		# ontploffing 3 m verderop
		Bk.catch_blast(Vector3(8, 0, -94), 3.0)
		print("na ontploffing spuit: ", ks[1].sprayed, " (verwacht true)")
		# voertuig
		car = Node3D.new()
		car.add_to_group("voertuigen")
		var csh := CollisionShape3D.new()
		csh.name = "Shape"
		var bx := BoxShape3D.new()
		bx.size = Vector3(1.7, 1.8, 3.6)
		csh.shape = bx
		car.add_child(csh)
		root.add_child(car)
		car.global_position = Vector3(30, 0, -96)
	if frames == 30:
		print("voertuig ver weg: ", ks[2].sprayed, " (verwacht false)")
		car.global_position = ks[2].global_position + Vector3(0, 0, 4.5)
	if frames == 34:
		print("voertuig op 4,5 m (net buiten): ", ks[2].sprayed, " (verwacht false)")
		car.global_position = ks[2].global_position + Vector3(0, 0, 2.2)   # tegen de kraan aan, zoals een geblokkeerde auto
	if frames == 50:
		print("voertuig eroverheen: ", ks[2].sprayed, " (verwacht true)")
		var playing: String = ks[0]._anim.current_animation if ks[0]._anim else "-"
		print("animatie: ", playing)
	if frames == 330:
		print("animatie na 4,5 s: ", ks[0]._anim.current_animation, " (verwacht Spuiten of Spuiten-loop)")
		# lantaarns: dag uit, avond aan
		ls[0].global_position = root.get_node("Game").player.global_position + Vector3(3, 0, 0)
		GameSettings.set_value("time", "day")
		ls[0]._apply()
		print("dag: licht aan = ", ls[0]._light.visible, " (verwacht false)")
		GameSettings.set_value("time", "night")
		ls[0]._apply()
		print("nacht: licht aan = ", ls[0]._light.visible, ", glas gloeit = ", ls[0]._glass.emission_energy_multiplier, " (verwacht true en 3)")
		GameSettings.set_value("time", "day")
		ks[0].hp = 0
		print("BRANDKRAAN TEST KLAAR")
		quit()
		return true
	return false
