class_name LuchtAanval
extends Node3D
## Kracht LUCHTAANVAL (generaalsrang E2, Rang): een P-47 (assets/p47.glb, Dennis' eigen model, door mij geanimeerd) scheert laag over een strook van
## LUCHT_LENGTH x LUCHT_WIDTH meter. Hij beschiet de strook met zijn acht mitrailleurs, laat twee bommen vallen (niveau 2: ook vier raketten) en
## op niveau 3 komt er twee seconden later een tweede toestel achteraan. Vijandelijke M2-torens en voertuigen mogen het toestel raken (vonken en
## rook), maar halen hem niet neer. Schade telt als "lucht" (geen bevestigde treffer van de speler).

const P47_PAD := "res://assets/p47.glb"   # 4 MB: pas laden als het nodig is (zie tests/ota_vroeg_test.gd)
const SPEED := 40.0        # m/s: sneller dan de straaljager van napalm, een propellertoestel in duikvlucht
const HEIGHT := 12.0       # m boven de grond
const LEAD := 80.0         # m voor de strook waar het toestel begint
const BURST_EVERY := 0.06  # s tussen twee mitrailleurgarven
const GUN_AHEAD := 9.0     # m voor het toestel waar de kogels de grond raken
const GUN_RADIUS := 1.7    # m rond een inslag waar een kogel schade doet
const GUN_DAMAGE := 26.0
const BOMB_RADIUS := 4.8
const BOMB_DAMAGE := 300.0
const ROCKET_RADIUS := 3.2
const ROCKET_DAMAGE := 190.0
const FALL_V := 40.0       # m/s vooruitsnelheid van een bom (toestel snelheid)
const GRAVITY := 22.0
const ROCKET_FLIGHT := 0.55

var center := Vector3.ZERO
var dir := Vector3.FORWARD
var niveau := 1
var primary := true         # alleen het eerste toestel bepaalt het geluid
var delay := 0.0            # s wachten voor dit toestel begint (tweede toestel op niveau 3)
var plane: Node3D
var _t := 0.0
var _gun_t := 0.0
var _hit_t := 0.0
var _bombs: Array = []      # [{node, s, released, fly, t, from, at}]
var _rockets: Array = []    # [{node, s, fired}]
var _flash_i := 0
var _jet_light: OmniLight3D
var _jet_shadow: MeshInstance3D
var _smoke: CPUParticles3D
var _hits := 0


## Roept het toestel (of twee) aan. dir is de aanvalsrichting.
static func start_aanval(main: Node, at: Vector3, d: Vector3, n: int) -> void:
	var count := 2 if n >= 3 else 1
	for i in count:
		var a := LuchtAanval.new()
		a.niveau = n
		a.primary = i == 0
		a.delay = 2.0 * float(i)
		main.add_child(a)
		a.start(at, d, i == 1)
	Game.banner.emit("LUCHTAANVAL ONDERWEG", "P-47 komt eraan · blijf uit de strook", 1.6)


## Schade aan alles van de vijand rond een punt. Static zodat de test het direct kan aanroepen.
static func schade(at: Vector3, radius: float, dmg: float) -> int:
	VijandHk.blast(at, radius, dmg)
	VijandM2Toren.blast(at, radius, dmg)
	Garnizoen.blast(at, radius, dmg, "vijand")
	var hits := 0
	for e in Game.enemies.duplicate():
		if not is_instance_valid(e) or e.get("dead") == true:
			continue
		var flat := Vector3(e.global_position.x - at.x, 0.0, e.global_position.z - at.z)
		var d := flat.length() - float(e.t.get("r", 0.4))
		if d < radius:
			var k := 1.0 - clampf(maxf(d, 0.0) / radius, 0.0, 1.0) * 0.6
			Game.hit_src = "lucht"
			e.hit(dmg * k, flat.normalized() if flat.length() > 0.01 else Vector3.UP, true)
			Game.hit_src = "speler"
			hits += 1
	return hits


func start(target: Vector3, d: Vector3, second := false) -> void:
	center = Vector3(target.x, 0.0, target.z)
	dir = Vector3(d.x, 0.0, d.z).normalized()
	if dir.length() < 0.1:
		dir = Vector3.FORWARD
	var packed := load(P47_PAD) as PackedScene
	plane = packed.instantiate()
	add_child(plane)
	plane.top_level = true
	plane.visible = false
	_place(-LEAD - Rang.LUCHT_LENGTH * 0.5)
	plane.rotation.y = atan2(-dir.x, -dir.z)
	var ap: AnimationPlayer = plane.find_child("AnimationPlayer", true, false)
	if ap != null and ap.has_animation("Vliegen"):   # Godot haalt het -loop-achtervoegsel van de clipnaam en laat hem lussen
		ap.play("Vliegen")
	for i in 2:
		var node: Node3D = plane.find_child("Bom%d" % (i + 1), true, false)
		var s_along := -6.0 + 12.0 * float(i) + (2.5 if second else 0.0)
		_bombs.append({"node": node, "s": s_along, "released": false, "hit": false, "at": center + dir * s_along})
	for i in 4:
		var node: Node3D = plane.find_child("Raket%d" % (i + 1), true, false)
		if node != null:
			node.visible = niveau >= 2
		var s_along := -13.0 + 8.7 * float(i)
		_rockets.append({"node": node, "s": s_along, "fired": false})
	for i in 2:   # de bommen onder de vleugels blijven bij niveau 1 en 2 net zo goed zichtbaar
		pass
	_jet_visibility()
	if primary:
		Sfx.jet_on()


## Zet het toestel op afstand s (m) langs de strook; s = 0 is het midden.
func _place(s: float) -> void:
	plane.global_position = center + dir * s + Vector3.UP * HEIGHT
	if _jet_light != null and is_instance_valid(_jet_light):
		_jet_light.global_position = plane.global_position + Vector3(0, 1.5, 0)
		_jet_light.light_energy = 2.2 + 1.2 * (0.5 + 0.5 * sin(_t * 9.0))
	if _jet_shadow != null and is_instance_valid(_jet_shadow):
		_jet_shadow.global_position = Vector3(plane.global_position.x, 0.09, plane.global_position.z)


func _jet_visibility() -> void:
	_jet_light = OmniLight3D.new()
	_jet_light.light_color = Color(1.0, 0.93, 0.8)
	_jet_light.omni_range = 18.0
	_jet_light.shadow_enabled = false
	add_child(_jet_light)
	_jet_light.top_level = true
	if NapalmAanval._shadow_shader == null:
		NapalmAanval._shadow_shader = Shader.new()
		NapalmAanval._shadow_shader.code = NapalmAanval.SHADOW_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = NapalmAanval._shadow_shader
	var pm := PlaneMesh.new()
	pm.size = Vector2(12.0, 11.0)
	_jet_shadow = MeshInstance3D.new()
	_jet_shadow.mesh = pm
	_jet_shadow.material_override = mat
	_jet_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_jet_shadow)
	_jet_shadow.top_level = true
	_jet_shadow.rotation.y = atan2(-dir.x, -dir.z)
	_jet_light.visible = false
	_jet_shadow.visible = false


func _jet_sound(s: float) -> void:
	var ear_at: Vector3 = center
	if Game.player != null and is_instance_valid(Game.player):
		ear_at = Game.player.global_position
	var to_ear: Vector3 = ear_at - plane.global_position
	var d := to_ear.length()
	var v_r := dir.dot(to_ear / maxf(d, 0.1))
	Sfx.jet_set(1.5 * exp(-d / 55.0) + 0.04, 0.85 + 0.3 * v_r)


func _physics_process(delta: float) -> void:
	if Game.state != "play" and Game.state != "prep":
		if primary:
			Sfx.jet_set(0.0, 1.0)
		return
	_t += delta
	if _t < delay or plane == null:
		return
	var tt := _t - delay
	if not plane.visible:
		plane.visible = true
		_jet_light.visible = true
		_jet_shadow.visible = true
	var s := -LEAD - Rang.LUCHT_LENGTH * 0.5 + SPEED * tt
	_place(s)
	if primary:
		_jet_sound(s)
	_tick_guns(s, delta)
	_tick_weapons(s)
	_tick_flak(s, delta)
	if s > LEAD + Rang.LUCHT_LENGTH:
		_finish()


func _finish() -> void:
	if plane != null:
		plane.queue_free()
		plane = null
	if _jet_light != null:
		_jet_light.queue_free()
	if _jet_shadow != null:
		_jet_shadow.queue_free()
	if primary:
		Sfx.jet_off()
	for b in _bombs:   # nog in de lucht: laat ze nog even doorvallen
		if b.released and not b.hit:
			return
	queue_free()


## Mitrailleurs: zolang het toestel boven de strook is, schieten de zes snuiten garven die vlak voor hem inslaan.
func _tick_guns(s: float, delta: float) -> void:
	var half := Rang.LUCHT_LENGTH * 0.5
	if s < -half - GUN_AHEAD or s > half - GUN_AHEAD * 0.4:
		return
	_gun_t -= delta
	while _gun_t <= 0.0:
		_gun_t += BURST_EVERY
		var side := dir.cross(Vector3.UP)
		var lane := randf_range(-Rang.LUCHT_WIDTH * 0.5, Rang.LUCHT_WIDTH * 0.5)
		var at := center + dir * (s + GUN_AHEAD) + side * lane
		at.y = 0.0
		_flash_i = (_flash_i + 1) % 6
		var mond: Node3D = plane.find_child("Monding%d" % (_flash_i + 1), true, false)
		if mond != null:
			Fx.muzzle(get_parent(), mond.global_position, "thompson", atan2(dir.x, dir.z))
		_hits += 1
		if _hits % 2 == 0:
			Fx.impact(get_parent(), at, Vector3.UP, "dirt")
		if _hits % 3 == 0:
			Fx.dust(get_parent(), at)
		if _hits % 5 == 0:
			Sfx.play("thud", 0.35, at)
		schade(at, GUN_RADIUS, GUN_DAMAGE)
		if _hits % 8 == 0:
			Sfx.play("ping", 0.4, plane.global_position)


## Bommen en raketten op hun plek langs de strook.
func _tick_weapons(s: float) -> void:
	var lead := FALL_V * sqrt(2.0 * (HEIGHT - 1.0) / GRAVITY)
	for b in _bombs:
		if not b.released and s >= float(b.s) - lead:
			_release_bomb(b)
	for r in _rockets:
		if niveau >= 2 and not r.fired and s >= float(r.s) - 6.0:
			_fire_rocket(r)


func _release_bomb(b: Dictionary) -> void:
	b.released = true
	var src: Node3D = b.node
	var bomb := Node3D.new()
	add_child(bomb)
	bomb.top_level = true
	if src != null:
		for c in src.get_children():
			bomb.add_child(c.duplicate())
		src.visible = false
		bomb.global_transform = src.global_transform
	else:
		bomb.global_position = Vector3(b.at.x, HEIGHT - 0.6, b.at.z)
	b["fly"] = bomb
	b["t"] = 0.0
	b["from"] = bomb.global_position
	b["ph"] = randf() * TAU
	Sfx.play("click", 0.5, bomb.global_position)
	var whistle := AudioStreamPlayer3D.new()
	whistle.stream = Sfx.fluit
	whistle.volume_db = -24.0
	whistle.unit_size = 14.0
	whistle.max_distance = 70.0
	bomb.add_child(whistle)
	whistle.play()
	b["whistle"] = whistle


func _fire_rocket(r: Dictionary) -> void:
	r.fired = true
	var src: Node3D = r.node
	var rk := Node3D.new()
	add_child(rk)
	rk.top_level = true
	var from := plane.global_position + Vector3(0, -0.8, 0)
	if src != null:
		for c in src.get_children():
			rk.add_child(c.duplicate())
		src.visible = false
		from = src.global_position
	var side := dir.cross(Vector3.UP)
	var at := center + dir * (float(r.s) + 20.0) + side * randf_range(-2.4, 2.4)
	at.y = 0.0
	rk.global_position = from
	rk.look_at(at, Vector3.UP)
	Fx.rocket_launch(get_parent(), from, atan2(dir.x, dir.z))
	Fx.rocket_trail(rk)
	Sfx.play("click", 0.6, from)
	var tw := rk.create_tween()
	tw.tween_property(rk, "global_position", at, ROCKET_FLIGHT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_rocket_hit.bind(rk, at))


func _rocket_hit(rk: Node3D, at: Vector3) -> void:
	rk.queue_free()
	var parent := get_parent()
	if parent == null:
		return
	Fx.explosion(parent, at, 0.9)
	Game.note_blast(at, 3.0)
	Sfx.play("boom", 0.7, at)
	schade(at, ROCKET_RADIUS, ROCKET_DAMAGE)


func _process(delta: float) -> void:
	for b in _bombs:
		if b.released and not b.hit and b.has("fly"):
			var bomb: Node3D = b.fly
			b.t += delta
			var fall := sqrt(2.0 * (float(b["from"].y) - 0.3) / GRAVITY)
			var k := clampf(float(b.t) / fall, 0.0, 1.0)
			var flat: Vector3 = (b["from"] as Vector3).lerp(b.at, k)
			bomb.global_position = Vector3(flat.x, float(b["from"].y) * (1.0 - k * k) + 0.3 * k * k, flat.z)
			bomb.rotation = Vector3(-k * 1.1, atan2(-dir.x, -dir.z) + sin(float(b.t) * 5.0 + float(b.ph)) * 0.12, sin(float(b.t) * 7.0 + float(b.ph)) * 0.18)
			var wh: AudioStreamPlayer3D = b.whistle
			if is_instance_valid(wh):
				wh.volume_db = lerpf(-24.0, 0.0, k * k)
				wh.pitch_scale = lerpf(1.25, 0.8, k)
			if k >= 1.0:
				_bomb_impact(b)
				bomb.queue_free()
				var all_done := true
				for o in _bombs:
					if not o.hit:
						all_done = false
				if all_done and plane == null:
					queue_free()


func _bomb_impact(b: Dictionary) -> void:
	b.hit = true
	var at: Vector3 = b.at
	var parent := get_parent()
	Fx.explosion(parent, at, 1.4)
	Game.note_blast(at, 4.0)
	Sfx.play("boom", 1.0, at)
	Fx.decal(parent, at, Vector3.UP, "scorch", 4.5, 120.0)
	Game.alert(at, 16.0, 4.0)
	schade(at, BOMB_RADIUS, BOMB_DAMAGE)


## Luchtafweer: vijandelijke M2-torens en voertuigen in de buurt raken het toestel, dat vonken en rook krijgt maar doorvliegt.
func _tick_flak(_s: float, delta: float) -> void:
	_hit_t -= delta
	if _hit_t > 0.0:
		return
	_hit_t = randf_range(0.16, 0.34)
	var near := false
	for e in Game.enemies:
		if is_instance_valid(e) and e.get("dead") != true:
			var d := Vector2(e.global_position.x - plane.global_position.x, e.global_position.z - plane.global_position.z).length()
			if d < 22.0 and (e.get("armor") != null and String(e.get("armor")) in ["jeep", "tank"]):
				near = true
				break
	if not near:
		near = VijandM2Toren.any_near(plane.global_position, 30.0)
	if not near:
		return
	var spot := plane.global_position + Vector3(randf_range(-2.5, 2.5), randf_range(-0.4, 0.4), randf_range(-2.0, 2.0))
	Fx.spark(get_parent(), spot, Vector3.UP)
	Sfx.play("ping", 0.35, spot)
	if _smoke == null:
		_smoke = Fx._puff(14, 1.4, 0.7, false, Fx._ramp([Color(0.1, 0.1, 0.1, 0.0), Color(0.12, 0.11, 0.1, 0.6), Color(0.2, 0.2, 0.2, 0.0)], [0.0, 0.2, 1.0]), Vector2(0.2, 0.6), 2.0)
		_smoke.gravity = Vector3(0, 0.6, 0)
		_smoke.local_coords = false
		plane.add_child(_smoke)
		_smoke.position = Vector3(0.0, 0.0, 1.2)
		_smoke.emitting = true


func _exit_tree() -> void:
	if primary:
		Sfx.jet_off()
