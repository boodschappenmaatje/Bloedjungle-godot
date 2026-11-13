class_name AanvalFx
## Effecten van de slimme vijandaanval (keuze 3A en 6A): een rookgranaat die een rookgordijn legt voor het open stuk naar je muur, en een rode
## lichtkogel boven het verzamelpunt als de aanval begint (fase 2 en hoger). Goedkoop: een handvol billboards met de bestaande rooktextuur van
## de wapeneffecten (WapenFx) en één lamp per lichtkogel, alles met een tween en daarna weg.

const ROOK_N := 9            # wolken per gordijn
const ROOK_BREED := 15.0     # m breed
const ROOK_GROOT := 5.2      # m doorsnede van een wolk op zijn grootst
const ROOK_T := 16.0         # s dat het gordijn blijft hangen
const ROOK_WEG := 5.0        # s uitdoven
const LICHT_HOOG := 34.0     # m: zo hoog gaat de lichtkogel
const LICHT_T := 11.0        # s dalen

static var _mat_rook: StandardMaterial3D
static var _mat_bus: StandardMaterial3D
static var _mat_ster: StandardMaterial3D
static var rook_zicht := true       # uit te zetten in tests die de rook niet willen
static var _gordijnen: Array = []   # actieve rookgordijnen: {a, b (2D-eindpunten), tot (ms)}; ze blokkeren het zicht (zie rook_blokkeert)

const ROOK_DIK := 2.6        # m: halve dikte van het gordijn voor het zicht
const ROOK_NAAST := 6.0      # m: van dichtbij ziet men nog wel door de rook


static func _rook_mat() -> StandardMaterial3D:
	if _mat_rook == null:
		_mat_rook = WapenFx._puff_material().duplicate() as StandardMaterial3D
		_mat_rook.albedo_color = Color(0.86, 0.85, 0.82)   # witgrijze rook (een rookgranaat is lichter dan kruitdamp)
	return _mat_rook


## Een rookgranaat: een bus vliegt in een boog van `van` naar `naar`, rolt even, en legt een rookgordijn dwars op `voor` (de looprichting).
static func rookgranaat(parent: Node, van: Vector3, naar: Vector3, voor: Vector3) -> Node3D:
	if parent == null or not parent.is_inside_tree():
		return null
	var root := Node3D.new()
	root.name = "Rookgranaat"
	root.add_to_group("aanval_rook")
	parent.add_child(root)
	if _mat_bus == null:
		_mat_bus = StandardMaterial3D.new()
		_mat_bus.albedo_color = Color(0.22, 0.26, 0.17)
		_mat_bus.roughness = 0.6
		_mat_bus.metallic = 0.4
	var bus := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.07
	cyl.bottom_radius = 0.07
	cyl.height = 0.26
	cyl.radial_segments = 8
	cyl.rings = 1
	bus.mesh = cyl
	bus.material_override = _mat_bus
	bus.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(bus)
	bus.global_position = van
	var land := Vector3(naar.x, 0.08, naar.z)
	var vlucht := clampf(van.distance_to(land) / 14.0, 0.6, 1.6)
	var tw := root.create_tween()
	tw.tween_method(func(u: float) -> void:
		bus.global_position = van.lerp(land, u) + Vector3.UP * sin(u * PI) * (2.5 + vlucht * 3.0)
		bus.rotation = Vector3(u * 14.0, u * 3.0, 0.0), 0.0, 1.0, vlucht)
	tw.tween_callback(func() -> void:
		Sfx.play("wuuf", 0.35, land)
		_gordijn(root, land, voor))
	tw.tween_interval(ROOK_T + ROOK_WEG + 1.0)
	tw.tween_callback(root.queue_free)
	return root


## Blokkeert een rookgordijn de zichtlijn van `van` naar `naar`? Een gordijn telt vanaf het moment dat de wolken groot zijn tot het begint uit te doven.
static func zet_rook_zicht(aan: bool) -> void:
	rook_zicht = aan


## Spelklok in ms (fysicaframes, dus gelijk aan het spel ook als dat sneller of trager loopt).
static func _nu() -> int:
	return int(float(Engine.get_physics_frames()) * 1000.0 / float(Engine.physics_ticks_per_second))


static func rook_blokkeert(van: Vector3, naar: Vector3) -> bool:
	if not rook_zicht or _gordijnen.is_empty():
		return false
	var nu := _nu()
	var a := Vector2(van.x, van.z)
	var b := Vector2(naar.x, naar.z)
	if a.distance_to(b) < ROOK_NAAST:
		return false
	var i := _gordijnen.size() - 1
	while i >= 0:
		var gd: Dictionary = _gordijnen[i]
		if nu > int(gd.tot):
			_gordijnen.remove_at(i)
		elif nu >= int(gd.van) and _seg_afstand(a, b, gd.a, gd.b) < ROOK_DIK:
			return true
		i -= 1
	return false


## Kortste afstand tussen twee lijnstukken in het vlak.
static func _seg_afstand(p1: Vector2, p2: Vector2, q1: Vector2, q2: Vector2) -> float:
	if Geometry2D.segment_intersects_segment(p1, p2, q1, q2) != null:
		return 0.0
	var c1 := Geometry2D.get_closest_point_to_segment(p1, q1, q2).distance_to(p1)
	var c2 := Geometry2D.get_closest_point_to_segment(p2, q1, q2).distance_to(p2)
	var c3 := Geometry2D.get_closest_point_to_segment(q1, p1, p2).distance_to(q1)
	var c4 := Geometry2D.get_closest_point_to_segment(q2, p1, p2).distance_to(q2)
	return minf(minf(c1, c2), minf(c3, c4))


static func _gordijn(root: Node3D, at: Vector3, voor: Vector3) -> void:
	var dwars := Vector3(-voor.z, 0.0, voor.x).normalized()
	if dwars.length() < 0.5:
		dwars = Vector3.RIGHT
	var nu := _nu()
	_gordijnen.append({
		"a": Vector2(at.x, at.z) - Vector2(dwars.x, dwars.z) * ROOK_BREED * 0.45,
		"b": Vector2(at.x, at.z) + Vector2(dwars.x, dwars.z) * ROOK_BREED * 0.45,
		"van": nu + 3500, "tot": nu + int((ROOK_T + ROOK_WEG * 0.4) * 1000.0)})
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = _rook_mat()
	for i in ROOK_N:
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		var k := (float(i) / float(ROOK_N - 1)) - 0.5
		var plek := at + dwars * k * ROOK_BREED + voor * randf_range(-1.2, 1.2)
		var start := randf_range(0.0, 1.6) + absf(k) * 2.5   # het gordijn groeit vanuit het midden naar buiten
		var groot := ROOK_GROOT * randf_range(0.8, 1.15)
		var drift := Vector3(0.12, 0.0, -0.07) + dwars * k * 0.05
		mi.global_position = at + Vector3.UP * 0.4
		mi.scale = Vector3.ONE * 0.3
		mi.transparency = 1.0
		var tw := mi.create_tween()
		tw.tween_interval(start)
		tw.tween_method(func(u: float) -> void:
			var s := 0.3 + (groot - 0.3) * (1.0 - pow(1.0 - minf(u * 4.0, 1.0), 3.0))
			mi.scale = Vector3.ONE * s
			mi.global_position = at.lerp(plek, minf(u * 5.0, 1.0)) + Vector3.UP * (s * 0.42) + drift * u * ROOK_T
			var a := 0.62 * minf(u * 6.0, 1.0)
			mi.transparency = 1.0 - a, 0.0, 1.0, ROOK_T)
		tw.tween_method(func(u: float) -> void:
			mi.transparency = 1.0 - 0.62 * (1.0 - u)
			mi.scale = Vector3.ONE * groot * (1.0 + 0.3 * u)
			mi.global_position += Vector3.UP * 0.01, 0.0, 1.0, ROOK_WEG)


## Een rode lichtkogel: schiet omhoog boven `at`, hangt even en daalt langzaam schommelend, met een rode lamp die over de grond zwaait.
static func lichtkogel(parent: Node, at: Vector3) -> Node3D:
	if parent == null or not parent.is_inside_tree():
		return null
	var root := Node3D.new()
	root.name = "Lichtkogel"
	root.add_to_group("aanval_lichtkogel")
	parent.add_child(root)
	if _mat_ster == null:
		_mat_ster = StandardMaterial3D.new()
		_mat_ster.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_ster.albedo_color = Color(1.0, 0.25, 0.15)
		_mat_ster.emission_enabled = true
		_mat_ster.emission = Color(1.0, 0.2, 0.1)
		_mat_ster.emission_energy_multiplier = 6.0
	var ster := MeshInstance3D.new()
	var bol := SphereMesh.new()
	bol.radius = 0.32
	bol.height = 0.64
	bol.radial_segments = 8
	bol.rings = 4
	ster.mesh = bol
	ster.material_override = _mat_ster
	ster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ster)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.3, 0.18)
	lamp.light_energy = 0.0
	lamp.omni_range = 34.0
	lamp.omni_attenuation = 1.4
	lamp.shadow_enabled = false
	ster.add_child(lamp)
	var start := Vector3(at.x, 1.5, at.z)
	ster.global_position = start
	Sfx.play("rocket", 0.35, start)
	var top := start + Vector3(randf_range(-3.0, 3.0), LICHT_HOOG, randf_range(-3.0, 3.0))
	var tw := root.create_tween()
	tw.tween_method(func(u: float) -> void:
		ster.global_position = start.lerp(top, 1.0 - pow(1.0 - u, 2.5))
		lamp.light_energy = 3.2 * u
		if randf() < 0.5:
			WapenFx._puff(root.get_parent(), ster.global_position, Vector3.DOWN, {"smoke_size": 0.35, "smoke_grow": 2.0, "smoke_life": 1.6, "smoke_speed": 0.4, "smoke_a": 0.35}, 0, "rook", Color(0.8, 0.8, 0.78)), 0.0, 1.0, 1.3)
	tw.tween_method(func(u: float) -> void:
		var y := LICHT_HOOG * (1.0 - u) + 1.5
		ster.global_position = Vector3(top.x + sin(u * 9.0) * 1.6, y, top.z + cos(u * 7.0) * 1.1)
		lamp.light_energy = (3.2 + randf_range(-0.6, 0.6)) * (1.0 - smoothstep(0.85, 1.0, u)), 0.0, 1.0, LICHT_T)
	tw.tween_callback(root.queue_free)
	return root
