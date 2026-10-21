class_name Loading
extends CanvasLayer
## Laadscherm met voortgangsbalk, voor de wereld wordt opgebouwd en alles één keer is getekend.

var _bar: ColorRect
var _fill: ColorRect
var _text: Label
const BAR_W := 520.0


func _init() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("0d110a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 18)
	add_child(box)
	var title := UI.label("BLOEDJUNGLE", UI.display(2), 54, UI.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_text = UI.label("Wereld bouwen...", UI.body(600, 1), 22, UI.INK_DIM)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_text)
	var holder := CenterContainer.new()
	box.add_child(holder)
	_bar = ColorRect.new()
	_bar.color = UI.PANEL_LINE
	_bar.custom_minimum_size = Vector2(BAR_W, 12)
	holder.add_child(_bar)
	_fill = ColorRect.new()
	_fill.color = UI.OLIVE_HI
	_fill.size = Vector2(0, 12)
	_bar.add_child(_fill)
	var tip := UI.label("Tip: sta vlak achter de muur of een omgevallen stam voor dekking.", UI.body(500, 0), 18, UI.INK_DIM)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tip)


func set_progress(frac: float, text: String) -> void:
	_fill.size.x = BAR_W * clampf(frac, 0.0, 1.0)
	_text.text = text
