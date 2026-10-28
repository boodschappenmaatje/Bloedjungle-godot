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
const BURN_TIME := 10.0
const BURN_RUN := 5.0     # s dat een vijand brandend rondrent voor hij dood neervalt (enemy.gd: ignite)
const SELF_DPS := 8.0
const TICK := 0.25
const CARPET := preload("res://shaders/napalm_vuur.gdshader")
const WAVE_SPEED := 7.0   # m/s waarmee het vuur vanaf een inslag langs de strook uitrolt
const REACH := 5.0        # m die het vuur vanaf een inslag bereikt: de vier inslagen overlappen, de uiteinden steken een stuk door
const FLAME_STEP := 1.8   # m tussen de vlammen langs de strook
const AFTER_TIME := 16.0  # s dat er na het vuur nog rook en een verkoolde strook blijven
const SMOKE_LIFE := 6.5   # s dat een rookpluim omhoog trekt
const FADE_TIME := 2.0    # s waarin het vuur aan het eind dooft
const IGNITE_DELAY := 0.22   # s tussen het openbarsten van het vat (nevel) en de ontsteking
const PUDDLE := preload("res://shaders/napalm_plas.gdshader")

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
var _smokes: Array = []       # rookpluimen: blijven nog even na het vuur
var _after_t := -1.0          # s sinds het vuur uit is (< 0: het brandt nog)
var _puddles: Array = []      # [{node, mat, t0}] uitdijende brandende plassen met grondgloed


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
		if _tick <= 0.0 and _after_t < 0.0:
			_tick = TICK
			_burn_damage()
		var all_hit := true
		for b in _bombs:
			if not b.hit:
				all_hit = false
		if all_hit and _burn_t > BURN_TIME and jet == null and _after_t < 0.0:
			_start_smolder()
	if _after_t >= 0.0:
		_after_t += delta
		if _after_t > AFTER_TIME - SMOKE_LIFE - 1.0:
			for sm in _smokes:   # geen nieuwe rook meer; wat er hangt trekt nog weg
				if is_instance_valid(sm):
					for c in sm.get_children():
						if c is CPUParticles3D:
							c.emitting = false
		if _after_t > AFTER_TIME:
			for sm in _smokes:
				if is_instance_valid(sm):
					sm.queue_free()
			if _carpet != null:
				_carpet.queue_free()
			queue_free()


## Het vuur is uit: lampen, vonken en vlammen weg; er blijven rook en een verkoolde strook, die langzaam verdwijnen.
func _start_smolder() -> void:
	_after_t = 0.0
	for f in _fires:
		if is_instance_valid(f):
			f.queue_free()
	for f in _flames:
		if f.node != null and is_instance_valid(f.node):
			f.node.queue_free()
	# extra pluimen tussen de inslagen, zodat de hele strook rookt
	for i in _bombs.size() - 1:
		var mid: Vector3 = ((_bombs[i].at as Vector3) + (_bombs[i + 1].at as Vector3)) * 0.5
		_smokes.append(_smolder(get_parent(), mid))
	for b in _bombs:
		_smokes.append(_smolder(get_parent(), b.at))


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
	b["ph"] = randf() * TAU            # elke bom tolt anders
	b["wob"] = randf_range(0.7, 1.4)
	b["spin"] = randf_range(-3.5, 3.5)
	Sfx.play("click", 0.5, bomb.global_position)
	# fluitend vallen: de toon wordt luider naarmate hij de grond nadert (volume loopt in _process)
	var whistle := AudioStreamPlayer3D.new()
	whistle.stream = Sfx.fluit
	whistle.volume_db = -26.0
	whistle.unit_size = 14.0
	whistle.max_distance = 70.0
	bomb.add_child(whistle)
	whistle.play()
	b["whistle"] = whistle
	# dunne rook- en vloeistofspoor achter de bom
	var trail := Fx._puff(26, 1.1, 0.55, false, Fx._ramp([Color(0.8, 0.8, 0.75, 0.0), Color(0.75, 0.75, 0.7, 0.32), Color(0.6, 0.6, 0.58, 0.0)], [0.0, 0.15, 1.0]), Vector2(0.1, 0.5), 2.6)
	trail.spread = 25.0
	trail.gravity = Vector3.ZERO
	get_parent().add_child(trail)
	trail.global_position = bomb.global_position
	trail.emitting = true
	b["trail"] = trail


func _process(delta: float) -> void:
	for b in _bombs:
		if b.released and not b.hit and b.has("fly"):
			var bomb: Node3D = b.fly
			b.t += delta
			var fall := sqrt(2.0 * (float(b["from"].y) - 0.3) / GRAVITY)
			var k := clampf(float(b.t) / fall, 0.0, 1.0)
			var flat: Vector3 = (b["from"] as Vector3).lerp(b.at, k)
			bomb.global_position = Vector3(flat.x, float(b["from"].y) * (1.0 - k * k) + 0.3 * k * k, flat.z)
			# de neus draait naar beneden, met een bom die slingert en tolt: hoe langer de val, hoe wilder
			var tt: float = b.t
			var ph: float = b.ph
			var w: float = b.wob
			var unrest := 0.35 + 0.65 * k
			bomb.rotation = Vector3(-k * 1.0 + sin(tt * 6.0 * w + ph) * 0.38 * unrest,
				atan2(-dir.x, -dir.z) + sin(tt * 4.1 * w + ph * 1.7) * 0.3 * unrest,
				tt * float(b.spin) + sin(tt * 9.0 + ph) * 0.4)
			var wh: AudioStreamPlayer3D = b.whistle
			if is_instance_valid(wh):
				wh.volume_db = lerpf(-26.0, 0.0, k * k)
				wh.pitch_scale = lerpf(1.25, 0.8, k)
			var tr: CPUParticles3D = b.trail
			if is_instance_valid(tr):
				tr.global_position = bomb.global_position
			if k >= 1.0:
				if is_instance_valid(tr):
					tr.emitting = false
					get_tree().create_timer(1.5).timeout.connect(tr.queue_free)
				_impact(b)
				bomb.queue_free()


func _impact(b: Dictionary) -> void:
	b.hit = true
	var at: Vector3 = b.at
	_impacts.append(at)
	var parent := get_parent()
	Game.note_blast(at, 3.5)
	# eerst barst het vat open: een kort wolkje vloeistofnevel, nog zonder vuur
	b["t_hit"] = _t + IGNITE_DELAY
	if _first_hit < 0.0:
		_first_hit = _t + IGNITE_DELAY
		_make_carpet()
	Sfx.play("thud", 0.9, at)
	_mist(parent, at)
	Game.alert(at, 16.0, 4.0)
	get_tree().create_timer(IGNITE_DELAY).timeout.connect(_ignite.bind(at))


## Het "wuuf": de nevel vat vlam. Een lage, rollende vuurbal langs de grond in plaats van één hoge bal.
func _ignite(at: Vector3) -> void:
	var parent := get_parent()
	if parent == null or _after_t >= 0.0:
		return
	Fx.explosion(parent, at, 0.55)
	Sfx.play("napalm", 1.0, at)
	Sfx.play("wuuf", 1.0, at)
	for sgn in [-1.0, 1.0]:
		_roll(parent, at, dir * sgn)
	_fires.append(_impact_light(parent, at))
	_fires.append(_embers(parent, at))
	_smokes.append(_smoke(parent, at))
	_char(parent, at)
	_puddle(parent, at)


## Kort, bleek vloeistofwolkje op het moment dat het vat openbarst.
func _mist(parent: Node, at: Vector3) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = at + Vector3(0, 0.5, 0)
	var m := Fx._puff(14, 0.5, 2.6, false, Fx._ramp([Color(0.85, 0.8, 0.65, 0.0), Color(0.85, 0.8, 0.65, 0.5), Color(0.8, 0.78, 0.7, 0.0)], [0.0, 0.2, 1.0]), Vector2(3.0, 6.0), 2.4)
	m.spread = 85.0
	m.gravity = Vector3.ZERO
	m.one_shot = true
	m.explosiveness = 1.0
	root.add_child(m)
	m.emitting = true
	get_tree().create_timer(1.2).timeout.connect(root.queue_free)


## Vuurtong die laag over de grond uitrolt (langs de strook) in plaats van omhoog.
func _roll(parent: Node, at: Vector3, d: Vector3) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = at + Vector3(0, 0.6, 0)
	var r := Fx._puff(22, 0.85, 2.4, true, Fx._ramp([Color(1.0, 0.9, 0.5, 0.0), Color(1.0, 0.65, 0.2, 0.9), Color(0.7, 0.15, 0.03, 0.0)], [0.0, 0.2, 1.0]), Vector2(8.0, 13.0), 1.5)
	r.direction = d
	r.spread = 14.0
	r.gravity = Vector3.ZERO
	r.one_shot = true
	r.explosiveness = 0.85
	root.add_child(r)
	r.emitting = true
	get_tree().create_timer(1.6).timeout.connect(root.queue_free)


## Verkoolde sporen: zwarte vlekken rond de inslag die blijven liggen als het vuur uit is.
func _char(parent: Node, at: Vector3) -> void:
	var side := dir.cross(Vector3.UP)
	var half := Streak.NAPALM_WIDTH * 0.5
	Fx.decal(parent, at, Vector3.UP, "scorch", 6.0, 140.0)
	for i in 3:
		var p := at + dir * randf_range(-3.2, 3.2) + side * randf_range(-half, half)
		Fx.decal(parent, p, Vector3.UP, "scorch", randf_range(2.0, 4.0), 140.0)


## Uitdijende brandende plas met gloed op de grond rond de inslag.
func _puddle(parent: Node, at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(9.0, 9.0)
	mi.mesh = pm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = PUDDLE
	mat.set_shader_parameter("seed", randf() * 20.0)
	mi.material_override = mat
	parent.add_child(mi)
	mi.global_position = at + Vector3.UP * 0.08
	mi.rotation.y = randf() * TAU
	_fires.append(mi)
	_puddles.append({"node": mi, "mat": mat, "t0": _t})


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
	var half := Streak.NAPALM_WIDTH * 0.5
	for i in n:
		var s := -length * 0.5 + (float(i) + 0.5) * FLAME_STEP
		var edge := smoothstep(0.55, 1.0, absf(s) / (length * 0.5))   # aan de uiteinden van de strook wordt het vuur lager
		for lane_sign in [-1.0, 1.0]:   # twee rijen, tegen elkaar verspringend, zodat het één aaneengesloten vuurwand is
			var lane: float = lane_sign * randf_range(0.7, 1.4)
			var shift := FLAME_STEP * 0.5 * (0.0 if lane_sign < 0.0 else 1.0)
			var h := randf_range(2.4, 4.8)
			var roll := randf()
			if roll < 0.15:
				h = randf_range(1.5, 2.2)       # lage plekken
			elif roll > 0.85:
				h = randf_range(5.0, 5.8)       # uitschieters
			h *= lerpf(1.0, 0.55, edge)
			_flames.append({"s": s + shift + randf_range(-0.3, 0.3), "lane": lane, "h": h, "w": randf_range(3.2, 4.6) * lerpf(1.0, 0.7, edge), "node": null, "born": 0.0, "die": randf(), "side": side, "ph": randf() * TAU, "fr": randf_range(7.0, 14.0)})
		if randf() < 0.55:   # losse brandhaardjes tussen de planten, ook buiten de twee rijen
			_flames.append({"s": s + randf_range(-0.9, 0.9), "lane": randf_range(-half, half), "h": randf_range(0.9, 1.7), "w": randf_range(1.3, 2.2), "node": null, "born": 0.0, "die": randf(), "side": side, "ph": randf() * TAU, "fr": randf_range(9.0, 18.0)})


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
	_carpet_mat.set_shader_parameter("after", 1.0 if _after_t < 0.0 else clampf(1.0 - _after_t / AFTER_TIME, 0.0, 1.0))
	for f in _flames:
		if f.node == null:
			if left <= FADE_TIME:
				continue
			for b in _bombs:
				if b.hit and absf(float(f.s) - float(b.s)) <= REACH and (_t - float(b.t_hit)) * WAVE_SPEED >= absf(float(f.s) - float(b.s)):
					var pos: Vector3 = center + dir * float(f.s) + (f.side as Vector3) * float(f.lane)
					f.node = _make_flame(pos, float(f.w), float(f.h))
					f.born = _t
					break
		elif is_instance_valid(f.node):
			# groeit in en krimpt aan het eind weg, de ene vlam eerder dan de andere
			var g := minf((_t - float(f.born)) / 0.9, 1.0) * clampf(left / (FADE_TIME * (0.5 + 0.5 * float(f.die))), 0.0, 1.0)
			g *= 0.86 + 0.14 * sin(_t * float(f.fr) + float(f.ph))   # flikkert
			(f.node as GeometryInstance3D).set_instance_shader_parameter("grow", g)


	var glow := clampf(left / FADE_TIME, 0.0, 1.0) * (1.0 if _after_t < 0.0 else clampf(1.0 - _after_t / 3.0, 0.0, 1.0))
	for pd in _puddles:
		if is_instance_valid(pd.node):
			(pd.mat as ShaderMaterial).set_shader_parameter("t", _t - float(pd.t0))
			(pd.mat as ShaderMaterial).set_shader_parameter("fade", glow)


## Eén vlamtong op wereldpositie pos; hij begint ingeklapt en groeit in (grow).
func _make_flame(pos: Vector3, w: float, h: float) -> MeshInstance3D:
	var mi := Fx.napalm_flame(get_parent(), Vector3.ZERO, w, h)
	mi.global_position = pos
	mi.set_instance_shader_parameter("grow", 0.0)
	return mi


## Flikkerend oranje schijnsel op de inslag: het vuur verlicht de grond, de omgeving en de speler.
func _impact_light(parent: Node, at: Vector3) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.5, 0.18)
	l.light_energy = 4.0
	l.omni_range = 11.0
	l.shadow_enabled = false
	parent.add_child(l)
	l.global_position = at + Vector3(0, 2.2, 0)
	var tw := l.create_tween().set_loops()
	tw.tween_property(l, "light_energy", 2.6, 0.12)
	tw.tween_property(l, "light_energy", 5.0, 0.17)
	tw.tween_property(l, "light_energy", 3.4, 0.1)
	return l


## Vonken en brandende druppels die omhoog spatten.
func _embers(parent: Node, at: Vector3) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = at
	var e := Fx._puff(14, 1.6, 0.14, true, Fx._ramp([Color(1, 0.9, 0.5, 0.0), Color(1, 0.6, 0.15, 1.0), Color(0.7, 0.12, 0.02, 0.0)], [0.0, 0.15, 1.0]), Vector2(3.0, 7.0), 0.4)
	e.spread = 70.0
	e.gravity = Vector3(0, -3.5, 0)
	root.add_child(e)
	e.emitting = true
	return root


## Lichte rook: doorschijnend en hoog, zodat de strook zichtbaar blijft.
func _smoke(parent: Node, at: Vector3) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = at + Vector3(0, 2.4, 0)
	var sm := Fx._puff(7, 4.0, 3.2, false, Fx._ramp([Color(0.1, 0.09, 0.08, 0.0), Color(0.14, 0.13, 0.12, 0.34), Color(0.2, 0.19, 0.18, 0.0)], [0.0, 0.25, 1.0]), Vector2(1.0, 2.0), 2.4)
	root.add_child(sm)
	sm.emitting = true
	return root


## Nablussende rook: dunne grijze pluimen die breder worden, met de wind meedrijven en uitdoven. Geen vuur meer, wel zichtbaar.
func _smolder(parent: Node, at: Vector3) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = at + Vector3(0, 0.4, 0)
	var g := 0.5
	var sm := Fx._puff(22, SMOKE_LIFE, 3.0, false, Fx._ramp([Color(g, g, g, 0.0), Color(g, g, g, 0.8), Color(g + 0.05, g + 0.05, g + 0.05, 0.6), Color(g + 0.1, g + 0.1, g + 0.1, 0.0)], [0.0, 0.12, 0.65, 1.0]), Vector2(0.9, 1.8), 1.0)
	var grow := Curve.new()
	grow.max_value = 4.0
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(1.0, 2.6))
	sm.scale_amount_curve = grow
	sm.gravity = Vector3(0.4, 0.5, 0.12)
	root.add_child(sm)
	sm.emitting = true
	return root


func _exit_tree() -> void:
	Sfx.jet_off()
