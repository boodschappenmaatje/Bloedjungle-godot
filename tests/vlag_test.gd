extends SceneTree
## Test van het verzamelvlag-model (Generals-plan, stap 2b).
## godot --headless --path . -s tests/vlag_test.gd --fixed-fps 60

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
		g.points = 10000
		kz = b.place("kazerne", Vector3(-6, 0, -8), PI)
		b.set_rally(kz, Vector3(-3, 0, -14))
		var f: Node3D = kz.flag
		_check("vlag bestaat en heet Verzamelvlag", f != null and f.name == "Verzamelvlag")
		_check("vlag is een RallyFlag", f is RallyFlag)
		_check("vlag staat op het verzamelpunt", f.position.is_equal_approx(Vector3(-3, 0, -14)))
		_check("model HQ-spel en LOD1 geladen", f.model_hi != null and f.model_lo != null)
		for n in ["Paal", "Zandzakken", "Doek", "Lamp", "Messing"]:
			_check("onderdeel " + n, f.model_hi.find_child(n, true, false) != null)
		var ap: AnimationPlayer = f.model_hi.find_child("AnimationPlayer", true, false)
		_check("clip Wapperen-loop speelt", ap != null and ap.is_playing() and ap.current_animation.begins_with("Wapperen"))
		_check("geen botsing (geen collision-nodes)", f.find_children("*", "CollisionObject3D", true, false).is_empty())
		_check("grondring aanwezig", f.ring != null and f.ring.mesh is QuadMesh)
		_check("lampmateriaal gevonden", f._lamp_mats.size() == 2)
		f.set_night(false)
		var day: float = f._lamp_mats[0].emission_energy_multiplier
		f.set_night(true)
		var nacht: float = f._lamp_mats[0].emission_energy_multiplier
		_check("lamp gloeit 's nachts sterker dan overdag", nacht > day * 10.0)
		# oude contract: zichtbaar bij stand vlag
		_check("vlag zichtbaar bij stand vlag", f.visible)
		b.toggle_rally_mode(kz)
		_check("vlag verborgen bij stand volgen", not f.visible)
	if frames == 14:
		print("klaar, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false
