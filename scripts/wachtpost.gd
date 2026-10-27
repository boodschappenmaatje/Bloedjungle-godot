class_name Wachtpost
extends Node3D
## Bij elke poort een slagboom en een wachthuisje (assets/wachtpost.glb, bron/wachtpost). De slagboom ligt 2,6 m binnen de muur dwars over de
## weg, gaat omhoog als de stalen poort open staat of kapot is (de arm volgt `Gates.list[i].open`) en zakt weer als de poort dicht gaat.
## Het wachthuisje heeft botsing, zodat je er niet doorheen loopt. In het huisje bij de noordpoort zit een wacht (Patrouille, Ally.guard) die
## door het raam schiet. Huisje en slagboom kunnen kapot, net als de poort: vijandelijke kogels en explosies beschadigen ze, je repareert ze in de wapenkamer.

const C := Data.COMPOUND
const G := Data.GATE_GAP
const BARRIER_Z := 2.6    # slagboom ligt zoveel meter binnen de muur
const HUT_Z := 5.0        # wachthuisje staat zoveel meter binnen de muur
const HUT_X := 6.3        # en zoveel meter naast het midden van de poort
const LIFT_FROM := 0.35   # de arm begint omhoog te gaan als de poort zo ver open is (0..1)
const GUARD_SZ := -1.0    # in het huisje bij de noordpoort zit de wacht
const HUT_HP := 450.0
const BOOM_HP := 120.0
const HUT_COST := 300
const BOOM_COST := 100
const HUT_TAKE := {"bullet": 0.5, "melee": 0.5, "explosive": 1.0}
const BOOM_TAKE := {"bullet": 1.0, "melee": 1.0, "explosive": 1.0}

static var inst: Wachtpost = null

## per poort: sz, barrier, hut, ap, len, hut_hp, hut_down, hut_body, hut_fx, boom_hp, boom_down, boom_body, boom_fx, wreck, arm
var posts: Array = []
var _spawned := false


func _enter_tree() -> void:
	inst = self


func _exit_tree() -> void:
	if inst == self:
		inst = null


## Plek van het huisje en de richting waarheen het raam kijkt: noord staat links (-X), zuid rechts (+X); het raam kijkt naar de weg.
static func hut_pos(sz: float) -> Vector3:
	return Vector3(HUT_X if sz > 0.0 else -HUT_X, 0.0, sz * (C - HUT_Z))


static func hut_yaw(sz: float) -> float:
	return PI / 2.0 if sz > 0.0 else -PI / 2.0


## Waar de wacht staat: in het huisje, bij het raam dat naar de weg kijkt.
static func guard_spot(sz: float) -> Vector3:
	var h := hut_pos(sz)
	return Vector3(h.x + (-0.5 if sz > 0.0 else 0.5), 0.0, h.z)


## Staat het huisje van deze poort nog? (de wacht zit er dan in; zonder huisje loopt hij naar zijn post langs de muur)
static func hut_alive(sz: float) -> bool:
	if inst == null:
		return false
	for p in inst.posts:
		if signf(p.sz) == signf(sz):
			return not p.hut_down
	return false


func _process(_delta: float) -> void:
	if not _spawned and (Game.state == "prep" or Game.state == "play") and Game.gates != null:
		_spawned = true
		_spawn()


func _spawn() -> void:
	var parent: Node = get_parent().get_node_or_null("Level")
	if parent == null:
		parent = get_parent()
	var scene := load("res://assets/wachtpost.glb") as PackedScene
	for i in Game.gates.list.size():
		var sz: float = Game.gates.list[i].sz
		var p := {"sz": sz, "hut_hp": HUT_HP, "hut_down": false, "hut_fx": null, "boom_hp": BOOM_HP, "boom_down": false, "boom_fx": null}
		var barrier := _piece(scene, "Wachthuis")
		barrier.position = Vector3(0, 0, sz * (C - BARRIER_Z))
		parent.add_child(barrier)
		var ap: AnimationPlayer = barrier.find_child("AnimationPlayer", true, false)
		ap.play("Open")
		ap.pause()
		ap.seek(0.0, true)
		p.barrier = barrier
		p.ap = ap
		p.len = ap.get_animation("Open").length
		p.arm = barrier.find_child("Boom", true, false)
		p.boom_body = _solid(barrier, Vector3(-G - 0.55, 0.65, 0), Vector3(0.6, 1.3, 0.5), p, "boom")   # de kast; kogels die hem raken beschadigen de slagboom
		p.wreck = _wreck(barrier)
		var hut := _piece(scene, "Slagboom")
		hut.position = hut_pos(sz)
		hut.rotation.y = hut_yaw(sz)
		parent.add_child(hut)
		p.hut = hut
		p.hut_body = _solid(hut, Vector3(0, 1.25, 0), Vector3(2.4, 2.5, 2.4), p, "hut")
		posts.append(p)


## Een kopie van de glb zonder het onderdeel dat hier niet bij hoort; het blijft op de glb-oorsprong staan.
static func _piece(scene: PackedScene, drop: String) -> Node3D:
	var root := Node3D.new()
	var model: Node3D = scene.instantiate()
	root.add_child(model)
	var other: Node = model.find_child(drop, true, false)
	if other:
		other.get_parent().remove_child(other)
		other.free()
	var keep: Node3D = model.find_child("Wachthuis" if drop == "Slagboom" else "Slagboom", true, false)
	if keep:
		keep.position = Vector3.ZERO
	return root


static func _solid(on: Node3D, at: Vector3, size: Vector3, post: Dictionary, part: String) -> PostBody:
	var body := PostBody.new()
	body.post = post
	body.part = part
	body.collision_layer = Kit.LAYER_WALL
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = at
	body.add_child(cs)
	on.add_child(body)
	return body


## De gebroken arm: twee stukken liggen schuin op de grond bij de kast (alleen zichtbaar als de slagboom kapot is).
static func _wreck(barrier: Node3D) -> Node3D:
	var w := Node3D.new()
	w.visible = false
	barrier.add_child(w)
	var red := Kit.flat(Color("7a1a14"), 0.7, 0.2)
	var white := Kit.flat(Color("b8b5a6"), 0.7, 0.2)
	Kit.box(w, Vector3(-2.2, 0.0, -0.2), Vector3(2.4, 0.14, 0.2), red, 0.35)
	Kit.box(w, Vector3(-0.3, 0.0, 0.6), Vector3(2.0, 0.14, 0.2), white, -0.5)
	Kit.box(w, Vector3(1.3, 0.0, -0.3), Vector3(0.9, 0.14, 0.2), red, 1.1)
	return w


func _physics_process(_delta: float) -> void:
	if posts.is_empty() or Game.gates == null:
		return
	for i in mini(posts.size(), Game.gates.list.size()):
		var g: Dictionary = Game.gates.list[i]
		var p: Dictionary = posts[i]
		if p.boom_down:
			continue
		var up := 1.0 if g.broken else clampf((float(g.open) - LIFT_FROM) / (1.0 - LIFT_FROM), 0.0, 1.0)
		(p.ap as AnimationPlayer).seek(up * float(p.len), true)


## Schade aan het huisje ("hut") of de slagboom ("boom"); kind: bullet, melee of explosive.
func damage(p: Dictionary, part: String, dmg: float, kind := "bullet") -> void:
	if (Game.state != "play" and Game.state != "prep") or dmg <= 0.0:
		return
	if part == "hut":
		if p.hut_down:
			return
		var was: float = p.hut_hp
		p.hut_hp -= dmg * HUT_TAKE[kind]
		if randf() < 0.5:
			Fx.dust(self, (p.hut as Node3D).global_position + Vector3(randf_range(-1, 1), 1.0, randf_range(-1, 1)))
		if p.hut_hp < HUT_HP * 0.5 and was >= HUT_HP * 0.5:
			p.hut_fx = Fx.burning(self, (p.hut as Node3D).global_position, false)
			Game.banner.emit("WACHTHUISJE BESCHADIGD", "", 1.2)
		if p.hut_hp <= 0.0:
			_break_hut(p)
	else:
		if p.boom_down:
			return
		p.boom_hp -= dmg * BOOM_TAKE[kind]
		if p.boom_hp <= 0.0:
			_break_boom(p)


func _break_hut(p: Dictionary) -> void:
	p.hut_down = true
	p.hut_hp = 0.0
	var at: Vector3 = (p.hut as Node3D).global_position
	(p.hut as Node3D).scale = Vector3(1, 0.32, 1)
	(p.hut_body.get_child(0) as CollisionShape3D).disabled = true
	if p.hut_fx != null and is_instance_valid(p.hut_fx):
		p.hut_fx.queue_free()
	p.hut_fx = Fx.burning(self, at, true)
	Fx.explosion(self, at + Vector3.UP * 1.0, 1.1)
	Sfx.play("boom", 0.8, at)
	Game.note_blast(at, 4.0)
	Game.banner.emit("WACHTHUISJE VERWOEST", "Repareer het in de wapenkamer.", 2.2)


func _break_boom(p: Dictionary) -> void:
	p.boom_down = true
	p.boom_hp = 0.0
	var at: Vector3 = (p.barrier as Node3D).to_global(Vector3(-G - 0.55, 0.8, 0))
	(p.arm as Node3D).visible = false
	(p.wreck as Node3D).visible = true
	p.boom_fx = Fx.burning(self, at, false)
	Fx.explosion(self, at, 0.6)
	Sfx.play("boom", 0.6, at)
	Game.banner.emit("SLAGBOOM KAPOT", "Repareer hem in de wapenkamer.", 1.8)


## Ontploffing op `at` met straal en schade (zoals Game.gates, vanuit vaten, granaten en granaten van een tank).
static func blast(at: Vector3, radius: float, dmg: float) -> void:
	if inst == null:
		return
	for p in inst.posts:
		var hd: float = maxf(0.0, Vector2((p.hut as Node3D).global_position.x - at.x, (p.hut as Node3D).global_position.z - at.z).length() - 1.4)
		if not p.hut_down and hd < radius:
			inst.damage(p, "hut", dmg * (1.0 - hd / radius), "explosive")
		var bc: Vector3 = (p.barrier as Node3D).global_position
		var bd: float = maxf(0.0, Vector2(bc.x - at.x, bc.z - at.z).length() - G)
		if not p.boom_down and bd < radius:
			inst.damage(p, "boom", dmg * (1.0 - bd / radius), "explosive")


func total_repair_cost() -> int:
	var c := 0
	for p in posts:
		c += (HUT_COST if p.hut_down else (HUT_COST / 3 if p.hut_hp < HUT_HP else 0)) + (BOOM_COST if p.boom_down else 0)
	return c


func repair_all() -> void:
	for p in posts:
		p.hut_hp = HUT_HP
		p.hut_down = false
		(p.hut as Node3D).scale = Vector3.ONE
		(p.hut_body.get_child(0) as CollisionShape3D).disabled = false
		p.boom_hp = BOOM_HP
		p.boom_down = false
		(p.arm as Node3D).visible = true
		(p.wreck as Node3D).visible = false
		for k in ["hut_fx", "boom_fx"]:
			if p[k] != null and is_instance_valid(p[k]):
				p[k].queue_free()
			p[k] = null
