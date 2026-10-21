extends AnimatableBody3D
## Eigen tank, gekocht bij de garage. Hij rijdt de lijst `goals` af (uit de garage naar zijn plek) en blijft
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
@onready var _toren: Node3D = $Model/Tank/Body/Toren
@onready var _loop: Node3D = $Model/Tank/Body/Toren/Loop
@onready var _anim: AnimationPlayer = $Model/AnimationPlayer


func _physics_process(delta: float) -> void:
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
		for e in Game.enemies.duplicate():
			if is_instance_valid(e) and e.global_position.distance_to(boom) < SHELL_RADIUS and SHELL_DAMAGE > 0.0:
				e.hit(SHELL_DAMAGE, (e.global_position - boom).normalized(), true))
