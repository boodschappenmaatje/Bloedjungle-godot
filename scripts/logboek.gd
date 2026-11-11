class_name Logboek
extends Node
## Foutenlogboek op afstand. Game zet deze knoop bij de start neer (geen eigen autoload: een nieuwe autoload in project.godot
## komt niet mee met een OTA-update). Hij schrijft de laatste minuten mee:
##  - foutmeldingen en waarschuwingen van Godot en de scripts (via een eigen Logger, ontdubbeld met een teller),
##  - om de 2 s een meting: fps (gemiddeld en slechtste beeld), spelstand, groep, positie, soldaten, vijanden, voertuig,
##  - recente acties: bevelen, start/einde, de meldingen in beeld (banners).
## Er gaat NIETS vanzelf weg. Alleen als je op "Meld probleem" tikt wordt het pakketje naar het Supabase-project gestuurd
## (MeldingenConfig). Liep het spel de vorige keer vast of waren er fouten, dan biedt het hoofdmenu één keer aan om die
## vorige sessie te melden. Lukt versturen niet (geen netwerk, project gepauzeerd), dan blijft het pakketje in een wachtrij
## en gaat het bij de volgende start alsnog. Geen naam, account of andere persoonlijke gegevens: zie docs/MELDINGEN.md.

signal verstuurd(ok: bool, uitleg: String)

const BEWAAR_S := 300.0        # zo lang terug bewaren we metingen en acties (5 minuten)
const MAX_FOUTEN := 80         # verschillende foutmeldingen (elke herhaling telt alleen op)
const MAX_ACTIES := 150
const MEET_S := 2.0
const OPSLAAN_S := 10.0
const MAP := "user://logboek"
const HUIDIG := MAP + "/huidig.json"
const VORIG := MAP + "/vorige.json"
const WACHTRIJ := MAP + "/wachtrij"
const MAX_WACHTRIJ := 5
var config_pad := "res://scripts/meldingen_config.gd"   # tests wijzen een andere (onbereikbare) meldplek aan

static var inst: Logboek

var start_tijd := 0.0           # Time.get_unix_time_from_system() bij de start
var fouten: Array = []          # {t, soort, bericht, plek, aantal, laatst}
var acties: Array = []          # {t, tekst}
var metingen: Array = []        # {t, fps, min_fps, stand, groep, pos, soldaten, vijanden, voertuig}
var vorige: Dictionary = {}     # de vorige sessie als die vastliep of fouten had (en nog niet gemeld/afgewezen)
var bezig := false              # er loopt een verzending

var _mutex := Mutex.new()
var _logger: FoutVanger
var _meet_t := 0.0
var _opslaan_t := 0.0
var _slechtste_ms := 0.0
var _beelden := 0
var _beeld_s := 0.0
var _laatst := {}               # vorige waarden van stand/bevel om veranderingen als actie te zien
var _http: HTTPRequest
var _wachtrij_bezig := ""


## Vangt alle fout- en waarschuwingsregels van de engine. Wordt vanuit elke thread aangeroepen: alleen kort in de rij zetten.
class FoutVanger extends Logger:
	var boek: WeakRef

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		var b := boek.get_ref() as Logboek
		if b == null:
			return
		var soort: String = ["fout", "waarschuwing", "scriptfout", "shaderfout"][clampi(error_type, 0, 3)]
		var tekst := rationale if rationale != "" else code
		var plek := "%s:%d %s" % [file.get_file(), line, function]
		var spoor := ""
		for bt in script_backtraces:
			if bt != null and not bt.is_empty():
				spoor = bt.format().left(800)
				break
		b.noteer_fout(soort, tekst, plek, spoor)

	func _log_message(message: String, error: bool) -> void:
		if not error:
			return
		var b := boek.get_ref() as Logboek
		if b != null:
			b.noteer_fout("stderr", message.strip_edges(), "", "")


static func actie(tekst: String) -> void:
	if inst != null:
		inst.noteer_actie(tekst)


func _ready() -> void:
	inst = self
	name = "Logboek"
	process_mode = Node.PROCESS_MODE_ALWAYS
	start_tijd = Time.get_unix_time_from_system()
	DirAccess.make_dir_recursive_absolute(WACHTRIJ)
	_lees_vorige()
	_logger = FoutVanger.new()
	_logger.boek = weakref(self)
	OS.add_logger(_logger)
	_http = HTTPRequest.new()
	_http.timeout = 20.0
	add_child(_http)
	_http.request_completed.connect(_klaar)
	Game.banner.connect(func(big: String, small: String, _t: float): noteer_actie("melding: %s %s" % [big, small]))
	Game.over.connect(func(reden: String): noteer_actie("einde: %s (%s)" % [reden, "gewonnen" if Game.won else "verloren"]))
	noteer_actie("start %s op %s" % [_versie(), OS.get_name()])
	_opslaan(false)
	# Wat de vorige keer niet weg kon, nu alsnog (een paar seconden later, zodat het opstarten er geen last van heeft).
	get_tree().create_timer(8.0, true, false, true).timeout.connect(_wachtrij_versturen)


func _exit_tree() -> void:
	if _logger != null:
		OS.remove_logger(_logger)
	_opslaan(true)
	if inst == self:
		inst = null


func _notification(what: int) -> void:
	# Naar de achtergrond of afsluiten: netjes opslaan. Een app die op de achtergrond wordt opgeruimd is geen vastloper.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_opslaan(true)
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_opslaan(false)


func _process(delta: float) -> void:
	_beelden += 1
	_beeld_s += delta
	_slechtste_ms = maxf(_slechtste_ms, delta * 1000.0)
	_meet_t += delta
	if _meet_t >= MEET_S:
		_meet_t = 0.0
		_meet()
	_opslaan_t += delta
	if _opslaan_t >= OPSLAAN_S:
		_opslaan_t = 0.0
		_opslaan(false)


# ---------------------------------------------------------------- meeschrijven

func _nu() -> float:
	return snappedf(Time.get_unix_time_from_system() - start_tijd, 0.1)


func noteer_fout(soort: String, tekst: String, plek: String, spoor: String) -> void:
	if tekst == "":
		return
	tekst = tekst.left(600)
	_mutex.lock()
	var t := Time.get_unix_time_from_system() - start_tijd
	var gevonden := false
	for f in fouten:
		if f.bericht == tekst and f.plek == plek:
			f.aantal += 1
			f.laatst = snappedf(t, 0.1)
			gevonden = true
			break
	if not gevonden:
		fouten.append({"t": snappedf(t, 0.1), "laatst": snappedf(t, 0.1), "soort": soort, "bericht": tekst, "plek": plek, "spoor": spoor, "aantal": 1})
		if fouten.size() > MAX_FOUTEN:
			fouten.pop_front()
	_mutex.unlock()


func noteer_actie(tekst: String) -> void:
	acties.append({"t": _nu(), "tekst": tekst.left(200)})
	while acties.size() > MAX_ACTIES:
		acties.pop_front()


func _meet() -> void:
	var stand := str(Game.state)
	if get_tree().paused:
		stand += "/pauze"
	var soldaten := 0
	for a in Game.allies:
		if is_instance_valid(a):
			soldaten += 1
	var vijanden := 0
	for e in Game.enemies:
		if is_instance_valid(e):
			vijanden += 1
	var pos := []
	var voertuig := ""
	var hp := -1
	if is_instance_valid(Game.player) and Game.player is Node3D:
		var p: Vector3 = (Game.player as Node3D).global_position
		pos = [snappedf(p.x, 0.1), snappedf(p.y, 0.1), snappedf(p.z, 0.1)]
		hp = int(Game.player.get("hp")) if Game.player.get("hp") != null else -1
		if Game.player.get("driving"):
			voertuig = "jeep"
		elif Game.player.get("in_tank"):
			voertuig = "tank"
		elif Game.player.get("airborne"):
			voertuig = "lucht"
		if Game.player.get("dead"):
			voertuig = "dood"
	var fps := (_beelden / _beeld_s) if _beeld_s > 0.0 else 0.0
	metingen.append({"t": _nu(), "fps": snappedf(fps, 0.1), "min_fps": snappedf(1000.0 / maxf(_slechtste_ms, 0.001), 0.1),
		"stand": stand, "groep": Game.wave, "pos": pos, "hp": hp, "soldaten": soldaten, "vijanden": vijanden,
		"voertuig": voertuig, "bevel": str(Game.squad_order)})
	_beelden = 0
	_beeld_s = 0.0
	_slechtste_ms = 0.0
	var grens := _nu() - BEWAAR_S
	while not metingen.is_empty() and metingen[0].t < grens:
		metingen.pop_front()
	while not acties.is_empty() and acties[0].t < grens and acties.size() > 20:
		acties.pop_front()
	# veranderingen in spelstand en groepsbevel zijn ook acties
	for k in ["state", "squad_order", "troop_mode", "wave"]:
		var w := str(Game.get(k))
		if _laatst.has(k) and _laatst[k] != w:
			noteer_actie("%s: %s -> %s" % [k, _laatst[k], w])
		_laatst[k] = w


# ---------------------------------------------------------------- pakketje

func _versie() -> String:
	return str(load("res://scripts/hud.gd").VERSION)


func pakket(oorzaak: String, tekst: String) -> Dictionary:
	_mutex.lock()
	var f := fouten.duplicate(true)
	_mutex.unlock()
	var scherm := DisplayServer.screen_get_size() if DisplayServer.get_name() != "headless" else Vector2i.ZERO
	var inst_keys := ["quality", "upscaling", "hz", "g2", "perf", "soldaat", "treeshadow", "buildshadow"]
	var instellingen := {}
	for k in inst_keys:
		instellingen[k] = str(GameSettings.get_value(k))
	return {
		"versie": _versie(),
		"oorzaak": oorzaak,
		"tekst": tekst.left(1500),
		"platform": "%s %s" % [OS.get_name(), OS.get_model_name()],
		"inhoud": {
			"godot": Engine.get_version_info().get("string", ""),
			"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")),
			"gpu": RenderingServer.get_video_adapter_name(),
			"scherm": [scherm.x, scherm.y],
			"venster": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y],
			"sessie_s": _nu(),
			"start_utc": Time.get_datetime_string_from_unix_time(int(start_tijd), true),
			"instellingen": instellingen,
			"ota": str(load("res://scripts/ota_keten.gd").status),
			"fouten": f,
			"acties": acties.duplicate(true),
			"metingen": metingen.duplicate(true),
		},
	}


func _opslaan(schoon: bool) -> void:
	var p := pakket("vorige_sessie", "")
	p["schoon"] = schoon
	var fa := FileAccess.open(HUIDIG, FileAccess.WRITE)
	if fa != null:
		fa.store_string(JSON.stringify(p))
		fa.close()


## Bij de start: het bestand van de vorige sessie. Niet netjes afgesloten (vastgelopen/gecrasht) of met fouten = aanbieden.
func _lees_vorige() -> void:
	if not FileAccess.file_exists(HUIDIG):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(HUIDIG))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(HUIDIG))
	if not (d is Dictionary):
		return
	var echte_fouten := 0
	for f in d.get("inhoud", {}).get("fouten", []):
		if str(f.get("soort", "")) != "waarschuwing":
			echte_fouten += 1
	var vastgelopen := not bool(d.get("schoon", true))
	if vastgelopen or echte_fouten > 0:
		d["oorzaak"] = "vastgelopen" if vastgelopen else "fouten_vorige_sessie"
		vorige = d
		var fa := FileAccess.open(VORIG, FileAccess.WRITE)
		if fa != null:
			fa.store_string(JSON.stringify(d))


## Uitleg voor het aanbod in het hoofdmenu ("" = niets aan te bieden).
func vorige_uitleg() -> String:
	if vorige.is_empty():
		return ""
	var n: int = vorige.get("inhoud", {}).get("fouten", []).size()
	var wat := "stopte het spel onverwacht" if vorige.get("oorzaak") == "vastgelopen" else "kwamen er foutmeldingen"
	return "De vorige keer (%s) %s%s." % [str(vorige.get("versie", "?")), wat, (", %d soorten fout" % n) if n > 0 else ""]


func vorige_afwijzen() -> void:
	vorige = {}
	DirAccess.remove_absolute(ProjectSettings.globalize_path(VORIG))


# ---------------------------------------------------------------- versturen

## Stuurt het pakketje (nu, of de vorige sessie). Antwoord komt via het signaal verstuurd.
func meld(tekst: String, van_vorige := false) -> void:
	var p: Dictionary
	if van_vorige and not vorige.is_empty():
		p = vorige.duplicate(true)
		p.erase("schoon")
		p["tekst"] = tekst.left(1500)
		vorige_afwijzen()
	else:
		p = pakket("knop", tekst)
	noteer_actie("melding verstuurd (%s)" % p.oorzaak)
	_naar_wachtrij(p)
	_wachtrij_versturen()


func _naar_wachtrij(p: Dictionary) -> String:
	var pad := "%s/%d_%d.json" % [WACHTRIJ, int(Time.get_unix_time_from_system()), randi() % 10000]
	var fa := FileAccess.open(pad, FileAccess.WRITE)
	if fa != null:
		fa.store_string(JSON.stringify(p))
		fa.close()
	# niet eindeloos opsparen: de oudste vallen eruit
	var lijst := _wachtrij_lijst()
	while lijst.size() > MAX_WACHTRIJ:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(WACHTRIJ + "/" + lijst.pop_front()))
	return pad


func _wachtrij_lijst() -> Array:
	var lijst := Array(DirAccess.get_files_at(WACHTRIJ)).filter(func(n: String): return n.ends_with(".json"))
	lijst.sort()
	return lijst


func wachtrij_aantal() -> int:
	return _wachtrij_lijst().size()


func _wachtrij_versturen() -> void:
	if bezig:
		return
	var lijst := _wachtrij_lijst()
	if lijst.is_empty():
		return
	var cfg: GDScript = load(config_pad)
	var url := str(cfg.URL)
	var sleutel := str(cfg.SLEUTEL)
	if url == "" or sleutel == "":
		verstuurd.emit(false, "Er is nog geen meldplek ingesteld; de melding staat bewaard op dit toestel.")
		return
	_wachtrij_bezig = WACHTRIJ + "/" + str(lijst[0])
	var body := FileAccess.get_file_as_string(_wachtrij_bezig)
	var headers := PackedStringArray(["Content-Type: application/json", "apikey: " + sleutel, "Prefer: return=minimal"])
	bezig = true
	var err := _http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		bezig = false
		verstuurd.emit(false, "Versturen kon niet starten (fout %d); de melding staat bewaard en gaat bij de volgende start." % err)


func _klaar(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	bezig = false
	if result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_wachtrij_bezig))
		var rest := wachtrij_aantal()
		verstuurd.emit(true, "Verstuurd. Claude kan hem nu lezen." + (" Nog %d in de wachtrij." % rest if rest > 0 else ""))
		if rest > 0:
			_wachtrij_versturen.call_deferred()
	elif result == HTTPRequest.RESULT_SUCCESS and code >= 400 and code < 500 and code != 408 and code != 429:
		# de database weigert dit pakketje (bijv. te groot): niet blijven proberen
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_wachtrij_bezig))
		verstuurd.emit(false, "De meldplek weigerde de melding (code %d): %s" % [code, body.get_string_from_utf8().left(120)])
	else:
		verstuurd.emit(false, "Geen verbinding (code %d/%d). De melding staat bewaard en gaat bij de volgende start." % [result, code])
