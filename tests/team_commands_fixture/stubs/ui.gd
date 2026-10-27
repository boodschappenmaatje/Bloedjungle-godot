extends Node

const PANEL := Color(0.04, 0.05, 0.04)
const BRASS := Color(0.8, 0.6, 0.2)
const PANEL_LINE := Color(0.4, 0.4, 0.3)
const INK := Color(1, 1, 1)
const INK_DIM := Color(0.5, 0.5, 0.5)

func safe_margins(_size: Vector2) -> Vector4:
	return Vector4.ZERO

func body(_weight: int) -> Font:
	return ThemeDB.fallback_font

func is_touch_platform() -> bool:
	return false

func style_button(_button: Button, _style: String) -> void:
	pass
