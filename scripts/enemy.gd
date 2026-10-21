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
var slow_t := 0.0  # prikkeldraad: zolang dit loopt is hij 60% trager
var wire_dmg := 0.0
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
	model.setup(t.color, "" if type == "knife" else t.get("gun", type))
	model.scale = Vector3.ONE * t.scale * Data.SOLDIER_SCALE
	(shape.shape as CapsuleShape3D).radius = t.r
	Game.enemies.append(self)


func _physics_process(delta: float) -> void:
	slow_t -= delta
	if dead or Game.state == "over":
		if not dead:
			model.play("stil")
		return
	var player = Game.player
	if _is_far(player):
		_far_step(delta)
		return
	_set_far(false)
	var melee: bool = t.get("melee", false)
	var range_: float = 0.0 if melee else t.range
	# doelwit: de speler als hij dichtbij genoeg is, anders de bunker
	var to_player := INF
	if player and not player.dead:
		to_player = _flat(player.global_position - global_position).length()
	var at_player := to_player < (20.0 if melee else 16.0)
	# raketwerpers gaan eerst achter een gebouw aan (rocketTower in 18-enemies.js)
	var rb: Variant = _rocket_target() if t.get("rocket", false) else null
	if melee and player and player.elev > 1.0:
		at_player = false  # een mes reikt niet tot op een toren
	_tgt_y = player.global_position.y if at_player else 0.0
	var goal: Vector3 = player.global_position if at_player else Vector3.ZERO
	var dist := to_player if at_player else _bunker_dist()
	if rb != null:
		at_player = false
		_tgt_y = 0.0
		goal = rb.at
		dist = _flat(rb.at - global_position).length() - 2.0

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
				Sfx.play("knife", 1.0, global_position)
				Game.mark_attack(global_position)
				if at_player:
					player.hit(t.dmg, Vector3(sin(look), 0, cos(look)), false)
				else:
					Game.damage_base(t.dmg)
	elif dist < range_ and (rb != null or _clear_shot(aim_at, not at_player)):
		want_move = false
		look = _angle_to(goal)
		if fire_t <= 0.0:
			_shoot(look)

	# een dichte poort in de weg: erop slaan of schieten tot hij kapot is
	var gate: Variant = Game.gates.blocking(global_position, goal) if want_move and Game.gates else null
	if gate != null:
		want_move = false
		look = _angle_to(Game.gates.pos_of(gate))
		if fire_t <= 0.0 and t.get("rocket", false):
			_shoot_rocket(look, Game.gates.pos_of(gate))  # een raket tegen de poort
		elif fire_t <= 0.0:
			fire_t = t.rate if melee else maxf(t.rate, 0.45)
			if melee:
				model.play("steken", 0.08, 1.7)
				Sfx.play("knife", 1.0, global_position)
			else:
				Sfx.play("ping", 0.8, global_position)
			Game.mark_attack(global_position)
			Game.gates.damage(Game.gates.list.find(gate), t.dmg, "melee" if melee else "bullet")

	var vel := Vector3.ZERO
	if want_move:
		var wp := Route.waypoint(global_position, goal)
		var d := _flat(wp - global_position)
		if d.length() > 0.05:
			vel = Vector3(d.x, 0.0, d.y).normalized() * t.speed * speed_mul * (0.4 if slow_t > 0.0 else 1.0)
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


var _tgt_y := 0.0
var _far := false
var _far_acc := 0.0
var _far_n := 0


## Ver van de speler en ver van de basis: niemand ziet hem, dus hij rekent maar af en toe en loopt rechtstreeks.
func _is_far(player: Variant) -> bool:
	if player == null or player.dead or slow_t > 0.0:
		return false
	var d2: float = _flat(player.global_position - global_position).length_squared()
	var from_base := maxf(absf(global_position.x), absf(global_position.z))
	var lim := 55.0 if _far else 62.0  # kleine marge tegen heen en weer schakelen
	return d2 > lim * lim and from_base > 48.0


func _set_far(on: bool) -> void:
	if _far == on:
		return
	_far = on
	model.visible = not on
	model.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT


## Elke vierde natuurkundige stap: een stap richting het volgende punt van de route, zonder botsingen of animatie.
func _far_step(delta: float) -> void:
	_set_far(true)
	_far_acc += delta
	_far_n += 1
	if _far_n % 4 != 0:
		return
	var wp := Route.waypoint(global_position, Vector3.ZERO)
	var d := _flat(wp - global_position)
	if d.length() > 0.05:
		var v: Vector2 = d.normalized() * float(t.speed) * speed_mul * _far_acc
		position += Vector3(v.x, 0.0, v.y)
		face = atan2(d.x, d.y)
		rotation.y = face
	position.y = 0.0
	_far_acc = 0.0


## Dichtstbijzijnde bouwwerk (geen muur of zandzak) binnen 26 m dat nog heel is en waar hij vrij zicht op heeft.
func _rocket_target() -> Variant:
	var best: Variant = null
	var bd := 26.0
	for b in Game.buildings:
		if b.down or Game.builds.is_piece(b.kind):
			continue
		var d := _flat(b.at - global_position).length()
		if d < bd and _rocket_clear(b):
			bd = d
			best = b
	return best


## Geen muur tussen hem en het gebouw (raketten gaan niet over de muur).
func _rocket_clear(b: Dictionary) -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.3, 0), Vector3(b.at.x, 1.3, b.at.z), Bullet.MASK_WALL)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	return r.is_empty() or r.collider == b.node


func _shoot(a: float) -> void:
	if t.get("rocket", false):
		_shoot_rocket(a)
		return
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
	var muzzle: Vector3 = global_position + fwd * (0.6 * t.scale) + Vector3.UP * 1.33 * minf(t.scale, 1.2) * Data.SOLDIER_SCALE
	Game.mark_attack(global_position)
	var rise := 0.0
	if _tgt_y > 1.0 and Game.player:
		var dd := _flat(Game.player.global_position - muzzle).length()
		rise = (_tgt_y + 1.0 - muzzle.y) / maxf(dd, 3.0)
	Bullet.fire(get_parent(), muzzle, a + randf_range(-1.0, 1.0) * t.spread * _aim_mult(), Data.ENEMY_BULLET_SPEED, t.dmg, Data.ENEMY_BULLET_LIFE, false, false, 0, 0.0, 0.0, rise)
	Fx.muzzle(get_parent(), muzzle)
	if Game.player and _flat(Game.player.global_position - global_position).length() < 30.0:
		Fx.casing(get_parent(), muzzle - Vector3(0, 0.15, 0))
	Sfx.play("ak" if type == "heavy" else "enemy", 1.0, global_position)


## Een trage raket die afgaat waar hij gemikt was (of tegen het eerste dat in de weg staat).
func _shoot_rocket(a: float, aim: Variant = null) -> void:
	fire_t = t.rate
	var fwd := Vector3(sin(a), 0.0, cos(a))
	var muzzle: Vector3 = global_position + fwd * 1.1 + Vector3.UP * 1.3
	Game.mark_attack(global_position)
	var rb: Variant = _rocket_target()
	var d := 20.0
	var dm: float = t.dmg
	if aim != null:
		d = _flat(aim - global_position).length()
	elif rb != null:
		d = _flat(rb.at - global_position).length()
	elif Game.player:
		d = _flat(Game.player.global_position - global_position).length()
		dm *= 0.7
	Bullet.fire_rocket(get_parent(), muzzle, a + randf_range(-1.0, 1.0) * t.spread, dm, minf(1.6, (d + 1.5) / 17.0))
	Sfx.play("rocket", 0.8, global_position)


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
	Sfx.play("splat", 1.0, global_position)
	Fx.blood(get_parent(), global_position + Vector3.UP * 1.2, dir)
	if randf() < 0.5:
		Fx.ground_blood(get_parent(), global_position + dir * 0.6, 0.5)
	if hp <= 0.0:
		_die(dir)


func _aim_mult() -> float:
	var b: Dictionary = Progress.bonus()
	return b.enemySpread * (b.nightSpread if GameSettings.get_value("time") == "night" else 1.0)


func _die(dir: Vector3) -> void:
	dead = true
	Game.enemies.erase(self)
	Game.kills += 1
	Sfx.play("thud", 1.0, global_position)
	Progress.stats.kills += 1
	if Progress.stats.kills % 25 == 0:
		Progress.save()
	Game.add_points(t.pts)
	collision_layer = 0
	collision_mask = 0
	Fx.blood(get_parent(), global_position + Vector3.UP, dir, 26)
	Fx.ground_blood(get_parent(), global_position + dir * 0.4, 1.7)
	if type == "heavy":
		Fx.explosion(get_parent(), global_position, 0.8)
	model.play("dood1" if randf() < 0.5 else "dood2", 0.08)
	get_tree().create_timer(8.0).timeout.connect(queue_free)
