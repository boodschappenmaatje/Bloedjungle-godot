extends SceneTree
## Schermafbeeldingen van het voorraaddepot, de voorraadtruck en de voorraadstapel in het spel met de echte spelcamera (stap 4b):
## depot dicht/open, de truck lost (kist op de laadplaat, portaalkraan), de truck laadt bij een stapel in drie standen, het wrak.
## xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path . -s tests/voorraad_foto.gd --fixed-fps 60
## Uitvoer: OUT/voorraad_*.png (OUT = omgevingsvariabele VOORRAAD_OUT, standaard /tmp/voorraadfoto)

var main: Node
var frames := 0
var game: Node
var sup
var depot: Dictionary
var truck
var out := "/tmp/voorraadfoto"
var step := 0
var t0 := 0


func _initialize() -> void:
	if OS.get_environment("VOORRAAD_OUT") != "":
		out = OS.get_environment("VOORRAAD_OUT")
	DirAccess.make_dir_recursive_absolute(out)
	var gs = load("res://scripts/game_settings.gd")
	gs.get_value("time")
	gs.values["time"] = "day"    # alleen in het geheugen (de bewaarde instelling kan "night" zijn), voor het laden van de wereld
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(func(): if frames > 3 and game != null: game.move = Vector2.ZERO)


func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("%s/voorraad_%s.png" % [out, name])
	print("foto ", name)


func _go(n: int) -> void:
	step = n
	t0 = frames


func _dt() -> int:
	return frames - t0


func _place_player(at: Vector3) -> void:
	game.player.global_position = at
	game.player.position.y = 0.0
	game.player.visible = false     # de camera volgt de speler; die staat niet in beeld


## Camera-opstelling: de speler staat naast het depot-voorplein, zodat de truck en het depot in beeld zijn (zelfde in voor/na).
func _depot_view() -> Vector3:
	var front := Vector3(sin(depot.yaw), 0, cos(depot.yaw))
	var side := Vector3(cos(depot.yaw), 0, -sin(depot.yaw))
	return depot.at + front * 2.0 + side * 0.0


func _stack_dir(s) -> Vector2:
	var via: Vector2 = sup._pos[s.site.via]
	return (via - s.site.pos).normalized()


func _process(_d: float) -> bool:
	frames += 1
	game = root.get_node("Game")
	if frames == 3:
		main.begin()
		for n in root.find_children("*", "", true, false):
			if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
				n.set_process(false)
		for m in get_nodes_in_group("menus"):
			m._show("")
	if frames == 90:
		sup = root.find_children("*", "Voorraad", true, false)[0]
		depot = sup.depots()[0]
		truck = sup.trucks_of(depot)[0]
		truck.set_physics_process(false)    # hij staat stil; we sturen de standen zelf
		var dock: Vector2 = sup.dock_point(depot)
		var front := Vector3(sin(depot.yaw), 0, cos(depot.yaw))
		_place_player(_depot_view())
		game.player.face = depot.yaw + PI
		_go(1)
	match step:
		1:
			if _dt() == 150:
				_shot("depot_dicht")
				var dock: Vector2 = sup.dock_point(depot)
				truck.global_position = Vector3(dock.x, 0, dock.y)
				truck.rotation.y = depot.yaw + PI
				truck.cargo = 150
				if truck.has_method("_set_lading"):
					truck._set_lading(true)
				truck.set_physics_process(true)
				truck._set_state(4)
				_go(2)
		2:
			# lossen: 6 s; fotos bij 2,0 s, 3,5 s, 4,1 s (net voor de kist neerkomt), 4,7 s (portaalkraan pakt) en 6,5 s
			var secs := float(_dt()) / 60.0
			if _dt() == 60 * 2.0 or _dt() == 60 * 3.5 or _dt() == 60 * 4.1 or _dt() == 60 * 4.7 or _dt() == 60 * 6.5:
				_shot("lossen_%02d" % int(round(secs * 10.0)))
			if _dt() > 60 * 8:
				# naar een stapel: de truck laadt
				var s = sup.stapels[0]
				var via: Vector2 = sup._pos[s.site.via]
				var dir: Vector2 = (via - s.site.pos).normalized()
				var stop: Vector2 = Vector2(s.site.pos.x, s.site.pos.y) + dir * sup.STOP_BEFORE
				truck.global_position = Vector3(stop.x, 0, stop.y)
				truck.rotation.y = atan2(-dir.x, -dir.y)
				truck.cargo = 0
				truck.slot = 0
				truck.site_id = s.site.id
				truck._back = [Vector2(truck.global_position.x, truck.global_position.z)]
				var mid := (Vector2(s.site.pos.x, s.site.pos.y) + stop) * 0.5
				_place_player(Vector3(mid.x, 0, mid.y))
				game.player.face = atan2(-dir.x, -dir.y)
				truck._set_state(2)
				_go(3)
		3:
			var secs := float(_dt()) / 60.0
			if _dt() == 60 * 2.0 or _dt() == 60 * 3.4 or _dt() == 60 * 4.4 or _dt() == 60 * 5.2:
				_shot("laden_%02d" % int(round(secs * 10.0)))
			if _dt() > 60 * 7.5:
				# de drie standen van de stapel
				var s = sup.stapels[0]
				truck.set_physics_process(false)
				truck.visible = false
				var dir2 := _stack_dir(s)
				_place_player(Vector3(s.site.pos.x, 0, s.site.pos.y) + Vector3(dir2.x, 0, dir2.y) * 1.2)
				game.player.face = atan2(-dir2.x, -dir2.y)
				_go(4)
		4:
			var s = sup.stapels[0]
			if _dt() == 10:
				s.left = s.full
				s.refresh()
			if _dt() == 40:
				_shot("stapel_vol")
				s.left = int(s.full * 0.5)
				s.refresh()
			if _dt() == 80:
				_shot("stapel_half")
				s.left = int(s.full * 0.15)
				s.refresh()
			if _dt() == 120:
				_shot("stapel_leeg")
				truck.visible = true
				var dock: Vector2 = sup.dock_point(depot)
				truck.global_position = Vector3(dock.x, 0, dock.y)
				truck.rotation.y = depot.yaw + PI
				truck.take(5000.0)
				_place_player(_depot_view())
				game.player.face = depot.yaw + PI
				_go(5)
		5:
			if _dt() == 90:
				_shot("wrak")
				return true
	return false
