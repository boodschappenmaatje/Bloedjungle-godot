extends CharacterBody3D
## Eigen tank, gekocht bij de garage. Kom je dichtbij, dan verschijnt INSTAPPEN: linker stick = rijden en draaien, rechter stick = koepel richten, tot de rand duwen = schieten. Hij rijdt de lijst `goals` af (uit de garage naar zijn plek) en blijft
## dan staan; de koepel draait naar de dichtstbijzijnde vijand. Model: assets/tank.glb (gemaakt in Blender), voorkant is -Z,
## met de delen Toren (draait om Y) en Loop (kantelt om X). De animaties uit Blender (Stationair,
## Rijden, Achteruit, Draaien, Schieten) laten wielen, rupsschakels en de vering bewegen.

const SPEED := 3.2         # m/s rijden
const TURN := 0.7          # rad/s draaien op de plek
const TURRET_TURN := 1.3   # rad/s koepel
const SIGHT := 34.0        # m, vanaf hier volgt de koepel een vijand
const SHELL_DAMAGE := 70.0   # schade van de granaat; zet op 0 voor alleen het effect
const SHELL_RADIUS := 3.2    # m
const RELOAD := 4.0          # s tussen twee schoten

var goals: Array = []  # Vector3-punten die hij afrijdt; leeg = blijft staan en bewaakt
var _reload := 2.0
var _turning := false
const ANIM_SPEED := 3.12   # m/s waarmee de rups in de clip Rijden loopt
var _clip := ""
const DRIVE_SPEED := 5.5   # m/s vooruit als jij bestuurt
const DRIVE_REVERSE := 2.5
const DRIVE_TURN := 1.5    # rad/s draaien als jij bestuurt
const DRIVE_TURRET := 2.4  # rad/s koepel als jij richt
const DRIVE_RELOAD := 1.6
const BOARD_DIST := 6.5
const RAM_DAMAGE := 60.0

var driven := false
var _speed := 0.0
var _btn: ActionBtn
var _ram_cd := 0.0
@onready var _toren: Node3D = $Model/Tank/Body/Toren
@onready var _loop: Node3D = $Model/Tank/Body/Toren/Loop
@onready var _anim: AnimationPlayer = $Model/AnimationPlayer


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
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
		p.global_position = global_position - global_transform.basis.x * 3.2
		p.global_position.y = 0.0
		p.collision_mask = p.get("_mask0")
		_btn.kind = "enter"
		_btn.set_caption("IN")
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
	_ram_cd -= delta
	var pl = Game.player
	var live: bool = Game.state == "play" or Game.state == "prep"
	if pl != null and pl.dead and driven:
		_toggle()
	_btn.visible = pl != null and not pl.dead and live and (driven or pl.global_position.distance_to(global_position) < BOARD_DIST)
	collision_mask = 0 if not goals.is_empty() else 50
	if driven:
		_drive_driven(delta, live)
		return
	_speed = 0.0
	if goals.is_empty():
		_turning = false
		_play("Stationair", 1.0)
		_aim(delta)
		return
	var goal: Vector3 = goals[0]
	var to := goal - global_position
	to.y = 0.0
	var want := atan2(-to.x, -to.z)
	var diff := wrapf(want - rotation.y, -PI, PI)
	if to.length() < 0.3:
		goals.pop_front()
		_turning = true
	elif _turning:
		rotation.y += clampf(diff, -TURN * delta, TURN * delta)
		_turning = absf(diff) > 0.02
		_play("Draaien", 1.0)
	else:
		rotation.y += clampf(diff, -TURN * delta, TURN * delta)
		global_position += to.normalized() * minf(SPEED * delta, to.length())
		_play("Rijden", SPEED / ANIM_SPEED)
	_aim(delta)


func _play(clip: String, speed: float) -> void:
	if clip != _clip:
		_clip = clip
		_anim.play(clip, 0.35)
	_anim.speed_scale = speed


func _aim(delta: float) -> void:
	var target = null
	var best := SIGHT
	for e in Game.enemies:
		var d: float = e.global_position.distance_to(global_position)
		if d < best:
			best = d
			target = e
	var local := 0.0
	var tilt := 0.03
	if target:
		var v: Vector3 = target.global_position - global_position
		local = wrapf(atan2(-v.x, -v.z) - rotation.y, -PI, PI)
		tilt = 0.0
	var d := wrapf(local - _toren.rotation.y, -PI, PI)
	_toren.rotation.y += clampf(d, -TURRET_TURN * delta, TURRET_TURN * delta)
	_loop.rotation.x = lerpf(_loop.rotation.x, tilt, delta * 2.0)
	_reload -= delta
	if target and _reload <= 0.0 and absf(d) < 0.12:
		_reload = RELOAD
		_shoot(target.global_position)


## Schiet een granaat: vuur uit de loop, een halve seconde later ontploft hij waar de vijand stond.
func _shoot(at: Vector3) -> void:
	var tip := _loop.global_position - _loop.global_transform.basis.z * 3.4
	Fx.muzzle(get_parent(), tip)
	Fx.dust(get_parent(), tip)
	var boom := Vector3(at.x, 0.0, at.z)
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		Fx.explosion(get_parent(), boom, 1.0)
		Woonhuis.blast_all(boom, 2.0, 140.0)  # kleiner dan de straal tegen vijanden: alleen de muur waar hij op mikt
		for e in Game.enemies.duplicate():
			if is_instance_valid(e) and e.global_position.distance_to(boom) < SHELL_RADIUS and SHELL_DAMAGE > 0.0:
				e.hit(SHELL_DAMAGE, (e.global_position - boom).normalized(), true))


## Door jou bestuurd: de linker stick geeft de richting (de tank draait op de plek en rijdt dan door,
## ligt de richting achter hem dan rijdt hij achteruit), de rechter stick richt de koepel.
func _drive_driven(delta: float, live: bool) -> void:
	var mv := Game.move
	var want_speed := 0.0
	var turning := false
	if live and mv.length() > 0.15:
		var want := atan2(-mv.x, -mv.y)
		var diff := wrapf(want - rotation.y, -PI, PI)
		var reverse := absf(diff) > 2.3
		if reverse:
			diff = wrapf(diff - PI, -PI, PI)
		rotation.y += clampf(diff, -DRIVE_TURN * delta, DRIVE_TURN * delta)
		turning = absf(diff) > 0.05
		var align := clampf(1.0 - absf(diff) / 0.9, 0.0, 1.0)
		want_speed = (-DRIVE_REVERSE if reverse else DRIVE_SPEED) * minf(mv.length() * 1.3, 1.0) * align
	_speed = move_toward(_speed, want_speed, 7.0 * delta)
	if absf(_speed) > 0.01:
		velocity = -global_transform.basis.z * _speed
		move_and_slide()
		global_position.y = 0.0
		if get_slide_collision_count() > 0:
			_speed *= 0.5
		var flat := Vector2(global_position.x, global_position.z)
		var clamped := Data.clamp_world(flat)
		if clamped != flat:
			flat = clamped
			global_position = Vector3(flat.x, 0.0, flat.y)
	if absf(_speed) > 0.3:
		_play("Rijden" if _speed > 0.0 else "Achteruit", absf(_speed) / ANIM_SPEED)
	elif turning:
		_play("Draaien", 1.0)
	else:
		_play("Stationair", 1.0)
	var p = Game.player
	p.global_position = Vector3(global_position.x, 0.0, global_position.z)
	p.face = rotation.y + PI
	# koepel
	var local := 0.0
	if live and not is_nan(Game.aim):
		local = wrapf(atan2(-sin(Game.aim), -cos(Game.aim)) - rotation.y, -PI, PI)
	var d := wrapf(local - _toren.rotation.y, -PI, PI)
	_toren.rotation.y += clampf(d, -DRIVE_TURRET * delta, DRIVE_TURRET * delta)
	_loop.rotation.x = lerpf(_loop.rotation.x, 0.0, delta * 2.0)
	_reload -= delta
	if live and Game.fire and _reload <= 0.0 and absf(d) < 0.15:
		_reload = DRIVE_RELOAD
		_shoot(_aim_point())
	_ram()


## Waar de granaat landt: bij de eerste vijand vlak voor de loop, anders 22 m verderop.
func _aim_point() -> Vector3:
	var fwd := -_loop.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var best := 22.0
	for e in Game.enemies:
		if not is_instance_valid(e):
			continue
		var v: Vector3 = e.global_position - global_position
		v.y = 0.0
		var dist := v.length()
		if dist > 3.0 and dist < best and absf(fwd.angle_to(v)) < 0.12:
			best = dist
	# staat er een muur of huis in de lijn van de loop, dan slaat de granaat daar in
	var from := _loop.global_position + Vector3(0, 0.3, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + fwd * best, Kit.LAYER_WALL | Kit.LAYER_BUNKER)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		var at: Vector3 = hit.position
		return Vector3(at.x, 0.0, at.z)
	return global_position + fwd * best


## Rijdt hij op een vijand voor zijn neus, dan gaat die neer.
func _ram() -> void:
	if _speed < 2.0 or _ram_cd > 0.0:
		return
	for e in Game.enemies.duplicate():
		if not is_instance_valid(e):
			continue
		var lp := to_local(e.global_position)
		if absf(lp.x) < 2.1 and lp.z < 0.8 and lp.z > -4.2:
			_ram_cd = 0.2
			e.hit(RAM_DAMAGE, -global_transform.basis.z, true)
