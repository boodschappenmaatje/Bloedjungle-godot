extends CharacterBody3D
## De speler: linker stick lopen, rechter stick richten (half duwen) en schieten (tot de rand).
## Waarden uit 21-player.js en 15-combat.js van de web-versie.

@onready var model: SoldierModel = $Model

var hp := Game.max_hp()
var face := PI       # waar hij naartoe kijkt (0 = zuid, naar de camera toe)
var weapon := "m1911"  # het uitgeruste wapen (Game.cur)
var ammo := 0
var fire_t := 0.0
var reload_t := 0.0
var idle_t := 0.0
var dead := false


func _ready() -> void:
	Game.player = self
	model.setup(Data.PLAYER_COLOR)
	model.scale = Vector3.ONE * Data.SOLDIER_SCALE
	weapon = Game.cur
	ammo = Game.owned[weapon].ammo
	rotation.y = face


func _physics_process(delta: float) -> void:
	if dead or Game.state == "shop":
		return
	if weapon != Game.cur:
		equip(Game.cur)
	var w: Dictionary = Game.wstat(weapon)
	var mv := Game.move
	var spd_mul: float = (1.0 + 0.07 * Game.upg.speed) * w.get("slow", 1.0)
	velocity = Vector3(mv.x, 0.0, mv.y) * Data.PLAYER_SPEED * spd_mul
	move_and_slide()
	var flat := Vector2(position.x, position.z)
	if flat.length() > Data.WORLD_R:
		flat = flat.limit_length(Data.WORLD_R)
		position = Vector3(flat.x, position.y, flat.y)
	position.y = 0.0

	var moving := mv.length()
	var aim := face
	if not is_nan(Game.aim):
		aim = _aim_assist(Game.aim)
	elif moving > 0.15:
		aim = atan2(mv.x, mv.y)
	face += angle_difference(face, aim) * minf(1.0, delta * 18.0)
	rotation.y = face

	fire_t -= delta
	if reload_t > 0.0:
		reload_t -= delta
		if reload_t <= 0.0:
			ammo = w.mag
			Game.changed.emit()
	if Game.fire:
		idle_t = 0.0
		_shoot(w)
	else:
		idle_t += delta
		if idle_t > 1.4 and ammo < w.mag:
			_reload(w)  # geen herlaadknop: na even niet schieten vult hij zelf bij
	_animate(mv, moving)


func _shoot(w: Dictionary) -> void:
	if reload_t > 0.0 or fire_t > 0.0:
		return
	if ammo <= 0:
		_reload(w)
		return
	fire_t = w.rate
	ammo -= 1
	var fwd := Vector3(sin(face), 0.0, cos(face))
	var muzzle := global_position + fwd * 0.6 + Vector3.UP * 1.33 * Data.SOLDIER_SCALE
	var over := _hugging_wall(fwd)
	for i in w.pellets:
		var a: float = face + (randf() - 0.5) * w.spread * 2.0
		Bullet.fire(get_parent(), muzzle, a, w.speed * randf_range(0.92, 1.05), w.dmg, w.life * randf_range(0.85, 1.1), true, over, w.pierce, w.get("explosive", 0.0))
	Fx.muzzle(get_parent(), muzzle)
	Game.changed.emit()
	if ammo <= 0:
		_reload(w)


## Wapenwissel: het magazijn van het oude wapen blijft bewaard.
func equip(id: String) -> void:
	if not Game.owned.has(id):
		return
	if Game.owned.has(weapon):
		Game.owned[weapon].ammo = ammo
	weapon = id
	Game.cur = id
	ammo = Game.owned[id].ammo
	reload_t = 0.0
	fire_t = 0.3
	Game.changed.emit()


func _reload(w: Dictionary) -> void:
	if reload_t > 0.0 or ammo >= w.mag:
		return
	reload_t = w.reload
	Game.changed.emit()


## Tegen de borstwering aan kun je eroverheen schieten (de vijand niet).
func _hugging_wall(fwd: Vector3) -> bool:
	var from := global_position + Vector3.UP
	var q := PhysicsRayQueryParameters3D.create(from, from + fwd * 1.6, Bullet.MASK_WALL)
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Trekt de richting iets naar een vijand binnen 20 m die er vlak naast staat (zoals aimAssist).
func _aim_assist(a: float) -> float:
	var best := NAN
	var bd := 0.2
	for e: Node3D in Game.enemies:
		var d := e.global_position - global_position
		if Vector2(d.x, d.z).length() > 20.0:
			continue
		var ea := atan2(d.x, d.z)
		var diff := absf(angle_difference(a, ea))
		if diff < bd:
			bd = diff
			best = ea
	return a if is_nan(best) else a + angle_difference(a, best) * 0.6


func _animate(mv: Vector2, moving: float) -> void:
	if reload_t > 0.0 and moving < 0.15:
		model.play("herladen")
	elif Game.fire and moving < 0.15:
		model.play("schieten", 0.1)
	elif moving < 0.15:
		model.play("stil")
	else:
		# achteruit lopen als hij de andere kant op kijkt dan hij loopt
		var back := cos(atan2(mv.x, mv.y) - face) < -0.3
		var spd := moving * Data.PLAYER_SPEED
		if back:
			model.play("achteruit", 0.2, spd / 2.0)
		elif spd > 4.0:
			model.play("rennen", 0.2, spd / 6.0)
		else:
			model.play("lopen", 0.2, spd / 2.4)


func hit(dmg: float, dir: Vector3, from_player: bool) -> void:
	if from_player or dead or Game.state == "over":
		return
	hp -= dmg * (1.0 - 0.08 * Game.upg.armor)
	model.flash()
	Fx.blood(get_parent(), global_position + Vector3.UP * 1.3, dir, 8)
	Game.changed.emit()
	if hp <= 0.0:
		hp = 0.0
		dead = true
		model.play("dood1", 0.1)
		Game.end_game("Je bent gesneuveld in golf %d" % Game.wave)
