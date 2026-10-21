class_name Bullet
extends MeshInstance3D
## Een kogel met lichtspoor. Vliegt recht op schouderhoogte en kijkt elke stap met een straal
## wat hij raakt. Wat geraakt kan worden heeft een functie hit(dmg, dir, from_player).

const MASK_WALL := 2
const MASK_PLAYER := 4
const MASK_ENEMY := 8
const MASK_BUNKER := 16

static var _mesh: BoxMesh
static var _mat_p: StandardMaterial3D
static var _mat_e: StandardMaterial3D

var dir := Vector3.FORWARD
var speed := 75.0
var dmg := 10.0
var life := 0.6
var mask := 0
var from_player := true
var pierce := 0
var explosive := 0.0
var rocket := false  # vijandelijke raket: ontploft op de plek waar hij gemikt was
var sink := 0.0  # kogels van een toren dalen tot schouderhoogte


## Maakt een kogel. over_wall: de schutter staat tegen de muur en schiet eroverheen.
static func fire(parent: Node, from: Vector3, angle: float, spd: float, damage: float, lifetime: float, by_player: bool, over_wall := false, pierce_ := 0, explosive_ := 0.0, sink_ := 0.0, rise_ := 0.0) -> void:
	if _mesh == null:
		_mesh = BoxMesh.new()
		_mesh.size = Vector3(0.05, 0.05, 0.9)
		_mat_p = _tracer(Color(1.0, 0.85, 0.4))
		_mat_e = _tracer(Color(1.0, 0.45, 0.25))
	var b := Bullet.new()
	b.mesh = _mesh
	b.material_override = _mat_p if by_player else _mat_e
	b.dir = Vector3(sin(angle), 0.0, cos(angle))
	b.speed = spd
	b.dmg = damage
	b.life = lifetime
	b.from_player = by_player
	b.pierce = pierce_
	b.explosive = explosive_
	b.sink = sink_
	b.dir.y = rise_  # schiet omhoog naar iemand op een toren
	b.mask = (MASK_ENEMY if by_player else MASK_PLAYER) | MASK_BUNKER | (0 if over_wall else MASK_WALL)
	parent.add_child(b)
	b.global_position = from
	b.rotation.y = angle


## Vijandelijke raket (18-enemies.js): traag, vliegt over de muur en ontploft waar hij gemikt was of tegen de eerste speler of bunker.
static func fire_rocket(parent: Node, from: Vector3, angle: float, damage: float, lifetime: float) -> void:
	if _mesh == null:
		fire(parent, from, angle, 0.0, 0.0, 0.0, false)  # maakt de gedeelde mesh en materialen klaar
		for c in parent.get_children():
			if c is Bullet and c.speed == 0.0:
				c.queue_free()
	var b := Bullet.new()
	b.mesh = _mesh
	b.material_override = _mat_e
	b.scale = Vector3(3.0, 3.0, 0.8)
	b.dir = Vector3(sin(angle), 0.0, cos(angle))
	b.speed = 17.0
	b.dmg = damage
	b.life = lifetime
	b.from_player = false
	b.rocket = true
	b.explosive = 3.2
	b.mask = MASK_PLAYER | MASK_BUNKER
	parent.add_child(b)
	b.global_position = from
	b.rotation.y = angle


static func _tracer(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		if rocket:
			_boom_enemy(global_position)
		queue_free()
		return
	if rocket and randf() < 0.5:
		Fx.dust(get_parent(), global_position - dir * 0.6)
	if sink > 0.0:
		dir.y = -sink if global_position.y > 1.3 else 0.0
	var step := dir * speed * delta
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + step, mask)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		var c: Object = hit.collider
		if rocket:
			_boom_enemy(hit.position)
			queue_free()
			return
		if explosive > 0.0:
			_explode(hit.position)
			queue_free()
			return
		if c.has_method("hit"):
			c.hit(dmg, dir, from_player)
			if c is BuildingBody:
				Fx.impact(get_parent(), hit.position, hit.normal)
			if pierce > 0 and c.collision_layer == MASK_ENEMY:
				pierce -= 1
				dmg *= 0.85
				global_position = hit.position + dir * 0.5
				return
		else:
			Fx.impact(get_parent(), hit.position, hit.normal)
		queue_free()
		return
	global_position += step


## Raket: grote ontploffing, schade neemt af met de afstand (alleen vijanden).
func _explode(at: Vector3) -> void:
	Fx.explosion(get_parent(), at, 1.4)
	if Game.builds:
		Game.builds.blast(at, explosive, dmg, true)  # eigen raketten doen een beetje schade aan je eigen bouwwerk
	for e in Game.enemies.duplicate():
		if is_instance_valid(e):
			var d: float = e.global_position.distance_to(at)
			if d < explosive:
				e.hit(dmg * (1.0 - d / explosive * 0.7), (e.global_position - at).normalized(), true)


## Ontploffing van een vijandelijke raket (explode() in 15-combat.js met fromPlayer = false).
func _boom_enemy(at: Vector3) -> void:
	var r := explosive
	Fx.explosion(get_parent(), at, 0.9)
	if Game.builds:
		Game.builds.blast(at, r, dmg, false)
	if Game.gates:
		for i in Game.gates.list.size():
			var g: Dictionary = Game.gates.list[i]
			var gd: float = maxf(0.0, Vector2(Game.gates.pos_of(g).x - at.x, Game.gates.pos_of(g).z - at.z).length() - Data.GATE_GAP)
			if not g.broken and gd < r:
				Game.gates.damage(i, dmg * 1.2 * (1.0 - gd / r), "bullet")
	var p = Game.player
	if p != null and not p.dead:
		var pd: float = Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length()
		if pd < r:
			p.hit(dmg * 0.6 * (0.5 if p.elev > 1.0 else 1.0) * (1.0 - pd / r), (p.global_position - at).normalized(), false)
	var bx := maxf(absf(at.x) - Data.BUNKER_HALF, 0.0)
	var bz := maxf(absf(at.z) - Data.BUNKER_HALF, 0.0)
	var bd := Vector2(bx, bz).length()
	if bd < r:
		Game.damage_base(dmg * 0.5 * (1.0 - bd / r))
