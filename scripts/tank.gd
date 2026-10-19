extends AnimatableBody3D
## Eigen tank die buiten de oostmuur heen en weer patrouilleert. De koepel draait naar de
## dichtstbijzijnde vijand. Model: assets/tank.glb (gemaakt in Blender), voorkant is -Z,
## met de delen Toren (draait om Y) en Loop (kantelt om X).

const SPEED := 3.2         # m/s rijden
const TURN := 0.7          # rad/s draaien op de plek
const TURRET_TURN := 1.3   # rad/s koepel
const SIGHT := 34.0        # m, vanaf hier volgt de koepel een vijand
const ROUTE := [Vector3(20.5, 0, 17.0), Vector3(20.5, 0, -17.0)]

var _next := 0
var _turning := false
var _t := 0.0
@onready var _toren: Node3D = $Model/Tank/Toren
@onready var _loop: Node3D = $Model/Tank/Toren/Loop
@onready var _romp: Node3D = $Model/Tank/RompMesh
@onready var _romp_y := _romp.position.y


func _physics_process(delta: float) -> void:
	_t += delta
	var goal: Vector3 = ROUTE[_next]
	var to := goal - global_position
	to.y = 0.0
	var want := atan2(-to.x, -to.z)
	var diff := wrapf(want - rotation.y, -PI, PI)
	if to.length() < 0.3:
		_next = (_next + 1) % ROUTE.size()
		_turning = true
	elif _turning:
		rotation.y += clampf(diff, -TURN * delta, TURN * delta)
		_turning = absf(diff) > 0.02
	else:
		rotation.y += clampf(diff, -TURN * delta, TURN * delta)
		global_position += to.normalized() * minf(SPEED * delta, to.length())
	# motor laat de romp een beetje trillen
	_romp.position.y = _romp_y + sin(_t * 31.0) * 0.012
	_aim(delta)


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
