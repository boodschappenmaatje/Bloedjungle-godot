extends CharacterBody3D
## De speler: linker stick lopen, rechter stick richten (half duwen) en schieten (tot de rand).
## Waarden uit 21-player.js en 15-combat.js van de web-versie.

@onready var model: SoldierModel = $Model

var hp := Game.max_hp()
var face := PI       # waar hij naartoe kijkt (0 = zuid, naar de camera toe)
var weapon := "m1911"  # het uitgeruste wapen (Game.cur)
var ammo := 0
var fire_t := 0.0
var _last_shot_ms := -100000   # Wapeneffecten AAA: rookje uit de loop bij herladen, kort na het schieten
var reload_t := 0.0
var idle_t := 0.0
var dead := false
var respawn_t := 0.0         # > 0 terwijl je dood bent en wacht om terug te komen
var shield_t := 0.0          # korte onkwetsbaarheid direct na terugkomen
var home := Vector3(0, 0, 4)  # terugkomplek bij de bunker (startplek in de basis)
const RESPAWN_TIME := 8.0
const RESPAWN_SHIELD := 2.5
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
var stance := 0             # 0 staan, 1 hurken, 2 liggen: alleen met de Meshy-speler (instelling Soldaat = meshy)
var _stam_wait := 0.0
var _lock: Node3D = null    # v234 (1A): vijand waarop het richten blijft kleven
var _cover_t := 0.0         # v234 (3A): hoe lang hij stilstaat tegen lage dekking
var _cover_auto := false    # de hurkhouding komt van de dekking, niet van de houdingknop
var _cover_off_t := 0.0
var _exhausted := false     # leeg geraakt: pas weer sprinten als er wat bij is
var _reload_dur := 1.0      # hoe lang het lopende herladen duurt (de herlaadbeweging past zich daaraan aan)
var _reload_elapsed := 0.0
var _reload_phase := 0
var _reload_was_empty := false
var _dust_t := 0.0
var _shot_sequence := 0
var _fire_was_down := false
var _infantry_preview_t := 0.0
const INFANTRY_PREVIEW_INTERVAL := 0.085  # ~12 world-space aim rays/sec, no extra rays for other units
const M1911_ASSIST_MIN_INTERVAL := 0.5
const M1911_EMPTY_RELOAD_IDLE := 0.55  # brief slide-lock pause, not 1.4 seconds of stalled audio
var _m1911_empty_click_latched := false
var m1911_mag_rounds := 0
var m1911_chambered := false

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
const STANCE_SPEED := [1.0, 0.5, 0.25]   # loopsnelheid per houding
const STANCE_HEIGHT := [2.15, 1.4, 0.7]  # capsulehoogte per houding: liggend vliegen kogels over je heen
const STANCE_RADIUS := [0.45, 0.45, 0.35]
const DODGE_SAFE := 0.32     # zo lang van de rol raken kogels hem niet


func _ready() -> void:
	Game.player = self
	home = global_position
	refresh_look()
	model.scale = Vector3.ONE * Data.SOLDIER_SCALE
	weapon = Game.cur
	model.set_gun(weapon)
	ammo = Game.owned[weapon].ammo
	if weapon == "m1911":
		var stored: Dictionary = Game.owned[weapon]
		if stored.has("mag_rounds") and stored.has("chambered"):
			m1911_mag_rounds = clampi(int(stored.mag_rounds), 0, 7)
			m1911_chambered = bool(stored.chambered)
		else:
			var legacy_total: int = clampi(ammo, 0, 8)
			m1911_chambered = legacy_total > 0
			m1911_mag_rounds = maxi(0, legacy_total - 1)
		_sync_m1911_ammo()
	rotation.y = face
	_mask0 = collision_mask
	$Shape.shape = ($Shape.shape as CapsuleShape3D).duplicate()   # de scène deelt de capsule; houdingen passen hem per speler aan


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
	shield_t = maxf(0.0, shield_t - delta)
	if dead and respawn_t > 0.0 and Game.state != "over":
		respawn_t -= delta
		if respawn_t <= 0.0:
			respawn()
	if dead or Game.state == "shop" or Game.state == "menu":
		_clear_infantry_preview()
		model.set_shoot_pose(false, weapon, Game.wstat(weapon).rate)
		return
	if driving:
		_clear_infantry_preview()
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
		_clear_infantry_preview()
		model.set_shoot_pose(false, weapon, w.rate)
		_climb_step(delta)
		return
	if dodge_t > 0.0:
		_clear_infantry_preview()
		model.set_shoot_pose(false, weapon, w.rate)
		_dodge_step(delta)
		return
	# sprint: alleen lopend, niet tijdens schieten en niet op een toren; kost uithoudingsvermogen
	var want_sprint: bool = stance == 0 and (sprint_on or Input.is_physical_key_pressed(KEY_SHIFT)) and mv.length() > 0.3 and not Game.fire and tower == null and not _exhausted
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
	velocity = Vector3(mv.x, 0.0, mv.y) * Data.PLAYER_SPEED * spd_mul * (SPRINT_MUL if sprinting else 1.0) * STANCE_SPEED[stance]
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
	var combat := get_tree().get_first_node_in_group("combat_buttons")
	var grenade_mode := combat != null and bool(combat.call("stick_armed"))   # granaat of kracht: de exacte stickrichting, geen richthulp naar vijanden
	if not is_nan(Game.aim):
		# Grenades use the EXACT stick direction; firearm aim assist may not
		# magnetize the throw preview to a nearby enemy.
		aim = Game.aim if grenade_mode else _aim_assist(Game.aim)
	elif moving > 0.15:
		aim = atan2(mv.x, mv.y)
	face += angle_difference(face, aim) * minf(1.0, delta * 18.0)
	rotation.y = face
	_update_cover(delta, moving)
	_update_infantry_preview(delta, w)

	fire_t -= delta
	if reload_t > 0.0:
		reload_t -= delta
		_reload_elapsed += delta
		if weapon == "m1911":
			_update_m1911_reload_events()
		if reload_t <= 0.0:
			if weapon == "m1911":
				_finish_m1911_reload()
			else:
				ammo = w.mag
			_reload_phase = 0
			model.gun_reset()
			Game.changed.emit()
	# Only a real right-stick hold in assisted mode can repeat a M1911 shot.
	# Mouse/keyboard and Manual mode remain trigger-edge semiautomatic.
	var assisted_touch := weapon == "m1911" and TouchSticks.m1911_touch_firing and GameSettings.get_value("m1911_fire_mode") == "assist"
	var trigger_pressed := Game.fire and (weapon != "m1911" or m1911_trigger_request(Game.fire, _fire_was_down, assisted_touch, fire_t <= 0.0))
	if not Game.fire:
		_m1911_empty_click_latched = false  # a new, deliberate press may dry-click once
	_fire_was_down = Game.fire
	var empty_magazine := weapon == "m1911" and m1911_is_empty(m1911_chambered, m1911_mag_rounds)
	if trigger_pressed and climb < 0.0:
		if not empty_magazine:
			idle_t = 0.0
		_shoot(w)
	# Repeated attempts against an empty pistol must NOT reset idle_t.
	# Otherwise a held assisted stick dry-clicks every 0.5s and blocks auto-reload forever.
	if (weapon == "m1911" and m1911_should_advance_idle(trigger_pressed, m1911_chambered, m1911_mag_rounds)) or (weapon != "m1911" and not trigger_pressed):
		idle_t += delta
	var idle_reload_delay := M1911_EMPTY_RELOAD_IDLE if weapon == "m1911" else 1.4
	if idle_t > idle_reload_delay and _should_auto_reload():
		_reload(w)
	if reload_t <= 0.0 and fire_t <= 0.0:
		model.ensure_weapon_idle()
	model.set_shoot_pose((Game.fire if weapon != "m1911" else trigger_pressed) and reload_t <= 0.0, weapon, w.rate)
	_animate(mv, moving)


## On-foot aiming uses the *actual current* body facing and the same muzzle,
## over-wall option and range as ordinary bullets. A preview never deals damage.
## Rocket/grenade arcs remain outside this straight-bullet pilot.
func _update_infantry_preview(delta: float, w: Dictionary) -> void:
	var hud := get_tree().get_first_node_in_group("combat_target_hud") as CombatTargetHud
	if hud == null:
		return
	var combat := get_tree().get_first_node_in_group("combat_buttons")
	if not _can_act() or Game.editing or is_nan(Game.aim) or (combat != null and bool(combat.call("stick_armed"))):
		_clear_infantry_preview()
		return
	_infantry_preview_t -= delta
	if _infantry_preview_t > 0.0:
		return
	_infantry_preview_t = INFANTRY_PREVIEW_INTERVAL
	var muzzle: Vector3 = model.muzzle_position()
	var facing := Vector3(sin(face), 0.0, cos(face))
	var over := _hugging_wall(facing)
	var distance := float(w.speed) * float(w.life)
	var result: Dictionary
	if weapon == "bazooka":
		# Do not draw a guaranteed blast at maximum lifetime: player rockets
		# do not explode on timeout. This preview never alters Bullet.fire().
		result = BazookaAimFeedback.predict(get_world_3d().direct_space_state, muzzle, face, distance, over, float(w.get("explosive", 0.0)))
	else:
		result = CombatAimFeedback.predict_infantry(get_world_3d().direct_space_state, muzzle, face, distance, over)
	hud.set_prediction(result, "infantry")


func _clear_infantry_preview() -> void:
	var hud := get_tree().get_first_node_in_group("combat_target_hud") as CombatTargetHud
	if hud != null:
		hud.clear_prediction("infantry")
	_infantry_preview_t = 0.0


## Besturing van knoppen en toetsen: herladen, sprint, rol en granaat.
func _can_act() -> bool:
	return not dead and not driving and not airborne and (Game.state == "play" or Game.state == "prep") and not Game.build_mode


func request_reload() -> void:
	if _can_act() and climb < 0.0:
		_reload(Game.wstat(weapon))


func toggle_sprint() -> void:
	if _can_act():
		if stance > 0:
			set_stance(0)   # sprinten kan alleen staand: eerst opstaan (lukt niet onder een laag dak)
			if stance > 0:
				return
		sprint_on = not sprint_on
		Sfx.play("click")


## Houdingknop: tik = staan > hurken > liggen > staan; lang indrukken = meteen liggen (of opstaan als je al laag zit).
func cycle_stance(long_press := false) -> void:
	if not _can_act() or not model.meshy_player or climb >= 0.0 or tower != null or dodge_t > 0.0:
		return
	var target := (stance + 1) % 3
	if long_press:
		target = 2 if stance == 0 else 0
	set_stance(target)
	Sfx.play("click")


## Zet de houding. Opstaan lukt alleen als er boven je ruimte is; anders blijf je in de hoogste houding waar het wel past.
func set_stance(target: int) -> void:
	if not model.meshy_player:
		return
	target = clampi(target, 0, 2)
	if target < stance:
		while target < 2 and not _has_room(target):
			target += 1
		if target >= stance:
			return
	stance = target
	model.set_stance(stance)
	var shape := $Shape as CollisionShape3D
	var cap := shape.shape as CapsuleShape3D
	cap.height = STANCE_HEIGHT[stance]
	cap.radius = STANCE_RADIUS[stance]
	shape.position.y = STANCE_HEIGHT[stance] * 0.5
	Game.changed.emit()


## Past de capsule van deze houding hier zonder iets te raken (muur, dak, andere lichamen)?
func _has_room(target: int) -> bool:
	var cap := CapsuleShape3D.new()
	cap.height = STANCE_HEIGHT[target]
	cap.radius = STANCE_RADIUS[target] - 0.05
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0.0, STANCE_HEIGHT[target] * 0.5 + 0.06, 0.0))
	q.collision_mask = _mask0
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## Een snelle koprol in de looprichting (zonder stick: een stap achteruit). Kort onkwetsbaar, daarna even wachten.
func request_dodge() -> void:
	if not _can_act() or climb >= 0.0 or tower != null or dodge_t > 0.0 or dodge_cd > 0.0 or stamina < DODGE_COST:
		return
	if stance > 0:
		set_stance(0)
		if stance > 0:
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


## Pure trigger rule, shared with headless regressions.
## assisted mode only repeats after the separate physical shot cooldown.
static func m1911_trigger_request(held: bool, was_held: bool, assisted: bool, ready: bool) -> bool:
	return held and (not was_held or (assisted and ready))


static func m1911_is_empty(chambered: bool, mag_rounds: int) -> bool:
	return not chambered and mag_rounds <= 0


static func m1911_should_advance_idle(trigger_requested: bool, chambered: bool, mag_rounds: int) -> bool:
	# A trigger held on an empty gun must not prevent the reload timer advancing.
	return not trigger_requested or m1911_is_empty(chambered, mag_rounds)


## Only one dry-click per intentional trigger hold; never loop a mechanical
## sound while the last-round slide is locked open.
func _m1911_empty_trigger_feedback() -> bool:
	if _m1911_empty_click_latched:
		return false
	_m1911_empty_click_latched = true
	_m1911_mechanical_event("dry_fire")
	model.play_weapon_action("leeg")
	return true


func _shoot(w: Dictionary) -> void:
	if reload_t > 0.0 or fire_t > 0.0:
		return
	if weapon == "m1911":
		# Never chamber a cartridge by pulling the trigger: a loaded magazine
		# with an empty chamber still requires operating the slide.
		if not m1911_chambered:
			_m1911_empty_trigger_feedback()
			return
	else:
		if ammo <= 0:
			_reload(w)
			return
	if weapon != "m1911" and ammo <= 0:
		_reload(w)
		return
	# At least half a second between distinct Colt shots, even after rate upgrades.
	fire_t = maxf(w.rate, M1911_ASSIST_MIN_INTERVAL) if weapon == "m1911" else w.rate
	if weapon == "m1911":
		_m1911_fire_chambered_round()
		_m1911_empty_click_latched = true  # do not dry-click again after last shot in same hold
	else:
		ammo -= 1
	_shot_sequence += 1
	model.shoot_recoil(weapon, ammo <= 0 and (weapon != "m1911" or m1911_mag_rounds <= 0))
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
		"m1911": camera_impulse = 0.0
		"mg42": camera_impulse = 0.006 if _shot_sequence % 5 == 0 else 0.0
		"bazooka": camera_impulse = 0.035
	var wfx_kick := WapenFx.kick(weapon)   # Wapeneffecten AAA: shotgun een zwaardere schok, pistool een lichte
	if wfx_kick > 0.0:
		camera_impulse = wfx_kick
	var wfx_fov := WapenFx.fov_punch(weapon)
	if wfx_fov > 0.0:
		var cam_fov := get_parent().get_node_or_null("Camera")
		if cam_fov and cam_fov.has_method("fov_punch"):
			cam_fov.call("fov_punch", wfx_fov)
	if camera_impulse > 0.0:
		var camera := get_parent().get_node_or_null("Camera")
		if camera and camera.has_method("combat_impulse"):
			camera.call("combat_impulse", camera_impulse)
	if weapon == "m47":
		# Eigen effect + zware ontploffing bij de inslag (M47Shot); geen gewone kogel.
		M47Shot.fire(get_parent(), muzzle, face, w.dmg * Progress.bonus().dmg, float(w.explosive))
	for i in 0 if weapon == "m47" else int(w.pellets):
		var a: float = face + (randf() - 0.5) * w.spread * 2.0
		var projectile_visual := tracer_weapon if weapon != "trench" or i == 0 or WapenFx.enabled("trench") else ""
		var projectile := Bullet.fire(get_parent(), muzzle, a, w.speed * randf_range(0.92, 1.05), w.dmg * Progress.bonus().dmg, w.life * randf_range(0.85, 1.1), true, over, w.pierce, w.get("explosive", 0.0), 0.28 if elev > 1.0 else 0.0, 0.0, projectile_visual)
		# Presentation-only source tag: actual HP loss remains the sole hit signal.
		# Explosive bazooka damage uses a separate path; do not claim bullet hits.
		if weapon != "bazooka":
			projectile.feedback_source = "infantry"
	if weapon == "m47":
		pass
	elif weapon == "bazooka":
		Fx.rocket_launch(get_parent(), muzzle, face)
	else:
		Fx.muzzle(get_parent(), muzzle, weapon, face)
	var casing_every: int = int(profile.get("casing_every", 1))
	if casing_every > 0 and (_shot_sequence - 1) % casing_every == 0:
		var axes := model.casing_axes()
		Fx.casing(get_parent(), model.casing_position(), axes[0], axes[1], weapon)
	WapenFx.shot_sound(weapon)
	WapenFx.haptic(weapon)
	_last_shot_ms = Time.get_ticks_msec()
	Game.changed.emit()
	# Keep the empty M1911 slide visible; the existing idle/manual reload
	# path may start the next reload later, but not in the firing frame.
	if ammo <= 0 and weapon != "m1911":
		_reload(w)


## Wapenwissel: het magazijn van het oude wapen blijft bewaard.
func equip(id: String) -> void:
	if not Game.owned.has(id) or not Game.carries(id):
		return
	if Game.owned.has(weapon):
		Game.owned[weapon].ammo = ammo
		if weapon == "m1911":
			_sync_m1911_ammo()
	weapon = id
	Game.cur = id
	model.set_gun(id)
	model.play_weapon_action("wisselen")
	ammo = Game.owned[id].ammo
	if id == "m1911":
		var stored: Dictionary = Game.owned[id]
		if stored.has("mag_rounds") and stored.has("chambered"):
			m1911_mag_rounds = clampi(int(stored.mag_rounds), 0, 7)
			m1911_chambered = bool(stored.chambered)
		else:
			var total: int = clampi(ammo, 0, 8)
			m1911_chambered = total > 0
			m1911_mag_rounds = maxi(0, total - 1)
		_sync_m1911_ammo()
	_shot_sequence = 0
	reload_t = 0.0
	_reload_elapsed = 0.0
	_reload_phase = 0
	_reload_was_empty = false
	_m1911_empty_click_latched = false
	fire_t = 0.3
	Game.changed.emit()


func _reload(w: Dictionary) -> void:
	if reload_t > 0.0 or (weapon == "m1911" and m1911_chambered and m1911_mag_rounds >= 7) or (weapon != "m1911" and ammo >= w.mag):
		return
	# A tactical reload is quick because a round remains chambered.
	# An empty reload also needs a slide release and takes slightly longer.
	var empty_m1911_reload := weapon == "m1911" and not m1911_chambered
	reload_t = w.reload * (1.2 if empty_m1911_reload else 1.0) * Progress.bonus().reload
	_reload_dur = maxf(reload_t, 0.1)
	_reload_elapsed = 0.0
	if weapon == "m1911":
		_reload_phase = 0
		_reload_was_empty = not m1911_chambered
	else:
		_reload_phase = 0
	model.play_weapon_action("herladen")
	if Time.get_ticks_msec() - _last_shot_ms < 3500:
		WapenFx.reload_wisp(get_parent(), model.muzzle_position(), weapon, face)
	if weapon == "m1911":
		_m1911_mechanical_event("reload_start")
	else:
		Sfx.play("reload")
	Game.changed.emit()


func _update_m1911_reload_events(force_mag_in := false) -> void:
	var progress := _reload_elapsed / maxf(_reload_dur, 0.01)
	if _reload_phase < 1 and progress >= 0.28:
		_reload_phase = 1
		_m1911_mechanical_event("mag_out")
	if _reload_phase < 2 and (progress >= 0.68 or force_mag_in):
		_reload_phase = 2
		m1911_mag_rounds = 7
		_sync_m1911_ammo()
		_m1911_mechanical_event("mag_in")
	if _reload_was_empty and _reload_phase < 3 and progress >= 0.92:
		_reload_phase = 3
		_m1911_mechanical_event("slide_release")


## Commit a completed reload atomically; no imaginary round may be chambered
## when the new magazine is empty. Exposed for the regression state matrix.
func _finish_m1911_reload() -> void:
	if _reload_phase < 2:
		_update_m1911_reload_events(true)
	if _reload_was_empty and not m1911_chambered and m1911_mag_rounds > 0:
		m1911_chambered = true
		m1911_mag_rounds -= 1
		if _reload_phase < 3:
			_m1911_mechanical_event("slide_release")
	_sync_m1911_ammo()
	_reload_phase = 0
	_reload_elapsed = 0.0
	_reload_was_empty = false


func _m1911_mechanical_event(event_name: String) -> void:
	# Temporary event tones use the existing procedural library. They are explicitly
	# not presented as independently recorded or historically verified sounds.
	var sounds := {"reload_start": "reload", "mag_out": "click", "mag_in": "reload", "slide_release": "click", "dry_fire": "click"}
	Sfx.play(sounds.get(event_name, "click"), 0.55)


## The only place a fired M1911 cartridge is consumed. Allows deterministic
## state tests without spawning bullets, audio or a complete level.
func _m1911_fire_chambered_round() -> bool:
	if not m1911_chambered:
		return false
	m1911_chambered = false
	if m1911_mag_rounds > 0:
		m1911_mag_rounds -= 1
		m1911_chambered = true
	_sync_m1911_ammo()
	return true


func _sync_m1911_ammo() -> void:
	if not Game.owned.has("m1911"):
		return
	ammo = m1911_mag_rounds + int(m1911_chambered)
	Game.owned.m1911.ammo = ammo
	Game.owned.m1911.mag_rounds = m1911_mag_rounds
	Game.owned.m1911.chambered = m1911_chambered


## Auto reload is different from a deliberate tactical reload. The old
## shared idle timer was reloading the M1911 after EVERY single shot because
## seven-round magazine capacity was checked even while the chamber was loaded.
func _should_auto_reload() -> bool:
	if weapon == "m1911":
		return not m1911_chambered and m1911_mag_rounds == 0 and can_reload()
	return can_reload()


func can_reload() -> bool:
	if reload_t > 0.0:
		return false
	return m1911_mag_rounds < 7 if weapon == "m1911" else ammo < int(Game.wstat(weapon).mag)


## Tegen de borstwering aan kun je eroverheen schieten (de vijand niet).
func _hugging_wall(fwd: Vector3) -> bool:
	var from := global_position + Vector3.UP
	var q := PhysicsRayQueryParameters3D.create(from, from + fwd * 1.6, Bullet.MASK_WALL)
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## v234 (1A): vergrendelen. Het richten kleeft aan de vijand die het dichtst bij je stickrichting staat (tot 26 m, binnen 30 graden).
## Hij blijft vergrendeld zolang je stick binnen 14 graden van hem blijft; duw je verder opzij, dan springt hij naar de volgende.
const LOCK_RANGE := 26.0
const LOCK_CONE := 0.52     # 30 graden: nieuwe vijand kiezen
const LOCK_KEEP := 0.25     # 14 graden: de huidige vijand houden
const LOCK_PULL := 0.9      # zo ver draait het richten naar de vijand toe


func _lock_angle(e: Node3D) -> float:
	var d := e.global_position - global_position
	return atan2(d.x, d.z)


func _lock_valid(e: Node3D) -> bool:
	if e == null or not is_instance_valid(e) or bool(e.get("dead")):
		return false
	var d := e.global_position - global_position
	return Vector2(d.x, d.z).length() <= LOCK_RANGE + 4.0


func _aim_assist(a: float) -> float:
	if _lock_valid(_lock) and absf(angle_difference(a, _lock_angle(_lock))) <= LOCK_KEEP:
		return a + angle_difference(a, _lock_angle(_lock)) * LOCK_PULL
	var best: Node3D = null
	var bd := LOCK_CONE
	for e: Node3D in Game.enemies:
		if not _lock_valid(e):
			continue
		var d := e.global_position - global_position
		var dist := Vector2(d.x, d.z).length()
		if dist > LOCK_RANGE:
			continue
		var diff := absf(angle_difference(a, atan2(d.x, d.z)))
		var score := diff + dist * 0.004   # bij gelijke hoek wint de dichtstbijzijnde
		if diff < LOCK_CONE and score < bd:
			bd = score
			best = e
	_lock = best
	if best == null:
		return a
	return a + angle_difference(a, _lock_angle(best)) * LOCK_PULL


## v234 (3A): automatisch in dekking. Sta je stil met je neus tegen lage dekking (kist, lage muur), dan zakt hij erachter in hurkhouding en
## staat hij weer op zodra je wegloopt, de houdingknop gebruikt of de dekking weg is. Alleen met de Meshy-soldaat (alleen die kent hurken).
func _low_cover_ahead() -> bool:
	var fwd := Vector3(sin(face), 0.0, cos(face))
	var space := get_world_3d().direct_space_state
	var low := global_position + Vector3.UP * 0.8
	var high := global_position + Vector3.UP * 2.3
	var hit_low := space.intersect_ray(PhysicsRayQueryParameters3D.create(low, low + fwd * 1.1, Bullet.MASK_WALL))
	if hit_low.is_empty():
		return false
	var hit_high := space.intersect_ray(PhysicsRayQueryParameters3D.create(high, high + fwd * 1.5, Bullet.MASK_WALL))
	return hit_high.is_empty()   # een muur die tot boven je hoofd reikt is geen dekking maar een muur


func _update_cover(delta: float, moving: float) -> void:
	if not model.meshy_player or tower != null or climb >= 0.0:
		_cover_auto = false
		return
	if _cover_auto and stance != 1:
		_cover_auto = false   # houdingknop gebruikt: jij beslist
	if _cover_auto:
		_cover_off_t = _cover_off_t + delta if (moving > 0.3 or not _low_cover_ahead()) else 0.0
		if _cover_off_t > 0.25:
			_cover_auto = false
			_cover_off_t = 0.0
			set_stance(0)
		return
	if stance == 0 and moving < 0.25 and _low_cover_ahead():
		_cover_t += delta
		if _cover_t > 0.3:
			_cover_t = 0.0
			set_stance(1)
			if stance == 1:
				_cover_auto = true
				_cover_off_t = 0.0
	else:
		_cover_t = 0.0


var _back := false   # loopt achteruit (zie _animate)


func _animate(mv: Vector2, moving: float) -> void:
	var run_mul := SPRINT_MUL if sprinting else 1.0
	if stance > 0 and model.meshy_player:
		_animate_low(mv, moving)
		return
	if reload_t > 0.0 and moving < 0.15:
		# de herlaadbeweging duurt precies zolang als het herladen van dit wapen
		model.play("herladen", 0.12, maxf(0.5, model.clip_length("herladen")) / _reload_dur)
	elif moving < 0.15:
		model.play("stil")
	else:
		# de romp en het wapen kijken naar het richtpunt, de benen draaien naar de looprichting (zijwaarts, schuin, achteruit);
		# kijkt hij meer dan ~105 graden van de looprichting weg, dan loopt hij achteruit (met hysterese tegen heen-en-weer)
		var rel := angle_difference(face, atan2(mv.x, mv.y))
		_back = absf(rel) > (1.31 if _back else 1.83)
		var back := _back
		var spd := moving * Data.PLAYER_SPEED * run_mul
		var leg := rel - signf(rel) * PI if back else rel
		if back and model.v2:
			model.play("lopen", 0.2, -spd / 2.4)   # VQ2: de loopcyclus achterstevoren, wapen blijft in de aanslag
		elif back:
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
		if not sprinting:
			model.set_leg_yaw(leg)


## Hurkend of liggend: eigen clips voor stilstaan, lopen/kruipen en achteruit (de Meshy-clips, zie bron/meshy_speler_animaties).
func _animate_low(mv: Vector2, moving: float) -> void:
	var low := stance == 2
	if reload_t > 0.0 and moving < 0.15:
		model.play("liggen_stil" if low else "hurken_stil", 0.15)   # herladen zonder eigen clip: de greep-IK beweegt de linkerhand
		return
	if moving < 0.15:
		model.play("liggen_stil" if low else "hurken_stil", 0.25)
		return
	var rel := angle_difference(face, atan2(mv.x, mv.y))
	_back = absf(rel) > (1.31 if _back else 1.83)
	var spd: float = moving * Data.PLAYER_SPEED * STANCE_SPEED[stance]
	if low:
		model.play("kruipen", 0.2, (1.0 if _back else -1.0) * clampf(spd / 0.9, 0.5, 2.0))   # vooruit = de achteruit-kruipclip omgekeerd
	else:
		model.play("hurken_achteruit" if _back else "hurken_lopen", 0.2, clampf(spd / 1.4, 0.5, 1.8))


func hit(dmg: float, dir: Vector3, from_player: bool, heavy := false) -> void:
	if from_player or dead or airborne or Game.state == "over":
		return
	if driving and VoertuigSchade.bestuurd != null:
		return   # in je jeep of tank vangt het voertuig de schade op (VoertuigSchade, stap V3)
	if in_tank:
		if not heavy:
			Fx.spark(get_parent(), global_position + Vector3.UP * 1.2, dir)  # kogels en messen ketsen af op het pantser
			return
		dmg *= 0.5  # pantser
	if dodge_t > DODGE_TIME - DODGE_SAFE or shield_t > 0.0:
		return  # midden in de rol, of net teruggekomen
	var cover := 0.45 if Game.defs and Game.defs.in_trench(global_position) else 1.0  # in een loopgraaf mis je ruim de helft
	hp -= dmg * (1.0 - 0.08 * Game.upg.armor) * Progress.bonus().taken * cover
	model.flash()
	model.flinch(dir, clampf(dmg / 25.0, 0.5, 1.4))   # romp en hoofd duwen mee met de kogel, zonder de schietpose te onderbreken
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
		# niet meer game over: na 8 s kom je terug bij de bunker; ondertussen mag je het bouwscherm gebruiken
		respawn_t = RESPAWN_TIME
		Sfx.play("thud", 0.8)
		Game.changed.emit()


## Het voertuig waar je in zat is vernield (stap V3, keuze 3B): je sneuvelt mee, zoals bij elke dood, en komt na 8 s terug bij de bunker.
func sneuvel() -> void:
	if dead:
		return
	hp = 0.0
	dead = true
	in_tank = false
	model.play("dood1", 0.1)
	respawn_t = RESPAWN_TIME
	Sfx.play("thud", 0.8)
	Game.changed.emit()


## Terugkomen na sneuvelen (Generals-plan 2d): vol leven, bij de bunker, even onkwetsbaar.
func respawn() -> void:
	dead = false
	respawn_t = 0.0
	hp = Game.max_hp()
	in_tank = false
	driving = false
	airborne = false
	visible = true
	collision_mask = _mask0
	velocity = Vector3.ZERO
	tower = null
	elev = 0.0
	climb = -1.0
	dodge_t = 0.0
	stance = 0
	global_position = home
	shield_t = RESPAWN_SHIELD
	# Teleporting home must reset camera smoothing; otherwise the view can
	# remain over the enemy camp while the soldier has already respawned.
	var camera := get_parent().get_node_or_null("Camera")
	if camera != null and camera.has_method("snap_to_player"):
		camera.call("snap_to_player")
	model.play("stil")
	get_tree().call_group("hq", "open_door")
	Game.banner.emit("JE BENT TERUG", "", 1.4)
	Game.changed.emit()
