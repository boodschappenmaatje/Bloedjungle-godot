class_name VijandM2Toren
extends Node3D

const HP := 650.0
const RANGE := 36.0
const DAMAGE := 6.0
const BURST := 8
const MODEL_PATH := "res://assets/vijand_m2_toren.glb"
var hp := HP
var destroyed := false
var shooter: Node3D
var reserved_by: Node3D
var aim_t := 0.0
var fire_t := 0.0
var burst := 0
var target: Node3D
var yaw: Node3D
var pitch: Node3D
var recoil: Node3D
var intact: Node3D


func _ready() -> void:
	add_to_group("vijand_toren")
	intact = load(MODEL_PATH).instantiate()
	intact.name = "TowerIntact"
	add_child(intact)
	var body := StaticBody3D.new()
	body.set_script(preload("res://scripts/vijand_m2_body.gd"))
	body.collision_layer = Kit.LAYER_WALL | Kit.LAYER_BUNKER
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.9, 5.0, 1.9)
	shape.shape = box
	body.position.y = 2.5
	body.add_child(shape)
	add_child(body)
	yaw = Node3D.new()
	yaw.name = "MG_Yaw"
	yaw.position.y = 4.6
	add_child(yaw)
	pitch = Node3D.new()
	pitch.name = "MG_Pitch"
	yaw.add_child(pitch)
	recoil = Node3D.new()
	recoil.name = "MG_Recoil"
	pitch.add_child(recoil)
	for name_ in ["AmmoBelt", "Muzzle", "CasingEject", "ShooterMount", "LadderStart", "LadderLanding", "LadderEnd"]:
		var anchor := Node3D.new()
		anchor.name = name_
		add_child(anchor)
	get_node("Muzzle").position = Vector3(0, 4.8, 1.3)
	get_node("ShooterMount").position = Vector3(0, 4.4, -0.4)
	get_node("LadderStart").position = Vector3(0, 0, -2.3)
	get_node("LadderLanding").position = Vector3(0, 2.2, -2.3)
	get_node("LadderEnd").position = Vector3(0, 4.4, -1.5)


func operational() -> bool:
	return not destroyed and is_instance_valid(shooter) and not shooter.dead and shooter.post == "schutter"


func _physics_process(delta: float) -> void:
	if destroyed:
		return
	if not operational():
		target = null
		burst = 0
		if reserved_by == null:
			for soldier in get_tree().get_nodes_in_group("vijand_verdediger"):
				if soldier.post == "reserve" and not soldier.dead and soldier.assignment == null:
					reserved_by = soldier
					soldier.assignment = self
					break
		return
	var best: Node3D
	var score := -INF
	for candidate in Game.allies + [Game.player]:
		if not is_instance_valid(candidate) or candidate.get("dead") == true:
			continue
		if candidate is Ally and candidate.beleg_bezig():
			continue
		var to: Vector3 = candidate.global_position - global_position
		var d := Vector2(to.x, to.z).length()
		if d > RANGE or d < 1.0:
			continue
		var muzzle: Vector3 = get_node("Muzzle").global_position
		var aim: Vector3 = candidate.global_position + Vector3.UP * 1.3
		var q := PhysicsRayQueryParameters3D.create(muzzle, aim, Bullet.MASK_WALL | Bullet.MASK_BUNKER | Bullet.MASK_NATURE | Bullet.MASK_FORTIFICATION)
		if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			continue
		var priority := 100.0 - d
		if candidate.is_in_group("voertuigen"):
			priority += 50.0
		if priority > score:
			score = priority
			best = candidate
	if best != target:
		target = best
		aim_t = 0.0
		burst = 0
	if target == null:
		return
	aim_t += delta
	var aim: Vector3 = target.global_position + Vector3.UP * 1.3
	var from: Vector3 = get_node("Muzzle").global_position
	var diff := aim - from
	yaw.rotation.y = lerp_angle(yaw.rotation.y, atan2(diff.x, diff.z), delta * 5.0)
	pitch.rotation.x = lerpf(pitch.rotation.x, -atan2(diff.y, Vector2(diff.x, diff.z).length()), delta * 5.0)
	recoil.position.z = move_toward(recoil.position.z, 0.0, delta * 0.7)
	fire_t -= delta
	if aim_t < 0.8 or fire_t > 0.0:
		return
	if burst >= BURST:
		burst = 0
		fire_t = 1.1
		return
	burst += 1
	fire_t = 0.115
	recoil.position.z = -0.12
	var angle := atan2(diff.x, diff.z)
	var round_ := Bullet.fire(get_parent(), from, angle, 150.0, DAMAGE, RANGE / 150.0, false, false, 0, 0, 0, diff.y / maxf(Vector2(diff.x, diff.z).length(), 0.1))
	round_.src = "m2"
	shooter.model.shoot_recoil("garand")
	Fx.spark(get_parent(), from, diff.normalized())


func damage(amount: float, _kind := "bullet") -> void:
	if destroyed:
		return
	hp -= amount
	if hp <= 0.0:
		destroyed = true
		if is_instance_valid(shooter):
			shooter.hit(shooter.hp + 1.0, Vector3.UP, true)
		intact.rotation.z = 0.18
		intact.position.y = -0.65
		Fx.explosion(get_parent(), global_position + Vector3.UP * 3.0, 2.0)
	elif hp < HP * 0.4:
		Fx.spark(get_parent(), global_position + Vector3.UP * 3.0, Vector3.UP)


static func blast(at: Vector3, radius: float, amount: float) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for node in tree.get_nodes_in_group("vijand_toren"):
		var tower := node as VijandM2Toren
		var center := tower.global_position + Vector3.UP * 2.7
		var distance := center.distance_to(at)
		if distance < radius + 1.4 and not BaseWallRules.blocks_blast(at, center):
			tower.damage(amount * (1.0 - 0.7 * maxf(distance - 1.4, 0.0) / radius), "explosive")
