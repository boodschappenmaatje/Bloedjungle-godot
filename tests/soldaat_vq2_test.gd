extends SceneTree
## Controleert het VQ2-mannetje (assets/soldaat_vq2.glb): elke look toont precies zijn lichaam en uitrusting, alle clips
## (ook klimmen, zitten en de acties) zitten erin en bewegen het skelet echt, de uniformtint en hoofdband werken, het
## wapen hangt in de hand, de speler kan van bovenlijf wisselen en de instelling "v1" geeft het oude model terug.
## Draaien: godot --headless --path . -s tests/soldaat_vq2_test.gd --fixed-fps 60

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("SOLDAAT VQ2 TEST: " + message)


func _visible_parts(m: SoldierModel) -> Array:
	var names := {}
	for k in SoldierModel.LOOKS:
		for n in SoldierModel.LOOKS[k]:
			names[n] = true
	var out := []
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		if names.has(str(mi.name)) and mi.visible and mi.is_inside_tree() and not mi.is_queued_for_deletion():
			out.append(str(mi.name))
	out.sort()
	return out


func _run() -> void:
	var legacy_save := ConfigFile.new()
	legacy_save.set_value("gear", "top", "bloot")
	_check(Progress.migrate_appearance(legacy_save), "oude spelerslook is niet gemigreerd")
	_check(legacy_save.get_value("gear", "top") == "jungle", "oude standaard wordt geen woodlandlook")
	_check(int(legacy_save.get_value("gear", "appearance_version")) == 1, "uiterlijkmigratieversie ontbreekt")
	var current_save := ConfigFile.new()
	current_save.set_value("gear", "appearance_version", 1)
	current_save.set_value("gear", "top", "bloot")
	_check(not Progress.migrate_appearance(current_save), "gekozen oude look wordt opnieuw gemigreerd")
	_check(current_save.get_value("gear", "top") == "bloot", "gekozen oude look wordt niet behouden")
	_check(Progress.GEAR["top"][0].id == "jungle", "nieuwe standaard is niet Jungle-overlever")

	var old_setting := GameSettings.get_value("soldaat")
	GameSettings.values["soldaat"] = "vq2"
	var holder := Node3D.new()
	root.add_child(holder)
	var models := {}
	for look in SoldierModel.LOOKS:
		var m := SoldierModel.new()
		holder.add_child(m)
		var gun := "garand"
		if look == "vijand:knife":
			gun = ""
		elif look == "vijand:rocket":
			gun = "rocket"
		elif look == "vijand:heavy":
			gun = "heavy"
		m.setup(Color("8c7b52") if look.begins_with("vijand") else Color("4b5a2c"), gun, look)
		models[look] = m
	await process_frame
	await process_frame
	for look in models:
		var m: SoldierModel = models[look]
		_check(m.v2, "%s: VQ2-model niet gebruikt" % look)
		var want: Array = SoldierModel.LOOKS[look].duplicate()
		want.sort()
		var got := _visible_parts(m)
		_check(got == want, "%s: zichtbaar %s, verwacht %s" % [look, got, want])
		for clip in ["stil", "lopen", "rennen", "achteruit", "schieten", "geraakt", "dood1", "dood2", "steken", "herladen",
				"klimmen", "zitten", "rollen", "sprinten", "explosie_dood", "brand_rennen", "brand_val"]:
			_check(m.anim.has_animation(clip), "%s: clip %s ontbreekt" % [look, clip])
		var tinted := 0
		for mat: StandardMaterial3D in m._mats:
			if mat.resource_name.ends_with("_Kleding"):
				tinted += 1
				if look != "speler:jungle":
					_check(mat.albedo_color.is_equal_approx(SoldierModel.uniform_tint(m._uniform)), "%s: kledingtint niet gezet" % look)
			if look == "speler:jungle" and mat.resource_name == "JungleCommando_Camo":
				_check(mat.albedo_color == Color.WHITE, "junglecommando-camouflage wordt niet ongetint getoond")
			_check(mat.albedo_texture != null, "%s: materiaal %s zonder albedo-textuur" % [look, mat.resource_name])
			_check(mat.normal_enabled and mat.normal_texture != null, "%s: materiaal %s zonder normal map" % [look, mat.resource_name])
		_check(tinted >= 1 or look == "speler:jungle", "%s: geen getint kledingmateriaal" % look)
		if look != "vijand:knife":
			_check(m._gun != null, "%s: geen wapen in de hand" % look)
			var hand := m._hand.global_position
			_check(m.muzzle_position().distance_to(hand) < 1.6, "%s: loopmonding ver van de hand" % look)

	# echte beweging: lopen verandert de dijbeenpose, stil blijft rustig
	var walker: SoldierModel = models["eigen"]
	var skel: Skeleton3D = walker.find_children("*", "Skeleton3D", true, false)[0]
	var thigh := skel.find_bone("DEF-thighL")
	walker.play("lopen", 0.0)
	await process_frame
	var q0 := skel.get_bone_pose_rotation(thigh)
	for _i in 12:
		await process_frame
	var q1 := skel.get_bone_pose_rotation(thigh)
	_check(q0.angle_to(q1) > 0.05, "lopen beweegt het been niet (%.3f rad)" % q0.angle_to(q1))
	# de huid volgt het skelet: het lichaam is een skin op hetzelfde skelet
	var body: MeshInstance3D = walker.find_child("Lijf_Uniform", true, false)
	_check(body != null and body.skin != null and body.get_node_or_null(body.skeleton) == skel, "lichaam hangt niet aan het skelet")
	var commando: SoldierModel = models["speler:jungle"]
	var commando_body := commando.find_child("Lijf_JungleCommando", true, false) as MeshInstance3D
	_check(commando_body != null and commando_body.visible, "speler gebruikt de Tiger Stripe-bronbody niet")
	var commando_skel := commando.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_check(commando_body.skin != null and commando_body.get_node_or_null(commando_body.skeleton) == commando_skel, "Jungle Commando-body is niet aan de bestaande 53-bottenrig gekoppeld")
	_check(not (commando.find_child("Hoofdband", true, false) as Node3D).visible, "standaard Jungle Commando draagt onverwacht een hoofdband")
	for detail in ["Mag_Pouches", "Radio_Field", "IFAK_Pouch"]:
		var detail_node := commando.find_child(detail, true, false) as MeshInstance3D
		_check(detail_node != null and detail_node.visible, "speleruitrusting %s ontbreekt" % detail)
	var has_gloves := false
	var has_dark_hair := false
	for mat: StandardMaterial3D in commando._mats:
		has_gloves = has_gloves or mat.resource_name == "Commando Webbing · Dark Olive"
		has_dark_hair = has_dark_hair or mat.resource_name == "Commando Hair · Short Dark Brown"
	_check(has_gloves, "volledig gesloten handschoenmateriaal ontbreekt")
	_check(has_dark_hair, "kort donker haarmateriaal ontbreekt")

	# hoofdband en flits
	var pl: SoldierModel = models["speler:bloot"]
	pl.set_band(Color("1f4fa8"))
	var band_ok := false
	for mat: StandardMaterial3D in pl._mats:
		if mat.resource_name == "Hoofdband":
			band_ok = mat.albedo_color.is_equal_approx(Color("1f4fa8"))
	_check(band_ok, "hoofdbandkleur niet gezet")
	pl.flash()
	pl._process(0.016)
	_check(pl._mats[0].albedo_color.r > 0.8 and pl._mats[0].albedo_color.g < 0.3, "rode trefferflits werkt niet")
	pl._process(0.2)
	_check(pl._mats[0].albedo_color == pl._base_cols[0], "kleur komt niet terug na de flits")

	# bovenlijf wisselen bij de speler
	pl.set_top("vest")
	var want_v: Array = SoldierModel.LOOKS["speler:vest"].duplicate()
	want_v.sort()
	_check(_visible_parts(pl) == want_v, "wisselen naar vest: %s" % [_visible_parts(pl)])
	pl.set_top("bloot")

	# terugval op het oude model
	GameSettings.values["soldaat"] = "v1"
	var oldm := SoldierModel.new()
	holder.add_child(oldm)
	oldm.setup(Color("4b5a2c"), "garand", "eigen")
	await process_frame
	_check(not oldm.v2 and oldm.find_child("Mannequin_1", true, false) != null, "instelling v1 geeft niet het oude model")
	GameSettings.values["soldaat"] = old_setting

	if failures.is_empty():
		print("SOLDAAT VQ2 TEST OK")
	else:
		print("SOLDAAT VQ2 TEST FAIL: ", failures.size())
	quit(1 if not failures.is_empty() else 0)
