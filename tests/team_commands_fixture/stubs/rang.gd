class_name Rang
extends RefCounted
## Fixture-only stub voor scripts/rang.gd: de teamcommando-tests kiezen alleen krachten in het wiel.
const VOLGORDE := ["artillerie", "napalm", "satelliet", "reparatie"]
const KRACHTEN := {
	"artillerie": {"naam": "ARTILLERIE"}, "napalm": {"naam": "NAPALM"},
	"satelliet": {"naam": "SATELLIET"}, "reparatie": {"naam": "REPARATIE"},
}
const NAPALM_TAP := 8.0
const NAPALM_RANGE_MIN := 8.0
const NAPALM_RANGE_MAX := 30.0
static var owned: Array = ["artillerie", "napalm"]   # de krachten die je "hebt" in de test
static var used: Array = []

static func heeft(id: String) -> bool: return owned.has(id)
static func klaar(id: String) -> bool: return owned.has(id)
static func niveau(id: String) -> int: return 1 if owned.has(id) else 0
static func beschikbaar() -> Array: return owned.duplicate()
static func cd_rest(_id: String) -> float: return 0.0
static func afkoeling(_id: String) -> float: return 90.0
static func huidig() -> String:
	if owned.has(Game.kracht_sel):
		return Game.kracht_sel
	return "" if owned.is_empty() else String(owned[0])
static func gebruik(id: String, _main: Node, _at: Vector3, _dir: Vector3) -> bool:
	used.append(id)
	return true
static func teken_icoon(_ci: CanvasItem, _id: String, _c: Vector2, _s: float, _col: Color) -> void: pass
