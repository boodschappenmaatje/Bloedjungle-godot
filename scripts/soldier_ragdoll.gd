class_name SoldierRagdoll
extends RefCounted
## Zet een VQ2-mannetje bij de dood om in een ragdoll: elf lichaamsdelen (PhysicalBone3D) op het DEF-skelet, verbonden met
## kegelgewrichten, die vanuit de pose op het moment van de dood vallen. Botst alleen met grond, muren en de bunker.
## Het aantal gelijktijdige ragdolls is begrensd (telefoon): daarna blijft de gewone sterfanimatie.

const MAX_ACTIVE := 6
const LAYER := 1 << 19          # eigen laag: ragdolls botsen niet met elkaar, spelers of vijanden
const MASK := 1 | 2 | 16        # grond, muur, bunker
## [bot, kindbot voor de as (leeg = omhoog), straal, massa, zwaaihoek, draaihoek in graden]
const BONES := [
	["DEF-hips", "DEF-spine002", 0.13, 9.0, 25.0, 15.0],
	["DEF-spine002", "DEF-neck", 0.14, 12.0, 25.0, 15.0],
	["DEF-head", "", 0.10, 4.5, 40.0, 40.0],
	["DEF-upper_armL", "DEF-forearmL", 0.05, 2.0, 70.0, 40.0],
	["DEF-forearmL", "DEF-handL", 0.045, 1.5, 55.0, 30.0],
	["DEF-upper_armR", "DEF-forearmR", 0.05, 2.0, 70.0, 40.0],
	["DEF-forearmR", "DEF-handR", 0.045, 1.5, 55.0, 30.0],
	["DEF-thighL", "DEF-shinL", 0.075, 6.0, 55.0, 20.0],
	["DEF-shinL", "DEF-footL", 0.06, 3.5, 40.0, 10.0],
	["DEF-thighR", "DEF-shinR", 0.075, 6.0, 55.0, 20.0],
	["DEF-shinR", "DEF-footR", 0.06, 3.5, 40.0, 10.0],
]

static var active := 0


static func can_start() -> bool:
	return active < MAX_ACTIVE


## `velocity` = beginsnelheid van het hele lichaam (wereld, m/s); `push` = extra klap op de borst (wereld, m/s).
## Geeft false als het niet kan (VQ2 aan, te veel ragdolls, geen skelet).
static func start(model: SoldierModel, velocity := Vector3.ZERO, push := Vector3.ZERO) -> bool:
	if not model.v2 or not can_start() or not model.is_inside_tree():
		return false
	var found := model.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return false
	var skel: Skeleton3D = found[0]
	if skel.find_bone("DEF-hips") < 0:
		return false
	# de animatie en de lichaamsverdraaiing stoppen; de pose waarin hij stond is het beginpunt van de val
	model.anim.pause()
	if model._fire_anim != null:
		model._fire_anim.pause()
	if model.pose != null:
		model.pose.active = false
	var sim := PhysicalBoneSimulator3D.new()
	sim.name = "Ragdoll"
	skel.add_child(sim)
	var bodies: Array[PhysicalBone3D] = []
	for spec in BONES:
		var bone := skel.find_bone(spec[0])
		if bone < 0:
			continue
		var rest := skel.get_bone_global_rest(bone)
		var dir_skel := Vector3.UP
		var length := 0.22
		if spec[1] != "":
			var child := skel.find_bone(spec[1])
			var d := skel.get_bone_global_rest(child).origin - rest.origin
			length = maxf(d.length(), 0.08)
			dir_skel = d / length
		var dir_local := (rest.basis.inverse() * dir_skel).normalized()
		var pb := PhysicalBone3D.new()
		pb.name = String(spec[0]).trim_prefix("DEF-")
		sim.add_child(pb)
		pb.bone_name = spec[0]
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = spec[2]
		cap.height = maxf(length, 2.0 * spec[2] + 0.02)
		cs.shape = cap
		pb.add_child(cs)
		pb.body_offset = Transform3D(Basis(Quaternion(Vector3.UP, dir_local)), dir_local * length * 0.5)
		pb.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
		pb.joint_offset = pb.body_offset.affine_inverse()
		pb.set("joint_constraints/swing_span", spec[4])
		pb.set("joint_constraints/twist_span", spec[5])
		pb.mass = spec[3]
		pb.linear_damp = 0.4
		pb.angular_damp = 4.0
		pb.collision_layer = LAYER
		pb.collision_mask = MASK
		bodies.append(pb)
	sim.physical_bones_start_simulation()
	for pb in bodies:
		pb.linear_velocity = velocity
		if pb.bone_name in ["DEF-spine002", "DEF-hips", "DEF-head"]:
			pb.linear_velocity = velocity + push
	# de huid kan ver van de rustpositie komen: niet wegknippen
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mi.extra_cull_margin = 4.0
	active += 1
	model.tree_exiting.connect(func(): active -= 1, CONNECT_ONE_SHOT)
	return true
