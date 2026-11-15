extends SceneTree
## Dambreuk 3a: het bergpad, de kloof, de helling en de kroon zijn begaanbaar; de rest buiten de kaart niet.

var fails := 0


func ok(c: bool, m: String) -> void:
	if not c:
		fails += 1
		print("FAIL ", m)


func _init() -> void:
	var dx := DamPad.dam_x()
	var z0 := Bergland.DAM_Z
	# binnen de kaart verandert er niets
	ok(Data.clamp_world(Vector2(10, 50)) == Vector2(10, 50), "binnen blijft")
	# buiten het pad wordt teruggezet
	var c := Data.clamp_world(Vector2(-100, -400), false)
	ok(c.y > -325.0, "ver in de bergen: terug (%s)" % c)
	# op het pad blijft je staan
	ok(Data.clamp_world(Vector2(-108, -291), true) == Vector2(-108, -291), "pad blijft")
	ok(Data.clamp_world(Vector2(Bergland.gorge_x(-310), -310), false) == Vector2(Bergland.gorge_x(-310), -310), "kloof ook voor voertuigen")
	# de kroon alleen te voet
	var kroon := Vector2(dx + 20.0, z0)
	ok(Data.clamp_world(kroon, true) == kroon, "kroon te voet")
	ok(Data.clamp_world(kroon, false) != kroon, "kroon niet voor voertuigen")
	# de dam zelf is dicht: midden van de voet van de dam en het meer erachter
	var in_dam := Vector2(dx, z0 + 8.0)
	ok(Data.clamp_world(in_dam, true) != in_dam, "dam is dicht")
	var meer := Vector2(dx, z0 - 20.0)
	ok(Data.clamp_world(meer, true) != meer, "meer is dicht")
	# hoogtes: helling gaat omhoog, kroon op 16, loopbrug op 20,8
	var h0 := Data.ground_y(dx + 12.0, z0 + 36.0)
	var hm := Data.ground_y(dx + 30.0, z0 + 14.0)
	var hk := Data.ground_y(dx + 30.0, z0 + 3.0)
	ok(h0 < 3.0, "voet van de helling laag (%f)" % h0)
	ok(hm > h0 + 6.0, "helling klimt (%f)" % hm)
	ok(absf(hk - (Bergland.DAM_FLOOR + DamPad.CROWN_Y)) < 1.0, "helling komt uit op de kroon (%f)" % hk)
	ok(absf(Data.ground_y(dx + 25.0, z0 + 2.0) - (Bergland.DAM_FLOOR + DamPad.CROWN_Y)) < 0.01, "kroon vlak")
	ok(absf(Data.ground_y(dx, z0 - 2.0) - (Bergland.DAM_FLOOR + DamPad.WALK_Y)) < 0.01, "loopbrug hoog")
	# een route van het pad naar de kroon bestaat: stap voor stap lopen zonder te worden teruggezet
	var path: Array = [Vector2(-168, -214), Vector2(-132, -262), Vector2(-108, -291), Vector2(-74, -294), Vector2(Bergland.gorge_x(-297), -297),
		Vector2(Bergland.gorge_x(z0 + 30.0), z0 + 30.0), Vector2(dx + 12.0, z0 + 36.0), Vector2(dx + 30.0, z0 + 14.0), Vector2(dx + 30.0, z0 + 3.0), Vector2(dx, z0 - 2.0)]
	for i in path.size() - 1:
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var n := int(a.distance_to(b) / 0.5)
		var bad := 0
		for k in n + 1:
			var p := a.lerp(b, float(k) / float(maxi(n, 1)))
			if Data.clamp_world(p, true).distance_to(p) > 0.3:
				bad += 1
		ok(bad == 0, "route stuk %d begaanbaar (%d plekken dicht)" % [i, bad])
	print("dam_pad_test: ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(1 if fails > 0 else 0)
