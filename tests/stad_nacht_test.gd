extends SceneTree
## Test: 's nachts lichten de ramen en het lampglas van de gebouwen op, overdag niet.
## Draaien: godot --headless --path . -s tests/stad_nacht_test.gd --fixed-fps 60

var main: Node
var frames := 0
var fouten := 0


func _glow(kind: String) -> Array:
	var out := []
	for h in get_nodes_in_group(kind):
		for m in h._glass:
			out.append([m.resource_name, m.emission_enabled, m.emission_energy_multiplier])
		break
	return out


func _check(label: String, want: bool) -> void:
	for kind in ["woonhuis", "winkel", "kerk", "benzine", "hotel", "magazijn"]:
		var g := _glow(kind)
		var bad := 0
		for r in g:
			if r[1] != want:
				bad += 1
		print(label, " ", kind, ": ", g.size(), " materialen, fout=", bad)
		if bad > 0 or (g.is_empty()):
			fouten += 1


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frames += 1
	var gs = load("res://scripts/game_settings.gd")
	if frames == 3:
		main.begin()
	if frames == 15:
		gs.set_value("time", "day")
	if frames == 100:
		_check("dag", false)
		gs.set_value("time", "night")
	if frames == 200:
		_check("nacht", true)
		gs.set_value("time", "day")
	if frames == 300:
		_check("weer dag", false)
		print("STAD NACHT TEST ", "OK" if fouten == 0 else "MISLUKT")
		quit(0 if fouten == 0 else 1)
	return false
