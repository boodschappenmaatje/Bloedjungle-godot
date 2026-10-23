class_name Pomp
extends StaticBody3D
## Benzinepomp of olievat bij het benzinestation (woonhuis.gd zet er een op elk knooppunt XPomp* en XVat* uit het model).
## Een paar kogels en hij gaat lekken en branden; nog meer, of een ontploffing in de buurt, en hij ontploft. Dat is een
## grote vuurbal: schade aan vijanden, jou, de muren en kolommen van het station, en pompen en vaten in de buurt gaan
## een fractie later mee (kettingreactie). Daarna blijft het uitgebrande wrak liggen met een brandende plas eromheen.

const KINDS := {
	"XPomp": {"hp": 90.0, "radius": 7.5, "damage": 300.0, "scale": 1.35, "burn": 14.0, "pool": 1.8},
	"XVat": {"hp": 40.0, "radius": 5.5, "damage": 220.0, "scale": 0.85, "burn": 8.0, "pool": 1.1},
}
const BURN_TIME := Vector2(2.4, 3.4)   # seconden tussen "gaat branden" en ontploffen
const POOL_DPS := 14.0                 # schade per seconde in de brandende plas
const POOL_TICK := 0.5

static var all: Array = []

var def: Dictionary
var hp := 0.0
var lit := false
var burning := false
var burn_t := 0.0
var house: Node3D
var _heel: MeshInstance3D
var _kapot: MeshInstance3D
var _cs: CollisionShape3D
var _flame: Node3D
var _pool_t := 0.0
var _pool_at := Vector3.ZERO
var _tick := 0.0


## Maakt het knooppunt n (met n_heel en n_kapot) explosief.
static func attach(owner_house: Node3D, n: Node3D, heel: MeshInstance3D, kapot: MeshInstance3D) -> Pomp:
	var p := Pomp.new()
	var kind := "XPomp" if String(n.name).begins_with("XPomp") else "XVat"
	p.def = KINDS[kind]
	p.hp = p.def.hp
	p.house = owner_house
	p._heel = heel
	p._kapot = kapot
	kapot.visible = false
	n.add_child(p)
	return p


func _ready() -> void:
	all.append(self)
	add_to_group("pompen")
	collision_layer = Barrel.LAYER   # kogels botsen ertegen en roepen hit() aan
	collision_mask = 0
	_cs = CollisionShape3D.new()
	var b := BoxShape3D.new()
	var bb := _heel.transform * _heel.get_aabb()   # in de ruimte van het knooppunt (de body hangt eronder)
	# kogels vliegen op schouderhoogte: de botsvorm is minstens 2 m hoog, ook voor een laag vat
	b.size = Vector3(maxf(bb.size.x, 0.5), maxf(bb.end.y, 2.0), maxf(bb.size.z, 0.5))
	_cs.shape = b
	_cs.position = Vector3(bb.get_center().x, b.size.y * 0.5, bb.get_center().z)
	add_child(_cs)


func _exit_tree() -> void:
	all.erase(self)


## Een ontploffing elders: pompen en vaten binnen de straal gaan mee, na elkaar.
static func catch_blast(at: Vector3, radius: float) -> void:
	for p: Pomp in all.duplicate():
		if is_instance_valid(p) and not p.lit and p.global_position.distance_to(at) < radius + 0.5:
			p.ignite(randf_range(0.2, 0.6))


func hit(dmg: float, dir: Vector3, _from_player: bool) -> void:
	if lit:
		return
	hp -= dmg
	Fx.spark(get_parent(), global_position + Vector3.UP * 1.0, -dir)
	if hp <= 0.0:
		ignite(0.0)
	elif hp <= def.hp * 0.5 and not burning:
		_start_burning()


## Onder de helft: er lekt benzine die vlam vat, en na een paar seconden ontploft hij vanzelf.
func _start_burning() -> void:
	burning = true
	burn_t = randf_range(BURN_TIME.x, BURN_TIME.y)
	_flame = Fx.flame(self, Vector3(0.0, 0.3, 0.0), 1.2)
	Fx.burning(self, global_position + Vector3(0.0, 1.0, 0.0), false)
	PerfMonitor.note("pomp brandt")


func ignite(delay: float) -> void:
	if lit:
		return
	lit = true
	if delay <= 0.0:
		_blow()
	else:
		get_tree().create_timer(delay).timeout.connect(_blow)


func _blow() -> void:
	if not is_inside_tree():
		return
	var at := global_position + Vector3.UP * 0.8
	var parent := house.get_parent() if house else get_parent()
	var r: float = def.radius
	Game.note_blast(at, r)
	Fx.explosion(parent, at, def.scale, Fx.CHUNKS_BARREL)
	Game.alert(at, 40.0, 8.0)
	Barrel.area_damage(at, r, def.damage)
	Barrel.catch_blast(at, r)   # ook pompen (Pomp.catch_blast)
	_heel.visible = false
	_kapot.visible = true
	(_cs.shape as BoxShape3D).size.y = 1.0   # het wrak houdt nog kogels tegen, maar je kunt eroverheen kijken
	_cs.position.y = 0.5
	if _flame and is_instance_valid(_flame):
		_flame.queue_free()
	# het wrak brandt na, met een plas brandende benzine eromheen
	var fire := Fx.flame(self, Vector3(0.0, 0.2, 0.0), 2.4)
	var smoke := Fx.burning(self, global_position + Vector3(0.0, 0.8, 0.0), false)
	_pool_t = def.burn
	_pool_at = global_position
	var tw := create_tween()
	tw.tween_interval(def.burn)
	tw.tween_callback(func():
		var ft := fire.create_tween()
		ft.tween_property(fire, "scale", Vector3(1.0, 0.0, 1.0), 1.5)
		ft.tween_callback(fire.queue_free))
	tw.tween_interval(6.0)
	tw.tween_callback(smoke.queue_free)


func _physics_process(delta: float) -> void:
	if burning and not lit:
		burn_t -= delta
		if burn_t <= 0.0:
			ignite(0.0)
	if _pool_t <= 0.0:
		return
	_pool_t -= delta
	_tick += delta
	if _tick < POOL_TICK:
		return
	_tick = 0.0
	# wie in de brandende plas staat, brandt mee (per tik, niet elk beeldje: anders bloed en geluid zonder eind)
	var r: float = def.pool
	var dmg := POOL_DPS * POOL_TICK
	var p = Game.player
	if p != null and not p.dead and not p.driving:
		var d := Vector2(p.global_position.x - _pool_at.x, p.global_position.z - _pool_at.z).length()
		if d < r and p.global_position.y < 0.8:
			p.hit(dmg, Vector3.UP, false)
	for e in Game.enemies.duplicate():
		if is_instance_valid(e) and Vector2(e.global_position.x - _pool_at.x, e.global_position.z - _pool_at.z).length() < r:
			e.hit(dmg * 2.0, Vector3.UP, true)
