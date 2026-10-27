class_name Grenade
extends Node3D
## Handgranaat: vliegt in een boog precies naar het gekozen doelpunt (2-12 m), stuitert, ontploft na 1,7 s.
## Doet schade aan vijanden, bouwwerken en poorten (en een beetje aan de speler zelf).

const FUSE := 1.7
const GRAVITY := 16.0
const RADIUS := 5.0
const DAMAGE := 220.0
const MIN_RANGE := 2.0
const MAX_RANGE := 12.0
const TAP_RANGE := 7.0   # alleen tikken op de knop: zo ver recht vooruit

static var _mat: StandardMaterial3D
static var _mesh: SphereMesh

var vel := Vector3.ZERO
var fuse := FUSE
var _ring: MeshInstance3D
var home = null   # Woonhuis waarin hij is gegooid: daar blijft hij binnen tot het gebouw plat ligt
var _prev := Vector3.ZERO
var _landed := false


## Gooit een granaat vanaf de speler in de kijkrichting, dist meter ver.
static func throw_from(parent: Node, from: Vector3, angle: float, dist := TAP_RANGE, body_pos := Vector3.INF) -> Grenade:
	var ground := body_pos.y if body_pos != Vector3.INF else 0.0
	return throw_at(parent, from, Vector3(from.x + sin(angle) * dist, ground, from.z + cos(angle) * dist), body_pos)


## Vliegtijd voor een worp over dist meter: dichtbij laag en kort, ver iets hoger (top ~2,5 m bij 12 m).
static func flight_time(dist: float) -> float:
	return 0.42 + dist * 0.04


## Beginsnelheid waarmee de granaat vanaf from precies op target neerkomt.
static func launch_velocity(from: Vector3, target: Vector3) -> Vector3:
	var flat := Vector3(target.x - from.x, 0.0, target.z - from.z)
	var t := flight_time(flat.length())
	var v := flat / t
	v.y = (target.y - from.y + 0.5 * GRAVITY * t * t) / t
	return v


## Het gebouw waarin de werper (of de werphand) staat, anders null.
static func find_home(from: Vector3, body_pos := Vector3.INF):
	for h in Woonhuis.all:
		if h._ruin:
			continue
		for p: Vector3 in [from, body_pos]:
			if p != Vector3.INF and h._in_foot(h.to_local(p), 0.0):
				return h
	return null


## Doelpunt binnen bereik (2-12 m van de werper) en, in een gebouw, binnen dat gebouw (v80).
static func clamp_target(body: Vector3, target: Vector3, home = null) -> Vector3:
	var d := Vector3(target.x - body.x, 0.0, target.z - body.z)
	var dist := clampf(d.length(), MIN_RANGE, MAX_RANGE)
	var dir := d.normalized() if d.length() > 0.01 else Vector3.FORWARD
	if home != null:
		# zo ver mogelijk richting het doel, maar met 0,4 m afstand tot de buitenmuur
		var lo := 0.0
		var hi := dist
		if not home._in_foot(home.to_local(body + dir * hi), -0.4):
			for i in 12:
				var mid := (lo + hi) * 0.5
				if home._in_foot(home.to_local(body + dir * mid), -0.4):
					lo = mid
				else:
					hi = mid
			dist = lo
	var t := body + dir * dist
	return Vector3(t.x, body.y, t.z)


## Voorspelt de baan tot de eerste landing: {points, land, blocked}. blocked = een muur of auto staat in de weg.
static func predict(world: World3D, from: Vector3, target: Vector3) -> Dictionary:
	var pts := PackedVector3Array([from])
	var pos := from
	var vel := launch_velocity(from, target)
	var dt := 1.0 / 30.0
	var space := world.direct_space_state
	for i in 60:
		vel.y -= GRAVITY * dt
		var nxt := pos + vel * dt
		var q := PhysicsRayQueryParameters3D.create(pos, nxt, Bullet.MASK_WALL | Bullet.MASK_BUNKER | Bullet.MASK_NATURE)
		var hit := space.intersect_ray(q)
		var v := Bullet.vehicle_on_path(pos, nxt)
		if not v.is_empty():
			pts.append(v.pos)
			return {"points": pts, "land": v.pos, "blocked": true}
		if hit:
			pts.append(hit.position)
			return {"points": pts, "land": hit.position, "blocked": true}
		if nxt.y <= target.y + 0.1 and vel.y < 0.0:
			pts.append(Vector3(nxt.x, target.y, nxt.z))
			return {"points": pts, "land": Vector3(nxt.x, target.y, nxt.z), "blocked": false}
		pts.append(nxt)
		pos = nxt
	return {"points": pts, "land": target, "blocked": false}


## Gooit een granaat vanaf from naar target (wordt nog begrensd op bereik en het gebouw waarin je staat).
static func throw_at(parent: Node, from: Vector3, target: Vector3, body_pos := Vector3.INF) -> Grenade:
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
	# gegooid vanuit een gebouw (positie van de werper of van de granaat): hij blijft erin
	g.home = find_home(from, body_pos)
	var body := body_pos if body_pos != Vector3.INF else Vector3(from.x, target.y, from.z)
	g.vel = launch_velocity(from, clamp_target(body, target, g.home))
	parent.add_child(g)
	g.global_position = from
	g._prev = g.global_position
	return g


func _physics_process(delta: float) -> void:
	vel.y -= GRAVITY * delta
	var step := vel * delta
	# muren en de bunker houden hem tegen
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + step, Bullet.MASK_WALL | Bullet.MASK_BUNKER | Bullet.MASK_NATURE)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	# auto's en bussen: net als bij kogels telt de carrosserie tot Bullet.HIT_TOP, dan stuitert hij ertegen en valt ernaast
	var v := Bullet.vehicle_on_path(global_position, global_position + step)
	if not v.is_empty() and (not hit or global_position.distance_to(v.pos) < global_position.distance_to(hit.position)):
		global_position = global_position.lerp(v.pos, 0.9) - Vector3(step.x, 0.0, step.z).normalized() * 0.15
		vel = Vector3(-vel.x * 0.3, minf(vel.y, 0.0) * 0.35, -vel.z * 0.3)
	elif hit:
		global_position = hit.position + hit.normal * 0.15
		var n: Vector3 = hit.normal
		vel = vel.bounce(n) * 0.35
	else:
		global_position += step
	var floor_y := 0.0
	if home != null:
		if is_instance_valid(home) and not home._ruin:
			_keep_inside()
			floor_y = maxf(0.0, home._floor_local(home.to_local(global_position), _prev.y))
		else:
			home = null
	_prev = global_position
	if global_position.y < floor_y + 0.1:
		global_position.y = floor_y + 0.1
		vel.y = absf(vel.y) * 0.35
		# eerste keer neerkomen remt hard af: hij blijft vlak bij de richtcirkel liggen
		var keep := 0.55 if _landed else 0.2
		_landed = true
		vel.x *= keep
		vel.z *= keep
	rotation.x += 10.0 * delta
	fuse -= delta
	if fuse <= 0.0:
		_explode()
		queue_free()


## Muren met kozijnen zijn open (ramen, deuren) en vloeren/dak hebben geen botsvorm: de granaat mag het grondvlak en het dak
## van zijn gebouw niet uit. Aan de rand stuitert hij terug.
func _keep_inside() -> void:
	var lp: Vector3 = home.to_local(global_position)
	if not home._in_foot(lp, -0.1):
		global_position = _prev
		var back: Vector3 = home.to_local(_prev)
		if not home._in_foot(back, -0.1):
			# stond al in de muur (spawn vlak bij de rand): terug naar het midden van het gebouw
			var c := Vector3(0, _prev.y - home.global_position.y, 0)
			global_position = home.to_global(back + (c - back).normalized() * 0.3)
		vel.x = -vel.x * 0.35
		vel.z = -vel.z * 0.35
	var top: float = home.global_position.y + float(home.levels[home.levels.size() - 1]) + 3.0
	if global_position.y > top:
		global_position.y = top
		vel.y = -absf(vel.y) * 0.35


func _explode() -> void:
	var at := global_position
	var r: float = RADIUS * float(Progress.bonus().grenade)
	Fx.explosion(get_parent(), at, 1.1)
	Sfx.play("rocket")
	Game.alert(at, 30.0, 6.0)  # een knal trekt aandacht
	PerfMonitor.note("granaat ontploft")
	Game.note_blast(at, r)
	Barrel.catch_blast(at, r)
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
