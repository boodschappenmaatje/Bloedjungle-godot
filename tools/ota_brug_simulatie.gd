extends SceneTree
## Bootst na wat een iPhone doet met de BRUG: de IPA (--main-pack <iOS-basis>) met alleen het nieuwe updatescherm (brug.pck) als actieve patch.
## Het updatescherm moet dan laden en zich opbouwen op een oude IPA, want via dat scherm haal je daarna de echte update op. Laadt het niet
## (bijvoorbeeld omdat het een script nodig heeft dat pas na de IPA is gemaakt), dan kom je niet meer in het updatemenu.
## Gebruik via tools/ota_brug_simulatie.sh. Verwijst bewust NIET naar klassen uit het project (class_name), alleen load() en dynamische aanroepen.

var fouten: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var updater = root.get_node_or_null("Updater")
	_eis(updater != null, "geen Updater-autoload")
	if updater != null:
		_eis(bool(updater.get("patch_geladen")), "de brug is niet geladen (Updater: %s)" % str(updater.get("status_tekst")))
	var s = load("res://scripts/update_panel.gd")
	var laadt: bool = s != null and s.can_instantiate()
	_eis(laadt, "het updatescherm uit de brug laadt niet op de IPA (compileert niet)")
	if laadt:
		var p: Node = s.new()
		root.add_child(p)
		for _i in 3:
			await process_frame
		var info := str(p.get("_info").text) if p.get("_info") != null else ""
		print("SIM brug-scherm: ", info.replace("\n", " | "))
		_eis(info != "", "het updatescherm bouwt zijn infovak niet op")
		_eis(p.find_children("*", "Button", true, false).size() >= 5, "het updatescherm mist zijn knoppen")
		p.queue_free()
		await process_frame
	for f in fouten:
		printerr("OTA_SIM_FOUT: ", f)
	print("OTA_SIM_BRUG_%s" % ("OK" if fouten.is_empty() else "MISLUKT"))
	quit(0 if fouten.is_empty() else 1)


func _eis(ok: bool, msg: String) -> void:
	if not ok:
		fouten.append(msg)
