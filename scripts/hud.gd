extends CanvasLayer
## Meldingen en knoppen midden op het scherm (golf-titel, "Start nu", gesneuveld). De balken, punten
## en munitie staan in hud_extra.gd, de wapenkamer in shop.gd; alles in de stijl van de web-versie.

const VERSION := "v135"

@onready var info: Label = %Info
@onready var big: Label = %Big
@onready var small: Label = %Small
@onready var start_btn: Button = %StartWave
@onready var over_box: PanelContainer = %Over
@onready var over_text: Label = %OverText

var _banner_t := 0.0


func _ready() -> void:
	$Top.hide()
	%Ammo.hide()
	Game.banner.connect(_on_banner)
	Game.over.connect(_on_over)
	start_btn.pressed.connect(func(): get_parent().start_wave())
	%Restart.pressed.connect(func(): get_tree().reload_current_scene())
	over_box.hide()
	var extra := HudExtra.new()
	extra.name = "HudExtra"
	add_child(extra)
	var weapon_strip: Control = load("res://scripts/weapon_strip.gd").new()
	add_child(weapon_strip)
	add_child(CombatButtons.new())
	add_child(load("res://scripts/perf_monitor.gd").new())
	add_child(Shop.new())
	add_child(PlaceHud.new())
	add_child(BuildMode.new())
	add_child(StadEditor.new())
	add_child(GateHud.new())
	_style()
	# schermtekst en sticks schalen mee met de schermgrootte: op een telefoon staat 1 punt = meerdere pixels
	get_window().size_changed.connect(_rescale)
	_rescale()


func _style() -> void:
	# golf-titel en ondertitel
	var ls: LabelSettings = big.label_settings.duplicate()
	ls.font = UI.display(1)
	ls.font_size = 20
	ls.font_color = UI.INK
	ls.outline_size = 0
	ls.shadow_color = Color(0, 0, 0, 0.7)
	ls.shadow_offset = Vector2(0, 1)
	ls.shadow_size = 2
	big.label_settings = ls
	var ss := LabelSettings.new()
	ss.font = UI.body(600, 2)
	ss.font_size = 12
	ss.font_color = UI.BRASS
	small.label_settings = ss
	$BannerPlate/Banner.add_theme_constant_override("separation", 0)
	var plate := UI.box(Color(0.025, 0.035, 0.027, 0.91), Color(UI.BRASS, 0.38), 1, 7, 7)
	plate.border_width_bottom = 2
	plate.content_margin_top = 4
	plate.content_margin_bottom = 4
	$BannerPlate.add_theme_stylebox_override("panel", plate)
	$BannerPlate.custom_minimum_size = Vector2(216, 48)
	$BannerPlate.offset_left = -108.0
	$BannerPlate.offset_right = 108.0
	# "Start nu" staat links naast "Wapenkamer"
	start_btn.text = "START NU"
	UI.style_button(start_btn, "gold")
	start_btn.add_theme_font_size_override("font_size", 12)
	start_btn.custom_minimum_size = Vector2(0, 30)
	start_btn.offset_top = 62.0
	start_btn.offset_bottom = 92.0
	start_btn.offset_right = -2.0
	start_btn.offset_left = -2.0 - 96.0
	# versiemarkering (zodat je kunt zien welke versie draait)
	info.text = VERSION
	info.add_theme_font_override("font", UI.body(600, 1))
	info.add_theme_font_size_override("font_size", 11)
	info.add_theme_color_override("font_color", Color(UI.INK_DIM, 0.6))
	info.offset_top = 68.0
	info.offset_left = 12.0
	# gesneuveld-scherm
	over_box.add_theme_stylebox_override("panel", UI.box(UI.PANEL, UI.PANEL_LINE, 1, 6, 20))
	var title: Label = $Over/Box/Title
	var ts := LabelSettings.new()
	ts.font = UI.display(1)
	ts.font_size = 34
	ts.font_color = UI.INK
	title.label_settings = ts
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	over_text.add_theme_font_override("font", UI.body(600, 0))
	over_text.add_theme_font_size_override("font_size", 16)
	over_text.add_theme_color_override("font_color", UI.INK_DIM)
	over_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	$Over/Box.add_theme_constant_override("separation", 12)
	UI.style_button(%Restart, "primary")
	%Restart.text = "OPNIEUW"


func _rescale() -> void:
	var s := get_window().size
	var touch := UI.is_touch_platform()
	get_window().content_scale_factor = clampf(minf(s.x, s.y) / (430.0 if touch else 720.0), 1.0, 4.0)
	_layout_wave_banner()


func _layout_wave_banner() -> void:
	var view_size := Vector2(get_viewport().get_visible_rect().size)
	var safe := UI.safe_margins(view_size)
	var top := safe.y + 8.0
	$BannerPlate.offset_top = top
	$BannerPlate.offset_bottom = top + 48.0
	start_btn.offset_top = top + 54.0
	start_btn.offset_bottom = start_btn.offset_top + 30.0


func _process(delta: float) -> void:
	info.visible = false  # de versie staat nu achter de fps-teller (HudExtra); hier zat hij onder de TACTISCH-knoppen
	if _banner_t > 0.0:
		_banner_t -= delta
	var temporary_banner := _banner_t > 0.0
	if not temporary_banner:
		big.text = "GOLF %d" % maxi(Game.wave, 1) if Game.state == "prep" or Game.state == "play" else ""
		if Game.state == "prep":
			var seconds := ceili(Game.prep_t)
			small.text = "%02d:%02d" % [floori(seconds / 60.0), posmod(seconds, 60)]
			if not Game.routes.is_empty():
				var names := []
				for id in Game.routes:
					names.append(String(AanvalRoutes.LIST[id].naam))
				small.text += "  ·  VIA " + " + ".join(names)
		else:
			small.text = ""
	var shown: bool = Game.state != "shop" and Game.state != "menu" and Game.state != "over"
	# De bestaande plaat blijft tijdens prep de golf en timer tonen. In play verschijnen alleen
	# tijdelijke Game.banner-meldingen; na hun bestaande timer verdwijnt de hele Control.
	var banner_visible := shown and (Game.state == "prep" or temporary_banner)
	$BannerPlate.visible = banner_visible
	big.visible = banner_visible and big.text != ""
	small.visible = banner_visible and small.text != ""
	start_btn.visible = Game.state == "prep" and not Game.build_mode


func _on_banner(b: String, s: String, t: float) -> void:
	big.text = b
	small.text = s.to_upper()
	_banner_t = t


func _on_over(_reason: String) -> void:
	pass  # het gesneuveld-scherm staat in pause_menu.gd
