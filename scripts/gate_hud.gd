class_name GateHud
extends Control
## Knop om de poort te openen en sluiten zodra je erbij staat (toets E), en bij een beschadigde poort een
## knop die je ingedrukt houdt om hem te repareren (updateGateRepair in 05b-gates.js).

var _btn: Button
var _fix: Button
var _holding := false
var _snd := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_btn = _mk("OPEN POORT", "gold")
	_btn.pressed.connect(_toggle)
	_fix = _mk("REPAREER", "buy")
	_fix.button_down.connect(func(): _holding = true)
	_fix.button_up.connect(func(): _holding = false)


func _mk(text: String, kind: String) -> Button:
	var b := Button.new()
	b.add_to_group("hud_button")
	b.text = text
	UI.style_button(b, kind)
	b.add_theme_font_override("font", UI.display(1))
	b.add_theme_font_size_override("font_size", 15)
	b.visible = false
	add_child(b)
	return b


func _toggle() -> void:
	var g: Variant = Game.gates.near_player() if Game.gates else null
	if g != null:
		Game.gates.toggle(g)


func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_E and not Game.build_mode:
		_toggle()


func _process(delta: float) -> void:
	var live := (Game.state == "play" or Game.state == "prep") and not Game.build_mode and Game.gates != null
	var g: Variant = Game.gates.near_player() if live else null
	_btn.visible = g != null
	var fixable: Variant = null
	if live and Game.player:
		for x in Game.gates.list:
			if not x.broken and x.hp < x.max_hp and Game.player.global_position.distance_to(Game.gates.pos_of(x)) < 3.6:
				fixable = x
	_fix.visible = fixable != null
	var bottom := size.y - 64.0
	if g != null:
		var open: bool = g.user_open or g.open > 0.5
		var hp_line := "" if g.hp >= g.max_hp else "\nsterkte %d%%" % roundi(g.hp / g.max_hp * 100.0)
		_btn.text = ("SLUIT POORT" if open else "OPEN POORT") + hp_line
		_btn.size = Vector2(150, 46)
		_btn.position = Vector2(size.x * 0.5 - 75.0, bottom - 56.0)
	if fixable != null:
		_fix.size = Vector2(120, 46)
		_fix.position = Vector2(size.x * 0.5 - 75.0 - 128.0, bottom - 56.0)
		if _holding:
			fixable.hp = minf(fixable.max_hp, fixable.hp + 140.0 * delta)
			_snd -= delta
			if _snd <= 0.0:
				_snd = 0.22
				Sfx.play("ping", 0.5, Game.gates.pos_of(fixable))
			Game.changed.emit() if Engine.get_process_frames() % 15 == 0 else null
	else:
		_holding = false
