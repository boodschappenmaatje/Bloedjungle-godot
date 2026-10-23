extends CanvasLayer
## Meldingen en knoppen midden op het scherm (golf-titel, "Start nu", gesneuveld). De balken, punten
## en munitie staan in hud_extra.gd, de wapenkamer in shop.gd; alles in de stijl van de web-versie.

const VERSION := "v70"

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
	add_child(GateHud.new())
	_style()
	# schermtekst en sticks schalen mee met de schermgrootte: op een telefoon staat 1 punt = meerdere pixels
	get_window().size_changed.connect(_rescale)
	_rescale()


func _style() -> void:
	# golf-titel en ondertitel
	var ls: LabelSettings = big.label_settings.duplicate()
	ls.font = UI.display(1)
	ls.font_size = 32
	ls.font_color = UI.INK
	ls.outline_size = 0
	ls.shadow_color = Color(0, 0, 0, 0.9)
	ls.shadow_offset = Vector2(0, 3)
	ls.shadow_size = 4
	big.label_settings = ls
	var ss := LabelSettings.new()
	ss.font = UI.body(600, 2)
	ss.font_size = 13
	ss.font_color = UI.INK_DIM
	ss.shadow_color = Color(0, 0, 0, 0.9)
	ss.shadow_offset = Vector2(0, 2)
	ss.shadow_size = 3
	small.label_settings = ss
	$Banner.offset_top = 64.0
	$Banner.offset_bottom = 120.0
	$Banner.add_theme_constant_override("separation", 6)
	# "Start nu" staat links naast "Wapenkamer"
	start_btn.text = "START NU"
	UI.style_button(start_btn, "gold")
	start_btn.add_theme_font_size_override("font_size", 12)
	start_btn.custom_minimum_size = Vector2(0, 32)
	start_btn.offset_top = 132.0
	start_btn.offset_bottom = 164.0
	start_btn.offset_right = -2.0
	start_btn.offset_left = -2.0 - 88.0
	# versiemarkering (zodat je kunt zien welke versie draait)
	info.text = VERSION
	info.add_theme_font_override("font", UI.body(600, 1))
	info.add_theme_font_size_override("font_size", 11)
	info.add_theme_color_override("font_color", Color(UI.INK_DIM, 0.6))
	info.offset_top = 66.0
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
	var touch := DisplayServer.is_touchscreen_available() or OS.get_environment("BJ_TOUCH") == "1"
	get_window().content_scale_factor = clampf(minf(s.x, s.y) / (430.0 if touch else 720.0), 1.0, 4.0)


func _process(delta: float) -> void:
	if _banner_t > 0.0:
		_banner_t -= delta
		if _banner_t <= 0.0:
			big.text = ""
			small.text = ""
	if Game.state == "prep" and _banner_t <= 0.0:
		big.text = "GOLF %d" % Game.wave
		small.text = ("Begint over %d · koop wapens en upgrades" % ceili(Game.prep_t)).to_upper()
	var shown: bool = Game.state != "shop" and Game.state != "menu" and not Game.build_mode
	big.visible = shown
	small.visible = shown
	start_btn.visible = Game.state == "prep" and not Game.build_mode


func _on_banner(b: String, s: String, t: float) -> void:
	big.text = b
	small.text = s.to_upper()
	_banner_t = t


func _on_over(_reason: String) -> void:
	pass  # het gesneuveld-scherm staat in pause_menu.gd
