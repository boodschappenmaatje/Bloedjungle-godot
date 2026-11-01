extends SceneTree
## Test: updates zonder nieuwe IPA (scripts/updater.gd). Een echte patch wordt gemaakt met PCKPacker en geladen; verkeerde hash,
## verkeerde grootte, verkeerde base en een patch die te vaak niet goed startte worden afgewezen; en de volledige GitHub-stroom
## (token, doorverwijzing zonder token, download, hash) loopt tegen een lokale nepserver (tools/ota_mock_server.py).
## Draaien: godot --headless --path . -s tests/ota_test.gd

const DIR := "user://ota_test"
const PORT := 18765

var fails := 0
var U: Script


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		push_error("OTA TEST: " + msg)


func _initialize() -> void:
	_run()


func _schoon() -> void:
	for sub in ["", "/x"]:
		var d := DirAccess.open(DIR + sub)
		if d != null:
			for f in d.get_files():
				d.remove(f)


func _nieuw(base := "BASIS1", gebouwd := 100):
	var u = U.new(DIR, false)
	u.app_base = base
	u.app_gebouwd = gebouwd
	return u


## Een patch met één bestand (res://ota_test/hallo.json) en het bijbehorende manifest.
func _maak_patch(naam: String, inhoud: String, base := "BASIS1", gebouwd := 200) -> Dictionary:
	var bron := DIR + "/bron.json"
	var f := FileAccess.open(bron, FileAccess.WRITE)
	f.store_string(inhoud)
	f.close()
	var pad := DIR + "/" + naam
	var pk := PCKPacker.new()
	pk.pck_start(pad)
	pk.add_file("res://ota_test/hallo.json", bron)
	pk.flush()
	var data := FileAccess.get_file_as_bytes(pad)
	return {"schema": 1, "versie": naam.get_basename(), "commit": "abc", "base": base, "gebouwd": gebouwd,
		"pck": {"naam": naam, "grootte": data.size(), "sha256": FileAccess.get_sha256(pad)}}


func _run() -> void:
	await process_frame  # in _initialize() staat de wortel nog niet in de boom
	U = load("res://scripts/updater.gd")
	DirAccess.make_dir_recursive_absolute(DIR)
	_schoon()

	# 1. beoordelen van een manifest
	var u0 = _nieuw()
	var m := _maak_patch("patch-a.pck", "{\"w\":1}")
	_check(u0._download_fout({"result": HTTPRequest.RESULT_TIMEOUT, "code": 0}).contains("time-out"), "download-timeout heeft geen bruikbare melding")
	_check(u0._download_fout({"result": HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR, "code": 0}).contains("opslagruimte"), "opslagfout heeft geen bruikbare melding")
	_check(u0.beoordeel(m) == "beschikbaar", "nieuwere patch is niet 'beschikbaar'")
	var oud := m.duplicate(true)
	oud.gebouwd = 100
	_check(u0.beoordeel(oud) == "actueel", "gelijk gebouwd is niet 'actueel'")
	var andere := m.duplicate(true)
	andere.base = "ANDER"
	_check(u0.beoordeel(andere) == "app_te_oud", "andere base is niet 'app_te_oud'")
	_check(u0.beoordeel({"versie": "x"}) == "fout", "onvolledig manifest is niet 'fout'")
	var kapot := m.duplicate(true)
	kapot.pck = {"naam": "x"}
	_check(u0.beoordeel(kapot) == "fout", "manifest zonder hash is niet 'fout'")

	# 2. installeren: goede patch, en afwijzen van een slechte
	var u1 = _nieuw()
	var tmp := DIR + "/download.tmp"
	DirAccess.copy_absolute(DIR + "/patch-a.pck", tmp)
	_check(u1.installeer(tmp, m) == "", "goede patch wordt afgekeurd: " + u1.installeer(tmp, m))
	_check(FileAccess.file_exists(DIR + "/actief.json"), "actief.json ontbreekt na installeren")
	_check(u1.herstart_nodig, "herstart_nodig staat niet aan na installeren")
	DirAccess.copy_absolute(DIR + "/patch-a.pck", tmp)
	var slecht_hash := m.duplicate(true)
	slecht_hash.pck.sha256 = "0".repeat(64)
	_check(u1.installeer(tmp, slecht_hash).contains("SHA-256"), "verkeerde hash wordt niet afgekeurd")
	var slecht_grootte := m.duplicate(true)
	slecht_grootte.pck.grootte = 5
	_check(u1.installeer(tmp, slecht_grootte).contains("grootte"), "verkeerde grootte wordt niet afgekeurd")
	var pad_aanval := m.duplicate(true)
	pad_aanval.pck.naam = "../../etc/passwd"
	_check(u1.installeer(tmp, pad_aanval) != "", "bestandsnaam met .. wordt niet afgekeurd")
	_check(u1.installeer(tmp, andere) != "", "manifest voor een andere app wordt geaccepteerd")

	# 3. bij de start laden: de patch is daarna zichtbaar als res://-bestand
	var info := DIR + "/build_info.json"
	var fi := FileAccess.open(info, FileAccess.WRITE)
	fi.store_string("{\"base\":\"BASIS1\",\"gebouwd\":100}")
	fi.close()
	_check(not FileAccess.file_exists("res://ota_test/hallo.json"), "testbestand bestaat al voor het laden")
	var u2 = U.new(DIR, false)
	u2.app_info_pad = info
	u2.opstarten()
	_check(u2.app_base == "BASIS1" and u2.app_gebouwd == 100, "bouwinfo niet gelezen: %s" % u2.app_base)
	_check(u2.patch_geladen, "patch is niet geladen (reden: %s)" % u2.teruggedraaid_reden)
	_check(FileAccess.get_file_as_string("res://ota_test/hallo.json") == "{\"w\":1}", "inhoud uit de patch niet zichtbaar")
	_check(int(FileAccess.open(DIR + "/opstart.json", FileAccess.READ).get_as_text().contains("\"onstabiel\":1") as int) == 1, "start telt niet als 'nog niet stabiel'")
	u2.markeer_stabiel()
	_check(not FileAccess.get_file_as_string(DIR + "/opstart.json").contains("\"onstabiel\":1"), "stabiel markeren zet de teller niet terug")

	# 4. een beschadigde patch wordt bij de start teruggedraaid
	var bytes := FileAccess.get_file_as_bytes(DIR + "/patch-a.pck")
	bytes[bytes.size() - 3] = (bytes[bytes.size() - 3] + 1) % 256
	var fb := FileAccess.open(DIR + "/patch-a.pck", FileAccess.WRITE)
	fb.store_buffer(bytes)
	fb.close()
	var u3 = U.new(DIR, false)
	u3.app_info_pad = info
	u3.opstarten()
	_check(not u3.patch_geladen and u3.teruggedraaid_reden.contains("beschadigd"), "beschadigde patch niet teruggedraaid (%s)" % u3.teruggedraaid_reden)
	_check(not FileAccess.file_exists(DIR + "/actief.json"), "actief.json blijft staan na terugdraaien")

	# 5. patch met een andere base wordt bij de start niet geladen; 6. crashbeveiliging
	var m2 := _maak_patch("patch-b.pck", "{\"w\":2}")
	DirAccess.copy_absolute(DIR + "/patch-b.pck", tmp)
	var u4 = _nieuw()
	_check(u4.installeer(tmp, m2) == "", "tweede patch installeren mislukt")
	var u5 = U.new(DIR, false)
	var fi2 := FileAccess.open(info, FileAccess.WRITE)
	fi2.store_string("{\"base\":\"NIEUWE_IPA\",\"gebouwd\":300}")
	fi2.close()
	u5.app_info_pad = info
	u5.opstarten()
	_check(not u5.patch_geladen and u5.teruggedraaid_reden.contains("andere app-versie"), "patch van een oudere app geladen (%s)" % u5.teruggedraaid_reden)
	DirAccess.copy_absolute(DIR + "/patch-b.pck", tmp)  # (het bestand is bij het terugdraaien verwijderd)
	if not FileAccess.file_exists(DIR + "/patch-b.pck"):
		m2 = _maak_patch("patch-b.pck", "{\"w\":2}")
	DirAccess.copy_absolute(DIR + "/patch-b.pck", tmp)
	_check(u4.installeer(tmp, m2) == "", "patch opnieuw installeren mislukt")
	var fo := FileAccess.open(DIR + "/opstart.json", FileAccess.WRITE)
	fo.store_string("{\"onstabiel\":2}")
	fo.close()
	var fi3 := FileAccess.open(info, FileAccess.WRITE)
	fi3.store_string("{\"base\":\"BASIS1\",\"gebouwd\":100}")
	fi3.close()
	var u6 = U.new(DIR, false)
	u6.app_info_pad = info
	u6.opstarten()
	_check(not u6.patch_geladen and u6.teruggedraaid_reden.contains("niet goed"), "twee mislukte starts zetten de patch niet uit (%s)" % u6.teruggedraaid_reden)

	# 7. terugdraaien op verzoek
	var m3 := _maak_patch("patch-c.pck", "{\"w\":3}")
	DirAccess.copy_absolute(DIR + "/patch-c.pck", tmp)
	var u7 = _nieuw()
	_check(u7.installeer(tmp, m3) == "", "patch c installeren mislukt")
	u7.terugdraaien()
	_check(not FileAccess.file_exists(DIR + "/actief.json"), "terugdraaien laat actief.json staan")

	# 7b. keten van patches: alleen wat nog mist wordt gehaald, en ze laden in volgorde (de laatste wint)
	_schoon()
	var k1 := _maak_patch("patch-k1.pck", "{\"w\":10}", "BASIS1", 201)
	var k2 := _maak_patch("patch-k2.pck", "{\"w\":20}", "BASIS1", 202)
	var keten_m: Dictionary = k2.duplicate(true)
	keten_m["schema"] = 2
	keten_m["patches"] = [k1.pck, k2.pck]
	var uk = _nieuw()
	_check(uk.manifest_patches(keten_m).size() == 2, "keten uit manifest niet gelezen")
	_check(uk.manifest_patches(k1).size() == 1, "schema 1 geeft niet één patch")
	_check(uk.ontbrekende_patches(keten_m).size() == 2, "zonder patches zou de hele keten ontbreken")
	_check(uk.beoordeel(keten_m) == "beschikbaar", "keten is niet 'beschikbaar'")
	DirAccess.copy_absolute(DIR + "/patch-k1.pck", tmp)
	_check(uk.installeer(tmp, k1) == "", "eerste patch van de keten installeren mislukt")
	uk.actief = uk._lees_json(DIR + "/actief.json")  # (de app doet dit pas bij de volgende start)
	var ontbrekend: Array = uk.ontbrekende_patches(keten_m)
	_check(ontbrekend.size() == 1 and str(ontbrekend[0].naam) == "patch-k2.pck", "met patch 1 erop moet alleen patch 2 ontbreken")
	var andere_keten: Dictionary = keten_m.duplicate(true)
	andere_keten.patches[0].sha256 = "0".repeat(64)
	_check(uk.ontbrekende_patches(andere_keten).size() == 2, "een afwijkende keten moet helemaal opnieuw")
	var lijst: Array = []
	for pe in [k1.pck, k2.pck]:
		lijst.append({"naam": pe.naam, "bestand": DIR + "/" + str(pe.naam), "sha256": pe.sha256, "grootte": pe.grootte})
	uk._bewaar_keten(keten_m, lijst)
	uk.actief = uk._lees_json(DIR + "/actief.json")
	_check(uk.ontbrekende_patches(keten_m).is_empty(), "na het bewaren van de hele keten ontbreekt er niets meer")
	var fik := FileAccess.open(info, FileAccess.WRITE)
	fik.store_string("{\"base\":\"BASIS1\",\"gebouwd\":100}")
	fik.close()
	var u8 = U.new(DIR, false)
	u8.app_info_pad = info
	u8.opstarten()
	_check(u8.patch_geladen, "keten is niet geladen (reden: %s)" % u8.teruggedraaid_reden)
	_check(FileAccess.get_file_as_string("res://ota_test/hallo.json") == "{\"w\":20}", "de laatste patch van de keten moet winnen")
	u8.terugdraaien()
	_check(not FileAccess.file_exists(DIR + "/patch-k1.pck") and not FileAccess.file_exists(DIR + "/patch-k2.pck"), "terugdraaien ruimt niet de hele keten op")

	# 7c. voortgang in procenten, snelheid en resterende tijd
	var uv = _nieuw()
	uv.status = "bezig"
	uv.dl_totaal = 200 * 1048576
	uv.dl_klaar = 50 * 1048576
	uv._meld_voortgang(0)
	uv._dl_laatste_ms -= 1000  # een seconde geleden: 25 MB erbij = 25 MB/s
	uv._meld_voortgang(25 * 1048576)
	_check(absf(uv.voortgang - 0.375) < 0.001, "voortgang is %.3f in plaats van 0.375" % uv.voortgang)
	_check(uv.status_tekst.contains("37%") and uv.status_tekst.contains("MB/s") and uv.status_tekst.contains("nog ca."), "voortgangstekst klopt niet: " + uv.status_tekst)
	_check(U._duur_tekst(5.2) == "6 sec" and U._duur_tekst(125.0) == "2 min 05 sec", "duurtekst klopt niet")

	# 8. de hele GitHub-stroom tegen de nepserver
	await _github_stroom()

	_schoon()
	if fails == 0:
		print("OTA TEST PASS: patch laden, afkeuren bij fout/verkeerde base/crashes, terugdraaien en de GitHub-stroom met token en doorverwijzing")
	quit(1 if fails > 0 else 0)


func _github_stroom() -> void:
	if not FileAccess.file_exists("res://tools/ota_mock_server.py"):
		return
	var mp := _maak_patch("patch-gh.pck", "{\"w\":\"github\"}", "BASIS1", 250)
	var mpad := DIR + "/manifest.json"
	var f := FileAccess.open(mpad, FileAccess.WRITE)
	f.store_string(JSON.stringify(mp))
	f.close()
	var pid := OS.create_process("python3", [ProjectSettings.globalize_path("res://tools/ota_mock_server.py"), str(PORT), ProjectSettings.globalize_path(mpad), ProjectSettings.globalize_path(DIR + "/patch-gh.pck"), "testtoken"])
	if pid <= 0:
		push_warning("OTA TEST: python3 niet beschikbaar, GitHub-stroom overgeslagen")
		return
	if not await _wacht_op_server():
		_check(false, "de nepserver kwam niet op")
		OS.kill(pid)
		return
	var u = _nieuw()
	u.api_basis = "http://127.0.0.1:%d" % PORT
	root.add_child(u)  # HTTPRequest-knopen hebben een boom nodig; token is op dat moment nog leeg, dus geen automatische controle
	# fout token -> duidelijke melding, geen crash
	u.set_token("verkeerd")
	await u.controleer()
	_check(u.status == "fout" and u.status_tekst.contains("401"), "verkeerd token geeft geen 401-melding: %s / %s" % [u.status, u.status_tekst])
	# goed token -> beschikbaar
	u.set_token("testtoken")
	await u.controleer()
	_check(u.status == "beschikbaar", "controleren geeft '%s' (%s)" % [u.status, u.status_tekst])
	_check(str(u.manifest.get("versie", "")) == "patch-gh", "manifest niet goed gelezen")
	# download: doorverwijzing zonder token, hash en grootte kloppen, patch klaargezet
	await u.download_en_installeer()
	_check(u.status == "gedownload", "download eindigt als '%s' (%s)" % [u.status, u.status_tekst])
	_check(FileAccess.file_exists(DIR + "/actief.json") and FileAccess.file_exists(DIR + "/patch-gh.pck"), "gedownloade patch niet klaargezet")
	if FileAccess.file_exists(DIR + "/patch-gh.pck"):
		_check(FileAccess.get_sha256(DIR + "/patch-gh.pck") == str(mp.pck.sha256), "gedownloade patch heeft een andere hash")
	# Direct HTTP 200 from a GitHub asset must stream to disk as well.
	var direct := DIR + "/direct-download.tmp"
	var direct_result: Dictionary = await u._haal_asset("http://127.0.0.1:%d/api-direct/2" % PORT, direct)
	_check(int(direct_result.get("code", -1)) == 200 and int(direct_result.get("result", -1)) == HTTPRequest.RESULT_SUCCESS, "directe API-download mislukt")
	_check(FileAccess.file_exists(direct) and FileAccess.get_sha256(direct) == str(mp.pck.sha256), "directe HTTP 200 asset-download is niet correct naar disk gestreamd")
	# een tweede controle: nu actueel (de actieve patch is even nieuw)
	var actief_json: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + "/actief.json"))
	_check(actief_json is Dictionary, "actief.json ontbreekt of is geen JSON na het installeren")
	if actief_json is Dictionary:
		u.actief = actief_json
	await u.controleer()
	_check(u.status == "actueel", "na installeren is de status '%s' in plaats van 'actueel'" % u.status)
	u.queue_free()
	OS.kill(pid)


## Wacht (in echte tijd, niet in speltijd) tot de nepserver antwoordt.
func _wacht_op_server() -> bool:
	var einde := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < einde:
		var r := HTTPRequest.new()
		root.add_child(r)
		if r.request("http://127.0.0.1:%d/ping" % PORT) == OK:
			var res: Array = await r.request_completed
			r.queue_free()
			if int(res[0]) == HTTPRequest.RESULT_SUCCESS:
				return true
		else:
			r.queue_free()
		OS.delay_msec(200)
		await process_frame
	return false
