class_name UpdatePanel
extends CanvasLayer
## Updatescherm (Hoofdmenu en Pauze > Updates): toont de app- en patchversie, laat je het GitHub-token invullen, controleert op een
## nieuwe patch en downloadt die pas als jij dat bevestigt. Na het installeren de app helemaal afsluiten en opnieuw openen.

var _status: Label
var _info: Label
var _token: LineEdit
var _check: Button
var _download: Button
var _back: Button
var _close: Button
var _balk: ProgressBar
var _center: CenterContainer
var _paneel: PanelContainer
var _kolommen: BoxContainer


## Opent het scherm onder `parent` (één tegelijk).
static func open(parent: Node) -> UpdatePanel:
	for n in parent.get_tree().get_nodes_in_group("update_panel"):
		return n
	var p := UpdatePanel.new()
	parent.get_tree().root.add_child(p)
	return p


func _ready() -> void:
	add_to_group("update_panel")
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/main_menu_bunker.jpg") as Texture2D
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.022, 0.015, 0.42)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	# donker paneel met kop en SLUITEN rechtsboven, net als de andere menu's; liggend tekst links en knoppen rechts,
	# staand onder elkaar. Geen scrollbalk.
	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_center)
	_paneel = PanelContainer.new()
	var sb := UI.box(Color(0.043, 0.052, 0.03, 0.9), Color(UI.BRASS, 0.55), 1, 6, 16)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 24
	_paneel.add_theme_stylebox_override("panel", sb)
	_center.add_child(_paneel)
	var blad := VBoxContainer.new()
	blad.add_theme_constant_override("separation", 12)
	_paneel.add_child(blad)
	var kop := HBoxContainer.new()
	kop.add_theme_constant_override("separation", 12)
	blad.add_child(kop)
	var titel := UI.label("UPDATES", UI.display(1), 28, UI.INK)
	titel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	kop.add_child(titel)
	_close = _knop("SLUITEN", "field_primary", queue_free)
	_close.custom_minimum_size = Vector2(112, 42)
	_close.add_theme_font_size_override("font_size", 17)
	_close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	kop.add_child(_close)
	_kolommen = BoxContainer.new()
	_kolommen.add_theme_constant_override("separation", 20)
	blad.add_child(_kolommen)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 9)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kolommen.add_child(v)
	var knoppen := VBoxContainer.new()
	knoppen.add_theme_constant_override("separation", 9)
	knoppen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kolommen.add_child(knoppen)

	_info = UI.label("", UI.body(600, 1), 15, UI.INK)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_info)
	_status = UI.label("", UI.body(700, 1), 16, UI.BRASS)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_status)
	_balk = ProgressBar.new()
	_balk.show_percentage = false
	_balk.custom_minimum_size.y = 9
	_balk.visible = false
	v.add_child(_balk)
	var hint := UI.label("Toegangstoken (GitHub, alleen-lezen, alleen deze repository). Wordt alleen op dit toestel bewaard.", UI.body(600, 0), 13, UI.INK_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	var token_row := HBoxContainer.new()
	token_row.add_theme_constant_override("separation", 8)
	v.add_child(token_row)
	_token = LineEdit.new()
	_token.secret = true
	_token.placeholder_text = "github_pat_…" if Updater.token() == "" else "(ingevuld; plak een nieuw token om te vervangen)"
	_token.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	token_row.add_child(_token)
	var save := _knop("OPSLAAN", "field", _sla_token_op)
	token_row.add_child(save)
	_check = _knop("CONTROLEREN OP UPDATES", "field", func(): Updater.controleer())
	knoppen.add_child(_check)
	_download = _knop("DOWNLOADEN EN INSTALLEREN", "field_primary", _download_met_lange_timeout)
	knoppen.add_child(_download)
	_back = _knop("TERUGDRAAIEN NAAR APP-VERSIE", "field", func(): Updater.terugdraaien())
	knoppen.add_child(_back)
	get_viewport().size_changed.connect(_schik)
	_schik()
	Updater.status_changed.connect(_ververs)
	_ververs()


# ------------------------------------------------------------------ download in stukken (werkt met elke Updater-versie)
#
# De Updater in de IPA geeft een download maar 30 seconden. Dit scherm haalt daarom zelf bestanden op in blokken van `chunk` bytes
# (HTTP Range), plakt ze achter elkaar in een .part-bestand en hervat na een storing waar het bleef. Het manifest (schema 3) bevat:
#   licht: één patch met scripts, scènes en kleine bestanden sinds de IPA. Wordt de actieve patch (Updater.installeer) en vervangt de vorige.
#   zwaar: een keten van patches met modellen, texturen en geluid. Elk stuk komt in user://ota/keten/ en wordt bij elke start door
#          scripts/ota_keten.gd geladen (user://ota/keten.json). Alleen de stukken die nog missen worden gedownload.
#   pck:   de brug (alleen dit scherm) voor apps die nog de oude updater uit de IPA gebruiken.

const CHUNK_TIMEOUT := 120.0
const POGINGEN := 4

var chunk := 16 * 1048576  # in tests kleiner
var _loopt := false
var _tot_bytes := 0
var _klaar_bytes := 0  # bytes die al op schijf staan (gelukte blokken en eerdere pogingen)
var _snelheid := 0.0
var _laatste_ms := 0
var _laatste_bytes := 0


## Welke stukken ontbreken nog? Eerst de ontbrekende zware stukken in volgorde, als laatste het lichte stuk (dat zet alles in één keer om).
## Zonder licht/zwaar in het manifest (schema 1 of 2): leeg, dan geldt de gewone route van de Updater.
static func stukken_nodig(m: Dictionary, actief: Dictionary, keten: Dictionary) -> Array:
	var zwaar: Array = m.get("zwaar", []) if m.get("zwaar") is Array else []
	var licht: Variant = m.get("licht")
	if zwaar.is_empty() and not (licht is Dictionary):
		return []
	var heb: Array = keten.get("stukken", []) if str(keten.get("basis", "")) == str(m.get("base", "")) and keten.get("stukken") is Array else []
	var n := behouden(zwaar, heb)
	var nodig: Array = zwaar.slice(n)
	if licht is Dictionary and str(actief.get("sha256", "")) != str((licht as Dictionary).get("sha256", "x")):
		nodig.append(licht)
	return nodig


## Hoeveel van de zware stukken die we al hebben kloppen (zelfde volgorde en SHA-256 als in het manifest)?
static func behouden(zwaar: Array, heb: Array) -> int:
	var n := 0
	while n < heb.size() and n < zwaar.size() and str(heb[n].get("sha256", "")) == str((zwaar[n] as Dictionary).get("sha256", "x")):
		n += 1
	return n if n == heb.size() else 0


func _lees(naam: String) -> Dictionary:
	return Updater._lees_json(Updater._pad(naam))


func _bytes_tekst(b: float) -> String:
	return "%.1f MB" % (b / 1048576.0)


func _duur_tekst(sec: float) -> String:
	var t := int(ceil(sec))
	if t < 60:
		return "%d sec" % t
	return "%d min %02d sec" % [t / 60, t % 60]


func _meld(bytes_nu: int) -> void:
	if _tot_bytes <= 0:
		return
	var nu := Time.get_ticks_msec()
	if _laatste_ms > 0 and nu > _laatste_ms and bytes_nu >= _laatste_bytes:
		var snel := float(bytes_nu - _laatste_bytes) / (float(nu - _laatste_ms) / 1000.0)
		_snelheid = snel if _snelheid <= 0.0 else lerpf(_snelheid, snel, 0.3)
	_laatste_ms = nu
	_laatste_bytes = bytes_nu
	var klaar := mini(_klaar_bytes + bytes_nu, _tot_bytes)
	var deel := clampf(float(klaar) / float(_tot_bytes), 0.0, 1.0)
	var tekst := "Downloaden… %d%% (%s van %s)" % [int(deel * 100.0), _bytes_tekst(klaar), _bytes_tekst(_tot_bytes)]
	if _snelheid > 1024.0:
		tekst += " · %.1f MB/s · nog ca. %s" % [_snelheid / 1048576.0, _duur_tekst(float(_tot_bytes - klaar) / _snelheid)]
	Updater._zet("bezig", tekst, deel)


## Eén aanvraag; naar_bestand is een blok dat naar schijf wordt gestreamd. Parent is de Updater, zodat sluiten van dit scherm niets afbreekt.
func _http(url: String, headers: PackedStringArray, naar_bestand := "") -> Dictionary:
	var r := HTTPRequest.new()
	r.timeout = CHUNK_TIMEOUT if naar_bestand != "" else 30.0
	r.max_redirects = 0
	if naar_bestand != "":
		r.download_file = naar_bestand
	Updater.add_child(r)
	var err := r.request(url, headers)
	if err != OK:
		r.queue_free()
		return {"result": -1, "code": -1}
	var teller: Timer = null
	if naar_bestand != "":
		teller = Timer.new()
		teller.wait_time = 0.5
		teller.timeout.connect(func(): _meld(r.get_downloaded_bytes()))
		Updater.add_child(teller)
		teller.start()
	var res: Array = await r.request_completed
	if teller != null:
		teller.queue_free()
	r.queue_free()
	var kop := {}
	for h in res[2] as PackedStringArray:
		var i := (h as String).find(":")
		if i > 0:
			kop[(h as String).substr(0, i).strip_edges().to_lower()] = (h as String).substr(i + 1).strip_edges()
	return {"result": res[0], "code": res[1], "headers": kop}


## Naam -> API-adres van elke asset in de release "updates".
func _release_assets() -> Dictionary:
	var rel: Dictionary = await Updater._vraag("%s/repos/%s/releases/tags/%s" % [Updater.api_basis, Updater.REPO, Updater.RELEASE_TAG], Updater._headers("application/vnd.github+json"))
	var uit := {}
	if int(rel.get("code", -1)) != 200:
		return uit
	var r: Variant = JSON.parse_string((rel.body as PackedByteArray).get_string_from_utf8())
	if r is Dictionary and (r as Dictionary).has("assets"):
		for a in (r as Dictionary).assets:
			uit[str(a.name)] = str(a.url)
	return uit


## Haalt één blok op: eerst de doorverwijzing (met token), dan het blok zelf (zonder token, met Range). "" bij succes, anders de reden.
func _haal_blok(asset_url: String, van: int, tot: int, dest: String) -> String:
	DirAccess.remove_absolute(dest)
	var a: Dictionary = await _http(asset_url, Updater._headers("application/octet-stream"))
	var loc := str(a.get("headers", {}).get("location", ""))
	if not (int(a.get("code", -1)) in [301, 302, 303, 307, 308]) or loc == "":
		return "geen verbinding met GitHub (HTTP %d)" % int(a.get("code", -1))
	var h := Updater._headers("application/octet-stream", false)
	h.append("Range: bytes=%d-%d" % [van, tot])
	var res: Dictionary = await _http(loc, h, dest)
	var code := int(res.get("code", -1))
	if int(res.get("result", -1)) != HTTPRequest.RESULT_SUCCESS:
		return "netwerkfout (code %d)" % int(res.get("result", -1))
	if code != 206 and code != 200:
		return "HTTP %d" % code
	return ""


## Plakt een geslaagd blok achter het .part-bestand. Geeft de nieuwe lengte, of -1 bij een schrijffout.
func _voeg_toe(part: String, blok: String) -> int:
	var uit := FileAccess.open(part, FileAccess.READ_WRITE) if FileAccess.file_exists(part) else FileAccess.open(part, FileAccess.WRITE)
	var inn := FileAccess.open(blok, FileAccess.READ)
	if uit == null or inn == null:
		return -1
	uit.seek_end()
	while inn.get_position() < inn.get_length():
		uit.store_buffer(inn.get_buffer(4 * 1048576))
	var n := uit.get_position()
	uit.close()
	inn = null
	DirAccess.remove_absolute(blok)
	return n


## Downloadt één stuk compleet naar `part` (hervat als er al een deel staat). "" bij succes, anders de reden.
func _haal_stuk(e: Dictionary, asset_url: String, part: String) -> String:
	var totaal := int(e.grootte)
	var heb := 0
	if FileAccess.file_exists(part):
		var f := FileAccess.open(part, FileAccess.READ)
		heb = f.get_length() if f != null else 0
		f = null
		if heb > totaal:
			DirAccess.remove_absolute(part)
			heb = 0
	var blok := Updater._pad("blok.tmp")
	_klaar_bytes += heb
	while heb < totaal:
		var tot := mini(heb + chunk, totaal) - 1
		var fout := "?"
		for poging in POGINGEN:
			fout = await _haal_blok(asset_url, heb, tot, blok)
			if fout == "":
				break
			await Updater.get_tree().create_timer(2.0 * (poging + 1)).timeout
		if fout != "":
			DirAccess.remove_absolute(blok)
			return fout
		var gelezen := FileAccess.open(blok, FileAccess.READ)
		var lengte := gelezen.get_length() if gelezen != null else 0
		gelezen = null
		if lengte == totaal and heb == 0:
			DirAccess.remove_absolute(part)  # de server negeerde Range en gaf het hele bestand
		var nieuw := _voeg_toe(part, blok)
		if nieuw < 0:
			return "kon niet schrijven (opslagruimte vol?)"
		_klaar_bytes += nieuw - heb
		heb = nieuw
		_laatste_ms = 0
		_laatste_bytes = 0
	return ""


func _schrijf(naam: String, d: Dictionary) -> void:
	Updater._schrijf_json(Updater._pad(naam), d)


func _download_met_lange_timeout() -> void:
	if _loopt:
		return
	var m: Dictionary = Updater.manifest
	var actief := _lees("actief.json")
	var keten := _lees("keten.json")
	var nodig := stukken_nodig(m, actief, keten)
	if nodig.is_empty():
		# geen keten in het manifest: de gewone route van de Updater (kleine patch)
		await Updater.download_en_installeer()
		return
	_loopt = true
	_tot_bytes = 0
	_klaar_bytes = 0
	_snelheid = 0.0
	_laatste_ms = 0
	_laatste_bytes = 0
	for e in nodig:
		_tot_bytes += int(e.grootte)
	Updater.status = "bezig"
	Updater._zet("bezig", "Downloaden voorbereiden…", 0.0)
	var urls := await _release_assets()
	DirAccess.make_dir_recursive_absolute(Updater._pad("keten"))
	# de zware stukken die we al hebben en kloppen blijven; de rest van de oude keten gaat weg
	var zwaar: Array = m.get("zwaar", []) if m.get("zwaar") is Array else []
	var heb: Array = keten.get("stukken", []) if str(keten.get("basis", "")) == str(m.get("base", "")) and keten.get("stukken") is Array else []
	var lijst: Array = heb.slice(0, behouden(zwaar, heb))
	_schrijf("keten.json", {"basis": str(m.base), "stukken": lijst})
	_ruim_keten_op(lijst)
	var licht_sha := str((m.get("licht", {}) as Dictionary).get("sha256", "")) if m.get("licht") is Dictionary else ""
	for e in nodig:
		var naam := str(e.naam).get_file()
		if not naam.ends_with(".pck") or naam.contains(".."):
			Updater._zet("fout", "De update is afgekeurd: ongeldige bestandsnaam.")
			_loopt = false
			return
		if not urls.has(naam):
			Updater._zet("fout", "Downloaden mislukt (%s staat niet in de release). Tik opnieuw op controleren." % naam)
			_loopt = false
			return
		var part := Updater._pad(naam + ".part")
		var fout := await _haal_stuk(e, str(urls[naam]), part)
		if fout != "":
			Updater._zet("fout", "Downloaden mislukt (%s). Tik opnieuw op download: het gaat verder waar het bleef." % fout)
			_loopt = false
			return
		Updater._zet("bezig", "Controleren…", 1.0)
		if licht_sha != "" and str(e.sha256) == licht_sha:
			# het lichte stuk wordt de actieve patch (de Updater controleert grootte en SHA-256 en ruimt de vorige op)
			var m0 := {"versie": str(m.versie), "base": str(m.base), "gebouwd": int(m.gebouwd), "pck": {"naam": naam, "grootte": int(e.grootte), "sha256": str(e.sha256)}}
			var err: String = Updater.installeer(part, m0)
			if err != "":
				DirAccess.remove_absolute(part)
				Updater._zet("fout", "De update is afgekeurd: " + err + ".")
				_loopt = false
				return
		else:
			var d := {"naam": naam, "bestand": Updater._pad("keten/" + naam), "sha256": str(e.sha256), "grootte": int(e.grootte)}
			if FileAccess.get_sha256(part) != str(e.sha256):
				DirAccess.remove_absolute(part)
				Updater._zet("fout", "De update is afgekeurd: SHA-256 klopt niet. Tik opnieuw op download.")
				_loopt = false
				return
			DirAccess.rename_absolute(part, str(d.bestand))
			lijst.append(d)
			_schrijf("keten.json", {"basis": str(m.base), "stukken": lijst})
	_loopt = false
	Updater.herstart_nodig = true
	Updater._zet("gedownload", "Update %s staat klaar. Sluit de app helemaal af en open opnieuw." % str(m.versie))


## Verwijdert stukken uit user://ota/keten die niet (meer) in de lijst staan.
func _ruim_keten_op(houd: Array) -> void:
	var blijf := {}
	for p in houd:
		blijf[str(p.get("bestand", "")).get_file()] = true
	var dir := DirAccess.open(Updater._pad("keten"))
	if dir == null:
		return
	for f in dir.get_files():
		if not blijf.has(f):
			dir.remove(f)


## Binnen de veilige marges blijven; staand de knoppen onder de tekst.
func _schik() -> void:
	var vp := get_viewport().get_visible_rect().size
	var safe := UI.safe_margins(vp, 10.0)
	_center.offset_left = safe.x
	_center.offset_top = safe.y
	_center.offset_right = -safe.z
	_center.offset_bottom = -safe.w
	_kolommen.vertical = vp.y > vp.x
	_paneel.custom_minimum_size.x = minf(900.0, vp.x - safe.x - safe.z)


func _knop(text: String, kind: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	UI.style_button(b, kind)
	b.custom_minimum_size.y = 52.0 if kind == "field_primary" else 46.0
	b.pressed.connect(cb)
	return b


func _sla_token_op() -> void:
	if _token.text.strip_edges() == "":
		return
	Updater.set_token(_token.text)
	_token.text = ""
	_token.placeholder_text = "(ingevuld; plak een nieuw token om te vervangen)"


## Extra regels onder de versie: wat de zware keten en het spelermodel bij de laatste start deden.
## Dit scherm draait ook als "brug" bovenop een oude IPA, en die heeft ota_keten.gd en soldier_model.player_status nog niet.
## Daarom hier NOOIT preload of een directe verwijzing naar scripts of leden die niet in elke IPA zitten (dan laadt het hele scherm niet
## meer en kom je niet meer in het updatemenu): alleen load() na een controle en get(). tools/ota_brug_simulatie.sh bewaakt dit in de workflow.
static func _extra_regels() -> String:
	var uit := ""
	for bron in [["res://scripts/ota_keten.gd", "status"], ["res://scripts/soldier_model.gd", "player_status"], ["res://scripts/soldier_model.gd", "enemy_status"]]:
		if not ResourceLoader.exists(bron[0]):
			continue
		var s: Variant = load(bron[0])
		var waarde: Variant = s.get(bron[1]) if s != null else null
		if waarde != null:
			uit += "\n" + str(waarde)
	return uit


func _ververs() -> void:
	if not is_inside_tree():
		return
	var app := "app-versie %s" % Updater.app_base.left(7) if Updater.app_base != "dev" else "ontwikkelbuild"
	var patch := "actieve update: %s" % str(Updater.actief.get("versie", "?")) if Updater.patch_geladen else "geen update actief (zoals in de IPA)"
	_info.text = "%s · %s" % [app, patch] + _extra_regels()
	_status.text = Updater.status_tekst
	var bezig: bool = Updater.status == "bezig"
	_balk.visible = bezig
	_balk.indeterminate = Updater.voortgang <= 0.0
	_balk.max_value = 1.0
	_balk.step = 0.001
	_balk.value = Updater.voortgang
	_check.disabled = bezig or Updater.app_base == "dev"
	var nodig: Array = [] if bezig or _loopt or Updater.herstart_nodig else stukken_nodig(Updater.manifest, _lees("actief.json"), _lees("keten.json"))
	var mb := 0.0
	for e in nodig:
		mb += float(int(e.grootte)) / 1048576.0
	if not nodig.is_empty() and Updater.status in ["actueel", "beschikbaar"]:
		_status.text = "Update beschikbaar: %s (%.1f MB in %d %s)." % [str(Updater.manifest.get("versie", "?")), mb, nodig.size(), "stuk" if nodig.size() == 1 else "stukken"]
	_download.visible = Updater.status == "beschikbaar" or not nodig.is_empty()
	_back.visible = Updater.patch_geladen and not Updater.herstart_nodig
