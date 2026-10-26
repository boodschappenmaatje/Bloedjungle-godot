class_name Streak
extends RefCounted
## Killstreak (luchtsteun): de ladder met beloningen, de kleine pictogrammen voor teller en knop, en het uitvoeren van een beloning.
## Teller en bank staan in Game (streak, streak_bank); de dogtag-teller in streak_hud.gd, de knop in combat_buttons.gd.
## Kills van jezelf en van jouw voertuigen tellen; kills van soldaten en van luchtsteun tellen niet (Game.hit_src).

const LADDER := [
	{"id": "truck", "kills": 10, "naam": "VERSTERKING", "kort": "TRUCK", "klaar": "VERSTERKING KLAAR"},
	{"id": "napalm", "kills": 16, "naam": "NAPALM-AANVAL", "kort": "NAPALM", "klaar": "NAPALM KLAAR"},
]

const TRUCK_SOLDIERS := 4
const TRUCK_STAY := 60.0     # s dat de versterking blijft
const NAPALM_LENGTH := 20.0  # m lengte van de brandstrook
const NAPALM_WIDTH := 5.0    # m breed
const NAPALM_RANGE_MIN := 8.0
const NAPALM_RANGE_MAX := 30.0
const NAPALM_TAP := 14.0     # alleen tikken: zo ver recht vooruit
const FADE_AFTER := 4.0      # s dat de teller na een kill in beeld blijft


static func reward(id: String) -> Dictionary:
	for r in LADDER:
		if r.id == id:
			return r
	return {}


## Eerstvolgende beloning die in deze streak nog niet is verdiend, of een leeg woordenboek.
static func next_reward() -> Dictionary:
	for r in LADDER:
		if not Game.streak_given.has(r.id):
			return r
	return {}


## Kills sinds de vorige drempel en kills tussen de vorige en de volgende drempel: {done, span}.
static func progress() -> Dictionary:
	var prev := 0
	for r in LADDER:
		if Game.streak_given.has(r.id):
			prev = int(r.kills)
	var nx := next_reward()
	var to: int = int(nx.kills) if not nx.is_empty() else maxi(prev, 1)
	return {"done": clampi(Game.streak - prev, 0, to - prev), "span": maxi(to - prev, 1)}


## Tekent het pictogram van een beloning in een Control (teller en knop). c = midden, s = schaal (1 = knopgrootte).
static func draw_icon(ci: CanvasItem, id: String, c: Vector2, s: float, col: Color) -> void:
	var dark := Color(0.05, 0.06, 0.04, 0.9)
	match id:
		"truck":
			ci.draw_rect(Rect2(c + Vector2(-14, -7) * s, Vector2(17, 13) * s), col)          # laadbak
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(5, -3) * s, c + Vector2(11, -3) * s, c + Vector2(15, 2) * s, c + Vector2(15, 6) * s, c + Vector2(5, 6) * s]), col)  # cabine
			ci.draw_circle(c + Vector2(-8, 8) * s, 3.4 * s, col)
			ci.draw_circle(c + Vector2(9, 8) * s, 3.4 * s, col)
			ci.draw_circle(c + Vector2(-8, 8) * s, 1.3 * s, dark)
			ci.draw_circle(c + Vector2(9, 8) * s, 1.3 * s, dark)
		"napalm":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -14) * s, c + Vector2(5, -6) * s, c + Vector2(10, 1) * s, c + Vector2(8, 8) * s, c + Vector2(0, 12) * s,
				c + Vector2(-8, 8) * s, c + Vector2(-10, 0) * s, c + Vector2(-5, -5) * s, c + Vector2(-3, -9) * s]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -2) * s, c + Vector2(4, 4) * s, c + Vector2(0, 9) * s, c + Vector2(-4, 4) * s]), dark)


## Voert een beloning uit. target/dir: alleen voor napalm (midden en richting van de strook).
static func use(id: String, main: Node, target: Vector3, dir: Vector3) -> void:
	Game.streak_air[id] = int(Game.streak_air.get(id, 0)) + 1
	match id:
		"truck":
			var v := Versterking.new()
			main.add_child(v)
			v.start(Game.player.global_position)
		"napalm":
			var n := NapalmAanval.new()
			main.add_child(n)
			n.start(target, dir)
