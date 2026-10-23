extends SceneTree
## Test: meubels zijn massief in alle gebouwen. Per gebouw: botsvormen van de inrichting aanwezig, deuropeningen blijven vrij
## en een echte wandeling tegen de balie van het hotel stopt ervoor.
## Draaien: godot --headless --path . -s tests/meubels_test.gd --fixed-fps 60

var main: Node
var frames := 0
var game: Node
var move := Vector2.ZERO
var hotel


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(func(): if frames > 3: game.move = move)


func _hits(h, p: Vector3) -> Array:
	var q := PhysicsShapeQueryParameters3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = 0.35
	sh.height = 1.7
	q.shape = sh
	q.transform = Transform3D(Basis(), p)
	q.collision_mask = Kit.LAYER_WALL
	var out := []
	for r in h.get_world_3d().direct_space_state.intersect_shape(q, 16):
		var c: Node = r.collider
		if c.get_parent() != null and String(c.get_parent().name) == "Meubels":
			out.append(c)
	return out


func _process(_d: float) -> bool:
	frames += 1
	game = root.get_node("Game")
	var t := frames - 3
	if t == 0:
		main.begin()
		for n in root.find_children("*", "", true, false):
			if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
				n.set_process(false)
	if t == 20:
		for kind in ["woonhuis", "winkel", "kerk", "benzine", "hotel", "magazijn"]:
			var hs := get_nodes_in_group(kind)
			if hs.is_empty():
				print(kind, ": NIET GEVONDEN")
				continue
			var h = hs[0]
			var shapes := 0
			var ok := 0
			for m in h._meubels:
				for cs in m.body.get_children():
					shapes += 1
					# midden van het blok moet een botsing geven
					if not _hits(h, (cs as Node3D).global_position).is_empty():
						ok += 1
			# deuropeningen: de deur gaat open naar binnen of buiten, het midden en 0,8 m ervoor en erachter moet vrij zijn
			var geblokkeerd := 0
			for d in h.doors:
				var n: Node3D = d.node
				# langs het deurblad (lokale x) en dwars erop in het grondvlak (ook voor de gedraaide magazijndeuren)
				var leaf := n.global_transform.basis.x.normalized()
				var dep := Vector3.UP.cross(leaf).normalized()
				var mid := n.global_position + leaf * 0.47
				mid.y = n.global_position.y + 0.9
				for off in [0.0, 0.25, -0.25]:
					if not _hits(h, mid + dep * off).is_empty():
						geblokkeerd += 1
						print("   deur ", n.name, " geblokkeerd bij ", off, " deur lokaal ", snapped(h.to_local(n.global_position), Vector3(0.01, 0.01, 0.01)))
						var pt: Vector3 = h.to_local(mid + dep * off)
						for m in h._meubels:
							for cs in m.body.get_children():
								var sz: Vector3 = (cs.shape as BoxShape3D).size
								var c: Vector3 = cs.position
								if absf(c.x - pt.x) < sz.x / 2 + 0.4 and absf(c.z - pt.z) < sz.z / 2 + 0.4 and absf(c.y - pt.y) < sz.y / 2 + 0.9:
									print("      blok ", snapped(c, Vector3(0.01, 0.01, 0.01)), " maat ", snapped(sz, Vector3(0.01, 0.01, 0.01)))
			print(kind, ": ", h._meubels.size(), " meubelgroepen, ", shapes, " blokken (", ok, " raken), deuren geblokkeerd=", geblokkeerd)
		hotel = get_nodes_in_group("hotel")[0]
		# wandeling in de hotel-lobby tegen de balie (x 3,15..3,95, z 0,4..3,6 lokaal): van x=1,2 naar oost
		game.player.global_position = hotel.to_global(Vector3(1.2, 0.3, 2.0))
		game.player.position.y = 0.3
		move = Vector2(1, 0)
	if t == 140:
		var lp: Vector3 = hotel.to_local(game.player.global_position)
		print("wandeling tegen de balie: x=", snappedf(lp.x, 0.01), " (balie begint op 3.15, speler stopt >= 0.3 ervoor)")
		move = Vector2.ZERO
		# door een bed in de kamer op verdieping 1 (bed x -1,1..0,3 lokaal, y(blender) -4,1..-2,1 = z 2,1..4,1): naar achter
		game.player.global_position = hotel.to_global(Vector3(-0.4, 3.8, 1.2))
		game.player.position.y = 3.8
		move = Vector2(0, 1)
	if t == 260:
		var lp2: Vector3 = hotel.to_local(game.player.global_position)
		print("wandeling tegen het bed: z=", snappedf(lp2.z, 0.01), " (bed begint op z=2.1)")
		hotel._fall_from(2)
		var rest: int = hotel._meubels.filter(func(m): return int(m.level) >= 2).size()
		print("na instorten van verdieping 2 en hoger: meubelgroepen daarboven=", rest, " over=", hotel._meubels.size())
		print("KLAAR")
		return true
	return false
