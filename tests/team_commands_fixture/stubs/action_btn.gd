class_name ActionBtn
extends Button

var kind := ""
var caption := ""
var badge := ""
const SIZE := Vector2(54, 54)

func set_caption(value: String) -> void:
	caption = value

static func make(button_kind: String, text_caption: String) -> ActionBtn:
	var b := ActionBtn.new()
	b.kind = button_kind
	b.caption = text_caption
	b.add_to_group("hud_button")
	return b
