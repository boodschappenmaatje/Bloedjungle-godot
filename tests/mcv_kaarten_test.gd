extends SceneTree
## Regressie: de bouwkaartjes volgen de spelmodus ook als die pas ná het laden van het scherm wordt gezet (zoals bij START MISSIE in het hoofdmenu): Kampmuur,
## Poort en Wachttoren in plaats van de oude Betonmuur. godot --headless --path . --script tests/mcv_kaarten_test.gd --fixed-fps 60

var D: GDScript
var main: Node
var frames := 0
var fails := 0


func _initialize() -> void:
	D = load("res://scripts/data.gd")
	D.set("mcv_mode", false)   # eerst het scherm laden zoals in het hoofdmenu: nog zonder MCV-modus
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


func _bm() -> Node:
	for c in main.get_node("Hud").get_children():
		if c.has_method("_enter") and c.has_method("_exit") and c.get("_ui") != null:
			return c
	return null


func _kinds(bm: Node) -> Array:
	var out: Array = []
	for c in bm._cards:
		out.append(c.kind)
	return out


func _process(_d: float) -> bool:
	frames += 1
	var g = root.get_node("Game")
	if frames == 2:
		main.get_node("Hud/Sticks").set_process(false)
	if frames == 4:
		var bm := _bm()
		_check("voor START MISSIE staan de oude kaartjes (Betonmuur)", bm != null and _kinds(bm).has("muur") and not _kinds(bm).has("kampmuur"))
		D.set("mcv_mode", true)   # START MISSIE
		main.begin()
	if frames == 14:
		var bm := _bm()
		bm._enter()
		var kinds := _kinds(bm)
		print("kaartjes: ", kinds)
		_check("na START MISSIE staat Kampmuur in het bouwmenu", kinds.has("kampmuur"))
		_check("ook Poort en Wachttoren", kinds.has("poort") and kinds.has("wachttoren"))
		_check("en de oude Betonmuur niet meer", not kinds.has("muur"))
		_check("geen dubbele kaartjes", kinds.size() == 13)
		var oud := 0
		for c in bm._ui.get_children():
			if c is Control and c.get_script() == bm._cards[0].get_script() and not c.is_queued_for_deletion():
				oud += 1
		_check("alleen de nieuwe kaartjes hangen in het scherm", oud == kinds.size())
		print("klaar, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false
