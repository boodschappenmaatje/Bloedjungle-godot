class_name NoodReparatie
extends Node3D
## Kracht REPARATIE (generaalsrang, Rang): een groene ring rolt vanaf jou naar buiten en heelt alles van jou erbinnen: jijzelf, je soldaten,
## je gebouwen en bouwstukken, je jeeps en tanks en je voorraadtrucks. Niveau bepaalt de straal (Rang.REPARATIE_STRAAL) en het deel dat wordt geheeld.
## Alleen wat in leven is wordt geheeld: een vernield gebouw of een wrak blijft zoals het is (dat herbouw of koop je).

const DUUR := 1.1    # s dat de ring zichtbaar is
const GROEN := Color(0.35, 1.0, 0.5)

var straal := 20.0
var _t := 0.0
var _mi: MeshInstance3D
var _mat: ShaderMaterial


## Roept de reparatie op rond `at` (niveau 1 tot 3) en heelt meteen. Returns de ring (verdwijnt vanzelf).
static func start(parent: Node, at: Vector3, niveau: int) -> NoodReparatie:
	var n := NoodReparatie.new()
	n.straal = float(Rang.REPARATIE_STRAAL[clampi(niveau, 1, Rang.MAX_NIVEAU) - 1])
	parent.add_child(n)
	n.global_position = Vector3(at.x, 0.0, at.z)
	var geheeld := heel(at, n.straal, float(Rang.waarde("reparatie", niveau)))
	Game.banner.emit("NOODREPARATIE", "%d dingen geheeld · %d m" % [geheeld, roundi(n.straal)], 1.8)
	Sfx.play("reload")
	Sfx.play("ping", 0.8)
	return n


## Heelt alles in `straal` m rond `at` voor `deel` van zijn maximum. Returns hoeveel dingen er beschadigd waren en nu geheeld zijn.
static func heel(at: Vector3, straal_: float, deel: float) -> int:
	var geheeld := 0
	var flat := func(p: Vector3) -> float: return Vector2(p.x - at.x, p.z - at.z).length()
	var p = Game.player
	if p != null and is_instance_valid(p) and not p.dead and flat.call(p.global_position) <= straal_ and p.hp < Game.max_hp():
		p.hp = minf(Game.max_hp(), p.hp + deel * Game.max_hp())
		geheeld += 1
	for a in Game.allies:
		if is_instance_valid(a) and a.get("dead") != true and flat.call(a.global_position) <= straal_ and float(a.hp) < float(a.hp_max):
			a.hp = minf(float(a.hp_max), float(a.hp) + deel * float(a.hp_max))
			if a.get("model") != null:
				a.model.flash(Color(0.3, 1.0, 0.45))
			geheeld += 1
	for b in Game.buildings.duplicate():
		if not b is Dictionary or b.down or not is_instance_valid(b.node) or Buildings.under_construction(b) or float(b.hp) >= float(b.max_hp):
			continue
		if flat.call((b.node as Node3D).global_position) <= straal_:
			Game.builds.heal(b, deel * float(b.max_hp))
			geheeld += 1
	for s in VoertuigSchade.all:
		if is_instance_valid(s) and not s.dead and s.hp < s.max_hp and flat.call(s.global_position) <= straal_:
			s.heal(deel * s.max_hp)
			geheeld += 1
	for t in Game.get_tree().get_nodes_in_group("voorraadtruck"):
		if is_instance_valid(t) and t.state != VoorraadTruck.S.WRAK and float(t.hp) < VoorraadTruck.HP_MAX and flat.call((t as Node3D).global_position) <= straal_:
			t.hp = minf(VoorraadTruck.HP_MAX, float(t.hp) + deel * VoorraadTruck.HP_MAX)
			geheeld += 1
	return geheeld


func _ready() -> void:
	var shader := Shader.new()
	shader.code = ArtillerieAim.SHADER   # dezelfde ring als de richthulp van de artillerie
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_mat.render_priority = 9
	_mat.set_shader_parameter("col", GROEN)
	_mat.set_shader_parameter("radius", straal)
	_mat.set_shader_parameter("alpha", 0.9)
	var pm := PlaneMesh.new()
	pm.size = Vector2(straal * 2.0 + 1.0, straal * 2.0 + 1.0)
	_mi = MeshInstance3D.new()
	_mi.mesh = pm
	_mi.material_override = _mat
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mi.position = Vector3(0.0, 0.09, 0.0)
	_mi.scale = Vector3.ONE * 0.1
	add_child(_mi)


func _process(delta: float) -> void:
	_t += delta
	var k := clampf(_t / DUUR, 0.0, 1.0)
	_mi.scale = Vector3.ONE * lerpf(0.1, 1.0, 1.0 - pow(1.0 - k, 3.0))   # snel naar buiten, aan het eind rustig
	_mat.set_shader_parameter("alpha", 0.9 * (1.0 - k * k))
	if k >= 1.0:
		queue_free()
