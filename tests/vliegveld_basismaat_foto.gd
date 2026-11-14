extends SceneTree
## Foto's van het vliegveld op basismaat (14 nov 2026) in de echte spelwereld: naast het HK en de andere
## basisgebouwen, de twee toestellen in de hangar, en een toestel op de LAND-aanvlieglijn.
## Draaien (met beeld): xvfb-run -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s tests/vliegveld_basismaat_foto.gd
## Uitvoer: env FOTO_DIR (standaard user://vliegveld_basismaat).

var out := ""
var main: Node3D
var game
var AH
var V


func _initialize() -> void:
	AH = load("res://scripts/airfield_hq_23.gd")
	V = load("res://scripts/vliegtuig.gd")
	root.size = Vector2i(1280, 720)
	call_deferred("_run")


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _save(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out.path_join(file))
	print("FOTO ", out.path_join(file))


func _shot(cam: Camera3D, from: Vector3, target: Vector3, fov: float, file: String) -> void:
	cam.fov = fov
	cam.global_position = from
	cam.look_at(target, Vector3.UP)
	await _frames(12)
	await _save(file)


func _place_near(kind: String, center: Vector3, radius_from: float, radius_to: float) -> Variant:
	for r in range(int(radius_from), int(radius_to), 3):
		for k in 24:
			var a := TAU * float(k) / 24.0
			var at := center + Vector3(cos(a), 0.0, sin(a)) * float(r)
			at = Vector3(roundf(at.x), 0.0, roundf(at.z))
			if game.builds.can_place(kind, at, 0.0):
				return game.builds.place(kind, at, 0.0)
	return null


func _run() -> void:
	out = OS.get_environment("FOTO_DIR")
	if out.is_empty():
		out = ProjectSettings.globalize_path("user://vliegveld_basismaat")
	DirAccess.make_dir_recursive_absolute(out)
	load("res://scripts/data.gd").mcv_autodeploy = true
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	game = root.get_node("Game")
	await _frames(3)
	await main.call("begin")
	var menu := get_first_node_in_group("menus")
	if menu != null:
		menu.call("_show", "")
	await _frames(30)
	game.state = "prep"
	game.points = 100000
	game.build_credit = 100000
	var hq: Vector3 = game.base_pos
	print("HK op ", hq)
	var af = _place_near("airfield", hq, 34, 90)
	if af == null:
		print("FOUT: geen plek voor het vliegveld")
		quit(1)
		return
	for kind in ["helipad", "garage", "kazerne", "depot"]:
		var b = _place_near(kind, hq, 14, 60)
		print(kind, " ", b != null)
	# bouwtijd overslaan
	for b in game.buildings:
		b["build_t"] = 0.0
	for _i in 2400:   # twee toestellen klaarzetten
		await process_frame
		if af.aircraft.size() >= 2:
			break
	print("toestellen klaar: ", af.aircraft.size())
	await _frames(30)
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	var cam := Camera3D.new()
	cam.far = 1200.0
	main.add_child(cam)
	cam.make_current()
	var at: Vector3 = af.at
	var mid := (at + hq) * 0.5
	await _shot(cam, mid + Vector3(0.0, 120.0, 0.1), mid, 50.0, "01_boven_basis_met_vliegveld.png")
	await _shot(cam, mid + Vector3(45.0, 70.0, 75.0), mid, 45.0, "02_schuin_basis_met_vliegveld.png")
	var basis := Basis(Vector3.UP, af.yaw)
	var hangar: Vector3 = at + basis * Vector3(AH.HANGAR_CENTER.x, 2.0, AH.HANGAR_CENTER.y)
	await _shot(cam, hangar + basis * Vector3(14.0, 22.0, 34.0), hangar + basis * Vector3(0.0, 0.0, 6.0), 45.0, "03_hangar_toren_strook.png")
	# deuren open en dak weg: de twee toestellen in de hangar
	var core: Node = af.node.get_meta("complex").get_meta("hangar")
	core.call("open_door", &"left")
	core.call("open_door", &"right")
	await _frames(200)
	await _shot(cam, hangar + basis * Vector3(0.0, 12.0, 24.0), hangar, 45.0, "04_twee_toestellen_door_de_deur.png")
	# een toestel op de LAND-aanvlieglijn
	var plane = af.aircraft[0].node
	var p = game.player
	p.global_position = plane.global_position + Vector3(3, 0, 3)
	await _frames(5)
	plane._press()
	var w: Vector3 = at + basis * Vector3(AH.RUNWAY_START_X - 40.0, 0.0, AH.RUNWAY_CENTER_Z + 25.0)
	plane.global_position = Vector3(w.x, 12.0, w.z)
	plane.alt = 12.0
	plane.speed = 18.0
	plane.mode = V.Mode.AIR
	plane.start_autoland()
	for _i in 900:
		await process_frame
		if plane.mode == V.Mode.AUTOLAND and plane._auto.size() == 1 and plane.alt < 6.0:
			break
	var strip: Vector3 = at + basis * Vector3(AH.RUNWAY_START_X, 0.0, AH.RUNWAY_CENTER_Z)
	await _shot(cam, strip + basis * Vector3(-5.0, 30.0, 40.0), strip + basis * Vector3(-10.0, 0.0, 0.0), 45.0, "05_land_eindnadering.png")
	print("KLAAR")
	quit(0)
