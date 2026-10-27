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
var in_tank := false       # zit in de tank: alleen raketten (en tankgranaten) doen hem iets, kogels en messen niet
var driving := false         # zit in de jeep: dan rijdt jeep.gd en loopt hij niet zelf
var elev := 0.0              # hoogte: 0 op de grond, TOWER_TOP op een wachttoren
var tower: Node3D = null     # de toren waar hij op staat of die hij beklimt
var climb := -1.0            # voortgang op de trap (0 = onderaan, 1 = boven), -1 = niet aan het klimmen
var climb_dir := 1
var climb_cd := 0.0
var _mask0 := 0
# Sprint, ontwijkrol en granaten
var stamina := 1.0          # 0..1: sprint kost er per seconde van, een rol kost een stuk in één keer
var sprint_on := false      # aan/uit met de sprintknop; Shift houdt hem ingedrukt
var sprinting := false
var dodge_t := 0.0          # > 0 terwijl hij rolt
var dodge_cd := 0.0
var dodge_dir := Vector2.ZERO
var grenade_cd := 0.0
var _stam_wait := 0.0
var _exhausted := false     # leeg geraakt: pas weer sprinten als er wat bij is
var _reload_dur := 1.0      # hoe lang het lopende herladen duurt (de herlaadbeweging past zich daaraan aan)
var _dust_t := 0.0
var _shot_sequence := 0

const STAIR_FOOT := 1.8      # de klimladder staat aan de +X zijde van de toren (zie bron/wachttoren)
const STAIR_TOP := 1.3
const DECK := 5.3
const CLIMB_SPEED := 1.8
const SPRINT_MUL := 1.5
const SPRINT_DRAIN := 0.22   # per seconde
const STAM_REGEN := 0.32     # per seconde, na een korte pauze
const DODGE_TIME := 0.42
const DODGE_SPEED := 11.5
const DODGE_COST := 0.28
const DODGE_CD := 1.3
const DODGE_SAFE := 0.32     # zo lang van de rol raken kogels hem niet


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
		model.setup(Progress.item("camo").col, weapon, "speler:" + str(Progress.item("top").id))
	else:
		model.set_uniform(Progress.item("camo").col)
		model.set_top(str(Progress.item("top").id))
	model.set_band(Progress.item("band").color)
	hp = Game.max_hp()


func _physics_process(delta: float) -> void:
	if dead or Game.state == "shop" or Game.state == "menu":
		model.set_shoot_pose(false, weapon, Game.wstat(weapon).rate)
		return
	if driving:
		return
	if weapon != Game.cur:
		equip(Game.cur)
	var w: Dictionary = Game.wstat(weapon)
	var mv := Game.move
	var spd_mul: float = (1.0 + 0.07 * Game.upg.speed) * w.get("slow", 1.0) * Progress.bonus().speed
	climb_cd -= delta
	dodge_cd = maxf(0.0, dodge_cd - delta)
	grenade_cd = maxf(0.0, grenade_cd - delta)
	if climb >= 0.0:
		model.set_shoot_pose(false, weapon, w.rate)
		_climb_step(delta)
		return
	if dodge_t > 0.0:
		model.set_shoot_pose(false, weapon, w.rate)
		_dodge_step(delta)
		return
	# sprint: alleen lopend, niet tijdens schieten en niet op een toren; kost uithoudingsvermogen
	var want_sprint: bool = (sprint_on or Input.is_physical_key_pressed(KEY_SHIFT)) and mv.length() > 0.3 and not Game.fire and tower == null and not _exhausted
	sprinting = want_sprint and stamina > 0.0
	if sprinting:
		stamina = maxf(0.0, stamina - SPRINT_DRAIN * delta)
		_stam_wait = 0.7
		if stamina <= 0.0:
			_exhausted = true
			sprint_on = false
			sprinting = false
	else:
		_stam_wait -= delta
		if _stam_wait <= 0.0:
			stamina = minf(1.0, stamina + STAM_REGEN * delta)
		if _exhausted and stamina > 0.3:
			_exhausted = false
	velocity = Vector3(mv.x, 0.0, mv.y) * Data.PLAYER_SPEED * spd_mul * (SPRINT_MUL if sprinting else 1.0)
	move_and_slide()
	var flat := Vector2(position.x, position.z)
	var clamped := Data.clamp_world(flat)
	if clamped != flat:
		flat = clamped
		position = Vector3(flat.x, position.y, flat.y)
	if tower != null:
		_on_deck(mv)
	else:
		# in een huis: vloerhoogte volgens de trap en de verdieping; vallen gaat geleidelijk
		var hy := Woonhuis.floor_at(global_position, position.y)
		hy = maxf(hy, 0.0)
		position.y = hy if hy >= position.y else maxf(hy, position.y - 9.0 * delta)
		elev = position.y
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
	model.set_shoot_pose(Game.fire and reload_t <= 0.0, weapon, w.rate)
	_animate(mv, moving)


## Besturing van knoppen en toetsen: herladen, sprint, rol en granaat.
func _can_act() -> bool:
	return not dead and not driving and not airborne and (Game.state == "play" or Game.state == "prep") and not Game.build_mode


func request_reload() -> void:
	if _can_act() and climb < 0.0:
		_reload(Game.wstat(weapon))


func toggle_sprint() -> void:
	if _can_act():
		sprint_on = not sprint_on
		Sfx.play("click")


## Een snelle koprol in de looprichting (zonder stick: een stap achteruit). Kort onkwetsbaar, daarna even wachten.
func request_dodge() -> void:
	if not _can_act() or climb >= 0.0 or tower != null or dodge_t > 0.0 or dodge_cd > 0.0 or stamina < DODGE_COST:
		return
	var mv := Game.move
	dodge_dir = mv.normalized() if mv.length() > 0.2 else Vector2(-sin(face), -cos(face))
	dodge_t = DODGE_TIME
	dodge_cd = DODGE_CD
	stamina -= DODGE_COST
	_stam_wait = 0.9
	sprint_on = false
	rotation.y = atan2(dodge_dir.x, dodge_dir.y)
	face = rotation.y
	model.play("rollen", 0.04, maxf(0.5, model.clip_length("rollen")) / DODGE_TIME)  # de koprol komt uit bron/acties
	Fx.dust(get_parent(), global_position)
	Sfx.play("thud", 0.6)


func _dodge_step(delta: float) -> void:
	dodge_t = maxf(0.0, dodge_t - delta)
	var p := 1.0 - dodge_t / DODGE_TIME
	velocity = Vector3(dodge_dir.x, 0.0, dodge_dir.y) * DODGE_SPEED * (1.0 - 0.5 * p)
	move_and_slide()
	var flat := Vector2(position.x, position.z)
	var clamped := Data.clamp_world(flat)
	if clamped != flat:
		position = Vector3(clamped.x, position.y, clamped.y)
	position.y = 0.0
	model.play("rollen", 0.04, maxf(0.5, model.clip_length("rollen")) / DODGE_TIME)
	if dodge_t <= 0.0:
		model.position = Vector3.ZERO
		Fx.dust(get_parent(), global_position)


## Toets G / alleen tikken: op een computer naar de muiscursor, op de telefoon 7 m recht vooruit.
func throw_grenade() -> void:
	var target := global_position + Vector3(sin(face), 0.0, cos(face)) * Grenade.TAP_RANGE
	if not UI.is_touch_platform():
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			var mp := get_viewport().get_mouse_position()
			var hit = Plane(Vector3.UP, global_position.y).intersects_ray(cam.project_ray_origin(mp), cam.project_ray_normal(mp))
			if hit != null:
				target = hit
	throw_grenade_at(target)


func can_throw_grenade() -> bool:
	return _can_act() and climb < 0.0 and dodge_t <= 0.0 and grenade_cd <= 0.0 and Game.grenades > 0


## Waar het richten begint: de hand van de speler, en het doelpunt begrensd op bereik en gebouw.
func grenade_aim(target: Vector3) -> Dictionary:
	var home = Grenade.find_home(global_position, global_position)
	var t := Grenade.clamp_target(global_position, target, home)
	var d := Vector3(t.x - global_position.x, 0.0, t.z - global_position.z).normalized()
	return {"from": global_position + d * 0.5 + Vector3.UP * (1.6 + elev), "target": t}


## Gooit naar een punt op de grond (richtcirkel van de granaatknop of de muis).
func throw_grenade_at(target: Vector3) -> void:
	if not can_throw_grenade():
		return
	Game.grenades -= 1
	grenade_cd = 0.5
	var a := grenade_aim(target)
	var t: Vector3 = a.target
	face = atan2(t.x - global_position.x, t.z - global_position.z)
	rotation.y = face
	Grenade.throw_at(get_parent(), a.from, t, global_position)
	Sfx.play("knife")
	Game.changed.emit()


func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_R:
				request_reload()
			KEY_SPACE:
				request_dodge()
			KEY_G:
				throw_grenade()


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
	_shot_sequence += 1
	model.shoot_recoil(weapon)
	var fwd := Vector3(sin(face), 0.0, cos(face))
	var muzzle: Vector3 = model.muzzle_position()
	var over := _hugging_wall(fwd)
	var profile: Dictionary = Data.WEAPON_VISUALS.get(weapon, Data.WEAPON_VISUALS["m1911"])
	var tracer_every: int = int(profile.get("trail_every", 1))
	var tracer_weapon := "bazooka" if weapon == "bazooka" else (weapon if tracer_every > 0 and (_shot_sequence - 1) % tracer_every == 0 else "")
	var camera_impulse := 0.0
	match weapon:
		"garand": camera_impulse = 0.012
		"trench": camera_impulse = 0.02
		"mg42": camera_impulse = 0.006 if _shot_sequence % 5 == 0 else 0.0
		"bazooka": camera_impulse = 0.035
	if camera_impulse > 0.0:
		var camera := get_parent().get_node_or_null("Camera")
		if camera and camera.has_method("combat_impulse"):
			camera.call("combat_impulse", camera_impulse)
	for i in w.pellets:
		var a: float = face + (randf() - 0.5) * w.spread * 2.0
		var projectile_visual := tracer_weapon if weapon != "trench" or i == 0 else ""
		Bullet.fire(get_parent(), muzzle, a, w.speed * randf_range(0.92, 1.05), w.dmg * Progress.bonus().dmg, w.life * randf_range(0.85, 1.1), true, over, w.pierce, w.get("explosive", 0.0), 0.28 if elev > 1.0 else 0.0, 0.0, projectile_visual)
	if weapon == "bazooka":
		Fx.rocket_launch(get_parent(), muzzle, face)
	else:
		Fx.muzzle(get_parent(), muzzle, weapon, face)
	var casing_every: int = int(profile.get("casing_every", 1))
	if casing_every > 0 and (_shot_sequence - 1) % casing_every == 0:
		var axes := model.casing_axes()
		Fx.casing(get_parent(), model.casing_position(), axes[0], axes[1])
	Sfx.play(Data.WEAPON_SND[weapon])
	Game.changed.emit()
	if ammo <= 0:
		_reload(w)


## Wapenwissel: het magazijn van het oude wapen blijft bewaard.
func equip(id: String) -> void:
	if not Game.owned.has(id) or not Game.carries(id):
		return
	if Game.owned.has(weapon):
		Game.owned[weapon].ammo = ammo
	weapon = id
	Game.cur = id
	model.set_gun(id)
	ammo = Game.owned[id].ammo
	_shot_sequence = 0
	reload_t = 0.0
	fire_t = 0.3
	Game.changed.emit()


func _reload(w: Dictionary) -> void:
	if reload_t > 0.0 or ammo >= w.mag:
		return
	reload_t = w.reload * Progress.bonus().reload
	_reload_dur = maxf(reload_t, 0.1)
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
	var run_mul := SPRINT_MUL if sprinting else 1.0
	if reload_t > 0.0 and moving < 0.15:
		# de herlaadbeweging duurt precies zolang als het herladen van dit wapen
		model.play("herladen", 0.12, maxf(0.5, model.clip_length("herladen")) / _reload_dur)
	elif moving < 0.15:
		model.play("stil")
	else:
		# achteruit lopen als hij de andere kant op kijkt dan hij loopt
		var back := cos(atan2(mv.x, mv.y) - face) < -0.3
		var spd := moving * Data.PLAYER_SPEED * run_mul
		if back:
			model.play("achteruit", 0.2, spd / 2.0)
		elif sprinting and model.anim.has_animation("sprinten"):
			model.play("sprinten", 0.15, clampf(spd / (Data.PLAYER_SPEED * SPRINT_MUL), 0.7, 1.3))
			_dust_t -= get_physics_process_delta_time()
			if _dust_t <= 0.0:
				_dust_t = 0.22
				Fx.dust(get_parent(), global_position + Vector3(0, 0.05, 0))  # stofwolkjes bij elke stap
		elif spd > 4.0:
			model.play("rennen", 0.2, spd / 6.0)
		else:
			model.play("lopen", 0.2, spd / 2.4)


func hit(dmg: float, dir: Vector3, from_player: bool, heavy := false) -> void:
	if from_player or dead or airborne or Game.state == "over":
		return
	if in_tank:
		if not heavy:
			Fx.spark(get_parent(), global_position + Vector3.UP * 1.2, dir)  # kogels en messen ketsen af op het pantser
			return
		dmg *= 0.5  # pantser
	if dodge_t > DODGE_TIME - DODGE_SAFE:
		return  # midden in de rol
	var cover := 0.45 if Game.defs and Game.defs.in_trench(global_position) else 1.0  # in een loopgraaf mis je ruim de helft
	hp -= dmg * (1.0 - 0.08 * Game.upg.armor) * Progress.bonus().taken * cover
	model.flash()
	Sfx.play("hurt", 0.7)
	if in_tank:
		Fx.explosion(get_parent(), global_position + Vector3.UP * 0.5, 0.8)
	else:
		Fx.blood(get_parent(), global_position + Vector3.UP * 1.3, dir, 8)
	Game.changed.emit()
	if hp <= 0.0:
		hp = 0.0
		dead = true
		if in_tank:
			Fx.explosion(get_parent(), global_position + Vector3.UP * 0.5, 1.8)  # de tank wordt opgeblazen
		model.play("dood1", 0.1)
		Game.end_game("Je bent gesneuveld in golf %d" % Game.wave)
