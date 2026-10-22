class_name Woonhuis
extends Node3D
## Gebouwen in de stad achter de brug, gemaakt in Blender (bron/woonhuis, bron/winkel). Eén script voor alle soorten:
## de maten, trappen en sloopregels staan per soort in _spec().
## Je kunt naar binnen: het dak verdwijnt, en ook de verdiepingen boven je, en de muren aan de camerakant
## gaan weg zodat je jezelf ziet. Trappen brengen je naar boven (hoogte via floor_at, zoals de toren met elev).
## Alles kan kapot: elk muurstuk (M0*, M1*, M2*, P*, T_*) gaat van heel naar kapot naar weg, met puin als dekking.
## Vallen er genoeg muurstukken van een laag weg, dan zakken de verdiepingen erboven in; bij de winkel stort
## het hele gebouw in (de 'Ruine' uit het model komt ervoor in de plaats).
## Lokale maten (Godot): voorkant (deur) aan +Z. Trappen en gaten in Blender-y (b = -z).

const HP := {"M": 320.0, "P": 160.0, "T": 140.0}


## Per soort: model, vloerhoogtes, grondvlak, trappen [x0, x1, b0 (onder), b1 (boven), van laag, naar laag],
## trapgaten [laag, x0, x1, b0, b1], balkon [x0, x1, z0, z1, laag], botsvlakken [midden, maat],
## instorten: per laag hoeveel muurstukken weg moeten voordat alles erboven valt (0 = nooit).
static func _spec(kind: String) -> Dictionary:
	if kind == "winkel":
		var f0 := 0.3
		var f1 := 3.8
		var f2 := 6.8
		return {
			"glb": "res://assets/winkel.glb", "levels": [f0, f1, f2], "hx": 4.5, "hz": 4.0,
			"groups": ["Begane", "Verdieping", "Verdieping2"],
			"stairs": [[-4.25, -3.25, -1.4, 2.6, 0, 1], [-3.25, -2.25, 2.6, -1.4, 1, 2]],
			"holes": [[1, -4.3, -3.2, -1.0, 2.6], [2, -3.3, -2.2, -1.4, 2.2]],
			"balcony": [-1.15, 1.15, 3.95, 4.95, 1],
			"guards": [
				# trap A: wang aan de winkelkant; muurtje tussen trap A en B (boven vloer 1, ook reling boven)
				[Vector3(-3.19, (f0 + f1) * 0.5 - 0.1, -0.85), Vector3(0.1, f1 - f0 - 0.2, 3.5)],
				[Vector3(-3.2, (f1 + f2 + 1.0) * 0.5, -0.6), Vector3(0.1, f2 + 1.0 - f1, 4.0)],
				# trap B: wang aan de kamerkant en de dichte kant onder het bovenste bordes
				[Vector3(-2.19, (f1 + f2 - 0.2) * 0.5, -0.35), Vector3(0.1, f2 - f1 - 0.2, 3.5)],
				[Vector3(-2.75, (f1 + f2 - 0.2) * 0.5, 1.46), Vector3(1.0, f2 - f1 - 0.2, 0.1)],
				# reling trapgat vloer 1 (voorkant) en vloer 2 (oost en achter)
				[Vector3(-3.75, f1 + 0.55, 1.03), Vector3(1.0, 1.1, 0.1)],
				[Vector3(-2.19, f2 + 0.55, -0.4), Vector3(0.1, 1.1, 3.6)],
				[Vector3(-2.75, f2 + 0.55, -2.23), Vector3(1.1, 1.1, 0.1)],
				# balkonhek
				[Vector3(0.0, f1 + 0.55, 4.88), Vector3(2.2, 1.1, 0.1)],
				[Vector3(-1.08, f1 + 0.55, 4.45), Vector3(0.1, 1.1, 0.9)],
				[Vector3(1.08, f1 + 0.55, 4.45), Vector3(0.1, 1.1, 0.9)],
			],
			"doors": ["DeurVoor", "DeurAchter", "DeurBinnen0", "DeurBinnen1", "DeurBinnen2"],
			"collapse": [5, 5], "ruin": true,
			"ruin_boxes": [[Vector3(0, 0.8, 0), Vector3(8.4, 1.6, 7.4)], [Vector3(0, 1.9, 0.2), Vector3(5.6, 1.4, 5.0)]],
			"roof_y": 8.0, "roof_r": 5.5, "roof_c": Vector3(-0.6, 9.9, 0.8),
			"fall_piles": [[Vector3(2.0, f0, -0.5), 1.15], [Vector3(-0.8, f0, 1.4), 1.0], [Vector3(1.0, f0, 2.0), 1.0]],
			"near": 10.0, "banner": "WINKEL INGESTORT",
		}
	var f0 := 0.3
	var f1 := 3.2
	return {
		"glb": "res://assets/woonhuis.glb", "levels": [f0, f1], "hx": 4.0, "hz": 3.5,
		"groups": ["Begane", "Verdieping"],
		"stairs": [[-3.75, -2.75, -1.8, 2.25, 0, 1]],
		"holes": [[1, -3.85, -2.65, -1.2, 2.25]],
		"balcony": [-0.15, 2.15, 3.45, 4.5, 1],
		"guards": [
			# trapwang aan de kamerkant en de achterkant van de trap onder de overloop
			[Vector3(-2.69, (f0 + f1) * 0.5 - 0.1, -(-1.8 + 0.5 + 2.25) * 0.5), Vector3(0.1, f1 - f0 - 0.2, 2.25 + 1.8 - 0.5)],
			[Vector3(-3.25, f0 + 1.3, -2.31), Vector3(1.0, 2.0, 0.1)],
			# reling boven
			[Vector3(-2.69, f1 + 0.55, -(-1.2 + 2.25) * 0.5), Vector3(0.1, 1.1, 2.25 + 1.2)],
			[Vector3(-3.25, f1 + 0.55, 1.24), Vector3(1.1, 1.1, 0.1)],
			# balkonhek (balkon x -0.1..2.1, z 3.5..4.45)
			[Vector3(1.0, f1 + 0.55, 4.45), Vector3(2.2, 1.1, 0.1)],
			[Vector3(-0.08, f1 + 0.55, 3.97), Vector3(0.1, 1.1, 0.95)],
			[Vector3(2.08, f1 + 0.55, 3.97), Vector3(0.1, 1.1, 0.95)],
		],
		"doors": ["DeurVoor", "DeurAchter", "DeurBinnen0", "DeurBinnen1"],
		"collapse": [6], "ruin": false, "ruin_boxes": [],
		"roof_y": 4.0, "roof_r": 5.0, "roof_c": Vector3(0, 7.0, 0),
		"fall_piles": [[Vector3(2.2, f0, -0.5), 1.15], [Vector3(-1.0, f0, -1.5), 1.0]],
		"near": 9.0, "banner": "HUIS INGESTORT",
	}


static var all: Array = []

var kind := "woonhuis"
var spec: Dictionary
var levels: Array
var model: Node3D
var segs: Array = []        # {name, node, heel, kapot, body, shape_heel, shape_kapot, hp, max, staat, out, floor}
var doors: Array = []       # {node, closed, t}
var _dak: Node3D
var _dak_heel: Node3D
var _dak_kapot: Node3D
var _ver: Node3D           # eerste verdieping (Verdieping)
var _groups: Array = []     # Begane, Verdieping, (Verdieping2): per laag
var _puin: Dictionary = {}
var _collapsed := false     # er is iets ingestort
var _fall := 99             # laagste laag die is ingestort
var _ruin := false          # het hele gebouw ligt plat
var _guard_body: StaticBody3D
var _inside := -1           # -1 buiten, anders de laag waarop je staat
var _hidden: Array = []     # muurstukken die nu voor de camera weg zijn


## Zet een huis neer in de wereld (Level), yaw in radialen.
static func place(parent: Node3D, at: Vector3, yaw := 0.0, soort := "woonhuis") -> Woonhuis:
	var h := Woonhuis.new()
	h.kind = soort
	h.position = at
	h.rotation.y = yaw
	parent.add_child(h)
	return h


func _ready() -> void:
	all.append(self)
	add_to_group("huis")
	add_to_group(kind)
	spec = _spec(kind)
	levels = spec.levels
	model = (load(spec.glb) as PackedScene).instantiate()
	add_child(model)
	for l in model.find_children("*", "Light3D", true, false):
		l.visible = false   # lampen pas 's nachts (scheelt op de iPhone)
	_dak = model.find_child("Dak", true, false)
	_ver = model.find_child("Verdieping", true, false)
	for g in spec.groups:
		_groups.append(model.find_child(g, true, false))
	var ruine: Node3D = model.find_child("Ruine", true, false)
	if ruine:
		ruine.visible = false
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
		if String(n.name).begins_with("Vloer"):
			continue
		_add_seg(n, heel, kapot)
	for nm in spec.doors:
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
		"floor": _seg_floor(String(n.name))}
	body.house = self
	body.seg = s
	segs.append(s)


## Laag van een muurstuk: M1V0 en P1 horen bij laag 1, T_* (tuin) bij 0.
static func _seg_floor(nm: String) -> int:
	if nm.length() > 1 and (nm[0] == "M" or nm[0] == "P") and nm[1].is_valid_int():
		return int(nm[1])
	return 0


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


## Extra botsvlakken: trapwangen, relingen rond de trapgaten en het balkonhek.
func _guards() -> void:
	_guard_body = StaticBody3D.new()
	_guard_body.collision_layer = Kit.LAYER_WALL
	_guard_body.collision_mask = 0
	add_child(_guard_body)
	for g in spec.guards:
		_box(_guard_body, g[0], g[1])


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
	if _ruin:
		return -1.0
	var hx: float = spec.hx
	var hz: float = spec.hz
	var b := -lp.z
	# balkon: alleen voor wie boven is
	var bal: Array = spec.balcony
	var bl: int = bal[4]
	if bl < _fall and cur > levels[bl] - 0.6 and lp.x > bal[0] and lp.x < bal[1] and lp.z > bal[2] and lp.z < bal[3]:
		return levels[bl]
	if absf(lp.x) > hx + 0.05 or absf(lp.z) > hz + 0.05:
		return -1.0
	# de hoogste vloer of trede onder je voeten waar je bij kunt (een trede op, of vallen)
	var lim := cur + 0.6
	var best: float = levels[0]
	if absf(lp.x) > hx - 0.25 or absf(lp.z) > hz - 0.25:
		best = levels[0] * 0.5   # drempels: buiten de muren loopt de grond van 0 naar de vloer
	for k in range(1, mini(levels.size(), _fall)):
		if levels[k] <= lim and levels[k] > best and not _in_hole(k, lp.x, b):
			best = levels[k]
	for st in spec.stairs:
		if st[5] >= _fall:
			continue
		if lp.x > st[0] - 0.1 and lp.x < st[1] + 0.1 and b > minf(st[2], st[3]) - 0.05 and b < maxf(st[2], st[3]) + 0.05:
			var t := clampf((b - st[2]) / (st[3] - st[2]), 0.0, 1.0)
			var y := lerpf(levels[st[4]], levels[st[5]], t)
			if y <= lim and y > best:
				best = y
	return best


func _in_hole(k: int, x: float, b: float) -> bool:
	for h in spec.holes:
		if h[0] == k and x > h[1] and x < h[2] and b > h[3] and b < h[4]:
			return true
	return false


# ---------------------------------------------------------------- zicht: dak, verdieping en de muren voor de camera

func _process(delta: float) -> void:
	var p = Game.player
	var where := -1
	if p != null and not p.driving:
		var lp := to_local(p.global_position)
		var bal: Array = spec.balcony
		var on_balcony: bool = p.position.y > levels[bal[4]] - 0.6 and lp.x > bal[0] - 0.05 and lp.x < bal[1] + 0.05 \
			and lp.z > bal[2] and lp.z < bal[3] + 0.1
		if not _ruin and ((absf(lp.x) < spec.hx + 0.3 and absf(lp.z) < spec.hz + 0.3) or on_balcony):
			where = 0
			for k in range(1, levels.size()):
				if p.position.y > levels[k] - 0.6:
					where = k
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
	if _ruin:
		return
	if _dak:
		_dak.visible = _inside < 0
	for k in range(1, _groups.size()):
		if _groups[k]:
			(_groups[k] as Node3D).visible = _inside < 0 or k <= _inside or k >= _fall
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
		if h.global_position.distance_to(at) < radius + float(h.spec.near):
			h.blast(at, radius, dmg)


func blast(at: Vector3, radius: float, dmg: float) -> void:
	if _ruin:
		return
	for s in segs.duplicate():
		if s.staat >= 2:
			continue
		var aabb: AABB = (s.heel as MeshInstance3D).global_transform * (s.heel as MeshInstance3D).get_aabb()
		var closest := at.clamp(aabb.position, aabb.end)
		var d := closest.distance_to(at)
		if d < radius:
			damage(s, dmg * 2.2 * (1.0 - d / radius), at)
	if _dak_heel and _dak.visible and not _ruin:
		var top := to_global(spec.roof_c)
		if Vector2(at.x - top.x, at.z - top.z).length() < spec.roof_r and at.y > spec.roof_y:
			_roof_state(1)


func damage(s: Dictionary, dmg: float, from := Vector3.INF) -> void:
	if s.staat >= 2 or dmg <= 0.0 or _ruin:
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
	var top := "M%d" % (levels.size() - 1)
	if String(s.name).begins_with(top) and st >= 2:
		var gone := segs.filter(func(x): return String(x.name).begins_with(top) and x.staat >= 2).size()
		_roof_state(2 if gone >= 4 else 1)


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
			Fx.dust(get_parent(), to_global(spec.roof_c))
	elif st >= 2 and not _dak.get_meta("weg", false):
		_dak.set_meta("weg", true)
		_dak_heel.visible = false
		_dak_kapot.visible = false
		# het dak valt op de hoogste vloer die nog staat
		var y: float = levels[mini(_fall, levels.size()) - 1]
		_pile(to_global(Vector3(1.5, y, 0.5)), "PuinGroot", 1.0)


## Te veel muren van een laag weg: alles erboven zakt in. Bij de winkel stort dan het hele gebouw in.
func _check_collapse() -> void:
	if _ruin:
		return
	var rules: Array = spec.collapse
	for lvl in rules.size():
		if lvl + 1 >= _fall or int(rules[lvl]) <= 0:
			continue
		var pre := "M%d" % lvl
		var gone := segs.filter(func(x): return String(x.name).begins_with(pre) and x.staat >= 2).size()
		if gone < int(rules[lvl]):
			continue
		if lvl == 0 and spec.ruin:
			_ruin_all()
		else:
			_fall_from(lvl + 1)
		return


## Verdieping k en alles erboven zakt in: vloeren kapot, inrichting weg, muren erboven kapot of weg, dak weg.
func _fall_from(k: int) -> void:
	_fall = k
	_collapsed = true
	for j in range(k, levels.size()):
		var g: Node3D = _groups[j]
		var vh: Node3D = model.find_child("Vloer%d_heel" % j, true, false)
		var vk: Node3D = model.find_child("Vloer%d_kapot" % j, true, false)
		if vh and vk:
			vh.visible = false
			vk.visible = true
		if g:
			for c in g.get_children():
				var nm := String(c.name)
				if nm.begins_with("Inrichting") or nm.begins_with("DeurBinnen") or nm == "Balkon":
					c.visible = false
	for s in segs:
		if s.floor >= k and s.staat < 2:
			_set_state(s, 2 if randf() < 0.6 else 1)
	_roof_state(2)
	for fp in spec.fall_piles:
		_pile(to_global(fp[0]), "PuinGroot", fp[1])
	var mid: float = levels[k]
	Fx.explosion(get_parent(), global_position + Vector3(0, mid, 0), 1.4)
	for n in 8:
		Fx.dust(get_parent(), global_position + Vector3(randf_range(-spec.hx, spec.hx), randf_range(0.5, mid + 2.0), randf_range(-spec.hz, spec.hz)))
	Game.banner.emit(spec.banner if k == 1 else "VERDIEPING INGESTORT", "", 1.4)
	_apply_view()


## Het hele gebouw stort in: alles weg, de ruïne uit het model komt ervoor in de plaats (houdt kogels tegen).
func _ruin_all() -> void:
	_ruin = true
	_collapsed = true
	_fall = 0
	for s in segs:
		s.staat = 2
		(s.cs as CollisionShape3D).disabled = true
		(s.body as StaticBody3D).collision_layer = 0
	for g in _groups:
		if g:
			(g as Node3D).visible = false
	if _dak:
		_dak.visible = false
	for c in get_children():
		if c is StaticBody3D or (c is Node3D and c != model):
			c.queue_free()   # losse puinhopen en de relingen
	var ruine: Node3D = model.find_child("Ruine", true, false)
	if ruine:
		ruine.visible = true
	var body := StaticBody3D.new()
	body.collision_layer = Kit.LAYER_WALL
	body.collision_mask = 0
	add_child(body)
	for rb in spec.ruin_boxes:
		_box(body, rb[0], rb[1])
	# wie binnen stond, wordt bedolven en naar buiten geduwd
	var p = Game.player
	if p != null and _inside >= 0 and not p.driving:
		p.global_position = to_global(Vector3(0, 0, spec.hz + 2.6))
		p.position.y = 0.0
		p.hit(60.0, Vector3(0, 0, 1), false)
	_inside = -1
	for n in 3:
		Fx.explosion(get_parent(), to_global(Vector3(randf_range(-2, 2), 2.0 + n * 2.5, randf_range(-2, 2))), 1.6)
	for n in 14:
		Fx.dust(get_parent(), to_global(Vector3(randf_range(-5, 5), randf_range(0.3, 6.0), randf_range(-4.5, 4.5))))
	Sfx.play("thud", 1.0, global_position)
	Game.banner.emit(spec.banner, "", 1.6)
