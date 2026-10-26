extends SceneTree
## Test: sneller slopen (dragende hoeken, kettingreactie, kraken + instorting, bedolven vijanden).
## Per gebouw en wapen: zet een vers gebouw buiten de kaart, schiet op de dragende hoeken (pistool: 26 x 0,33 per kogel)
## of gooi granaten (straal 5, schade 220) op de hoeken, tel hoeveel er nodig zijn tot het kraken begint, wacht
## de instorting af en kijk of een vijand die binnen stond is bedolven. Draaien: godot --headless --path . -s tests/sloop_test.gd --fixed-fps 60

const KINDS := ["woonhuis", "winkel", "hotel", "magazijn", "benzine"]
var main: Node
var frames := 0
var trials: Array = []
var idx := 0
var h
var enemy: Node
var wait := 0
var phase := 0
var count := 0
var fails := 0
var trial: Dictionary
var base_banners := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	load("res://scripts/woonhuis.gd").set("spread_now", true)   # telt granaten/kogels tot het kraken: kettingreactie meteen
	for k in KINDS:
		trials.append({"kind": k, "weapon": "pistool"})
		trials.append({"kind": k, "weapon": "granaat"})


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		push_error("SLOOP TEST: " + msg)


func _process(_d: float) -> bool:
	frames += 1
	var game = root.get_node("Game")
	if frames == 3:
		main.begin()
		for n in root.find_children("*", "", true, false):
			if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
				n.set_process(false)
		return false
	if frames < 6:
		return false
	if wait > 0:
		wait -= 1
		return false
	if phase == 0:
		if idx >= trials.size():
			print("KLAAR, fouten: ", fails)
			quit(1 if fails > 0 else 0)
			return true
		trial = trials[idx]
		h = load("res://scripts/woonhuis.gd").place(main, Vector3(300 + idx * 40, 0, 300), 0.0, trial.kind)
		phase = 1
		wait = 3
		return false
	if phase == 1:
		var rule: Dictionary = h.spec.collapse[0]
		var pil: Array = h._pillars_for(rule.pre)
		_check(pil.size() >= 2, "%s: te weinig dragende hoeken" % trial.kind)
		enemy = load("res://scenes/enemy.tscn").instantiate()
		enemy.call("setup", "rifle", 1)
		enemy.position = h.global_position + Vector3(0.0, 0.0, 2.5 if trial.kind == "benzine" else 0.0)
		main.add_child(enemy)
		enemy.set_process(false)   # blijft staan waar hij staat
		enemy.set_physics_process(false)
		count = 0
		var i := 0
		while h._warn <= 0.0 and not h._ruin and count < 3000:
			var s: Dictionary = pil[i % pil.size()]
			i += 1
			count += 1
			if trial.weapon == "pistool":
				h.damage(s, 26.0 * 0.33)
			else:
				load("res://scripts/woonhuis.gd").blast_all(h.to_global((s.box as AABB).get_center()), 5.0, 220.0)
		var old_need := int(rule.need)
		var old_hits: float = old_need * ceilf(320.0 / (26.0 * 0.33)) if trial.weapon == "pistool" else float(old_need)
		print("%-9s %-8s: kraakt na %4d %s op %d dragende hoeken (oud: ~%d, %d muren weg)" % [trial.kind, trial.weapon, count,
			"kogels" if trial.weapon == "pistool" else "granaten", pil.size(), old_hits, old_need])
		_check(h._warn > 0.0 or h._ruin, "%s %s: geen kraak" % [trial.kind, trial.weapon])
		phase = 2
		wait = 120
		return false
	if phase == 2:
		var done: bool = h._ruin or h._collapsed
		print("            instorting: %s, vijand binnen %s" % ["ja" if done else "NEE", "bedolven" if enemy.dead else "OVERLEEFD"])
		_check(done, "%s %s: niet ingestort" % [trial.kind, trial.weapon])
		_check(enemy.dead or trial.kind == "benzine" and trial.weapon == "granaat", "%s: vijand niet bedolven" % trial.kind)
		h.queue_free()
		if is_instance_valid(enemy):
			enemy.queue_free()
		idx += 1
		phase = 0
		wait = 3
		return false
	return false
