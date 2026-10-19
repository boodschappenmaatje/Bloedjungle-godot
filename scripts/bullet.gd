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


## Maakt een kogel. over_wall: de schutter staat tegen de muur en schiet eroverheen.
static func fire(parent: Node, from: Vector3, angle: float, spd: float, damage: float, lifetime: float, by_player: bool, over_wall := false) -> void:
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
	b.mask = (MASK_ENEMY if by_player else MASK_PLAYER) | MASK_BUNKER | (0 if over_wall else MASK_WALL)
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
		queue_free()
		return
	var step := dir * speed * delta
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + step, mask)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		var c: Object = hit.collider
		if c.has_method("hit"):
			c.hit(dmg, dir, from_player)
		else:
			Fx.dust(get_parent(), hit.position)
		queue_free()
		return
	global_position += step
