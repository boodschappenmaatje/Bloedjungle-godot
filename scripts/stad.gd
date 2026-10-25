class_name Stad
extends Node3D
## De stad achter de brug: wegdelen, gebouwen en straatmeubilair, opgebouwd uit een lijst (StadData.ITEMS).
## De stadseditor (stad_editor.gd) voegt dingen toe, schuift ze en haalt ze weg; Stad houdt de 3D-wereld bij.
## Een item is een woordenboek: k = soort (zie KINDS), x en z = midden in meters, r = kwartslagen (0-3), m = gespiegeld.
## Wegdelen komen uit de straatset (assets/straat.glb, bron/straat/maak_straat.py) en zitten samen in één mesh met één vlak
## per materiaal (snel op de iPhone); gebouwen en straatmeubilair zijn losse nodes.

const CELL := 6.0   # een wegdeel is 6 x 6 m
const SAVE_PATH := "user://stad_editor.json"
const STRAAT_GLB := "res://assets/straat.glb"
const MEUBILAIR_GLB := "res://assets/straatmeubilair.glb"   # bron/straatmeubilair/maak_straatmeubilair.py
## Materialen van de straatset met wereld-UV (meters per herhaling): de bovenkant loopt zo naadloos door over gedraaide wegdelen.
const WORLD_UV := {"Asfalt": 12.0, "Stoep": 1.2, "Keien": 1.0, "Steen": 2.0}

## cat: weg / gebouw / straat. hx en hz = halve maat van de voetafdruk, snap = rasterstap, cost = zwaarte voor de iPhone.
## open = zijkanten van een wegdeel (N, E, S, W), rw = breedte van het asfalt. h = hoogte van een grijs blok.
## spacing = afstand tussen kopieën met de kwast, road = mag op de weg staan. part = object in de straatset.
## stoep = straatmeubilair, bomen en struiken mogen erop.
const KINDS := {
	"weg_recht": {"cat": "weg", "name": "Recht", "open": "NS", "rw": 4.0, "hx": 3.0, "hz": 3.0, "snap": 6.0, "cost": 1.0, "part": "Recht"},
	"weg_bocht": {"cat": "weg", "name": "Bocht", "open": "NE", "rw": 4.0, "hx": 3.0, "hz": 3.0, "snap": 6.0, "cost": 1.0, "part": "Bocht"},
	"weg_t": {"cat": "weg", "name": "T-kruising", "open": "NES", "rw": 4.0, "hx": 3.0, "hz": 3.0, "snap": 6.0, "cost": 1.0, "part": "TStuk"},
	"weg_kruis": {"cat": "weg", "name": "Kruispunt", "open": "NESW", "rw": 4.0, "hx": 3.0, "hz": 3.0, "snap": 6.0, "cost": 1.0, "part": "Kruis"},
	"weg_steeg": {"cat": "weg", "name": "Steeg", "open": "NS", "rw": 2.0, "hx": 3.0, "hz": 3.0, "snap": 6.0, "cost": 1.0, "part": "Steeg"},
	"weg_zebra": {"cat": "weg", "name": "Zebrapad", "open": "NS", "rw": 4.0, "hx": 3.0, "hz": 3.0, "snap": 6.0, "cost": 1.0, "part": "Zebra"},
	"stoep": {"cat": "weg", "name": "Stoep", "open": "", "rw": 0.0, "hx": 3.0, "hz": 3.0, "snap": 6.0, "cost": 0.5, "part": "Stoep", "stoep": true},
	"plein": {"cat": "weg", "name": "Plein", "plein": true, "hx": 6.0, "hz": 6.0, "snap": 3.0, "cost": 3.0, "part": "Plein"},
	"woonhuis": {"cat": "gebouw", "name": "Woonhuis", "hx": 4.0, "hz": 3.5, "snap": 0.5, "cost": 10.0, "model": true, "h": 7.0},
	"winkel": {"cat": "gebouw", "name": "Winkel met flat", "hx": 4.5, "hz": 4.0, "snap": 0.5, "cost": 14.0, "model": true, "h": 9.0},
	"kerk": {"cat": "gebouw", "name": "Kerk met toren", "hx": 4.75, "hz": 9.5, "snap": 0.5, "cost": 20.0, "model": true, "h": 12.0, "glb": "res://assets/kerk.glb"},
	"benzine": {"cat": "gebouw", "name": "Benzinestation", "hx": 5.0, "hz": 5.5, "snap": 0.5, "cost": 12.0, "model": true, "h": 5.0, "glb": "res://assets/benzine.glb"},
	"magazijn": {"cat": "gebouw", "name": "Magazijn", "hx": 6.0, "hz": 4.0, "snap": 0.5, "cost": 8.0, "model": true, "h": 5.8, "glb": "res://assets/magazijn.glb"},
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
	"bus": {"cat": "straat", "name": "Bus", "hx": 1.3, "hz": 5.3, "snap": 0.5, "cost": 3.0, "h": 3.1, "spacing": 12.0, "road": true},
	"buswrak": {"cat": "straat", "name": "Buswrak", "hx": 1.3, "hz": 5.3, "snap": 0.5, "cost": 3.0, "h": 2.8, "spacing": 12.0, "road": true},
	"busbrand": {"cat": "straat", "name": "Brandende bus", "hx": 1.3, "hz": 5.3, "snap": 0.5, "cost": 6.0, "h": 3.1, "spacing": 14.0, "road": true},
	"brandkraan": {"cat": "straat", "name": "Brandkraan", "hx": 0.25, "hz": 0.25, "snap": 0.5, "cost": 0.3, "h": 0.8, "spacing": 12.0, "road": true},
	"container": {"cat": "straat", "name": "Vuilcontainer", "hx": 0.95, "hz": 0.5, "snap": 0.5, "cost": 0.7, "h": 1.2, "spacing": 5.0, "road": true},
	"bord": {"cat": "straat", "name": "Verkeersbord", "hx": 0.3, "hz": 0.3, "snap": 0.5, "cost": 0.3, "h": 2.5, "spacing": 8.0, "road": true},
	"stoplicht": {"cat": "straat", "name": "Stoplicht", "hx": 0.3, "hz": 0.3, "snap": 0.5, "cost": 0.5, "h": 3.7, "spacing": 8.0, "road": true},
	"zandzakken": {"cat": "straat", "name": "Zandzakken", "hx": 1.6, "hz": 0.5, "snap": 0.5, "cost": 0.5, "h": 1.0, "spacing": 3.5, "road": true},
	"puin": {"cat": "straat", "name": "Puin", "hx": 1.2, "hz": 1.2, "snap": 0.5, "cost": 0.5, "h": 0.8, "spacing": 3.0, "road": true},
	"hek": {"cat": "straat", "name": "Hek", "hx": 1.5, "hz": 0.15, "snap": 0.5, "cost": 0.3, "h": 1.2, "spacing": 3.0, "road": true},
	"boom": {"cat": "straat", "name": "Boom", "hx": 0.9, "hz": 0.9, "snap": 0.5, "cost": 1.5, "h": 6.0, "spacing": 4.0},
	"struik": {"cat": "straat", "name": "Struik", "hx": 0.7, "hz": 0.7, "snap": 0.5, "cost": 0.7, "h": 1.2, "spacing": 2.5},
}

## Volgorde in het palet van de editor.
const ORDER := {
	"weg": ["weg_recht", "weg_bocht", "weg_t", "weg_kruis", "weg_steeg", "weg_zebra", "stoep", "plein"],
	"gebouw": ["woonhuis", "winkel", "kerk", "benzine", "magazijn", "hotel", "blok1", "blok2", "blok3", "blok4"],
	"straat": ["lantaarn", "bankje", "bushokje", "prullenbak", "brandkraan", "container", "bord", "stoplicht", "auto", "autowrak", "autobrand", "bus", "buswrak", "busbrand", "zandzakken", "puin", "hek", "boom", "struik"],
}

## Gebouwen met een eigen sloopmodel (woonhuis.gd): zoveel mogen er tegelijk actief zijn.
const MAX_SLOOP := 8
const WEIGHT_MAX := 100.0

static var current: Stad
static var rects: Array = []      # voetafdrukken van wegen en gebouwen, om de jungle eromheen weg te laten
static var _mats := {}
static var save_path := SAVE_PATH
static var _parts := {}   # straatset: objectnaam -> {mesh, surfaces: [{mat, a (arrays)}]}

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
			if not k.get("road", false) and not ok.get("stoep", false) and _overlap(r, ro, 0.05):
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
	var mi := MeshInstance3D.new()
	mi.mesh = _part("Fontein").get("mesh")
	root.add_child(mi)
	Kit.collider(root, Vector3(0, 0.6, 0), Vector3(3.6, 1.2, 3.6), Kit.LAYER_WALL)
	return root


## Straatmeubilair: het model uit assets/straatmeubilair.glb, met een botsvorm waar je er niet doorheen mag lopen.
const PROP_PARTS := {"bankje": "Bankje", "bushokje": "Bushokje", "prullenbak": "Prullenbak",
		"container": "Container", "bord": "Bord", "stoplicht": "Stoplicht", "zandzakken": "Zandzakken", "puin": "Puin", "hek": "Hek",
		"boom": "Boom", "struik": "Struik"}
## Botsvormen: [midden, maat] in meters (voorkant = +z).
const PROP_BOXES := {
	"bankje": [Vector3(0, 0.45, 0), Vector3(1.8, 0.9, 0.5)],
	"bushokje": [Vector3(0, 1.1, 0.5), Vector3(3.2, 2.2, 0.3)],
	"zandzakken": [Vector3(0, 0.5, 0), Vector3(3.2, 1.0, 0.8)],
	"puin": [Vector3(0, 0.4, 0), Vector3(2.0, 0.8, 1.8)],
	"boom": [Vector3(0, 1.0, 0), Vector3(0.6, 2.0, 0.6)],
	"container": [Vector3(0, 0.6, 0), Vector3(1.9, 1.2, 0.95)],
	"prullenbak": [Vector3(0, 0.45, 0), Vector3(0.5, 0.9, 0.5)],
}


func _prop(kind: String) -> Node3D:
	var root := Node3D.new()
	if PROP_PARTS.has(kind) and not _part(PROP_PARTS[kind]).is_empty():
		var mi := MeshInstance3D.new()
		mi.mesh = _part(PROP_PARTS[kind]).mesh
		root.add_child(mi)
		if PROP_BOXES.has(kind):
			Kit.collider(root, PROP_BOXES[kind][0], PROP_BOXES[kind][1], Kit.LAYER_WALL)
	elif kind == "brandkraan":
		return Brandkraan.new()
	elif kind == "lantaarn":
		return Lantaarn.new()
	elif kind in ["bus", "buswrak", "busbrand"]:
		return Bus.make(kind, int(roundf(float(kind.hash() % 97) + float(get_child_count()) * 3.0)))
	elif kind.begins_with("auto"):
		return Auto.make(kind, int(roundf(float(kind.hash() % 97) + float(get_child_count()) * 3.0)))
	return root


# ---------------------------------------------------------------- wegen

const DIRS := {"N": Vector2(0, -1), "E": Vector2(1, 0), "S": Vector2(0, 1), "W": Vector2(-1, 0)}


## Een object uit de straatset: de mesh en per vlak het materiaal en de arrays (één keer ingelezen).
static func _part(name: String) -> Dictionary:
	if _parts.is_empty():
		for path in [STRAAT_GLB, MEUBILAIR_GLB]:
			if not ResourceLoader.exists(path):
				continue
			var root: Node = (load(path) as PackedScene).instantiate()
			for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
				var list: Array = []
				for i in mi.mesh.get_surface_count():
					list.append({"mat": mi.mesh.surface_get_material(i), "a": mi.mesh.surface_get_arrays(i)})
				_parts[String(mi.name)] = {"mesh": mi.mesh, "surfaces": list}
			root.free()
	return _parts.get(name, {})


## Bouwt alle wegen opnieuw als één mesh: de wegdelen uit de straatset, gedraaid en verschoven, samengevoegd per materiaal.
func rebuild_roads() -> void:
	if _roads == null:
		_roads = MeshInstance3D.new()
		_roads.name = "Wegen"
		_roads.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_roads)
	var buckets := {}
	for d in items:
		var k: Dictionary = KINDS[d.k]
		if k.cat == "weg":
			_append_part(buckets, d, String(k.part))
	var mesh := ArrayMesh.new()
	for key in buckets:
		var bk: Dictionary = buckets[key]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = bk.v
		arr[Mesh.ARRAY_NORMAL] = bk.n
		arr[Mesh.ARRAY_TEX_UV] = bk.uv
		arr[Mesh.ARRAY_INDEX] = bk.i
		if bk.has_t:
			arr[Mesh.ARRAY_TANGENT] = bk.t
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(mesh.get_surface_count() - 1, bk.mat)
	_roads.mesh = mesh if mesh.get_surface_count() > 0 else null


## Voegt één wegdeel toe aan de emmers (per materiaal). Gespiegeld = x omgekeerd, dus de driehoeken andersom.
func _append_part(buckets: Dictionary, d: Dictionary, part: String) -> void:
	var mir := int(d.m) == 1
	var b := Basis(Vector3.UP, yaw_of(d)) * Basis.from_scale(Vector3(-1.0 if mir else 1.0, 1.0, 1.0))
	var o := Vector3(d.x, 0, d.z)
	for s: Dictionary in _part(part).get("surfaces", []):
		var mat: Material = s.mat
		var key := mat.resource_name if mat != null else ""
		if not buckets.has(key):
			buckets[key] = {"mat": mat, "v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(),
					"t": PackedFloat32Array(), "i": PackedInt32Array(), "has_t": true}
		var bk: Dictionary = buckets[key]
		var a: Array = s.a
		var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
		var tans: PackedFloat32Array = a[Mesh.ARRAY_TANGENT] if a[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(verts.size()))
		var ws: float = WORLD_UV.get(key, 0.0)
		bk.has_t = bk.has_t and tans.size() == verts.size() * 4
		var base: int = bk.v.size()
		for j in verts.size():
			var p: Vector3 = b * verts[j] + o
			var nn: Vector3 = b * norms[j]
			bk.v.append(p)
			bk.n.append(nn)
			var world := ws > 0.0 and nn.y > 0.7
			bk.uv.append(Vector2(p.x / ws, p.z / ws) if world else uvs[j])
			if tans.size() == verts.size() * 4:
				var t := Vector3(1, 0, 0) if world else b * Vector3(tans[j * 4], tans[j * 4 + 1], tans[j * 4 + 2])
				bk.t.append_array([t.x, t.y, t.z, tans[j * 4 + 3] * (-1.0 if mir and not world else 1.0)])
		for j in range(0, idx.size(), 3):
			bk.i.append(base + idx[j])
			bk.i.append(base + idx[j + 2 if mir else j + 1])
			bk.i.append(base + idx[j + 1 if mir else j + 2])
