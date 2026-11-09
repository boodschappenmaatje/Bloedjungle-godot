extends SceneTree
## Test: wereld per start (W1) - de jungle-seed verandert per spel, maar de vaste Data.WORLD_SEED_DEFAULT (editor,
## headless, tests) blijft precies de oude, vaste jungle: geen kratten, geen ander bosjes-/open-plekken-patroon.
## Draaien: godot --headless --path . -s tests/wereld_seed_test.gd --fixed-fps 60
## (foliage.gd gebruikt Game.enemies/allies in een andere functie; zoals de andere jungle-tests laadt dit script
## Foliage daarom dynamisch met load(), niet als class_name, anders faalt het compileren buiten main.tscn.)

var fails := 0
var fol: GDScript
var frames := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		push_error("WERELD SEED TEST FAIL: " + msg)


func _build(seed_: int) -> Dictionary:
	var w := Node3D.new()
	root.add_child(w)   # moet in de boom staan: _register_vegetation() leest get_global_transform()
	fol.call("plant", w, seed_)
	var crate_mesh: Mesh = Kit.prop_mesh(Kit.MUNITIEKIST)
	var crates := 0
	for m in w.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).mesh == crate_mesh:
			crates += 1
	var trees: PackedVector2Array = fol.get("trees")
	var result := {
		"trees": PackedVector2Array(trees),
		"crates": crates,
		"grove": Vector4(fol.get("_grove_px"), fol.get("_grove_pz"), fol.get("_grove_fx"), fol.get("_grove_fz")),
	}
	w.free()
	return result


func _initialize() -> void:
	root.add_child(load("res://scenes/main.tscn").instantiate())   # registreert Game e.a. voor foliage.gd, net als jungle_test.gd
	fol = load("res://scripts/foliage.gd")


func _process(_d: float) -> bool:
	frames += 1
	if frames != 3:   # pas als de boom echt draait (zoals jungle_test.gd): anders is get_global_transform() nog niet geldig
		return false
	_run()
	return true


func _run() -> void:
	# randomize_world_seed(): nooit de vaste standaard, en niet elke keer hetzelfde getal.
	var seeds := {}
	for i in 20:
		Data.randomize_world_seed()
		_check(Data.world_seed != Data.WORLD_SEED_DEFAULT, "randomize_world_seed mag nooit de vaste standaard-seed teruggeven")
		_check(Data.world_seed >= 1, "world_seed moet positief zijn")
		seeds[Data.world_seed] = true
	_check(seeds.size() > 1, "randomize_world_seed geeft steeds hetzelfde getal terug, dus geen echte willekeur")
	print("stap 1 ok: ", seeds.size(), " verschillende seeds")

	# Vaste standaard-seed: exact de oude jungle (geen kratten, oude bosjes-fase/frequentie).
	var a := _build(Data.WORLD_SEED_DEFAULT)
	print("stap 2 ok: standaard-jungle gebouwd, ", a.trees.size(), " bomen")
	_check(a.grove == Vector4(1.3, 0.4, 0.075, 0.095), "bij de vaste standaard-seed moet het oude bosjespatroon ongewijzigd blijven")
	_check(a.crates == 0, "bij de vaste standaard-seed mogen er geen kratten bijkomen (bestaande editor/tests/screenshots blijven gelijk)")
	_check(a.trees.size() > 0, "de vaste standaard-seed moet nog gewoon jungle planten")

	# Twee verschillende willekeurige seeds: andere bomen, ander bosjespatroon, en kratten erbij.
	var b := _build(4242)
	print("stap 3 ok: wereld b gebouwd, ", b.crates, " kratten")
	var c := _build(99001)
	print("stap 4 ok: wereld c gebouwd, ", c.crates, " kratten")
	_check(b.trees.size() == a.trees.size(), "een andere seed mag niet veranderen hoeveel bomen er staan, alleen waar")
	_check(b.trees != a.trees, "seed 4242 moet andere boomplekken geven dan de vaste standaard-seed")
	_check(b.trees != c.trees, "twee verschillende willekeurige seeds moeten verschillende jungles geven")
	_check(b.grove != a.grove, "een willekeurige seed moet een ander bosjespatroon geven dan de vaste standaard")
	_check(b.crates >= 1, "bij een willekeurige seed moeten er munitiekisten in de jungle staan")
	_check(c.crates >= 1, "bij een willekeurige seed moeten er munitiekisten in de jungle staan")

	# Dezelfde seed nog eens: exact dezelfde jungle terug (nodig om met Dennis een kaart te kunnen reproduceren).
	var b2 := _build(4242)
	_check(b2.trees == b.trees, "dezelfde seed moet twee keer precies dezelfde jungle geven")
	_check(b2.grove == b.grove, "dezelfde seed moet twee keer precies hetzelfde bosjespatroon geven")

	if fails == 0:
		print("WERELD SEED TEST OK")
	quit(1 if fails > 0 else 0)
