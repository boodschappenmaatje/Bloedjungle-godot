extends SceneTree
## Test van de radiomeldingen (Generals-plan, stap 2c).
## godot --headless --path . -s tests/radio_test.gd --fixed-fps 60

var main: Node
var frames := 0
var fails := 0
var kz: Variant


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


func _process(_d: float) -> bool:
	frames += 1
	var g = root.get_node("Game")
	if frames == 2:
		main.get_node("Hud/Sticks").set_process(false)
	if frames == 4:
		main.begin()
		g.player.global_position = Vector3(-6, 0, -9)
	if frames == 8:
		var b = g.builds
		var r: Radio = b.radio
		_check("radio bestaat", r != null)
		for kind in Radio.POOLS:
			for n in Radio.POOLS[kind]:
				_check("opname " + n, ResourceLoader.exists(Radio.DIR + n + ".wav"))
		_check("onbekende soort wordt genegeerd", not r.say("onzin"))
		_check("bouw klaar klinkt", r.say("bouw_klaar") and r._player.playing)
		_check("tweede melding wacht (loopt niet door elkaar)", r.say("eenheid_klaar") and r._pending == "eenheid_klaar")
		_check("basis onder vuur: cooldown blokkeert herhaling", r.say("basis_aanval") and not r.say("basis_aanval"))
		g.points = 10000
		kz = b.place("kazerne", Vector3(-6, 0, -8), PI)
		var before: float = r._last.get("gebouw_vernield", -1000.0)
		b.damage(kz, 99999.0)
		_check("gebouw vernield meldt zich", float(r._last.get("gebouw_vernield", -1000.0)) != before)
	if frames == 14:
		print("klaar, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false
