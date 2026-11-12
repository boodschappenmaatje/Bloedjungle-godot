class_name VijandTank
extends CharacterBody3D
## De vijandelijke tank (Generals-plan stap V2, keuze G; Dennis' keuzes van 9 november 2026). Hij rijdt dezelfde weg als de vijandelijke jeep (AanvalRoutes.voertuig_pad: poort van
## de vijandbasis, door de stad, brug of ondiepte) maar belegert: zodra er binnen SIEGE_DIST een doel is (jouw soldaten, jij, muren, poorten, torens of het hoofdkwartier) stopt
## hij, draait de koepel en schiet elke RELOAD seconden een explosieve granaat. Rijdt verder zodra er niets meer binnen bereik is. Hij heeft geen MG, dus soldaten dichtbij
## kunnen hem omsingelen; raketsoldaten zijn zijn echte vijand (Data.ARMOR_MULT, pantser "tank": kogel 5%, scherpschutter 10%, raket 200%, explosie en brand 150%).
## Hij staat in Game.enemies en in de groep "vijand_voertuig", zodat jouw soldaten, torens, de Apache, granaten, napalm, de teller en de radar hem vanzelf zien.
## Op 0 levenspunten brandt hij uit als zwartgeblakerd wrak (koepel iets scheef) en verdwijnt na een halve minuut.
## Het model is Dennis' eigen tank (Meshy, bron/vijand_tank): VijandTank > Body > [RompMesh, RupsL, RupsR, WielL_*, WielR_*, Toren > [TorenMesh, Kanon > [KanonMesh, Monding]]].
## Alles wat ontbreekt wordt overgeslagen. Alle getallen zijn voorstellen om te testen.

const MODEL_PAD := "res://assets/vijand_tank.glb"
const HP := 900.0
const SPEED := 5.0          # m/s over de weg (jouw eigen tank rijdt 3,2 tot 5,5)
const REVERSE := 2.0
const ACCEL := 2.4
const BRAKE := 6.0
const MAX_YAW := 0.8        # rad/s: een tank draait op zijn plaats
const YAW_ACCEL := 1.8
const WHEEL_R := 0.362
const TRACK_HALF := 1.34    # m, halve afstand tussen de rupsen (snelheid per kant in een bocht)
const TRACK_LEN := 12.65    # m, lengte van de rupsbaan (de textuur loopt er één keer overheen)
const TURRET_TURN := 0.9    # rad/s koepel (jouw tank 1,3)
const SIEGE_DIST := 38.0    # m van het dichtstbijzijnde doel: hier stopt hij en schiet
const SHOT_RANGE := 45.0    # m: verder landt de granaat niet
const RELOAD := 6.0         # s tussen twee granaten (jouw tank 4,0)
const SHELL_DAMAGE := 70.0
const SHELL_RADIUS := 3.2
const SHELL_SPEED := 55.0   # m/s
const SCATTER := 0.9        # m: zo ver kan een granaat naast het doel vallen
const AIM_TOL := 0.07       # rad: zo recht moet de koepel staan voor hij schiet
const BUILD_MULT := 3.0     # tegen gebouwen driemaal zo hard als tegen een soldaat (zoals jouw tank)
const HQ_DAMAGE := 56.0     # levenspunten van het hoofdkwartier (1000) per granaat
const HQ_R := 5.0           # m: zo groot telt het hoofdkwartier als doel
const BURN_DPS := 40.0      # napalm: schade per seconde zolang hij brandt
const WAYPOINT_R := 3.0     # m: zo dichtbij telt een punt van de route als bereikt (een tank snijdt hoeken niet af: er staan palen en muren)
const WHISKER := 11.0       # m: zo ver kijkt hij vooruit naar muren en andere vaste dingen
const WHISKER_SIDE := 1.9   # m: de zijdelingse voelsprieten lopen langs de rupsen (halve breedte 1,7 m plus een handbreedte)
const WRECK_STAY := 30.0    # s dat het wrak blijft liggen
const BAR_W := 2.8
const POINTS := 300

var type := "tank"
var armor := "tank"
var t: Dictionary = {"hp": HP, "speed": SPEED, "r": 2.0, "scale": 1.0, "range": SHOT_RANGE, "dmg": SHELL_DAMAGE, "rate": RELOAD, "burst": 1, "pause": RELOAD, "pts": POINTS, "color": Color("5b6038")}
var hp := HP
var max_hp := HP
var dead := false
var alert_t := 0.0
var slow_t := 0.0
var wire_dmg := 0.0
var burn_t := 0.0
var route: Array = []
var route_i := 0
var cross_i := 0
var target: Dictionary = {}   # het doel van de koepel: {"kind", "pos", "node"/"ref"}
var holding := false          # staat stil: beleg of wachten voor de opgehaalde brug

var _speed := 0.0
var _yaw_rate := 0.0
var _time := 0.0
var _cool := 3.0
var _retarget_t := 0.0
var _sample_t := 0.0
var _sample_pos := Vector3.ZERO
var _stuck := 0
var _back_t := 0.0
var _back_dir := 1.0
var _wreck_t := 0.0
var _smoke: Node3D
var _fire: Node3D
var _burn_fx: Node3D
var _snd: AudioStreamPlayer3D
var _bar: Node3D
var _bar_fill: MeshInstance3D
var _anim: AnimationPlayer
var _body: Node3D
var _toren: Node3D
var _kanon: Node3D
var _monding: Node3D
var _wheels_l: Array = []
var _wheels_r: Array = []
var _rups: Array[StandardMaterial3D] = []
var _body_base := Transform3D.IDENTITY
var _crossing: Array = []
var _hit_wall_t := 0.0
var _shots_fired := 0
var _recoil_t := 0.0


## Maakt een vijandelijke tank die deze punten afrijdt. Voeg hem toe aan de wereld en zet hem op zijn plek.
static func make(pad: Array, wave := 1) -> VijandTank:
	var v := VijandTank.new()
	v.route = pad
	v.max_hp = HP * (1.0 + (maxi(1, wave) - 1) * 0.05)
	v.hp = v.max_hp
	return v


func _ready() -> void:
	add_to_group("vijand_voertuig")
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 8   # de laag van de vijand: kogels en raketten van jou en je soldaten raken hem
	collision_mask = Kit.LAYER_WALL | Kit.LAYER_BUNKER | Kit.LAYER_NATURE | Kit.LAYER_FORTIFICATION | 32 | 4   # muren, torens, bomen, jouw voertuigen en jij
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.4, 2.8, 5.8)   # een eenvoudige doos om de romp, zoals bij de jeep (het kanon steekt er 2 m voor uit en botst niet: een tank draait zo ruim door de straat)
	cs.shape = box
	cs.position = Vector3(0.0, 1.4, 0.0)
	add_child(cs)
	_build_model()
	_build_bar()
	_build_sound()
	Game.enemies.append(self)
	_sample_pos = global_position


func _exit_tree() -> void:
	Game.enemies.erase(self)


# ---------------------------------------------------------------- model

func _build_model() -> void:
	var model: Node3D = null
	if ResourceLoader.exists(MODEL_PAD):
		model = (load(MODEL_PAD) as PackedScene).instantiate() as Node3D
	if model == null:
		model = Node3D.new()
		Kit.box(model, Vector3(0.0, 1.0, 0.0), Vector3(3.4, 1.4, 6.4), Kit.flat(Color("5b6038")))
		Kit.box(model, Vector3(0.0, 2.0, 0.6), Vector3(2.2, 0.8, 2.6), Kit.flat(Color("5b6038")))
	model.name = "Model"
	add_child(model)
	_body = model.find_child("Body", true, false) as Node3D
	_toren = model.find_child("Toren", true, false) as Node3D
	_kanon = model.find_child("Kanon", true, false) as Node3D
	_monding = model.find_child("Monding", true, false) as Node3D
	for w in model.find_children("WielL_*", "Node3D", true, false):
		_wheels_l.append(w)
	for w in model.find_children("WielR_*", "Node3D", true, false):
		_wheels_r.append(w)
	for n in ["RupsL", "RupsR"]:
		var mi := model.find_child(n, true, false) as MeshInstance3D
		if mi != null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
			var base := mi.mesh.surface_get_material(0) as StandardMaterial3D
			if base != null:
				var own := base.duplicate() as StandardMaterial3D   # elke rups loopt in zijn eigen tempo
				mi.set_surface_override_material(0, own)
				_rups.append(own)
	if _body != null:
		_body_base = _body.transform
	_anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim != null:
		_strip_hull_tracks()
		_anim.stop()
	_red_marker()


## De Blender-clip Vuren laat ook de romp wippen; die sporen gaan eruit zodat de code de romp vrij beweegt (alleen het kanon schiet terug).
func _strip_hull_tracks() -> void:
	if not _anim.has_animation("Vuren"):
		return
	var a := _anim.get_animation("Vuren")
	for i in range(a.get_track_count() - 1, -1, -1):
		var p := String(a.track_get_path(i))
		if not p.contains("KanonMesh"):
			a.remove_track(i)


## Het rode teken op de koepel (net als de rode stip op de jeep): van boven meteen te zien dat het een vijandelijke tank is.
func _red_marker() -> void:
	var dot := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.42
	cyl.bottom_radius = 0.42
	cyl.height = 0.04
	cyl.radial_segments = 16
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.08, 0.05)
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.05, 0.03)
	mat.emission_energy_multiplier = 1.2
	mat.roughness = 0.6
	cyl.material = mat
	dot.mesh = cyl
	dot.name = "RodeStip"
	dot.position = Vector3(0.0, 0.93, -0.55)
	dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(_toren if _toren != null else self).add_child(dot)


## Een levensbalk boven de tank (zoals bij de jeep), rood op donker; hij kijkt altijd naar de camera.
func _build_bar() -> void:
	_bar = Node3D.new()
	_bar.name = "Levensbalk"
	_bar.position.y = 4.4
	add_child(_bar)
	for is_fill in [false, true]:
		var quad := QuadMesh.new()
		quad.size = Vector2(BAR_W - 0.14 if is_fill else BAR_W, 0.19 if is_fill else 0.3)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.albedo_color = Color(0.94, 0.25, 0.16) if is_fill else Color(0.025, 0.03, 0.025, 0.88)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		quad.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position.z = 0.012 if is_fill else 0.0
		_bar.add_child(mi)
		if is_fill:
			_bar_fill = mi


func _build_sound() -> void:
	if Game.supply == null or not is_instance_valid(Game.supply):
		return
	_snd = AudioStreamPlayer3D.new()
	_snd.name = "Motor"
	_snd.stream = Game.supply.engine_stream()
	_snd.volume_db = -14.0
	_snd.pitch_scale = 0.8
	_snd.max_distance = 55.0
	_snd.unit_size = 8.0
	_snd.position = Vector3(0, 1.2, 2.4)
	add_child(_snd)
	_snd.play()


# ---------------------------------------------------------------- schade

## Kogel, raket, granaat of ontploffing. De soort schade volgt uit Game.hit_class (soldaten met een raket of scherpschutters zetten die); heeft een
## spelerskogel geen soort, dan telt een ontploffing vlakbij als "explosie" en al het andere als "kogel".
func hit(dmg: float, dir: Vector3, from_player: bool) -> void:
	if not from_player or dead:
		return
	var klasse := Game.hit_class
	if klasse == "":
		klasse = "explosie" if not Game.blast_near(global_position).is_empty() else "kogel"
	_take(dmg * Data.counter(klasse, armor), dir)


func _take(dmg: float, dir: Vector3) -> void:
	if dead or dmg <= 0.0:
		return
	hp -= dmg
	if dir != Vector3.ZERO:
		Fx.spark(get_parent(), global_position + Vector3(0.0, 1.6, 0.0) - dir * 1.6, -dir)
	if hp <= 0.0:
		_destroy(dir)
		return
	if hp < max_hp * 0.5 and _smoke == null:
		_smoke = Fx.burning(self, global_position + Vector3(0.0, 1.8, 2.6), false)
	if hp < max_hp * 0.25 and _fire == null:
		_fire = Fx.flame(self, Vector3(0.0, 1.7, 2.6), 1.8)


## Napalm: hij vat vlam en verbrandt een paar seconden lang.
func ignite(secs := 5.0) -> void:
	if dead or burn_t > 0.0:
		return
	burn_t = secs
	_burn_fx = Fx.flame(self, Vector3(0.0, 1.4, 0.0), 2.4)
	Game.alert(global_position, 14.0, 4.0)


func flinch(_from: Vector3) -> void:
	pass   # een tank schrikt niet van een knal


func _destroy(dir: Vector3) -> void:
	dead = true
	hp = 0.0
	Game.enemies.erase(self)
	remove_from_group("vijand_voertuig")
	Game.alert(global_position, 16.0, 5.0)
	Game.kills += 1
	Progress.stats.kills += 1
	Game.add_score(POINTS)
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	_speed = 0.0
	if _snd != null:
		_snd.stop()
	_bar.visible = false
	Fx.explosion(get_parent(), global_position + Vector3(0.0, 1.6, 0.0), 1.8)
	Game.note_blast(global_position, 4.5)   # de knal raakt wie er vlak naast staat en laat bomen vallen
	_char()
	if _smoke == null:
		_smoke = Fx.burning(self, global_position + Vector3(0.0, 1.8, 1.2), false)
	if _fire == null:
		_fire = Fx.flame(self, Vector3(0.0, 1.7, 1.2), 2.6)
	if _burn_fx != null and is_instance_valid(_burn_fx):
		_burn_fx.queue_free()
	Game.banner.emit("VIJANDELIJKE TANK VERNIELD", "", 1.6)
	_wreck_t = WRECK_STAY


## Het wrak is zwartgeblakerd en de koepel staat iets scheef: elk onderdeel krijgt hetzelfde donkere materiaal.
func _char() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.06, 0.055, 0.05)
	mat.roughness = 0.95
	for mi in find_children("*", "MeshInstance3D", true, false):
		if mi.name != "RodeStip" and not _bar.is_ancestor_of(mi):
			(mi as MeshInstance3D).material_override = mat
	if _toren != null:
		_toren.rotation.y += 0.22
		_toren.rotation.z = 0.07
	if _kanon != null:
		_kanon.rotation.x = -0.06
	if _body != null:
		_body.rotation.z = 0.025


# ---------------------------------------------------------------- rijden

func _physics_process(delta: float) -> void:
	if dead:
		_wreck_t -= delta
		if _wreck_t <= 0.0:
			queue_free()
		return
	if Game.state != "play" and Game.state != "prep":
		_speed = 0.0
		return
	_time += delta
	slow_t -= delta
	alert_t -= delta
	if burn_t > 0.0:
		burn_t -= delta
		_take(BURN_DPS * Data.counter("brand", armor) * delta, Vector3.ZERO)
		if dead:
			return
	_retarget_t -= delta
	if _retarget_t <= 0.0:
		_retarget_t = 0.4
		target = _pick_target()
	_drive(delta)
	_aim_and_fire(delta)
	_animate(delta)
	_update_bar()


## Het eerstvolgende punt: eerst de route, daarna het hoofdkwartier. Over de rivier gaat hij via de brug; staat die omhoog, dan wacht hij aan de noordkant.
func _goal() -> Variant:
	holding = false
	if route_i < route.size():
		var p: Vector3 = route[route_i]
		if _flat_dist(p) < WAYPOINT_R:
			route_i += 1
			return _goal()
		return p
	var base: Vector3 = Game.base_pos
	if _north_of_river(global_position):
		if cross_i == 0 and not _crossing.is_empty() and Game.bridge != null and is_instance_valid(Game.bridge) and not Game.bridge.is_down():
			_crossing.clear()   # de brug gaat omhoog voordat hij erop rijdt: wachten (hij hangt niet boven het water)
		if _crossing.is_empty():
			_crossing = _make_crossing()
		if _crossing.is_empty():
			holding = true   # de brug staat omhoog: hij wacht aan de noordkant en schiet op wie binnen bereik komt
			return null
		var cp: Vector3 = _crossing[mini(cross_i, _crossing.size() - 1)]
		if cross_i < _crossing.size() - 1 and _flat_dist(cp) < 3.0:
			cross_i += 1
			cp = _crossing[cross_i]
		return cp
	_crossing.clear()
	if _flat_dist(base) < SIEGE_DIST - 4.0:
		holding = true
		return null
	return base


func _north_of_river(p: Vector3) -> bool:
	return p.z < Data.river_z(p.x) - Data.RIVER_HALF - 0.5


## De drie punten van de oversteek: voor de brug, op de brug en erachter. Staat de brug omhoog, dan is er geen oversteek (lege lijst).
func _make_crossing() -> Array:
	if Game.bridge != null and is_instance_valid(Game.bridge) and not Game.bridge.is_down():
		return []
	var cx := Data.BRIDGE_X
	var rz := Data.river_z(cx)
	var d := Data.RIVER_HALF + 4.5
	return [Vector3(cx, 0.0, rz - d), Vector3(cx, 0.0, rz), Vector3(cx, 0.0, rz + d)]


func _drive(delta: float) -> void:
	var want_speed := 0.0
	var want_yaw := 0.0
	var goal: Variant = _goal()
	var siege := not target.is_empty() and _target_dist() <= SIEGE_DIST
	if siege:
		holding = true   # beleg: hij staat stil zolang er een doel binnen bereik is
	if _back_t > 0.0:
		_back_t -= delta
		want_speed = -REVERSE
		want_yaw = _back_dir * MAX_YAW * 0.6
	elif goal != null and not siege and not _blocked_by_wall(goal):
		var to: Vector3 = (goal as Vector3) - global_position
		to.y = 0.0
		var fwd := -global_transform.basis.z
		var alpha := atan2(fwd.cross(to).y, fwd.dot(to)) + _avoid()
		want_yaw = clampf(alpha * 1.6, -MAX_YAW, MAX_YAW)
		want_speed = SPEED * clampf(1.0 - absf(alpha) / 1.1, 0.0, 1.0) * (0.4 if slow_t > 0.0 else 1.0)
		if absf(alpha) < 1.1 and want_speed < 1.2:
			want_speed = 1.2   # in een flauwe bocht blijft hij rollen
		if route_i >= route.size() and to.length() < 14.0:
			want_speed = minf(want_speed, maxf(to.length() * 0.5, 1.5))   # bij de basis rustig aankomen
	var braking := signf(want_speed) != signf(_speed) or absf(want_speed) < absf(_speed)
	_speed = move_toward(_speed, want_speed, (BRAKE if braking else ACCEL) * delta)
	_yaw_rate = move_toward(_yaw_rate, want_yaw, YAW_ACCEL * delta)
	_check_stuck(delta, want_speed, want_yaw)
	if absf(_speed) < 0.01 and absf(_yaw_rate) < 0.005:
		return
	rotation.y += _yaw_rate * delta
	velocity = -global_transform.basis.z * _speed
	move_and_slide()
	Foliage.ram(self, absf(_speed), 1.5, 2.5)   # tegen een boom aan: hij valt om (zelfde gewichtsklasse als jouw tank)
	global_position.y = 0.0
	if get_slide_collision_count() > 0:
		_speed *= 0.6
	var flat := Vector2(global_position.x, global_position.z)
	var clamped := Data.clamp_world(flat)
	if clamped != flat:
		global_position = Vector3(clamped.x, 0.0, clamped.y)
	if _snd != null:
		_snd.pitch_scale = 0.75 + clampf(absf(_speed) / SPEED, 0.0, 1.0) * 0.5 + clampf(absf(_yaw_rate), 0.0, 0.8) * 0.2


## Drie voelsprieten vooruit, evenwijdig aan zijn rijrichting: één langs de linker rups, één in het midden en één langs de rechter rups. Ze zien alleen wat in zijn eigen
## baan staat (muur, geparkeerde auto, paal), dus in een smalle straat rijdt hij gewoon rechtdoor en stuurt hij alleen weg van wat hij zou raken (dat is de zijde met de dichtstbijzijnde hindernis).
## Bomen tellen niet mee: die rijdt hij plat (Foliage.ram). Geeft een extra hoek (rad, + = naar links) die bij de hoek naar het doel opgeteld wordt.
func _avoid() -> float:
	var space := get_world_3d().direct_space_state
	var fwd := -global_transform.basis.z
	var right := global_transform.basis.x
	var base := global_position + Vector3(0.0, 0.9, 0.0) + fwd * 2.6
	var mask := Kit.LAYER_WALL | Kit.LAYER_BUNKER | Kit.LAYER_FORTIFICATION
	var d := [WHISKER, WHISKER, WHISKER]   # links, midden, rechts
	var i := 0
	for off in [-WHISKER_SIDE, 0.0, WHISKER_SIDE]:
		var from: Vector3 = base + right * off
		var q := PhysicsRayQueryParameters3D.create(from, from + fwd * WHISKER, mask)
		q.exclude = [get_rid()]
		var h := space.intersect_ray(q)
		if not h.is_empty():
			d[i] = (h.position - from).length()
		i += 1
	if d[0] >= WHISKER and d[1] >= WHISKER and d[2] >= WHISKER:
		return 0.0
	var pl: float = 1.0 - d[0] / WHISKER   # druk van links: hoe dichterbij, hoe harder
	var pc: float = 1.0 - d[1] / WHISKER
	var pr: float = 1.0 - d[2] / WHISKER
	var steer := pl - pr   # hindernis links: naar rechts sturen (negatief)
	steer = -steer
	if pc > 0.0 and absf(steer) < 0.25:
		steer += pc * (1.0 if d[0] > d[2] else -1.0)   # iets recht voor hem en aan beide kanten even ver: naar de vrijere kant
	return clampf(steer * 1.3, -1.3, 1.3)


## Zit hij vast (hij wil rijden maar komt niet vooruit), dan zet hij even achteruit en draait; na een paar pogingen slaat hij het punt over.
func _check_stuck(delta: float, want_speed: float, want_yaw: float) -> void:
	_sample_t += delta
	if _sample_t < 0.8:
		return
	var moved := (global_position - _sample_pos).length()
	_sample_pos = global_position
	_sample_t = 0.0
	if _back_t > 0.0:
		return
	if absf(want_speed) > 1.0 and moved < 0.35:
		_stuck += 1
		if _stuck >= 2:
			_back_t = 1.8
			_back_dir = -signf(want_yaw) if absf(want_yaw) > 0.05 else (1.0 if randf() < 0.5 else -1.0)
			if _stuck >= 5:
				_stuck = 0
				if route_i < route.size():
					route_i += 1   # dit punt lukt niet: het volgende
	else:
		_stuck = 0


## Staat er een muurstuk of een dichte poort van jouw basis vlak voor hem, dan blijft hij staan en beschiet het (dat is dan ook zijn doel).
func _blocked_by_wall(goal: Vector3) -> bool:
	var dir := goal - global_position
	dir.y = 0.0
	if dir.length() < 0.5:
		return false
	if Game.gates != null:
		var gate: Variant = Game.gates.blocking(global_position, goal)
		if gate != null:
			return true
	dir = dir.normalized()
	var from := global_position + Vector3.UP
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 5.0, Kit.LAYER_FORTIFICATION)
	var h := get_world_3d().direct_space_state.intersect_ray(q)
	return not h.is_empty() and h.collider is BuildingBody


# ---------------------------------------------------------------- doel kiezen en schieten

## Het dichtstbijzijnde doel binnen schootsafstand. Soldaten en jij tellen zwaarder dan muren (je afstand telt dertig procent korter), het hoofdkwartier telt vanaf zijn rand.
## Geeft {"kind": ally/player/voertuig/build/gate/hq, "pos": Vector3, ...} of een leeg woordenboek.
func _pick_target() -> Dictionary:
	var best := {}
	var best_score := SHOT_RANGE + 0.01
	var here := global_position
	for c in Game.allies:
		if c == null or not is_instance_valid(c) or c.get("dead") == true or (c is Ally and c.onraakbaar()):
			continue
		var d := _flat_dist((c as Node3D).global_position)
		if d * 0.7 < best_score and d <= SHOT_RANGE:
			best_score = d * 0.7
			best = {"kind": "ally", "pos": (c as Node3D).global_position, "node": c, "dist": d}
	var p: Node3D = Game.player
	if p != null and is_instance_valid(p) and p.get("dead") != true:
		var d2 := _flat_dist(p.global_position)
		if d2 * 0.7 < best_score and d2 <= SHOT_RANGE:
			best_score = d2 * 0.7
			best = {"kind": "player", "pos": p.global_position, "node": p, "dist": d2}
	for v in VoertuigSchade.doelen():   # jouw jeep en tank tellen ook als doel, ook als ze leeg geparkeerd staan (V3, keuze 6A)
		var dv := _flat_dist((v as Node3D).global_position)
		if dv * 0.7 < best_score and dv <= SHOT_RANGE:
			best_score = dv * 0.7
			best = {"kind": "voertuig", "pos": (v as Node3D).global_position, "node": v, "dist": dv}
	for b in Game.buildings:
		if not b is Dictionary or b.get("down", false) or not Buildings.DEFS.has(b.kind):
			continue
		var at: Vector3 = b.at
		var sz: Vector3 = Buildings.DEFS[b.kind].size
		var d3 := maxf(0.0, Vector2(at.x - here.x, at.z - here.z).length() - maxf(sz.x, sz.z) * 0.5)
		if d3 < best_score and d3 <= SHOT_RANGE:
			best_score = d3
			best = {"kind": "build", "pos": at, "ref": b, "dist": d3}
	if Game.gates != null:
		for i in Game.gates.list.size():
			var g: Dictionary = Game.gates.list[i]
			if g.broken:
				continue
			var gp: Vector3 = Game.gates.pos_of(g)
			var d4 := maxf(0.0, Vector2(gp.x - here.x, gp.z - here.z).length() - Gates.G)
			if d4 < best_score and d4 <= SHOT_RANGE:
				best_score = d4
				best = {"kind": "gate", "pos": gp, "index": i, "dist": d4}
	if Game.base_hp > 0.0 and Game.state == "play":
		var hd := maxf(0.0, _flat_dist(Game.base_pos) - HQ_R)
		if hd < best_score and hd <= SHOT_RANGE:
			best_score = hd
			best = {"kind": "hq", "pos": Game.base_pos, "dist": hd}
	return best


func _target_valid() -> bool:
	if target.is_empty():
		return false
	match str(target.kind):
		"ally", "player":
			return target.node != null and is_instance_valid(target.node) and target.node.get("dead") != true
		"voertuig":
			return target.node != null and is_instance_valid(target.node) and VoertuigSchade.doelen().has(target.node)
		"build":
			return Game.buildings.has(target.ref) and not target.ref.down
		"gate":
			return Game.gates != null and int(target.index) < Game.gates.list.size() and not Game.gates.list[int(target.index)].broken
		"hq":
			return Game.base_hp > 0.0
	return false


## Afstand tot het doel (vanaf de rand van het doel waar dat telt); voor het stoppen en voor de schootsafstand.
func _target_dist() -> float:
	if target.is_empty():
		return INF
	if not _target_valid():
		return INF
	return _flat_dist(_target_pos()) - (HQ_R if str(target.kind) == "hq" else 0.0)


func _target_pos() -> Vector3:
	match str(target.kind):
		"ally", "player", "voertuig":
			return (target.node as Node3D).global_position
		"gate":
			return Game.gates.pos_of(Game.gates.list[int(target.index)])
		"build":
			return target.ref.at
		"hq":
			return Game.base_pos
	return global_position


func _aim_and_fire(delta: float) -> void:
	_cool -= delta
	if _toren == null or _monding == null:
		return
	var has := not target.is_empty() and _target_valid()
	var desired_local := 0.0   # zonder doelwit kijkt de koepel naar voren
	var aim_pos := Vector3.ZERO
	var tilt := 0.0
	if has:
		aim_pos = _target_pos()
		var d := aim_pos - _monding.global_position
		desired_local = wrapf(atan2(-d.x, -d.z) - rotation.y, -PI, PI)
		tilt = clampf(atan2(maxf(0.0, 2.0 - _monding.global_position.y) * 0.4, maxf(Vector2(d.x, d.z).length(), 1.0)), 0.0, 0.08)
	var diff := wrapf(desired_local - _toren.rotation.y, -PI, PI)
	_toren.rotation.y += clampf(diff, -TURRET_TURN * delta, TURRET_TURN * delta)
	if _kanon != null:
		_kanon.rotation.x = lerpf(_kanon.rotation.x, tilt, delta * 2.0)
	if has and _cool <= 0.0 and absf(diff) < AIM_TOL and _target_dist() <= SHOT_RANGE and not _mid_turn():
		_shoot(aim_pos)


## Draait de romp nog flink, dan wacht het schot (de koepel staat dan al snel scheef ten opzichte van het doel).
func _mid_turn() -> bool:
	return absf(_yaw_rate) > 0.5


## Schiet een granaat naar `aim`. Staat er een muur of het hoofdkwartier in de weg, dan ontploft hij daar (zoals een echt kanonschot); anders landt hij bij het doel.
func _shoot(aim: Vector3) -> void:
	_cool = RELOAD
	_shots_fired += 1
	var from := _monding.global_position
	var to := aim + Vector3(randf_range(-SCATTER, SCATTER), 0.0, randf_range(-SCATTER, SCATTER))
	to.y = maxf(aim.y, 0.0)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to + Vector3.UP * 0.9, Bullet.MASK_WALL | Bullet.MASK_BUNKER | Bullet.MASK_FORTIFICATION)
	var h := space.intersect_ray(q)
	if not h.is_empty():
		to = (h.position as Vector3) - (to + Vector3.UP * 0.9 - from).normalized() * 0.3
		to.y = maxf(to.y, 0.0)
	TankFx.shot(get_parent(), from, to - from, false, false)
	if _anim != null and _anim.has_animation("Vuren"):
		_anim.play("Vuren", 0.02)
	_recoil()
	VijandTank.launch(get_parent(), from, to, aim)


## De romp wipt even na het schot (alleen het uiterlijk).
func _recoil() -> void:
	_recoil_t = 0.45


# ---------------------------------------------------------------- de granaat zelf

## Een granaat vliegt van `from` naar `to` (met een lage boog) en ontploft daar. Statisch: de granaat valt ook als de tank er tussen die tijd niet meer is.
static func launch(parent: Node, from: Vector3, to: Vector3, _aim: Vector3, dmg := SHELL_DAMAGE) -> void:
	var shell := Node3D.new()
	shell.name = "TankGranaat"
	if TankFx.enabled():
		shell.add_child(TankFx.streak())   # snelle lichtstreep in plaats van het oranje balletje
	var ball := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.13
	sph.height = 0.38
	sph.radial_segments = 8
	sph.rings = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.7, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.55, 0.15)
	mat.emission_energy_multiplier = 2.4
	sph.material = mat
	ball.mesh = sph
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not TankFx.enabled():
		shell.add_child(ball)
	parent.add_child(shell)
	shell.global_position = from
	var flat := Vector2(to.x - from.x, to.z - from.z)
	shell.rotation.y = atan2(flat.x, flat.y)
	Fx.rocket_trail(shell)
	var dist := maxf(from.distance_to(to), 1.0)
	var secs := dist / SHELL_SPEED
	var arc := minf(dist * 0.03, 1.6)
	var tw := shell.create_tween()
	tw.tween_method(func(k: float) -> void:
		shell.global_position = from.lerp(to, k) + Vector3.UP * (sin(k * PI) * arc), 0.0, 1.0, secs)
	tw.tween_callback(func() -> void:
		VijandTank.boom(parent, to, dmg)
		shell.queue_free())


## De ontploffing van een tankgranaat: schade aan gebouwen, poorten, jouw soldaten, jou en het hoofdkwartier, met afname naar de rand. De hoge basismuur houdt de scherven tegen.
static func boom(parent: Node, at: Vector3, dmg := SHELL_DAMAGE) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var r := SHELL_RADIUS
	Game.note_blast(at, r)
	TankFx.impact(parent, at, 1.2)
	Barrel.catch_blast(at, r)
	VoertuigSchade.blast(at, r, dmg)   # tegen jouw jeep en tank telt een tankgranaat als "explosie" (pantser jeep/tank)
	Garnizoen.blast(at, r, dmg, "eigen")
	if Game.builds != null:
		Game.builds.blast(at, r, dmg * BUILD_MULT, false)
	if Game.gates != null:
		for i in Game.gates.list.size():
			var g: Dictionary = Game.gates.list[i]
			var gp: Vector3 = Game.gates.pos_of(g)
			var gd := maxf(0.0, Vector2(gp.x - at.x, gp.z - at.z).length() - Gates.G)
			if not g.broken and gd < r:
				Game.gates.damage(i, dmg * 1.2 * (1.0 - gd / r), "explosive")
	for a in Game.allies.duplicate():
		if a == null or not is_instance_valid(a) or (a is Ally and a.onraakbaar()):
			continue
		var d := Vector2(a.global_position.x - at.x, a.global_position.z - at.z).length()
		if d < r and not BaseWallRules.blocks_blast(at, a.global_position):
			a.hp -= dmg * (1.0 - d / r * 0.5)
			if a.hp <= 0.0:
				Game.allies.erase(a)
				a.queue_free()
				Game.changed.emit()
	var p: Node3D = Game.player
	if p != null and is_instance_valid(p) and p.get("dead") != true:
		var pd := Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length()
		if pd < r and not BaseWallRules.blocks_blast(at, p.global_position):
			p.hit(dmg * 0.6 * (1.0 - pd / r), (p.global_position - at).normalized(), false, true)
	var hq := maxf(0.0, Vector2(Game.base_pos.x - at.x, Game.base_pos.z - at.z).length() - HQ_R)
	if hq < r and Game.state == "play":
		Game.damage_base(HQ_DAMAGE * (1.0 - hq / r))


# ---------------------------------------------------------------- uiterlijk

func _animate(delta: float) -> void:
	var left := _speed - _yaw_rate * TRACK_HALF    # + = naar links; de linker rups loopt dan langzamer
	var right := _speed + _yaw_rate * TRACK_HALF
	for w in _wheels_l:
		(w as Node3D).rotation.x = wrapf((w as Node3D).rotation.x - left * delta / WHEEL_R, -PI, PI)
	for w in _wheels_r:
		(w as Node3D).rotation.x = wrapf((w as Node3D).rotation.x - right * delta / WHEEL_R, -PI, PI)
	if _rups.size() == 2:
		_rups[0].uv1_offset.x = fposmod(_rups[0].uv1_offset.x + left * delta / TRACK_LEN, 1.0)
		_rups[1].uv1_offset.x = fposmod(_rups[1].uv1_offset.x + right * delta / TRACK_LEN, 1.0)
	if _body == null:
		return
	_recoil_t = maxf(0.0, _recoil_t - delta)
	var amp := clampf(absf(_speed) / 3.0 + absf(_yaw_rate), 0.12, 1.0)
	var bounce := (0.008 * sin(_time * 7.0) + 0.004 * sin(_time * 12.3)) * amp
	var pitch := 0.0035 * sin(_time * 5.3) * amp - 0.012 * exp(-(0.45 - _recoil_t) * 6.0) * sin((0.45 - _recoil_t) * 26.0) * (1.0 if _recoil_t > 0.0 else 0.0)
	var roll := clampf(-_yaw_rate * absf(_speed) * 0.004, -0.04, 0.04)
	_body.transform = _body_base * Transform3D(Basis.from_euler(Vector3(pitch, 0, roll)), Vector3(0, bounce, 0))


func _update_bar() -> void:
	var player: Node3D = Game.player
	var dist := player.global_position.distance_to(global_position) if player != null and is_instance_valid(player) else INF
	_bar.visible = dist < 90.0
	if _bar.visible:
		var f := clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
		_bar_fill.scale.x = maxf(f, 0.001)
		_bar_fill.position.x = -(1.0 - f) * (BAR_W - 0.14) * 0.5


func _flat_dist(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()
