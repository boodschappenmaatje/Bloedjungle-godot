class_name Puin
extends Node3D
## Rondvliegend puin met GPU-instancing (zoals mobiele actiegames dat doen): alle brokstukken met hetzelfde model zijn
## samen één MultiMesh = één draw call (plus één voor de schaduw), in plaats van een eigen MeshInstance3D met een eigen
## tween per stuk. Eén granaat in de woonwijk maakte vroeger ~290 losse brokken (= ~290 draw calls, 290 tweens die elk
## beeld GDScript draaien); nu is dat een paar draw calls en één lus.
## Elk stuk vliegt in een boog (kwadratische Bézier: start, hoogste punt, landing; een worp onder zwaartekracht is precies
## zo'n boog), tolt, blijft een tijd liggen en krimpt dan weg. Zit een soort vol, dan maakt het oudste stuk plaats.

const CAP := 96          # stukken per model tegelijk; het oudste maakt plaats
const SHRINK := 0.5      # seconden wegkrimpen aan het eind
const MAX_TRAILS := 8    # rooksporen achter grote brokken (explosies)

static var _inst: Puin

var _sets := {}          # sleutel -> set (Dictionary)
var _trail_pool: Array[CPUParticles3D] = []
var _trails_live := 0


## Gooi één stuk: van p0 via ctrl naar p1 in dur seconden (Bézier), draaiing rot0 + spin * t, blijft stay seconden liggen.
## trail = een rookspoor erachter zolang het vliegt (hooguit MAX_TRAILS tegelijk).
static func throw(parent: Node, mesh: Mesh, p0: Vector3, ctrl: Vector3, p1: Vector3, dur: float, rot0: Vector3, spin: Vector3,
		sc: Vector3, stay: float, shadow := false, material: Material = null, trail := false) -> void:
	if mesh == null:
		return
	var me := _host(parent)
	if me == null:
		return
	me._add(mesh, p0, ctrl, p1, maxf(dur, 0.01), rot0, spin, sc, stay, shadow, material, trail)


## Worp onder zwaartekracht (zoals Fx._debris): beginsnelheid v, valversnelling g, landt op hoogte floor_y.
static func toss(parent: Node, mesh: Mesh, start: Vector3, v: Vector3, g: float, floor_y: float, rot0: Vector3, spin: Vector3,
		sc: Vector3, stay: float, shadow := false, material: Material = null, trail := false) -> void:
	var h := start.y - floor_y
	var t_land := (v.y + sqrt(maxf(0.0, v.y * v.y + 2.0 * g * h))) / g
	var p1 := start + Vector3(v.x * t_land, v.y * t_land - 0.5 * g * t_land * t_land, v.z * t_land)
	p1.y = floor_y
	var ctrl := start + v * (t_land * 0.5)
	throw(parent, mesh, start, ctrl, p1, t_land, rot0, spin, sc, stay, shadow, material, trail)


## Hoeveel stukken er nu liggen of vliegen (tests en prestatie-overlay).
static func live_count() -> int:
	if _inst == null or not is_instance_valid(_inst):
		return 0
	var n := 0
	for k in _inst._sets:
		n += (_inst._sets[k] as Soort).live.size()
	return n


static func clear() -> void:
	if _inst != null and is_instance_valid(_inst):
		_inst.queue_free()
	_inst = null


static func _host(parent: Node) -> Puin:
	if _inst != null and is_instance_valid(_inst) and _inst.is_inside_tree():
		return _inst
	if parent == null or not parent.is_inside_tree():
		return null
	_inst = Puin.new()
	_inst.name = "Puin"
	# onder de hoofdscène, zodat het puin bij een nieuw spel meeverdwijnt
	var host: Node = parent.get_tree().current_scene if parent.get_tree().current_scene != null else parent.get_tree().root
	host.add_child(_inst)
	return _inst


func _exit_tree() -> void:
	if _inst == self:
		_inst = null


## Alle stukken met hetzelfde model (en schaduw/materiaal): één MultiMesh. Per stuk de boog, draaiing en leeftijd.
class Soort:
	var mm: MultiMesh
	var mmi: MultiMeshInstance3D
	var next := 0
	var live := PackedInt32Array()
	var p0 := PackedVector3Array()
	var c := PackedVector3Array()
	var p1 := PackedVector3Array()
	var rot0 := PackedVector3Array()
	var spin := PackedVector3Array()
	var sc := PackedVector3Array()
	var age := PackedFloat32Array()
	var dur := PackedFloat32Array()
	var stay := PackedFloat32Array()
	var landed := PackedByteArray()
	var used := PackedByteArray()
	var trail: Array = []

	func _init(n: int) -> void:
		p0.resize(n)
		c.resize(n)
		p1.resize(n)
		rot0.resize(n)
		spin.resize(n)
		sc.resize(n)
		age.resize(n)
		dur.resize(n)
		stay.resize(n)
		landed.resize(n)
		used.resize(n)
		trail.resize(n)


const HIDDEN := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3(0, -50, 0))


func _set_for(mesh: Mesh, shadow: bool, material: Material) -> Soort:
	var key := "%d:%d:%d" % [mesh.get_instance_id(), int(shadow), material.get_instance_id() if material else 0]
	if _sets.has(key):
		return _sets[key]
	var s := Soort.new(CAP)
	s.mm = MultiMesh.new()
	s.mm.transform_format = MultiMesh.TRANSFORM_3D
	s.mm.mesh = mesh
	s.mm.instance_count = CAP
	for i in CAP:
		s.mm.set_instance_transform(i, HIDDEN)
	s.mmi = MultiMeshInstance3D.new()
	s.mmi.multimesh = s.mm
	s.mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if material:
		s.mmi.material_override = material
	# de stukken liggen overal in de wereld: niet wegknippen op een verouderd kader
	s.mmi.custom_aabb = AABB(Vector3(-400, -10, -400), Vector3(800, 80, 800))
	add_child(s.mmi)
	_sets[key] = s
	return s


func _add(mesh: Mesh, p0: Vector3, ctrl: Vector3, p1: Vector3, dur: float, rot0: Vector3, spin: Vector3, sc: Vector3,
		stay: float, shadow: bool, material: Material, trail: bool) -> void:
	var s := _set_for(mesh, shadow, material)
	var i := s.next
	s.next = (i + 1) % CAP
	if s.used[i] == 1:
		s.live.remove_at(s.live.find(i))   # vol: het oudste stuk maakt plaats
		_drop_trail(s, i)
	s.used[i] = 1
	s.live.append(i)
	s.p0[i] = p0
	s.c[i] = ctrl
	s.p1[i] = p1
	s.dur[i] = dur
	s.rot0[i] = rot0
	s.spin[i] = spin
	s.sc[i] = sc
	s.age[i] = 0.0
	s.stay[i] = stay
	s.landed[i] = 0
	if trail and _trails_live < MAX_TRAILS:
		var t := _take_trail()
		t.global_position = p0
		t.emitting = true
		s.trail[i] = t
	s.mm.set_instance_transform(i, _xf(p0, rot0, sc))


static func _xf(p: Vector3, rot: Vector3, sc: Vector3) -> Transform3D:
	return Transform3D(Basis.from_euler(rot).scaled_local(sc), p)


func _take_trail() -> CPUParticles3D:
	_trails_live += 1
	while not _trail_pool.is_empty():
		var t: CPUParticles3D = _trail_pool.pop_back()
		if is_instance_valid(t):
			t.restart()
			return t
	var p := Fx._smoke_trail()
	add_child(p)
	return p


func _drop_trail(s: Soort, i: int) -> void:
	var t = s.trail[i]
	if t == null:
		return
	s.trail[i] = null
	_trails_live = maxi(0, _trails_live - 1)
	if is_instance_valid(t):
		(t as CPUParticles3D).emitting = false   # de rook die er al is waait nog uit
		_trail_pool.append(t)


func _process(delta: float) -> void:
	for key in _sets:
		var s: Soort = _sets[key]
		if s.live.is_empty():
			continue
		var mm := s.mm
		var done := PackedInt32Array()
		for i in s.live:
			var a: float = s.age[i] + delta
			s.age[i] = a
			var dur: float = s.dur[i]
			if a < dur:
				var u := a / dur
				var w := 1.0 - u
				var p: Vector3 = s.p0[i] * (w * w) + s.c[i] * (2.0 * u * w) + s.p1[i] * (u * u)
				mm.set_instance_transform(i, _xf(p, s.rot0[i] + s.spin[i] * a, s.sc[i]))
				var t = s.trail[i]
				if t != null and is_instance_valid(t):
					(t as CPUParticles3D).global_position = p
			elif s.landed[i] == 0:
				s.landed[i] = 1
				mm.set_instance_transform(i, _xf(s.p1[i], s.rot0[i] + s.spin[i] * dur, s.sc[i]))
				_drop_trail(s, i)
			elif a > dur + s.stay[i]:
				var k := 1.0 - (a - dur - s.stay[i]) / SHRINK
				if k <= 0.0:
					mm.set_instance_transform(i, HIDDEN)
					done.append(i)
				else:
					mm.set_instance_transform(i, _xf(s.p1[i], s.rot0[i] + s.spin[i] * dur, s.sc[i] * k))
		for i in done:
			s.live.remove_at(s.live.find(i))
			s.used[i] = 0
