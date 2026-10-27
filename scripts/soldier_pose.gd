class_name SoldierPose
extends SkeletonModifier3D
## Past de pose van het VQ2-mannetje aan nadat de animatie het skelet heeft bijgewerkt:
## - benen en romp draaien los van elkaar: de benen volgen de looprichting (zijwaarts, schuin, achteruit) terwijl romp en wapen
##   naar het richtpunt blijven kijken;
## - een treffer duwt de romp en het hoofd een stuk mee in de richting van de kogel en veert terug.
## Alles gebeurt in de ruimte van het skelet (Y omhoog, het mannetje kijkt naar +Z).

const LEG_TURN_RATE := 11.0   # radialen per seconde waarmee de benen naar de looprichting draaien
const KICK_ATTACK := 0.045
const KICK_DECAY := 8.5
const SPINE := [["DEF-spine001", 0.22], ["DEF-spine002", 0.34], ["DEF-spine003", 0.44]]
const HEAD := 0.35

var leg_yaw := 0.0          # gewenste draaiing van de benen t.o.v. de romp
var _leg := 0.0             # werkelijke (gladgestreken) draaiing
var _kick_dir := Vector2.ZERO   # horizontale richting waarin de treffer duwt (skeletruimte, x/z)
var _kick_amp := 0.0
var _kick_t := 99.0
var _skel: Skeleton3D
var _hips := -1
var _spine: Array[int] = []
var _head := -1


func setup_skeleton(skel: Skeleton3D) -> void:
	_skel = skel
	_hips = skel.find_bone("DEF-hips")
	_head = skel.find_bone("DEF-head")
	_spine.clear()
	for s in SPINE:
		_spine.append(skel.find_bone(s[0]))


## `dir` is de wereldrichting waarin de kogel vliegt; de romp buigt die kant op.
func kick(dir: Vector3, strength: float) -> void:
	if _skel == null:
		return
	var local := _skel.global_transform.basis.inverse() * dir
	var flat := Vector2(local.x, local.z)
	if flat.length_squared() < 0.0001:
		flat = Vector2(0.0, 1.0)
	_kick_dir = flat.normalized()
	_kick_amp = clampf(strength, 0.4, 2.0)
	_kick_t = 0.0


func is_kicking() -> bool:
	return _kick_t < 1.2


func _process(delta: float) -> void:
	var step := LEG_TURN_RATE * delta
	_leg += clampf(angle_difference(_leg, leg_yaw), -step, step)
	if _kick_t < 99.0:
		_kick_t += delta


func _kick_value() -> float:
	if _kick_t >= 1.2:
		return 0.0
	if _kick_t < KICK_ATTACK:
		return _kick_amp * _kick_t / KICK_ATTACK
	return _kick_amp * exp(-(_kick_t - KICK_ATTACK) * KICK_DECAY)


func _rotate_bone(bone: int, axis: Vector3, angle: float) -> void:
	if bone < 0 or absf(angle) < 0.0001:
		return
	var g := _skel.get_bone_global_pose(bone)
	g.basis = Basis(axis, angle) * g.basis
	_skel.set_bone_global_pose(bone, g)


func _process_modification() -> void:
	if _skel == null or _hips < 0:
		return
	if absf(_leg) > 0.001:
		# de benen draaien mee met de heup; de romp draait er in drie stappen precies tegenin terug
		_rotate_bone(_hips, Vector3.UP, _leg)
		_rotate_bone(_spine[0], Vector3.UP, -_leg * 0.4)
		_rotate_bone(_spine[1], Vector3.UP, -_leg * 0.3)
		_rotate_bone(_spine[2], Vector3.UP, -_leg * 0.3)
	var k := _kick_value()
	if k > 0.001:
		var axis := Vector3.UP.cross(Vector3(_kick_dir.x, 0.0, _kick_dir.y)).normalized()
		for i in SPINE.size():
			_rotate_bone(_spine[i], axis, k * SPINE[i][1])
		_rotate_bone(_head, axis, -k * HEAD)   # het hoofd slaat tegen de beweging van de romp in
