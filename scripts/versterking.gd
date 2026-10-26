class_name Versterking
extends Node3D
## Killstreak VERSTERKING: de legertruck rijdt hard het veld op, stopt bij de speler, de laadklep gaat open en vier soldaten springen
## eruit en blijven bij de speler. De truck rijdt direct daarna weg (zit de speler zelf in de truck, dan blijft hij staan).
## De soldaten (Ally met helper = true) tellen niet mee voor je streak (Game.hit_src = "soldaat" via hun kogels).

const TRUCK := preload("res://scenes/vrachtwagen.tscn")
const APPROACH := 46.0   # m waar de truck vandaan komt
const STOP_DIST := 6.5   # m van de speler waar hij stopt

var truck: Node = null
var crew: Array = []
var _state := "aanrijden"
var _t := 0.0
var _spawned := 0
var _stop := Vector3.ZERO
var _exit := Vector3.ZERO


func start(player_pos: Vector3) -> void:
	var toward := _clear_direction(player_pos)
	_stop = player_pos + toward * STOP_DIST
	_stop.y = 0.0
	var from := _stop + toward * APPROACH
	from = _in_world(from, _stop)
	_exit = from
	truck = TRUCK.instantiate()
	get_parent().add_child(truck)
	truck.global_position = Vector3(from.x, 0.0, from.z)
	truck.rotation.y = atan2(-(_stop.x - from.x), -(_stop.z - from.z))
	truck.start_convoy(_stop, 11.0)
	Game.banner.emit("VERSTERKING ONDERWEG", "Een truck met soldaten komt eraan", 2.0)
	Sfx.play("claxon", 0.6, from)


## Richting (van de speler af) waar de truck vandaan komt: bij voorkeur van achter de speler, over een vrij stuk grond.
func _clear_direction(p: Vector3) -> Vector3:
	var back: float = PI + (Game.player.face if Game.player else 0.0)
	var space := get_world_3d().direct_space_state
	for k in [0, 1, -1, 2, -2, 3, -3, 4]:
		var a: float = back + k * PI / 4.0
		var d := Vector3(sin(a), 0.0, cos(a))
		var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.2, p + d * APPROACH + Vector3.UP * 1.2, Bullet.MASK_WALL | Bullet.MASK_BUNKER)
		if space.intersect_ray(q).is_empty() and Data.clamp_world(Vector2(p.x + d.x * APPROACH, p.z + d.z * APPROACH)) == Vector2(p.x + d.x * APPROACH, p.z + d.z * APPROACH):
			return d
	return Vector3(sin(back), 0.0, cos(back))


## Zorgt dat het beginpunt binnen de wereld ligt: anders korter langs dezelfde lijn.
static func _in_world(from: Vector3, toward: Vector3) -> Vector3:
	var v := Vector2(from.x, from.z)
	var c := Data.clamp_world(v)
	if c == v:
		return from
	return Vector3(c.x, 0.0, c.y)


func _physics_process(delta: float) -> void:
	if truck == null or not is_instance_valid(truck):
		_cleanup()
		return
	_t += delta
	match _state:
		"aanrijden":
			if truck.goals.is_empty() and absf(truck._speed) < 0.25:
				_state = "lossen"
				_t = 0.0
				truck.open_for_unloading()
		"lossen":
			if _t > 0.9 and _spawned < Streak.TRUCK_SOLDIERS and fmod(_t - 0.9, 0.5) < delta:
				_drop_soldier()
			if _spawned >= Streak.TRUCK_SOLDIERS and _t > 0.9 + Streak.TRUCK_SOLDIERS * 0.5 + 0.6:
				# de soldaten blijven bij de speler (helper volgt hem altijd); de truck rijdt weg
				crew.clear()
				if truck.driven:
					queue_free()      # de speler zit zelf in de truck: hij blijft
					return
				_state = "wegrijden"
				_t = 0.0
				truck.start_convoy(_exit, 11.0)
		"wegrijden":
			if truck.goals.is_empty() or _t > 12.0:
				truck.queue_free()
				queue_free()


func _drop_soldier() -> void:
	_spawned += 1
	var a := Ally.new()
	get_parent().add_child(a)
	a.helper = true
	var at: Vector3 = truck.rear_point()
	a.global_position = Vector3(at.x, 0.0, at.z)
	a.face = truck.rotation.y
	a.setup(120.0, 24.0, Game.allies.size())
	Game.allies.append(a)
	crew.append(a)
	Sfx.play("thud", 0.4, at)


func _free_ally(a: Ally) -> void:
	Game.allies.erase(a)
	a.queue_free()


func _cleanup() -> void:
	for a in crew:
		if is_instance_valid(a):
			_free_ally(a)
	crew.clear()
	queue_free()


func _exit_tree() -> void:
	for a in crew:
		if is_instance_valid(a):
			Game.allies.erase(a)
			a.queue_free()
