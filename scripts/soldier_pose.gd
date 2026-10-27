class_name SoldierPose
extends SkeletonModifier3D
## Past de pose van het VQ2-mannetje aan nadat de animatie het skelet heeft bijgewerkt:
## - benen en romp draaien los van elkaar: de benen volgen de looprichting (zijwaarts, schuin, achteruit) terwijl romp en wapen
##   naar het richtpunt blijven kijken;
## - een treffer duwt de romp en het hoofd een stuk mee in de richting van de kogel en veert terug;
## - het wapen wordt per wapen echt vastgehouden: het ligt op een vaste plek voor de borst (kolf in de schouder, of met
##   gestrekte armen bij een pistool) en beide armen worden met twee-botten-IK naar de rechtergreep en de steungreep gezet.
## Alles gebeurt in de ruimte van het skelet (Y omhoog, het mannetje kijkt naar +Z).

const LEG_TURN_RATE := 11.0   # radialen per seconde waarmee de benen naar de looprichting draaien
const KICK_ATTACK := 0.045
const KICK_DECAY := 8.5
const SPINE := [["DEF-spine001", 0.22], ["DEF-spine002", 0.34], ["DEF-spine003", 0.44]]
const HEAD := 0.35

## Houding per wapen, in de ruimte van het wapenmodel (Blender: x rechts, y loop, z omhoog, meter, oorsprong = rechtergreep).
## "butt": kolfplaat; die komt in de schoudergroef: `pocket` = plek t.o.v. het rechterschoudergewricht in de ruimte van de borst
## (x naar het midden, y omhoog, z vooruit). Zonder kolf staat de rechtergreep op "grip" t.o.v. dat gewricht. "left" = plek van de steunhand op het wapen, "roll" = draaiing van die hand
## om de looprichting (0 = de hand vouwt van links om de greep, 90 = van onderen onder het voorhout).
const HOLDS := {
	"m1911": {"grip": Vector3(0.14, -0.03, 0.56), "left": Vector3(-0.03, 0.005, -0.015), "roll": 0.0},
	"thompson": {"butt": Vector3(0, -0.375, 0.04), "pocket": Vector3(0.12, -0.04, 0.08), "left": Vector3(0, 0.30, -0.06), "roll": 90.0},
	"garand": {"butt": Vector3(0, -0.445, 0.03), "pocket": Vector3(0.12, -0.04, 0.08), "left": Vector3(0, 0.38, 0.0), "roll": 90.0},
	"trench": {"butt": Vector3(0, -0.36, 0.02), "pocket": Vector3(0.12, -0.04, 0.08), "left": Vector3(0, 0.36, 0.02), "roll": 90.0},
	"mg42": {"butt": Vector3(0, -0.435, 0.05), "pocket": Vector3(0.12, -0.10, 0.08), "left": Vector3(0, 0.30, 0.03), "roll": 90.0},
	"bazooka": {"butt": Vector3(0, -0.2, 0.18), "pocket": Vector3(0.04, 0.07, 0.03), "left": Vector3(0, 0.5, 0.0), "roll": 90.0},
}
const HOLD_BLEND := 0.12      # seconden om tussen animatie en vastgehouden wapen over te vloeien
const POLE_R := Vector3(-0.6, -1.0, -0.3)   # de elleboog wijst omlaag en naar buiten
const POLE_L := Vector3(0.5, -1.0, -0.3)

var weapon := ""            # sleutel in HOLDS ("" = geen wapen)
var hold := false           # stil/lopen/schieten: de handen volgen het wapen; anders speelt de animatie (herladen, klimmen, rol)
var recoil := 0.0           # terugslag 0..1,35 (zie SoldierModel)
var gun_n := Transform3D.IDENTITY   # wapenknoop t.o.v. het bot DEF-handR (door SoldierModel gezet)
var palm_l := Vector3.ZERO  # handpalm t.o.v. DEF-handL
var reach_gap := {"R": 0.0, "L": 0.0}   # hoeveel de pols buiten het bereik van de arm ligt (m, > 0 = hand bereikt het wapen niet); voor tests
var _hold_w := 0.0
var _clav := {}             # "R"/"L" -> sleutelbeenbot
var _arm := {}              # "R"/"L" -> [bovenarm, onderarm, hand]
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
	for side in ["R", "L"]:
		_arm[side] = [skel.find_bone("DEF-upper_arm" + side), skel.find_bone("DEF-forearm" + side), skel.find_bone("DEF-hand" + side)]
		_clav[side] = skel.find_bone("DEF-shoulder" + side)


## Afstand van de pols naar het midden van de handpalm, in de ruimte van het handbot (rustpose).
func palm_offset(side: String) -> Vector3:
	var hand: int = _arm[side][2]
	var mid := _skel.find_bone("DEF-f_middle01" + side)
	var rest := _skel.get_bone_global_rest(hand)
	return rest.basis.inverse() * (_skel.get_bone_global_rest(mid).origin - rest.origin) * 0.55


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
	_hold_w = move_toward(_hold_w, 1.0 if hold and HOLDS.has(weapon) else 0.0, delta / HOLD_BLEND)


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
	if recoil > 0.0:
		# schouderruk: romp tilt achterover en draait licht mee, zodat het ook vanuit de bovencamera te zien is
		for i in 3:
			_rotate_bone(_spine[i], Vector3.RIGHT, -recoil * 0.07 * (i + 1) / 3.0 * 1.0)
			_rotate_bone(_spine[i], Vector3.UP, recoil * 0.05)
	var k := _kick_value()
	if k > 0.001:
		var axis := Vector3.UP.cross(Vector3(_kick_dir.x, 0.0, _kick_dir.y)).normalized()
		for i in SPINE.size():
			_rotate_bone(_spine[i], axis, k * SPINE[i][1])
		_rotate_bone(_head, axis, -k * HEAD)   # het hoofd slaat tegen de beweging van de romp in
	if _hold_w > 0.001:
		_hold_weapon(_hold_w)


## Gewenste stand van het wapenmodel in de skeletruimte: de loop wijst recht vooruit (+Z), vaste plek voor de borst.
func _gun_transform() -> Transform3D:
	var spec: Dictionary = HOLDS[weapon]
	var basis := Basis(Vector3.UP, PI)   # het wapenmodel heeft de loop langs -Z
	var pos: Vector3
	var shoulder := _skel.get_bone_global_pose(_arm["R"][0]).origin
	if spec.has("butt"):
		var b: Vector3 = spec["butt"]   # Blender -> wapenknoop (x, z, -y)
		var chest := _skel.get_bone_global_pose(_spine[2]).basis.orthonormalized()
		pos = shoulder + chest * (spec["pocket"] as Vector3) - basis * Vector3(b.x, b.z, -b.y)
	else:
		pos = shoulder + (spec["grip"] as Vector3)
	pos.z -= recoil * 0.06
	basis = Basis(Vector3.RIGHT, -recoil * 0.12) * basis
	return Transform3D(basis, pos)


func _hold_weapon(w: float) -> void:
	var spec: Dictionary = HOLDS[weapon]
	var d := _gun_transform()
	# rechterhand: de hand zo dat de wapenknoop precies op `d` valt, met dezelfde handstand als in de stilstaande houding
	var wrist_r := d * gun_n.affine_inverse()
	# linkerhand: spiegelbeeld van de handstand rechts, gedraaid om de looprichting; de pols ligt een handpalm van de steungreep af
	var l: Vector3 = spec["left"]
	var grip_point := d * Vector3(l.x, l.z, -l.y)
	var mirror := Basis.from_scale(Vector3(-1, 1, 1))
	var hb: Basis = mirror * wrist_r.basis * mirror
	hb = Basis(Vector3(0, 0, 1), deg_to_rad(float(spec["roll"]))) * hb
	var wrist_l := Transform3D(hb, grip_point - hb * palm_l)
	_solve_arm(_arm["R"], wrist_r, POLE_R, w, "R")
	_solve_arm(_arm["L"], wrist_l, POLE_L, w, "L")


## Twee-botten-IK: bovenarm, onderarm en hand zo dat de pols op `wrist.origin` komt (zover de arm reikt) en de hand de gewenste stand krijgt.
func _solve_arm(bones: Array, wrist: Transform3D, pole: Vector3, w: float, side := "R") -> void:
	var upper: int = bones[0]
	var fore: int = bones[1]
	var hand: int = bones[2]
	var gu := _skel.get_bone_global_pose(upper)
	var a := gu.origin
	var m := _skel.get_bone_global_pose(fore).origin
	var h := _skel.get_bone_global_pose(hand).origin
	var l1 := (m - a).length()
	var l2 := (h - m).length()
	var to := wrist.origin - a
	# te ver weg: het schoudergewricht schuift naar voren (schouderblad), net als bij een echte schutter die zich uitrekt
	var gap := to.length() - (l1 + l2)
	if gap > 0.0 and _clav[side] >= 0:
		var clav: int = _clav[side]
		var orig := _skel.get_bone_global_pose(clav)
		var best := 0.0
		var best_d := to.length()
		for ang in [0.45 * w, -0.45 * w]:
			var t := orig
			t.basis = Basis(Vector3.UP, ang) * orig.basis
			_skel.set_bone_global_pose(clav, t)
			var dist := (wrist.origin - _skel.get_bone_global_pose(upper).origin).length()
			if dist < best_d:
				best_d = dist
				best = ang
		var t2 := orig
		t2.basis = Basis(Vector3.UP, best) * orig.basis
		_skel.set_bone_global_pose(clav, t2)
		gu = _skel.get_bone_global_pose(upper)
		a = gu.origin
		m = _skel.get_bone_global_pose(fore).origin
		h = _skel.get_bone_global_pose(hand).origin
		to = wrist.origin - a
		gap = to.length() - (l1 + l2)
	reach_gap[side] = gap
	var d := clampf(to.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.004)
	var dir := to.normalized()
	var along := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var height := sqrt(maxf(l1 * l1 - along * along, 0.0))
	var out := (pole - dir * pole.dot(dir)).normalized()
	var elbow := a + dir * along + out * height
	var reach := a + dir * d
	var old_u := gu.basis
	gu.basis = Basis(Quaternion((m - a).normalized(), (elbow - a).normalized())) * old_u
	_skel.set_bone_global_pose(upper, Transform3D(old_u.orthonormalized().slerp(gu.basis.orthonormalized(), w), a))
	var gf := _skel.get_bone_global_pose(fore)
	var old_f := gf.basis
	var h2 := _skel.get_bone_global_pose(hand).origin
	var new_f := Basis(Quaternion((h2 - gf.origin).normalized(), (reach - gf.origin).normalized())) * old_f
	gf.basis = old_f.orthonormalized().slerp(new_f.orthonormalized(), w)
	_skel.set_bone_global_pose(fore, gf)
	var gh := _skel.get_bone_global_pose(hand)
	gh.basis = gh.basis.orthonormalized().slerp(wrist.basis.orthonormalized(), w)
	_skel.set_bone_global_pose(hand, gh)
