extends SceneTree
## Test: de stad achter de brug. De standaardindeling moet kloppen (niets in de rivier of op elkaar), de regels
## van de editor moeten werken en opslaan/laden moet hetzelfde terugkrijgen.
## Draaien: godot --headless --path . -s tests/stad_test.gd --fixed-fps 60

var main: Node
var frames := 0
var Stad  # pas bij het draaien geladen: de Game-autoload is bij het compileren van dit script nog niet bekend


func _initialize() -> void:
	Stad = load("res://scripts/stad.gd")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		main.begin()
	if frames < 8:
		return false
	var s = Stad.current
	print("stad: ", s.items.size(), " items, zwaarte ", Stad.weight_of(s.items), ", sloopbare gebouwen ", Stad.sloop_count(s.items))
	var bad := 0
	for d in s.items:
		var p: String = Stad.problem(d, s.items)
		if p != "":
			print("FAIL ", d.k, " ", d.x, ",", d.z, ": ", p)
			bad += 1
	print("standaard klopt: ", bad == 0)
	# regels: weg in de rivier, gebouw op de weg, twee wegen op dezelfde plek
	var t := {"k": "weg_recht", "x": 0.0, "z": -78.0, "r": 0, "m": 0}
	print("rivier: ", Stad.problem(t, s.items))
	t = {"k": "woonhuis", "x": 0.0, "z": -102.0, "r": 0, "m": 0}
	print("gebouw op weg: ", Stad.problem(t, s.items))
	t = {"k": "weg_recht", "x": 0.0, "z": -96.0, "r": 0, "m": 0}
	print("dubbel: ", Stad.problem(t, s.items))
	t = {"k": "boom", "x": 0.0, "z": -96.0, "r": 0, "m": 0}
	print("boom op weg: ", Stad.problem(t, s.items))
	t = {"k": "weg_bocht", "x": 36.0, "z": -102.0, "r": 0, "m": 0}
	print("bocht naast de straat: ", Stad.problem(t, s.items), "|")
	# toevoegen, schuiven, weghalen
	var n: int = s.items.size()
	s.add_item(t)
	s.add_item({"k": "kerk", "x": -40.0, "z": -115.0, "r": 0, "m": 0})
	t.x = 42.0
	s.refresh(t)
	s.remove_item(t)
	print("toevoegen en weghalen (verwacht ", n + 1, "): ", s.items.size())
	# opslaan en laden
	Stad.save_path = "user://stad_test.json"
	s.save_user()
	var back: Array = Stad.load_saved()
	print("bewaard en terug: ", back.size(), " van ", s.items.size())
	Stad.clear_saved()
	print(Stad.to_text(s.items).substr(0, 120))
	print("jungle weg bij het huis: ", Stad.covers(Vector3(11, 0, -110), 4.0), " en ver weg: ", Stad.covers(Vector3(60, 0, 40), 4.0))
	print("STAD TEST KLAAR")
	quit()
	return true
