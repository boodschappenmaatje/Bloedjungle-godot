class_name Gebieden
extends Node3D
## Bezette gebieden in de stad: vijanden verdedigen hun gebied in plaats van naar de basis te lopen.
## Verdedigers worden pas aangemaakt als de speler dichtbij komt, blijven op hun post en worden alert als de speler
## in het gebied komt of er wordt geschoten of ontploft (zie enemy.gd, zone/post/awake). Per gebied hangt er een klein,
## doorzichtig getal met het aantal verdedigers, alleen bij het dichtstbijzijnde gebied; als het leeg is verdwijnt het.

## rect = x, z, breedte, diepte van het gebied (m); posts = waar de verdedigers staan; kinds = soorten (om beurten).
## base = aantal verdedigers op golf 1, het groeit mee met de golf tot maximaal max.
const ZONES := {
	"brugkop": {"naam": "BRUGKOP", "rect": Rect2(-16, -112, 32, 16), "base": 3, "max": 6, "kinds": ["knife", "rifle", "rifle"],
		"posts": [Vector3(5, 0, -100), Vector3(-5, 0, -104), Vector3(4, 0, -109), Vector3(-4, 0, -111), Vector3(9, 0, -105), Vector3(-8, 0, -110)]},
	"woonwijk": {"naam": "WOONWIJK", "rect": Rect2(-46, -138, 34, 34), "base": 4, "max": 9, "kinds": ["rifle", "rifle", "knife", "rocket"],
		"posts": [Vector3(-30, 0, -112), Vector3(-30, 0, -121), Vector3(-22, 0, -108), Vector3(-38, 0, -108), Vector3(-22, 0, -126), Vector3(-38, 0, -126), Vector3(-30, 0, -131), Vector3(-17, 0, -112), Vector3(-45, 0, -122)]},
	"industrie": {"naam": "INDUSTRIE", "rect": Rect2(30, -122, 32, 26), "base": 4, "max": 9, "kinds": ["knife", "heavy", "rifle", "rifle"],
		"posts": [Vector3(34, 0, -100), Vector3(40, 0, -101), Vector3(47, 0, -100), Vector3(36, 0, -119), Vector3(48, 0, -119), Vector3(57, 0, -108), Vector3(58, 0, -115), Vector3(34, 0, -108), Vector3(56, 0, -100)]},
	"kade": {"naam": "KADE", "rect": Rect2(-72, -105, 52, 11), "base": 4, "max": 8, "kinds": ["knife", "knife", "rifle"],
		"posts": [Vector3(-62, 0, -100), Vector3(-54, 0, -99), Vector3(-46, 0, -100), Vector3(-38, 0, -99), Vector3(-30, 0, -100), Vector3(-24, 0, -99), Vector3(-66, 0, -102), Vector3(-34, 0, -102)]},
	"plein": {"naam": "PLEIN", "rect": Rect2(-16, -147, 32, 23), "base": 5, "max": 10, "kinds": ["rifle", "heavy", "knife", "rifle", "rocket"],
		"posts": [Vector3(-8, 0, -128), Vector3(8, 0, -128), Vector3(-6, 0, -141), Vector3(6, 0, -141), Vector3(0, 0, -143), Vector3(-12, 0, -134), Vector3(12, 0, -134), Vector3(-3, 0, -125), Vector3(3, 0, -125), Vector3(0, 0, -138)]},
}

const SPAWN_DIST := 70.0   # de verdedigers verschijnen als de speler zo dichtbij komt (m, tot de rand van het gebied)
const SHOW_DIST := 42.0    # het getal verschijnt binnen deze afstand
const CHECK_EVERY := 0.25

var state := {}   # id -> {"guards": Array, "spawned": bool, "start": int, "cleared": bool, "label": Label3D, "queue": Array}
var _t := 0.0


static func center(id: String) -> Vector3:
	var r: Rect2 = ZONES[id].rect
	return Vector3(r.get_center().x, 0.0, r.get_center().y)


## Ligt p in het gebied, met een marge (m) eromheen?
static func inside(id: String, p: Vector3, margin := 0.0) -> bool:
	var r: Rect2 = ZONES[id].rect
	return r.grow(margin).has_point(Vector2(p.x, p.z))


## Afstand van p tot de rand van het gebied (0 als p erin ligt).
static func dist_to(id: String, p: Vector3) -> float:
	var r: Rect2 = ZONES[id].rect
	var dx := maxf(maxf(r.position.x - p.x, p.x - r.end.x), 0.0)
	var dz := maxf(maxf(r.position.y - p.z, p.z - r.end.y), 0.0)
	return Vector2(dx, dz).length()


static func garrison_size(id: String, wave: int) -> int:
	var z: Dictionary = ZONES[id]
	return mini(int(z.max), int(z.base) + maxi(0, wave - 1) / 2)


func _ready() -> void:
	Game.gebieden = self
	reset()


## Alles op nul: nieuwe missie of herstart.
func reset() -> void:
	for id in state:
		var s: Dictionary = state[id]
		for g in s.guards:
			if is_instance_valid(g):
				Game.enemies.erase(g)
				g.queue_free()
		if is_instance_valid(s.label):
			s.label.queue_free()
	state.clear()
	for id in ZONES:
		state[id] = {"guards": [], "spawned": false, "start": 0, "cleared": false, "label": null, "queue": [], "flash": 0.0}


func is_cleared(id: String) -> bool:
	return state.has(id) and state[id].cleared


func alive(id: String) -> int:
	var n := 0
	for g in state[id].guards:
		if is_instance_valid(g) and not g.dead:
			n += 1
	return n


func _process(delta: float) -> void:
	var p = Game.player
	if p == null or Game.state == "menu" or Game.state == "over" or state.is_empty():
		return
	var pos: Vector3 = p.global_position
	# verdedigers aanmaken, een of twee per beeld zodat het niet hapert
	for id in state:
		var s: Dictionary = state[id]
		if s.cleared:
			continue
		if not s.spawned and dist_to(id, pos) < SPAWN_DIST and (Game.state == "prep" or Game.state == "play"):
			_plan(id)
		if not s.queue.is_empty():
			_spawn_one(id)
	_t -= delta
	if _t > 0.0:
		_fade(delta)
		return
	_t = CHECK_EVERY
	var best := ""
	var best_d := SHOW_DIST
	for id in state:
		var s: Dictionary = state[id]
		if s.cleared or not s.spawned:
			continue
		var n := alive(id)
		if n == 0 and s.queue.is_empty():
			_clear(id)
			continue
		var d := dist_to(id, pos)
		if d < best_d:
			best_d = d
			best = id
	for id in state:
		var s: Dictionary = state[id]
		if s.cleared or not s.spawned:
			continue
		_show(id, id == best)
	_fade(delta)


func _plan(id: String) -> void:
	var s: Dictionary = state[id]
	s.spawned = true
	var z: Dictionary = ZONES[id]
	var n := garrison_size(id, Game.wave)
	var posts: Array = z.posts.duplicate()
	posts.shuffle()
	var kinds: Array = z.kinds
	for i in n:
		var kind: String = kinds[i % kinds.size()]
		s.queue.append([kind, posts[i % posts.size()]])
	s.start = n
	PerfMonitor.note("gebied %s bezet door %d" % [id, n])


func _spawn_one(id: String) -> void:
	var s: Dictionary = state[id]
	var job: Array = s.queue.pop_front()
	var e: Node3D = load("res://scenes/enemy.tscn").instantiate()
	e.setup(job[0], Game.wave)
	e.zone = id
	e.post = job[1]
	e.position = job[1]
	e.rotation.y = randf() * TAU
	get_parent().add_child(e)
	s.guards.append(e)


func _clear(id: String) -> void:
	var s: Dictionary = state[id]
	s.cleared = true
	PerfMonitor.note("gebied %s vrij" % id)
	var l: Label3D = s.label
	if l != null and is_instance_valid(l):
		l.text = "✓"
		l.modulate = Color(0.5, 0.95, 0.35, 0.9)
		s.flash = 1.6
	Game.changed.emit()


## Het getal laten staan of laten vervagen.
func _show(id: String, on: bool) -> void:
	var s: Dictionary = state[id]
	if on and s.label == null:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = false
		l.pixel_size = 0.016
		l.font_size = 64
		l.outline_size = 14
		l.outline_modulate = Color(0, 0, 0, 0.6)
		l.modulate = Color(1.0, 0.5, 0.4, 0.0)
		l.position = center(id) + Vector3(0, 5.5, 0)
		l.render_priority = 5
		add_child(l)
		s.label = l
	var l2: Label3D = s.label
	if l2 == null:
		return
	if on:
		l2.text = str(alive(id) + s.queue.size())
		# het getal hangt boven de dichtstbijzijnde verdediger, zodat het niet achter de knoppen of onder de rand van het beeld valt
		var p = Game.player
		var best: Variant = null
		var bd := INF
		for g in s.guards:
			if is_instance_valid(g) and not g.dead:
				var d: float = g.global_position.distance_to(p.global_position)
				if d < bd:
					bd = d
					best = g
		if best != null:
			l2.set_meta("target", best.global_position + Vector3(0, 3.6, 0))
	l2.set_meta("want", 0.8 if on else 0.0)


func _fade(delta: float) -> void:
	for id in state:
		var s: Dictionary = state[id]
		var l: Label3D = s.label
		if l == null or not is_instance_valid(l):
			continue
		if s.cleared:
			s.flash -= delta
			var a := clampf(s.flash / 0.6, 0.0, 1.0) * 0.9
			l.modulate.a = a
			if s.flash <= 0.0:
				l.queue_free()
				s.label = null
			continue
		if l.has_meta("target"):
			var tp: Vector3 = l.get_meta("target")
			l.position = tp if l.modulate.a < 0.05 else l.position.lerp(tp, minf(1.0, delta * 5.0))
		var want: float = l.get_meta("want", 0.0)
		l.modulate.a = move_toward(l.modulate.a, want, delta * 1.2)


## Aantal vijanden dat bij de golf hoort (verdedigers tellen niet mee voor de golf).
static func wave_count() -> int:
	var n := 0
	for e in Game.enemies:
		if is_instance_valid(e) and e.zone == "":
			n += 1
	return n
