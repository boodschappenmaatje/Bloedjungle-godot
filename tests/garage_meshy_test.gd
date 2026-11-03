extends SceneTree
## Nieuwe garage (Meshy-motorpool, assets/garage.glb): botsvormen, poortkast, LOD, lampen en deurclips; een jeep rijdt
## door de open poort naar buiten en de poort gaat weer dicht. Zandzakken en kabelhaspel voor de garage hebben een botsvorm.
## godot --headless --path . -s tests/garage_meshy_test.gd --fixed-fps 60

var main: Node
var frames := 0
var fails := 0
var gar: Variant
var saw_open := false
var max_out := -1.0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


func _hit(p: Vector3) -> bool:
	var q := PhysicsPointQueryParameters3D.new()
	q.position = p
	q.collision_mask = Kit.LAYER_WALL
	for r in gar.node.get_world_3d().direct_space_state.intersect_point(q, 8):
		if r.collider == gar.node:
			return true
	return false


func _process(_d: float) -> bool:
	frames += 1
	var g = root.get_node("Game")
	if frames == 2:
		main.get_node("Hud/Sticks").set_process(false)
	if frames == 4:
		main.begin()
		g.player.global_position = Vector3(-6, 0, -9)
	if frames == 8:
		var b = g.builds
		g.points = 100000
		g.build_credit = 100000
		b.place("kazerne", Vector3(-6, 0, -8), PI)
		gar = b.place("garage", Vector3(16, 0, 2), 0.0)
		_check("garage geplaatst", gar != null)
		if gar == null:
			quit(1)
			return true
		var model: Node = gar.node.get_meta("model")
		var romp := model.find_child("Romp", true, false) as GeometryInstance3D
		var lod := model.find_child("Romp_LOD1", true, false) as GeometryInstance3D
		_check("romp en LOD1 wisselen op %.0f m" % b.GARAGE_LOD, romp != null and lod != null and romp.visibility_range_end == b.GARAGE_LOD and lod.visibility_range_begin == b.GARAGE_LOD)
		var shapes := 0
		for c in gar.node.get_children():
			if c is CollisionShape3D:
				shapes += 1
		_check("12 botsvormen (11 kasten + poort), heeft %d" % shapes, shapes == 12)
		var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
		var only_doors := true
		for clip in ["Open", "Dicht"]:
			var a := ap.get_animation(clip)
			only_doors = only_doors and a.get_track_count() >= 2
			for i in a.get_track_count():
				only_doors = only_doors and String(a.track_get_path(i)).get_slice(":", 0).get_file().begins_with("Deur")
		_check("Open/Dicht bewegen alleen de deuren", only_doors)
		var lamps := 0
		for n in ["DeurLampL", "DeurLampM", "DeurLampR", "BinnenLamp"]:
			var l := model.find_child(n, true, false) as Light3D
			if l and not l.shadow_enabled and ((l is SpotLight3D and l.spot_range <= 10.0) or (l is OmniLight3D and l.omni_range <= 10.0)):
				lamps += 1
		_check("4 lampen met kort bereik", lamps == 4)
		_check("poort dicht = poortkast aan", not gar.door_shape.disabled)
	if frames == 10:
		var at: Vector3 = gar.at
		_check("muur links houdt tegen", _hit(at + Vector3(-3.04, 1.0, -0.5)))
		_check("zandzakken links voor houden tegen", _hit(at + Vector3(-2.9, 0.4, 2.56)))
		_check("kabelhaspel rechts voor houdt tegen", _hit(at + Vector3(2.51, 0.5, 2.51)))
		_check("dichte poort houdt tegen", _hit(at + Vector3(-0.04, 1.0, 1.81)))
		_check("voorplein is vrij", not _hit(at + Vector3(-0.04, 0.5, 3.5)))
		g.builds.buy_vehicle(gar, "jeep")
	if frames > 10 and gar != null:
		if gar.door_shape.disabled:
			saw_open = true
		if is_instance_valid(gar.veh):
			max_out = maxf(max_out, (gar.veh.global_position - gar.at).z)
	if frames == 10 + 600:
		_check("poort ging open (poortkast uit)", saw_open)
		_check("jeep reed de poort uit (%.1f m voor het midden)" % max_out, max_out > g.builds.FRONT + 2.0)
		_check("poort weer dicht", gar.phase == "idle" and not gar.door_shape.disabled)
		print("klaar, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false
