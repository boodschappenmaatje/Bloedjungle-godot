extends SceneTree
## Test van bouwtijd en techboom (Generals-plan, fase 1 stap 1).
## godot --headless --path . -s tests/bouwtijd_test.gd --fixed-fps 60

var main: Node
var frames := 0
var kz: Variant
var fails := 0


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
		g.points = 100000
		g.build_credit = 100000
		_check("garage zonder kazerne geweigerd", b.missing("garage") == "kazerne" and b.place("garage", Vector3(8, 0, -8), 0.0, true) == null)
		_check("muur heeft geen eisen", b.missing("muur") == "")
		kz = b.place("kazerne", Vector3(-6, 0, -8), PI, true)
		_check("kazerne geplaatst in aanbouw", kz != null and b.under_construction(kz) and kz.build_t > 11.0)
		_check("steiger aanwezig", kz.site != null and kz.node.get_node_or_null("Steiger") != null)
		_check("garage nog geweigerd tijdens bouw", b.missing("garage") == "kazerne")
		var before: int = b.queued()
		b.recruit(kz)
		_check("geen training tijdens bouw", b.queued() == before)
		kz.node.set_meta("t0", 0)
	if frames > 8 and frames < 8 + 60 * 14 and kz != null and root.get_node("Game").builds.under_construction(kz) and frames % 120 == 0:
		print("voortgang nog ", snappedf(kz.build_t, 0.1))
	if frames == 8 + 60 * 6:
		_check("halverwege nog in aanbouw", root.get_node("Game").builds.under_construction(kz))
	if frames == 8 + 60 * 14:
		var b2 = root.get_node("Game").builds
		_check("kazerne klaar na 12 s", not b2.under_construction(kz))
		_check("steiger weg", kz.site == null and kz.node.get_node_or_null("Steiger") == null)
		_check("garage nu toegestaan", b2.missing("garage") == "")
		_check("training werkt weer", (func(): b2.recruit(kz); return kz.queue == 1).call())
		var gar = b2.place("garage", Vector3(8, 0, -8), 0.0)
		_check("place() zonder bouwtijd bouwt direct (bestaande tests)", gar != null and not b2.under_construction(gar))
		print("klaar, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false
