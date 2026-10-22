class_name Woonhuis
extends Node3D
## Woonhuis van 2 verdiepingen in de stad achter de brug (assets/woonhuis.glb, gemaakt in Blender: bron/woonhuis).
## Je kunt naar binnen: het dak verdwijnt, op de begane grond ook de verdieping, en de muren aan de camerakant
## gaan weg zodat je jezelf ziet. De trap brengt je naar boven (hoogte via floor_at, zoals de toren met elev).
## Alles kan kapot: elk muurstuk (M0*, M1*, P*, T_*) gaat van heel naar kapot naar weg, met puin als dekking.
## Vallen er 6 muurstukken van de begane grond weg, dan zakt de verdieping in.
## Lokale maten (Godot): voorkant (deur) aan +Z, x -4..4, z -3,5..3,5, tuin tot z = -10.

const F0 := 0.3            # vloer begane grond
const F1 := 3.2            # vloer verdieping
const HX := 4.0
const HZ := 3.5
const STAIR_X0 := -3.75
const STAIR_X1 := -2.75
const STAIR_B0 := -1.8     # trap in Blender-y (= -z): onderste trede ...
const STAIR_B1 := 2.25     # ... tot de overloop
const HOLE_B0 := -1.2      # trapgat in de verdiepingsvloer begint hier
const HP := {"M": 320.0, "P": 160.0, "T": 140.0}
const COLLAPSE := 6

static var all: Array = []

var model: Node3D
var segs: Array = []        # {name, node, heel, kapot, body, shape_heel, shape_kapot, hp, max, staat, out, floor}
var doors: Array = []       # {node, closed, t}
var _dak: Node3D
var _dak_heel: Node3D
var _dak_kapot: Node3D
var _ver: Node3D
var _puin: Dictionary = {}
var _collapsed := false
var _inside := -1           # -1 buiten, 0 begane grond, 1 verdieping
var _hidden: Array = []     # muurstukken die nu voor de camera weg zijn


## Zet een huis neer in de wereld (Level), yaw in radialen.
static func place(parent: Node3D, at: Vector3, yaw := 0.0) -> Woonhuis:
	var h := Woonhuis.new()
	h.position = at
	h.rotation.y = yaw
	parent.add_child(h)
	return h


func _ready() -> void:
	all.append(self)
	add_to_group("huis")
	model = (load("res://assets/woonhuis.glb") as PackedScene).instantiate()
	add_child(model)
	for l in model.find_children("*", "Light3D", true, false):
		l.visible = false   # lampen pas 's nachts (scheelt op de iPhone)
	_dak = model.find_child("Dak", true, false)
	_ver = model.find_child("Verdieping", true, false)
	var puin: Node3D = model.find_child("Puin", true, false)
	for c in puin.get_children():
		_puin[c.name] = c
	puin.visible = false
	for n in model.find_children("*", "Node3D", true, false):
		var heel := n.get_node_or_null(NodePath(String(n.name) + "_heel")) as MeshInstance3D
		var kapot := n.get_node_or_null(NodePath(String(n.name) + "_kapot")) as MeshInstance3D
		if heel == null or kapot == null:
			continue
		kapot.visible = false
		if n.name == "Dak":
			_dak_heel = heel
			_dak_kapot = kapot
			continue
		if n.name == "Vloer1":
			continue
		_add_seg(n, heel, kapot)
	for nm in ["DeurVoor", "DeurAchter", "DeurBinnen0", "DeurBinnen1"]:
		var d: Node3D = model.find_child(nm, true, false)
		if d:
			doors.append({"node": d, "closed": d.rotation.y, "t": 0.0})
	_guards()


func _exit_tree() -> void:
	all.erase(self)


func _add_seg(n: Node3D, heel: MeshInstance3D, kapot: MeshInstance3D) -> void:
	var body := HouseBody.new()
	body.collision_layer = Kit.LAYER_WALL
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh_heel := _wall_shape(heel)
	cs.shape = sh_heel
	body.add_child(cs)
	heel.add_child(body)
	var kind := String(n.name).substr(0, 1)
	var hp: float = HP.get(kind, 200.0)
	var s := {"name": String(n.name), "node": n, "heel": heel, "kapot": kapot, "body": body, "cs": cs,
		"shape_heel": sh_heel, "shape_kapot": null, "hp": hp, "max": hp, "staat": 0,
		"floor": 1 if String(n.name).begins_with("M1") or n.name == "P1" else 0}
	body.house = self
	body.seg = s
	segs.append(s)


## Botsvorm van alleen het metselwerk (pleister/binnen/baksteen): kozijnen, luiken en vensterbanken zitten niet in de weg.
func _wall_shape(mi: MeshInstance3D) -> Shape3D:
	var src := mi.mesh
	var keep := ArrayMesh.new()
	for i in src.get_surface_count():
		var m := src.surface_get_material(i)
		if m and m.resource_name in ["Pleister", "Binnen", "Baksteen"]:
			keep.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, src.surface_get_arrays(i))
	if keep.get_surface_count() == 0:
		return src.create_trimesh_shape()
	return keep.create_trimesh_shape()


## Extra botsvlakken: de zijkant van de trap (beneden), de reling rond het trapgat en het balkonhek (boven).
func _guards() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Kit.LAYER_WALL
	body.collision_mask = 0
	add_child(body)
	# trapwang aan de kamerkant en de achterkant van de trap onder de overloop
	_box(body, Vector3(STAIR_X1 + 0.06, (F0 + F1) * 0.5 - 0.1, -(STAIR_B0 + 0.5 + STAIR_B1) * 0.5), Vector3(0.1, F1 - F0 - 0.2, STAIR_B1 - STAIR_B0 - 0.5))
	_box(body, Vector3((STAIR_X0 + STAIR_X1) * 0.5, F0 + 1.3, -(STAIR_B1 + 0.06)), Vector3(STAIR_X1 - STAIR_X0, 2.0, 0.1))
	# reling boven
	_box(body, Vector3(STAIR_X1 + 0.06, F1 + 0.55, -(HOLE_B0 + STAIR_B1) * 0.5), Vector3(0.1, 1.1, STAIR_B1 - HOLE_B0))
	_box(body, Vector3((STAIR_X0 + STAIR_X1) * 0.5, F1 + 0.55, -HOLE_B0 + 0.04), Vector3(STAIR_X1 - STAIR_X0 + 0.1, 1.1, 0.1))
	# balkonhek (balkon x -0.1..2.1, z 3.5..4.45)
	_box(body, Vector3(1.0, F1 + 0.55, 4.45), Vector3(2.2, 1.1, 0.1))
	_box(body, Vector3(-0.08, F1 + 0.55, 3.97), Vector3(0.1, 1.1, 0.95))
	_box(body, Vector3(2.08, F1 + 0.55, 3.97), Vector3(0.1, 1.1, 0.95))


func _box(body: StaticBody3D, pos: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = pos
	body.add_child(cs)


# ---------------------------------------------------------------- hoogte (trap en verdieping)

## Vloerhoogte op wereldpositie p voor iemand die nu op hoogte cur staat; -1 als p niet bij een huis hoort.
static func floor_at(p: Vector3, cur: float) -> float:
	for h: Woonhuis in all:
		var y := h._floor_local(h.to_local(p), cur)
		if y >= 0.0:
			return y
	return -1.0


func _floor_local(lp: Vector3, cur: float) -> float:
	var up := cur > F1 - 0.6 and not _collapsed
	var b := -lp.z
	# balkon: alleen voor wie boven is
	if up and lp.x > -0.15 and lp.x < 2.15 and lp.z > HZ - 0.05 and lp.z < HZ + 1.0:
		return F1
	if absf(lp.x) > HX + 0.05 or absf(lp.z) > HZ + 0.05:
		return -1.0
	if lp.x > STAIR_X0 - 0.1 and lp.x < STAIR_X1 + 0.1 and b > STAIR_B0 - 0.05 and b < STAIR_B1 and not _collapsed:
		var stair := F0 + clampf((b - STAIR_B0) / (STAIR_B1 - STAIR_B0), 0.0, 1.0) * (F1 - F0)
		if absf(cur - stair) < 0.9:
			return stair
		if up and b < HOLE_B0:
			return F1
		return stair if cur > stair else F0
	if up:
		return F1
	# drempels: buiten de muren loopt de grond van 0 naar de vloer
	if absf(lp.x) > HX - 0.25 or absf(lp.z) > HZ - 0.25:
		return F0 * 0.5
	return F0


# ---------------------------------------------------------------- zicht: dak, verdieping en de muren voor de camera

func _process(delta: float) -> void:
	var p = Game.player
	var where := -1
	if p != null and not p.driving:
		var lp := to_local(p.global_position)
		var on_balcony: bool = p.position.y > F1 - 0.6 and lp.x > -0.2 and lp.x < 2.2 and lp.z > HZ and lp.z < HZ + 1.1
		if (absf(lp.x) < HX + 0.3 and absf(lp.z) < HZ + 0.3) or on_balcony:
			where = 1 if p.position.y > F1 - 0.6 else 0
	if where != _inside:
		_inside = where
		_apply_view()
	# deuren gaan open als er iemand dichtbij is
	for d in doors:
		var n: Node3D = d.node
		var near := false
		if p != null:
			var dp: Vector3 = n.global_position - p.global_position
			near = Vector2(dp.x, dp.z).length() < 1.9 and absf(dp.y) < 1.5
		d.t = move_toward(d.t, 1.0 if near else 0.0, delta * 3.0)
		n.rotation.y = d.closed + d.t * PI * 0.5


func _apply_view() -> void:
	for s in _hidden:
		_show_seg(s, true)
	_hidden.clear()
	if _dak:
		_dak.visible = _inside < 0
	if _ver:
		_ver.visible = _inside != 0 or _collapsed
	if _inside < 0:
		return
	# muren van deze verdieping die naar de camera (+Z in de wereld) kijken
	var cam_dir := Vector3(0, 0, 1)
	for s in segs:
		if s.staat >= 2 or String(s.name).begins_with("T"):
			continue
		if s.floor != _inside:
			continue
		var outward: Vector3 = (s.node as Node3D).global_transform.basis.z   # buitenkant = lokale +Z (Blender -Y)
		if String(s.name).begins_with("P") or outward.dot(cam_dir) > 0.4:
			_show_seg(s, false)
			_hidden.append(s)


func _show_seg(s: Dictionary, vis: bool) -> void:
	(s.heel as Node3D).visible = vis and s.staat == 0
	(s.kapot as Node3D).visible = vis and s.staat == 1


# ---------------------------------------------------------------- slopen

## Ontploffing in de buurt van huizen (raketten, tankgranaten): muurstukken in de straal krijgen schade.
static func blast_all(at: Vector3, radius: float, dmg: float) -> void:
	for h: Woonhuis in all:
		if h.global_position.distance_to(at) < radius + 9.0:
			h.blast(at, radius, dmg)


func blast(at: Vector3, radius: float, dmg: float) -> void:
	for s in segs.duplicate():
		if s.staat >= 2:
			continue
		var aabb: AABB = (s.heel as MeshInstance3D).global_transform * (s.heel as MeshInstance3D).get_aabb()
		var closest := at.clamp(aabb.position, aabb.end)
		var d := closest.distance_to(at)
		if d < radius:
			damage(s, dmg * 2.2 * (1.0 - d / radius), at)
	if _dak_heel and _dak.visible:
		var top := global_position + Vector3(0, 7.0, 0)
		if Vector2(at.x - top.x, at.z - top.z).length() < 5.0 and at.y > 4.0:
			_roof_state(1)


func damage(s: Dictionary, dmg: float, from := Vector3.INF) -> void:
	if s.staat >= 2 or dmg <= 0.0:
		return
	s.hp -= dmg
	var c := _center(s)
	if randf() < 0.6:
		Fx.dust(get_parent(), c + Vector3(randf_range(-0.6, 0.6), randf_range(-0.8, 0.8), randf_range(-0.6, 0.6)))
	if s.staat == 0 and s.hp < s.max * 0.55:
		_set_state(s, 1)
		_chunks(s, 3)
		Sfx.play("thud", 0.8, c)
	if s.hp <= 0.0:
		_set_state(s, 2)
		_chunks(s, 5)
		_rubble(s)
		Sfx.play("thud", 1.0, c)
		_check_collapse()


func _set_state(s: Dictionary, st: int) -> void:
	s.staat = st
	var hidden_now: bool = _hidden.has(s)
	(s.heel as Node3D).visible = st == 0 and not hidden_now
	(s.kapot as Node3D).visible = st == 1 and not hidden_now
	var cs: CollisionShape3D = s.cs
	if st == 1:
		if s.shape_kapot == null:
			s.shape_kapot = _wall_shape(s.kapot)
		cs.shape = s.shape_kapot
		# de body hangt onder 'heel'; zelfde plek als 'kapot', dus alleen de vorm wisselt
	elif st >= 2:
		cs.disabled = true
		(s.body as StaticBody3D).collision_layer = 0
	if String(s.name).begins_with("M1") and st >= 2:
		var gone := segs.filter(func(x): return String(x.name).begins_with("M1") and x.staat >= 2).size()
		_roof_state(2 if gone >= 4 else 1)


## Voor het mikken van de tank: midden en buitenrichting van een muurstuk.
func seg_center(s: Dictionary) -> Vector3:
	return _center(s)


func seg_outward(s: Dictionary) -> Vector3:
	return _outward(s)


func _center(s: Dictionary) -> Vector3:
	var mi: MeshInstance3D = s.heel
	return (mi.global_transform * mi.get_aabb()).get_center()


func _outward(s: Dictionary) -> Vector3:
	var o: Vector3 = (s.node as Node3D).global_transform.basis.z
	o.y = 0.0
	return o.normalized()


## Brokken die wegvliegen en blijven liggen.
func _chunks(s: Dictionary, n: int) -> void:
	var c := _center(s)
	var out := _outward(s)
	for i in n:
		var src: Node3D = _puin.get("Brok%d" % (i % 4))
		if src == null:
			return
		var m: Node3D = src.duplicate()
		m.visible = true
		get_parent().add_child(m)
		m.global_position = c + Vector3(randf_range(-0.6, 0.6), randf_range(-0.5, 0.8), randf_range(-0.6, 0.6))
		m.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		var land := m.global_position + out * randf_range(1.0, 3.2) + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
		land.y = 0.12
		var tw := m.create_tween()
		var top := (m.global_position + land) * 0.5 + Vector3.UP * randf_range(0.8, 1.8)
		var p0 := m.global_position
		tw.tween_method(func(t: float) -> void:
			m.global_position = p0.lerp(top, t).lerp(top.lerp(land, t), t)
			m.rotate_x(0.15), 0.0, 1.0, 0.55)
		tw.tween_interval(25.0)
		tw.tween_callback(m.queue_free)


## Puinhoop aan de voet van een weggeslagen muur: blijft liggen als dekking (houdt kogels tegen).
func _rubble(s: Dictionary, big := false) -> void:
	var c := _center(s)
	var out := _outward(s)
	var foot := c + out * (0.9 if s.floor == 0 else 2.0)
	foot.y = 0.0
	var small: bool = not big and (String(s.name).begins_with("T") or String(s.name).begins_with("P"))
	_pile(foot, "PuinKlein" if small else "PuinGroot", 0.75 if small else 0.85)
	for k in 3:
		Fx.dust(get_parent(), c + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)))


func _pile(at: Vector3, kind: String, sc: float) -> void:
	var src: Node3D = _puin.get(kind)
	if src == null:
		return
	var m: Node3D = src.duplicate()
	m.visible = true
	add_child(m)
	m.global_position = at
	m.rotation.y = randf() * TAU
	m.scale = Vector3.ONE * sc
	var body := StaticBody3D.new()
	body.collision_layer = Kit.LAYER_WALL
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	var r := (1.5 if kind == "PuinGroot" else 0.8) * sc
	b.size = Vector3(r * 1.5, 0.75 * sc + 0.2, r * 1.5)
	cs.shape = b
	cs.position.y = b.size.y * 0.5
	body.add_child(cs)
	m.add_child(body)


func _roof_state(st: int) -> void:
	if _dak_heel == null:
		return
	if st == 1 and _dak_heel.visible == false and _dak_kapot.visible == false and _dak.get_meta("weg", false):
		return
	if st == 1:
		if _dak_heel.visible:
			_dak_heel.visible = false
			_dak_kapot.visible = true
			Fx.dust(get_parent(), global_position + Vector3(-1.2, 7.0, 1.6))
	elif st >= 2 and not _dak.get_meta("weg", false):
		_dak.set_meta("weg", true)
		_dak_heel.visible = false
		_dak_kapot.visible = false
		_pile(to_global(Vector3(1.5, F0, 0.5)), "PuinGroot", 1.0)


## Te veel muren van de begane grond weg: de verdieping zakt in.
func _check_collapse() -> void:
	if _collapsed:
		return
	var gone := segs.filter(func(x): return String(x.name).begins_with("M0") and x.staat >= 2).size()
	if gone < COLLAPSE:
		return
	_collapsed = true
	var v1h: Node3D = _ver.find_child("Vloer1_heel", true, false)
	var v1k: Node3D = _ver.find_child("Vloer1_kapot", true, false)
	if v1h and v1k:
		v1h.visible = false
		v1k.visible = true
	for nm in ["Inrichting1", "Balkon", "DeurBinnen1"]:
		var o: Node3D = _ver.find_child(nm, true, false)
		if o:
			o.visible = false
	for s in segs:
		if s.floor == 1 and s.staat < 2:
			_set_state(s, 2 if randf() < 0.6 else 1)
	_roof_state(2)
	_pile(to_global(Vector3(2.2, F0, -0.5)), "PuinGroot", 1.15)
	_pile(to_global(Vector3(-1.0, F0, -1.5)), "PuinGroot", 1.0)
	Fx.explosion(get_parent(), global_position + Vector3(0, 3.0, 0), 1.4)
	for k in 8:
		Fx.dust(get_parent(), global_position + Vector3(randf_range(-4, 4), randf_range(0.5, 5), randf_range(-3.5, 3.5)))
	Game.banner.emit("HUIS INGESTORT", "", 1.4)
	_apply_view()
