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
const VAT := preload("res://assets/fx/vat.glb")  # bron/explosie/maak_vat.py: drie vaten met deuken, roest en een waarschuwingsband
static var _vat_mat: StandardMaterial3D
static var _lid_mat: StandardMaterial3D

const BURN_TIME := Vector2(2.6, 3.6)  # seconden tussen "gaat lekken en branden" en ontploffen

var hp := HP
var spot := Vector3.ZERO
var lit := false
var chained := false  # door een ander vat aangestoken: kleinere vuurbal
var burning := false  # onder de helft: vlam, gloed en een tikkende lont
var burn_t := 0.0
var _body: MeshInstance3D
var _lid: MeshInstance3D
var _own_lid: StandardMaterial3D
var _own_mat: StandardMaterial3D
var _flame: Node3D
var _wobble: Tween


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
			b.ignite(randf_range(0.12, 0.45), true)  # na elkaar, niet allemaal tegelijk
	Pomp.catch_blast(at, radius)  # benzinepompen en olievaten bij het benzinestation


func _ready() -> void:
	add_to_group("barrels")
	collision_layer = LAYER
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.42
	cyl.height = 2.0  # kogels vliegen op schouderhoogte (~1,3 m): de botsvorm is hoger dan het vat zelf, anders gaan ze eroverheen
	cs.shape = cyl
	cs.position.y = 1.0
	add_child(cs)
	_build()
	rotation.y = fmod(spot.x * 12.9898 + spot.z * 78.233, TAU)


func _build() -> void:
	if _vat_mat == null:
		# de hoekkleuren (rood, roest, geel-zwarte band) komen uit het model; het materiaal geeft alleen glans
		_vat_mat = _mat(Color.WHITE, 0.55, 0.2)
		_vat_mat.vertex_color_use_as_albedo = true
		_lid_mat = _mat(Color.WHITE, 0.6, 0.1)
		_lid_mat.vertex_color_use_as_albedo = true
	var n := (absi(int(spot.x * 7.0 + spot.z * 13.0)) % 3) + 1  # drie varianten met andere deuken en roest
	var holder := VAT.instantiate()
	var body := holder.find_child("Vat%d" % n, true, false) as MeshInstance3D
	var lid := holder.find_child("Deksel%d" % n, true, false) as MeshInstance3D
	_body = MeshInstance3D.new()
	_body.mesh = body.mesh
	_body.material_override = _vat_mat
	add_child(_body)
	_lid = MeshInstance3D.new()
	_lid.mesh = lid.mesh
	_lid.material_override = _lid_mat
	add_child(_lid)
	holder.queue_free()


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
		return
	_shake(0.12 + 0.2 * (1.0 - hp / HP))
	_set_glow(1.0 - hp / HP)
	if hp <= HP * 0.5 and not burning:
		_start_burning()


## Een geraakt vat schudt even; hoe zwaarder beschadigd, hoe harder.
func _shake(amount: float) -> void:
	if _wobble != null and _wobble.is_valid():
		_wobble.kill()
	rotation.x = 0.0
	rotation.z = 0.0
	_wobble = create_tween()
	var a := amount * randf_range(0.8, 1.2)
	var dir := Vector2.from_angle(randf() * TAU)
	_wobble.tween_property(self, "rotation:x", dir.x * a, 0.05)
	_wobble.parallel().tween_property(self, "rotation:z", dir.y * a, 0.05)
	_wobble.tween_property(self, "rotation:x", -dir.x * a * 0.5, 0.07)
	_wobble.parallel().tween_property(self, "rotation:z", -dir.y * a * 0.5, 0.07)
	_wobble.tween_property(self, "rotation:x", 0.0, 0.1)
	_wobble.parallel().tween_property(self, "rotation:z", 0.0, 0.1)


## Hitte: het vat wordt donkerder (verkoold) met een heel zachte rode gloed; de opening bovenop gloeit oranje (daar brandt het).
## amount: 0 = niets, 1 = zwaar in brand.
func _set_glow(amount: float) -> void:
	if _body == null:
		return
	if _own_mat == null:
		_own_mat = _vat_mat.duplicate() as StandardMaterial3D
		_own_mat.emission_enabled = true
		_body.material_override = _own_mat
		_own_lid = _lid_mat.duplicate() as StandardMaterial3D
		_own_lid.emission_enabled = true
		_lid.material_override = _own_lid
	var a := clampf(amount, 0.0, 1.0)
	_own_mat.albedo_color = Color.WHITE.lerp(Color(0.3, 0.22, 0.2), a)  # verkolen
	_own_mat.emission = Color(1.0, 0.2, 0.04)
	_own_mat.emission_energy_multiplier = 0.05 + 0.45 * a * a
	_own_lid.emission = Color(1.0, 0.28, 0.04)
	_own_lid.emission_energy_multiplier = 0.25 + 1.1 * a


## Onder de helft: het vat lekt een vlam en ontploft na enkele seconden vanzelf (ook als je niet meer schiet).
func _start_burning() -> void:
	burning = true
	burn_t = randf_range(BURN_TIME.x, BURN_TIME.y)
	_flame = Fx.flame(self, Vector3(0.0, 0.95, 0.0), 1.5)
	Fx.burning(self, global_position + Vector3(0.0, 0.95, 0.0), false)  # zwarte rook
	Fx.embers(self, Vector3(0.0, 0.98, 0.0))  # opstijgende vonken
	PerfMonitor.note("vat brandt")


func _process(delta: float) -> void:
	if not burning or lit:
		return
	burn_t -= delta
	# de gloed zwelt aan richting de knal, het vat trilt steeds vaker
	var frac := clampf(1.0 - burn_t / BURN_TIME.y, 0.0, 1.0)
	_set_glow(0.5 + 0.5 * frac + 0.15 * sin(Time.get_ticks_msec() * 0.03))
	if randf() < delta * (2.0 + 8.0 * frac):
		_shake(0.05 + 0.1 * frac)
	if burn_t <= 0.0:
		ignite(0.0)


## Laat het vat na een korte vertraging ontploffen (0 = meteen).
func ignite(delay: float, from_chain := false) -> void:
	if lit:
		return
	lit = true
	chained = from_chain
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
	Game.note_blast(at, RADIUS)
	Fx.explosion(parent, at, 0.6 if chained else 0.85, Fx.CHUNKS_BARREL)  # kleiner dan een raket: een vat is geen bom
	Game.alert(at, 30.0, 6.0)
	area_damage(at, RADIUS, DAMAGE)
	catch_blast(at, RADIUS)
	Fx.wreck(parent, global_position)
	queue_free()


## Schade van een ontploffing in een straal: vijanden, gebouwen (ook de huizen in de stad), poorten, jij en de bunker.
static func area_damage(at: Vector3, radius: float, dmg: float) -> void:
	for e in Game.enemies.duplicate():
		if is_instance_valid(e):
			var d: float = e.global_position.distance_to(at)
			if d < radius:
				e.hit(dmg * (1.0 - d / radius * 0.7), (e.global_position - at).normalized(), true)
	if Game.builds:
		Game.builds.blast(at, radius, dmg, true)
	Wachtpost.blast(at, radius, dmg)
	Generator.blast(at, radius, dmg)
	if Game.gates:
		for i in Game.gates.list.size():
			var gt: Dictionary = Game.gates.list[i]
			var gp: Vector3 = Game.gates.pos_of(gt)
			var gd: float = maxf(0.0, Vector2(gp.x - at.x, gp.z - at.z).length() - Data.GATE_GAP)
			if not gt.broken and gd < radius:
				Game.gates.damage(i, dmg * 0.35 * (1.0 - gd / radius), "explosive")
	var p = Game.player
	if p != null and not p.dead:
		var pd: float = Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length()
		if pd < radius:
			p.hit(dmg * 0.25 * (1.0 - pd / radius), (p.global_position - at).normalized(), false)
	var bx := maxf(absf(at.x) - Data.BUNKER_HALF, 0.0)
	var bz := maxf(absf(at.z) - Data.BUNKER_HALF, 0.0)
	var bd := Vector2(bx, bz).length()
	if bd < radius:
		Game.damage_base(dmg * 0.3 * (1.0 - bd / radius))
