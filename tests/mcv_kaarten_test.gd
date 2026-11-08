extends SceneTree
## Regressie: het bouwmenu heeft de kaartjes van de MCV-start (Kampmuur, Poort, Wachttoren) en niet de oude Betonmuur.
## godot --headless --path . --script tests/mcv_kaarten_test.gd --fixed-fps 60

var D: GDScript
var main: Node
var frames := 0
var fails := 0


func _initialize() -> void:
	D = load("res://scripts/data.gd")
	D.set("mcv_autodeploy", false)
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
	if frames == 2:
		main.get_node("Hud/Sticks").set_process(false)
	if frames == 4:
		main.begin()
	if frames == 14:
		var bm := _bm()
		bm._enter()
		var kinds := _kinds(bm)
		print("kaartjes: ", kinds)
		_check("Kampmuur staat in het bouwmenu", kinds.has("kampmuur"))
		_check("ook Poort en Wachttoren", kinds.has("poort") and kinds.has("wachttoren"))
		_check("en de oude Betonmuur niet meer", not kinds.has("muur"))
		_check("13 kaartjes, geen dubbele", kinds.size() == 13)
		print("klaar, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false
