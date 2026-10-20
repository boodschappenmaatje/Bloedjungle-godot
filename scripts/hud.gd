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
		hp_bar.value = p.hp / Data.PLAYER_HP * 100.0
		var w: Dictionary = Data.WEAPONS[p.weapon]
		ammo.text = "%s   %s" % [w.name, "herladen..." if p.reload_t > 0.0 else "%d / %d" % [p.ammo, w.mag]]
	base_bar.value = Game.base_hp / Game.base_max * 100.0
	info.text = "Golf %d   Punten %d   Kills %d   (v7)" % [Game.wave, Game.points, Game.kills]


func _on_banner(b: String, s: String, t: float) -> void:
	big.text = b
	small.text = s
	_banner_t = t


func _on_over(reason: String) -> void:
	over_text.text = "%s\nScore %d   Kills %d" % [reason, Game.score, Game.kills]
	over_box.show()
