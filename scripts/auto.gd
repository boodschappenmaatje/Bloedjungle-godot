class_name Auto
extends CharacterBody3D
## Personenauto in de stad (assets/auto.glb, bron/auto/maak_auto.py). Hij staat geparkeerd; loop je erheen, dan verschijnt INSTAPPEN en
## kun je er zelf mee rijden (linker stick sturen en gas, rechter stick = claxon). Voorkant is -Z.
##
## Schade: kogels doen gewone schade, ontploffingen veel meer. Per fase gaat er meer kapot: voorruit, achterruit, banden plat,
## deuren en kap eraf, rook uit de motor, dan brand. Onder 30% brandt hij en ontploft na enkele seconden vanzelf; op 0 meteen.
## De ontploffing is groot: vuurbal, schokgolf, rondvliegende deuren, kap en wielen, schade aan alles binnen 9 m (ook jou),
## kettingreactie naar andere auto's, vaten en pompen. Het verkoolde wrak blijft staan (met collision) en brandt nog even na.
## Zoals bij de brandkraan zijn vuur en rook deeltjes in code (Fx), niet in de glb.

const MODEL := preload("res://assets/auto.glb")
const HP := 700.0
const BULLET_ARMOR := 1.0            # v95: Thompson ~3 s tot brand, pistool ~5,5 s (was 0,5x: veel te lang)
const BLAST_DAMAGE := 560.0          # ontploffing vlakbij; neemt af met de afstand
const BLAST_RADIUS := 9.0            # straal van de ontploffing van de auto zelf
const BLAST_HURT := 380.0            # schade aan vijanden, jou en gebouwen in die straal
const FIRE_AT := 0.30                # onder dit deel van de hp gaat hij branden
const FUSE := Vector2(6.0, 9.0)      # seconden tussen gaan branden en ontploffen
const SPEED := 17.0                  # m/s vooruit
const REVERSE := 4.0
const ACCEL := 7.0
const BRAKE := 10.0
const WHEELBASE := 2.62
const WHEEL_R := 0.335
const MAX_STEER := 0.5
const BOARD_DIST := 4.2
const RAM_DAMAGE := 55.0
const COLORS := [Color("7f2a24"), Color("32496b"), Color("a39673"), Color("49573a"), Color("b9b9b2"), Color("1b1c1e"), Color("6d6f70")]
const STAGES := [0.80, 0.62, 0.48, 0.36]   # hp-deel waaronder de volgende schadefase begint
const WHEELS := ["Wiel_LV", "Wiel_RV", "Wiel_LA", "Wiel_RA"]
const DOORS := ["DeurLV", "DeurRV", "DeurLA", "DeurRA"]

static var all: Array = []
static var driven_car: Auto = null
static var _btn: ActionBtn
static var _cand: Auto
static var _cand_ms := 0
static var _lak_mats := {}

var kind := "auto"
var color_i := 0
var hp := HP
var stage := 0
var burning := false
var exploded := false
var wreck := false
var driven := false
var _shadow: ShadowProxy   # tot het voertuig schade krijgt, bestuurd wordt of wrak is
var _fuse := 0.0
var _speed := 0.0
var _steer := 0.0
var _yaw_rate := 0.0
var _accel := 0.0
var _t := 0.0
var _check := 0.0
var _ram_cd := 0.0
var _alarm := 0.0
var _alarm_beep := 0.0
var _flat := {}
var _gone := {}
var _holes := 0
var _hood_open := false
var _blend := 0.0
var _horn := false
var _blink := 0.0
var _model: Node3D
var _car: Node3D
var _romp: MeshInstance3D
var _anim: AnimationPlayer
var _wheels := {}
var _wheel_pos := {}
var _spin := {}
var _door_rest := {}
var _wrak_mat: Material
var _shape: CollisionShape3D
var _fire: Node3D
var _smoke: Node3D
var _exhaust: CPUParticles3D
var _lamps: Array[SpotLight3D] = []
var _tail: Array = []


static func make(k: String, seed_: int) -> Auto:
	var a := Auto.new()
	a.kind = k
	a.color_i = absi(seed_) % COLORS.size()
	return a


func _ready() -> void:
	all.append(self)
	collision_layer = Barrel.LAYER | Bullet.MASK_VEHICLE      # kogels botsen ertegen en roepen hit() aan; je loopt er niet doorheen
	collision_mask = 114
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	set_meta("impact_material", "metal")
	_shape = CollisionShape3D.new()
	_shape.name = "Shape"
	var b := BoxShape3D.new()
	b.size = Vector3(1.95, 1.5, 4.4)
	_shape.shape = b
	_shape.position = Vector3(0, 0.75, 0)
	add_child(_shape)
	_model = MODEL.instantiate()
	add_child(_model)
	_car = _model.get_node("Auto")
	_romp = _car.get_node("Romp") as MeshInstance3D
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for w in WHEELS:
		_wheels[w] = _car.get_node(w)
		_wheel_pos[w] = (_wheels[w] as Node3D).position
		_spin[w] = 0.0
	for d in DOORS:
		_door_rest[d] = (_car.get_node(d) as Node3D).transform
	_wrak_mat = (_car.get_node("WrakRef") as MeshInstance3D).mesh.surface_get_material(0)
	(_car.get_node("WrakRef") as Node3D).visible = false
	_paint()
	_strip_clips()
	for n in _car.get_children():
		if String(n.name).begins_with("Licht"):
			_tail.append(n)
	_vis_lamps(false)   # de verlichte lenzen kosten elk een draw call: alleen zichtbaar als ze iets doen
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).visibility_range_end = 90.0   # ver weg tekent de iPhone geen auto's
	if kind == "auto":
		_shadow = ShadowProxy.make(self, _model, "auto_" + kind, [], 4)   # een heel, geparkeerd voertuig: één schaduwvorm
		if _shadow != null:
			_shadow.set_mode(1)
	if kind == "autowrak":
		_make_wreck(true)
	elif kind == "autobrand":
		hp = HP * 0.22
		stage = STAGES.size()
		_apply_stage(true)
		_start_fire(false)
	set_physics_process(true)


func _exit_tree() -> void:
	all.erase(self)
	if driven_car == self:
		driven_car = null


static var _lib: AnimationLibrary
static var _hood_q := Quaternion.IDENTITY
const CLIP_NODES := {"Ruitenwissers": "Wisser", "Knipperen": "LichtKnip", "Alarm": "Licht"}


## De Blender-export keyt in elke clip ook alle andere bewegende onderdelen (op hun rustpositie). Dat zou bij het afspelen van een
## clip een afgebroken deur of de opengesprongen kap weer terugzetten, dus de auto's krijgen één gedeelde bibliotheek waarin per clip
## alleen de eigen sporen zitten. DeurenOpen, KapOpen en KofferOpen blijven in de glb zelf (viewer en demo); in het spel staat de kap
## met de stand uit KapOpen en bewegen deuren in code.
func _strip_clips() -> void:
	if _anim == null:
		return
	if _lib == null:
		var src := _anim.get_animation_library("")
		var kap := src.get_animation("KapOpen")
		for i in kap.get_track_count():
			if kap.track_get_type(i) == Animation.TYPE_ROTATION_3D and String(kap.track_get_path(i)).contains("Motorkap"):
				_hood_q = kap.rotation_track_interpolate(i, 0.45)   # klemt half open
		_lib = AnimationLibrary.new()
		for clip in CLIP_NODES:
			var a := src.get_animation(clip).duplicate() as Animation
			for i in range(a.get_track_count() - 1, -1, -1):
				var path := String(a.track_get_path(i))
				var leaf := path.get_slice("/", path.get_slice_count("/") - 1).get_slice(":", 0)
				if not leaf.begins_with(CLIP_NODES[clip]):
					a.remove_track(i)
			_lib.add_animation(clip, a)
	_anim.remove_animation_library("")
	_anim.add_animation_library("", _lib)


func _vis_lamps(on: bool) -> void:
	for n in _tail:
		(n as Node3D).visible = on


func _paint() -> void:
	var m: BaseMaterial3D = _lak_mats.get(color_i)
	if m == null:
		m = _romp.mesh.surface_get_material(0).duplicate() as BaseMaterial3D
		m.albedo_color = COLORS[color_i]
		_lak_mats[color_i] = m
	_romp.set_surface_override_material(0, m)
	for d in DOORS:
		var dm := _car.get_node(d) as MeshInstance3D
		dm.set_surface_override_material(_surface_named(dm, "Lak"), m)
	for n in ["Motorkap", "Kofferklep"]:
		var pm := _car.get_node(n) as MeshInstance3D
		pm.set_surface_override_material(_surface_named(pm, "Lak"), m)


func _surface_named(mi: MeshInstance3D, mat_name: String) -> int:
	for i in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(i)
		if m != null and m.resource_name == mat_name:
			return i
	return 0


# ---------------------------------------------------------------- schade

## Waar raakt het stuk kogelbaan van a naar b de auto? Geeft 0..1 langs de baan, of -1 als hij mist.
## Kogels vliegen op schouderhoogte (1,6-1,7 m), net boven het dak van de botsdoos: daarom telt alles tot Bullet.HIT_TOP
## boven de grond als raak, zoals je het van bovenaf ziet. Begint de baan in de doos, dan is het meteen raak (0).
func segment_hit(a: Vector3, b: Vector3) -> float:
	var box := _shape.shape as BoxShape3D
	var la := to_local(a)
	var lb := to_local(b)
	var lo := Vector3(_shape.position.x - box.size.x * 0.5, -0.3, _shape.position.z - box.size.z * 0.5)
	var hi := Vector3(_shape.position.x + box.size.x * 0.5, maxf(_shape.position.y + box.size.y * 0.5, Bullet.HIT_TOP), _shape.position.z + box.size.z * 0.5)
	var t0 := 0.0
	var t1 := 1.0
	var d := lb - la
	for i in 3:
		if absf(d[i]) < 0.000001:
			if la[i] < lo[i] or la[i] > hi[i]:
				return -1.0
			continue
		var ta := (lo[i] - la[i]) / d[i]
		var tb := (hi[i] - la[i]) / d[i]
		t0 = maxf(t0, minf(ta, tb))
		t1 = minf(t1, maxf(ta, tb))
		if t0 > t1:
			return -1.0
	return t0


## Afstand van een punt tot de botsdoos (0 als het erin ligt).
func blast_dist(at: Vector3) -> float:
	var box := _shape.shape as BoxShape3D
	var l := to_local(at) - _shape.position
	var h := box.size * 0.5
	return Vector3(maxf(absf(l.x) - h.x, 0.0), maxf(absf(l.y) - h.y, 0.0), maxf(absf(l.z) - h.z, 0.0)).length()


## Kogel (of mes) geraakt: maal BULLET_ARMOR, bij de eerste klap gaat het alarm.
func hit(dmg: float, dir: Vector3, _from_player: bool) -> void:
	if exploded or wreck:
		return
	take(dmg * BULLET_ARMOR)
	if _holes < 14:
		_holes += 1
		_bullet_hole(dir)


## Ontploffing in de buurt (Game.note_blast): hoe dichterbij, hoe harder.
static func catch_blast(at: Vector3, radius: float) -> void:
	for a: Auto in all.duplicate():
		if not is_instance_valid(a) or a.exploded or a.wreck:
			continue
		var d := a.blast_dist(at)   # vanaf de carrosserie, niet het midden: een knal bij de kont van een lange bus telt ook
		if d < radius + 0.5:
			a.take(BLAST_DAMAGE * (1.0 - clampf(d / (radius + 0.5), 0.0, 1.0) * 0.7))


## Schade, instappen of wrak: weer de losse stukjes (die laten precies zien wat er nog staat).
func _shadow_loose() -> void:
	if _shadow != null:
		_shadow.set_mode(2)
		_shadow = null


func take(dmg: float) -> void:
	if exploded or wreck:
		return
	_shadow_loose()
	hp -= dmg
	if hp <= 0.0:
		explode()
		return
	if not driven and _alarm <= 0.0:
		_alarm = 14.0
		_vis_lamps(true)
		if _anim != null and _anim.has_animation("Alarm"):
			_anim.play("Alarm")
	var f := hp / HP
	while stage < STAGES.size() and f < STAGES[stage]:
		stage += 1
		_apply_stage(false)
	var target := clampf((1.0 - f) * 1.35, 0.0, 1.0)
	if target > _blend + 0.01:
		_blend = target
		create_tween().tween_method(_set_blend, _blend_shown(), target, 0.18)
	if f < FIRE_AT and not burning:
		_start_fire(true)


func _blend_shown() -> float:
	return _romp.get("blend_shapes/Deuk") if _romp.mesh.get_blend_shape_count() > 0 else 0.0


func _set_blend(v: float) -> void:
	if is_instance_valid(_romp) and _romp.mesh.get_blend_shape_count() > 0:
		_romp.set("blend_shapes/Deuk", v)


## Fase n begint: wat gaat er nu kapot? (quiet = bij het laden, zonder effecten)
func _apply_stage(quiet: bool) -> void:
	var s := stage
	if s >= 1:
		_drop("Voorruit", quiet)
	if s >= 2:
		_drop("Achterruit", quiet)
		_flatten("Wiel_LV", quiet)
	if s >= 3:
		_flatten("Wiel_RA", quiet)
		_pop_hood(quiet)
		_door_off(DOORS[_pick(0)], quiet)
		_smoke_start()
	if s >= 4:
		_door_off(DOORS[_pick(1)], quiet)
		_flatten("Wiel_RV", quiet)


func _pick(i: int) -> int:
	return posmod(color_i + i * 2 + int(position.x + position.z), 4)


func _drop(n: String, quiet: bool) -> void:
	var g := _car.get_node_or_null(n) as Node3D
	if g == null or not g.visible:
		return
	g.visible = false
	if not quiet:
		Fx.spark(get_parent(), g.global_position + Vector3.UP * 0.3, Vector3.UP)
		Sfx.play("thud", 0.4, global_position)


func _flatten(w: String, quiet: bool) -> void:
	if _flat.has(w):
		return
	_flat[w] = true
	if not quiet:
		Fx.dust(get_parent(), (_wheels[w] as Node3D).global_position)
		Sfx.play("splat", 0.35, global_position)
	_model.position.y = -0.025 * _flat.size()


func _pop_hood(quiet: bool) -> void:
	if _hood_open or _gone.has("Motorkap"):
		return
	_hood_open = true
	(_car.get_node("Motorkap") as Node3D).quaternion = _hood_q
	if not quiet:
		Fx.dust(get_parent(), global_position + Vector3(0, 1.0, 0))
		Sfx.play("gate", 0.35, global_position)


## Een deur vliegt eraf en blijft op straat liggen.
func _door_off(n: String, quiet: bool) -> void:
	if _gone.has(n):
		return
	var d := _car.get_node_or_null(n) as Node3D
	if d == null:
		return
	_gone[n] = true
	if quiet:
		d.visible = false
		return
	_fling(d, 1.0)


## Maakt een deel los van de auto en laat het in een boog wegvliegen; het blijft even liggen en krimpt dan weg.
func _fling(part: Node3D, power: float) -> void:
	var gt := part.global_transform
	var parent := get_parent()
	part.get_parent().remove_child(part)
	parent.add_child(part)
	part.global_transform = gt
	var out := (gt.origin - global_position)
	out.y = 0.0
	var dir := out.normalized() if out.length() > 0.05 else Vector3(randf() - 0.5, 0, randf() - 0.5).normalized()
	var v := dir * randf_range(3.0, 7.0) * power + Vector3(0, randf_range(3.5, 8.0) * power, 0)
	var spin := Vector3(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
	var g := 18.0
	var start := gt.origin
	var t_land := (v.y + sqrt(v.y * v.y + 2.0 * g * maxf(start.y, 0.1))) / g
	var rot0 := gt.basis
	var tw := part.create_tween()
	tw.tween_method(_fly.bind(part, start, v, spin, rot0, g, t_land), 0.0, t_land, t_land)
	tw.tween_callback(_thud.bind(part))
	tw.tween_interval(24.0)
	tw.tween_property(part, "scale", Vector3.ONE * 0.001, 0.8)
	tw.tween_callback(part.queue_free)


func _fly(t: float, part: Node3D, start: Vector3, v: Vector3, spin: Vector3, rot0: Basis, g: float, t_land: float) -> void:
	if not is_instance_valid(part):
		return
	var p := start + Vector3(v.x * t, v.y * t - 0.5 * g * t * t, v.z * t)
	part.global_transform = Transform3D(rot0 * Basis.from_euler(spin * minf(t, t_land)), Vector3(p.x, maxf(p.y, 0.12), p.z))


func _thud(part: Node3D) -> void:
	if is_instance_valid(part):
		Sfx.play("thud", 0.5, part.global_position)


func _bullet_hole(dir: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.02, 0.02, 0.02)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# in lokale ruimte op de zijkant of bovenkant die naar de schutter kijkt
	var ld := global_transform.basis.inverse() * dir
	var side := signf(-ld.x) if absf(ld.x) > absf(ld.z) else 0.0
	if side != 0.0:
		mi.position = Vector3(side * 0.93, randf_range(0.5, 1.0), randf_range(-1.6, 1.6))
		mi.rotation.y = side * PI / 2.0
	else:
		var fs := signf(-ld.z)
		mi.position = Vector3(randf_range(-0.6, 0.6), randf_range(0.55, 0.9), fs * 2.14)
		mi.rotation.y = 0.0 if fs > 0.0 else PI


# ---------------------------------------------------------------- vuur en ontploffing

func _smoke_start() -> void:
	if _smoke != null or exploded:
		return
	_smoke = Fx.burning(self, global_position + Vector3(0, 0.9, -1.4), false)
	PerfMonitor.note("auto rookt")


func _start_fire(with_fuse: bool) -> void:
	burning = true
	_smoke_start()
	_fire = Fx.flame(self, Vector3(0.0, 0.85, -1.35), 1.5, with_fuse)
	if with_fuse:
		_fuse = randf_range(FUSE.x, FUSE.y)
		Game.alert(global_position, 30.0, 6.0)
		PerfMonitor.note("auto brandt")


func explode() -> void:
	_shadow_loose()
	if exploded:
		return
	exploded = true
	var at := global_position + Vector3(0, 0.6, 0)
	var parent := get_parent()
	if driven:
		_exit_player(true)
	set_physics_process(false)
	# 1. schade eerst, dan beeld: vijanden, jij, gebouwen, poorten; kettingreactie naar vaten, pompen en auto's
	Game.note_blast(at, BLAST_RADIUS)
	Barrel.area_damage(at, BLAST_RADIUS, BLAST_HURT)
	Barrel.catch_blast(at, BLAST_RADIUS)
	Game.alert(at, 60.0, 10.0)
	# 2. vuurbal, rook en vonken (bestaande explosie), een tweede bal vlak erachter en een schokgolf
	Fx.explosion(parent, at, 1.9, Fx.CHUNKS_BARREL)
	get_tree().create_timer(0.14).timeout.connect(func():
		if is_instance_valid(parent):
			Fx.explosion(parent, at + Vector3(randf_range(-1.2, 1.2), 0.2, randf_range(-1.2, 1.2)), 1.3, Fx.CHUNKS_GROUND))
	_shockwave(parent, at)
	var cam: Camera3D = null
	if Game.player and is_instance_valid(Game.player):
		cam = Game.player.get_parent().get_node_or_null("Camera") as Camera3D
	if cam and cam.has_method("combat_impulse") and Game.player.global_position.distance_to(at) < 40.0:
		cam.call("combat_impulse", 0.06)
	# 3. de echte onderdelen vliegen weg: deuren, kap, kofferklep, twee wielen
	for n in DOORS:
		if not _gone.has(n):
			_fling(_car.get_node(n) as Node3D, 1.2)
			_gone[n] = true
	for n in ["Motorkap", "Kofferklep"]:
		var p := _car.get_node_or_null(n) as Node3D
		if p != null and p.visible:
			_fling(p, 1.5 if n == "Motorkap" else 1.1)
	var order := WHEELS.duplicate()
	order.shuffle()
	for i in 2:
		_fling(_wheels[order[i]] as Node3D, 1.0)
		_flat[order[i]] = true
	for n in ["Voorruit", "Achterruit"]:
		(_car.get_node(n) as Node3D).visible = false
	if _anim != null:
		_anim.stop()
	_make_wreck(false)
	# 4. de romp springt op door de klap en valt terug
	var tw := create_tween()
	tw.tween_property(_model, "position:y", 1.1, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_model, "rotation:z", randf_range(-0.22, 0.22), 0.22)
	tw.parallel().tween_property(_model, "rotation:x", randf_range(-0.12, 0.12), 0.22)
	tw.tween_property(_model, "position:y", -0.06, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		Fx.dust(parent, global_position + Vector3(0, 0.3, 0))
		Sfx.play("thud", 0.8, global_position))
	tw.tween_property(_model, "position:y", 0.0, 0.1)
	# 5. het wrak brandt nog een tijd na, met rook
	if _fire and is_instance_valid(_fire):
		_fire.queue_free()
	_fire = Fx.flame(self, Vector3(0.0, 0.7, 0.0), 2.2)
	var fire := _fire
	var smoke := _smoke
	if smoke == null or not is_instance_valid(smoke):
		smoke = Fx.burning(self, global_position + Vector3(0, 0.8, 0), false)
		_smoke = smoke
	var ft := create_tween()
	ft.tween_interval(26.0)
	ft.tween_callback(func():
		if is_instance_valid(fire):
			var sh := fire.create_tween()
			sh.tween_property(fire, "scale", Vector3(1.0, 0.0, 1.0), 2.5)
			sh.tween_callback(fire.queue_free))
	ft.tween_interval(18.0)
	ft.tween_callback(func():
		if is_instance_valid(smoke):
			smoke.queue_free())
	PerfMonitor.note("auto ontploft")


func _shockwave(parent: Node, at: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.93
	tm.outer_radius = 1.0
	tm.rings = 28
	tm.ring_segments = 6
	ring.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.8, 0.5, 0.55)
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ring)
	ring.global_position = Vector3(at.x, 0.25, at.z)
	ring.scale = Vector3(0.5, 0.35, 0.5)
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector3(BLAST_RADIUS * 1.15, 0.5, BLAST_RADIUS * 1.15), 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.55)
	tw.tween_callback(ring.queue_free)
	# stofwolk langs de grond
	Fx.spray_once(parent, "auto_stof", Vector3(at.x, 0.3, at.z), 4.0, BLAST_RADIUS * 1.2, 1.0, 1.5,
		func(): return Fx._spray(36, 1.1, Vector3(0.18, 0.18, 0.18), Color(0.5, 0.45, 0.38, 0.7), 0.0, 0.0, 90.0, 0.5, false))


## Verkoold wrak: zwart materiaal op de lak, deuk helemaal, dak ingezakt; blijft staan met een lagere botsvorm.
func _make_wreck(quiet: bool) -> void:
	_shadow_loose()
	wreck = true
	_romp.set_surface_override_material(0, _wrak_mat)
	if _romp.mesh.get_blend_shape_count() > 0:
		_romp.set("blend_shapes/Deuk", 1.0)
	_car.scale = Vector3(1.0, 0.94, 1.0)
	for n in ["Voorruit", "Achterruit"]:
		(_car.get_node(n) as Node3D).visible = false
	if quiet:
		for n in DOORS:
			if _pick(DOORS.find(n)) % 2 == 0:
				_car.get_node(n).visible = false
				_gone[n] = true
		for w in WHEELS:
			_flatten(w, true)
		_pop_hood(true)
	# de overgebleven lak-delen worden ook zwart
	for n in DOORS + ["Motorkap", "Kofferklep"]:
		var p := _car.get_node_or_null(n) as MeshInstance3D
		if p != null and not _gone.has(n):
			p.set_surface_override_material(_surface_named(p, "Lak"), _wrak_mat)
	for n in _tail:
		(n as Node3D).scale = Vector3.ONE * 0.001
	_vis_lamps(false)
	var b := _shape.shape as BoxShape3D
	b.size = Vector3(1.95, 1.0, 4.4)
	_shape.position.y = 0.5
	if driven_car == self:
		driven_car = null
	if is_in_group("voertuigen"):
		remove_from_group("voertuigen")


# ---------------------------------------------------------------- instappen en rijden

func _physics_process(delta: float) -> void:
	_t += delta
	_ram_cd -= delta
	var p = Game.player
	var live: bool = Game.state == "play" or Game.state == "prep"
	_check -= delta
	if _check <= 0.0 and not driven:
		_check = 0.2
		if p != null and not p.dead and live and not exploded and not wreck and driven_car == null and Bus.driven_car == null \
				and p.global_position.distance_to(global_position) < BOARD_DIST:
			_cand = self
			_cand_ms = Time.get_ticks_msec()
	_keep_button(p)
	if burning and not exploded and kind != "autobrand":
		_fuse -= delta
		if _fuse <= 0.0:
			explode()
			return
	if _alarm > 0.0:
		_alarm_tick(delta)
	if driven:
		if p == null or p.dead:
			_exit_player(false)
		else:
			p.global_position = Vector3(global_position.x, 0.0, global_position.z)
			p.face = rotation.y + PI
			_horn_tick()
			_ram()
	_drive(delta, live)
	_animate(delta)


func _keep_button(p) -> void:
	if _btn != null and not is_instance_valid(_btn):
		_btn = null
	if _btn == null:
		if _cand != self and not driven:
			return
		_make_button()
	if _btn.get_parent().get_parent() != self:
		return
	var recent := Time.get_ticks_msec() - _cand_ms < 450 and is_instance_valid(_cand) and not _cand.exploded
	_btn.visible = driven_car != null or recent
	_btn.dock(2)
	if driven_car != null:
		_btn.kind = "exit"
		_btn.set_caption("UIT")
	else:
		_btn.kind = "enter"
		_btn.set_caption("IN")
	_btn.queue_redraw()


func _make_button() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_btn = ActionBtn.make("enter", "IN")
	_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_btn.offset_left = ActionBtn.slot_x(2)
	_btn.offset_right = ActionBtn.slot_x(2) + ActionBtn.SIZE.x
	_btn.offset_top = -126.0
	_btn.offset_bottom = -126.0 + ActionBtn.SIZE.y
	_btn.pressed.connect(Auto._pressed)
	_btn.hide()
	layer.add_child(_btn)


static func _pressed() -> void:
	if driven_car != null and is_instance_valid(driven_car):
		driven_car._exit_player(false)
	elif _cand != null and is_instance_valid(_cand):
		_cand._enter()


func _enter() -> void:
	_shadow_loose()
	var p = Game.player
	if p == null or p.dead or driven or exploded or wreck or Bus.driven_car != null:
		return
	driven = true
	driven_car = self
	_alarm = 0.0
	add_to_group("voertuigen")   # brandkranen spuiten als je erover rijdt
	p.driving = true
	p.visible = false
	p.collision_mask = 0
	p.velocity = Vector3.ZERO
	_door_wave("DeurLV")
	_vis_lamps(true)
	_lights(GameSettings.get_value("time") != "day")
	if _anim != null:
		_anim.stop()
		if GameSettings.get_value("weather") == "rain" and _anim.has_animation("Ruitenwissers"):
			_anim.play("Ruitenwissers")
	_make_exhaust()
	Sfx.play("click", 0.5, global_position)


func _exit_player(blasted: bool) -> void:
	var p = Game.player
	driven = false
	if driven_car == self:
		driven_car = null
	remove_from_group("voertuigen")
	_lights(false)
	for n in _tail:
		(n as Node3D).scale = Vector3.ONE * 0.001
	if _alarm <= 0.0:
		_vis_lamps(false)
	if _exhaust != null:
		_exhaust.emitting = false
	if _anim != null:
		_anim.stop()
	if p != null:
		p.driving = false
		p.visible = true
		var side := global_transform.basis.x
		p.global_position = global_position - side * (2.6 if blasted else 1.9)
		p.global_position.y = 0.0
		p.collision_mask = p.get("_mask0")
	_door_wave("DeurLV")


## De bestuurdersdeur zwaait even open bij in- en uitstappen.
func _door_wave(n: String) -> void:
	var d := _car.get_node_or_null(n) as Node3D
	if d == null or _gone.has(n) or exploded:
		return
	var sgn := -1.0 if n.begins_with("DeurL") else 1.0
	var tw := create_tween()
	tw.tween_method(_set_door.bind(n, sgn), 0.0, 1.0, 0.18)
	tw.tween_interval(0.5)
	tw.tween_method(_set_door.bind(n, sgn), 1.0, 0.0, 0.25)


func _set_door(a: float, n: String, sgn: float) -> void:
	var d := _car.get_node_or_null(n) as Node3D
	if d == null or _gone.has(n):
		return
	var rest: Transform3D = _door_rest[n]
	d.transform = Transform3D(rest.basis * Basis(Vector3.UP, sgn * 1.15 * a), rest.origin)


func _lights(on: bool) -> void:
	for l in _lamps:
		if is_instance_valid(l):
			l.queue_free()
	_lamps.clear()
	for n in _tail:
		var nm := String(n.name)
		if nm.begins_with("LichtKop"):
			(n as Node3D).scale = Vector3.ONE if on else Vector3.ONE * 0.001
	if not on:
		return
	for sx in [-0.6, 0.6]:
		var l := SpotLight3D.new()
		l.light_energy = 3.0
		l.spot_range = 26.0
		l.spot_angle = 30.0
		l.spot_attenuation = 0.8
		l.light_color = Color(1.0, 0.94, 0.8)
		l.shadow_enabled = false
		l.position = Vector3(sx, 0.7, -2.1)
		l.rotation.x = -0.05
		add_child(l)
		_lamps.append(l)


func _make_exhaust() -> void:
	if _exhaust != null:
		_exhaust.emitting = true
		return
	_exhaust = Fx._puff(10, 1.0, 0.45, false, Fx._ramp([Color(0.5, 0.5, 0.5, 0.0), Color(0.5, 0.5, 0.5, 0.35), Color(0.6, 0.6, 0.6, 0.0)], [0.0, 0.2, 1.0]), Vector2(0.4, 0.9), 1.8)
	_exhaust.position = Vector3(0.45, 0.28, 2.2)
	_exhaust.direction = Vector3(0.0, 0.25, 1.0)
	_exhaust.spread = 25.0
	add_child(_exhaust)
	_exhaust.emitting = true


func _horn_tick() -> void:
	var f: bool = Game.fire
	if f and not _horn:
		Sfx.play("claxon", 0.7, global_position)
		Game.alert(global_position, 24.0, 3.0)
	_horn = f


func _alarm_tick(delta: float) -> void:
	_alarm -= delta
	_alarm_beep -= delta
	if _alarm_beep <= 0.0 and _alarm > 0.0:
		_alarm_beep = 0.6
		Sfx.play("alarm", 0.5, global_position)
	if _alarm <= 0.0 and _anim != null and not driven and not exploded:
		_anim.stop()
		for n in _tail:
			(n as Node3D).scale = Vector3.ONE * 0.001
		_vis_lamps(false)


func _drive(delta: float, live: bool) -> void:
	if exploded or wreck:
		return
	var want_speed := 0.0
	var want_steer := 0.0
	var pivot := 0.0
	var mv := Game.move
	var health := clampf(hp / HP / 0.5, 0.0, 1.0)     # onder 50% hp loopt de motor slecht
	var vmax := SPEED * (0.55 + 0.45 * health) * (1.0 - 0.1 * _flat.size())
	if driven and live and mv.length() > 0.15:
		var want := atan2(-mv.x, -mv.y)
		var diff := wrapf(want - rotation.y, -PI, PI)
		var reverse := absf(diff) > 2.3
		if reverse:
			diff = wrapf(diff - PI, -PI, PI)
		want_steer = clampf(diff * 1.6, -MAX_STEER, MAX_STEER) * (-1.0 if reverse else 1.0)
		var bend := 1.0 - 0.5 * minf(absf(diff) / 1.2, 1.0)
		pivot = diff
		want_speed = (-REVERSE if reverse else vmax * bend) * minf(mv.length() * 1.3, 1.0)
	var old := _speed
	var braking := signf(want_speed) != signf(_speed) or absf(want_speed) < absf(_speed)
	_speed = move_toward(_speed, want_speed, (BRAKE if braking else ACCEL) * delta)
	_accel = lerpf(_accel, (_speed - old) / delta, delta * 4.0)
	_steer = move_toward(_steer, want_steer, 2.5 * delta)
	var pull := 0.05 * (1 if _flat.has("Wiel_LV") else 0) - 0.05 * (1 if _flat.has("Wiel_RV") else 0)
	_yaw_rate = _speed * tan(_steer + pull * clampf(absf(_speed) / 8.0, 0.0, 1.0)) / WHEELBASE
	rotation.y += clampf(pivot, -1.0, 1.0) * 1.8 * clampf(1.0 - absf(_speed) / 2.5, 0.0, 1.0) * delta
	if absf(_speed) < 0.01:
		return
	rotation.y += _yaw_rate * delta
	velocity = -global_transform.basis.z * _speed
	move_and_slide()
	global_position.y = 0.0
	if get_slide_collision_count() > 0:
		if absf(_speed) > 6.0:
			take(absf(_speed) * 2.0)    # hard tegen iets aan: schade aan de auto
			Fx.spark(get_parent(), global_position + Vector3(0, 0.8, 0) - global_transform.basis.z * signf(_speed) * 2.0, Vector3.UP)
		_speed *= 0.5
	var flat := Vector2(global_position.x, global_position.z)
	var clamped := Data.clamp_world(flat)
	if clamped != flat:
		flat = clamped
		global_position = Vector3(flat.x, 0.0, flat.y)


func _animate(delta: float) -> void:
	if exploded:
		return
	for w in WHEELS:
		var n: Node3D = _wheels[w]
		if not is_instance_valid(n) or n.get_parent() != _car:
			continue
		_spin[w] = wrapf(_spin[w] - _speed * delta / WHEEL_R, -TAU, TAU)
		var st := _steer if w.ends_with("V") else 0.0
		var k := 0.84 if _flat.has(w) else 1.0
		n.transform = Transform3D(Basis(Vector3.UP, st) * Basis(Vector3.RIGHT, _spin[w]) * Basis.from_scale(Vector3(1, k, k)),
				_wheel_pos[w] + Vector3(0, -WHEEL_R * (1.0 - k), 0))
	if not driven and not wreck:
		_model.rotation = _model.rotation.lerp(Vector3.ZERO, delta * 6.0)
	if driven and not wreck:
		var amp := clampf(absf(_speed) / 6.0, 0.1, 1.0)
		var pitch := clampf(_accel * 0.004, -0.03, 0.03) + 0.003 * sin(_t * 7.3) * amp
		var roll := clampf(-_yaw_rate * _speed * 0.003, -0.05, 0.05)
		_model.rotation = Vector3(pitch, 0, roll)
		_model.position.y = (0.01 * sin(_t * 9.0) + 0.005 * sin(_t * 15.7)) * amp - 0.025 * _flat.size()
		_blink_tick(delta)
		_exhaust_tick()
		if absf(_speed) > 7.0 and randf() < delta * 6.0:
			Fx.dust(get_parent(), global_position + global_transform.basis.z * 1.3 + Vector3(randf_range(-0.8, 0.8), 0.1, 0))
		var braking: bool = _accel < -1.5
		for n in _tail:
			if String(n.name).begins_with("LichtAchter"):
				(n as Node3D).scale = Vector3.ONE if braking else Vector3.ONE * 0.001


## Knipperlicht: in de bocht links via de Blender-clip, rechts met dezelfde lampen in code.
func _blink_tick(delta: float) -> void:
	if _anim != null and _anim.is_playing() and _anim.current_animation == "Ruitenwissers":
		return
	var turning := absf(_steer) > 0.18 and absf(_speed) > 1.0
	if turning and _steer > 0.0 and _anim != null and _anim.has_animation("Knipperen"):
		if _anim.current_animation != "Knipperen" or not _anim.is_playing():
			_anim.play("Knipperen")
	elif turning:
		_blink += delta
		var on := fmod(_blink, 1.0) < 0.5
		for n in _tail:
			if String(n.name).begins_with("LichtKnip") and String(n.name).ends_with("R"):
				(n as Node3D).scale = Vector3.ONE if on else Vector3.ONE * 0.001
	else:
		if _anim != null and _anim.current_animation == "Knipperen":
			_anim.stop()
			for n in _tail:
				if String(n.name).begins_with("LichtKnip"):
					(n as Node3D).scale = Vector3.ONE * 0.001


func _exhaust_tick() -> void:
	if _exhaust == null:
		return
	var throttle := clampf(absf(_accel) / 4.0 + absf(_speed) / 25.0, 0.0, 1.0)
	_exhaust.emitting = throttle > 0.12 or stage >= 2


func _ram() -> void:
	if _speed < 3.0 or _ram_cd > 0.0:
		return
	for e in Game.enemies.duplicate():
		if not is_instance_valid(e):
			continue
		var lp := to_local(e.global_position)
		if absf(lp.x) < 1.2 and lp.z < 0.8 and lp.z > -2.9:
			_ram_cd = 0.2
			e.hit(RAM_DAMAGE, -global_transform.basis.z, true)
