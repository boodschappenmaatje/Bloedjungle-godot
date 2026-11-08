extends SceneTree
## Muur trekken over begroeiing: een liggende stam blokkeert het muurstuk niet meer (hij verdwijnt), en als de omheining compleet is verdwijnt alles
## binnen de muren vanzelf (bomen, struiken, varens, gras, stammen, rotsen), waar het ook staat.
## godot --headless --path . --script tests/mcv_omheining_test.gd --fixed-fps 60
var main: Node
var frames := 0
var fails := 0
var log_entry: Dictionary


func _initialize() -> void:
	root.size = Vector2i(932, 430)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


func _process(_d: float) -> bool:
	frames += 1
	var g = root.get_node("Game")
	var F = load("res://scripts/foliage.gd")
	var K = load("res://scripts/kampmuur.gd")
	if frames == 2:
		main.get_node("Hud/Sticks").set_process(false)
	if frames == 4:
		main.begin()
	if frames > 4 and g.state == "prep":
		g.prep_t = 1e9
	if frames == 20:
		g.points = 5000
		g.build_credit = 5000
		# 1. een liggende stam: het muurstuk dwars erover is geldig en haalt de stam weg
		for cell in F._vegetation_cells:
			for e in F._vegetation_cells[cell]:
				if e.get("kind", "") == "log" and not e.get("cleared", false) and e.world_position.length() > 40.0 and log_entry.is_empty():
					log_entry = e
		_check("er ligt ergens een stam", not log_entry.is_empty())
		if log_entry.is_empty():
			quit(1)
			return false
		var c: Vector3 = log_entry.world_position
		var a: Vector2i = K.snap(c + Vector3(-3.6, 0, 0))
		var b: Vector2i = K.snap(c + Vector3(3.6, 0, 0))
		var path: Array = K.line_path(a, b)
		var pl: Dictionary = K.plan(path)
		var bad := 0
		for e in pl.edges:
			if e.state == "slecht":
				bad += 1
		_check("een muur over een stam is niet 'slecht' (%d slechte stukken, %s)" % [bad, str(pl.reason)], bad == 0)
		var r: Dictionary = K.build(path)
		_check("de muur is gebouwd (%d stukken)" % int(r.built), int(r.built) > 0)
		_check("de stam is verdwenen", bool(log_entry.get("cleared", false)))
		# 2. een compleet vierkant om het hoofdkwartier: alles daarbinnen verdwijnt
		var rect: Array = K.rect_path(Vector2i(-12, -12), Vector2i(12, 12))
		var inside := Rect2(-12 * 3.5 + 1.0, -12 * 3.5 + 1.0, 24 * 3.5 - 2.0, 24 * 3.5 - 2.0)
		var regions := [{"name": "binnen", "center": inside.get_center(), "size": inside.size, "yaw": 0.0}]
		var before: int = F.count_clearable_in_regions(regions, Vector3.ZERO, 0.0, 0.0)
		print("  begroeiing binnen het vierkant vooraf: ", before)
		_check("er staat begroeiing binnen het toekomstige vierkant", before > 0)
		var r2: Dictionary = K.build(rect)
		_check("het vierkant is gebouwd (%d stukken, overgeslagen %d)" % [int(r2.built), int(r2.skipped)], int(r2.built) > 0 and int(r2.skipped) == 0)
		_check("de omheining is compleet", K.enclosed())
		var after: int = F.count_clearable_in_regions(regions, Vector3.ZERO, 0.0, 0.0)
		_check("binnen de muren is alles weg (%d over)" % after, after == 0)
		print("klaar, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false
