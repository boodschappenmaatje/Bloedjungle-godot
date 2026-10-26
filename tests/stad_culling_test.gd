extends SceneTree
## Test zonder GPU: stad-voetafdruk wordt bijgewerkt en veilige marge
## houdt nabijgelegen gebouwen zichtbaar. Geen physics/colliders worden aangepast.
## godot --headless --path . -s tests/stad_culling_test.gd

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("STAD CULL FAIL: " + label)


func _run() -> void:
	var S = load("res://scripts/stad.gd")
	var s = S.new()
	s.items = S.from_lines([["woonhuis", 0, -110, 0, 0], ["hotel", 15, -145, 0, 0]])
	s._rebuild_city_footprint()
	_check(s._has_city_footprint, "geen voetafdruk")
	var bounds: Rect2 = s._city_footprint
	_check(bounds.has_point(Vector2(0, -110)), "woonhuis niet inbegrepen")
	_check(bounds.has_point(Vector2(15, -145)), "hotel niet inbegrepen")
	_check(not S._footprints_overlap(bounds, Rect2(Vector2(-15, 30), Vector2(30, 25))), "stad ver buiten beeld wordt niet verborgen")
	_check(S._footprints_overlap(bounds, Rect2(Vector2(-10, -95), Vector2(20, 25))), "stad dichtbij verdwijnt")
	_check(S._footprints_overlap(bounds, Rect2(Vector2(-20, -70), Vector2(25, 15))), "veiligheidsmarge ontbreekt")

	# Bij wijzigingen in de stadseditor moet de omhullende voetafdruk verversen.
	s.items = S.from_lines([["woonhuis", 200, -200, 0, 0]])
	s._rebuild_city_footprint()
	_check(s._city_footprint.has_point(Vector2(200, -200)), "nieuwe locatie niet meegenomen")
	_check(not s._city_footprint.has_point(Vector2(0, -110)), "oude locatie is achtergebleven")
	_check(S._footprints_overlap(s._city_footprint, Rect2(Vector2(190, -210), Vector2(20, 20))), "nieuwe locatie niet zichtbaar")

	# Deze optimalisatie verandert alleen Stad.visible: geen queue_free,
	# geen physics layers/masks en geen process_mode-wijzigingen.
	s.free()
	print("STAD CULL TEST: ", "OK" if failures == 0 else "%d FOUT(EN)" % failures)
	quit(0 if failures == 0 else 1)
