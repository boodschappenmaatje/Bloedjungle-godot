extends SceneTree
## Test: de stadseditor. Open hem, zet een wegdeel en een bank neer met echte muisklikken, schuif het wegdeel,
## draai, kopieer, haal weg en maak alles ongedaan. Controleert ook dat de camera recht van boven kijkt.
## Draaien: godot --headless --path . -s tests/stad_editor_test.gd --fixed-fps 60

var main: Node
var frames := 0
var game: Node
var ed
var stad
var n0 := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _click(p: Vector2, hold := 0) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = p
	e.pressed = true
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	var u := InputEventMouseButton.new()
	u.button_index = MOUSE_BUTTON_LEFT
	u.position = p
	u.pressed = false
	Input.parse_input_event(u)
	Input.flush_buffered_events()


func _screen_of(wx: float, wz: float) -> Vector2:
	return root.get_camera_3d().unproject_position(Vector3(wx, 0, wz))


func _process(_d: float) -> bool:
	frames += 1
	game = root.get_node("Game")
	if frames == 2:
		root.size = Vector2i(1280, 720)
	if frames == 3:
		main.begin()
		for n in root.find_children("*", "", true, false):
			if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
				n.set_process(false)
	if frames < 10:
		return false
	var t := frames - 10
	if t == 0:
		stad = load("res://scripts/stad.gd").current
		ed = root.find_children("*", "Control", true, false).filter(func(n): return n.get_script() and String(n.get_script().resource_path).ends_with("stad_editor.gd"))[0]
		n0 = stad.items.size()
		print("state ", game.state, " items ", n0)
		ed.enter()
		print("editor open: ", game.editing, " bouwmodus ", game.build_mode)
	if t == 40:
		var cam := root.get_camera_3d()
		print("camera hoogte ", snappedf(cam.global_position.y, 0.1), " kijkt omlaag: ", snappedf(-cam.global_transform.basis.z.y, 0.01))
		# wegdeel kiezen en neerzetten op (6,-96) — naast de eerste weg? nee: vrije plek aan de oostkant boven de straat
		ed._pick_kind("weg_recht")
		_click(_screen_of(6, -96))
	if t == 45:
		print("na plaatsen: ", stad.items.size() - n0, " erbij (verwacht 1)")
		_click(_screen_of(6, -96))   # zelfde plek: moet geweigerd worden
	if t == 50:
		print("dubbel geweigerd: ", stad.items.size() - n0, " erbij (verwacht 1), melding: ", ed._msg.text)
		ed._pick_kind("weg_recht")   # uitzetten
		ed._pick_kind("bankje")
		_click(_screen_of(6, -96))
	if t == 55:
		print("bankje erbij: ", stad.items.size() - n0, " (verwacht 2)")
		ed._pick_kind("bankje")
		ed._pick_kind("woonhuis")
		_click(_screen_of(6, -96))   # huis op de weg: geweigerd
	if t == 60:
		print("huis op weg geweigerd: ", stad.items.size() - n0, " (verwacht 2), melding: ", ed._msg.text)
		ed._pick_kind("woonhuis")
		# selecteer het nieuwe wegdeel (onder het bankje: tik ernaast) en draai
		_click(_screen_of(7.8, -96))
	if t == 65:
		print("geselecteerd: ", ed._sel.get("k", "niets"), " r=", ed._sel.get("r", -1))
		ed._rotate()   # draaimodus aan
		print("draaimodus: ", ed._tool)
		_click(_screen_of(7.8, -96))   # tik op het wegdeel
		print("gedraaid: r=", ed._sel.get("r", -1), " (verwacht 1) tool ", ed._tool)
		ed._rotate()   # draaimodus uit
		print("draaimodus uit: '", ed._tool, "'")
		_click(_screen_of(7.8, -96))
		ed._copy()
		print("gekopieerd: ", stad.items.size() - n0, " erbij (verwacht 3), selectie ", ed._sel.get("x", 0), ",", ed._sel.get("z", 0))
		ed._mirror()
		ed._delete_sel()
		print("weggehaald: ", stad.items.size() - n0, " (verwacht 2)")
	if t == 70:
		for i in 6:
			ed._do_undo()
		print("alles ongedaan: ", stad.items.size() - n0, " (verwacht 0)")
		ed._show_text()
		print("tekst: ", ed._text.text.length() > 100)
		ed.exit()
		print("editor dicht: ", not game.editing, " ", not game.build_mode)
		print("STAD EDITOR TEST KLAAR")
		quit()
		return true
	return false
