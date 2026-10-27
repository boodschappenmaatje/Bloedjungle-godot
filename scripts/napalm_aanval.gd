class_name NapalmAanval
extends Node3D
## Killstreak NAPALM-AANVAL: een straaljager (assets/straaljager.glb) scheert laag over een strook van NAPALM_LENGTH x NAPALM_WIDTH meter
## en laat vier napalmbussen vallen die elk op een vast punt van de strook neerkomen. Elke bus ontploft in een vuurbal en laat
## brandende napalm achter; vijanden die in de strook staan of erin lopen vatten vlam, rennen 5 s panisch rond en vallen dan dood. De speler brandt een beetje mee als hij erin staat.
## Schade telt als "lucht": die kills tellen niet mee voor je eigen streak.

const JET := preload("res://assets/straaljager.glb")
const SPEED := 58.0       # m/s
const HEIGHT := 13.0      # m boven de grond
const LEAD := 80.0        # m voor de strook waar het toestel begint
const FALL_V := 20.0      # m/s vooruitsnelheid van een losgelaten bus
const GRAVITY := 22.0
const BURN_TIME := 9.0
const BURN_RUN := 5.0     # s dat een vijand brandend rondrent voor hij dood neervalt (enemy.gd: ignite)
const SELF_DPS := 8.0
const TICK := 0.25
const CARPET := preload("res://shaders/napalm_vuur.gdshader")
const WAVE_SPEED := 7.0   # m/s waarmee het vuur vanaf een inslag langs de strook uitrolt
const REACH := 5.0        # m die het vuur vanaf een inslag bereikt: de vier inslagen overlappen, de uiteinden steken een stuk door
const FLAME_STEP := 1.8   # m tussen de vlammen langs de strook
const FADE_TIME := 2.0    # s waarin het vuur aan het eind dooft

var center := Vector3.ZERO
var dir := Vector3.FORWARD
var jet: Node3D
var _t := 0.0
var _bombs: Array = []        # [{node, released, hit, at (inslagpunt), s (positie langs de strook waar hij valt)}]
var _impacts: Array[Vector3] = []
var _burn_t := -1.0
var _tick := 0.0
var _fires: Array = []
var _carpet: MeshInstance3D
var _carpet_mat: ShaderMaterial
var _flames: Array = []       # [{s, lane, h, node, die}] vlammen die meekomen met de vuurgolf
var _first_hit := -1.0
var _passed := false


func start(target: Vector3, d: Vector3) -> void:
	center = Vector3(target.x, 0.0, target.z)
	dir = Vector3(d.x, 0.0, d.z).normalized()
	if dir.length() < 0.1:
		dir = Vector3.FORWARD
	jet = JET.instantiate()
	add_child(jet)
	jet.top_level = true
	jet.scale = Vector3.ONE * 0.8   # 13 m lang: past op het scherm en leest als een toestel boven de strook
	_place(-LEAD - Streak.NAPALM_LENGTH * 0.5)
	jet.rotation.y = atan2(-dir.x, -dir.z)
	var ap: AnimationPlayer = jet.find_child("AnimationPlayer", true, false)
	if ap != null and ap.has_animation("Vliegen"):   # Godot haalt het -loop-achtervoegsel van de clipnaam en laat hem lussen
		ap.play("Vliegen")
	var kinds := ["Bom1", "Bom2", "Bom3", "Bom4"]
	for i in kinds.size():
		var node: Node3D = jet.find_child(kinds[i], true, false)
		var s_along := -Streak.NAPALM_LENGTH * 0.5 + Streak.NAPALM_LENGTH * float(i) / float(kinds.size() - 1)
		_bombs.append({"node": node, "released": false, "hit": false, "s": s_along, "at": center + dir * s_along})
	Game.banner.emit("NAPALM ONDERWEG", "Blijf uit de strook", 1.5)
	Sfx.jet_on()


## Geluid van het toestel: luider naarmate hij dichterbij komt, hoger op de heenweg en lager op de terugweg (dopplereffect),
## en een dreun als hij over het midden van de strook scheert.
func _jet_sound(s: float) -> void:
	var ear_at: Vector3 = center
	if Game.player != null and is_instance_valid(Game.player):
		ear_at = Game.player.global_position
	var to_ear: Vector3 = ear_at - jet.global_position
	var d := to_ear.length()
	var v_r := dir.dot(to_ear / maxf(d, 0.1))   # +1: recht op je af, -1: recht van je weg
	Sfx.jet_set(1.8 * exp(-d / 60.0) + 0.04, 1.0 + 0.3 * v_r)
	if not _passed and s >= 0.0:
		_passed = true
		Sfx.play("straal", 1.0)
		Sfx.play("boom", 0.5, center)


## Zet het toestel op afstand s (m) langs de strook; s = 0 is het midden.
func _place(s: float) -> void:
	jet.global_position = center + dir * s + Vector3.UP * HEIGHT


func _physics_process(delta: float) -> void:
	if Game.state != "play" and Game.state != "prep":
		Sfx.jet_set(0.0, 1.0)
		return
	_t += delta
	if jet != null:
		var s := -LEAD - Streak.NAPALM_LENGTH * 0.5 + SPEED * _t
		_place(s)
		_jet_sound(s)
		var lead := FALL_V * sqrt(2.0 * (HEIGHT - 1.0) / GRAVITY)
		for b in _bombs:
			if not b.released and s >= float(b.s) - lead:
				_release(b)
		if s > LEAD + Streak.NAPALM_LENGTH:
			jet.queue_free()
			jet = null
			Sfx.jet_off()
	_update_carpet(delta)
	if not _impacts.is_empty():
		# vanaf de eerste inslag brandt het: wie in een brandende strook staat of erin loopt, vat vlam
		_burn_t = maxf(_burn_t, 0.0) + delta
		_tick -= delta
		if _tick <= 0.0:
			_tick = TICK
			_burn_damage()
		var all_hit := true
		for b in _bombs:
			if not b.hit:
				all_hit = false
		if all_hit and _burn_t > BURN_TIME and jet == null:
			for f in _fires:
				if is_instance_valid(f):
					f.queue_free()
			for f in _flames:
				if f.node != null and is_instance_valid(f.node):
					f.node.queue_free()
			if _carpet != null:
				_carpet.queue_free()
			queue_free()


func _release(b: Dictionary) -> void:
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
		bomb.global_position = Vector3(b.at.x, HEIGHT - 0.5, b.at.z)
	b["fly"] = bomb
	b["t"] = 0.0
	b["from"] = bomb.global_position
	Sfx.play("click", 0.5, bomb.global_position)


func _process(delta: float) -> void:
	for b in _bombs:
		if b.released and not b.hit and b.has("fly"):
			var bomb: Node3D = b.fly
			b.t += delta
			var fall := sqrt(2.0 * (float(b["from"].y) - 0.3) / GRAVITY)
			var k := clampf(float(b.t) / fall, 0.0, 1.0)
			var flat: Vector3 = (b["from"] as Vector3).lerp(b.at, k)
			bomb.global_position = Vector3(flat.x, float(b["from"].y) * (1.0 - k * k) + 0.3 * k * k, flat.z)
			# de neus draait naar beneden tijdens de val
			bomb.rotation = Vector3(-k * 1.0, atan2(-dir.x, -dir.z), 0.0)
			if k >= 1.0:
				_impact(b)
				bomb.queue_free()


func _impact(b: Dictionary) -> void:
	b.hit = true
	var at: Vector3 = b.at
	_impacts.append(at)
	var parent := get_parent()
	Fx.explosion(parent, at, 0.9)
	Sfx.play("napalm", 1.0, at)
	Game.note_blast(at, 3.5)
	b["t_hit"] = _t
	if _first_hit < 0.0:
		_first_hit = _t
		_make_carpet()
	# één vlam met schijnsel op de inslag zelf; de rest van het vuur is het tapijt
	_fires.append(Fx.flame(parent, at, randf_range(1.6, 2.2), true))
	_fires.append(Fx.burning(parent, at, false))
	Game.alert(at, 16.0, 4.0)


func _in_strip(p: Vector3) -> bool:
	for at: Vector3 in _impacts:
		var d := Vector3(p.x - at.x, 0.0, p.z - at.z)
		var along := d.dot(dir)
		var across := absf(d.dot(dir.cross(Vector3.UP)))
		if absf(along) < 4.4 and across < Streak.NAPALM_WIDTH * 0.5 + 0.8:
			return true
	return false


func _burn_damage() -> void:
	for e in Game.enemies.duplicate():
		if is_instance_valid(e) and not e.dead and _in_strip(e.global_position):
			e.ignite(BURN_RUN)   # in de brandende strook: vlam vat, 5 s rennen, dan neer
	var p = Game.player
	if p != null and is_instance_valid(p) and not p.dead and _in_strip(p.global_position):
		p.hit(SELF_DPS * TICK, dir, false)


## Het brandende veld: een gloeiende grondlaag over de hele strook en rijen lage vlammen die meekomen met de vuurgolf.
func _make_carpet() -> void:
	var length := Streak.NAPALM_LENGTH + 2.0 * REACH
	var plane := PlaneMesh.new()
	plane.size = Vector2(length, Streak.NAPALM_WIDTH + 1.0)
	_carpet = MeshInstance3D.new()
	_carpet.mesh = plane
	_carpet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_carpet_mat = ShaderMaterial.new()
	_carpet_mat.shader = CARPET
	_carpet_mat.set_shader_parameter("wave_speed", WAVE_SPEED)
	_carpet_mat.set_shader_parameter("max_reach", REACH)
	_carpet_mat.set_shader_parameter("half_width", Streak.NAPALM_WIDTH * 0.5 + 0.5)
	_carpet.material_override = _carpet_mat
	get_parent().add_child(_carpet)
	_carpet.global_position = center + Vector3.UP * 0.06
	_carpet.rotation.y = atan2(-dir.z, dir.x) + 0.0   # lokale x = langs de strook
	var side := dir.cross(Vector3.UP)
	var n := int(ceil(length / FLAME_STEP))
	for i in n:
		var s := -length * 0.5 + (float(i) + 0.5) * FLAME_STEP
		for lane_sign in [-1.0, 1.0]:   # twee vlammen per stap, links en rechts van de middenlijn
			var lane: float = lane_sign * randf_range(0.4, 1.5)
			_flames.append({"s": s + randf_range(-0.4, 0.4), "lane": lane, "h": randf_range(1.0, 1.7), "node": null, "die": randf() * FADE_TIME, "side": side})


## Vuurgolf: vlammen verschijnen zodra het vuur van een inslag ze bereikt en doven aan het eind.
func _update_carpet(_delta: float) -> void:
	if _carpet == null:
		return
	var imp_s := Vector4(-1000, -1000, -1000, -1000)
	var imp_t := Vector4(-1, -1, -1, -1)
	for i in _bombs.size():
		var b: Dictionary = _bombs[i]
		if b.hit:
			imp_s[i] = float(b.s)
			imp_t[i] = _t - float(b.t_hit)
	_carpet_mat.set_shader_parameter("imp_s", imp_s)
	_carpet_mat.set_shader_parameter("imp_t", imp_t)
	var since := _t - _first_hit
	var left := BURN_TIME - since
	_carpet_mat.set_shader_parameter("fade", clampf(left / FADE_TIME, 0.0, 1.0))
	for f in _flames:
		if f.node == null:
			if left <= FADE_TIME:
				continue
			for b in _bombs:
				if b.hit and absf(float(f.s) - float(b.s)) <= REACH and (_t - float(b.t_hit)) * WAVE_SPEED >= absf(float(f.s) - float(b.s)):
					var pos: Vector3 = center + dir * float(f.s) + (f.side as Vector3) * float(f.lane)
					f.node = Fx.flame(get_parent(), pos, float(f.h), false)
					break
		elif not is_instance_valid(f.node):
			continue
		elif left < float(f.die):
			f.node.queue_free()
	if left <= 0.0:
		_carpet.queue_free()
		_carpet = null


func _exit_tree() -> void:
	Sfx.jet_off()
