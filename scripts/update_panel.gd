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
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(430, 0)
	pc.add_theme_stylebox_override("panel", UI.box(UI.PANEL, UI.PANEL_LINE, 1, 6, 16))
	c.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pc.add_child(v)
	v.add_child(UI.label("UPDATES", UI.display(1), 28, UI.INK))
	_info = UI.label("", UI.body(600, 0), 13, UI.INK_DIM)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_info)
	_status = UI.label("", UI.body(700, 0), 15, UI.BRASS)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_status)
	_balk = ProgressBar.new()
	_balk.show_percentage = false
	_balk.custom_minimum_size.y = 8
	_balk.visible = false
	v.add_child(_balk)
	var hint := UI.label("Toegangstoken (GitHub, alleen-lezen, alleen deze repository). Wordt alleen op dit toestel bewaard.", UI.body(600, 0), 12, UI.INK_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	_token = LineEdit.new()
	_token.secret = true
	_token.placeholder_text = "github_pat_…" if Updater.token() == "" else "(ingevuld; plak een nieuw token om te vervangen)"
	_token.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_token)
	var save := _knop("Opslaan", "secondary", _sla_token_op)
	row.add_child(save)
	_check = _knop("Controleer op updates", "secondary", func(): Updater.controleer())
	v.add_child(_check)
	_download = _knop("Download en installeer", "primary", _download_met_lange_timeout)
	v.add_child(_download)
	_back = _knop("Terugdraaien naar de app-versie", "secondary", func(): Updater.terugdraaien())
	v.add_child(_back)
	_close = _knop("Sluiten", "secondary", queue_free)
	v.add_child(_close)
	Updater.status_changed.connect(_ververs)
	_ververs()


## OTA bootstrap compatibility: the original Updater autoload is instantiated
## before loading a patch pack, and cannot update its own downloader in memory.
## A patched UpdatePanel can therefore stream large releases independently.
func _download_met_lange_timeout() -> void:
	if Updater.status != "beschikbaar" or Updater.manifest.is_empty():
		return
	var m: Dictionary = Updater.manifest
	var asset_url := str(m.get("_asset_url", ""))
	if asset_url == "":
		return
	var dest: String = Updater._pad("download.tmp")
	DirAccess.remove_absolute(dest)
	var size_mb := float(int(m.pck.grootte)) / 1048576.0
	Updater._zet("bezig", "Downloaden… (%.1f MB, maximaal 10 minuten)" % size_mb)
	var result: Dictionary = await _grote_vraag(asset_url, true, dest)
	var redirect := str(result.get("location", ""))
	if int(result.get("code", -1)) in [301, 302, 303, 307, 308] and redirect != "":
		DirAccess.remove_absolute(dest)
		result = await _grote_vraag(redirect, false, dest)
	if int(result.get("result", -1)) != HTTPRequest.RESULT_SUCCESS or int(result.get("code", -1)) != 200:
		DirAccess.remove_absolute(dest)
		Updater._zet("fout", "Downloaden mislukt (%s)." % _download_reden(result))
		return
	var err: String = Updater.installeer(dest, m)
	if err != "":
		Updater._zet("fout", "De update is afgekeurd: " + err + ".")
		return
	Updater._zet("gedownload", "Update %s staat klaar. Sluit de app helemaal af en open opnieuw." % str(m.versie))


func _grote_vraag(url: String, authenticated: bool, destination: String) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = 600.0
	request.max_redirects = 0
	request.download_file = destination
	Updater.add_child(request)
	var error := request.request(url, Updater._headers("application/octet-stream", authenticated))
	if error != OK:
		request.queue_free()
		return {"result": -1, "code": -1, "reason": "aanvraag starten (%d)" % error}
	var response: Array = await request.request_completed
	request.queue_free()
	var location := ""
	for h in response[2] as PackedStringArray:
		var hs := str(h)
		if hs.to_lower().begins_with("location:"):
			location = hs.substr(9).strip_edges()
			break
	return {"result": response[0], "code": response[1], "location": location}


func _download_reden(response: Dictionary) -> String:
	var code := int(response.get("code", -1))
	var result := int(response.get("result", -1))
	if result == HTTPRequest.RESULT_TIMEOUT:
		return "time-out; controleer je verbinding"
	if result == HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
		return "te weinig opslagruimte of schrijffout"
	if result == HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN:
		return "downloadbestand kan niet geopend worden"
	if code in [401, 403, 404]:
		return "GitHub-toegang geweigerd (HTTP %d)" % code
	if code > 0:
		return "HTTP %d" % code
	return str(response.get("reason", "netwerkfout %d" % result))


func _knop(text: String, kind: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	UI.style_button(b, kind)
	b.pressed.connect(cb)
	return b


func _sla_token_op() -> void:
	if _token.text.strip_edges() == "":
		return
	Updater.set_token(_token.text)
	_token.text = ""
	_token.placeholder_text = "(ingevuld; plak een nieuw token om te vervangen)"


func _ververs() -> void:
	if not is_inside_tree():
		return
	var app := "app-versie %s" % Updater.app_base.left(7) if Updater.app_base != "dev" else "ontwikkelbuild"
	var patch := "actieve update: %s" % str(Updater.actief.get("versie", "?")) if Updater.patch_geladen else "geen update actief (zoals in de IPA)"
	_info.text = "%s · %s" % [app, patch]
	_status.text = Updater.status_tekst
	var bezig: bool = Updater.status == "bezig"
	_balk.visible = bezig
	_balk.indeterminate = true
	_check.disabled = bezig or Updater.app_base == "dev"
	_download.visible = Updater.status == "beschikbaar"
	_back.visible = Updater.patch_geladen and not Updater.herstart_nodig
