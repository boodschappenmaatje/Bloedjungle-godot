extends SceneTree
## Bootst na wat een iPhone doet met een OTA-update: de IPA (--main-pack <iOS-basis>), het lichte stuk als actieve patch (Updater) en de
## zware stukken (ota_keten), en start dan het spel. Mislukt (exit 1) als de speler geen zichtbaar model heeft of de scripts niet compileren.
## Gebruik via tools/ota_simulatie.sh. Verwijst bewust NIET naar klassen uit het project (class_name): dat compileert scripts te vroeg,
## nog voor de patches zijn aangekoppeld, en geeft een vals alarm. Alles hier gaat met load() en dynamische aanroepen.

var fouten: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _meshes(n: Node) -> int:
	var c := 1 if (n is MeshInstance3D and (n as MeshInstance3D).mesh != null and (n as MeshInstance3D).visible) else 0
	for k in n.get_children():
		c += _meshes(k)
	return c


func _run() -> void:
	var updater = root.get_node_or_null("Updater")
	_eis(updater != null, "geen Updater-autoload")
	if updater != null:
		_eis(bool(updater.get("patch_geladen")), "de lichte patch is niet geladen (Updater: %s)" % str(updater.get("status_tekst")))
	var keten_status := str(load("res://scripts/ota_keten.gd").get("status"))
	print("SIM keten: ", keten_status)
	_eis(keten_status.begins_with("zware stukken geladen"), "de zware keten is niet geladen: " + keten_status)
	var instellingen = load("res://scripts/game_settings.gd")
	for soldaat in ["meshy", "vq2"]:
		instellingen.set_value("soldaat", soldaat)
		var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
		root.add_child(main)
		for _i in 4:
			await process_frame
		main.call("begin")
		for _i in 8:
			await process_frame
		var game = root.get_node_or_null("Game")
		var speler: Node3D = game.get("player") if game != null else null
		var model = speler.get("model") if speler != null else null
		var n := _meshes(model) if model != null else 0
		var status := str(load("res://scripts/soldier_model.gd").get("player_status"))
		print("SIM soldaat=%s zichtbare meshes=%d status=%s" % [soldaat, n, status])
		_eis(n >= 3, "speler onzichtbaar bij soldaat=%s (meshes=%d, status=%s)" % [soldaat, n, status])
		main.queue_free()
		await process_frame
	for f in fouten:
		printerr("OTA_SIM_FOUT: ", f)
	print("OTA_SIM_%s" % ("OK" if fouten.is_empty() else "MISLUKT"))
	quit(0 if fouten.is_empty() else 1)


func _eis(ok: bool, msg: String) -> void:
	if not ok:
		fouten.append(msg)
