extends SceneTree
## Test: wegen trekken als lijn in de stadseditor. Het spel kiest zelf recht, bocht, T en kruising en past bestaande wegen aan.
## Draaien: godot --headless --path . -s tests/stad_lijn_test.gd --fixed-fps 60

var main: Node
var frames := 0
var ed
var stad
var n0 := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _cells(list: Array) -> Array:
	var out: Array = []
	for c in list:
		out.append(Vector2i(c[0], c[1]))
	return out


func _kinds(plan: Dictionary) -> String:
	return str(plan.add.map(func(d): return "%s r%d (%d,%d)" % [d.k, d.r, d.x, d.z]))


func _process(_d: float) -> bool:
	frames += 1
	if frames == 2:
		root.size = Vector2i(1280, 720)
	if frames == 3:
		main.begin()
	if frames < 10:
		return false
	var t := frames - 10
	if t == 0:
		stad = load("res://scripts/stad.gd").current
		ed = root.find_children("*", "Control", true, false).filter(func(n): return n.get_script() and String(n.get_script().resource_path).ends_with("stad_editor.gd"))[0]
		n0 = stad.items.size()
		ed.enter()
		ed._set_look_mode(false)
		ed._pick_kind("lijn")
		print("tool ", ed._tool)
		# rij verlengen naar het oosten
		ed._line_cells = _cells([[5, -17], [6, -17], [7, -17]])
		ed._line_update()
		print("A verlengen: ok=", ed._line_plan.ok, " erbij ", ed._line_plan.add.size(), " weg ", ed._line_plan.remove.size(), " ", _kinds(ed._line_plan))
		ed._line_apply()
		print("   items nu ", stad.items.size() - n0, " erbij (verwacht 2)")
		# bocht in een nieuwe zijstraat: (7,-17) -> (8,-17) -> (8,-16)
		ed._line_cells = _cells([[9, -20], [10, -20], [10, -21]])
		ed._line_update()
		print("B bocht: ok=", ed._line_plan.ok, " ", ed._line_plan.problem, " ", _kinds(ed._line_plan), " weg ", ed._line_plan.remove.size())
		ed._line_apply()
		# in het gebouw
		ed._line_cells = _cells([[7, -17], [7, -18]])
		ed._line_update()
		print("C gebouw: ok=", ed._line_plan.ok, " melding=", ed._line_plan.problem)
		ed._line_apply()
		# kruising: noord-zuid dwars door de zijstraat
		ed._line_cells = _cells([[1, -16], [1, -17]])
		ed._line_update()
		print("D T-stuk: ok=", ed._line_plan.ok, " erbij ", ed._line_plan.add.size(), " weg ", ed._line_plan.remove.size(), " ", _kinds(ed._line_plan))
		ed._line_apply()
		var tm := {}
		for m in [1, 2, 4, 8, 3, 5, 6, 9, 10, 12, 7, 11, 13, 14, 15]:
			tm[m] = ed.piece_for(m, false)
		print("maskers: ", tm)
		# steeg
		ed._tool = "lijn_steeg"
		ed._line_cells = _cells([[9, -17], [10, -17]])
		ed._line_update()
		print("E steeg: ", _kinds(ed._line_plan))
		# plein: lijn die het plein raakt slaat de plein-cellen over
		ed._tool = "lijn"
		ed._line_cells = _cells([[0, -18], [0, -19]])
		ed._line_update()
		print("F plein: ok=", ed._line_plan.ok, " ", ed._line_plan.problem, " ", _kinds(ed._line_plan))
		# alles ongedaan: lijnen gaan als één stap terug
		var steps := 0
		while not ed._undo.is_empty() and steps < 10:
			ed._do_undo()
			steps += 1
		print("na ongedaan: ", stad.items.size() - n0, " erbij (verwacht 0)")
		print("STAD LIJN TEST KLAAR")
		return true
	return false
