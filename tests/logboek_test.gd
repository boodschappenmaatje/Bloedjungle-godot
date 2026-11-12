extends SceneTree
## Test van het foutenlogboek op afstand (scripts/logboek.gd, knop "Meld probleem"):
##  1. Game zet het logboek neer (geen nieuwe autoload, want die komt niet mee met OTA)
##  2. foutmeldingen worden gevangen en ontdubbeld (teller), waarschuwingen apart
##  3. om de 2 s een meting met fps, spelstand en positie; acties (bevel, banner) komen in de lijst
##  4. het pakketje heeft versie, platform, fouten, acties en metingen en blijft klein
##  5. een niet netjes afgesloten vorige sessie wordt herkend en aangeboden; een nette sessie zonder fouten niet
##  6. zonder verbinding blijft de melding in de wachtrij (max 5) en er gaat niets vanzelf weg
##  7. het meldscherm in het menu: knop MELDEN, scherm open, TERUG wijst het aanbod af
## godot --headless --path . --script tests/logboek_test.gd
## Met BLOEDJUNGLE_MELD_ECHT=1 gaat er ook één echte testmelding (oorzaak "test") naar het Supabase-project.

var fails := 0
var LB: GDScript   # scripts/logboek.gd, pas na de start geladen (de autoload Game bestaat dan)
var _watchdog := 0


func _initialize() -> void:
	call_deferred("_run")


func _process(_d: float) -> bool:
	_watchdog += 1
	if _watchdog > 20000:
		push_error("Logboektest hangt")
		quit(99)
	return false


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _wachtrij_leeg() -> void:
	for f in DirAccess.get_files_at(LB.WACHTRIJ):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LB.WACHTRIJ + "/" + f))


func _run() -> void:
	await _frames(3)
	LB = load("res://scripts/logboek.gd")
	var game := root.get_node("Game")
	var G := game
	var boek: Node = LB.inst
	_check("1 Game zet het logboek neer", boek != null and boek.get_parent() == game)
	_check("1 geen eigen autoload in project.godot", not FileAccess.get_file_as_string("res://project.godot").contains("logboek"))
	if boek == null:
		quit(1)
		return
	_wachtrij_leeg()

	# 2 fouten vangen en ontdubbelen
	var voor: int = boek.fouten.size()
	for i in 3:
		push_error("logboektest kapot %d" % 7)
	push_warning("logboektest let op")
	await _frames(2)
	var kapot: Array = boek.fouten.filter(func(f): return str(f.bericht).contains("logboektest kapot"))
	_check("2 fout gevangen", kapot.size() == 1)
	_check("2 herhaling telt op (3x)", kapot.size() == 1 and int(kapot[0].aantal) == 3)
	var waarsch: Array = boek.fouten.filter(func(f): return str(f.bericht).contains("logboektest let op"))
	_check("2 waarschuwing apart gemarkeerd", waarsch.size() == 1 and waarsch[0].soort == "waarschuwing")
	_check("2 fouten erbij", boek.fouten.size() >= voor + 2)
	for i in 120:
		push_error("logboektest veel %d" % i)
	_check("2 maximaal %d verschillende fouten" % LB.MAX_FOUTEN, boek.fouten.size() <= LB.MAX_FOUTEN)

	# 3 metingen en acties
	G.state = "prep"
	boek._meet_t = LB.MEET_S
	await _frames(3)
	_check("3 meting gedaan", not boek.metingen.is_empty())
	var m: Dictionary = boek.metingen.back() if not boek.metingen.is_empty() else {}
	_check("3 meting heeft fps, stand en soldaten", m.has("fps") and m.get("stand", "") == "prep" and m.has("soldaten") and m.has("pos"))
	LB.actie("bevel attack aan 4 eenheden")
	G.banner.emit("TANK VAST", "test", 1.0)
	G.state = "play"
	var teksten: Array = boek.acties.map(func(a): return str(a.tekst))
	_check("3 bevel als actie", teksten.has("bevel attack aan 4 eenheden"))
	_check("3 banner als actie", teksten.any(func(t): return t.contains("TANK VAST")))
	boek._meet_t = LB.MEET_S
	await _frames(2)
	teksten = boek.acties.map(func(a): return str(a.tekst))
	_check("3 spelstand-wissel als actie", teksten.any(func(t): return t.begins_with("state: ")))

	# 4 pakketje
	var p: Dictionary = boek.pakket("knop", "de tank bleef hangen")
	var versie := str(load("res://scripts/hud.gd").VERSION)
	_check("4 versie " + versie, p.versie == versie)
	_check("4 velden voor de tabel", p.has_all(["versie", "oorzaak", "tekst", "platform", "inhoud"]) and p.size() == 5)
	_check("4 inhoud", p.inhoud.has_all(["fouten", "acties", "metingen", "instellingen", "godot", "sessie_s"]))
	var json := JSON.stringify(p)
	_check("4 klein genoeg (%d bytes)" % json.length(), json.length() < 300000)
	_check("4 geen spelernaam of score-namen", not json.contains("\"naam\"") and not json.contains("scores"))

	# 5 vorige sessie
	var nep: Dictionary = boek.pakket("vorige_sessie", "")
	nep["schoon"] = false
	var fa := FileAccess.open(LB.HUIDIG, FileAccess.WRITE)
	fa.store_string(JSON.stringify(nep))
	fa.close()
	boek.vorige = {}
	boek._lees_vorige()
	_check("5 vastgelopen sessie herkend", boek.vorige.get("oorzaak", "") == "vastgelopen")
	_check("5 uitleg voor het menu", boek.vorige_uitleg().contains("onverwacht"))
	nep = {"versie": "v1", "schoon": true, "inhoud": {"fouten": [{"soort": "waarschuwing"}]}}
	fa = FileAccess.open(LB.HUIDIG, FileAccess.WRITE)
	fa.store_string(JSON.stringify(nep))
	fa.close()
	boek.vorige = {}
	boek._lees_vorige()
	_check("5 nette sessie met alleen waarschuwingen: geen aanbod", boek.vorige.is_empty() and boek.vorige_uitleg() == "")
	boek._opslaan(false)

	# 6 wachtrij zonder verbinding
	var echt_pad: String = boek.config_pad
	boek.config_pad = "res://tests/logboek_config_onbereikbaar.gd"
	_wachtrij_leeg()
	var antwoord := []
	boek.verstuurd.connect(func(ok, uitleg): antwoord.append([ok, uitleg]))
	boek.meld("test zonder netwerk")
	for i in 600:
		if not antwoord.is_empty():
			break
		await process_frame
	_check("6 antwoord: niet gelukt", not antwoord.is_empty() and antwoord[0][0] == false)
	_check("6 melding blijft bewaard", boek.wachtrij_aantal() == 1)
	for i in 7:
		boek._naar_wachtrij(boek.pakket("knop", "extra %d" % i))
	_check("6 wachtrij maximaal %d" % LB.MAX_WACHTRIJ, boek.wachtrij_aantal() == LB.MAX_WACHTRIJ)
	_wachtrij_leeg()
	boek.config_pad = echt_pad

	# 6b optioneel: echte testmelding naar Supabase
	if OS.get_environment("BLOEDJUNGLE_MELD_ECHT") == "1":
		antwoord.clear()
		boek._naar_wachtrij(boek.pakket("test", "automatische test logboek_test.gd"))
		boek._wachtrij_versturen()
		for i in 1200:
			if not antwoord.is_empty():
				break
			await process_frame
		_check("6b echte melding aangekomen", not antwoord.is_empty() and antwoord[0][0] == true)
		_check("6b wachtrij weer leeg", boek.wachtrij_aantal() == 0)

	# 7 meldscherm in het menu
	var menu: Node = load("res://scripts/pause_menu.gd").new()
	root.add_child(menu)
	await _frames(2)
	var knoppen := menu.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
	_check("7 tegel MELDEN in het hoofdmenu", knoppen.has("MELDEN"))
	var pauze_knop := menu.find_children("*", "Button", true, false).any(func(b): return (b as Button).text == "Meld probleem")
	_check("7 knop Meld probleem in de pauze", pauze_knop)
	boek.vorige = {"versie": "v0", "oorzaak": "vastgelopen", "inhoud": {"fouten": []}}
	menu.open_melden("menu", true)
	await _frames(2)
	_check("7 meldscherm open", menu._cur == "melden" and menu._meld_intro.text.contains("onverwacht"))
	menu._melden_sluiten()
	_check("7 TERUG wijst het aanbod af", boek.vorige.is_empty() and menu._cur == "menu")
	_check("7 niets vanzelf verstuurd", boek.wachtrij_aantal() == 0)
	menu.queue_free()
	await _frames(2)

	print("Logboektest klaar, fouten: %d" % fails)
	quit(1 if fails > 0 else 0)
