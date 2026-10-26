class_name Ally
extends CharacterBody3D
## Een rekruut uit de kazerne: loopt met je mee of houdt een post langs de muur en schiet op vijanden in de buurt.
## Zoals de bondgenoten uit 16d-base.js (nu nog zonder vijanden die op hem schieten).

const POSTS := [Vector2(-5, -12.7), Vector2(5, -12.7), Vector2(-5, 12.7), Vector2(5, 12.7), Vector2(-12.7, -5), Vector2(12.7, -5),
	Vector2(-12.7, 5), Vector2(12.7, 5), Vector2(-8.5, -12.7), Vector2(8.5, -12.7), Vector2(-8.5, 12.7), Vector2(8.5, 12.7)]
const SPEED := 4.6
const RANGE := 16.0

var model: SoldierModel
var face := 0.0
var hp := 100.0
var dmg := 16.0
var idx := 0
var fire_t := 0.5
var _shooting := false
var _shot_sequence := 0
var recall = null    # Vector3 als de versterking naar de truck terug moet lopen
var helper := false  # versterking uit de luchtsteun: volgt altijd de speler en blijft los van de kazerne
var truck: Node = null  # vrachtwagen die hem vervoert; die bepaalt dan waar hij is en wat hij doet


func setup(hp_: float, dmg_: float, index: int) -> void:
	hp = hp_
	dmg = dmg_
	idx = index
	collision_layer = 0
	collision_mask = Kit.LAYER_WALL | Kit.LAYER_BUNKER | Kit.LAYER_WATER
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	col.shape = cap
	col.position.y = 0.9
	add_child(col)
	model = SoldierModel.new()
	add_child(model)
	model.setup(Color("5a6a36"), "thompson")
	model.scale = Vector3.ONE * Data.SOLDIER_SCALE
	rotation.y = face


func set_level(hp_: float, dmg_: float) -> void:
	hp = maxf(hp, hp_ * 0.8)
	dmg = dmg_


func _physics_process(delta: float) -> void:
	if truck != null:
		if is_instance_valid(truck):
			model.set_shoot_pose(false, "thompson", 0.5)
			truck.ride_step(self, delta)
			rotation.y = face
			return
		truck = null
	if Game.state != "play" and Game.state != "prep":
		velocity = Vector3.ZERO
		model.set_shoot_pose(false, "thompson", 0.5)
		return
	fire_t -= delta
	var target: Node3D = _nearest_enemy()
	var goal := _goal()
	var to_goal := Vector2(goal.x - global_position.x, goal.z - global_position.z)
	var want := Vector3.ZERO
	var moving := false
	if to_goal.length() > (0.6 if Game.troop_mode == "hold" and not helper else 2.2):
		var wp := Route.waypoint(global_position, goal)
		var d := Vector2(wp.x - global_position.x, wp.z - global_position.z)
		if d.length() > 0.05:
			want = Vector3(d.x, 0, d.y).normalized() * SPEED * (1.0 if to_goal.length() > 5.0 else 0.6)
			moving = true
	velocity = want
	move_and_slide()
	position.y = 0.0
	var look := face
	if target != null:
		var td := target.global_position - global_position
		look = atan2(td.x, td.z)
	elif moving:
		look = atan2(want.x, want.z)
	face += angle_difference(face, look) * minf(1.0, delta * 12.0)
	rotation.y = face
	if target != null and fire_t <= 0.0 and absf(angle_difference(face, look)) < 0.35:
		_shoot()
	_shooting = target != null
	model.set_shoot_pose(_shooting, "thompson", 0.5)
	if moving:
		model.play("lopen", 0.2, 1.4)
	elif _shooting:
		model.play("schieten", 0.1)
	else:
		model.play("stil")


func _goal() -> Vector3:
	if recall != null:
		return recall
	if Game.troop_mode == "hold" and not helper:
		var p: Vector2 = POSTS[idx % POSTS.size()] * (Data.COMPOUND / 14.0)
		return Vector3(p.x, 0, p.y)
	var a := float(idx) * 2.4 + 0.6
	var base: Vector3 = Game.player.global_position
	base.y = 0.0
	return base + Vector3(cos(a), 0, sin(a)) * 2.8


func _nearest_enemy() -> Node3D:
	var best: Node3D = null
	var bd := RANGE
	var from := global_position + Vector3.UP * 1.4
	for e: Node3D in Game.enemies:
		if not is_instance_valid(e):
			continue
		var d := (e.global_position - global_position)
		d.y = 0.0
		var l := d.length()
		if l < bd:
			var q := PhysicsRayQueryParameters3D.create(from, e.global_position + Vector3.UP * 1.3, Bullet.MASK_WALL | Bullet.MASK_BUNKER)
			if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
				bd = l
				best = e
	return best


func _shoot() -> void:
	fire_t = 0.5
	_shot_sequence += 1
	model.shoot_recoil("thompson")
	var muzzle: Vector3 = model.muzzle_position()
	var profile: Dictionary = Data.WEAPON_VISUALS["thompson"]
	var tracer := "thompson" if (_shot_sequence - 1) % int(profile.trail_every) == 0 else ""
	var b := Bullet.fire(get_parent(), muzzle, face + randf_range(-0.05, 0.05), 70.0, dmg, 0.6, true, false, 0, 0.0, 0.0, 0.0, tracer)
	b.src = "soldaat"
	Fx.muzzle(get_parent(), muzzle, "thompson", face)
	if _shot_sequence % int(profile.casing_every) == 0:
		var axes := model.casing_axes()
		Fx.casing(get_parent(), model.casing_position(), axes[0], axes[1])
	Sfx.play("ak", 0.45, global_position)
