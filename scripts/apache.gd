class_name Apache
extends Node3D
## Eigen Apache, gekocht bij het helikopterplatform. Hij staat op de lift (het platform tilt hem uit de grond),
## je stapt in met INSTAPPEN en vliegt: linker stick = vliegen, rechter stick = richten, tot de rand duwen = schieten
## met het kanon onder de neus. LANDEN brengt hem terug op het platform (als je er dichtbij bent), waar de lift hem weer de grond in zakt;
## elders landt hij waar je boven bent (niet boven water) en blijft daar staan tot je weer instapt.
## Model: assets/apache.glb (Blender), voorkant is -Z; de rotors draaien in de code, de Blender-clips gebruiken we niet.

enum Mode { LIFT, FLY, LAND, FREE, GROUND }  # FREE = landt ergens, GROUND = staat geparkeerd op de grond

const SCALE := 0.45          # het model is 17 m lang; zo past hij op het platform
const SPEED := 15.0          # m/s
const ACCEL := 5.0
const CRUISE := 7.0          # vlieghoogte in m
const CLIMB := 3.0           # m/s stijgen en dalen
const FIRE_RATE := 0.07
const DAMAGE := 14.0
const BOARD_DIST := 9.0      # m van het midden van het platform: dichterbij dan dit toont de knop
const LAND_DIST := 24.0
const RING_DIST := 9.0       # m vanaf de heli: waar de richtcirkel op de grond ligt
const RING_R := 3.0
const GROUND_BOARD := 6.0     # m: bij een geparkeerde heli op de grond toont de knop IN
const ROTOR_RPS := 3.0
const TAIL_RPS := 9.0

var mode := Mode.LIFT
var driven := false
var pad: Dictionary
var vel := Vector3.ZERO
var _rotor: Node3D
var _tail: Node3D
var _wrap: Node3D
var _rot_speed := 0.0
var _rot_target := 0.0
var _cool := 0.0
var _spool := 0.0           # na het instappen eerst de rotor op toeren, dan pas recht omhoog
var _t := 0.0
var _btn: ActionBtn
var _btn_what := ""
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D


func setup(p: Dictionary) -> void:
	pad = p


func _ready() -> void:
	_wrap = Node3D.new()
	_wrap.scale = Vector3.ONE * SCALE
	add_child(_wrap)
	var inst: Node3D = (load("res://assets/apache.glb") as PackedScene).instantiate()
	_wrap.add_child(inst)
	var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
	if ap:
		ap.stop()
		ap.queue_free()
	# het model is bewaard in de stand van de laatste Blender-clip (scheef overhellend): eerst recht zetten
	var body := inst.find_child("Body", true, false) as Node3D
	if body:
		body.rotation = Vector3.ZERO
	_rotor = inst.find_child("Rotor", true, false)
	_tail = inst.find_child("Staartrotor", true, false)
	# de skids net op de grond zetten
	var rump := inst.find_child("RompMesh", true, false) as MeshInstance3D
	if rump:
		var low := INF
		var to_wrap := _wrap.global_transform.affine_inverse() * rump.global_transform
		var bb := rump.get_aabb()
		for i in 8:
			low = minf(low, (to_wrap * bb.get_endpoint(i)).y)
		inst.position.y -= low
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_btn = ActionBtn.make("enter", "IN")
	_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_btn.offset_left = ActionBtn.slot_x(2)
	_btn.offset_right = ActionBtn.slot_x(2) + ActionBtn.SIZE.x
	_btn.offset_top = -126.0
	_btn.offset_bottom = -126.0 + ActionBtn.SIZE.y
	_btn.pressed.connect(_press)
	layer.add_child(_btn)
	_btn.hide()
	_make_ring()
	_follow_lift()


## Richtcirkel op de grond voor de heli: het kanon schiet schuin omlaag naar die cirkel. Rood als er een vijand in staat.
func _make_ring() -> void:
	var t := TorusMesh.new()
	t.inner_radius = RING_R - 0.12
	t.outer_radius = RING_R
	t.rings = 24
	t.ring_segments = 4
	_ring = MeshInstance3D.new()
	_ring.mesh = t
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.albedo_color = Color(1.0, 0.85, 0.3, 0.75)
	_ring_mat.no_depth_test = true
	_ring.material_override = _ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.top_level = true
	_ring.visible = false
	add_child(_ring)


func _ring_center() -> Vector3:
	var fwd := -global_transform.basis.z
	return Vector3(global_position.x + fwd.x * RING_DIST, 0.0, global_position.z + fwd.z * RING_DIST)


func _update_ring() -> void:
	var on := mode == Mode.FLY and driven and _spool <= 0.0 and global_position.y > 3.0
	_ring.visible = on
	if not on:
		return
	var c := _ring_center()
	_ring.global_position = Vector3(c.x, 0.08, c.z)
	var hot := false
	for e in Game.enemies:
		if is_instance_valid(e) and Vector2(e.global_position.x - c.x, e.global_position.z - c.z).length() < RING_R + 0.4:
			hot = true
			break
	_ring_mat.albedo_color = Color(1.0, 0.25, 0.2, 0.85) if hot else Color(1.0, 0.85, 0.3, 0.7)


func _pad_center() -> Vector3:
	return pad.at


func _lift_pos() -> Transform3D:
	var lift: Node3D = pad.lift
	return lift.global_transform


func _follow_lift() -> void:
	global_transform = Transform3D(Basis(Vector3.UP, pad.yaw), _lift_pos().origin)


func parked() -> bool:
	return mode == Mode.LIFT


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _press() -> void:
	var p = Game.player
	if p == null or p.dead:
		return
	match _btn_what:
		"roep":
			pad.want = true
			Sfx.play("click")
		"in":
			_board(p)
		"land":
			mode = Mode.LAND
			pad.want = true
			Sfx.play("click")
		"landhier":
			var why := _no_landing()
			if why != "":
				Game.banner.emit("HELI", why, 1.6)
				return
			mode = Mode.FREE
			vel = Vector3.ZERO
			Sfx.play("click")


func _board(p) -> void:
	driven = true
	mode = Mode.FLY
	vel = Vector3.ZERO
	_spool = 2.4
	p.driving = true
	p.airborne = true
	p.visible = false
	p.collision_mask = 0
	p.velocity = Vector3.ZERO
	Sfx.play("click")


func _leave(p) -> void:
	driven = false
	mode = Mode.LIFT
	vel = Vector3.ZERO
	p.driving = false
	p.airborne = false
	p.visible = true
	var out: Vector3 = Buildings._pt(pad.at, pad.yaw, 7.6, 0.0)
	p.global_position = Vector3(out.x, 0.0, out.z)
	p.collision_mask = p.get("_mask0")


func _physics_process(delta: float) -> void:
	_t += delta
	var live: bool = Game.state == "play" or Game.state == "prep"
	var p = Game.player
	if p != null and p.dead and driven:
		_leave(p)
	_rot_target = 0.0 if mode == Mode.GROUND else 1.0 if mode != Mode.LIFT else (0.3 if (pad.hs == "open" or pad.hs == "opening") else 0.0)
	_rot_speed = move_toward(_rot_speed, _rot_target, delta / 2.5)
	if _rotor:
		_rotor.rotation.y -= _rot_speed * ROTOR_RPS * TAU * delta
	if _tail:
		_tail.rotation.x += _rot_speed * TAIL_RPS * TAU * delta
	match mode:
		Mode.LIFT:
			_follow_lift()
			_wrap.rotation = _wrap.rotation.lerp(Vector3.ZERO, minf(1.0, delta * 4.0))
		Mode.FLY:
			_fly(delta, live)
		Mode.LAND:
			_land(delta)
		Mode.FREE:
			_land_free(delta)
		Mode.GROUND:
			_wrap.rotation = _wrap.rotation.lerp(Vector3.ZERO, minf(1.0, delta * 4.0))
	_update_ring()
	_update_button(p, live)


func _update_button(p, live: bool) -> void:
	var what := ""
	if p != null and not p.dead and live:
		var d := _flat_dist(p.global_position, pad.at)
		if mode == Mode.LIFT and not driven and d < BOARD_DIST:
			what = "in" if pad.hs == "open" else ("roep" if pad.hs == "closed" and not pad.want else "")
		elif mode == Mode.FLY and driven and _spool <= 0.0:
			what = "land" if _flat_dist(global_position, pad.at) < LAND_DIST else "landhier"
		elif mode == Mode.GROUND and not driven and _flat_dist(p.global_position, global_position) < GROUND_BOARD:
			what = "in"
	_btn_what = what
	_btn.visible = what != ""
	_btn.dock(2)
	if what == "in":
		_btn.kind = "enter"
		_btn.set_caption("IN")
	elif what == "roep":
		_btn.kind = "poort"
		_btn.set_caption("HELI")
	elif what == "land" or what == "landhier":
		_btn.kind = "exit"
		_btn.set_caption("LANDEN")
	_btn.queue_redraw()


func _fly(delta: float, live: bool) -> void:
	var p = Game.player
	var mv := Game.move if live else Vector2.ZERO
	# omhoog tot de vlieghoogte, daarna sturen
	var y_goal := CRUISE
	if _spool > 0.0:
		_spool -= delta
	else:
		global_position.y = move_toward(global_position.y, y_goal, CLIMB * delta)
	var want := Vector3(mv.x, 0.0, mv.y) * SPEED * clampf(mv.length() * 1.2, 0.0, 1.0)
	if global_position.y < 4.2 or _spool > 0.0:
		want = Vector3.ZERO  # eerst recht omhoog tussen de luiken uit
	vel = vel.lerp(want, minf(1.0, ACCEL * delta * 0.5))
	global_position += vel * delta
	var flat := Vector2(global_position.x, global_position.z)
	var clamped := Data.clamp_world(flat)
	if clamped != flat:
		flat = clamped
		global_position = Vector3(flat.x, global_position.y, flat.y)
	# neus: naar waar je richt, anders naar waar je heen vliegt
	var face := rotation.y
	var aiming: bool = live and not is_nan(Game.aim)
	if aiming:
		face = Game.aim + PI
	elif mv.length() > 0.15:
		face = atan2(-mv.x, -mv.y)
	var diff := wrapf(face - rotation.y, -PI, PI)
	rotation.y += clampf(diff, -2.6 * delta, 2.6 * delta)
	# overhellen met de vaart
	var fwd := -global_transform.basis.z
	var right := global_transform.basis.x
	_wrap.rotation.x = lerpf(_wrap.rotation.x, -clampf(vel.dot(fwd) * 0.02, -0.3, 0.3), delta * 3.0)
	_wrap.rotation.z = lerpf(_wrap.rotation.z, -clampf(vel.dot(right) * 0.02, -0.3, 0.3), delta * 3.0)
	# kanon onder de neus
	_cool -= delta
	if live and Game.fire and aiming and absf(diff) < 0.3 and _cool <= 0.0 and global_position.y > 3.0:
		_cool = FIRE_RATE
		# schuin omlaag naar een willekeurig punt in de richtcirkel
		var from := Vector3(global_position.x, global_position.y - 0.6, global_position.z) + fwd * 3.0
		var c := _ring_center()
		var spot := Vector3(c.x, 1.0, c.z) + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).limit_length(1.0) * RING_R * sqrt(randf())
		var to := spot - from
		var hd := Vector2(to.x, to.z).length()
		var spd := 95.0
		Bullet.fire(get_parent(), from, atan2(to.x, to.z), spd, DAMAGE, hd / spd * 1.3, true, true, 0, 0.0, 0.0, to.y / maxf(hd, 0.1))
		Fx.muzzle(get_parent(), global_position + fwd * 3.4 + Vector3(0, -0.6, 0))
		Sfx.play("mg", 0.4, global_position)
	if p != null:
		p.global_position = Vector3(global_position.x, 0.0, global_position.z)
		p.face = rotation.y + PI


## Waarom hij hier niet kan landen ("" = het kan): water, bomen of rotsen, muren/gebouwen.
func _no_landing() -> String:
	var gp := global_position
	if absf(gp.z - Data.river_z(gp.x)) < Data.RIVER_HALF + 3.0:
		return "Boven water kun je niet landen"
	if Foliage.has_tree_near(gp.x, gp.z, 5.0):
		return "Te veel bomen, zoek een open plek"
	var q := PhysicsShapeQueryParameters3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 4.5
	q.shape = sh
	q.transform = Transform3D(Basis.IDENTITY, Vector3(gp.x, 1.5, gp.z))
	q.collision_mask = 2 | 16 | 32  # muren, bunkers, voertuigen
	q.collide_with_areas = false
	if not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty():
		return "Hier is geen ruimte om te landen"
	return ""


## Zakt recht naar beneden op de plek waar je bent; bij de grond stap je uit en blijft hij staan.
func _land_free(delta: float) -> void:
	var p = Game.player
	vel = vel.lerp(Vector3.ZERO, minf(1.0, delta * 2.0))
	global_position += vel * delta
	global_position.y = move_toward(global_position.y, 0.0, 2.6 * delta)
	_wrap.rotation = _wrap.rotation.lerp(Vector3.ZERO, minf(1.0, delta * 3.0))
	if p != null and driven:
		p.global_position = Vector3(global_position.x, 0.0, global_position.z)
	if global_position.y <= 0.02:
		mode = Mode.GROUND
		if p != null and driven:
			driven = false
			p.driving = false
			p.airborne = false
			p.visible = true
			var side := global_transform.basis.x * 4.2
			p.global_position = Vector3(global_position.x + side.x, 0.0, global_position.z + side.z)
			p.collision_mask = p.get("_mask0")


func _land(delta: float) -> void:
	var p = Game.player
	var target: Vector3 = pad.at
	var d := _flat_dist(global_position, target)
	var ready: bool = pad.hs == "open"
	if d > 0.4:
		var dir := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z).normalized()
		global_position += dir * minf(10.0, d * 1.2 + 1.5) * delta
		global_position.y = move_toward(global_position.y, CRUISE, CLIMB * delta)
	elif ready:
		var floor_y: float = _lift_pos().origin.y
		global_position.x = target.x
		global_position.z = target.z
		global_position.y = move_toward(global_position.y, floor_y, 2.2 * delta)
		rotation.y += clampf(wrapf(pad.yaw - rotation.y, -PI, PI), -1.5 * delta, 1.5 * delta)
		if absf(global_position.y - floor_y) < 0.02:
			if p != null:
				_leave(p)
			mode = Mode.LIFT
	_wrap.rotation = _wrap.rotation.lerp(Vector3.ZERO, minf(1.0, delta * 3.0))
	if p != null and driven:
		p.global_position = Vector3(global_position.x, 0.0, global_position.z)
