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
static var _glow_p: ArrayMesh
static var _glow_e: ArrayMesh
static var _weapon_glows := {}

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


func _enter_tree() -> void:
	PerfMonitor.bullets_live += 1


func _exit_tree() -> void:
	PerfMonitor.bullets_live -= 1


## Maakt een kogel. over_wall: de schutter staat tegen de muur en schiet eroverheen.
static func fire(parent: Node, from: Vector3, angle: float, spd: float, damage: float, lifetime: float, by_player: bool, over_wall := false, pierce_ := 0, explosive_ := 0.0, sink_ := 0.0, rise_ := 0.0, visual_weapon := "") -> void:
	if _mesh == null:
		_mesh = BoxMesh.new()
		_mesh.size = Vector3(0.05, 0.05, 0.9)
		_mat_p = _tracer(Color(1.0, 0.85, 0.4))
		_mat_e = _tracer(Color(1.0, 0.45, 0.25))
		_glow_p = _glow(Color(1.0, 0.85, 0.3, 1.0), Color(1.0, 0.35, 0.0, 0.0))
		_glow_e = _glow(Color(1.0, 0.45, 0.25, 1.0), Color(0.9, 0.05, 0.0, 0.0))
	var b := Bullet.new()
	b.mesh = _weapon_glow(visual_weapon) if by_player and Data.WEAPON_VISUALS.has(visual_weapon) else (_glow_p if by_player else _glow_e)
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


## Vijandelijke raket (18-enemies.js): traag; ontploft waar hij gemikt was of tegen de eerste muur, speler of bunker.
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
	b.mask = MASK_PLAYER | MASK_BUNKER | MASK_WALL
	parent.add_child(b)
	b.global_position = from
	b.rotation.y = angle


## Lichtspoor: een felle kop met een staart die uitdooft (twee kruislings gezette vlakken met een kleurverloop)
## en een kleine gloeiende bol als kop. Beide tellen op bij wat erachter ligt, dus het straalt zonder te vullen.
static func _weapon_glow(weapon: String) -> ArrayMesh:
	if _weapon_glows.has(weapon):
		return _weapon_glows[weapon]
	var v: Dictionary = Data.WEAPON_VISUALS[weapon]
	var m := _glow(v.trail_head, v.trail_tail, v.trail_length, v.trail_width, 0.10, 0.042 if weapon != "bazooka" else 0.07)
	_weapon_glows[weapon] = m
	return m


static func _glow(head: Color, tail: Color, tail_length := 2.0, width := 0.07, head_length := 0.35, ball_size := 0.09) -> ArrayMesh:
	var m := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z0 := -tail_length   # korte, taps toelopende staart achter de kogel
	var z1 := head_length
	for ang in [0.0, PI * 0.5]:
		var side := Vector3(cos(ang), sin(ang), 0.0) * width
		var pts := [Vector3(0, 0, z0) - side * 0.2, Vector3(0, 0, z0) + side * 0.2, Vector3(0, 0, z1) + side, Vector3(0, 0, z1) - side]
		var cols := [tail, tail, head, head]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_color(cols[i])
			st.add_vertex(pts[i])
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays())
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.surface_set_material(0, mat)
	var ball := SphereMesh.new()
	ball.radius = ball_size
	ball.height = ball_size * 2.0
	ball.radial_segments = 8
	ball.rings = 4
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.albedo_color = head
	var arr := ball.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		verts[i] += Vector3(0, 0, z1)
	arr[Mesh.ARRAY_VERTEX] = verts
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(1, bm)
	return m


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
		elif dir.y < -0.05 and randf() < 0.35:
			Fx.dust(get_parent(), Vector3(global_position.x, 0.1, global_position.z))  # schuine kogel (heli) slaat in de grond
		queue_free()
		return
	if rocket and randf() < 0.5:
		Fx.dust(get_parent(), global_position - dir * 0.6)
	if sink > 0.0:
		dir.y = -sink if global_position.y > 1.3 else 0.0
	var step := dir * speed * delta
	for k: Brandkraan in Brandkraan.all:   # schiet je er tegenaan, dan begint de kogel in de botsvorm en ziet de straal hem niet
		if is_instance_valid(k) and not k.sprayed and (mask & Barrel.LAYER) != 0 and k.inside(global_position):
			k.hit(dmg, dir, from_player)
			queue_free()
			return
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
			var target_script: Script = (c as Node).get_script() as Script if c is Node else null
			var target_script_path := target_script.resource_path if target_script != null else ""
			var target_handles_impact := target_script_path in ["res://scripts/enemy.gd", "res://scripts/player.gd"] or c is Barrel or c is Pomp or c is Brandkraan
			if not target_handles_impact:
				Fx.impact(get_parent(), hit.position, hit.normal, _impact_material(c))
			c.hit(dmg, dir, from_player)
			if pierce > 0 and c.collision_layer == MASK_ENEMY:
				pierce -= 1
				dmg *= 0.85
				global_position = hit.position + dir * 0.5
				return
		else:
			Fx.impact(get_parent(), hit.position, hit.normal, _impact_material(c))
		queue_free()
		return
	global_position += step


func _impact_material(collider: Object) -> String:
	if collider is Node:
		var node := collider as Node
		if node.is_in_group("ground"):
			return "dirt"
		if node.has_meta("impact_material"):
			return str(node.get_meta("impact_material"))
	if collider is Barrel or collider is Brandkraan or collider is Pomp or collider is GateBody:
		return "metal"
	return "concrete"


## Raket: grote ontploffing, schade neemt af met de afstand (alleen vijanden).
func _explode(at: Vector3) -> void:
	Game.note_blast(at, explosive)
	Fx.explosion(get_parent(), at, 1.4)
	Barrel.catch_blast(at, explosive)
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
	Game.note_blast(at, r)
	Fx.explosion(get_parent(), at, 0.9)
	Barrel.catch_blast(at, r)
	if Game.builds:
		Game.builds.blast(at, r, dmg, false)
	if Game.gates:
		for i in Game.gates.list.size():
			var g: Dictionary = Game.gates.list[i]
			var gd: float = maxf(0.0, Vector2(Game.gates.pos_of(g).x - at.x, Game.gates.pos_of(g).z - at.z).length() - Data.GATE_GAP)
			if not g.broken and gd < r:
				Game.gates.damage(i, dmg * 1.2 * (1.0 - gd / r), "explosive")
	var p = Game.player
	if p != null and not p.dead:
		var pd: float = Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length()
		if pd < r:
			p.hit(dmg * 0.6 * (0.5 if p.elev > 1.0 else 1.0) * (1.0 - pd / r), (p.global_position - at).normalized(), false, true)
	var bx := maxf(absf(at.x) - Data.BUNKER_HALF, 0.0)
	var bz := maxf(absf(at.z) - Data.BUNKER_HALF, 0.0)
	var bd := Vector2(bx, bz).length()
	if bd < r:
		Game.damage_base(dmg * 0.5 * (1.0 - bd / r))
