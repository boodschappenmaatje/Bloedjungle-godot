class_name Stad
extends Node3D
## De stad achter de brug: wegdelen, gebouwen en straatmeubilair, opgebouwd uit een lijst (StadData.ITEMS).
## De stadseditor (stad_editor.gd) voegt dingen toe, schuift ze en haalt ze weg; Stad houdt de 3D-wereld bij.
## Een item is een woordenboek: k = soort (zie KINDS), x en z = midden in meters, r = kwartslagen (0-3), m = gespiegeld.
## Wegen zitten samen in één mesh (snel op de iPhone); gebouwen en straatmeubilair zijn losse nodes.

const CELL := 6.0   # een wegdeel is 6 x 6 m
const ASPHALT_Y := 0.03
const PAVE_Y := 0.1
const SAVE_PATH := "user://stad_editor.json"

## cat: weg / gebouw / straat. hx en hz = halve maat van de voetafdruk, snap = rasterstap, cost = zwaarte voor de iPhone.
## open = zijkanten van een wegdeel (N, E, S, W), rw = breedte van het asfalt. h = hoogte van een grijs blok.
## spacing = afstand tussen kopieën met de kwast, road = mag op de weg staan.
const KINDS := {
	"weg_recht": {"cat": "weg", "name": "Recht", "open": "NS", "rw": 4.0, "hx": 3.0, "hz": 3.0, "snap": 6.0, "cost": 1.0},
	"weg_bocht": {"cat": "weg", "name": "Bocht", "open": "NE", "rw": 4.0, "hx": 3.0, "hz": 3.0, "snap": 6.0, "cost": 1.0},
	"weg_t": {"cat": "weg", "name": "T-kruising", "open": "NES", "rw": 4.0, "hx": 3.0, "hz": 3.0, "snap": 6.0, "cost": 1.0},
	"weg_kruis": {"cat": "weg", "name": "Kruispunt", "open": "NESW", "rw": 4.0, "hx": 3.0, "hz": 3.0, "snap": 6.0, "cost": 1.0},
	"weg_steeg": {"cat": "weg", "name": "Steeg", "open": "NS", "rw": 2.0, "hx": 3.0, "hz": 3.0, "snap": 6.0, "cost": 1.0},
	"plein": {"cat": "weg", "name": "Plein", "plein": true, "hx": 6.0, "hz": 6.0, "snap": 3.0, "cost": 3.0},
	"woonhuis": {"cat": "gebouw", "name": "Woonhuis", "hx": 4.0, "hz": 3.5, "snap": 0.5, "cost": 10.0, "model": true, "h": 7.0},
	"winkel": {"cat": "gebouw", "name": "Winkel met flat", "hx": 4.5, "hz": 4.0, "snap": 0.5, "cost": 14.0, "model": true, "h": 9.0},
	"kerk": {"cat": "gebouw", "name": "Kerk met toren", "hx": 4.75, "hz": 9.5, "snap": 0.5, "cost": 20.0, "model": true, "h": 12.0, "glb": "res://assets/kerk.glb"},
	"benzine": {"cat": "gebouw", "name": "Benzinestation", "hx": 5.0, "hz": 5.5, "snap": 0.5, "cost": 12.0, "model": true, "h": 5.0, "glb": "res://assets/benzine.glb"},
	"magazijn": {"cat": "gebouw", "name": "Magazijn", "hx": 6.0, "hz": 4.0, "snap": 0.5, "cost": 3.0, "h": 6.0, "color": Color("6c7566"), "label": "MAGAZIJN"},
	"hotel": {"cat": "gebouw", "name": "Hotel", "hx": 5.0, "hz": 4.5, "snap": 0.5, "cost": 18.0, "model": true, "h": 12.9, "glb": "res://assets/hotel.glb"},
	"blok1": {"cat": "gebouw", "name": "Blok 1 laag", "hx": 4.0, "hz": 3.5, "snap": 0.5, "cost": 3.0, "h": 3.2, "color": Color("8a8a84"), "label": "1 LAAG"},
	"blok2": {"cat": "gebouw", "name": "Blok 2 lagen", "hx": 4.0, "hz": 3.5, "snap": 0.5, "cost": 3.0, "h": 6.4, "color": Color("8a8a84"), "label": "2 LAGEN"},
	"blok3": {"cat": "gebouw", "name": "Blok 3 lagen", "hx": 4.0, "hz": 3.5, "snap": 0.5, "cost": 3.0, "h": 9.6, "color": Color("8a8a84"), "label": "3 LAGEN"},
	"blok4": {"cat": "gebouw", "name": "Blok 4 lagen", "hx": 4.0, "hz": 3.5, "snap": 0.5, "cost": 3.0, "h": 12.8, "color": Color("8a8a84"), "label": "4 LAGEN"},
	"lantaarn": {"cat": "straat", "name": "Lantaarn", "hx": 0.3, "hz": 0.3, "snap": 0.5, "cost": 0.5, "h": 4.2, "spacing": 10.0, "road": true},
	"bankje": {"cat": "straat", "name": "Bankje", "hx": 0.9, "hz": 0.35, "snap": 0.5, "cost": 0.5, "h": 0.9, "spacing": 5.0, "road": true},
	"bushokje": {"cat": "straat", "name": "Bushokje", "hx": 1.6, "hz": 0.7, "snap": 0.5, "cost": 1.0, "h": 2.6, "spacing": 8.0, "road": true},
	"prullenbak": {"cat": "straat", "name": "Prullenbak", "hx": 0.3, "hz": 0.3, "snap": 0.5, "cost": 0.3, "h": 0.9, "spacing": 6.0, "road": true},
	"auto": {"cat": "straat", "name": "Auto", "hx": 1.0, "hz": 2.2, "snap": 0.5, "cost": 1.0, "h": 1.5, "spacing": 5.5, "road": true},
	"autowrak": {"cat": "straat", "name": "Autowrak", "hx": 1.0, "hz": 2.2, "snap": 0.5, "cost": 1.0, "h": 1.5, "spacing": 5.5, "road": true},
	"autobrand": {"cat": "straat", "name": "Brandende auto", "hx": 1.0, "hz": 2.2, "snap": 0.5, "cost": 4.0, "h": 1.5, "spacing": 7.0, "road": true},
	"zandzakken": {"cat": "straat", "name": "Zandzakken", "hx": 1.6, "hz": 0.5, "snap": 0.5, "cost": 0.5, "h": 1.0, "spacing": 3.5, "road": true},
	"puin": {"cat": "straat", "name": "Puin", "hx": 1.2, "hz": 1.2, "snap": 0.5, "cost": 0.5, "h": 0.8, "spacing": 3.0, "road": true},
	"hek": {"cat": "straat", "name": "Hek", "hx": 1.5, "hz": 0.15, "snap": 0.5, "cost": 0.3, "h": 1.2, "spacing": 3.0, "road": true},
	"boom": {"cat": "straat", "name": "Boom", "hx": 0.9, "hz": 0.9, "snap": 0.5, "cost": 1.5, "h": 6.0, "spacing": 4.0},
	"struik": {"cat": "straat", "name": "Struik", "hx": 0.7, "hz": 0.7, "snap": 0.5, "cost": 0.7, "h": 1.2, "spacing": 2.5},
}

## Volgorde in het palet van de editor.
const ORDER := {
	"weg": ["weg_recht", "weg_bocht", "weg_t", "weg_kruis", "weg_steeg", "plein"],
	"gebouw": ["woonhuis", "winkel", "kerk", "benzine", "magazijn", "hotel", "blok1", "blok2", "blok3", "blok4"],
	"straat": ["lantaarn", "bankje", "bushokje", "prullenbak", "auto", "autowrak", "autobrand", "zandzakken", "puin", "hek", "boom", "struik"],
}

## Gebouwen met een eigen sloopmodel (woonhuis.gd): zoveel mogen er tegelijk actief zijn.
const MAX_SLOOP := 8
const WEIGHT_MAX := 100.0

static var current: Stad
static var rects: Array = []      # voetafdrukken van wegen en gebouwen, om de jungle eromheen weg te laten
static var _mats := {}
static var save_path := SAVE_PATH

var items: Array = []
var _roads: MeshInstance3D


# ---------------------------------------------------------------- opbouwen

## Bouwt de stad in de wereld (Level). Heeft de speler met de editor een eigen indeling bewaard, dan is dat de stad.
static func build(parent: Node3D) -> Stad:
	var s := Stad.new()
	s.name = "Stad"
	parent.add_child(s)
	current = s
	var saved := load_saved()
	s.set_items(saved if not saved.is_empty() else from_lines(StadData.ITEMS))
	return s


static func from_lines(lines: Array) -> Array:
	var out: Array = []
	for l in lines:
		if l is Array and l.size() >= 3 and KINDS.has(String(l[0])) and available(String(l[0])):
			out.append({"k": String(l[0]), "x": float(l[1]), "z": float(l[2]), "r": int(l[3]) % 4 if l.size() > 3 else 0, "m": int(l[4]) if l.size() > 4 else 0})
	return out


static func available(kind: String) -> bool:
	var k: Dictionary = KINDS[kind]
	return not k.has("glb") or ResourceLoader.exists(String(k.glb))


func set_items(list: Array) -> void:
	for d in items:
		if d.get("node") != null and is_instance_valid(d.node):
			d.node.queue_free()
			d.node = null
	items.clear()
	for d in list:
		items.append(d)
		_make_node(d)
	rebuild_roads()
	_update_rects()


func add_item(d: Dictionary) -> void:
	items.append(d)
	_make_node(d)
	_changed(d)


func remove_item(d: Dictionary) -> void:
	items.erase(d)
	if d.get("node") != null and is_instance_valid(d.node):
		d.node.queue_free()
	d.node = null
	_changed(d)


## Na een verschuiving, draai of spiegeling: zet de node en de weg opnieuw neer.
func refresh(d: Dictionary) -> void:
	if d.get("node") != null and is_instance_valid(d.node):
		_place_node(d)
	_changed(d)


func _changed(d: Dictionary) -> void:
	if KINDS[d.k].cat == "weg":
		rebuild_roads()
	_update_rects()


func _update_rects() -> void:
	rects.clear()
	for d in items:
		if KINDS[d.k].cat != "straat":
			rects.append(rect_of(d))


## Ligt p binnen margin meter van een weg of gebouw? De jungle laat die plekken vrij.
static func covers(p: Vector3, margin: float) -> bool:
	for r: Rect2 in rects:
		if r.grow(margin).has_point(Vector2(p.x, p.z)):
			return true
	return false


# ---------------------------------------------------------------- maten en regels

static func half_of(d: Dictionary) -> Vector2:
	var k: Dictionary = KINDS[d.k]
	return Vector2(k.hz, k.hx) if int(d.r) % 2 == 1 else Vector2(k.hx, k.hz)


static func rect_of(d: Dictionary) -> Rect2:
	var h := half_of(d)
	return Rect2(Vector2(d.x, d.z) - h, h * 2.0)


static func yaw_of(d: Dictionary) -> float:
	return int(d.r) * PI / 2.0


static func weight_of(list: Array) -> float:
	var w := 0.0
	for d in list:
		w += float(KINDS[d.k].cost)
	return w


static func sloop_count(list: Array) -> int:
	var n := 0
	for d in list:
		if KINDS[d.k].get("model", false):
			n += 1
	return n


static func _overlap(a: Rect2, b: Rect2, shrink: float) -> bool:
	return a.grow(-shrink).intersects(b.grow(-shrink))


## Wat is er mis met dit item op deze plek? Leeg als het mag. others = de stad; ignore = het item zelf als je het verschuift of draait.
static func problem(d: Dictionary, others: Array, ignore := {}) -> String:
	var k: Dictionary = KINDS[d.k]
	var r := rect_of(d)
	if r.position.x < -Data.WORLD_X + 1.0 or r.end.x > Data.WORLD_X - 1.0 or r.position.y < -Data.WORLD_Z_N + 1.0:
		return "BUITEN DE KAART"
	var pts: Array = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.get_center(), Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y), Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y)]
	for p: Vector2 in pts:
		var rz := Data.river_z(p.x)
		if k.cat != "gebouw" and absf(p.x - Data.BRIDGE_X) < 3.6 and p.y < rz - 0.5:
			continue  # de weg die op de brug aansluit
		if p.y > rz - Data.RIVER_HALF - 0.3:
			return "IN DE RIVIER OF ERVOOR"
	for o in others:
		if is_same(o, d) or is_same(o, ignore):
			continue
		var ok: Dictionary = KINDS[o.k]
		var ro := rect_of(o)
		if k.cat == "gebouw" and ok.cat == "gebouw":
			if _overlap(r.grow(0.4), ro, 0.05):
				return "TE DICHT OP EEN GEBOUW"
		elif k.cat == "gebouw" and ok.cat == "weg" or k.cat == "weg" and ok.cat == "gebouw":
			if _overlap(r, ro, 0.05):
				return "GEBOUW OP DE WEG"
		elif k.cat == "weg" and ok.cat == "weg":
			if _overlap(r, ro, 0.05):
				return "HIER LIGT AL EEN WEG"
		elif k.cat == "straat" and ok.cat == "gebouw":
			if ro.has_point(Vector2(d.x, d.z)):
				return "IN EEN GEBOUW"
		elif k.cat == "gebouw" and ok.cat == "straat":
			if r.has_point(Vector2(o.x, o.z)):
				return "STAAT OP IETS"
		elif k.cat == "straat" and ok.cat == "weg":
			if not k.get("road", false) and _overlap(r, ro, 0.05):
				return "NIET OP DE WEG"
		elif k.cat == "straat" and ok.cat == "straat":
			if _overlap(r, ro, 0.15):
				return "TE DICHT OP IETS"
	return ""


# ---------------------------------------------------------------- opslaan

static func to_lines(list: Array) -> Array:
	var out: Array = []
	for d in list:
		out.append([d.k, snappedf(d.x, 0.01), snappedf(d.z, 0.01), int(d.r), int(d.m)])
	return out


## Tekst om in stad_data.gd te plakken.
static func to_text(list: Array) -> String:
	var rows: Array = []
	for d in list:
		rows.append("\t[\"%s\", %s, %s, %d, %d]," % [d.k, _num(d.x), _num(d.z), int(d.r), int(d.m)])
	return "const ITEMS := [\n" + "\n".join(rows) + "\n]\n"


static func _num(v: float) -> String:
	return str(snappedf(v, 0.01)).trim_suffix(".0")


## Bewaart de indeling van de editor. Verandert StadData later, dan vervalt dit bestand vanzelf.
func save_user() -> void:
	if DisplayServer.get_name() == "headless" and save_path == SAVE_PATH:
		return
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"basis": StadData.ITEMS.hash(), "items": to_lines(items)}))


static func load_saved() -> Array:
	if DisplayServer.get_name() == "headless" and save_path == SAVE_PATH:
		return []
	if not FileAccess.file_exists(save_path):
		return []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary or int(data.get("basis", 0)) != StadData.ITEMS.hash() or not data.get("items") is Array:
		return []
	return from_lines(data.items)


static func clear_saved() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


# ---------------------------------------------------------------- nodes

func _make_node(d: Dictionary) -> void:
	var k: Dictionary = KINDS[d.k]
	var n: Node3D = null
	if k.cat == "gebouw":
		if k.get("model", false):
			n = Woonhuis.place(self, Vector3(d.x, 0, d.z), yaw_of(d), d.k)
		else:
			n = _block(d.k)
			add_child(n)
	elif k.cat == "straat":
		n = _prop(d.k)
		add_child(n)
	elif k.get("plein", false):
		n = _fountain()
		add_child(n)
	d["node"] = n
	if n != null:
		_place_node(d)


func _place_node(d: Dictionary) -> void:
	var n: Node3D = d.node
	n.position = Vector3(d.x, 0, d.z)
	n.rotation.y = yaw_of(d)
	n.scale = Vector3(-1.0 if int(d.m) == 1 and KINDS[d.k].cat == "straat" else 1.0, 1.0, 1.0)


func _mat(key: String) -> Material:
	if not _mats.has(key):
		match key:
			"asfalt":
				_mats[key] = Kit.surface("asfalt", Color("232526"), Color("383b3b"), 0.93, 0.0, 0.08, 0.5)
			"stoep":
				_mats[key] = Kit.photo("buildings/concrete", 2.5, Color(0.66, 0.65, 0.6))
			"streep":
				_mats[key] = Kit.flat(Color("c9bd6a"), 0.8)
			"tegels":
				_mats[key] = Kit.photo("buildings/concrete", 3.0, Color(0.82, 0.79, 0.72))
	return _mats[key]


## Grijs blok voor een gebouw dat nog niet gemaakt is, met een deurtje aan de voorkant (+z).
func _block(kind: String) -> Node3D:
	var k: Dictionary = KINDS[kind]
	var root := Node3D.new()
	var mat := Kit.flat(k.color, 0.9)
	Kit.box(root, Vector3.ZERO, Vector3(k.hx * 2.0, k.h, k.hz * 2.0), mat, 0.0, Kit.LAYER_WALL)
	Kit.box(root, Vector3(0, 0, k.hz - 0.05), Vector3(1.4, 2.3, 0.2), Kit.flat(Color("2a2a26")))
	Kit.box(root, Vector3(0, k.h, 0), Vector3(k.hx * 2.0 + 0.4, 0.3, k.hz * 2.0 + 0.4), Kit.flat(Color("55554f")))
	var lb := Label3D.new()
	lb.text = String(k.label)
	lb.pixel_size = 0.016
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.modulate = Color(1, 1, 1, 0.9)
	lb.outline_size = 8
	lb.position = Vector3(0, k.h + 1.2, 0)
	root.add_child(lb)
	return root


func _fountain() -> Node3D:
	var root := Node3D.new()
	var stone := Kit.photo("buildings/concrete", 2.0, Color(0.7, 0.68, 0.62))
	Kit.cylinder(root, Vector3.ZERO, 1.9, 0.5, stone, 16)
	Kit.cylinder(root, Vector3(0, 0.5, 0), 1.3, 0.4, stone, 16)
	Kit.cylinder(root, Vector3.ZERO, 0.3, 2.8, stone, 8, 0.2)
	Kit.cylinder(root, Vector3(0, 2.8, 0), 0.55, 0.25, stone, 10)
	Kit.collider(root, Vector3(0, 0.6, 0), Vector3(3.6, 1.2, 3.6), Kit.LAYER_WALL)
	return root


func _prop(kind: String) -> Node3D:
	var root := Node3D.new()
	var dark := Kit.flat(Color("2a2d2a"), 0.6, 0.5)
	match kind:
		"lantaarn":
			Kit.cylinder(root, Vector3.ZERO, 0.09, 4.0, dark, 8, 0.06)
			Kit.box(root, Vector3(0, 3.95, 0.35), Vector3(0.1, 0.1, 0.8), dark)
			Kit.box(root, Vector3(0, 3.78, 0.7), Vector3(0.3, 0.16, 0.45), Kit.flat(Color("e8d9a0"), 0.5))
		"bankje":
			var wood := Kit.wood()
			Kit.box(root, Vector3(0, 0.42, 0), Vector3(1.8, 0.07, 0.45), wood)
			Kit.box(root, Vector3(0, 0.7, -0.2), Vector3(1.8, 0.4, 0.06), wood)
			Kit.box(root, Vector3(-0.8, 0, 0), Vector3(0.08, 0.42, 0.4), dark)
			Kit.box(root, Vector3(0.8, 0, 0), Vector3(0.08, 0.42, 0.4), dark)
			Kit.collider(root, Vector3(0, 0.45, 0), Vector3(1.8, 0.9, 0.5), Kit.LAYER_WALL)
		"bushokje":
			Kit.box(root, Vector3(0, 0, -0.62), Vector3(3.2, 2.2, 0.08), Kit.flat(Color("6e8a8c"), 0.2, 0.2))
			Kit.box(root, Vector3(-1.56, 0, 0), Vector3(0.08, 2.2, 1.2), Kit.flat(Color("6e8a8c"), 0.2, 0.2))
			Kit.box(root, Vector3(0, 2.2, 0), Vector3(3.4, 0.12, 1.5), dark)
			Kit.box(root, Vector3(0.4, 0, -0.3), Vector3(1.8, 0.45, 0.4), Kit.wood())
			Kit.collider(root, Vector3(0, 1.1, -0.6), Vector3(3.2, 2.2, 0.2), Kit.LAYER_WALL)
		"prullenbak":
			Kit.cylinder(root, Vector3.ZERO, 0.26, 0.9, Kit.flat(Color("3c4a3a"), 0.7, 0.3), 10)
		"auto", "autowrak", "autobrand":
			_car(root, kind)
		"zandzakken":
			Kit.sandbags(root, Vector3(-1.5, 0, 0), Vector3(1.5, 0, 0), 3, 7)
			Kit.collider(root, Vector3(0, 0.5, 0), Vector3(3.2, 1.0, 0.8), Kit.LAYER_WALL)
		"puin":
			var rock := Kit.concrete_dark()
			var sizes: Array = [Vector3(1.6, 0.6, 1.2), Vector3(0.9, 0.9, 0.8), Vector3(1.2, 0.4, 1.4), Vector3(0.5, 0.5, 0.5)]
			var offs: Array = [Vector3(0, 0, 0), Vector3(0.4, 0.3, -0.3), Vector3(-0.6, 0, 0.5), Vector3(0.7, 0, 0.6)]
			for i in sizes.size():
				Kit.box(root, offs[i], sizes[i], rock, 0.5 + i * 0.9)
			Kit.collider(root, Vector3(0, 0.4, 0), Vector3(2.0, 0.8, 1.8), Kit.LAYER_WALL)
		"hek":
			var wood := Kit.wood()
			for x in [-1.4, 0.0, 1.4]:
				Kit.box(root, Vector3(x, 0, 0), Vector3(0.1, 1.2, 0.1), wood)
			Kit.box(root, Vector3(0, 0.45, 0), Vector3(3.0, 0.08, 0.05), wood)
			Kit.box(root, Vector3(0, 0.9, 0), Vector3(3.0, 0.08, 0.05), wood)
		"boom":
			Kit.cylinder(root, Vector3.ZERO, 0.28, 4.2, Kit.photo("nature/tree_bark", 1.5, Color(0.7, 0.62, 0.52)), 8, 0.18)
			var leaf := Kit.flat(Color("2f5a28"), 0.95)
			for i in 3:
				var mi := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 1.7 - i * 0.35
				sm.height = (1.7 - i * 0.35) * 1.6
				sm.radial_segments = 10
				sm.rings = 5
				mi.mesh = sm
				mi.material_override = leaf
				mi.position = Vector3(0, 4.3 + i * 0.9, 0)
				root.add_child(mi)
			Kit.collider(root, Vector3(0, 1.0, 0), Vector3(0.6, 2.0, 0.6), Kit.LAYER_WALL)
		"struik":
			var mi := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.8
			sm.height = 1.2
			sm.radial_segments = 8
			sm.rings = 4
			mi.mesh = sm
			mi.material_override = Kit.flat(Color("3a6a2c"), 0.95)
			mi.position = Vector3(0, 0.55, 0)
			root.add_child(mi)
	return root


func _car(root: Node3D, kind: String) -> void:
	var seed_ := absi(int(root.get_instance_id()) % 4)
	var colors: Array = [Color("8a2a24"), Color("3c5a7c"), Color("c9c2a8"), Color("4a5a3a")]
	var body_col: Color = colors[seed_]
	if kind != "auto":
		body_col = Color("25221f")
	var body := Kit.flat(body_col, 0.5, 0.3)
	var glass := Kit.flat(Color("151a1c") if kind == "auto" else Color("0c0c0b"), 0.2)
	Kit.box(root, Vector3(0, 0.35, 0), Vector3(1.9, 0.7, 4.3), body, 0.0, Kit.LAYER_WALL)
	Kit.box(root, Vector3(0, 1.0, -0.2), Vector3(1.7, 0.6, 2.2), glass)
	Kit.box(root, Vector3(0, 1.58, -0.2), Vector3(1.6, 0.06, 2.0), body)
	for sx in [-1, 1]:
		for z in [-1.4, 1.4]:
			Kit.box(root, Vector3(sx * 0.95, 0, z), Vector3(0.28, 0.6, 0.62), Kit.flat(Color("101010"), 0.9))
	if kind == "autobrand":
		Fx.burning(root, Vector3.ZERO, true).position = Vector3(0, 0.8, 0)


# ---------------------------------------------------------------- wegen

const DIRS := {"N": Vector2(0, -1), "E": Vector2(1, 0), "S": Vector2(0, 1), "W": Vector2(-1, 0)}


## Bouwt alle wegen opnieuw als één mesh met vier vlakken: asfalt, stoep, strepen en pleintegels.
func rebuild_roads() -> void:
	if _roads == null:
		_roads = MeshInstance3D.new()
		_roads.name = "Wegen"
		_roads.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_roads)
	var keys: Array = ["asfalt", "stoep", "streep", "tegels"]
	var sts: Array = []
	var used: Array = [false, false, false, false]
	for i in 4:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		sts.append(st)
	for d in items:
		var k: Dictionary = KINDS[d.k]
		if k.cat != "weg":
			continue
		if k.get("plein", false):
			used[3] = true
			_top(sts[3], d, -k.hx, -k.hz, k.hx, k.hz, 0.05)
			continue
		_piece(d, k, sts, used)
	var mesh := ArrayMesh.new()
	for i in 4:
		if used[i]:
			sts[i].commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, _mat(keys[i]))
	_roads.mesh = mesh if mesh.get_surface_count() > 0 else null


func _piece(d: Dictionary, k: Dictionary, sts: Array, used: Array) -> void:
	var rw: float = k.rw
	var a := (CELL - rw) / 2.0
	var xs: Array = [-CELL / 2.0, -CELL / 2.0 + a, CELL / 2.0 - a, CELL / 2.0]
	var open: String = k.open
	for j in 3:
		for i in 3:
			var is_open := false
			if i == 1 and j == 1:
				is_open = true
			elif i == 1 and j == 0:
				is_open = open.contains("N")
			elif i == 1 and j == 2:
				is_open = open.contains("S")
			elif i == 0 and j == 1:
				is_open = open.contains("W")
			elif i == 2 and j == 1:
				is_open = open.contains("E")
			if is_open:
				used[0] = true
				_top(sts[0], d, xs[i], xs[j], xs[i + 1], xs[j + 1], ASPHALT_Y)
			else:
				used[1] = true
				_curb(sts[1], d, xs[i], xs[j], xs[i + 1], xs[j + 1])
	# stippellijn midden op een recht stuk
	if open == "NS" and rw > 3.0:
		used[2] = true
		_top(sts[2], d, -0.07, -1.2, 0.07, 1.2, ASPHALT_Y + 0.012)


func _w(d: Dictionary, lx: float, y: float, lz: float) -> Vector3:
	var v := Vector3(lx * (-1.0 if int(d.m) == 1 else 1.0), y, lz)
	return Basis(Vector3.UP, yaw_of(d)) * v + Vector3(d.x, 0, d.z)


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	if (c - a).cross(b - a).dot(n) < 0.0:
		var t := b
		b = c
		c = t
	for v in [a, b, c]:
		st.set_normal(n)
		st.add_vertex(v)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, e: Vector3, n: Vector3) -> void:
	_tri(st, a, b, c, n)
	_tri(st, a, c, e, n)


func _top(st: SurfaceTool, d: Dictionary, x0: float, z0: float, x1: float, z1: float, y: float) -> void:
	_quad(st, _w(d, x0, y, z0), _w(d, x1, y, z0), _w(d, x1, y, z1), _w(d, x0, y, z1), Vector3.UP)


## Stoeptegel met een opstaande rand rondom.
func _curb(st: SurfaceTool, d: Dictionary, x0: float, z0: float, x1: float, z1: float) -> void:
	_top(st, d, x0, z0, x1, z1, PAVE_Y)
	var y := PAVE_Y
	var wall := func(ax: float, az: float, bx: float, bz: float) -> void:
		var out := Basis(Vector3.UP, yaw_of(d)) * Vector3((bz - az) * (-1.0 if int(d.m) == 1 else 1.0), 0, -(bx - ax))
		_quad(st, _w(d, ax, 0, az), _w(d, bx, 0, bz), _w(d, bx, y, bz), _w(d, ax, y, az), out.normalized())
	wall.call(x0, z0, x1, z0)
	wall.call(x1, z0, x1, z1)
	wall.call(x1, z1, x0, z1)
	wall.call(x0, z1, x0, z0)
