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
	var lijst := _actieve_lijst()
	if lijst.is_empty():
		_deactiveer("de update bevat geen patchbestanden")
		return
	for p in lijst:
		var reden := controleer_patchbestand(p)
		if reden != "":
			_deactiveer(reden)
			return
	if str(actief.get("base", "")) != app_base:
		_deactiveer("deze update hoort bij een andere app-versie")
		return
	# de keten wordt in volgorde geladen: elke patch overschrijft wat de vorige al veranderde
	for p in lijst:
		if not ProjectSettings.load_resource_pack(str(p.bestand), true):
			_deactiveer("Godot kon de update niet laden")
			return
	patch_geladen = true


## De geladen patches in volgorde. Oud formaat (één patch direct in actief.json) wordt als keten van één gelezen.
func _actieve_lijst() -> Array:
	var l: Variant = actief.get("patches")
	if l is Array:
		return l
	if actief.has("bestand"):
		return [actief]
	return []


## De patches van een manifest in volgorde. Schema 1 heeft er één (pck), schema 2 de hele keten sinds de IPA (patches).
func manifest_patches(m: Dictionary) -> Array:
	var l: Variant = m.get("patches")
	if l is Array and not (l as Array).is_empty():
		return l
	return [m.pck] if m.get("pck") is Dictionary else []


## Welke patches uit het manifest staan nog niet op dit toestel (in volgorde)? Wijkt de bestaande keten af, dan alles opnieuw.
func ontbrekende_patches(m: Dictionary) -> Array:
	var keten := manifest_patches(m)
	var heb := _actieve_lijst()
	var n := 0
	while n < heb.size() and n < keten.size() and str(heb[n].get("sha256", "")) == str((keten[n] as Dictionary).get("sha256", "x")):
		n += 1
	if n < heb.size():
		n = 0
	return keten.slice(n)


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
	var oude_lijst := _actieve_lijst()
	actief = {}
	DirAccess.remove_absolute(_pad("actief.json"))
	_schrijf_json(_pad("opstart.json"), {"onstabiel": 0})
	_schrijf_json(_pad("laatste_terugdraai.json"), {"reden": reden, "patch": oud.get("versie", "?")})
	for p in oude_lijst:
		if FileAccess.file_exists(str(p.get("bestand", ""))):
			DirAccess.remove_absolute(str(p.bestand))
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
	if not (m.pck is Dictionary):
		return "fout"
	var lijst := manifest_patches(m)
	for p in lijst:
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
	var urls := {}
	for pe in manifest_patches(manifest):
		urls[str(pe.get("naam", ""))] = str(assets.get(str(pe.get("naam", "")), {}).get("url", ""))
	manifest["_urls"] = urls
	match beoordeel(manifest):
		"beschikbaar":
			var mb := 0.0
			for pe in ontbrekende_patches(manifest):
				mb += float(int(pe.grootte)) / 1048576.0
			_zet("beschikbaar", "Update beschikbaar: %s (%.1f MB)." % [str(manifest.versie), mb])
			update_beschikbaar.emit(manifest)
		"app_te_oud":
			_zet("app_te_oud", "Er is een update, maar voor een nieuwere app. Installeer eerst de nieuwste IPA via AltStore.")
		"actueel":
			_zet("actueel", "Je hebt de nieuwste update.")
		_:
			_zet("fout", "Het manifest klopt niet; de update wordt niet gebruikt.")


## Downloadt alle ontbrekende patches uit het laatste manifest (in volgorde), controleert grootte en SHA-256 van elk
## en zet de hele keten klaar voor de volgende start. Een eerder gelukte deelpatch wordt niet opnieuw gedownload.
func download_en_installeer() -> void:
	if status != "beschikbaar" or manifest.is_empty():
		return
	var todo := ontbrekende_patches(manifest)
	if todo.is_empty():
		_zet("actueel", "Je hebt de nieuwste update.")
		return
	var keten := manifest_patches(manifest)
	var urls: Dictionary = manifest.get("_urls", {})
	var heb := _actieve_lijst()
	var nieuwe: Array = heb.slice(0, keten.size() - todo.size())
	var tmp := _pad("download.tmp")
	for i in todo.size():
		var e: Dictionary = todo[i]
		var naam := str(e.naam).get_file()
		if not naam.ends_with(".pck") or naam.contains(".."):
			_zet("fout", "De update is afgekeurd: ongeldige bestandsnaam.")
			return
		var doel := _pad(naam)
		var d := {"naam": naam, "bestand": doel, "sha256": str(e.sha256), "grootte": int(e.grootte)}
		# al eerder binnengehaald (bijvoorbeeld een vorige poging die halverwege stopte)?
		if controleer_patchbestand(d) != "":
			var url := str(urls.get(str(e.naam), manifest.get("_asset_url", "") if keten.size() == 1 else ""))
			if url == "":
				_zet("fout", "Downloaden mislukt (updatebestand staat niet in de release).")
				return
			DirAccess.remove_absolute(tmp)
			_zet("bezig", "Downloaden… deel %d van %d (%.1f MB)" % [i + 1, todo.size(), float(int(e.grootte)) / 1048576.0])
			var res: Dictionary = await _haal_asset(url, tmp)
			if int(res.get("code", -1)) != 200 or int(res.get("result", -1)) != HTTPRequest.RESULT_SUCCESS:
				DirAccess.remove_absolute(tmp)
				_zet("fout", "Downloaden mislukt (%s)." % _download_fout(res))
				return
			var fout := _neem_patch_aan(tmp, d)
			if fout != "":
				_zet("fout", "De update is afgekeurd: " + fout + ".")
				return
		nieuwe.append(d)
	_bewaar_keten(manifest, nieuwe)
	_zet("gedownload", "Update %s staat klaar. Sluit de app helemaal af en open hem opnieuw om hem te gebruiken." % str(manifest.versie))


## Controleert een gedownload bestand tegen de verwachte grootte en hash en zet het op zijn plek.
func _neem_patch_aan(tmp_pad: String, d: Dictionary) -> String:
	var f := FileAccess.open(tmp_pad, FileAccess.READ)
	if f == null or f.get_length() != int(d.grootte):
		return "de grootte klopt niet"
	f = null
	if FileAccess.get_sha256(tmp_pad) != str(d.sha256):
		return "SHA-256 klopt niet"
	if DirAccess.rename_absolute(tmp_pad, str(d.bestand)) != OK:
		return "kon het bestand niet opslaan"
	return ""


## Maakt de keten actief voor de volgende start en ruimt patchbestanden op die er niet meer bij horen.
func _bewaar_keten(m: Dictionary, lijst: Array) -> void:
	var nieuwe_paden := {}
	for p in lijst:
		nieuwe_paden[str(p.bestand)] = true
	for p in _actieve_lijst():
		var pad := str(p.get("bestand", ""))
		if pad != "" and not nieuwe_paden.has(pad) and FileAccess.file_exists(pad):
			DirAccess.remove_absolute(pad)
	_schrijf_json(_pad("actief.json"), {"versie": str(m.versie), "base": str(m.base), "gebouwd": int(m.gebouwd), "patches": lijst})
	_schrijf_json(_pad("opstart.json"), {"onstabiel": 0})
	herstart_nodig = true


## Controleert een gedownload bestand tegen het manifest en maakt het de enige actieve patch (voor de volgende start; schema 1).
## Geeft "" bij succes, anders de reden van afkeuren. Voor een hele keten gebruikt de app download_en_installeer().
func installeer(tmp_pad: String, m: Dictionary) -> String:
	if beoordeel(m) not in ["beschikbaar", "actueel"]:
		return "het manifest hoort niet bij deze app"
	var p: Dictionary = m.pck
	var naam := str(p.naam).get_file()
	if not naam.ends_with(".pck") or naam.contains(".."):
		return "ongeldige bestandsnaam"
	var d := {"naam": naam, "bestand": _pad(naam), "sha256": str(p.sha256), "grootte": int(p.grootte)}
	var fout := _neem_patch_aan(tmp_pad, d)
	if fout != "":
		return fout
	_bewaar_keten(m, [d])
	return ""


## De patch uitzetten: bij de volgende start draait de app weer precies zoals in de IPA.
func terugdraaien() -> void:
	for p in _actieve_lijst():
		if FileAccess.file_exists(str(p.get("bestand", ""))):
			DirAccess.remove_absolute(str(p.bestand))
	DirAccess.remove_absolute(_pad("actief.json"))
	herstart_nodig = true
	_zet("actueel", "Teruggezet naar de app-versie. Sluit de app helemaal af en open opnieuw.")
