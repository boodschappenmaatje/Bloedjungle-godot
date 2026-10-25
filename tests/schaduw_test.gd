extends SceneTree
## Test: één samengevoegde schaduwvorm per heel stadsgebouw (woonhuis.gd _shadow_proxy). Heel en buiten: de vorm werpt de
## schaduw en de losse stukjes niet; binnen: weer de losse stukjes (dak en muren gaan weg); na schade blijvend de losse stukjes.
## Draaien: godot --headless --path . -s tests/schaduw_test.gd --fixed-fps 60

var main: Node
var frames := 0
var game: Node
var fails := 0
var huis


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		push_error("SCHADUW TEST FAIL: " + msg)


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _casting(h) -> int:
	var n := 0
	for mi in h._proxy_parts:
		if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			n += 1
	return n


func _process(_d: float) -> bool:
	frames += 1
	game = root.get_node("Game")
	if frames == 3:
		main.begin()
		for n in root.find_children("*", "", true, false):
			if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
				n.set_process(false)
		for kind in ["woonhuis", "winkel", "hotel", "kerk", "benzine", "magazijn"]:
			for h in get_nodes_in_group(kind):
				_check(h._proxy != null and h._proxy.visible, "%s heeft geen samengevoegde schaduw" % kind)
				if h._proxy != null:
					_check(h._proxy.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY, "%s: schaduwvorm is zichtbaar in beeld" % kind)
					_check(_casting(h) == 0, "%s: losse stukjes werpen nog schaduw" % kind)
					print("%s: %d stukjes -> 1 schaduwvorm (%d vlakken)" % [kind, h._proxy_parts.size(), h._proxy.mesh.get_surface_count()])
				break
		huis = get_nodes_in_group("woonhuis")[0]
		game.player.global_position = huis.global_position + Vector3(0, 0, 0.5)
	if frames == 30:
		_check(huis._inside >= 0, "speler staat niet binnen (%d)" % huis._inside)
		_check(not huis._proxy.visible and _casting(huis) == huis._proxy_parts.size(), "binnen: losse stukjes werpen geen schaduw")
		game.player.global_position = huis.global_position + Vector3(0, 0, 14)
	if frames == 60:
		_check(huis._inside < 0 and huis._proxy.visible and _casting(huis) == 0, "weer buiten: schaduwvorm niet terug")
		var s: Dictionary = huis.segs[0]
		huis.damage(s, float(s.max) * 2.0)
	if frames == 70:
		_check(not huis._proxy.visible and _casting(huis) > 0, "na schade werpt de samengevoegde vorm nog schaduw")
		if fails == 0:
			print("SCHADUW TEST OK")
		quit(1 if fails else 0)
	return false
