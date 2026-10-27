extends SceneTree
## Test: bomen en palmen vallen om bij een grote ontploffing vlakbij (Game.note_blast), niet bij een kleine of verre; de stronk
## blijft, de stam blijft als lage botsing liggen en de boom staat niet meer in de lijst voor de heli.
## Draaien: godot --headless --path . -s tests/boom_val_test.gd --fixed-fps 60

var main: Node
var game: Node
var F: GDScript   # niet via class_name: dit testscript wordt gecompileerd voordat de autoloads er zijn
var frames := 0
var fails := 0
var e: Dictionary
var f: Dictionary
var trees0 := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		push_error("BOOM VAL TEST FAIL: " + msg)


func _pick(boom: bool) -> Dictionary:
	for key in F.get("_reg"):
		for en: Dictionary in F.get("_reg")[key]:
			if String(en["vn"]).begins_with("Boom") == boom and not en["felled"]:
				return en
	return {}


func _falling() -> Array:
	var out := []
	for n in F.get("_root").get_children():
		if n.get_script() and String(n.get_script().resource_path).ends_with("boom_val.gd"):
			out.append(n)
	return out


func _initialize() -> void:
	F = load("res://scripts/foliage.gd")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	game = root.get_node("Game")


func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		main.begin()
	if frames == 100:
		e = _pick(false)
		f = _pick(true)
		_check(not e.is_empty() and not f.is_empty(), "palm en jungleboom staan in het register")
		var o: Vector3 = e["xf"].origin
		trees0 = F.get("trees").size()
		game.note_blast(o + Vector3(1.0, 0, 0), 2.0)
		_check(not e["felled"], "kleine knal velt niets")
		game.note_blast(o + Vector3(30, 0, 0), 5.0)
		_check(not e["felled"], "verre knal velt niets")
		game.note_blast(o + Vector3(1.0, 0, 0), 3.2)   # tankgranaat vlak naast de stam
		_check(e["felled"], "tankgranaat velt de palm")
		_check(F.get("trees").size() == trees0 - 1, "palm staat niet meer in de hellilijst")
		var m: Transform3D = (e["mm"] as MultiMesh).get_instance_transform(e["idx"])
		if DisplayServer.get_name() != "headless":   # de dummy-renderer onthoudt geen instantietransformaties
			_check(m.basis.get_scale().length() < 0.001, "de staande palm is uit de MultiMesh")
		var fl := _falling()
		_check(fl.size() == 1, "er valt precies een boom: %d" % fl.size())
		if fl.size() == 1:
			var dir: Vector3 = (fl[0].get("_dir") as Vector3)
			_check(dir.x < -0.9, "valt van de knal af (-x): " + str(dir))
		var n1: int = F.call("fell_near", o, 6.0)
		_check(n1 == 0 or not e["felled"] == false, "dezelfde boom valt niet twee keer")
		var p: Vector3 = f["xf"].origin
		game.note_blast(p + Vector3(0, 0, 2.0), 8.0)   # grote knal: de jungleboom valt ook
		_check(f["felled"], "grote knal velt de jungleboom")
		var cnt := 0
		for key in F.get("_reg"):
			for en: Dictionary in F.get("_reg")[key]:
				if en["felled"]:
					cnt += 1
		_check(cnt <= 2 + F.FELL_MAX, "per knal niet meer dan FELL_MAX")
	if frames == 100 + 200:
		var landed := 0
		for n in _falling():
			var up: Vector3 = n.basis.y
			_check(absf(up.y) < 0.2, "boom ligt plat: " + str(up))
			landed += 1
		_check(landed == 2, "twee liggende bomen")
		var bodies := 0
		for n in F.get("_root").get_children():
			if n is StaticBody3D and n.collision_layer == 128 and n.get_child_count() == 1 and n.get_child(0).shape is BoxShape3D:
				bodies += 1
		_check(bodies == 2, "twee liggende stammen met botsing: %d" % bodies)
		var stumps := 0
		for n in F.get("_root").get_children():
			if n is MeshInstance3D and n.mesh and String(n.mesh.resource_name).begins_with("Stomp") or (n is MeshInstance3D and n.mesh and n.mesh.get_aabb().size.y < 2.5 and n.mesh.get_surface_count() == 1 and n.get_parent() == F.get("_root") and n.mesh.get_aabb().size.x < 4.0 and n.mesh.get_aabb().size.y > 0.5):
				stumps += 1
		_check(stumps >= 2, "stronken staan er: %d" % stumps)
		print("BOOM VAL TEST ", "OK" if fails == 0 else "%d FOUT(EN)" % fails)
		quit(1 if fails > 0 else 0)
		return true
	return false
