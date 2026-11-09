extends "res://scripts/enemy.gd"
## Twelve persistent defenders; reserves walk and climb before a vacant MG can fire.

var post := "poort"
var tower: Node3D
var home := Vector3.ZERO
var assignment: Node3D
var climb_t := 0.0
var approach_done := false

# Confirmed M2-gunner hits get a short, unobtrusive world-space indication.
# No extra effects when a shot hits the moving steel shield or concrete.
var _hit_bar_t := 0.0
var _hit_cross_t := 0.0
var _hit_ping_cd := 0.0
var _hit_label: Label3D


func _ready() -> void:
	super._ready()
	_hit_label = Label3D.new()
	_hit_label.name = "M2HitConfirm"
	_hit_label.position = Vector3(0.0, 2.95, 0.0)
	_hit_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hit_label.font_size = 38
	_hit_label.pixel_size = 0.008
	_hit_label.outline_size = 8
	_hit_label.outline_modulate = Color(0.04, 0.05, 0.04, 0.95)
	_hit_label.modulate = Color(0.97, 0.93, 0.79)
	_hit_label.no_depth_test = false
	_hit_label.visible = false
	add_child(_hit_label)


func _process(delta: float) -> void:
	super._process(delta)
	_hit_bar_t = maxf(0.0, _hit_bar_t - delta)
	_hit_cross_t = maxf(0.0, _hit_cross_t - delta)
	_hit_ping_cd = maxf(0.0, _hit_ping_cd - delta)
	if _hit_label != null:
		_hit_label.visible = _hit_cross_t > 0.0
		_hit_label.modulate = Color(1.0, 0.90, 0.66) if dead else Color(0.94, 0.97, 0.88)
	# The normal range marker respects user HUD settings. A recent confirmed
	# gunner hit temporarily reveals and enlarges it even in minimal HUD mode.
	if _range_marker != null and post == "schutter":
		var show_hit_bar := not dead and _hit_bar_t > 0.0
		if show_hit_bar:
			_range_marker.visible = true
			_health_fill.scale.x = clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
		_range_marker.scale = Vector3(1.45, 1.45, 1.0) if show_hit_bar else Vector3.ONE


func hit(dmg: float, dir: Vector3, from_player: bool) -> void:
	var confirmed_gunner_hit := from_player and not dead and dmg > 0.0 and post == "schutter" and Game.hit_src == "speler"
	super.hit(dmg, dir, from_player)
	if not confirmed_gunner_hit:
		return
	_hit_bar_t = 1.5
	_hit_cross_t = 1.6 if dead else 0.24
	if _hit_label != null:
		_hit_label.text = "MG UIT" if dead else "×"
	# The existing blood + pain reaction stays on the real body; this soft
	# short ping confirms a hit, never a hit on steel/concrete.
	if _hit_ping_cd <= 0.0:
		Sfx.play("ping" if dead else "click", 0.48 if dead else 0.24)
		_hit_ping_cd = 0.18


func _physics_process(delta: float) -> void:
	if dead or Game.state not in ["play", "prep"]:
		return
	if post == "schutter":
		velocity = Vector3.ZERO
		model.set_shoot_pose(true, "garand", 0.2)
		model.play("stil", 0.2)
		return
	if post == "reserve" and assignment != null:
		if not is_instance_valid(assignment) or assignment.destroyed:
			assignment = null
			climb_t = 0.0
			approach_done = false
		else:
			var ladder: Vector3 = assignment.get_node("LadderStart").global_position
			var base_center: Vector3 = assignment.get_parent().global_position
			var offset: Vector3 = assignment.global_position - base_center
			var via := base_center + Vector3(signf(offset.x) * 8.0, 0, signf(offset.z) * 21.0)
			if global_position.distance_to(via) < 0.8:
				approach_done = true
			var waypoint: Vector3 = ladder if approach_done else via
			var diff := waypoint - global_position
			diff.y = 0.0
			if diff.length() > (0.3 if approach_done else 0.8) and climb_t <= 0.0:
				velocity = diff.normalized() * 5.2
				move_and_slide()
				model.play("rennen", 0.1)
				return
			climb_t += delta
			velocity = Vector3.ZERO
			# Actual translation through the three ladder stages, vulnerable throughout.
			var landing: Vector3 = assignment.get_node("LadderLanding").global_position
			var end: Vector3 = assignment.get_node("LadderEnd").global_position
			global_position = ladder.lerp(landing, minf(climb_t / 1.5, 1.0)) if climb_t < 1.5 else landing.lerp(end, minf((climb_t - 1.5) / 1.5, 1.0))
			model.play("klimmen" if climb_t < 3.0 else "stil", 0.1)
			if climb_t >= 4.0:
				post = "schutter"
				tower = assignment
				assignment.shooter = self
				assignment = null
			return
	var target: Node3D = Game.player if is_instance_valid(Game.player) and not Game.player.dead else null
	for a in Game.allies:
		if is_instance_valid(a) and global_position.distance_to(a.global_position) < (global_position.distance_to(target.global_position) if target else INF):
			target = a
	if target == null:
		return
	var to := target.global_position - global_position
	var distance := Vector2(to.x, to.z).length()
	var goal := home
	if post == "reserve" and distance < 18.0:
		goal += Vector3(to.z, 0, -to.x).normalized() * 3.0
	var step := goal - global_position
	step.y = 0
	velocity = step.normalized() * 3.0 if step.length() > 0.8 else Vector3.ZERO
	move_and_slide()
	model.play("lopen" if velocity.length() > 0.1 else "stil", 0.15)
	if distance <= 16.0:
		var from := global_position + Vector3.UP * 1.5
		var aim := target.global_position + Vector3.UP * 1.3
		var ray := PhysicsRayQueryParameters3D.create(from, aim, Bullet.MASK_WALL | Bullet.MASK_BUNKER | Bullet.MASK_NATURE | Bullet.MASK_FORTIFICATION)
		if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			fire_t -= delta
			if fire_t <= 0.0:
				fire_t = 0.65
				var angle := atan2(aim.x - from.x, aim.z - from.z)
				Bullet.fire(get_parent(), from, angle, 90.0, 7.0, 0.3, false, false, 0, 0, 0, (aim.y - from.y) / maxf(distance, 0.1))
				model.shoot_recoil("garand")


func _die(dir: Vector3, clip := "") -> void:
	if tower != null and is_instance_valid(tower):
		tower.shooter = null
	if assignment != null and is_instance_valid(assignment):
		assignment.reserved_by = null
	super._die(dir, clip)
