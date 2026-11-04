class_name VijandBasis
## De vijandelijke basis (Generals-plan stap D2, onderdeel 5a): ver in het noorden achter de stad, een spiegel van jouw basis in
## groen-gele vijandkleuren. Dit is de speelbare versie met eenvoudige BLOKKEN; de mooie Meshy-modellen komen in stap 5b.
## Ligging: middelpunt Data.VIJAND_POS, muur van 64 x 56 m, poort in de zuidmuur (naar jouw basis toe), vier hoektorens,
## en binnen: hoofdkwartier, kazerne, garage, depot en generator. Alles is massief (LAYER_WALL): je loopt er niet doorheen.
## Stap 5a-2: het hoofdkwartier is Dennis' eigen model (VijandHk) en slopen = winnen; aanvalsgroepen komen uit de poort (main.gd).
## Stap 5a-3a: jouw leger kan hierheen marcheren en het HK beschieten (Ally, AanvalRoutes.march_path); rode vlak op de radar (HudExtra).
## Nog niet: garnizoen en schietende torens (5a-3b).

const P := Data.VIJAND_POS
const HALF := Data.VIJAND_HALF
const GATE := Data.VIJAND_GATE
const WALL_H := Data.WALL_H
const WALL_T := Data.WALL_T

# Vijandkleuren, subtiel groen-geel. Dennis voegt de definitieve kleuren (van zijn model "assault") zelf toe via Codex; pas dan alleen deze rij aan.
const KLEUR_MUUR := Color("676a45")
const KLEUR_BLOK := Color("5b6038")
const KLEUR_DAK := Color("747a3c")
const KLEUR_DONKER := Color("353924")
const KLEUR_ACCENT := Color("b7aa38")

static var _mats: Dictionary = {}


## Alle onderdelen als kinderen van één knoop "VijandBasis" (groep "vijand_basis") onder root.
static func build(root: Node3D) -> Node3D:
	_mats.clear()
	var holder := Node3D.new()
	holder.name = "VijandBasis"
	holder.position = P
	holder.add_to_group("vijand_basis")
	root.add_child(holder)
	_muur(holder)
	_poort(holder)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_toren(holder, Vector3(sx * (HALF.x - 1.8), 0, sz * (HALF.y - 1.8)))
	_hoofdkwartier(holder)
	_gebouw(holder, "Kazerne", Vector3(-19.0, 0, -4.0), Vector3(10.0, 4.4, 6.5))
	_gebouw(holder, "Garage", Vector3(19.0, 0, -4.0), Vector3(9.0, 4.2, 8.0))
	_gebouw(holder, "Depot", Vector3(-19.0, 0, 12.0), Vector3(8.0, 3.6, 8.0))
	_generator(holder, Vector3(19.0, 0, 12.0))
	return holder


## Plek van het hoofdkwartier in de wereld (het doel om te slopen in stap 5a-2).
static func hk_pos() -> Vector3:
	return P + Vector3(0.0, 0.0, -13.0)


## Een punt net buiten de poort, aan de kant van jouw basis: hier begint een aanvalsgroep haar tocht.
static func gate_outside() -> Vector3:
	return P + Vector3(0.0, 0.0, HALF.y + 3.0)


## Een punt vlak binnen de poort: hier lopen soldaten van jouw leger de basis in (stap 5a-3a), vóór ze naar hun plek voor het HK gaan.
static func gate_inside() -> Vector3:
	return P + Vector3(0.0, 0.0, HALF.y - 4.0)


## Plek van soldaat i tijdens het beschieten van het HK (stap 5a-3a): een waaier op het binnenplein, een meter of tien voor de deur van
## het HK. Dat is binnen het bereik van Ally.RANGE en vrij van de gebouwen langs de zijmuren. Meer dan 7 soldaten staan in rijen erachter.
static func attack_spot(i: int) -> Vector3:
	var col := posmod(i, 7)
	var row := posmod(i / 7, 4)
	return P + Vector3((col - 3) * 1.8, 0.0, row * 1.6)


## Afstand in meters (plat) van dit punt tot het dichtstbijzijnde stuk van het HK-blok; 0 als het erin staat.
static func hk_distance(p: Vector3) -> float:
	var c := hk_pos() + VijandHk.KERN_MIDDEN
	return Vector2(maxf(absf(p.x - c.x) - VijandHk.KERN.x * 0.5, 0.0), maxf(absf(p.z - c.z) - VijandHk.KERN.z * 0.5, 0.0)).length()


## Beginplek van een soldaat van een aanvalsgroep (stap 5a-2): op het binnenplein vlak achter de poort, in de vrije baan naar de opening.
static func spawn_point() -> Vector3:
	return P + Vector3(randf_range(-1.8, 1.8), 0.0, HALF.y - randf_range(5.0, 12.0))


## Ligt dit punt (x, z) binnen de buitenmuur, met een marge in meters?
static func contains(p: Vector3, margin := 0.0) -> bool:
	return absf(p.x - P.x) <= HALF.x + margin and absf(p.z - P.z) <= HALF.y + margin


static func _mat(color: Color, rough := 0.92) -> StandardMaterial3D:
	var key := "%s_%s" % [color.to_html(false), rough]
	if not _mats.has(key):
		_mats[key] = Kit.flat(color, rough)
	return _mats[key]


## Lage betonnen borstwering rond de basis, open bij de poort in de zuidmuur.
static func _muur(h: Node3D) -> void:
	var seg_x := HALF.x - GATE
	var segs := [
		[Vector3(0, 0, -HALF.y), Vector2(HALF.x * 2.0, WALL_T)],
		[Vector3(-HALF.x, 0, 0), Vector2(WALL_T, HALF.y * 2.0)],
		[Vector3(HALF.x, 0, 0), Vector2(WALL_T, HALF.y * 2.0)],
		[Vector3(-(GATE + seg_x / 2.0), 0, HALF.y), Vector2(seg_x, WALL_T)],
		[Vector3(GATE + seg_x / 2.0, 0, HALF.y), Vector2(seg_x, WALL_T)],
	]
	var muur := Node3D.new()
	muur.name = "Muur"
	h.add_child(muur)
	for s in segs:
		var p: Vector3 = s[0]
		var sz: Vector2 = s[1]
		Kit.box(muur, p, Vector3(sz.x, WALL_H, sz.y), _mat(KLEUR_MUUR), 0.0, Kit.LAYER_WALL)
		Kit.box(muur, p + Vector3.UP * WALL_H, Vector3(sz.x + 0.1, 0.14, sz.y + 0.14), _mat(KLEUR_DONKER))


## Twee poortposten met een balk met geel-zwarte rand; de opening blijft vrij.
static func _poort(h: Node3D) -> void:
	var poort := Node3D.new()
	poort.name = "Poort"
	h.add_child(poort)
	for sx in [-1.0, 1.0]:
		var p := Vector3(sx * (GATE + 0.3), 0, HALF.y)
		Kit.box(poort, p, Vector3(0.7, 2.1, 0.7), _mat(KLEUR_DONKER), 0.0, Kit.LAYER_WALL)
		Kit.box(poort, p + Vector3.UP * 2.1, Vector3(0.9, 0.16, 0.9), _mat(KLEUR_MUUR))
	Kit.box(poort, Vector3(0, 2.0, HALF.y), Vector3(GATE * 2.0 + 1.0, 0.18, 0.4), _mat(KLEUR_BLOK))
	for i in 10:
		var x := -GATE + 0.25 + i * (GATE * 2.0 / 9.0)
		Kit.box(poort, Vector3(x, 1.84, HALF.y), Vector3(0.22, 0.16, 0.44), _mat(KLEUR_ACCENT if i % 2 == 0 else Color("1a1a18")))


## Wachttoren van blokken: vier poten als één massief blok, een platform, een dak en een geweernest (de MG komt in stap 5a-3).
static func _toren(h: Node3D, pos: Vector3) -> void:
	var t := Node3D.new()
	t.name = "Toren"
	t.position = pos
	t.add_to_group("vijand_toren")
	h.add_child(t)
	Kit.collider(t, Vector3(0, 2.5, 0), Vector3(1.9, 5.0, 1.9), Kit.LAYER_WALL)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Kit.box(t, Vector3(sx * 0.8, 0, sz * 0.8), Vector3(0.22, 4.4, 0.22), _mat(KLEUR_DONKER))
	Kit.box(t, Vector3(0, 4.4, 0), Vector3(2.3, 0.2, 2.3), _mat(KLEUR_BLOK))
	Kit.box(t, Vector3(0, 4.6, 0.95), Vector3(2.3, 0.8, 0.12), _mat(KLEUR_MUUR))   # borstwering naar de basis
	Kit.box(t, Vector3(0, 5.6, 0), Vector3(2.7, 0.14, 2.7), _mat(KLEUR_DAK))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Kit.box(t, Vector3(sx * 1.2, 4.6, sz * 1.2), Vector3(0.1, 1.0, 0.1), _mat(KLEUR_DONKER))


## Hoofdkwartier: Dennis' eigen model "Enemy hk" (VijandHk, vanaf stap 5a-2) op dezelfde plek en met dezelfde breedte (9 m) als het blok
## waarmee 5a-1 begon. Het heeft levenspunten en laat je winnen als je het sloopt.
static func _hoofdkwartier(h: Node3D) -> void:
	var hk := VijandHk.new()
	hk.name = "Hoofdkwartier"
	hk.position = Vector3(0.0, 0.0, -13.0)
	hk.add_to_group("vijand_hk")
	h.add_child(hk)


## Eenvoudig gebouw als massief blok met een dakrand en een gele streep op het dak.
static func _gebouw(h: Node3D, naam: String, pos: Vector3, size: Vector3) -> void:
	var b := Node3D.new()
	b.name = naam
	b.position = pos
	b.add_to_group("vijand_gebouw")
	h.add_child(b)
	Kit.box(b, Vector3.ZERO, size, _mat(KLEUR_BLOK), 0.0, Kit.LAYER_WALL)
	Kit.box(b, Vector3(0, size.y, 0), Vector3(size.x + 0.3, 0.25, size.z + 0.3), _mat(KLEUR_DAK))
	Kit.box(b, Vector3(0, size.y + 0.25, 0), Vector3(size.x * 0.6, 0.05, size.z * 0.25), _mat(KLEUR_ACCENT))
	# een donkere deur aan de kant van de middenstraat
	var side := 1.0 if pos.x < 0.0 else -1.0
	Kit.box(b, Vector3(side * (size.x * 0.5 + 0.03), 0, 0), Vector3(0.1, 2.2, 2.0), _mat(KLEUR_DONKER))


## Generator: een klein blok met twee brandstoffusten.
static func _generator(h: Node3D, pos: Vector3) -> void:
	var g := Node3D.new()
	g.name = "Generator"
	g.position = pos
	g.add_to_group("vijand_gebouw")
	h.add_child(g)
	Kit.box(g, Vector3.ZERO, Vector3(3.4, 2.2, 3.0), _mat(KLEUR_BLOK), 0.0, Kit.LAYER_WALL)
	Kit.box(g, Vector3(0, 2.2, 0), Vector3(3.6, 0.2, 3.2), _mat(KLEUR_DAK))
	Kit.cylinder(g, Vector3(2.7, 0, 0.6), 0.3, 0.9, _mat(KLEUR_ACCENT, 0.7), 10)
	Kit.cylinder(g, Vector3(2.7, 0, -0.6), 0.3, 0.9, _mat(KLEUR_DONKER), 10)
