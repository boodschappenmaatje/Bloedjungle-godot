class_name Barrel
extends StaticBody3D
## Explosief vat. Eén of twee kogels laten hem ontploffen: schade in een straal aan vijanden, jou, gebouwen,
## poorten en de bunker, en vaten in de buurt gaan een fractie later mee (kettingreactie).
## Staat in groepjes buiten de muur op de aanvalsroutes; elke golf komen opgeblazen vaten terug (populate).

const RADIUS := 5.5
const DAMAGE := 220.0
const HP := 40.0
const CLUSTERS := 9
const LAYER := 2  # hetzelfde als muren: kogels en soldaten botsen ertegen, en kogels roepen hit() aan

static var _spots: Array[Vector3] = []
static var _body_mat: StandardMaterial3D
static var _band_mat: StandardMaterial3D
static var _sign_mat: StandardMaterial3D

var hp := HP
var spot := Vector3.ZERO
var lit := false


## Zet vaten op alle plekken die nog leeg zijn (de eerste keer worden de plekken bepaald).
static func populate(root: Node3D) -> void:
	if _spots.is_empty():
		_make_spots()
	for n in root.get_tree().get_nodes_in_group("barrels"):
		if not Game.barrels.has(n):
			n.queue_free()  # restanten van een vorig spel
	for p in _spots:
		var taken := false
		for b in Game.barrels:
			if is_instance_valid(b) and b.spot == p:
				taken = true
				break
		if taken:
			continue
		var b := Barrel.new()
		b.spot = p
		b.position = p
		root.add_child(b)
		Game.barrels.append(b)


static func _make_spots() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var tries := 0
	while _spots.size() < CLUSTERS * 2 and tries < 400:
		tries += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(35.0, 48.0)
		var c := Vector3(cos(a) * r, 0.0, sin(a) * r)
		if c.z < -22.0:
			continue  # niet in de bosstrook en de rivier in het noorden
		if absf(c.x) < 6.0:
			continue  # de weg naar de poorten blijft vrij
		if Foliage.has_tree_near(c.x, c.z, 4.5):
			continue  # onder een palm zie je het vat niet
		var ok := true
		for s in _spots:
			if s.distance_to(c) < 7.0:
				ok = false
		if not ok:
			continue
		_spots.append(c)
		_spots.append(c + Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(0.8, 1.1)))
		if rng.randf() < 0.5 and _spots.size() < CLUSTERS * 2:
			_spots.append(c + Vector3(rng.randf_range(0.8, 1.1), 0.0, rng.randf_range(-0.3, 0.3)))


## Een ontploffing elders (raket, granaat, ander vat): vaten binnen de straal gaan mee.
static func catch_blast(at: Vector3, radius: float) -> void:
	for b in Game.barrels.duplicate():
		if is_instance_valid(b) and b.global_position.distance_to(at) < radius + 0.5:
			b.ignite(randf_range(0.08, 0.3))


func _ready() -> void:
	add_to_group("barrels")
	collision_layer = LAYER
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.42
	cyl.height = 1.0
	cs.shape = cyl
	cs.position.y = 0.5
	add_child(cs)
	_build()
	rotation.y = fmod(spot.x * 12.9898 + spot.z * 78.233, TAU)


func _build() -> void:
	if _body_mat == null:
		_body_mat = _mat(Color(0.62, 0.1, 0.07), 0.55, 0.45)
		_band_mat = _mat(Color(0.14, 0.13, 0.12), 0.7, 0.5)
		_sign_mat = _mat(Color(0.95, 0.78, 0.12), 0.8, 0.0)
	var body := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 0.38
	m.bottom_radius = 0.38
	m.height = 0.96
	m.radial_segments = 14
	m.rings = 1
	body.mesh = m
	body.material_override = _body_mat
	body.position.y = 0.5
	add_child(body)
	for y in [0.17, 0.5, 0.83]:
		var band := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = 0.395
		bm.bottom_radius = 0.395
		bm.height = 0.05
		bm.radial_segments = 14
		bm.rings = 1
		band.mesh = bm
		band.material_override = _band_mat
		band.position.y = y
		add_child(band)
	var top := MeshInstance3D.new()  # deksel met rand
	var tm := CylinderMesh.new()
	tm.top_radius = 0.34
	tm.bottom_radius = 0.34
	tm.height = 0.03
	tm.radial_segments = 14
	top.mesh = tm
	top.material_override = _band_mat
	top.position.y = 0.985
	add_child(top)
	var tag := MeshInstance3D.new()  # gele waarschuwingsstreep
	var qm := QuadMesh.new()
	qm.size = Vector2(0.34, 0.24)
	tag.mesh = qm
	tag.material_override = _sign_mat
	tag.position = Vector3(0.0, 0.5, 0.385)
	add_child(tag)


static func _mat(c: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func hit(dmg: float, dir: Vector3, _from_player: bool) -> void:
	if lit:
		return
	hp -= dmg
	Fx.spark(get_parent(), global_position + Vector3.UP * 0.6, -dir)
	if hp <= 0.0:
		ignite(0.0)


## Laat het vat na een korte vertraging ontploffen (0 = meteen).
func ignite(delay: float) -> void:
	if lit:
		return
	lit = true
	if delay <= 0.0:
		_blow()
	else:
		get_tree().create_timer(delay).timeout.connect(_blow)


func _blow() -> void:
	if not is_inside_tree():
		return
	var at := global_position + Vector3.UP * 0.4
	Game.barrels.erase(self)
	var parent := get_parent()
	Fx.explosion(parent, at, 1.15, Fx.CHUNKS_BARREL)
	Game.alert(at, 30.0, 6.0)
	for e in Game.enemies.duplicate():
		if is_instance_valid(e):
			var d: float = e.global_position.distance_to(at)
			if d < RADIUS:
				e.hit(DAMAGE * (1.0 - d / RADIUS * 0.7), (e.global_position - at).normalized(), true)
	if Game.builds:
		Game.builds.blast(at, RADIUS, DAMAGE, true)
	if Game.gates:
		for i in Game.gates.list.size():
			var gt: Dictionary = Game.gates.list[i]
			var gp: Vector3 = Game.gates.pos_of(gt)
			var gd: float = maxf(0.0, Vector2(gp.x - at.x, gp.z - at.z).length() - Data.GATE_GAP)
			if not gt.broken and gd < RADIUS:
				Game.gates.damage(i, DAMAGE * 0.35 * (1.0 - gd / RADIUS), "explosive")
	var p = Game.player
	if p != null and not p.dead:
		var pd: float = Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length()
		if pd < RADIUS:
			p.hit(DAMAGE * 0.25 * (1.0 - pd / RADIUS), (p.global_position - at).normalized(), false)
	var bx := maxf(absf(at.x) - Data.BUNKER_HALF, 0.0)
	var bz := maxf(absf(at.z) - Data.BUNKER_HALF, 0.0)
	var bd := Vector2(bx, bz).length()
	if bd < RADIUS:
		Game.damage_base(DAMAGE * 0.3 * (1.0 - bd / RADIUS))
	catch_blast(at, RADIUS)
	queue_free()
