extends SceneTree
## De legertruck moet onder de poort van de garage door kunnen: hoogste punt van de truck (zonder antenne) < bovenkant van de deuren.
## godot --headless --path . -s tests/garage_hoogte_test.gd

var fouten := 0


func _check(naam: String, ok: bool, uitleg := "") -> void:
	print(("OK   " if ok else "FOUT ") + naam + (" " + uitleg if uitleg != "" else ""))
	if not ok:
		fouten += 1


func _top(n: Node) -> float:
	var top := -1e9
	if n is MeshInstance3D:
		top = maxf(top, ((n as MeshInstance3D).global_transform * (n as MeshInstance3D).get_aabb()).end.y)
	for c in n.get_children():
		top = maxf(top, _top(c))
	return top


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var g: Node3D = (load("res://assets/garage.glb") as PackedScene).instantiate()
	root.add_child(g)
	var t: Node3D = (load("res://scenes/vrachtwagen.tscn") as PackedScene).instantiate()
	root.add_child(t)
	await process_frame
	var deur := _top(g.find_child("DeurL", true, false))
	# de truck is 3,6 m hoog (zeildak boven de laadbak); alleen de twee uitlaatpijpen achter de cabine steken hoger uit (5,2 m)
	var truck := _top(t.find_child("ZeilDakMesh", true, false))
	var pijpen := _top(t.find_child("RompMesh", true, false))
	print("poort ", snappedf(deur, 0.01), " m, truck ", snappedf(truck, 0.01), " m, uitlaatpijpen ", snappedf(pijpen, 0.01), " m")
	_check("poort hoger dan 4 m", deur > 4.0)
	_check("truck past onder de poort met 20 cm speling", truck < deur - 0.2, "marge %.2f m" % (deur - truck))
	print("klaar, fouten: %d" % fouten)
	quit(fouten)
