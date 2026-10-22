extends SceneTree
## Meet in een headless draai hoeveel CPU-tijd het aanmaken van vijanden kost (zonder tekenen: de GPU doet niet mee).
## Draaien: godot --headless --path . -s tools/meet_spawn.gd
## Let op: dit meet alleen het opbouwen van modellen, scripts en botsvormen. Het tekenen op een telefoon meet je met de prestatiemodus.

var main: Node
var f := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	f += 1
	if f == 3:
		main.begin()
	if f == 10:
		var scene: PackedScene = load("res://scenes/enemy.tscn")
		for kind in ["knife", "rifle", "rocket", "heavy"]:
			var times := []
			for i in 8:
				var t0 := Time.get_ticks_usec()
				var e: Node = scene.instantiate()
				e.call("setup", kind, 1)
				e.position = Vector3(40 + i, 0, 40)
				main.add_child(e)
				times.append(float(Time.get_ticks_usec() - t0) / 1000.0)
			var sum := 0.0
			for v in times:
				sum += v
			print("%-7s eerste %.1f ms · volgende gemiddeld %.1f ms · slechtste %.1f ms" % [kind, times[0], (sum - times[0]) / 7.0, times.max()])
		# een hele golf in één beeld
		var t1 := Time.get_ticks_usec()
		for i in 12:
			var e2: Node = scene.instantiate()
			e2.call("setup", "rifle", 1)
			e2.position = Vector3(-40 - i, 0, 40)
			main.add_child(e2)
		print("12 schutters in één beeld: %.1f ms (bij 60 fps is een beeld 16,7 ms)" % (float(Time.get_ticks_usec() - t1) / 1000.0))
		quit()
	return false
