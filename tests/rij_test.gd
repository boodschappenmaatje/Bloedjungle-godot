extends SceneTree
## Test van de kazerne-bouwrij en het verzamelpunt (Generals-plan, stap 2a).
## godot --headless --path . -s tests/rij_test.gd --fixed-fps 60

var main: Node
var frames := 0
var kz: Variant
var fails := 0
var pts0 := 0


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
		g.points = 10000
		kz = b.place("kazerne", Vector3(-6, 0, -8), PI)
		kz.lv = 3  # 6 soldaten tegelijk, zodat de rij van 5 de beperking is
		pts0 = g.points
		for i in 7:
			b.recruit(kz)
		_check("rij is maximaal 5", kz.queue == 5)
		_check("5 x 250 punten betaald", pts0 - g.points == 5 * 250)
		b.cancel_recruit(kz)
		_check("annuleren haalt er een uit", kz.queue == 4)
		_check("annuleren geeft 250 terug", pts0 - g.points == 4 * 250)
		_check("rijbalk bestaat", kz.rij != null)
		var oud = load("res://scripts/ally.gd").new()
		main.add_child(oud)
		oud.global_position = Vector3(-4, 0, -4)
		oud.setup(100.0, 16.0, 0)
		g.allies.append(oud)
		b.set_rally(kz, Vector3(-30, 0, -20))
		_check("al klare soldaat loopt naar de vlag", oud.command == "defend" and oud.command_target.is_equal_approx(Vector3(-30, 0, -20)))
		_check("vlag staat", kz.has_rally and kz.flag != null and kz.flag.position.is_equal_approx(Vector3(-30, 0, -20)))
		_check("vlag zetten zet de stand op vlag", kz.rally_mode == "vlag" and kz.flag.visible)
		kz.train_t = 0.05
	if frames == 30:
		var b = root.get_node("Game").builds
		_check("rijbalk zichtbaar met soldaten in de rij", kz.rij.visible)
		var allies: Array = root.get_node("Game").allies
		var found := false
		for a in allies:
			if is_instance_valid(a) and a.command == "defend" and a.command_target.is_equal_approx(Vector3(-30, 0, -20)):
				found = true
		_check("nieuwe soldaat gaat naar de vlag", found and kz.queue == 3)
		b.toggle_rally_mode(kz)
		_check("terug naar volgen", kz.rally_mode == "volgen")
		print("klaar, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false
