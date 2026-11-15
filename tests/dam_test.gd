extends SceneTree
## Test (dambreuk-plan stap 2): de dam (assets/dam.glb) staat in de kloof, heeft het afgesproken detail (minstens 40.000
## driehoeken, 4K-texturen) en de contracten voor de breuk (stukken, clips Kraken en Breken); het stuwmeer ligt achter de dam.
## Draaien: godot --headless --path . -s tests/dam_test.gd

var frames := 0
var main: Node


func _fail(msg: String) -> void:
	print("FAIL ", msg)


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _tris(n: Node) -> int:
	var t := 0
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var m: Mesh = (n as MeshInstance3D).mesh
		for s in m.get_surface_count():
			t += m.surface_get_array_index_len(s) / 3 if m.surface_get_array_index_len(s) > 0 else m.surface_get_array_len(s) / 3
	for c in n.get_children():
		t += _tris(c)
	return t


func _process(_d: float) -> bool:
	frames += 1
	if frames < 4:
		return false
	var lvl := main.get_node("Level")
	var dam := lvl.find_child("Dam", true, false) as Dam
	if dam == null or dam.model == null:
		_fail("dam niet in de wereld")
		return true
	# 1. plek: in de kloof, op de kloofbodem
	var want := Vector3(Bergland.gorge_x(Bergland.DAM_Z), Bergland.DAM_FLOOR, Bergland.DAM_Z)
	if dam.position.distance_to(want) > 0.01:
		_fail("dam staat niet in de kloof: %s" % dam.position)
	# 2. detail: minstens 40.000 driehoeken in het model, 4K-texturen
	var tris := _tris(dam.model)
	print("dam driehoeken: ", tris)
	if tris < 40000:
		_fail("dam te grof: %d driehoeken (eis: minstens 40.000)" % tris)
	if tris > 120000:   # sinds de Meshy-dam (importstraat, 15 nov): muur ~68k + drie sluisdeuren 24k; Godot maakt LOD's
		_fail("dam te zwaar: %d driehoeken" % tris)
	for k in ["beton", "staal"]:
		for t in ["albedo", "normal", "orm"]:
			var tex := load("res://assets/textures/dam/%s_%s.jpg" % [k, t]) as Texture2D
			if tex == null or tex.get_width() < 4096 or tex.get_height() < 4096:
				_fail("%s_%s niet in 4K" % [k, t])
	# 3. contracten voor de breuk
	var names := dam.piece_names()
	var cnt := {"Blok_": 0, "Pijler_": 0, "Poort_": 0, "Hijs_": 0, "Kraak_": 0, "Lek_": 0}
	for n in names:
		for k in cnt:
			if String(n).begins_with(k):
				cnt[k] += 1
	if cnt["Blok_"] != 24 or cnt["Pijler_"] != 4 or cnt["Poort_"] != 3 or cnt["Hijs_"] != 3 or cnt["Kraak_"] < 10 or cnt["Lek_"] < 6:
		_fail("stukken kloppen niet: %s" % cnt)
	for nm in ["Loopbrug", "Fundering", "Flank_L", "Flank_R", "Slijtvloer", "Wachthuis"]:
		if not names.has(nm):
			_fail("onderdeel %s ontbreekt" % nm)
	if dam.player == null or not dam.player.has_animation("Kraken") or not dam.player.has_animation("Breken"):
		_fail("clips Kraken en Breken ontbreken")
	else:
		if absf(dam.player.get_animation("Kraken").length - 5.0) > 0.1 or absf(dam.player.get_animation("Breken").length - 6.0) > 0.1:
			_fail("clipduur klopt niet")
	# 4. tekenbudget: intact net met een paar oppervlakken, stukken verborgen, geen schaduw
	if dam.intact == null or dam.intact.mesh.get_surface_count() > 8:
		_fail("samengevoegd net ontbreekt of heeft te veel oppervlakken")
	if dam.model.visible or not dam.intact.visible:
		_fail("in rust moet alleen het samengevoegde net zichtbaar zijn")
	# 5. clips werken: na Kraken groeien de scheuren, na Breken zijn de blokken weg van hun plek
	var blok := dam.model.find_child("Blok_4_3", true, false) as Node3D
	var kraak := dam.model.find_child("Kraak_1", true, false) as Node3D
	var p0 := blok.position
	dam.kraken()
	dam.player.seek(4.9, true)
	if kraak.scale.x < 0.9:
		_fail("scheur groeit niet in Kraken: schaal %.2f" % kraak.scale.x)
	if not dam.model.visible or dam.intact.visible:
		_fail("kraken() moet de losse stukken tonen")
	dam.breken()
	dam.player.seek(5.9, true)
	if blok.position.distance_to(p0) < 3.0:
		_fail("blok valt niet weg in Breken: %.2f m" % blok.position.distance_to(p0))
	dam.reset()
	dam.player.seek(0.0, true)
	# 6. stuwmeer: alleen voor de dam, op peil, niet op de grondplaat
	var lake := lvl.find_child("Stuwmeer", true, false) as MeshInstance3D
	if lake == null:
		_fail("stuwmeer ontbreekt")
	else:
		var aabb := lake.get_aabb()
		print("stuwmeer: ", aabb)
		var verts: PackedVector3Array = lake.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var zmax := -1e9
		for v in verts:
			zmax = maxf(zmax, v.z)
			if absf(v.y - Bergland.LAKE_Y) > 0.01:
				_fail("water niet op peil")
				break
		if zmax > Bergland.DAM_Z:
			_fail("water loopt voorbij de dam: z=%.1f" % zmax)
		if verts.size() < 400:
			_fail("stuwmeer te klein: %d punten" % verts.size())
	print("dam_test klaar")
	return true
