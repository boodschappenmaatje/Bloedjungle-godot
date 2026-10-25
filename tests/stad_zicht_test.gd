extends SceneTree
## Test: zichtafstanden in de stad. In het spel tekent de iPhone verre gebouwen en straatmeubilair niet; in de editor
## (hoog boven de stad) staat dat uit en komt het daarna terug.
## Draaien: godot --headless --path . -s tests/stad_zicht_test.gd --fixed-fps 60

var main: Node
var frames := 0
var ed
var fouten := 0


func _ends(kind: String) -> Array:
	var out := []
	var S = load("res://scripts/stad.gd")
	for d in S.current.items:
		if S.KINDS[d.k].cat == kind and d.node != null:
			for mi in d.node.find_children("*", "GeometryInstance3D", true, false):
				out.append((mi as GeometryInstance3D).visibility_range_end)
	return out


func _check(label: String, kind: String, want: float) -> void:
	var e := _ends(kind)
	var bad := 0
	for v in e:
		if not is_equal_approx(v, want):
			bad += 1
	print(label, ": ", e.size(), " meshes, fout=", bad, " (verwacht ", want, ")")
	if bad > 0 or e.is_empty():
		fouten += 1


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		main.begin()
		for n in root.find_children("*", "", true, false):
			if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
				n.set_process(false)
	if frames == 20:
		_check("gebouwen in het spel", "gebouw", 130.0)
		_check("straatmeubilair in het spel", "straat", 70.0)
		ed = root.find_children("*", "Control", true, false).filter(func(n): return n.get_script() and String(n.get_script().resource_path).ends_with("stad_editor.gd"))[0]
		ed.enter()
	if frames == 25:
		_check("gebouwen in de editor", "gebouw", 0.0)
		_check("straatmeubilair in de editor", "straat", 0.0)
		ed.exit()
	if frames == 30:
		_check("gebouwen na de editor", "gebouw", 130.0)
		_check("straatmeubilair na de editor", "straat", 70.0)
		print("STAD ZICHT TEST ", "OK" if fouten == 0 else "MISLUKT")
		quit(0 if fouten == 0 else 1)
	return false
