extends SceneTree
## Test: een granaat die je in een gebouw gooit blijft in dat gebouw (grondvlak, vloer en dak), in alle richtingen en ook boven.
## Draaien: godot --headless --path . -s tests/granaat_test.gd --fixed-fps 60

var main: Node
var frames := 0
var tracked: Array = []   # [granaat, huis, laag]
var fouten := 0
var worpen := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(_check)


func _check() -> void:
	for t in tracked:
		var g = t[0]
		if not is_instance_valid(g) or g.is_queued_for_deletion():
			continue
		var h = t[1]
		var lp: Vector3 = h.to_local(g.global_position)
		if not h._in_foot(lp, 0.05):
			fouten += 1
			print("BUITEN: ", h.spec.get("name", h.name), " laag ", t[2], " lp=", lp)
			t[0] = null
		elif lp.y < -0.01:
			fouten += 1
			print("DOOR DE VLOER: ", h.name, " laag ", t[2], " y=", lp.y)
			t[0] = null


func _process(_d: float) -> bool:
	frames += 1
	var game = root.get_node("Game")
	var t := frames - 3
	if t == 0:
		main.begin()
	if t == 20:
		for kind in ["woonhuis", "winkel", "kerk", "benzine", "hotel"]:
			var hs := get_nodes_in_group(kind)
			if hs.is_empty():
				print(kind, ": NIET GEVONDEN")
				fouten += 1
				continue
			var h = hs[0]
			for laag in mini(h.levels.size(), 3):
				for pos in [Vector3(0, 0, 0), Vector3(h.spec.hx * 0.7, 0, h.spec.hz * 0.6), Vector3(-h.spec.hx * 0.7, 0, -h.spec.hz * 0.6)]:
					var lp: Vector3 = pos + Vector3(0, float(h.levels[laag]) + 0.05, 0)
					if not h._in_foot(lp, -0.4):
						continue
					var wp: Vector3 = h.to_global(lp)
					for i in 12:
						var a := TAU * i / 12.0
						var g = load("res://scripts/grenade.gd").throw_from(h.get_parent(), wp + Vector3(0, 1.6, 0), a, 11.0, wp)
						if g.home == null:
							print("GEEN THUIS: ", kind, " laag ", laag)
							fouten += 1
						tracked.append([g, h, laag])
						worpen += 1
	if t == 20 + 120:
		print("worpen: ", worpen, " fouten: ", fouten)
		print("TEST OK" if fouten == 0 and worpen > 0 else "TEST MISLUKT")
		quit(0 if fouten == 0 else 1)
	return false
