class_name Streak
extends RefCounted
const NAPALM_TAP := 8.0
const NAPALM_RANGE_MIN := 8.0
const NAPALM_RANGE_MAX := 30.0
static func reward(_id: String) -> Dictionary: return {"kort": ""}
static func use(_id: String, _parent: Node, _target: Vector3, _dir: Vector3) -> void: pass
static func draw_icon(_ci: CanvasItem, _id: String, _c: Vector2, _s: float, _col: Color) -> void: pass
