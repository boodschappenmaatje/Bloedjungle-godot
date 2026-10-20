extends CanvasLayer
## Schermteksten: levens van jou en de bunker, punten, golf, munitie, meldingen en de knoppen.

@onready var hp_bar: ProgressBar = %HpBar
@onready var base_bar: ProgressBar = %BaseBar
@onready var info: Label = %Info
@onready var ammo: Label = %Ammo
@onready var big: Label = %Big
@onready var small: Label = %Small
@onready var start_btn: Button = %StartWave
@onready var over_box: Control = %Over
@onready var over_text: Label = %OverText

var _banner_t := 0.0


func _ready() -> void:
	Game.changed.connect(_refresh)
	Game.banner.connect(_on_banner)
	Game.over.connect(_on_over)
	start_btn.pressed.connect(func(): get_parent().start_wave())
	%Restart.pressed.connect(func(): get_tree().reload_current_scene())
	over_box.hide()
	add_child(HudExtra.new())
	add_child(Shop.new())
	# schermtekst en sticks schalen mee met de schermgrootte: op een telefoon staat 1 punt = meerdere pixels
	get_window().size_changed.connect(_rescale)
	_rescale()
	_refresh()


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
	if Game.state == "prep":
		start_btn.text = "Start golf %d  (%d)" % [Game.wave, ceili(Game.prep_t)]
	start_btn.visible = Game.state == "prep"


func _refresh() -> void:
	var p = Game.player
	if p:
		hp_bar.value = p.hp / Game.max_hp() * 100.0
		$Top/HpLabel.text = "Leven   %d / %d" % [ceili(p.hp), roundi(Game.max_hp())]
		var w: Dictionary = Game.wstat(p.weapon)
		ammo.text = "…" if p.reload_t > 0.0 else "%d | %d" % [p.ammo, w.mag]
		ammo.add_theme_font_size_override("font_size", 30)
		ammo.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		ammo.add_theme_constant_override("outline_size", 6)
		var low: bool = p.reload_t <= 0.0 and p.ammo <= w.mag * 0.25
		ammo.add_theme_color_override("font_color", Color(1, 0.3, 0.25) if low else (Color(1, 0.86, 0.45) if p.reload_t > 0.0 else Color(1, 1, 1)))
	base_bar.value = Game.base_hp / Game.base_max * 100.0
	$Top/BaseLabel.text = "Bunker   %d / %d" % [ceili(Game.base_hp), roundi(Game.base_max)]
	info.text = "Kills %d   (v13)" % Game.kills


func _on_banner(b: String, s: String, t: float) -> void:
	big.text = b
	small.text = s
	_banner_t = t


func _on_over(reason: String) -> void:
	over_text.text = "%s\nScore %d   Kills %d" % [reason, Game.score, Game.kills]
	over_box.show()
