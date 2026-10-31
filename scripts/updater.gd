extends Node
## Updates zonder nieuwe IPA ("over the air"): een kleine patch (.pck) met alleen de gewijzigde bestanden t.o.v. de gebouwde app.
## Dit is de EERSTE autoload: een goedgekeurde patch wordt geladen voordat Game en Sfx en de rest starten, dus ook die scripts
## en alle modellen, texturen, scènes en data kunnen via een patch veranderen. Engine- en iOS-code (en het icoon) kunnen dat niet.
##
## Bron: de GitHub-release "updates" van deze repository (gebouwd door .github/workflows/ota.yml). De repository is privé, dus de app
## gebruikt een alleen-lezen token dat de gebruiker zelf één keer invult; het staat alleen op dit toestel (user://ota/token.cfg),
## nooit in de IPA of de code. Er verandert niets zonder dat de speler het bevestigt (updatescherm), en na elke start die niet
## stabiel eindigt, valt de app terug op de versie uit de IPA.
##
## Veiligheid: een patch wordt alleen geladen als grootte en SHA-256 uit het manifest kloppen en de patch bij deze app hoort
## (zelfde "base"). Alleen resources en GDScript uit onze eigen release; geen willekeurige externe code.

signal status_changed
signal update_beschikbaar(manifest: Dictionary)

const REPO := "boodschappenmaatje/Bloedjungle-godot"
const RELEASE_TAG := "updates"
const ONSTABIEL_MAX := 2  # zoveel starts achter elkaar die niet stabiel eindigen, dan wordt de patch teruggedraaid
const STABIEL_NA := 20.0  # seconden spelen waarna een start als gelukt telt
const TIMEOUT := 30.0
const DOWNLOAD_TIMEOUT := 600.0  # Grote iOS-patches (>250 MB) kunnen minuten duren.

var api_basis := "https://api.github.com"  # in tests een lokale server
var ota_dir := "user://ota"
var app_info_pad := "res://build_info.json"

var app_base := "dev"  # basis-commit waar de patches van afgeleid zijn (staat in de IPA, uit build_info.json)
var app_gebouwd := 0  # tijdstip (epoch) waarop de IPA is gebouwd
var actief: Dictionary = {}  # de geladen patch: {versie, bestand, sha256, grootte, base, gebouwd}
var patch_geladen := false
var teruggedraaid_reden := ""  # niet leeg als de patch bij de start is afgekeurd of teruggedraaid
var manifest: Dictionary = {}  # het laatst opgehaalde manifest
var status := "geen_token"  # geen_token, bezig, actueel, beschikbaar, app_te_oud, geen_bouwinfo, fout, gedownload
var status_tekst := ""
var voortgang := 0.0
var herstart_nodig := false


## Normaal zonder argumenten (autoload). Tests geven een eigen map en zetten de start uit.
func _init(map := "user://ota", start := true) -> void:
	ota_dir = map
	if start:
		opstarten()


func opstarten() -> void:
	DirAccess.make_dir_recursive_absolute(ota_dir)
	_lees_bouwinfo()
	_pas_actieve_patch_toe()
	_zet_status_na_start()


func _ready() -> void:
	# stabiel genoeg gedraaid: de teller voor "niet goed opgestart" gaat terug naar nul
	get_tree().create_timer(STABIEL_NA).timeout.connect(markeer_stabiel)
	# één keer per start, na het laden van het menu, stil kijken of er iets nieuws is (alleen als er een token is)
	if token() != "" and app_base != "dev":
		get_tree().create_timer(4.0).timeout.connect(func(): controleer(true))


# ------------------------------------------------------------------ bouwinfo en actieve patch

func _lees_bouwinfo() -> void:
	# Hoort bij de IPA zelf: lezen vóór een patch geladen wordt, want een patch bevat ook een build_info.json.
	if not FileAccess.file_exists(app_info_pad):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(app_info_pad))
	if d is Dictionary:
		app_base = str(d.get("base", "dev"))
		app_gebouwd = int(d.get("gebouwd", 0))


func _pad(naam: String) -> String:
	return ota_dir.path_join(naam)


func _lees_json(pad: String) -> Dictionary:
	if not FileAccess.file_exists(pad):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(pad))
	return d if d is Dictionary else {}


func _schrijf_json(pad: String, d: Dictionary) -> void:
	var f := FileAccess.open(pad, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d))


func _pas_actieve_patch_toe() -> void:
	actief = _lees_json(_pad("actief.json"))
	if actief.is_empty():
		return
	# crashbeveiliging: te vaak achter elkaar niet stabiel gestart -> terug naar de app-versie
	var onstabiel := int(_lees_json(_pad("opstart.json")).get("onstabiel", 0))
	if onstabiel >= ONSTABIEL_MAX:
		_deactiveer("de app startte %d keer niet goed met deze update" % onstabiel)
		return
	_schrijf_json(_pad("opstart.json"), {"onstabiel": onstabiel + 1})
	var reden := controleer_patchbestand(actief)
	if reden != "":
		_deactiveer(reden)
		return
	if str(actief.get("base", "")) != app_base:
		_deactiveer("deze update hoort bij een andere app-versie")
		return
	patch_geladen = ProjectSettings.load_resource_pack(str(actief.bestand), true)
	if not patch_geladen:
		_deactiveer("Godot kon de update niet laden")


## Klopt het bestand van een patch (bestaat, grootte, SHA-256)? Geeft "" als het goed is, anders de reden.
func controleer_patchbestand(d: Dictionary) -> String:
	var pad := str(d.get("bestand", ""))
	if pad == "" or not FileAccess.file_exists(pad):
		return "het updatebestand ontbreekt"
	var f := FileAccess.open(pad, FileAccess.READ)
	if f == null or int(d.get("grootte", -1)) != f.get_length():
		return "het updatebestand heeft de verkeerde grootte"
	f = null
	if FileAccess.get_sha256(pad) != str(d.get("sha256", "")):
		return "het updatebestand is beschadigd (SHA-256 klopt niet)"
	return ""


func _deactiveer(reden: String) -> void:
	teruggedraaid_reden = reden
	patch_geladen = false
	var oud := actief.duplicate()
	actief = {}
	DirAccess.remove_absolute(_pad("actief.json"))
	_schrijf_json(_pad("opstart.json"), {"onstabiel": 0})
	_schrijf_json(_pad("laatste_terugdraai.json"), {"reden": reden, "patch": oud.get("versie", "?")})
	if oud.has("bestand") and FileAccess.file_exists(str(oud.bestand)):
		DirAccess.remove_absolute(str(oud.bestand))
	push_warning("Updater: terug naar de app-versie: " + reden)


func markeer_stabiel() -> void:
	_schrijf_json(_pad("opstart.json"), {"onstabiel": 0})


func _zet_status_na_start() -> void:
	if app_base == "dev":
		status = "geen_bouwinfo"
		status_tekst = "Dit is een ontwikkelbuild (geen bouwinfo): updates staan uit."
	elif token() == "":
		status = "geen_token"
		status_tekst = "Vul een toegangstoken in om updates te kunnen ophalen."
	else:
		status = "actueel"
		status_tekst = "Nog niet gecontroleerd."
	if teruggedraaid_reden != "":
		status_tekst = "De update is teruggedraaid: " + teruggedraaid_reden + "."


# ------------------------------------------------------------------ token

func token() -> String:
	var cf := ConfigFile.new()
	if cf.load(_pad("token.cfg")) == OK:
		return str(cf.get_value("github", "token", "")).strip_edges()
	return ""


func set_token(t: String) -> void:
	var cf := ConfigFile.new()
	cf.set_value("github", "token", t.strip_edges())
	cf.save(_pad("token.cfg"))
	_zet_status_na_start()
	status_changed.emit()


# ------------------------------------------------------------------ beoordelen van een manifest

## "beschikbaar", "actueel" of "app_te_oud" (de patch is gemaakt voor een andere app-versie), "fout" bij een rommelig manifest.
func beoordeel(m: Dictionary) -> String:
	for k in ["versie", "base", "gebouwd", "pck"]:
		if not m.has(k):
			return "fout"
	var p: Variant = m.pck
	if not (p is Dictionary) or not (p as Dictionary).has("naam") or not (p as Dictionary).has("sha256") or not (p as Dictionary).has("grootte"):
		return "fout"
	if str(m.base) != app_base:
		return "app_te_oud"
	var huidig := maxi(app_gebouwd, int(actief.get("gebouwd", 0)))
	return "beschikbaar" if int(m.gebouwd) > huidig else "actueel"


# ------------------------------------------------------------------ GitHub (alleen-lezen token)

func _headers(accept: String, met_token := true) -> PackedStringArray:
	var h := PackedStringArray(["Accept: " + accept, "User-Agent: Bloedjungle-app", "X-GitHub-Api-Version: 2022-11-28"])
	if met_token:
		h.append("Authorization: Bearer " + token())
	return h


## Eén aanvraag. max_redirects 0, zodat we de doorverwijzing zelf volgen (zonder token naar de opslagserver te sturen).
func _vraag(url: String, headers: PackedStringArray, naar_bestand := "") -> Dictionary:
	var r := HTTPRequest.new()
	r.timeout = DOWNLOAD_TIMEOUT if naar_bestand != "" else TIMEOUT
	r.max_redirects = 0
	if naar_bestand != "":
		r.download_file = naar_bestand
	add_child(r)
	var err := r.request(url, headers)
	if err != OK:
		r.queue_free()
		return {"result": -1, "code": -1, "fout": "kon de aanvraag niet starten (%d)" % err}
	var res: Array = await r.request_completed
	var timer_bytes := r.get_downloaded_bytes()
	r.queue_free()
	var kop := {}
	for h in res[2] as PackedStringArray:
		var i := h.find(":")
		if i > 0:
			kop[h.substr(0, i).strip_edges().to_lower()] = h.substr(i + 1).strip_edges()
	return {"result": res[0], "code": res[1], "headers": kop, "body": res[3], "bytes": timer_bytes}


## Een bestand uit de release ophalen: eerst de API (met token), dan de doorverwijzing (zonder token).
func _haal_asset(asset_url: String, naar_bestand := "") -> Dictionary:
	# Also stream the FIRST GitHub API response to disk. A release asset
	# request can return HTTP 200 directly rather than 302; buffering a
	# 250 MB response in a PackedByteArray could exhaust iOS memory.
	var a: Dictionary = await _vraag(asset_url, _headers("application/octet-stream"), naar_bestand)
	var loc := str(a.get("headers", {}).get("location", ""))
	if int(a.get("code", -1)) in [301, 302, 303, 307, 308] and loc != "":
		# Discard any redirect response file. Never forward the GitHub token
		# to the blob-storage host that actually serves the release asset.
		if naar_bestand != "" and FileAccess.file_exists(naar_bestand):
			DirAccess.remove_absolute(naar_bestand)
		return await _vraag(loc, _headers("application/octet-stream", false), naar_bestand)
	return a


func _download_fout(res: Dictionary) -> String:
	var code := int(res.get("code", -1))
	var result := int(res.get("result", -1))
	if result == HTTPRequest.RESULT_TIMEOUT:
		return "time-out bij grote download"
	if result == HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN:
		return "kon downloadbestand niet openen (opslag)"
	if result == HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
		return "kon downloadbestand niet schrijven (opslagruimte)"
	if result != HTTPRequest.RESULT_SUCCESS:
		return str(res.get("fout", "netwerkfout (code %d)" % result))
	if code in [401, 403, 404]:
		return "GitHub-toegang geweigerd (HTTP %d)" % code
	if code > 0:
		return "HTTP %d" % code
	return "geen verbinding"


func _zet(s: String, tekst: String, v := 0.0) -> void:
	status = s
	status_tekst = tekst
	voortgang = v
	status_changed.emit()


## Kijkt in de release "updates" of er een nieuwere patch voor deze app is. stil = geen foutmelding in beeld bij geen netwerk.
func controleer(stil := false) -> void:
	if app_base == "dev":
		_zet("geen_bouwinfo", "Dit is een ontwikkelbuild (geen bouwinfo): updates staan uit.")
		return
	if token() == "":
		_zet("geen_token", "Vul een toegangstoken in om updates te kunnen ophalen.")
		return
	_zet("bezig", "Controleren op updates…")
	var rel: Dictionary = await _vraag("%s/repos/%s/releases/tags/%s" % [api_basis, REPO, RELEASE_TAG], _headers("application/vnd.github+json"))
	if int(rel.get("code", -1)) != 200:
		var c := int(rel.get("code", -1))
		var uitleg := "geen verbinding" if c <= 0 else ("het token is ongeldig of mist rechten (%d)" % c if c in [401, 403, 404] else "GitHub antwoordde %d" % c)
		_zet("fout" if not stil else "actueel", "Updates controleren mislukt: " + uitleg + ".")
		return
	var r: Variant = JSON.parse_string((rel.body as PackedByteArray).get_string_from_utf8())
	if not (r is Dictionary) or not (r as Dictionary).has("assets"):
		_zet("fout", "Updates controleren mislukt: onverwacht antwoord van GitHub.")
		return
	var assets := {}
	for a in (r as Dictionary).assets:
		assets[str(a.name)] = a
	if not assets.has("manifest.json"):
		_zet("actueel", "Er staat nog geen update klaar.")
		return
	var mp: Dictionary = await _haal_asset(str(assets["manifest.json"].url))
	var m: Variant = JSON.parse_string((mp.get("body", PackedByteArray()) as PackedByteArray).get_string_from_utf8()) if int(mp.get("code", -1)) == 200 else null
	if not (m is Dictionary):
		_zet("fout", "Updates controleren mislukt: manifest niet te lezen.")
		return
	manifest = m
	manifest["_asset_url"] = str(assets.get(str(manifest.get("pck", {}).get("naam", "")), {}).get("url", ""))
	match beoordeel(manifest):
		"beschikbaar":
			var mb := float(int(manifest.pck.grootte)) / 1048576.0
			_zet("beschikbaar", "Update beschikbaar: %s (%.1f MB)." % [str(manifest.versie), mb])
			update_beschikbaar.emit(manifest)
		"app_te_oud":
			_zet("app_te_oud", "Er is een update, maar voor een nieuwere app. Installeer eerst de nieuwste IPA via AltStore.")
		"actueel":
			_zet("actueel", "Je hebt de nieuwste update.")
		_:
			_zet("fout", "Het manifest klopt niet; de update wordt niet gebruikt.")


## Downloadt de patch uit het laatste manifest, controleert grootte en SHA-256 en zet hem klaar voor de volgende start.
func download_en_installeer() -> void:
	if status != "beschikbaar" or manifest.is_empty() or str(manifest.get("_asset_url", "")) == "":
		return
	var p: Dictionary = manifest.pck
	var tmp := _pad("download.tmp")
	DirAccess.remove_absolute(tmp)
	_zet("bezig", "Downloaden… (%.1f MB)" % (float(int(p.grootte)) / 1048576.0))
	var res: Dictionary = await _haal_asset(str(manifest._asset_url), tmp)
	if int(res.get("code", -1)) != 200 or int(res.get("result", -1)) != HTTPRequest.RESULT_SUCCESS:
		DirAccess.remove_absolute(tmp)
		_zet("fout", "Downloaden mislukt (%s)." % _download_fout(res))
		return
	var fout := installeer(tmp, manifest)
	if fout != "":
		_zet("fout", "De update is afgekeurd: " + fout + ".")
		return
	_zet("gedownload", "Update %s staat klaar. Sluit de app helemaal af en open hem opnieuw om hem te gebruiken." % str(manifest.versie))


## Controleert een gedownload bestand tegen het manifest en maakt het de actieve patch (voor de volgende start).
## Geeft "" bij succes, anders de reden van afkeuren. De vorige patch wordt vervangen.
func installeer(tmp_pad: String, m: Dictionary) -> String:
	if beoordeel(m) not in ["beschikbaar", "actueel"]:
		return "het manifest hoort niet bij deze app"
	var p: Dictionary = m.pck
	var naam := str(p.naam).get_file()
	if not naam.ends_with(".pck") or naam.contains(".."):
		return "ongeldige bestandsnaam"
	var d := {"versie": str(m.versie), "bestand": _pad(naam), "sha256": str(p.sha256), "grootte": int(p.grootte), "base": str(m.base), "gebouwd": int(m.gebouwd)}
	var f := FileAccess.open(tmp_pad, FileAccess.READ)
	if f == null or f.get_length() != int(p.grootte):
		return "de grootte klopt niet"
	f = null
	if FileAccess.get_sha256(tmp_pad) != str(p.sha256):
		return "SHA-256 klopt niet"
	# oude patchbestanden opruimen, de nieuwe op zijn plek zetten
	var oud := _lees_json(_pad("actief.json"))
	if DirAccess.rename_absolute(tmp_pad, str(d.bestand)) != OK:
		return "kon het bestand niet opslaan"
	if oud.has("bestand") and str(oud.bestand) != str(d.bestand) and FileAccess.file_exists(str(oud.bestand)):
		DirAccess.remove_absolute(str(oud.bestand))
	_schrijf_json(_pad("actief.json"), d)
	_schrijf_json(_pad("opstart.json"), {"onstabiel": 0})
	herstart_nodig = true
	return ""


## De patch uitzetten: bij de volgende start draait de app weer precies zoals in de IPA.
func terugdraaien() -> void:
	var oud := _lees_json(_pad("actief.json"))
	DirAccess.remove_absolute(_pad("actief.json"))
	if oud.has("bestand") and FileAccess.file_exists(str(oud.bestand)):
		DirAccess.remove_absolute(str(oud.bestand))
	herstart_nodig = true
	_zet("actueel", "Teruggezet naar de app-versie. Sluit de app helemaal af en open hem opnieuw.")
