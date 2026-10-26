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
	_download = _knop("Download en installeer", "primary", func(): Updater.download_en_installeer())
	v.add_child(_download)
	_back = _knop("Terugdraaien naar de app-versie", "secondary", func(): Updater.terugdraaien())
	v.add_child(_back)
	_close = _knop("Sluiten", "secondary", queue_free)
	v.add_child(_close)
	Updater.status_changed.connect(_ververs)
	_ververs()


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
