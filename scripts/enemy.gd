extends CharacterBody3D
## Vijandelijke soldaat. Loopt naar de speler als die dichtbij is, anders naar de bunker.
## Messen vallen van dichtbij aan, geweren en de MG schieten zodra ze vrij zicht hebben.
## Om de muur heen loopt hij via een hoek en een van de twee poorten (zie route.gd).
## Waarden uit 01-data.js en 18-enemies.js van de web-versie.

@onready var model: SoldierModel = $Model
@onready var shape: CollisionShape3D = $Shape

var type := "knife"
var t: Dictionary
var armor := "licht"   # pantser voor het steen-papier-schaar (Data.ARMOR_MULT): "licht" of "zwaar"
var hp := 45.0
var max_hp := 45.0
var face := 0.0
var fire_t := 1.0
var burst_n := 0
var _assault_ammo := 0
var _assault_reload_t := 0.0
var speed_mul := 1.0
var slow_t := 0.0  # prikkeldraad: zolang dit loopt is hij 60% trager
var wire_dmg := 0.0
var strafe := 1.0
var dead := false

# Gedrag in groepsverband (zie ook Game.alert en Game.next_slot):
# dekking zoeken als hij geraakt wordt, flankeren, terugtrekken met hulp van de buren en gespreid op de bunker aanvallen.
var slot := 0
var role := "assault"  # assault of flank
var mode := "attack"  # attack, cover of retreat
var mode_t := 0.0
var cover_cd := 3.0
var cover_pt := Vector3.ZERO
var hurt_t := 99.0
var alert_t := 0.0
var flank_left := 7.0
var retreated := false
var path: Array = []  # vaste aanvalsroute (aanval_routes.gd): deze punten eerst aflopen
var path_i := 0
var stun_t := 0.0  # geschrokken van een explosie: even stilstaan
var _shoot_pose_t := 0.0
var _shot_sequence := 0
var _range_marker: Node3D
var _health_fill: MeshInstance3D
var burn_t := 0.0          # > 0: staat in brand (napalm), rent wild rond en valt aan het eind dood
var _burn_fx: Node3D
var _burn_dir := Vector3.ZERO
var _burn_turn := 0.0


# Slimme vijandaanval (AanvalAI, keuzes 1A-10A): het groepsbrein geeft opdrachten, de soldaat voert ze uit met zijn eigen gedrag.
var ai_groep: Variant = null   # de groep (Dictionary in AanvalAI.groepen) of null
var ai_ploeg := 0              # ploeg 0 of 1 voor vuur en beweging
var ai_kant := ""              # N, O, Z of W: de kant van jouw kamp die hij aanvalt
var ai_hold: Variant = null    # Vector3: hier wachten (verzamelpunt, sprong, terugtrekken); null = gewoon naar het doel
var ai_vuur := false           # dekkingsvuur: ook buiten zijn gewone bereik schieten (tot AI_VUUR_R m)
var ai_snel := false           # oprukken of terugtrekken: rennen
var ai_order := ""             # "storm" of ""
var _ai_far_t := 0.0
var ai_doel: Node3D = null     # 4A: waar hij op schiet als jij niet dichtbij bent (null = het HK)
var _ai_wacht := false         # staat nu op zijn wachtplek (gehurkt)
const AI_VUUR_R := 34.0

var _stuck_t := 0.0  # hoe lang hij tegen iets aan loopt zonder vooruit te komen
var _detour_t := 0.0  # nog zo lang opzij omlopen
var _detour_side := 1.0


func setup(kind: String, wave: int) -> void:
	type = kind
	t = Data.ETYPES[kind]
	armor = String(t.get("armor", "licht"))
	max_hp = t.hp * (1.0 + (maxi(1, wave) - 1) * 0.11)
	hp = max_hp
	fire_t = randf_range(0.8, 1.8)
	_assault_ammo = int(Data.WEAPONS.get("garand", {}).get("mag", 8)) if kind == "assault" else 0
	_assault_reload_t = 0.0
	speed_mul = randf_range(0.9, 1.12)
	strafe = 1.0 if randf() < 0.5 else -1.0
	slot = Game.next_slot()
	if kind in ["rifle", "assault"] and slot % 3 == 1:
		role = "flank"


func _ready() -> void:
	model.setup(t.color, "" if type == "knife" else t.get("gun", type), "vijand:" + type)
	model.scale = Vector3.ONE * t.scale * Data.SOLDIER_SCALE
	(shape.shape as CapsuleShape3D).radius = t.r
	Game.enemies.append(self)
	_build_range_marker()


## Een kleine gezondheidsstreep boven verre vijanden, alleen wanneer ze in zicht zijn.
## Twee eenvoudige quads per vijand: geen tekst, extra viewport of lichtberekening.
func _build_range_marker() -> void:
	_range_marker = Node3D.new()
	_range_marker.name = "RangeMarker"
	_range_marker.position.y = 2.55 * t.scale * Data.SOLDIER_SCALE
	add_child(_range_marker)
	for is_fill in [false, true]:
		var quad := QuadMesh.new()
		quad.size = Vector2(1.05 if is_fill else 1.17, 0.075 if is_fill else 0.12)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.albedo_color = Color(0.94, 0.25, 0.16) if is_fill else Color(0.025, 0.03, 0.025, 0.88)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.no_depth_test = false
		quad.material = mat
		var mesh := MeshInstance3D.new()
		mesh.mesh = quad
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.position.z = 0.012 if is_fill else 0.0
		_range_marker.add_child(mesh)
		if is_fill:
			_health_fill = mesh


func _process(_delta: float) -> void:
	if _range_marker == null:
		return
	var player: Node3D = Game.player
	var distance := player.global_position.distance_to(global_position) if player != null and is_instance_valid(player) else INF
	var marker_mode := GameSettings.get_value("markeringen")
	var cam := get_viewport().get_camera_3d()
	var markers_on := marker_mode == "on" or (marker_mode == "tact" and cam != null and not bool(cam.get("combat_view")))
	_range_marker.visible = markers_on and not dead and distance >= 11.0 and distance <= 38.0 and not _far
	if _range_marker.visible:
		_health_fill.scale.x = clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)


func _physics_process(delta: float) -> void:
	slow_t -= delta
	_shoot_pose_t = maxf(0.0, _shoot_pose_t - delta)
	model.set_shoot_pose(_shoot_pose_t > 0.0, "mg42" if type == "heavy" else "garand", t.get("rate", 0.2))
	if dead or Game.state == "over":
		if not dead:
			model.play("stil")
		return
	if burn_t > 0.0:
		burn_t -= delta
		_burn_step(delta)
		if burn_t <= 0.0:
			_burn_die()
		return
	if stun_t > 0.0:
		stun_t -= delta
		velocity = Vector3.ZERO
		if stun_t <= 0.0:
			model.play("stil", 0.15)
		return
	if type == "assault" and _assault_reload_t > 0.0:
		_assault_reload_t = maxf(0.0, _assault_reload_t - delta)
		velocity = Vector3.ZERO
		if _assault_reload_t <= 0.0:
			_assault_ammo = int(Data.WEAPONS.get("garand", {}).get("mag", 8))
			model.play("stil", 0.12)
		else:
			if model.current != "herladen":
				model.play("herladen", 0.08)
		return
	var player = Game.player
	if _is_far(player):
		_far_step(delta)
		return
	_set_far(false)
	var melee: bool = t.get("melee", false)
	var range_: float = 0.0 if melee else t.range
	# doelwit: de speler als hij dichtbij genoeg is, anders de bunker
	var to_player := INF
	if player and not player.dead:
		to_player = _flat(player.global_position - global_position).length()
	hurt_t += delta
	alert_t -= delta
	mode_t -= delta
	cover_cd -= delta
	var at_player := to_player < (20.0 if melee else 16.0) + (10.0 if alert_t > 0.0 else 0.0)
	var tactical := not melee and type != "heavy"
	# raketwerpers gaan eerst achter een gebouw aan (rocketTower in 18-enemies.js)
	var rb: Variant = _rocket_target() if t.get("rocket", false) else null
	if melee and player and player.elev > 1.0:
		at_player = false  # een mes reikt niet tot op een toren
	_tgt_y = player.global_position.y if at_player else 0.0
	var goal: Vector3 = player.global_position if at_player else Game.base_pos
	var dist := to_player if at_player else _bunker_dist()
	if ai_doel != null and not is_instance_valid(ai_doel):
		ai_doel = null
	if not at_player and ai_doel != null and not (ai_doel == player and player.dead):
		goal = ai_doel.global_position
		goal.y = 0.0
		_tgt_y = 1.0 if ai_doel != player else player.global_position.y
		dist = _flat(goal - global_position).length() - 1.0
	if rb != null:
		at_player = false
		_tgt_y = 0.0
		goal = rb.at
		dist = _flat(rb.at - global_position).length() - 2.0
	# F2: een gebouw met jouw soldaten binnen bereik: hij schiet terug op het raam
	_aim_pt = null
	if not at_player and rb == null and not melee:
		var gz: Variant = Garnizoen.eigen_doel(global_position, range_)
		if gz != null:
			goal = (gz as Node3D).global_position
			goal.y = 0.0
			_aim_pt = (gz as Node3D).global_position
			_tgt_y = (_aim_pt as Vector3).y
			dist = _flat(goal - global_position).length()

	# vanaf hier: waar hij naartoe loopt (move_goal) kan anders zijn dan waarop hij mikt (goal)
	var move_goal := goal
	var flanking := false
	if at_player and role == "flank" and flank_left > 0.0 and to_player > 9.0 and mode == "attack":
		# om de speler heen lopen en van opzij aanvallen, in plaats van recht erop af
		var away := _flat(global_position - player.global_position).normalized()
		var side := Vector2(-away.y, away.x) * strafe
		move_goal = player.global_position + Vector3(side.x + away.x * 0.3, 0.0, side.y + away.y * 0.3) * 9.0
		flank_left -= delta
		flanking = true
	elif not at_player and rb == null and _route_goal() != null:
		move_goal = _route_goal()
	elif not at_player and rb == null and ai_hold != null:
		move_goal = ai_hold
	var hold := 1.0 if melee else 0.65 + 0.1 * float(slot % 4)  # schutters houden verschillende afstanden aan (gelaagd, niet in een kluitje)
	var cover_look := 0.0
	if tactical:
		if mode == "attack" and cover_cd <= 0.0 and hurt_t < 1.5 and hp < max_hp * 0.75 and (at_player or dist < range_ * 1.2):
			cover_cd = 6.0
			var c: Variant = _find_cover(goal)
			if c != null:
				mode = "cover"
				mode_t = randf_range(1.4, 2.4)
				cover_pt = c
		if mode == "attack" and not retreated and hp < max_hp * 0.3 and hurt_t < 3.0:
			retreated = true
			mode = "retreat"
			mode_t = 3.0
			Game.alert(global_position, 18.0, 6.0)  # de buren komen helpen
		if mode != "attack" and mode_t <= 0.0:
			mode = "attack"
		cover_look = _angle_to(goal)

	fire_t -= delta
	var want_move := true
	var look := face
	var aim_at: Vector3 = _aim_pt if _aim_pt != null else goal + Vector3.UP * 1.2
	if mode == "cover":
		var cd := _flat(cover_pt - global_position)
		want_move = cd.length() > 0.6
		look = cover_look
		move_goal = cover_pt
	elif mode == "retreat":
		want_move = false
		look = cover_look
	elif melee:
		if dist < t.r + 0.8:
			want_move = false
			look = _angle_to(goal)
			if fire_t <= 0.0:
				fire_t = t.rate
				model.play("steken", 0.08, 1.7)
				Sfx.play("knife", 1.0, global_position)
				Game.mark_attack(global_position)
				if at_player:
					if not BaseWallRules.blocks_blast(global_position, player.global_position):
						player.hit(t.dmg, Vector3(sin(look), 0, cos(look)), false)
				elif ai_doel != null:
					_ai_steek(ai_doel)   # 4A: het mes op wat hij uitkoos (soldaat, wacht, gebouw, truck)
				elif not BaseWallRules.blocks_blast(global_position, Game.base_pos):
					Game.damage_base(t.dmg)
	elif not flanking and dist < range_ * hold and (rb != null or _clear_shot(aim_at, not at_player)):
		want_move = false
		look = _angle_to(goal)
		if fire_t <= 0.0:
			_shoot(look)

	# AanvalAI: staat zijn doel (een soldaat van jou) pal voor hem, dan treft een kogel niet meer: kolfslag
	if not melee and not at_player and rb == null and ai_doel is Ally and fire_t <= 0.0 and _flat((ai_doel as Node3D).global_position - global_position).length() < 2.0:
		fire_t = t.rate
		Sfx.play("knife", 0.8, global_position)
		_ai_steek(ai_doel)

	# AanvalAI: op zijn wachtplek blijven (gehurkt); de ploeg met dekkingsvuur schiet ook op grotere afstand
	_ai_wacht = false
	if ai_hold != null and not at_player and rb == null and mode == "attack" and _route_goal() == null:
		if _flat((ai_hold as Vector3) - global_position).length() < 1.2:
			want_move = false
			_ai_wacht = true
			look = _angle_to(goal)
			if ai_vuur and not melee and fire_t <= 0.0 and dist < AI_VUUR_R and _clear_shot(aim_at, true):
				_shoot(look)

	# een dichte poort in de weg: erop slaan of schieten tot hij kapot is
	var gate: Variant = Game.gates.blocking(global_position, move_goal) if want_move and Game.gates else null
	if gate != null:
		want_move = false
		look = _angle_to(Game.gates.pos_of(gate))
		if fire_t <= 0.0 and t.get("rocket", false):
			_shoot_rocket(look, Game.gates.pos_of(gate))  # een raket tegen de poort
		elif fire_t <= 0.0:
			if type != "assault" or _consume_assault_round():
				fire_t = t.rate if melee else maxf(t.rate, 0.45)
				if melee:
					model.play("steken", 0.08, 1.7)
					Sfx.play("knife", 1.0, global_position)
				else:
					Sfx.play("ping", 0.8, global_position)
				Game.mark_attack(global_position)
				Game.gates.damage(Game.gates.list.find(gate), t.dmg, "melee" if melee else "bullet")
				if type == "assault" and _assault_ammo <= 0:
					_start_assault_reload()

	# MCV-start: een muur (of poort) van het kamp in de weg: erop slaan of schieten tot hij kapot is, net als bij de poort van het oude kamp
	var wall: Variant = _wall_ahead(move_goal, delta) if want_move else null
	if wall != null:
		want_move = false
		var wall_at: Vector3 = wall.at
		look = _angle_to(wall_at)
		if fire_t <= 0.0 and t.get("rocket", false):
			_shoot_rocket(look, wall_at)
		elif fire_t <= 0.0:
			if type != "assault" or _consume_assault_round():
				fire_t = t.rate if melee else maxf(t.rate, 0.45)
				if melee:
					model.play("steken", 0.08, 1.7)
					Sfx.play("knife", 1.0, global_position)
				else:
					Sfx.play("ping", 0.8, global_position)
				Game.mark_attack(global_position)
				Game.builds.damage(wall, t.dmg * (0.5 if melee else 0.25))
				if type == "assault" and _assault_ammo <= 0:
					_start_assault_reload()

	var vel := Vector3.ZERO
	if want_move:
		var wp := Route.waypoint(global_position, move_goal)
		var d := _flat(wp - global_position)
		if d.length() > 0.05:
			vel = Vector3(d.x, 0.0, d.y).normalized() * t.speed * speed_mul * (0.4 if slow_t > 0.0 else 1.0) * (1.25 if mode == "cover" else 1.0) * (1.35 if ai_snel else 1.0)
			look = atan2(d.x, d.y) if mode != "cover" else cover_look
	elif mode == "retreat":
		var away2 := _flat(global_position - goal).normalized()
		vel = Vector3(away2.x, 0.0, away2.y) * t.speed * speed_mul * 0.9
		look = cover_look  # terugtrekken met het gezicht naar de vijand
	elif not melee and mode == "attack" and dist < range_ * 0.6:
		# te dichtbij: zijwaarts uitwijken terwijl hij schiet
		vel = Vector3(cos(look), 0.0, -sin(look)) * strafe * t.speed * 0.4
	# een stam of rots recht in de weg: even opzij omlopen in plaats van ertegenaan duwen
	if _detour_t > 0.0:
		_detour_t -= delta
		vel = vel.rotated(Vector3.UP, _detour_side * 1.1)
	velocity = vel
	move_and_slide()
	if want_move and vel.length() > 0.5 and get_real_velocity().length() < vel.length() * 0.3:
		_stuck_t += delta
		if _stuck_t > 0.25 and _detour_t <= 0.0:
			_detour_t = 0.9
			_detour_side = 1.0 if randf() < 0.5 else -1.0
	else:
		_stuck_t = 0.0
	position.y = 0.0
	face += angle_difference(face, look) * minf(1.0, delta * 10.0)
	rotation.y = face
	_animate(vel.length(), want_move)


var _tgt_y := 0.0
var _aim_pt: Variant = null   # F2: het raam van een gebouw met jouw soldaten waar hij nu op schiet (null = jij of de basis)
var _far := false
var _far_acc := 0.0
var _far_n := 0


## Het volgende punt van de vaste aanvalsroute, of null als hij de route af heeft.
func _route_goal() -> Variant:
	while path_i < path.size():
		var p: Vector3 = path[path_i]
		if _flat(p - global_position).length() > 3.0:
			return p
		path_i += 1
	return null


## AanvalAI 4A: een messteek op zijn doel. Een soldaat of wacht verliest levenspunten (en sneuvelt zoals bij een M2-kogel), de rest krijgt een vijandelijke treffer.
func _ai_steek(doel: Node3D) -> void:
	if doel is Ally:
		var a: Ally = doel
		if a.onraakbaar():
			return
		a.hp -= t.dmg
		if a.hp <= 0.0:
			Game.allies.erase(a)
			a.queue_free()
			Game.changed.emit()
	elif doel.has_method("hit"):
		doel.hit(t.dmg, Vector3(sin(face), 0, cos(face)), false)


## Ver van de speler en ver van de basis: niemand ziet hem, dus hij rekent maar af en toe en loopt rechtstreeks.
func _is_far(player: Variant) -> bool:
	if player == null or player.dead or slow_t > 0.0:
		return false
	var d2: float = _flat(player.global_position - global_position).length_squared()
	var from_base := maxf(absf(global_position.x - Game.base_pos.x), absf(global_position.z - Game.base_pos.z))
	var lim := 55.0 if _far else 62.0  # kleine marge tegen heen en weer schakelen
	return d2 > lim * lim and from_base > 48.0


func _set_far(on: bool) -> void:
	if _far == on:
		return
	_far = on
	model.visible = not on
	model.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT


## Elke vierde natuurkundige stap: een stap richting het volgende punt van de route, zonder botsingen of animatie.
func _far_step(delta: float) -> void:
	_set_far(true)
	_far_acc += delta
	_far_n += 1
	if _far_n % 4 != 0:
		return
	var rg: Variant = _route_goal()
	if rg == null and ai_hold != null:
		if _flat((ai_hold as Vector3) - global_position).length() < 1.0:
			_far_acc = 0.0
			return   # wacht op zijn plek (verzamelpunt), ook als niemand kijkt
		rg = ai_hold
	elif rg == null and ai_doel != null and is_instance_valid(ai_doel):
		rg = ai_doel.global_position
	# AanvalAI: een soldaat van jou pal voor hem, ook als jij ver weg bent: hij slaat (anders was die soldaat onaantastbaar)
	if ai_doel is Ally and _flat((ai_doel as Node3D).global_position - global_position).length() < 2.5:
		_ai_far_t -= _far_acc
		if _ai_far_t <= 0.0:
			_ai_far_t = maxf(float(t.rate), 0.8)
			_ai_steek(ai_doel)
		_far_acc = 0.0
		return
	var wp := Route.waypoint(global_position, rg if rg != null else Game.base_pos)
	var d := _flat(wp - global_position)
	if d.length() > 0.05:
		var v: Vector2 = d.normalized() * float(t.speed) * speed_mul * _far_acc
		position += Vector3(v.x, 0.0, v.y)
		face = atan2(d.x, d.y)
		rotation.y = face
	position.y = 0.0
	_far_acc = 0.0


## Dichtstbijzijnde bouwwerk (geen muur of zandzak) of voertuig van jou (jeep, tank) binnen 26 m dat nog heel is en waar hij vrij zicht op heeft.
func _rocket_target() -> Variant:
	var best: Variant = null
	var bd := 26.0
	for v in VoertuigSchade.doelen():   # raketten zijn er juist voor pantser (V3, keuze 6A)
		var dv := _flat((v as Node3D).global_position - global_position).length()
		if dv < bd and _rocket_clear({"at": (v as Node3D).global_position, "node": v}):
			bd = dv
			best = {"at": (v as Node3D).global_position, "node": v}
	for b in Game.buildings:
		if b.down or Game.builds.is_piece(b.kind):
			continue
		var d := _flat(b.at - global_position).length()
		if d < bd and _rocket_clear(b):
			bd = d
			best = b
	return best


## Geen muur tussen hem en het gebouw (raketten gaan niet over de muur).
func _rocket_clear(b: Dictionary) -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.3, 0), Vector3(b.at.x, 1.3, b.at.z), Bullet.MASK_WALL)
	q.hit_from_inside = true
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	return r.is_empty() or r.collider == b.node


func _shoot(a: float) -> void:
	if t.get("rocket", false):
		_shoot_rocket(a)
		return
	if not _consume_assault_round():
		return
	var burst: int = t.get("burst", 0)
	if burst > 0:
		burst_n += 1
		fire_t = t.rate
		if burst_n >= burst:
			burst_n = 0
			fire_t = t.pause
	else:
		fire_t = t.rate
	var muzzle: Vector3 = model.muzzle_position()
	Game.mark_attack(global_position)
	var rise := 0.0
	if _aim_pt != null:
		var ad := _flat((_aim_pt as Vector3) - muzzle).length()
		rise = ((_aim_pt as Vector3).y - muzzle.y) / maxf(ad, 3.0)
	elif _tgt_y > 1.0 and Game.player:
		var dd := _flat(Game.player.global_position - muzzle).length()
		rise = (_tgt_y + 1.0 - muzzle.y) / maxf(dd, 3.0)
	var weapon_kind := "mg42" if type == "heavy" else "garand"
	_shot_sequence += 1
	var tracer_every := 1 if type == "heavy" else 2
	var tracer_weapon := weapon_kind if _shot_sequence % tracer_every == 0 else ""
	var kogel := Bullet.fire(get_parent(), muzzle, a + randf_range(-1.0, 1.0) * t.spread * _aim_mult(), Data.ENEMY_BULLET_SPEED, t.dmg, Data.ENEMY_BULLET_LIFE, false, false, 0, 0.0, 0.0, rise, tracer_weapon)
	if kogel != null and ai_doel != null and is_instance_valid(ai_doel) and ai_doel is Ally:
		kogel.src = "vijand"   # 4A: hij mikt op een soldaat van jou; zo raakt de kogel die ook (zoals een M2-kogel)
	model.shoot_recoil(weapon_kind)
	_shoot_pose_t = 0.24
	Fx.muzzle(get_parent(), muzzle, weapon_kind, a)
	var casing_every: int = int(Data.WEAPON_VISUALS[weapon_kind].get("casing_every", 1))
	if _shot_sequence % casing_every == 0 and Game.player and _flat(Game.player.global_position - global_position).length() < 30.0:
		var axes := model.casing_axes()
		Fx.casing(get_parent(), model.casing_position(), axes[0], axes[1])
	Sfx.play("ak" if type == "heavy" else "enemy", 1.0, global_position)
	if type == "assault" and _assault_ammo <= 0:
		_start_assault_reload()


func _consume_assault_round() -> bool:
	if type != "assault":
		return true
	if _assault_reload_t > 0.0:
		return false
	if _assault_ammo <= 0:
		_start_assault_reload()
		return false
	_assault_ammo -= 1
	return true


func _start_assault_reload() -> void:
	if type != "assault" or _assault_reload_t > 0.0:
		return
	var garand: Dictionary = Data.WEAPONS.get("garand", {})
	_assault_reload_t = float(garand.get("reload", 1.9))
	model.play("herladen", 0.08)


## Een trage raket die afgaat waar hij gemikt was (of tegen het eerste dat in de weg staat).
func _shoot_rocket(a: float, aim: Variant = null) -> void:
	fire_t = t.rate
	var muzzle: Vector3 = model.muzzle_position()
	Game.mark_attack(global_position)
	var rb: Variant = _rocket_target()
	var d := 20.0
	var dm: float = t.dmg
	if aim != null:
		d = _flat(aim - global_position).length()
	elif rb != null:
		d = _flat(rb.at - global_position).length()
	elif Game.player:
		d = _flat(Game.player.global_position - global_position).length()
		dm *= 0.7
	Bullet.fire_rocket(get_parent(), muzzle, a + randf_range(-1.0, 1.0) * t.spread, dm, minf(1.6, (d + 1.5) / 17.0))
	Sfx.play("rocket", 0.8, global_position)


## Vrij schootsveld: geen muur (of bunker, als hij op de speler mikt) ertussen.
func _clear_shot(target: Vector3, at_bunker: bool) -> bool:
	var from := global_position + Vector3.UP * 1.33
	if BaseWallRules.blocks_ground_fire(from, target):
		return false
	if AanvalFx.rook_blokkeert(from, target):
		return false   # rookgordijn: hij ziet zijn doel niet
	var mask := Bullet.MASK_WALL | (0 if at_bunker else Bullet.MASK_BUNKER)
	var q := PhysicsRayQueryParameters3D.create(from, target, mask)
	q.hit_from_inside = true
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return true
	# AanvalAI (4A): mikt hij op een gebouw of toren, dan is dat gebouw zelf geen blokkade
	var c: Object = r.collider
	return ai_doel != null and is_instance_valid(ai_doel) and c is Node and (c == ai_doel or ai_doel.is_ancestor_of(c) or (c as Node).is_ancestor_of(ai_doel))


## Een plek achter het dichtstbijzijnde gebouw (of zandzak, muur) vanaf waar de dreiging komt, binnen 14 m; null als er niets is.
func _find_cover(threat: Vector3) -> Variant:
	var best: Variant = null
	var bd := 14.0
	for b in Game.buildings:
		if b.down:
			continue
		var d := _flat(b.at - global_position).length()
		if d >= bd:
			continue
		var sz: Vector3 = Game.builds.DEFS[b.kind].size
		var out := _flat(b.at - threat).normalized()
		var pt: Vector3 = b.at + Vector3(out.x, 0.0, out.y) * (maxf(sz.x, sz.z) * 0.5 + 1.0)
		if _flat(pt - threat).length() < _flat(b.at - threat).length():
			continue  # dat zou voor het gebouw zijn
		bd = d
		best = pt
	return best


var _wall_t := 0.0
var _wall_cache: Variant = null


## Staat er een muurstuk of poort van het kamp vlak voor hem op weg naar zijn doel? (Een straal van 2,6 m, vijf keer per seconde.) Geeft het bouwstuk of null.
func _wall_ahead(goal: Vector3, delta: float) -> Variant:
	_wall_t -= delta
	if _wall_t > 0.0:
		return _wall_cache if _wall_cache != null and Game.buildings.has(_wall_cache) else null
	_wall_t = 0.2
	_wall_cache = null
	var dir := _flat(goal - global_position)
	if dir.length() < 0.5:
		return null
	dir = dir.normalized()
	var from := global_position + Vector3.UP
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(dir.x, 0.0, dir.y) * 2.6, Kit.LAYER_FORTIFICATION)
	var h := get_world_3d().direct_space_state.intersect_ray(q)
	if not h.is_empty() and h.collider is BuildingBody:
		var ref: Dictionary = (h.collider as BuildingBody).ref
		if not ref.is_empty() and Game.buildings.has(ref) and (ref.kind == "kampmuur" or ref.kind == "poort"):
			_wall_cache = ref
	return _wall_cache


func _bunker_dist() -> float:
	var p := global_position - Game.base_pos
	if Game.base_yaw != 0.0:
		p = Basis(Vector3.UP, -Game.base_yaw) * p   # het hoofdkwartier kan gedraaid staan
	return maxf(absf(p.x), absf(p.z)) - Data.BUNKER_HALF


func _angle_to(p: Vector3) -> float:
	return atan2(p.x - global_position.x, p.z - global_position.z)


static func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func _animate(spd: float, moving: bool) -> void:
	if type == "assault" and _assault_reload_t > 0.0:
		if model.current != "herladen":
			model.play("herladen", 0.08)
		return
	if model.current == "steken" and model.anim.is_playing():
		return
	if _ai_wacht and _shoot_pose_t <= 0.0 and model.anim != null and model.anim.has_animation("hurken_stil"):
		model.play("hurken_stil", 0.25)   # wachten op het verzamelpunt of achter dekking: gehurkt (echte Meshy-clip)
		return
	if type == "assault" and moving:
		var local_motion: Vector3 = global_transform.basis.inverse() * velocity
		if spd <= 3.5 and absf(local_motion.x) > absf(local_motion.z) * 1.25:
			model.play("Walk_Left_with_Gun" if local_motion.x < 0.0 else "Cautious_Crouch_Walk_Right_inplace", 0.2, spd / 2.4)
			return
		if local_motion.z < -absf(local_motion.x) * 1.25:
			model.play("achteruit", 0.2, spd / 2.4)
			return
	if spd < 0.3:
		model.play("schieten" if not moving and not t.get("melee", false) else "stil")
	elif type == "assault" and spd > 5.0:
		model.play("sprinten", 0.2, spd / 5.5)
	elif spd > 3.5:
		model.play("rennen", 0.2, spd / 6.0)
	else:
		model.play("lopen", 0.2, spd / 2.4)


func hit(dmg: float, dir: Vector3, from_player: bool) -> void:
	if not from_player or dead:
		return
	dmg *= Data.counter(Game.hit_class, armor)   # steen-papier-schaar: raketten tegen zwaar, sluipschutters tegen mensen
	hp -= dmg
	hurt_t = 0.0
	model.flash(Color(1.0, 0.38, 0.07))
	model.hit_reaction(dir, clampf(dmg / 55.0, 0.75, 1.7))
	Sfx.play("splat", 1.0, global_position)
	Fx.spark(get_parent(), global_position + Vector3.UP * 1.15, -dir)
	Fx.blood(get_parent(), global_position + Vector3.UP * 1.2, dir, 14, Color(0.18, 0.58, 0.07))
	if randf() < 0.5:
		Fx.ground_blood(get_parent(), global_position + dir * 0.6, 0.5)
	if hp <= 0.0:
		_die(dir)


func _aim_mult() -> float:
	var b: Dictionary = Progress.bonus()
	return b.enemySpread * (b.nightSpread if GameSettings.get_value("time") == "night" else 1.0)


## Napalm: hij vat vlam, rent secs seconden panisch rond en valt dan dood neer.
func ignite(secs := 5.0) -> void:
	if dead or burn_t > 0.0:
		return
	burn_t = secs
	stun_t = 0.0
	_burn_turn = 0.0
	_burn_fx = Fx.napalm_flame(self, Vector3(0.0, 0.05, 0.0), 1.7, 2.6)
	model.flash(Color(1.0, 0.45, 0.1))
	Sfx.play("hurt", 0.8, global_position)
	Game.alert(global_position, 14.0, 4.0)   # de buren schrikken van een brandende maat


func _burn_step(delta: float) -> void:
	_burn_turn -= delta
	if _burn_turn <= 0.0:
		_burn_turn = randf_range(0.4, 0.9)
		var a := randf() * TAU
		_burn_dir = Vector3(sin(a), 0.0, cos(a))
	velocity = _burn_dir * 5.8 * speed_mul
	move_and_slide()
	position.y = 0.0
	var flat := Data.clamp_world(Vector2(global_position.x, global_position.z))
	global_position = Vector3(flat.x, 0.0, flat.y)
	face += angle_difference(face, atan2(_burn_dir.x, _burn_dir.z)) * minf(1.0, delta * 8.0)
	rotation.y = face
	model.play("brand_rennen", 0.1)


func _burn_die() -> void:
	hp = 0.0
	velocity = Vector3.ZERO
	Game.hit_src = "lucht"   # een brandende vijand is geen bevestigde treffer van de speler
	_die(_burn_dir, "brand_val")
	Game.hit_src = "speler"
	if _burn_fx != null and is_instance_valid(_burn_fx):
		get_tree().create_timer(3.5).timeout.connect(func():
			if is_instance_valid(_burn_fx):
				_burn_fx.queue_free())


func _die(dir: Vector3, clip := "") -> void:
	dead = true
	Game.enemies.erase(self)
	Game.alert(global_position, 12.0, 5.0)  # de buren in de buurt zijn gewaarschuwd en zoeken de speler
	Game.kills += 1
	Sfx.play("thud", 1.0, global_position)
	Progress.stats.kills += 1
	if Progress.stats.kills % 25 == 0:
		Progress.save()
	Game.add_score(t.pts)   # geen geld meer voor kills (Generals-stap 4): geld komt uit voorraad
	collision_layer = 0
	collision_mask = 0
	Fx.blood(get_parent(), global_position + Vector3.UP, dir, 26)
	Fx.ground_blood(get_parent(), global_position + dir * 0.4, 1.7)
	if type == "heavy":
		Fx.explosion(get_parent(), global_position, 0.8)
	var blast: Dictionary = Game.blast_near(global_position)
	if clip != "":
		model.play(clip, 0.1)
	elif blast.is_empty():
		var flat := Vector3(dir.x, 0.0, dir.z).normalized()
		# VQ2: de ragdoll valt vanuit de pose van dat moment en krijgt de klap van de kogel mee; anders de gewone sterfanimatie
		var ragdoll := GameSettings.get_value("ragdoll") == "on" and SoldierRagdoll.start(model, flat * 0.8, flat * 3.2 + Vector3(0, 0.7, 0))
		if not ragdoll:
			model.play("dood1" if randf() < 0.5 else "dood2", 0.08)
	else:
		_fling(blast)
	get_tree().create_timer(8.0).timeout.connect(queue_free)


## Geschrokken van een explosie vlakbij: even bevriezen, daarna (schutters) achter het dichtstbijzijnde gebouw of muur duiken.
func flinch(from: Vector3) -> void:
	if dead or type == "heavy" or stun_t > 0.0:
		return
	stun_t = randf_range(0.45, 0.85)
	var d := _flat(global_position - from)
	if d.length() > 0.1:
		rotation.y = atan2(-d.x, -d.y)  # draait naar de knal
		face = rotation.y
	model.play("geraakt", 0.05, 1.8)
	if not t.get("melee", false) and cover_cd <= 0.0:
		var c: Variant = _find_cover(from)
		if c != null:
			mode = "cover"
			mode_t = stun_t + randf_range(1.2, 2.0)
			cover_pt = c
			cover_cd = 6.0


const FLING_AIR := 0.55  # seconden in de lucht; de animatie explosie_dood landt rond dat moment (frame 16 van 30 per s)
const FLING_SLIDE := 0.4


## Weggeslingerd door een ontploffing: hij vliegt met het gezicht naar de knal een boog weg van het midden, landt op zijn rug en glijdt uit.
## De animatie (Blender, bron/acties) doet de houding; hier loopt het mannetje zelf langs de boog.
func _fling(blast: Dictionary) -> void:
	var from: Vector2 = _flat(global_position - blast.at)
	if from.length() < 0.2:
		from = Vector2.from_angle(randf() * TAU)
	var d := from.normalized()
	var power := 1.0 - clampf(from.length() / float(blast.r), 0.0, 1.0)  # dichter bij de knal = verder weg
	var dist := 2.6 + 3.8 * power  # meter in de lucht
	var start := global_position
	var land := Vector2(start.x, start.z) + d * dist
	# niet door een muur of de bunker heen vliegen
	var q := PhysicsRayQueryParameters3D.create(start + Vector3.UP * 1.0, Vector3(land.x, 1.0, land.y), Bullet.MASK_WALL | Bullet.MASK_BUNKER)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty():
		var hit_pos: Vector3 = r.position
		land = Vector2(hit_pos.x, hit_pos.z) - d * 0.6
		dist = maxf(0.5, (land - Vector2(start.x, start.z)).length())
	rotation.y = atan2(-d.x, -d.y)  # kijkt naar de knal terwijl hij achteruit vliegt
	face = rotation.y
	model.play("explosie_dood", 0.05)
	var tw := create_tween()
	tw.tween_method(_fling_step.bind(start, d, dist), 0.0, FLING_AIR + FLING_SLIDE, FLING_AIR + FLING_SLIDE)


func _fling_step(t: float, start: Vector3, d: Vector2, dist: float) -> void:
	if not is_inside_tree():
		return
	var along: float
	var h := 0.0
	if t <= FLING_AIR:
		along = dist * 0.85 * (t / FLING_AIR)
		var u := t / FLING_AIR
		h = 4.0 * 0.68 * u * (1.0 - u)  # boog met een top van ~0,7 m
	else:
		var s := (t - FLING_AIR) / FLING_SLIDE
		along = dist * (0.85 + 0.15 * (1.0 - (1.0 - s) * (1.0 - s)))  # uitglijden, steeds trager
	global_position = Vector3(start.x + d.x * along, h, start.z + d.y * along)
