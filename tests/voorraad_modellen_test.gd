extends SceneTree
## Generals stap 4b: de echte GLB-modellen van het voorraaddepot, de voorraadtruck (met wrak) en de voorraadstapel (bron/voorraad/).
## Controleert namen, clips (lengte, echt bewegende onderdelen), driehoekbudgetten, materialen en LOD1; speelt de clips en kijkt of de
## onderdelen echt bewegen. Gameplaycontract van 4a (botsblok, route, wrak, poortopening) staat in tests/voorraad_test.gd.
## godot --headless --path . --script tests/voorraad_modellen_test.gd --fixed-fps 60

var fails := 0


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


func _tris(n: Node) -> int:
	var t := 0
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh
		if m == null:
			continue
		for s in m.get_surface_count():
			var arr := m.surface_get_arrays(s)
			var idx = arr[Mesh.ARRAY_INDEX]
			t += (idx.size() if idx != null and idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return t


func _mats(n: Node) -> Dictionary:
	var d := {}
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh
		if m == null:
			continue
		for s in m.get_surface_count():
			var mat := m.surface_get_material(s)
			if mat != null:
				d[mat.resource_name] = true
	return d


func _load(path: String) -> Node:
	var ps := load(path)
	if ps == null:
		_check("%s laadt" % path, false)
		return null
	var n: Node = (ps as PackedScene).instantiate()
	root.add_child(n)
	return n


func _has(n: Node, names: Array, label: String) -> void:
	var missing: Array = []
	for x in names:
		if n.find_child(x, true, false) == null:
			missing.append(x)
	_check("%s: onderdelen %s" % [label, str(names)], missing.is_empty())
	if not missing.is_empty():
		print("   ontbreekt: ", missing)


## De afhaalkist-pivot heet per stand Afhaal, Afhaal_001, Afhaal_002 (Blender maakt de namen uniek).
func _afhaal(stand: Node) -> bool:
	for c in stand.get_children():
		var nm := String(c.name)
		if nm == "Afhaal" or (nm.begins_with("Afhaal_") and nm.substr(7).is_valid_int()):
			return c.get_child_count() >= 4
	return false


func _tr(n: Node, name: String) -> Transform3D:
	return (n.find_child(name, true, false) as Node3D).transform


func _initialize() -> void:
	# ---------------- truck
	var tr := _load("res://assets/voorraadtruck.glb")
	if tr != null:
		_has(tr, ["Wiel_FL", "Wiel_FR", "Wiel_ML", "Wiel_MR", "Wiel_RL", "Wiel_RR", "Lading", "Kist_vast", "Kolom", "Giek", "GiekUit", "Kettingpunt", "Ketting", "Grijper", "Klauw_LV", "Klauw_RV", "Klauw_LA"], "truck")
		var ap := tr.find_child("AnimationPlayer", true, false) as AnimationPlayer
		_check("truck: clips Laden en Lossen", ap != null and ap.has_animation("Laden") and ap.has_animation("Lossen"))
		if ap != null:
			for c in ["Laden", "Lossen"]:
				var a := ap.get_animation(c)
				_check("truck: clip %s is 6 s en bevat veel kanalen (%d)" % [c, a.get_track_count()], absf(a.length - 6.0) < 0.1 and a.get_track_count() >= 10)
			var kolom0 := _tr(tr, "Kolom").basis
			ap.play("Laden")
			ap.seek(2.0, true)
			var kolom1 := _tr(tr, "Kolom").basis
			_check("truck: kraankolom zwenkt in Laden", kolom0.x.distance_to(kolom1.x) > 0.5)
			var lading0 := (tr.find_child("Lading", true, false) as Node3D).scale.x
			ap.seek(5.9, true)
			var lading1 := (tr.find_child("Lading", true, false) as Node3D).scale.x
			_check("truck: de kist komt in de bak aan het eind van Laden (%.3f -> %.3f)" % [lading0, lading1], lading0 < 0.1 and lading1 > 0.9)
			ap.seek(6.0, true)
			var kolom2 := _tr(tr, "Kolom").basis
			_check("truck: Laden eindigt in de beginpose (kraan terug)", kolom0.x.distance_to(kolom2.x) < 0.05)
			ap.play("Lossen")
			ap.seek(0.0, true)
			var l0 := (tr.find_child("Lading", true, false) as Node3D).scale.x
			ap.seek(5.9, true)
			var l1 := (tr.find_child("Lading", true, false) as Node3D).scale.x
			_check("truck: Lossen begint geladen en eindigt leeg (%.3f -> %.3f)" % [l0, l1], l0 > 0.9 and l1 < 0.1)
		var n := _tris(tr)
		print("truck LOD0: ", n, " driehoeken, materialen ", _mats(tr).keys())
		_check("truck: LOD0 heeft minstens 40.000 driehoeken (afspraak) en blijft licht genoeg (<= 60.000)", n >= 40000 and n <= 60000)
		_check("truck: één gebakken atlas plus staal en kist (<= 4 materialen)", _mats(tr).size() <= 4)
		var ap_ := tr.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap_ != null:
			ap_.play("Laden")
			ap_.seek(0.0, true)
			var g0 := (tr.find_child("GiekUit", true, false) as Node3D).position
			ap_.seek(2.4, true)
			var g1 := (tr.find_child("GiekUit", true, false) as Node3D).position
			_check("truck: telescoopgiek schuift uit in Laden (%.2f m)" % g0.distance_to(g1), g0.distance_to(g1) > 1.5)
			ap_.seek(0.0, true)
			var k0 := (tr.find_child("Klauw_LV", true, false) as Node3D).transform.basis
			ap_.seek(2.6, true)
			var k1 := (tr.find_child("Klauw_LV", true, false) as Node3D).transform.basis
			_check("truck: klauwen openen en sluiten in Laden", k0.x.distance_to(k1.x) + k0.y.distance_to(k1.y) + k0.z.distance_to(k1.z) > 0.15)
			ap_.seek(0.0, true)
			var gr0 := (tr.find_child("Grijper", true, false) as Node3D).position.y
			ap_.seek(3.0, true)
			var gr1 := (tr.find_child("Grijper", true, false) as Node3D).position.y
			_check("truck: grijper zakt aan de ketting (%.2f m)" % (gr0 - gr1), gr0 - gr1 > 1.5)
		tr.queue_free()
	var lod := _load("res://assets/voorraadtruck_lod1.glb")
	if lod != null:
		var n2 := _tris(lod)
		print("truck LOD1: ", n2, " driehoeken")
		_check("truck: LOD1 binnen budget (ca. 3.800, marge tot 5.000)", n2 > 200 and n2 <= 5000)
		lod.queue_free()
	var wr := _load("res://assets/voorraadtruck_wrak.glb")
	if wr != null:
		var n3 := _tris(wr)
		print("truck wrak: ", n3, " driehoeken")
		_check("wrak: aanwezig en niet te zwaar (<= 60.000)", n3 > 1000 and n3 <= 60000)
		wr.queue_free()
	# ---------------- depot
	var dp := _load("res://assets/voorraaddepot.glb")
	if dp != null:
		_has(dp, ["Perron", "Schuur", "Poort", "Poort_balk", "Brug", "Loopkat", "Haak", "Kist_vast", "Kist_perron", "Kist_opslag", "Lampen"], "depot")
		var ap2 := dp.find_child("AnimationPlayer", true, false) as AnimationPlayer
		_check("depot: clips Poort en Kraan-lossen", ap2 != null and ap2.has_animation("Poort") and ap2.has_animation("Kraan-lossen"))
		if ap2 != null:
			var door := ap2.get_animation("Poort")
			var kr := ap2.get_animation("Kraan-lossen")
			_check("depot: Poort is 2 s (%.2f)" % door.length, absf(door.length - 2.0) < 0.1)
			_check("depot: Kraan-lossen is 4,5 s (%.2f)" % kr.length, absf(kr.length - 4.5) < 0.1)
			ap2.play("Poort")
			ap2.seek(0.0, true)
			var s0 := (dp.find_child("Poort", true, false) as Node3D).scale.y
			var z0 := (dp.find_child("Poort", true, false) as Node3D).scale
			ap2.seek(2.0, true)
			var z1 := (dp.find_child("Poort", true, false) as Node3D).scale
			_check("depot: de rolpoort rolt op (schaal %s -> %s)" % [str(z0), str(z1)], z0.y > 0.9 and z1.y < 0.1)
			ap2.play("Kraan-lossen")
			ap2.seek(0.0, true)
			var b0 := _tr(dp, "Brug").origin
			var k0 := _tr(dp, "Loopkat").origin
			ap2.seek(1.0, true)
			var b1 := _tr(dp, "Brug").origin
			var k1 := _tr(dp, "Loopkat").origin
			_check("depot: brug en loopkat rijden (%s -> %s)" % [str(b0), str(b1)], b0.distance_to(b1) > 0.3 and k0.distance_to(k1) > 1.0)
			ap2.seek(4.5, true)
			var b2 := _tr(dp, "Brug").origin
			_check("depot: Kraan-lossen eindigt in de beginpose", b0.distance_to(b2) < 0.05)
			var kp0 := (dp.find_child("Kist_perron", true, false) as Node3D).scale.x
			ap2.seek(0.0, true)
			var kp1 := (dp.find_child("Kist_perron", true, false) as Node3D).scale.x
			var ko1 := (dp.find_child("Kist_opslag", true, false) as Node3D).scale.x
			ap2.seek(4.4, true)
			var ko2 := (dp.find_child("Kist_opslag", true, false) as Node3D).scale.x
			_check("depot: kist staat eerst op de laadplaat en uiteindelijk op het opslagpallet (%.2f/%.2f)" % [kp1, ko2], kp1 > 0.9 and ko1 < 0.1 and ko2 > 0.9 and kp0 < 0.1)
		var n4 := _tris(dp)
		print("depot LOD0: ", n4, " driehoeken, materialen ", _mats(dp).keys())
		_check("depot: LOD0 binnen budget (maximaal ca. 45.000)", n4 > 8000 and n4 <= 45000)
		dp.queue_free()
	var dl := _load("res://assets/voorraaddepot_lod1.glb")
	if dl != null:
		var n5 := _tris(dl)
		print("depot LOD1: ", n5, " driehoeken")
		_check("depot: LOD1 binnen budget (ca. 6.000, marge tot 8.000)", n5 > 500 and n5 <= 8000)
		dl.queue_free()
	# ---------------- stapel
	var st := _load("res://assets/voorraadstapel.glb")
	if st != null:
		_has(st, ["Stapel_vol", "Stapel_half", "Stapel_leeg"], "stapel")
		var tot := []
		for nm in ["Stapel_vol", "Stapel_half", "Stapel_leeg"]:
			var s := st.find_child(nm, true, false)
			if s == null:
				continue
			var t := _tris(s)
			tot.append(t)
			_check("stapel: %s heeft een afhaalkist en blijft onder de 5.500 driehoeken (%d)" % [nm, t], _afhaal(s) and t > 1500 and t <= 5500)
		_check("stapel: vol > half > leeg in driehoeken (grofweg), aantal kisten verschilt", tot.size() == 3 and tot[0] > tot[1])
		st.queue_free()
	print("klaar, fouten=", fails)
	quit(1 if fails > 0 else 0)
