class_name Artillerie
extends Node3D
## Artilleriecommando: je wijst een punt aan, na een korte radio-oproep slaan `shells` granaten in rond dat punt (5 op niveau 1, zie Rang).
## Het commando komt van het hoofdkwartier niveau 3 (Generals-plan stap 3) of van de generaalsrang (stap E1); de afkoeling staat in Rang.
## Alleen vijanden krijgen schade: jijzelf, je soldaten en je gebouwen blijven heel.

const SHELLS := 5          # aantal granaten op niveau 1
const RADIUS := 6.5        # m: zo ver rond het doelpunt kunnen de granaten inslaan
const BLAST := 4.8         # m: ontploffingsstraal per granaat
const DAMAGE := 320.0      # schade in het midden van een inslag, 40% aan de rand
const CALL_DELAY := 1.5    # s tussen het commando en de eerste inslag
const INTERVAL := 0.75     # s tussen twee inslagen
const FLIGHT := 0.7        # s dat een granaat zichtbaar naar beneden valt
const RANGE_MIN := 14.0    # m vanaf de speler (slepen)
const RANGE_MAX := 60.0
const TAP_RANGE := 26.0    # alleen tikken: dichtstbijzijnde vijand in dit bereik, anders zo ver recht vooruit

var target := Vector3.ZERO
var shells := SHELLS
var impacts: Array = []     # {t, pos, shown, done}
var _t := 0.0
var _marker: MeshInstance3D
var _shells_done := 0

static var _ring_shader: Shader


## Wijst het punt aan. De afkoeling zet de aanroeper (Rang.gebruik). Returns de strike.
static func call_in(parent: Node, at: Vector3, shells_ := SHELLS) -> Artillerie:
	var a := Artillerie.new()
	a.shells = shells_
	parent.add_child(a)
	a.start(at)
	return a


## Doelpunt bij tikken: de dichtstbijzijnde vijand die ver genoeg weg is, anders recht vooruit.
static func tap_target(from: Vector3, facing: Vector3) -> Vector3:
	var best: Node3D = null
	var bd := TAP_RANGE
	for e in Game.enemies:
		if not is_instance_valid(e) or e.get("dead") == true:
			continue
		var d := Vector2(e.global_position.x - from.x, e.global_position.z - from.z).length()
		if d >= RANGE_MIN * 0.6 and d < bd:
			bd = d
			best = e
	if best != null:
		return Vector3(best.global_position.x, 0.0, best.global_position.z)
	return Vector3(from.x, 0.0, from.z) + facing.normalized() * TAP_RANGE


## Doelpunt bij slepen: schermrichting = wereldrichting, afstand wordt RANGE_MIN tot RANGE_MAX.
static func drag_target(from: Vector3, dir: Vector3, k: float) -> Vector3:
	return Vector3(from.x, 0.0, from.z) + dir.normalized() * lerpf(RANGE_MIN, RANGE_MAX, clampf(k, 0.0, 1.0))


func start(at: Vector3) -> void:
	target = Vector3(at.x, 0.0, at.z)
	global_position = target
	for i in shells:
		var p := target
		if i > 0:
			var a := float(i) * 2.399 + randf() * 0.6        # gouden hoek: gelijkmatig verspreid
			var r := sqrt(float(i) / float(shells)) * RADIUS * randf_range(0.7, 1.0)
			p += Vector3(cos(a) * r, 0.0, sin(a) * r)
		impacts.append({"t": CALL_DELAY + float(i) * INTERVAL, "pos": p, "shown": false, "done": false})
	_marker = _make_marker()
	add_child(_marker)
	Game.banner.emit("ARTILLERIE ONDERWEG", "%d granaten · inslag over %d s" % [shells, ceili(CALL_DELAY)], 1.6)
	Sfx.play("click", 0.7)


func _process(delta: float) -> void:
	_t += delta
	if _marker != null:
		var pulse := 0.6 + 0.4 * sin(_t * 9.0)
		(_marker.material_override as ShaderMaterial).set_shader_parameter("alpha", 0.35 + 0.5 * pulse)
	for im in impacts:
		if im.done:
			continue
		if not im.shown and _t >= float(im.t) - FLIGHT:
			im.shown = true
			_drop_shell(im.pos)
		if _t >= float(im.t):
			im.done = true
			_impact(im.pos)
			_shells_done += 1
	if _shells_done >= shells:
		queue_free()


func _drop_shell(at: Vector3) -> void:
	Sfx.play("ping", 0.45, at)
	var mi := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.12
	cap.height = 0.9
	mi.mesh = cap
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.8, 0.45)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.55, 0.15)
	mat.emission_energy_multiplier = 2.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = at + Vector3(randf_range(-4.0, 4.0), 55.0, randf_range(-4.0, 4.0))
	var tw := mi.create_tween()
	tw.tween_property(mi, "global_position", at + Vector3(0, 0.3, 0), FLIGHT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


func _impact(at: Vector3) -> void:
	var parent: Node = Game.defs if Game.defs != null and is_instance_valid(Game.defs) else (get_parent() if get_parent() != null else self)
	Fx.explosion(parent, at, 1.5)
	damage_at(at)


## Schade aan alle vijanden rond een inslag. Static zodat de test het direct kan aanroepen.
## Dit is bewust een overhead-artillerie-exceptie: muren blokkeren deze inslag niet.
static func damage_at(at: Vector3) -> int:
	VijandHk.blast(at, BLAST, DAMAGE)   # ook het vijandelijke hoofdkwartier (stap 5a-2)
	VijandM2Toren.blast(at, BLAST, DAMAGE)
	Garnizoen.blast(at, BLAST, DAMAGE, "vijand")   # een granaat van boven in een bezet gebouw (F2)
	var hits := 0
	for e in Game.enemies.duplicate():
		if not is_instance_valid(e) or e.get("dead") == true:
			continue
		var flat := Vector3(e.global_position.x - at.x, 0.0, e.global_position.z - at.z)
		var d := flat.length() - float(e.t.get("r", 0.4))
		if d < BLAST:
			var k := 1.0 - clampf(maxf(d, 0.0) / BLAST, 0.0, 1.0) * 0.6
			Game.hit_src = "lucht"    # artillerie telt als luchtsteun (geen bevestigde treffer van de speler)
			e.hit(DAMAGE * k, flat.normalized() if flat.length() > 0.01 else Vector3.UP, true)
			Game.hit_src = "speler"
			hits += 1
	return hits


func _make_marker() -> MeshInstance3D:
	if _ring_shader == null:
		_ring_shader = Shader.new()
		_ring_shader.code = ArtillerieAim.SHADER
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(RADIUS * 2.0 + 1.0, RADIUS * 2.0 + 1.0)
	mi.mesh = pm
	var mat := ShaderMaterial.new()
	mat.shader = _ring_shader
	mat.render_priority = 9
	mat.set_shader_parameter("col", ArtillerieAim.ENEMY)
	mat.set_shader_parameter("radius", RADIUS)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, 0.08, 0)
	return mi
