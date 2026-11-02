extends SceneTree
## Het updatescherm draait ook als "brug" bovenop een oude IPA (apps met de oude updater). Een IPA heeft scripts als ota_keten.gd en
## soldier_model.player_status nog niet; een preload of directe verwijzing ernaar maakt dat het hele scherm niet meer laadt en je niet
## meer in het updatemenu komt (v174, 2 november 2026). De echte controle op een IPA staat in de workflow (tools/ota_brug_simulatie.sh);
## dit is de snelle controle vooraf.
## godot --headless --path . -s tests/ota_brug_test.gd

var fails := 0


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


func _initialize() -> void:
	var bron := FileAccess.get_file_as_string("res://scripts/update_panel.gd")
	_check("update_panel.gd leest zijn bron", bron.length() > 1000)
	# regels met alleen commentaar tellen niet
	var preloads := 0
	var directe_verwijzingen := 0
	for regel in bron.split("\n"):
		var r := regel.strip_edges()
		if r.begins_with("#") or r.begins_with("##"):
			continue
		if r.contains("preload("):
			preloads += 1
		if r.contains("OtaKeten") or r.contains("SoldierModel.player_status"):
			directe_verwijzingen += 1
	_check("geen preload in het updatescherm (een IPA mist die scripts)", preloads == 0)
	_check("geen directe verwijzing naar ota_keten of player_status", directe_verwijzingen == 0)
	# in het volledige project komen de extra regels er wel in
	var regels: String = (load("res://scripts/update_panel.gd") as GDScript).call("_extra_regels")
	var keten_status := str((load("res://scripts/ota_keten.gd") as GDScript).get("status"))
	_check("extra regels bevatten de status van de zware keten", regels.contains(keten_status))
	var speler_status := str((load("res://scripts/soldier_model.gd") as GDScript).get("player_status"))
	_check("extra regels bevatten de spelerstatus", regels.contains(speler_status))
	print("klaar, fouten: ", fails)
	quit(1 if fails > 0 else 0)
