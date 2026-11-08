extends SceneTree
## Voorraadverkeer bij een stapel vlak bij het depot: een depot op (24, -24) met de voorkant naar het noorden ligt maar 22 m van stapel Bosrand. Daar ontstond
## een vastloper: de truck die terugkwam hield de stapel nog vast (hij stond minder dan 11 m ervan af), de truck die vertrok hield de uitrit vast, en ze
## wachtten eeuwig op elkaar. Drie trucks moeten hier blijven rijden en geld afleveren, zonder noodgevallen.
## godot --headless --path . --script tests/voorraad_kort_test.gd --fixed-fps 60
var main: Node
var frames := 0
var fails := 0
var sup
var depot: Dictionary
var trips_mid := 0

const RUN := 60 * 120


func _initialize() -> void:
	root.size = Vector2i(932, 430)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


func _process(_d: float) -> bool:
	frames += 1
	var g = root.get_node("Game")
	if frames < 60:
		root.size = Vector2i(932, 430)
	if frames == 2:
		main.get_node("Hud/Sticks").set_process(false)
	if frames == 4:
		main.begin()
		for m in get_nodes_in_group("menus"):
			m._show("")
	if frames > 4 and g.state == "prep":
		g.prep_t = 1e9
	if frames == 20:
		var dp = g.builds.place("depot", Vector3(24.0, 0.0, -24.0), PI, true)
		if dp != null:
			dp.build_t = 0.05
	if frames == 40:
		sup = g.supply
		g.points = 99999
		var depots: Array = sup.depots()
		_check("het depot staat er", depots.size() == 1)
		if depots.is_empty():
			quit(1)
			return false
		depot = depots[0]
		sup.buy_truck(depot)
		sup.buy_truck(depot)
	if frames == 40 + RUN / 2:
		trips_mid = sup.trips
	if frames == 40 + RUN:
		var ghosts := 0
		for t in get_nodes_in_group("voorraadtruck"):
			ghosts += int(t._vk.ghosts)
		_check("drie trucks bij het depot", sup.trucks_of(depot).size() == 3)
		_check("er komt geld binnen in de eerste helft (%d ritten)" % trips_mid, trips_mid >= 1)
		_check("de trucks blijven afleveren in de tweede helft (%d ritten erbij)" % (sup.trips - trips_mid), sup.trips - trips_mid >= 2)
		_check("geen noodgevallen (%d)" % ghosts, ghosts == 0)
		print("klaar, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false
