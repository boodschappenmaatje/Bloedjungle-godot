extends CharacterBody3D
## Eigen jeep met een schutter op een .50 MG. Hij staat geparkeerd in de basis; kom je dichtbij, dan
## verschijnt de knop INSTAPPEN. Bestuurd: linker stick = rijden (de jeep draait naar waar je duwt),
## rechter stick = het MG richten, tot de rand duwen = schieten. Aanrijden doet schade aan vijanden.
## Uit de garage rijdt hij zelf naar zijn plek (`goals`). Geparkeerd schiet de schutter niet; schieten doe je zelf als je in de jeep zit.
## Model: assets/jeep.glb (Blender), voorkant is -Z. Wielen, sturen en vering doet deze code; van de
## Blender-clips gebruiken we alleen Vuren (terugslag, vlam, hulzen, schutter).

const SPEED := 16.7         # m/s vooruit (60 km/u)
const REVERSE := 3.5        # m/s achteruit
const ACCEL := 8.0          # m/s² gas geven
const BRAKE := 9.0          # m/s² remmen
const WHEELBASE := 2.04     # m tussen voor- en achteras
const WHEEL_R := 0.37
const MAX_STEER := 0.5      # rad
const GUN_TURN := 3.0       # rad/s draaien van het MG als de schutter zelf richt
const GUN_TURN_DRIVEN := 7.0
const FIRE_RATE := 0.1      # s tussen kogels
const DAMAGE := 9.0
const BOARD_DIST := 4.5     # m: dichterbij dan dit toont de knop INSTAPPEN
const RAM_DAMAGE := 40.0

var driven := false
var goals: Array = []  # Vector3-punten waar hij zelf naartoe rijdt (uit de garage); leeg = geparkeerd
var _speed := 0.0
var _steer := 0.0
var _yaw_rate := 0.0
var _accel := 0.0
var _t := 0.0
var _cool := 0.0
var _ram_cd := 0.0
var _firing := false
var _night := false
var _head_mat: StandardMaterial3D
var _tail_mat: StandardMaterial3D
var _body_base: Transform3D
var _mg_base: Transform3D
var _lijf_base: Transform3D
var _btn: ActionBtn

@onready var _anim: AnimationPlayer = $Model/AnimationPlayer
@onready var _body: Node3D = $Model/Jeep/Body
@onready var _stuur := [$Model/Jeep/Body/StuurLV, $Model/Jeep/Body/StuurRV]
@onready var _wheels := [$Model/Jeep/Body/StuurLV/WielLV, $Model/Jeep/Body/StuurRV/WielRV, $Model/Jeep/Body/WielLA, $Model/Jeep/Body/WielRA]
@onready var _gun: Node3D = $Model/Jeep/Body/Geschut
@onready var _mg: Node3D = $Model/Jeep/Body/Geschut/MG
@onready var _lijf: Node3D = $Model/Jeep/Body/Geschut/Schutter/Bovenlijf
@onready var _monding: Node3D = $Model/Jeep/Body/Geschut/MG/Monding


func _ready() -> void:
	add_to_group("voertuigen")   # brandkranen spuiten als je erover rijdt
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_body_base = _body.transform
	_mg_base = _mg.transform
	_lijf_base = _lijf.transform
	_strip_fire_clip()
	_anim.stop()
	_rest_fire_parts()
	_setup_lights()
	_build_button()


## De Blender-clip Vuren keyt ook romp, wielen en geschut; die sporen halen we eruit zodat de code
## ze vrij kan bewegen terwijl het MG vuurt.
func _strip_fire_clip() -> void:
	var a := _anim.get_animation("Vuren")
	for i in range(a.get_track_count() - 1, -1, -1):
		var p := String(a.track_get_path(i))
		if not (p.contains("/MG") or p.contains("/Bovenlijf")):
			a.remove_track(i)


func _rest_fire_parts() -> void:
	$Model/Jeep/Body/Geschut/MG/Monding/Vlam.scale = Vector3.ONE * 0.001
	for h in ["Huls0", "Huls1", "Huls2"]:
		get_node("Model/Jeep/Body/Geschut/MG/" + h).scale = Vector3.ONE * 0.001
	_mg.transform = _mg_base
	_lijf.transform = _lijf_base


func _setup_lights() -> void:
	var romp: MeshInstance3D = $Model/Jeep/Body/RompMesh
	for i in romp.mesh.get_surface_count():
		var m := romp.mesh.surface_get_material(i)
		if m is StandardMaterial3D and (m.resource_name == "Koplamp" or m.resource_name == "Achterlicht"):
			var copy: StandardMaterial3D = m.duplicate()
			romp.set_surface_override_material(i, copy)
			if m.resource_name == "Koplamp":
				_head_mat = copy
			else:
				_tail_mat = copy
	_night = GameSettings.get_value("time") != "day"
	for n in ["KoplampL", "KoplampR"]:
		get_node("Model/Jeep/Body/" + n).visible = _night
	if _head_mat:
		_head_mat.emission_energy_multiplier = 6.0 if _night else 0.0


func _build_button() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_btn = ActionBtn.make("enter", "IN")
	_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_btn.offset_left = ActionBtn.slot_x(2)
	_btn.offset_right = ActionBtn.slot_x(2) + ActionBtn.SIZE.x
	_btn.offset_top = -126.0
	_btn.offset_bottom = -126.0 + ActionBtn.SIZE.y
	_btn.pressed.connect(_toggle)
	_btn.hide()
	layer.add_child(_btn)


func _toggle() -> void:
	var p = Game.player
	if p == null or p.dead:
		return
	if driven:
		driven = false
		p.driving = false
		p.visible = true
		var side := global_transform.basis.x
		p.global_position = global_position - side * 1.9
		p.global_position.y = 0.0
		p.collision_mask = p.get("_mask0")
		_btn.kind = "enter"
		_btn.set_caption("IN")
		_btn.queue_redraw()
	else:
		driven = true
		goals.clear()
		p.driving = true
		p.visible = false
		p.collision_mask = 0
		p.velocity = Vector3.ZERO
		_btn.kind = "exit"
		_btn.set_caption("UIT")
		_btn.queue_redraw()


func _physics_process(delta: float) -> void:
	_t += delta
	_ram_cd -= delta
	var p = Game.player
	var live: bool = Game.state == "play" or Game.state == "prep"
	if p != null and p.dead and driven:
		_toggle()
	if _btn:
		var near: bool = p != null and not p.dead and live and (driven or p.global_position.distance_to(global_position) < BOARD_DIST)
		_btn.visible = near
		_btn.dock(2)
	_drive(delta, live)
	_animate(delta)
	if driven and p != null:
		p.global_position = Vector3(global_position.x, 0.0, global_position.z)
		p.face = rotation.y + PI
		_aim_driven(delta, live)
		_ram()
	else:
		_aim_auto(delta)


func _drive(delta: float, live: bool) -> void:
	var want_speed := 0.0
	var want_steer := 0.0
	var pivot := 0.0
	var mv := Game.move
	collision_mask = 0 if not goals.is_empty() else 178
	if not driven and not goals.is_empty():
		# uit de garage naar zijn parkeerplek: sturen naar het volgende punt
		var to: Vector3 = goals[0] - global_position
		to.y = 0.0
		if to.length() < 1.3:
			goals.pop_front()
		else:
			var fwd := -global_transform.basis.z
			var alpha := atan2(fwd.cross(to).y, fwd.dot(to))
			want_steer = clampf(atan(2.0 * WHEELBASE * sin(alpha) / maxf(to.length(), 2.5)), -MAX_STEER, MAX_STEER)
			want_speed = clampf(to.length() * 0.8 + 0.8, 1.5, 4.5)
			if goals.size() == 1:
				want_speed = clampf(to.length() * 0.8, 0.8, 4.5)
	elif driven and live and mv.length() > 0.15:
		# de jeep draait naar de kant waar je de stick duwt; ligt die achter hem, dan rijdt hij achteruit
		var want := atan2(-mv.x, -mv.y)
		var diff := wrapf(want - rotation.y, -PI, PI)
		var reverse := absf(diff) > 2.3
		if reverse:
			diff = wrapf(diff - PI, -PI, PI)
		want_steer = clampf(diff * 1.6, -MAX_STEER, MAX_STEER) * (-1.0 if reverse else 1.0)
		var bend := 1.0 - 0.5 * minf(absf(diff) / 1.2, 1.0)
		pivot = diff
		want_speed = (-REVERSE if reverse else SPEED * bend) * minf(mv.length() * 1.3, 1.0)
	var old := _speed
	var braking := signf(want_speed) != signf(_speed) or absf(want_speed) < absf(_speed)
	_speed = move_toward(_speed, want_speed, (BRAKE if braking else ACCEL) * delta)
	_accel = lerpf(_accel, (_speed - old) / delta, delta * 4.0)
	_steer = move_toward(_steer, want_steer, 2.5 * delta)
	_yaw_rate = _speed * tan(_steer) / WHEELBASE
	# stilstaand of tegen een muur kan hij toch bijdraaien, anders loop je vast
	rotation.y += clampf(pivot, -1.0, 1.0) * 1.8 * clampf(1.0 - absf(_speed) / 2.5, 0.0, 1.0) * delta
	if absf(_speed) < 0.01:
		return
	rotation.y += _yaw_rate * delta
	velocity = -global_transform.basis.z * _speed
	move_and_slide()
	global_position.y = 0.0
	if get_slide_collision_count() > 0:
		_speed *= 0.6
	var flat := Vector2(global_position.x, global_position.z)
	var clamped := Data.clamp_world(flat)
	if clamped != flat:
		flat = clamped
		global_position = Vector3(flat.x, 0.0, flat.y)


func _animate(delta: float) -> void:
	for w in _wheels:
		w.rotation.x = wrapf(w.rotation.x - _speed * delta / WHEEL_R, -PI, PI)
	for s in _stuur:
		s.rotation.y = _steer
	# vering: wat hobbelen, neus omhoog bij gas, omlaag bij remmen, overhellen naar buiten in de bocht
	var amp := clampf(absf(_speed) / 6.0, 0.15, 1.0)
	var bounce := (0.012 * sin(_t * 9.0) + 0.006 * sin(_t * 15.7)) * amp
	var pitch := clampf(_accel * 0.01, -0.05, 0.05) + 0.004 * sin(_t * 7.3) * amp
	var roll := clampf(-_yaw_rate * _speed * 0.006, -0.07, 0.07)
	_body.transform = _body_base * Transform3D(Basis.from_euler(Vector3(pitch, 0, roll)), Vector3(0, bounce, 0))
	if _tail_mat:
		var brake_light: bool = _accel < -1.0 or (driven and absf(_speed) < 0.3 and Game.move.length() < 0.15)
		_tail_mat.emission_energy_multiplier = lerpf(_tail_mat.emission_energy_multiplier, 6.0 if brake_light else (3.0 if _night else 0.6), delta * 10.0)


## Rijdt hij op een vijand voor zijn neus, dan gaat die neer.
func _ram() -> void:
	if _speed < 3.0 or _ram_cd > 0.0:
		return
	for e in Game.enemies.duplicate():
		if not is_instance_valid(e):
			continue
		var lp := to_local(e.global_position)
		if absf(lp.x) < 1.2 and lp.z < 0.8 and lp.z > -2.9:
			_ram_cd = 0.2
			e.hit(RAM_DAMAGE, -global_transform.basis.z, true)


func _aim_driven(delta: float, live: bool) -> void:
	var local := 0.0
	if live and not is_nan(Game.aim):
		local = wrapf(atan2(-sin(Game.aim), -cos(Game.aim)) - rotation.y, -PI, PI)
	var d := wrapf(local - _gun.rotation.y, -PI, PI)
	_gun.rotation.y += clampf(d, -GUN_TURN_DRIVEN * delta, GUN_TURN_DRIVEN * delta)
	_cool -= delta
	var shoot: bool = live and Game.fire and absf(d) < 0.35
	if shoot and _cool <= 0.0:
		_cool = FIRE_RATE
		var fwd := -_gun.global_transform.basis.z
		_shoot(atan2(fwd.x, fwd.z) + randf_range(-0.05, 0.05))
	_set_firing(shoot)


## Geparkeerd of zonder bestuurder schiet de schutter niet: schieten doe je zelf vanuit de jeep.
func _aim_auto(delta: float) -> void:
	var d := wrapf(0.0 - _gun.rotation.y, -PI, PI)
	_gun.rotation.y += clampf(d, -GUN_TURN * delta, GUN_TURN * delta)
	_set_firing(false)


func _shoot(angle: float) -> void:
	var from := _monding.global_position
	Bullet.fire(get_parent(), from, angle, 90.0, DAMAGE, 0.45, true, true)
	Fx.muzzle(get_parent(), from)
	Fx.casing(get_parent(), from)
	Sfx.play("mg", 0.4, global_position)


func _set_firing(on: bool) -> void:
	if on == _firing:
		return
	_firing = on
	if on:
		_anim.play("Vuren", 0.05)
	else:
		_anim.stop()
		_rest_fire_parts()
