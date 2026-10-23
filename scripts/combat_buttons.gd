class_name CombatButtons
extends Control
## Ronde knoppen voor herladen, sprint, granaat en ontwijkrol, rechtsonder binnen bereik van de duim die richt.
## Vaste plekken, zodat ze de sticks, de wapenstrip, de radar en de verdedigingsknoppen niet raken.

var _reload: ActionBtn
var _sprint: ActionBtn
var _grenade: ActionBtn
var _roll: ActionBtn
var _state := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reload = _make("herlaad", "HERLAAD", func(): _player_call("request_reload"))
	_sprint = _make("sprint", "SPRINT", func(): _player_call("toggle_sprint"))
	_grenade = _make("granaat", "GEBRUIK", _use_equipment)
	_roll = _make("rol", "ROL", func(): _player_call("request_dodge"))
	resized.connect(_layout)
	_layout()


func _make(kind: String, caption: String, action: Callable) -> ActionBtn:
	var b := ActionBtn.make(kind, caption)
	b.focus_mode = Control.FOCUS_NONE
	b.visible = true  # ActionBtn.make verbergt nieuwe knoppen; deze zijn er altijd, de container bepaalt of ze getoond worden
	b.button_down.connect(action)  # reageert meteen bij aanraking, niet pas bij loslaten
	add_child(b)
	return b


func _player_call(method: String) -> void:
	var p = Game.player
	if p != null and is_instance_valid(p):
		p.call(method)


func _use_equipment() -> void:
	match Game.equipment_sel:
		"grenade":
			_player_call("throw_grenade")
		"mine":
			if Game.defs != null and is_instance_valid(Game.defs):
				Game.defs.place_kind("mine")


## Alles rechts, binnen bereik van de duim die richt: 2x2 raster in de rechteronderhoek.
## Onder: sprint + rol, boven: granaat + herlaad. De wisselknop (shop.gd) staat links van het raster.
func _layout() -> void:
	var safe := UI.safe_margins(size)
	var g := ActionBtn.SIZE.x + 8.0
	var x1 := size.x - safe.z - 4.0 - ActionBtn.SIZE.x
	var x0 := x1 - g
	var y1 := size.y - safe.w - 4.0 - ActionBtn.SIZE.y
	if UI.is_touch_platform():
		var stick_center_x := size.x - safe.z - (76.0 if size.x < 880.0 else 86.0)
		var stick_edge_x := stick_center_x - 76.0
		x1 = stick_edge_x - 10.0 - ActionBtn.SIZE.x
		x0 = x1 - g
		if size.x < size.y:
			y1 = size.y - 360.0 - maxf(0.0, safe.w - 12.0)
		else:
			y1 = size.y - safe.w - 4.0 - ActionBtn.SIZE.y
	elif size.x < size.y:
		y1 = size.y - 222.0 - 8.0 - ActionBtn.SIZE.y - maxf(0.0, safe.w - 12.0)  # staand: boven de wapenstrip
	var y0 := y1 - g
	_sprint.position = Vector2(x0, y1)
	_roll.position = Vector2(x1, y1)
	_grenade.position = Vector2(x0, y0)
	_reload.position = Vector2(x1, y0)
	for b in [_reload, _sprint, _grenade, _roll]:
		b.size = ActionBtn.SIZE


func _process(_delta: float) -> void:
	var show := (Game.state == "play" or Game.state == "prep") and not Game.build_mode
	visible = show
	var p = Game.player
	if not show or p == null or not is_instance_valid(p):
		return
	var w: Dictionary = Game.wstat(p.weapon)
	var reloading: bool = p.reload_t > 0.0
	var equipment_count: int = Game.grenades if Game.equipment_sel == "grenade" else int(Game.inv.get("mine", 0)) if Game.equipment_sel == "mine" else 0
	var key := "%s|%s|%d|%s|%.2f|%.2f|%s|%s|%d" % [str(p.sprint_on), str(p.sprinting), Game.grenades, str(reloading), p.stamina, p.dodge_cd, str(p.ammo >= w.mag), Game.equipment_sel, equipment_count]
	if key == _state:
		return
	_state = key
	_reload.disabled = p.ammo >= w.mag or reloading or p.driving
	_sprint.open_state = p.sprint_on
	_sprint.bar = p.stamina
	_sprint.disabled = p.driving
	_sprint.queue_redraw()
	_grenade.equipment_kind = Game.equipment_sel
	_grenade.badge = "×%d" % equipment_count
	_grenade.disabled = equipment_count <= 0 or p.driving
	_grenade.queue_redraw()
	_roll.disabled = p.dodge_cd > 0.0 or p.stamina < p.DODGE_COST or p.driving
	_roll.bar = (1.0 - p.dodge_cd / p.DODGE_CD) if p.dodge_cd > 0.0 else -1.0
	_roll.queue_redraw()
	_reload.queue_redraw()
