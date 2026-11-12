class_name VijandJeep
extends CharacterBody3D
## De vijandelijke jeep (Generals-plan stap D2, keuze G; Dennis' keuzes van 9 november 2026). Hij rijdt zelf van de poort van de vijandbasis over de weg
## (AanvalRoutes.voertuig_pad) door de stad naar de brug of ondiepte en dan naar jouw basis, en schiet onderweg met zijn MG op jouw soldaten en op jou.
## Hij staat in Game.enemies (net als een soldaat) en in de groep "vijand_voertuig", zodat jouw soldaten, torens, de Apache, granaten, napalm, de teller en de radar
## hem vanzelf zien. Hij is pantser "jeep" (Data.ARMOR_MULT): kogels doen weinig, raketten, granaten en vuur veel. Op 0 levenspunten brandt hij uit als wrak
## en verdwijnt na een halve minuut. Het model is Dennis' eigen jeep (Meshy, bron/vijand_jeep): romp, vier wielen (voorwielen sturen), MG op een draaipaal
## en een bestuurder en schutter in vijandkleuren. Knopen: VijandJeep > Body > RompMesh, StuurLV/RV > WielLV/RV, WielLA/RA, Bestuurder, Geschut > MG > Monding en
## Schutter. Alles wat ontbreekt wordt overgeslagen, dus een ander model werkt ook zolang MODEL_PAD en de namen kloppen.

const MODEL_PAD := "res://assets/vijand_jeep.glb"
const MODEL_TINT := Color.WHITE   # alleen als het model een materiaal "Olijf" heeft (de jeep van de speler) tint hij die; Dennis' eigen model niet
const HP := 220.0
const SPEED := 11.0         # m/s: een goede 40 km/u over de weg
const REVERSE := 3.0
const ACCEL := 6.0
const BRAKE := 10.0
const WHEELBASE := 2.04
const WHEEL_R := 0.37
const MAX_STEER := 0.5
const GUN_TURN := 3.2       # rad/s draaien van het MG
const RANGE := 30.0         # m: zo ver ziet de schutter
const BULLET_SPEED := 110.0
const DAMAGE := 5.0
const FIRE_RATE := 0.12     # s tussen twee kogels in een salvo
const BURST := 6
const PAUSE := 1.0          # s tussen twee salvo's
const SPREAD := 0.05        # rad
const BURN_DPS := 55.0      # napalm: schade per seconde zolang hij brandt
const WAYPOINT_R := 3.0     # m: zo dichtbij telt een routepunt als bereikt (de punten liggen minstens 4 m uit elkaar)
const WHISKER := 7.0        # m: zo ver kijkt hij vooruit naar muren, geparkeerde auto's en andere vaste dingen
const BASE_HOLD := 22.0     # m van het hoofdkwartier: hier stopt hij en schiet
const CHASE_R := 55.0       # m: zuid van de rivier jaagt hij op soldaten tot zo ver
const CHASE_STOP := 11.0    # m: zo dichtbij komt hij een soldaat
const WRECK_STAY := 30.0    # s dat het wrak blijft liggen
const BAR_W := 1.9
const POINTS := 150

var type := "jeep"
var armor := "jeep"
var t: Dictionary = {"hp": HP, "speed": SPEED, "r": 1.3, "scale": 1.0, "range": RANGE, "dmg": DAMAGE, "rate": FIRE_RATE, "burst": BURST, "pause": PAUSE, "pts": POINTS, "color": Color("5b6038")}
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
var target: Node3D = null
var holding := false   # staat stil: hij is bij de basis of wacht voor de opgehaalde brug

var _speed := 0.0
var _steer := 0.0
var _yaw_rate := 0.0
var _accel := 0.0
var _time := 0.0
var _cool := 0.0
var _shots := 0
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
var _stuur: Array = []
var _wheels: Array = []
var _gun: Node3D
var _mg: Node3D
var _monding: Node3D
var _lijf: Node3D
var _body_base := Transform3D.IDENTITY
var _mg_base := Transform3D.IDENTITY
var _lijf_base := Transform3D.IDENTITY
var _firing := false
var _crossing: Array = []
var _hit_wall_t := 0.0
var _base_t := 0.0


## Maakt een vijandelijke jeep die deze punten afrijdt. Voeg hem toe aan de wereld en zet hem op zijn plek.
static func make(pad: Array, wave := 1) -> VijandJeep:
	var j := VijandJeep.new()
	j.route = pad
	j.max_hp = HP * (1.0 + (maxi(1, wave) - 1) * 0.05)
	j.hp = j.max_hp
	return j


func _ready() -> void:
	add_to_group("vijand_voertuig")
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 8   # de laag van de vijand: kogels en raketten van jou en je soldaten raken hem
	collision_mask = Kit.LAYER_WALL | Kit.LAYER_BUNKER | Kit.LAYER_NATURE | Kit.LAYER_FORTIFICATION | 32 | 4   # muren, torens, bomen, jouw voertuigen en jij
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.9, 1.7, 4.3)
	cs.shape = box
	cs.position = Vector3(0.0, 0.85, 0.17)
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
		Kit.box(model, Vector3(0.0, 0.8, 0.0), Vector3(1.7, 1.0, 3.6), Kit.flat(Color("5b6038")))
	model.name = "Model"
	add_child(model)
	_body = model.find_child("Body", true, false) as Node3D
	_gun = model.find_child("Geschut", true, false) as Node3D
	_mg = model.find_child("MG", true, false) as Node3D
	_monding = model.find_child("Monding", true, false) as Node3D
	_lijf = model.find_child("Bovenlijf", true, false) as Node3D
	for n in ["StuurLV", "StuurRV"]:
		var s := model.find_child(n, true, false) as Node3D
		if s != null:
			_stuur.append(s)
	for n in ["WielLV", "WielRV", "WielLA", "WielRA"]:
		var w := model.find_child(n, true, false) as Node3D
		if w != null:
			_wheels.append(w)
	if _body != null:
		_body_base = _body.transform
	if _mg != null:
		_mg_base = _mg.transform
	if _lijf != null:
		_lijf_base = _lijf.transform
	_anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim != null:
		_strip_fire_clip()
		_anim.stop()
	_rest_fire_parts(model)
	for lamp in model.find_children("Koplamp*", "SpotLight3D", true, false):
		(lamp as Node3D).visible = false   # geen lichtbundels: tientallen schaduwen kost een telefoon te veel
	if MODEL_TINT != Color.WHITE:
		_tint(model)
	_red_dot()


## Zoals bij de jeep van de speler: de Blender-clip Vuren keyt ook romp en wielen; die sporen gaan eruit zodat de code ze vrij beweegt.
func _strip_fire_clip() -> void:
	if not _anim.has_animation("Vuren"):
		return
	var a := _anim.get_animation("Vuren")
	for i in range(a.get_track_count() - 1, -1, -1):
		var p := String(a.track_get_path(i))
		if not (p.contains("/MG") or p.contains("/Bovenlijf")):
			a.remove_track(i)


func _rest_fire_parts(model: Node3D) -> void:
	var vlam := model.find_child("Vlam", true, false) as Node3D
	if vlam != null:
		vlam.scale = Vector3.ONE * 0.001
	for h in ["Huls0", "Huls1", "Huls2"]:
		var n := model.find_child(h, true, false) as Node3D
		if n != null:
			n.scale = Vector3.ONE * 0.001
	if _mg != null:
		_mg.transform = _mg_base
	if _lijf != null:
		_lijf.transform = _lijf_base


## De lak (materiaal "Olijf") krijgt een geel-groene tint; de rest (banden, metaal, glas) blijft zoals het was.
func _tint(model: Node3D) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh
		if m == null:
			continue
		for i in m.get_surface_count():
			var mat := m.surface_get_material(i)
			if mat is StandardMaterial3D and mat.resource_name == "Olijf":
				var copy := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				copy.albedo_color = MODEL_TINT
				(mi as MeshInstance3D).set_surface_override_material(i, copy)


## De rode stip op de motorkap: zo zie je van boven meteen dat het een vijandelijke jeep is.
func _red_dot() -> void:
	var dot := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.32
	cyl.bottom_radius = 0.32
	cyl.height = 0.03
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
	dot.position = Vector3(0.0, 1.19, -1.15)
	dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(_body if _body != null else self).add_child(dot)


## Een levensbalk boven de jeep (zoals de balk boven verre vijanden), rood op donker; hij kijkt altijd naar de camera.
func _build_bar() -> void:
	_bar = Node3D.new()
	_bar.name = "Levensbalk"
	_bar.position.y = 3.3
	add_child(_bar)
	for is_fill in [false, true]:
		var quad := QuadMesh.new()
		quad.size = Vector2(BAR_W - 0.12 if is_fill else BAR_W, 0.16 if is_fill else 0.26)
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
	_snd.volume_db = -20.0
	_snd.pitch_scale = 1.5
	_snd.max_distance = 45.0
	_snd.unit_size = 6.0
	_snd.position = Vector3(0, 1.0, -1.0)
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
		Fx.spark(get_parent(), global_position + Vector3(0.0, 1.0, 0.0) - dir * 0.8, -dir)
	if hp <= 0.0:
		_destroy(dir)
		return
	if hp < max_hp * 0.5 and _smoke == null:
		_smoke = Fx.burning(self, global_position + Vector3(0.0, 0.9, -1.2), false)
	if hp < max_hp * 0.25 and _fire == null:
		_fire = Fx.flame(self, Vector3(0.0, 0.9, -1.2), 1.4)


## Napalm: hij vat vlam en verbrandt een paar seconden lang.
func ignite(secs := 5.0) -> void:
	if dead or burn_t > 0.0:
		return
	burn_t = secs
	_burn_fx = Fx.flame(self, Vector3(0.0, 0.8, 0.0), 1.8)
	Game.alert(global_position, 14.0, 4.0)


func flinch(_from: Vector3) -> void:
	pass   # een jeep schrikt niet van een knal


func _destroy(dir: Vector3) -> void:
	dead = true
	hp = 0.0
	Game.enemies.erase(self)
	remove_from_group("vijand_voertuig")
	Game.alert(global_position, 14.0, 5.0)
	Game.kills += 1
	Progress.stats.kills += 1
	Game.add_score(POINTS)
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	_speed = 0.0
	_set_firing(false)
	if _snd != null:
		_snd.stop()
	_bar.visible = false
	for n in ["Bestuurder", "Schutter"]:
		var crew := find_child(n, true, false) as Node3D
		if crew != null:
			crew.visible = false   # de bemanning is niet meer te zien in het wrak
	Fx.explosion(get_parent(), global_position + Vector3(0.0, 0.8, 0.0), 1.3)
	Game.note_blast(global_position, 3.5)   # de knal raakt wie er vlak naast staat en laat bomen vallen
	_char()
	if _smoke == null:
		_smoke = Fx.burning(self, global_position + Vector3(0.0, 0.9, -0.4), false)
	if _fire == null:
		_fire = Fx.flame(self, Vector3(0.0, 0.7, -0.4), 1.8)
	if _burn_fx != null and is_instance_valid(_burn_fx):
		_burn_fx.queue_free()
	Game.banner.emit("VIJANDELIJKE JEEP VERNIELD", "", 1.4)
	_wreck_t = WRECK_STAY


## Het wrak is zwartgeblakerd: elk onderdeel krijgt hetzelfde donkere materiaal.
func _char() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.06, 0.055, 0.05)
	mat.roughness = 0.95
	for mi in find_children("*", "MeshInstance3D", true, false):
		if mi.name != "RodeStip" and not _bar.is_ancestor_of(mi):
			(mi as MeshInstance3D).material_override = mat
	if _body != null:
		_body.rotation.z = 0.06   # hij zakt wat scheef op zijn veren


# ---------------------------------------------------------------- rijden en schieten

func _physics_process(delta: float) -> void:
	if dead:
		_wreck_t -= delta
		if _wreck_t <= 0.0:
			queue_free()
		return
	if Game.state != "play" and Game.state != "prep":
		_speed = 0.0
		_set_firing(false)
		return
	_time += delta
	slow_t -= delta
	alert_t -= delta
	if burn_t > 0.0:
		burn_t -= delta
		_take(BURN_DPS * Data.counter("brand", armor) * delta, Vector3.ZERO)
		if dead:
			return
	_drive(delta)
	_aim_and_fire(delta)
	_animate(delta)
	_update_bar()


## Het eerstvolgende doel: eerst de punten van de route, daarna (zuid van de rivier) een soldaat in de buurt, anders het hoofdkwartier. Over de rivier gaat hij
## via de brug, of via de ondiepte als de brug omhoog staat.
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
		if cross_i < _crossing.size() - 1 and _flat_dist(cp) < 2.5:
			cross_i += 1
			cp = _crossing[cross_i]
		return cp
	_crossing.clear()
	if target != null and is_instance_valid(target) and _flat_dist(target.global_position) < CHASE_R:
		if _flat_dist(target.global_position) < CHASE_STOP:
			holding = true
			return null
		return target.global_position
	if _flat_dist(base) < BASE_HOLD:
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
	var d := Data.RIVER_HALF + 3.5
	return [Vector3(cx, 0.0, rz - d), Vector3(cx, 0.0, rz), Vector3(cx, 0.0, rz + d)]


func _drive(delta: float) -> void:
	var want_speed := 0.0
	var want_steer := 0.0
	var goal: Variant = _goal()
	if _back_t > 0.0:
		_back_t -= delta
		want_speed = -REVERSE
		want_steer = clampf(_back_dir * MAX_STEER, -MAX_STEER, MAX_STEER)
	elif goal != null and not _blocked_by_wall(goal):
		var to: Vector3 = (goal as Vector3) - global_position
		to.y = 0.0
		var fwd := -global_transform.basis.z
		var alpha := atan2(fwd.cross(to).y, fwd.dot(to)) + _avoid()
		want_steer = clampf(atan(2.0 * WHEELBASE * sin(alpha) / maxf(to.length(), 2.5)), -MAX_STEER, MAX_STEER)
		want_speed = SPEED * clampf(1.0 - absf(alpha) / 1.5, 0.3, 1.0) * (0.4 if slow_t > 0.0 else 1.0)
		if route_i >= route.size() and to.length() < 12.0:
			want_speed = minf(want_speed, maxf(to.length() * 0.6, 2.0))   # bij de basis of een soldaat rustig aankomen
		if target != null and is_instance_valid(target) and _flat_dist(target.global_position) < 16.0:
			want_speed *= 0.7   # dichtbij vuurt hij rustiger
	var old := _speed
	var braking := signf(want_speed) != signf(_speed) or absf(want_speed) < absf(_speed)
	_speed = move_toward(_speed, want_speed, (BRAKE if braking else ACCEL) * delta)
	_accel = lerpf(_accel, (_speed - old) / delta, delta * 4.0)
	_steer = move_toward(_steer, want_steer, 2.5 * delta)
	_yaw_rate = _speed * tan(_steer) / WHEELBASE
	_check_stuck(delta, want_speed)
	if absf(_speed) < 0.01:
		return
	rotation.y += _yaw_rate * delta
	velocity = -global_transform.basis.z * _speed
	move_and_slide()
	Foliage.ram(self, absf(_speed), 6.0)   # tegen een boom aan: hij valt om
	global_position.y = 0.0
	if get_slide_collision_count() > 0:
		_speed *= 0.6
	var flat := Vector2(global_position.x, global_position.z)
	var clamped := Data.clamp_world(flat)
	if clamped != flat:
		global_position = Vector3(clamped.x, 0.0, clamped.y)
	if _snd != null:
		_snd.pitch_scale = 1.2 + clampf(absf(_speed) / SPEED, 0.0, 1.0) * 0.8


## Drie voelsprieten vooruit (links, midden, rechts): staat er iets vast voor zijn neus (muur, geparkeerde auto, paal), dan stuurt hij naar de vrije kant.
## Bomen tellen niet mee: die rijdt hij plat (Foliage.ram). Geeft een extra hoek (rad) die bij de hoek naar het doel opgeteld wordt.
func _avoid() -> float:
	var space := get_world_3d().direct_space_state
	var fwd := -global_transform.basis.z
	var from := global_position + Vector3(0.0, 0.7, 0.0) + fwd * 1.9
	var mask := Kit.LAYER_WALL | Kit.LAYER_BUNKER | Kit.LAYER_FORTIFICATION
	var d := [WHISKER, WHISKER, WHISKER]   # links, midden, rechts
	var i := 0
	for ang in [0.55, 0.0, -0.55]:
		var dir := fwd.rotated(Vector3.UP, ang)
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * WHISKER, mask)
		q.exclude = [get_rid()]
		var h := space.intersect_ray(q)
		if not h.is_empty():
			d[i] = (h.position - from).length()
		i += 1
	if d[0] >= WHISKER and d[1] >= WHISKER and d[2] >= WHISKER:
		return 0.0
	var side := signf(d[0] - d[2])   # + = links is vrijer: naar links sturen
	if side == 0.0:
		side = 1.0
	var near := WHISKER - minf(d[1], minf(d[0] * 1.2, d[2] * 1.2))
	return clampf(near / WHISKER * 1.3, 0.0, 1.0) * side


## Zit hij vast (hij wil rijden maar komt niet vooruit), dan zet hij even achteruit met de wielen de andere kant op; na een paar pogingen slaat hij het punt over.
func _check_stuck(delta: float, want_speed: float) -> void:
	_sample_t += delta
	if _sample_t < 0.6:
		return
	var moved := (global_position - _sample_pos).length()
	_sample_pos = global_position
	_sample_t = 0.0
	if _back_t > 0.0:
		return
	if absf(want_speed) > 2.0 and moved < 0.5:
		_stuck += 1
		if _stuck >= 2:
			_back_t = 1.3
			_back_dir = -signf(_steer) if absf(_steer) > 0.05 else (1.0 if randf() < 0.5 else -1.0)
			if _stuck >= 5:
				_stuck = 0
				if route_i < route.size():
					route_i += 1   # dit punt lukt niet: het volgende
	else:
		_stuck = 0


## Staat er een muurstuk of een dichte poort van jouw basis vlak voor hem, dan blijft hij staan en schiet erop (heel traag: dit is geen belegeraar).
func _blocked_by_wall(goal: Vector3) -> bool:
	var dir := goal - global_position
	dir.y = 0.0
	if dir.length() < 0.5:
		return false
	if Game.gates != null:
		var gate: Variant = Game.gates.blocking(global_position, goal)
		if gate != null:
			_hit_wall_t -= get_physics_process_delta_time()
			if _hit_wall_t <= 0.0:
				_hit_wall_t = 0.5
				Game.gates.damage(Game.gates.list.find(gate), DAMAGE * 0.4, "bullet")
			return true
	dir = dir.normalized()
	var from := global_position + Vector3.UP
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 3.2, Kit.LAYER_FORTIFICATION)
	var h := get_world_3d().direct_space_state.intersect_ray(q)
	if not h.is_empty() and h.collider is BuildingBody:
		var ref: Dictionary = (h.collider as BuildingBody).ref
		if not ref.is_empty() and Game.buildings.has(ref) and (ref.kind == "kampmuur" or ref.kind == "poort"):
			_hit_wall_t -= get_physics_process_delta_time()
			if _hit_wall_t <= 0.0:
				_hit_wall_t = 0.5
				Game.builds.damage(ref, DAMAGE * 0.4)
			return true
	return false


func _aim_and_fire(delta: float) -> void:
	_retarget_t -= delta
	if _retarget_t <= 0.0:
		_retarget_t = 0.3
		target = _pick_target()
	_cool -= delta
	if _gun == null or _monding == null:
		return
	var desired_local := 0.0   # zonder doelwit kijkt het MG naar voren
	var aim_pos := Vector3.ZERO
	var has := target != null and is_instance_valid(target)
	if has:
		aim_pos = target.global_position + Vector3.UP * 1.3
		var d := aim_pos - _monding.global_position
		desired_local = wrapf(atan2(-d.x, -d.z) - rotation.y, -PI, PI)
	var diff := wrapf(desired_local - _gun.rotation.y, -PI, PI)
	_gun.rotation.y += clampf(diff, -GUN_TURN * delta, GUN_TURN * delta)
	var aligned := has and absf(diff) < 0.2
	if aligned and _cool <= 0.0:
		_shoot(aim_pos)
	_set_firing(has and aligned and _shots > 0)
	_fire_at_base(delta, has)


## Staat hij bij het hoofdkwartier en is er niemand anders om op te schieten, dan beschiet hij het gebouw (een MG doet daar weinig).
func _fire_at_base(delta: float, has_target: bool) -> void:
	_base_t -= delta
	if has_target or _base_t > 0.0 or route_i < route.size() or _flat_dist(Game.base_pos) > BASE_HOLD + 2.0 or absf(_speed) > 1.0:
		return
	if BaseWallRules.blocks_blast(global_position, Game.base_pos):
		return
	_base_t = 0.5
	Game.mark_attack(global_position)
	Game.damage_base(DAMAGE * 0.4)
	Sfx.play("mg", 0.3, global_position)


## Dichtstbijzijnde soldaat of speler binnen bereik waar hij vrij schootsveld op heeft; en de basis zelf als hij dichtbij is.
func _pick_target() -> Node3D:
	var best: Node3D = null
	var best_d := CHASE_R if not _north_of_river(global_position) else RANGE
	for c in Game.allies + [Game.player] + VoertuigSchade.doelen():   # ook jouw jeep en tank, ook leeg geparkeerd (V3, keuze 6A)
		if c == null or not is_instance_valid(c) or c.get("dead") == true:
			continue
		if c is Ally and c.onraakbaar():
			continue
		var d := _flat_dist((c as Node3D).global_position)
		if d < best_d and (d > RANGE or _clear_shot((c as Node3D).global_position + Vector3.UP * 1.3)):
			best_d = d
			best = c
	return best


func _clear_shot(aim_pos: Vector3) -> bool:
	if _monding == null:
		return true
	var q := PhysicsRayQueryParameters3D.create(_monding.global_position, aim_pos, Bullet.MASK_WALL | Bullet.MASK_BUNKER | Bullet.MASK_NATURE | Bullet.MASK_FORTIFICATION)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _shoot(aim_pos: Vector3) -> void:
	var from := _monding.global_position
	var fwd := -_gun.global_transform.basis.z
	var flat := maxf(Vector2(aim_pos.x - from.x, aim_pos.z - from.z).length(), 0.1)
	if flat > RANGE:
		_cool = 0.2
		return   # nog te ver: eerst dichterbij rijden
	if not _clear_shot(aim_pos):
		_cool = 0.3
		return
	_shots += 1
	if _shots >= BURST:
		_shots = 0
		_cool = PAUSE
	else:
		_cool = FIRE_RATE
	var angle := atan2(fwd.x, fwd.z) + randf_range(-SPREAD, SPREAD)
	var rise := (aim_pos.y - from.y) / flat
	var round_ := Bullet.fire(get_parent(), from, angle, BULLET_SPEED, DAMAGE, (RANGE + 4.0) / BULLET_SPEED, false, false, 0, 0, 0, rise)
	round_.src = "m2"   # zo raakt hij ook jouw soldaten (die geen botslaag hebben)
	Fx.muzzle(get_parent(), from)
	Sfx.play("mg", 0.35, global_position)


func _set_firing(on: bool) -> void:
	if on == _firing:
		return
	_firing = on
	if _anim == null or not _anim.has_animation("Vuren"):
		return
	if on:
		_anim.play("Vuren", 0.05)
	else:
		_anim.stop()
		if _mg != null:
			_mg.transform = _mg_base
		if _lijf != null:
			_lijf.transform = _lijf_base


func _animate(delta: float) -> void:
	for w in _wheels:
		(w as Node3D).rotation.x = wrapf((w as Node3D).rotation.x - _speed * delta / WHEEL_R, -PI, PI)
	for s in _stuur:
		(s as Node3D).rotation.y = _steer
	if _body == null:
		return
	var amp := clampf(absf(_speed) / 6.0, 0.15, 1.0)
	var bounce := (0.012 * sin(_time * 9.0) + 0.006 * sin(_time * 15.7)) * amp
	var pitch := clampf(_accel * 0.01, -0.05, 0.05) + 0.004 * sin(_time * 7.3) * amp
	var roll := clampf(-_yaw_rate * _speed * 0.006, -0.07, 0.07)
	_body.transform = _body_base * Transform3D(Basis.from_euler(Vector3(pitch, 0, roll)), Vector3(0, bounce, 0))


func _update_bar() -> void:
	var player: Node3D = Game.player
	var dist := player.global_position.distance_to(global_position) if player != null and is_instance_valid(player) else INF
	_bar.visible = dist < 80.0
	if _bar.visible:
		var f := clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
		_bar_fill.scale.x = maxf(f, 0.001)
		_bar_fill.position.x = -(1.0 - f) * (BAR_W - 0.12) * 0.5


func _flat_dist(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()
