extends CharacterBody3D
## Vijandelijke soldaat. Loopt naar de speler als die dichtbij is, anders naar de bunker.
## Messen vallen van dichtbij aan, geweren en de MG schieten zodra ze vrij zicht hebben.
## Om de muur heen loopt hij via een hoek en een van de twee poorten (zie route.gd).
## Waarden uit 01-data.js en 18-enemies.js van de web-versie.

@onready var model: SoldierModel = $Model
@onready var shape: CollisionShape3D = $Shape

var type := "knife"
var t: Dictionary
var hp := 45.0
var max_hp := 45.0
var face := 0.0
var fire_t := 1.0
var burst_n := 0
var speed_mul := 1.0
var strafe := 1.0
var dead := false


func setup(kind: String, wave: int) -> void:
	type = kind
	t = Data.ETYPES[kind]
	max_hp = t.hp * (1.0 + (maxi(1, wave) - 1) * 0.11)
	hp = max_hp
	fire_t = randf_range(0.8, 1.8)
	speed_mul = randf_range(0.9, 1.12)
	strafe = 1.0 if randf() < 0.5 else -1.0


func _ready() -> void:
	model.setup(t.color)
	model.scale = Vector3.ONE * t.scale
	(shape.shape as CapsuleShape3D).radius = t.r
	Game.enemies.append(self)


func _physics_process(delta: float) -> void:
	if dead or Game.state == "over":
		if not dead:
			model.play("stil")
		return
	var player = Game.player
	var melee: bool = t.get("melee", false)
	var range_: float = 0.0 if melee else t.range
	# doelwit: de speler als hij dichtbij genoeg is, anders de bunker
	var to_player := INF
	if player and not player.dead:
		to_player = _flat(player.global_position - global_position).length()
	var at_player := to_player < (20.0 if melee else 16.0)
	var goal: Vector3 = player.global_position if at_player else Vector3.ZERO
	var dist := to_player if at_player else _bunker_dist()

	fire_t -= delta
	var want_move := true
	var look := face
	var aim_at := goal + Vector3.UP * 1.2
	if melee:
		if dist < t.r + 0.8:
			want_move = false
			look = _angle_to(goal)
			if fire_t <= 0.0:
				fire_t = t.rate
				model.play("steken", 0.08, 1.7)
				if at_player:
					player.hit(t.dmg, Vector3(sin(look), 0, cos(look)), false)
				else:
					Game.damage_base(t.dmg)
	elif dist < range_ and _clear_shot(aim_at, not at_player):
		want_move = false
		look = _angle_to(goal)
		if fire_t <= 0.0:
			_shoot(look)

	var vel := Vector3.ZERO
	if want_move:
		var wp := Route.waypoint(global_position, goal)
		var d := _flat(wp - global_position)
		if d.length() > 0.05:
			vel = Vector3(d.x, 0.0, d.y).normalized() * t.speed * speed_mul
			look = atan2(d.x, d.y)
	elif not melee and dist < range_ * 0.6:
		# te dichtbij: zijwaarts uitwijken terwijl hij schiet
		vel = Vector3(cos(look), 0.0, -sin(look)) * strafe * t.speed * 0.4
	velocity = vel
	move_and_slide()
	position.y = 0.0
	face += angle_difference(face, look) * minf(1.0, delta * 10.0)
	rotation.y = face
	_animate(vel.length(), want_move)


func _shoot(a: float) -> void:
	var burst: int = t.get("burst", 0)
	if burst > 0:
		burst_n += 1
		fire_t = t.rate
		if burst_n >= burst:
			burst_n = 0
			fire_t = t.pause
	else:
		fire_t = t.rate
	var fwd := Vector3(sin(a), 0.0, cos(a))
	var muzzle: Vector3 = global_position + fwd * (0.6 * t.scale) + Vector3.UP * 1.33 * minf(t.scale, 1.2)
	Bullet.fire(get_parent(), muzzle, a + randf_range(-1.0, 1.0) * t.spread, Data.ENEMY_BULLET_SPEED, t.dmg, Data.ENEMY_BULLET_LIFE, false)
	Fx.muzzle(get_parent(), muzzle)


## Vrij schootsveld: geen muur (of bunker, als hij op de speler mikt) ertussen.
func _clear_shot(target: Vector3, at_bunker: bool) -> bool:
	var from := global_position + Vector3.UP * 1.33
	var mask := Bullet.MASK_WALL | (0 if at_bunker else Bullet.MASK_BUNKER)
	var q := PhysicsRayQueryParameters3D.create(from, target, mask)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _bunker_dist() -> float:
	var p := global_position
	return maxf(absf(p.x), absf(p.z)) - Data.BUNKER_HALF


func _angle_to(p: Vector3) -> float:
	return atan2(p.x - global_position.x, p.z - global_position.z)


static func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func _animate(spd: float, moving: bool) -> void:
	if model.current == "steken" and model.anim.is_playing():
		return
	if spd < 0.3:
		model.play("schieten" if not moving and not t.get("melee", false) else "stil")
	elif spd > 3.5:
		model.play("rennen", 0.2, spd / 6.0)
	else:
		model.play("lopen", 0.2, spd / 2.4)


func hit(dmg: float, dir: Vector3, from_player: bool) -> void:
	if not from_player or dead:
		return
	hp -= dmg
	model.flash()
	Fx.blood(get_parent(), global_position + Vector3.UP * 1.2, dir)
	if randf() < 0.5:
		Fx.ground_blood(get_parent(), global_position + dir * 0.6, 0.5)
	if hp <= 0.0:
		_die(dir)


func _die(dir: Vector3) -> void:
	dead = true
	Game.enemies.erase(self)
	Game.kills += 1
	Game.add_points(t.pts)
	collision_layer = 0
	collision_mask = 0
	Fx.blood(get_parent(), global_position + Vector3.UP, dir, 26)
	Fx.ground_blood(get_parent(), global_position + dir * 0.4, 1.7)
	if type == "heavy":
		Fx.explosion(get_parent(), global_position, 0.8)
	model.play("dood1" if randf() < 0.5 else "dood2", 0.08)
	get_tree().create_timer(8.0).timeout.connect(queue_free)
