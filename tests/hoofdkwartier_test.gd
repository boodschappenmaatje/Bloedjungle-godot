extends SceneTree
## Test van het hoofdkwartier (Generals-plan, stap 3): neemt de plek en het gameplaycontract van de oude bunker over.
## godot --headless --path . -s tests/hoofdkwartier_test.gd --fixed-fps 60

var main: Node
var frames := 0
var fails := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


func _process(_d: float) -> bool:
	frames += 1
	var g = root.get_node("Game")
	if frames == 2:
		main.get_node("Hud/Sticks").set_process(false)
	if frames == 4:
		main.begin()
	if frames == 10:
		var bunker := main.find_child("Bunker", true, false) as StaticBody3D
		_check("botsblok Bunker bestaat", bunker != null)
		_check("zelfde laag en masker", bunker.collision_layer == Kit.LAYER_BUNKER and bunker.collision_mask == 0)
		_check("zelfde schadescript", bunker.get_script() == load("res://scripts/bunker.gd"))
		var shape := bunker.get_node("BunkerCollision") as CollisionShape3D
		_check("botsblok 4,6 x 2 x 4,6", (shape.shape as BoxShape3D).size.is_equal_approx(Vector3(4.6, 2.0, 4.6)))
		var hq := bunker.get_node_or_null("Hoofdkwartier")
		_check("hoofdkwartier is de visual", hq != null and hq.is_in_group("hq"))
		_check("model en LOD1 geladen", hq.model != null and hq.model_lod != null)
		for n in ["Romp", "Platen", "Glas", "Deur", "Radar", "Vlag", "Doek", "Lamp_Rood", "Camonet", "Zandzakwal", "Niveau2", "Niveau3", "Schade1", "Schade2"]:
			_check("onderdeel " + n, hq.model.find_child(n, true, false) != null)
		var ap: AnimationPlayer = hq.model.find_child("AnimationPlayer", true, false)
		_check("clips Open en Dicht", ap != null and ap.has_animation("Open") and ap.has_animation("Dicht"))
		var rp: AnimationPlayer = hq.model.get_node_or_null("RadarSpeler")
		_check("radar draait (eigen speler)", rp != null and rp.is_playing())
		var vp: AnimationPlayer = hq.model.get_node_or_null("VlagSpeler")
		_check("vlag wappert (eigen speler)", vp != null and vp.is_playing())
		_check("geen extra botsing in het model", hq.find_children("*", "CollisionObject3D", true, false).is_empty())
		# niveaus
		var n2 := hq.model.find_child("Niveau2", true, false) as Node3D
		var n3 := hq.model.find_child("Niveau3", true, false) as Node3D
		_check("niveau 1: geen extra onderdelen", not n2.visible and not n3.visible)
		var wal := hq.model.find_child("Zandzakwal", true, false) as Node3D
		_check("zandzakwal sluit de dakrand al op niveau 1", wal != null and wal.is_visible_in_tree() and wal.get_parent() == n3.get_parent())
		_check("vlag: doekmateriaal gevonden (spel en LOD1)", hq._flags.size() == 2)
		var flag_mat: StandardMaterial3D = hq._flags[0]["mat"]
		_check("niveau 1: vlag met een ster (doek uit de glb)", flag_mat.albedo_texture == hq._flags[0]["tex1"])
		g.hq_level = 2
		hq._process(0.0)
		_check("niveau 2 toont onderdelen", n2.visible and not n3.visible)
		_check("niveau 2: vlag met twee sterren", flag_mat.albedo_texture != null and flag_mat.albedo_texture.resource_path.contains("_vlag_s2_"))
		g.hq_level = 3
		hq._process(0.0)
		_check("niveau 3 toont alles", n2.visible and n3.visible)
		_check("niveau 3: vlag met drie sterren (ook in LOD1)", flag_mat.albedo_texture.resource_path.contains("_vlag_s3_") and (hq._flags[1]["mat"] as StandardMaterial3D).albedo_texture.resource_path.contains("lod1_vlag_s3_"))
		# schade
		var s1 := hq.model.find_child("Schade1", true, false) as Node3D
		var s2 := hq.model.find_child("Schade2", true, false) as Node3D
		g.base_hp = g.base_max
		hq._process(0.0)
		_check("heel: geen schadelaag", not s1.visible and not s2.visible)
		g.base_hp = g.base_max * 0.5
		hq._process(0.0)
		_check("half kapot: laag 1", s1.visible and not s2.visible)
		g.base_hp = g.base_max * 0.2
		hq._process(0.0)
		_check("bijna kapot: laag 2", s1.visible and s2.visible)
		g.base_hp = g.base_max
		# deur
		hq.open_door()
		_check("deur gaat open", ap.current_animation == "Open")
		# schadecontract
		g.state = "play"
		g.base_hp = 1000.0
		bunker.hit(100.0, Vector3.ZERO, false)
		_check("vijandelijke schade 80%", is_equal_approx(g.base_hp, 920.0))
		bunker.hit(100.0, Vector3.ZERO, true)
		_check("eigen schade telt niet", is_equal_approx(g.base_hp, 920.0))
	if frames == 16:
		print("klaar, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false
