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
var airborne := false        # vliegt in de helikopter: onkwetsbaar voor kogels van beneden
var driving := false         # zit in de jeep: dan rijdt jeep.gd en loopt hij niet zelf
var elev := 0.0              # hoogte: 0 op de grond, TOWER_TOP op een wachttoren
var tower: Node3D = null     # de toren waar hij op staat of die hij beklimt
var climb := -1.0            # voortgang op de trap (0 = onderaan, 1 = boven), -1 = niet aan het klimmen
var climb_dir := 1
var climb_cd := 0.0
var _mask0 := 0

const STAIR_FOOT := 1.8      # de klimladder staat aan de +X zijde van de toren (zie bron/wachttoren)
const STAIR_TOP := 1.3
const DECK := 5.3
const CLIMB_SPEED := 1.8


func _ready() -> void:
	Game.player = self
	refresh_look()
	model.scale = Vector3.ONE * Data.SOLDIER_SCALE
	weapon = Game.cur
	model.set_gun(weapon)
	ammo = Game.owned[weapon].ammo
	rotation.y = face
	_mask0 = collision_mask


## Kleur en hoofdband volgens de gekozen uitrusting; ook gebruikt als je in het menu iets anders kiest.
func refresh_look() -> void:
	if model.anim == null:
		model.setup(Progress.item("camo").col, weapon)
	else:
		model.set_uniform(Progress.item("camo").col)
	model.set_band(Progress.item("band").color)
	hp = Game.max_hp()


func _physics_process(delta: float) -> void:
	if dead or Game.state == "shop" or Game.state == "menu":
		return
	if driving:
		return
	if weapon != Game.cur:
		equip(Game.cur)
	var w: Dictionary = Game.wstat(weapon)
	var mv := Game.move
	var spd_mul: float = (1.0 + 0.07 * Game.upg.speed) * w.get("slow", 1.0) * Progress.bonus().speed
	climb_cd -= delta
	if climb >= 0.0:
		_climb_step(delta)
		return
	velocity = Vector3(mv.x, 0.0, mv.y) * Data.PLAYER_SPEED * spd_mul
	move_and_slide()
	var flat := Vector2(position.x, position.z)
	var clamped := Data.clamp_world(flat)
	if clamped != flat:
		flat = clamped
		position = Vector3(flat.x, position.y, flat.y)
	if tower != null:
		_on_deck(mv)
	else:
		position.y = 0.0
		_find_stairs(mv)
	var sunk: bool = tower == null and Game.defs != null and Game.defs.in_trench(global_position)
	model.position.y = lerpf(model.position.y, -0.78 if sunk else 0.0, minf(1.0, delta * 8.0))

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
	if Game.fire and climb < 0.0:
		idle_t = 0.0
		_shoot(w)
	else:
		idle_t += delta
		if idle_t > 1.4 and ammo < w.mag:
			_reload(w)  # geen herlaadknop: na even niet schieten vult hij zelf bij
	_animate(mv, moving)


## Onderaan de trap van een toren omhoog lopen begint de klim.
func _find_stairs(mv: Vector2) -> void:
	if climb_cd > 0.0 or mv.length() < 0.3:
		return
	for t: Node3D in get_tree().get_nodes_in_group("tower"):
		var lp: Vector3 = t.to_local(global_position)
		var ld: Vector3 = t.global_transform.basis.inverse() * Vector3(mv.x, 0.0, mv.y)
		if lp.x > STAIR_FOOT - 0.3 and lp.x < STAIR_FOOT + 1.0 and absf(lp.z) < 0.55 and ld.x < -0.3:
			tower = t
			climb = 0.0
			climb_dir = 1
			collision_mask = 0
			_roof(t, false)
			return


## Het dak gaat weg als je erop staat, anders zie je jezelf niet.
func _roof(t: Node3D, vis: bool) -> void:
	for n in ["Toren_dak", "Toren_dakrib"]:
		var m := t.find_child(n, true, false)
		if m:
			m.visible = vis


## Op het platform: vrij lopen binnen de reling; door de opening bij de trap naar beneden.
func _on_deck(mv: Vector2) -> void:
	var lp: Vector3 = tower.to_local(global_position)
	var ld: Vector3 = tower.global_transform.basis.inverse() * Vector3(mv.x, 0.0, mv.y)
	lp.z = clampf(lp.z, -1.0, 1.0)
	var gap := absf(lp.z) < 0.5
	lp.x = clampf(lp.x, -1.0, 1.35 if gap else 1.0)
	if lp.x > 1.2 and gap and ld.x > 0.3 and climb_cd <= 0.0:
		climb = 1.0
		climb_dir = -1
	var g := tower.to_global(lp)
	global_position = Vector3(g.x, elev, g.z)


func _climb_step(delta: float) -> void:
	var len_ := Vector2(STAIR_FOOT - STAIR_TOP, DECK).length()
	climb = clampf(climb + climb_dir * CLIMB_SPEED * delta / len_, 0.0, 1.0)
	var lp := Vector3(lerpf(STAIR_FOOT, STAIR_TOP, climb), 0.0, 0.0)
	elev = DECK * climb
	var g := tower.to_global(lp)
	global_position = Vector3(g.x, elev, g.z)
	# altijd met het gezicht naar de ladder, ook naar beneden (dan loopt de animatie achteruit)
	var dw: Vector3 = tower.global_transform.basis * Vector3(-1.0, 0.0, 0.0)
	face = atan2(dw.x, dw.z)
	rotation.y = face
	model.position = Vector3(0.0, 0.0, -0.32)  # iets voor de ladder, zodat handen en voeten de sporten raken
	model.play("klimmen", 0.15, 2.0 * climb_dir)
	if climb_dir > 0 and climb >= 1.0:
		climb = -1.0
		model.position = Vector3.ZERO
		elev = DECK
		climb_cd = 0.5
		var l2: Vector3 = tower.to_local(global_position)
		l2.x = 1.0
		var g2 := tower.to_global(l2)
		global_position = Vector3(g2.x, elev, g2.z)
	elif climb_dir < 0 and climb <= 0.0:
		climb = -1.0
		model.position = Vector3.ZERO
		elev = 0.0
		climb_cd = 0.8
		collision_mask = _mask0
		_roof(tower, true)
		tower = null
		position.y = 0.0


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
		Bullet.fire(get_parent(), muzzle, a, w.speed * randf_range(0.92, 1.05), w.dmg * Progress.bonus().dmg, w.life * randf_range(0.85, 1.1), true, over, w.pierce, w.get("explosive", 0.0), 0.28 if elev > 1.0 else 0.0)
	Fx.muzzle(get_parent(), muzzle)
	Fx.casing(get_parent(), muzzle - Vector3(0, 0.15, 0))
	Sfx.play(Data.WEAPON_SND[weapon])
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
	model.set_gun(id)
	ammo = Game.owned[id].ammo
	reload_t = 0.0
	fire_t = 0.3
	Game.changed.emit()


func _reload(w: Dictionary) -> void:
	if reload_t > 0.0 or ammo >= w.mag:
		return
	reload_t = w.reload * Progress.bonus().reload
	Sfx.play("reload")
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
	if from_player or dead or airborne or Game.state == "over":
		return
	var cover := 0.45 if Game.defs and Game.defs.in_trench(global_position) else 1.0  # in een loopgraaf mis je ruim de helft
	hp -= dmg * (1.0 - 0.08 * Game.upg.armor) * Progress.bonus().taken * cover
	model.flash()
	Sfx.play("hurt", 0.7)
	Fx.blood(get_parent(), global_position + Vector3.UP * 1.3, dir, 8)
	Game.changed.emit()
	if hp <= 0.0:
		hp = 0.0
		dead = true
		model.play("dood1", 0.1)
		Game.end_game("Je bent gesneuveld in golf %d" % Game.wave)
