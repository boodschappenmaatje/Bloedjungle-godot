class_name Gates
extends Node3D
## De twee stalen schuifpoorten (05b-gates.js). Het paneel hangt vóór de muur en schuift langzaam
## (2,5 s, animatie uit assets/poort.glb) opzij langs de buitenkant. Jij opent en sluit met de knop bij
## de poort, je soldaten openen hem als ze erdoor moeten, vijanden nooit: die slaan of schieten erop tot
## hij kapot gaat. Een kapotte poort staat open tot je hem in de wapenkamer repareert.

const C := Data.COMPOUND
const G := Data.GATE_GAP
const HP := 900.0
const REACH := 4.4
const SLIDE_T := 2.5
const TAKE := {"bullet": 0.25, "melee": 0.5, "explosive": 1.0}

var list: Array = []  # per poort: name, root, anim, body, shape, open, hold, user_open, hp, max_hp, broken, moving
var _sound_t := 0.0


func max_hp() -> float:
	return roundf(HP * (1.0 + 0.4 * Game.upg.get("gate", 0)))


func _ready() -> void:
	add_to_group("gates")
	for sz in [-1.0, 1.0]:
		var g := {"name": "noord" if sz < 0.0 else "zuid", "sz": sz, "open": 0.0, "hold": 0.0, "user_open": false,
			"hp": HP, "max_hp": HP, "broken": false, "moving": false}
		var root := Node3D.new()
		root.position = Vector3(0, 0, sz * C)
		root.rotation.y = 0.0 if sz < 0.0 else PI  # de buitenkant van het model is -Z
		add_child(root)
		var model: Node = (load("res://assets/poort.glb") as PackedScene).instantiate()
		Kit.skin(model, "poort")
		root.add_child(model)
		var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
		ap.play("Paneel")
		ap.pause()
		ap.seek(0.0, true)
		g.anim = ap
		g.panel = model.find_child("Paneel", true, false)
		var body := GateBody.new()
		body.index = list.size()
		body.collision_layer = Kit.LAYER_WALL
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(G * 2.0, 1.5, 0.3)
		cs.shape = bs
		cs.position = Vector3(0, 0.75, 0)
		body.add_child(cs)
		root.add_child(body)
		g.root = root
		g.body = body
		g.shape = cs
		g.wreck = _wreck(root)
		list.append(g)
	_apply_all()


func _wreck(root: Node3D) -> Node3D:
	var w := Node3D.new()
	w.visible = false
	root.add_child(w)
	var dark := Kit.flat(Color("262a1a"), 0.7, 0.3)
	var olive := Kit.flat(Color("3e4428"), 0.7, 0.3)
	Kit.box(w, Vector3(-1.2, 0.0, -0.9), Vector3(2.6, 0.1, 1.2), olive, 0.4)
	Kit.box(w, Vector3(1.1, 0.06, -0.5), Vector3(2.2, 0.1, 1.0), dark, -0.5)
	Kit.box(w, Vector3(1.9, 0.0, -0.6), Vector3(0.12, 1.1, 0.14), dark, 0.2)
	Kit.box(w, Vector3(-2.0, 0.0, -0.3), Vector3(0.1, 0.8, 0.12), dark, 1.0)
	return w


func pos_of(g: Dictionary) -> Vector3:
	return Vector3(0, 0, g.sz * C)


## De poort die voor deze soldaat dicht zit: hij staat er vlakbij, aan de andere kant van de muur dan zijn doel.
func blocking(from: Vector3, goal: Vector3) -> Variant:
	if _inside(from) == _inside(goal):
		return null
	for g in list:
		if g.broken or g.open > 0.6:
			continue
		var p := pos_of(g)
		if absf(from.x - p.x) < G + 0.6 and absf(from.z - p.z) < 1.9:
			return g
	return null


static func _inside(p: Vector3) -> bool:
	return absf(p.x) < C and absf(p.z) < C


func near_player() -> Variant:
	var pl = Game.player
	if pl == null or pl.elev > 1.0:
		return null
	for g in list:
		if not g.broken and pl.global_position.distance_to(pos_of(g)) < REACH:
			return g
	return null


func toggle(g: Dictionary) -> void:
	if g.broken or (Game.state != "play" and Game.state != "prep"):
		return
	g.user_open = not g.user_open
	Sfx.play("click")
	Game.changed.emit()


func damage(i: int, dmg: float, kind := "bullet") -> void:
	var g: Dictionary = list[i]
	if g.broken or (Game.state != "play" and Game.state != "prep"):
		return
	var was: float = g.hp
	g.hp -= dmg * TAKE[kind]
	if g.hp < g.max_hp * 0.5 and was >= g.max_hp * 0.5:
		Sfx.play("thud", 1.0, pos_of(g))
		Game.banner.emit("POORT BESCHADIGD", "", 1.2)
	if g.hp <= 0.0:
		_break(g)
	Game.changed.emit()


func _break(g: Dictionary) -> void:
	g.broken = true
	g.hp = 0.0
	g.open = 1.0
	g.user_open = false
	g.panel.visible = false
	g.wreck.visible = true
	g.shape.disabled = true
	Fx.explosion(self, pos_of(g) + Vector3(0, 0.8, 0), 0.6)
	Sfx.play("boom", 0.8, pos_of(g))
	Game.banner.emit("POORT KAPOT", "De %spoort staat open. Repareer hem in de wapenkamer." % g.name, 2.4)
	_apply(g)


func repair(g: Dictionary) -> void:
	g.max_hp = max_hp()
	g.hp = g.max_hp
	g.broken = false
	g.user_open = false
	g.open = 0.0
	g.hold = 0.0
	g.panel.visible = true
	g.wreck.visible = false
	g.shape.disabled = false
	_apply(g)


func repair_cost(g: Dictionary) -> int:
	return 400 if g.broken else (150 if g.hp < g.max_hp else 0)


func total_repair_cost() -> int:
	var n := 0
	for g in list:
		n += repair_cost(g)
	return n


func repair_all() -> void:
	for g in list:
		repair(g)


func upgrade() -> void:
	var old := max_hp()
	Game.upg["gate"] = Game.upg.get("gate", 0) + 1
	for g in list:
		g.max_hp = max_hp()
		if not g.broken:
			g.hp += g.max_hp - old


func _apply_all() -> void:
	for g in list:
		_apply(g)


## Zet paneel en botsblok op de stand van `open` (0 dicht, 1 open).
func _apply(g: Dictionary) -> void:
	var o: float = g.open
	g.anim.seek(o * SLIDE_T, true)
	var w := maxf(0.1, G * 2.0 * (1.0 - o))
	(g.shape.shape as BoxShape3D).size.x = w
	g.shape.position.x = G * o
	g.shape.disabled = g.broken or o > 0.97


func _physics_process(delta: float) -> void:
	var live := Game.state == "play" or Game.state == "prep"
	var lamp: StandardMaterial3D = BaseProps.GATE_LAMP
	var any_moving := false
	var any_open := false
	for g in list:
		if g.broken:
			continue
		if g.user_open and (not live or Game.player == null or Game.player.global_position.distance_to(pos_of(g)) > 10.0):
			g.user_open = false  # een poort die je open liet gaat dicht als je ver weg bent
		var friend: bool = live and g.user_open
		if live and not friend:
			for a in Game.allies:
				if is_instance_valid(a) and a.global_position.distance_to(pos_of(g)) < 3.6:
					friend = true
					break
		g.hold = 0.9 if friend else g.hold - delta
		var want := 1.0 if g.hold > 0.0 else 0.0
		var prev: float = g.open
		g.open = minf(1.0, prev + delta / SLIDE_T) if want > prev else maxf(0.0, prev - delta / SLIDE_T)
		var moving: bool = g.open != prev
		if moving:
			_apply(g)
			any_moving = true
			if not g.moving:
				Sfx.play("gate", 0.8, pos_of(g))
		g.moving = moving
		any_open = any_open or g.open > 0.99
	# lampjes op de poortposten: knipperend oranje tijdens het schuiven, groen als open, rood als dicht
	if lamp:
		var t := Time.get_ticks_msec() / 1000.0
		var c := Color(2.0, 0.2, 0.1)
		if any_moving:
			c = Color(3.0, 1.6, 0.05) if sin(t * 14.0) > 0.0 else Color(0.4, 0.2, 0.05)
		elif any_open:
			c = Color(0.2, 2.4, 0.3)
		lamp.albedo_color = Color(c.r, c.g, c.b).clamp()
		lamp.emission = Color(c.r, c.g, c.b).clamp()
