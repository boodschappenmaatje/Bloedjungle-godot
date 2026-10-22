class_name Grenade
extends Node3D
## Handgranaat (throwGrenade in 15-combat.js): vliegt in een boog, stuitert, ontploft na 1,7 s.
## Doet schade aan vijanden, bouwwerken en poorten (en een beetje aan de speler zelf).

const FUSE := 1.7
const GRAVITY := 16.0
const RADIUS := 5.0
const DAMAGE := 220.0

static var _mat: StandardMaterial3D
static var _mesh: SphereMesh

var vel := Vector3.ZERO
var fuse := FUSE
var _ring: MeshInstance3D


## Gooit een granaat vanaf de speler in de kijkrichting (reikwijdte ~11 m).
static func throw_from(parent: Node, from: Vector3, angle: float, dist := 11.0) -> void:
	var g := Grenade.new()
	if _mesh == null:
		_mesh = SphereMesh.new()
		_mesh.radius = 0.11
		_mesh.height = 0.22
		_mat = StandardMaterial3D.new()
		_mat.albedo_color = Color(0.29, 0.32, 0.16)
		_mat.roughness = 0.6
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	mi.material_override = _mat
	g.add_child(mi)
	var t := 0.85
	g.vel = Vector3(sin(angle) * dist / t, 7.0, cos(angle) * dist / t)
	parent.add_child(g)
	g.global_position = from


func _physics_process(delta: float) -> void:
	vel.y -= GRAVITY * delta
	var step := vel * delta
	# muren en de bunker houden hem tegen
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + step, Bullet.MASK_WALL | Bullet.MASK_BUNKER)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		global_position = hit.position + hit.normal * 0.15
		var n: Vector3 = hit.normal
		vel = vel.bounce(n) * 0.35
	else:
		global_position += step
	if global_position.y < 0.1:
		global_position.y = 0.1
		vel.y = absf(vel.y) * 0.35
		vel.x *= 0.55
		vel.z *= 0.55
	rotation.x += 10.0 * delta
	fuse -= delta
	if fuse <= 0.0:
		_explode()
		queue_free()


func _explode() -> void:
	var at := global_position
	var r: float = RADIUS * float(Progress.bonus().grenade)
	Fx.explosion(get_parent(), at, 1.1)
	Sfx.play("rocket")
	Game.alert(at, 30.0, 6.0)  # een knal trekt aandacht
	for e in Game.enemies.duplicate():
		if is_instance_valid(e):
			var d: float = e.global_position.distance_to(at)
			if d < r:
				e.hit(DAMAGE * (1.0 - d / r * 0.7), (e.global_position - at).normalized(), true)
	if Game.builds:
		Game.builds.blast(at, r, DAMAGE, true)
	if Game.gates:
		for i in Game.gates.list.size():
			var gt: Dictionary = Game.gates.list[i]
			var gd: float = maxf(0.0, Vector2(Game.gates.pos_of(gt).x - at.x, Game.gates.pos_of(gt).z - at.z).length() - Data.GATE_GAP)
			if not gt.broken and gd < r:
				Game.gates.damage(i, DAMAGE * 0.35 * (1.0 - gd / r), "explosive")
	var p = Game.player
	if p != null and not p.dead:
		var pd: float = Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length()
		if pd < r:
			p.hit(DAMAGE * 0.25 * (1.0 - pd / r), (p.global_position - at).normalized(), false)
