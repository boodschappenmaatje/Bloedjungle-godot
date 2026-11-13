extends SceneTree
## Controleert dat de speler altijd een zichtbaar model heeft, ook als het Meshy-model ontbreekt.
## Draaien: godot --headless --path . -s tests/speler_zichtbaar_test.gd --fixed-fps 60

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _meshes(n: Node) -> int:
	var c := 1 if (n is MeshInstance3D and (n as MeshInstance3D).mesh != null and (n as MeshInstance3D).visible) else 0
	for k in n.get_children():
		c += _meshes(k)
	return c


func _run() -> void:
	GameSettings.set_value("markeringen", "on")   # de ring telt mee; in third person staat "tact" hem uit
	for soldaat in ["vq2", "meshy"]:
		GameSettings.set_value("soldaat", soldaat)
		var main: Node = load("res://scenes/main.tscn").instantiate()
		root.add_child(main)
		for _i in 3:
			await process_frame
		await main.call("begin")
		for _i in 5:
			await process_frame
		var p: Node3D = root.get_node("Game").get("player")
		var n := _meshes(p.get("model")) if p != null and p.get("model") != null else 0
		print("soldaat=%s zichtbare meshes=%d" % [soldaat, n])
		if n < 3:
			failures.append("speler onzichtbaar bij soldaat=" + soldaat)
		main.queue_free()
		await process_frame
	for f in failures:
		push_error(f)
	quit(1 if failures.size() > 0 else 0)
