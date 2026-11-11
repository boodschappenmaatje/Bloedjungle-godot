class_name VoertuigSchade
extends Node3D
## Levenspunten voor jouw eigen jeep en tank (Generals-plan, stap V3). Keuzes van Dennis, 11 november 2026: 1A jeep en tank (niet de Apache), 2A hetzelfde pantser als de
## vijandelijke voertuigen (jeep 220, tank 900 levenspunten, `Data.ARMOR_MULT`), 3B je sneuvelt mee als het voertuig kapot gaat (na 8 s terug bij de bunker), 4A weg is weg
## (nieuw kopen in de garage), 5A dezelfde levensbalk, rook (onder 50%), vuur (onder 25%) en zwart wrak (30 s) als de vijandelijke voertuigen, plus de balk van het voertuig in
## je eigen scherm zolang je erin zit, 6A vijanden schieten ook op een leeg geparkeerd voertuig.
##
## Dit onderdeel hangt als kind aan `jeep.gd` of `tank.gd` (`VoertuigSchade.attach`). Alleen schade van de vijand telt: kogels (`Bullet.vehicle_on_path` met `hostile`), raketten en
## tankgranaten (`VoertuigSchade.blast`). Jouw eigen kogels, granaten en ontploffingen raken je voertuig niet. Zit je erin, dan gaat alles wat jou zou raken naar het voertuig
## (`Player.hit` geeft dan niets meer door).

const KINDS := {
	"jeep": {"hp": 220.0, "armor": "jeep", "name": "JEEP", "bar_y": 3.3, "bar_w": 1.9, "smoke": Vector3(0.0, 0.9, -1.2), "flame": Vector3(0.0, 0.9, -1.2), "flame_h": 1.4, "boom": 3.5, "boom_fx": 1.3},
	"tank": {"hp": 900.0, "armor": "tank", "name": "TANK", "bar_y": 4.4, "bar_w": 2.8, "smoke": Vector3(0.0, 1.8, 2.6), "flame": Vector3(0.0, 1.7, 2.6), "flame_h": 1.8, "boom": 4.5, "boom_fx": 1.7},
}
const WRECK_STAY := 30.0    # s dat het wrak blijft liggen (zoals bij de vijandelijke voertuigen)
const SMOKE_AT := 0.5       # onder dit deel van de levenspunten rookt hij
const FIRE_AT := 0.25       # onder dit deel brandt hij
const BAR_SEEN := 70.0      # m: zo dichtbij moet je zijn om de balk te zien (zit je erin, dan altijd)

static var all: Array = []                 # de levende voertuigen met levenspunten (VoertuigSchade)
static var bestuurd: VoertuigSchade = null  # het voertuig waar jij nu in zit

signal vernield

var kind := "jeep"
var armor := "jeep"
var hp := 220.0
var max_hp := 220.0
var dead := false

var _vehicle: CharacterBody3D
var _shape: CollisionShape3D
var _info: Dictionary
var _bar: Node3D
var _bar_fill: MeshInstance3D
var _smoke: Node3D
var _fire: Node3D
var _wreck_t := 0.0


## Hang het onderdeel aan een voertuig. Zijn botsdoos heet "Shape" (zoals in scenes/jeep.tscn en scenes/tank.tscn).
static func attach(vehicle: CharacterBody3D, kind_: String) -> VoertuigSchade:
	var s := VoertuigSchade.new()
	s.name = "Schade"
	s.kind = kind_
	vehicle.add_child(s)
	return s


## Het deel levenspunten (0 tot 1) van het voertuig waar je in zit, of -1 als je in geen jeep of tank zit (voor de balk in je scherm).
static func bestuurd_fractie() -> float:
	if bestuurd == null or not is_instance_valid(bestuurd) or bestuurd.dead:
		return -1.0
	return clampf(bestuurd.hp / maxf(bestuurd.max_hp, 1.0), 0.0, 1.0)


## Naam van het voertuig waar je in zit ("JEEP" of "TANK"), anders een lege tekst.
static func bestuurd_naam() -> String:
	if bestuurd == null or not is_instance_valid(bestuurd) or bestuurd.dead:
		return ""
	return str(bestuurd._info.name)


## De voertuigen die vijanden als doel kiezen: alles wat nog heel is, ook als het leeg geparkeerd staat (keuze 6A).
static func doelen() -> Array:
	var out: Array = []
	for s: VoertuigSchade in all:
		if is_instance_valid(s) and not s.dead and is_instance_valid(s._vehicle):
			out.append(s._vehicle)
	return out


## Ontploffing van de vijand (raket, tankgranaat): schade neemt af met de afstand tot de carrosserie. `klasse` is de soort schade voor het pantser (Data.ARMOR_MULT).
static func blast(at: Vector3, radius: float, dmg: float, klasse := "explosie") -> void:
	for s: VoertuigSchade in all.duplicate():
		if not is_instance_valid(s) or s.dead:
			continue
		var d := s.blast_dist(at)
		if d < radius and not BaseWallRules.blocks_blast(at, s.global_position):
			s.take(dmg * Data.counter(klasse, s.armor) * (1.0 - d / radius * 0.7), (s.global_position - at).normalized())


func _ready() -> void:
	_vehicle = get_parent() as CharacterBody3D
	_shape = _vehicle.get_node("Shape") as CollisionShape3D
	_info = KINDS[kind]
	armor = str(_info.armor)
	max_hp = float(_info.hp)
	hp = max_hp
	all.append(self)
	_build_bar()


func _exit_tree() -> void:
	all.erase(self)
	if bestuurd == self:
		bestuurd = null


## De speler stapt in of uit: dan telt dit voertuig voor zijn scherm en vangt het de schade op.
func set_bestuurd(on: bool) -> void:
	if on:
		bestuurd = self
	elif bestuurd == self:
		bestuurd = null


# ---------------------------------------------------------------- raken

## Waar raakt het stuk kogelbaan van a naar b het voertuig? Geeft 0..1 langs de baan, of -1 als hij mist. Zoals bij `Auto.segment_hit`: alles tot `Bullet.HIT_TOP` telt als raak.
func segment_hit(a: Vector3, b: Vector3) -> float:
	var box := _shape.shape as BoxShape3D
	var la := to_local(a)
	var lb := to_local(b)
	var lo := Vector3(_shape.position.x - box.size.x * 0.5, -0.3, _shape.position.z - box.size.z * 0.5)
	var hi := Vector3(_shape.position.x + box.size.x * 0.5, maxf(_shape.position.y + box.size.y * 0.5, Bullet.HIT_TOP), _shape.position.z + box.size.z * 0.5)
	var t0 := 0.0
	var t1 := 1.0
	var d := lb - la
	for i in 3:
		if absf(d[i]) < 0.000001:
			if la[i] < lo[i] or la[i] > hi[i]:
				return -1.0
			continue
		var ta := (lo[i] - la[i]) / d[i]
		var tb := (hi[i] - la[i]) / d[i]
		t0 = maxf(t0, minf(ta, tb))
		t1 = minf(t1, maxf(ta, tb))
		if t0 > t1:
			return -1.0
	return t0


## Afstand van een punt tot de botsdoos (0 als het erin ligt).
func blast_dist(at: Vector3) -> float:
	var box := _shape.shape as BoxShape3D
	var l := to_local(at) - _shape.position
	var h := box.size * 0.5
	return Vector3(maxf(absf(l.x) - h.x, 0.0), maxf(absf(l.y) - h.y, 0.0), maxf(absf(l.z) - h.z, 0.0)).length()


## Een kogel van de vijand. De soort schade volgt uit Game.hit_class (raket, scherpschutter); anders is het een gewone kogel. Jouw eigen schoten doen niets.
func hit(dmg: float, dir: Vector3, from_player: bool) -> void:
	if from_player or dead:
		return
	var klasse := Game.hit_class if Game.hit_class != "" else "kogel"
	take(dmg * Data.counter(klasse, armor), dir)


## Levenspunten eraf (al met het pantser verrekend): vonken, rook onder de helft, vuur onder een kwart, en bij nul ontploft hij.
func take(dmg: float, dir: Vector3) -> void:
	if dead or dmg <= 0.0:
		return
	hp -= dmg
	if dir != Vector3.ZERO:
		Fx.spark(_vehicle.get_parent(), _vehicle.global_position + Vector3(0.0, 1.0, 0.0) - dir.normalized() * 0.8, -dir.normalized())
	if bestuurd == self and dmg >= 12.0:
		_shake(clampf(dmg / 400.0, 0.02, 0.07))
	if hp <= 0.0:
		_destroy(dir)
		return
	if hp < max_hp * SMOKE_AT and _smoke == null:
		_smoke = Fx.burning(_vehicle, _vehicle.global_position + _info.smoke, false)
	if hp < max_hp * FIRE_AT and _fire == null:
		_fire = Fx.flame(_vehicle, _info.flame, float(_info.flame_h))


func _shake(amount: float) -> void:
	var p = Game.player
	if p == null or not is_instance_valid(p):
		return
	var cam := p.get_parent().get_node_or_null("Camera") as Camera3D
	if cam != null and cam.has_method("combat_impulse"):
		cam.call("combat_impulse", amount)


# ---------------------------------------------------------------- kapot

## Het voertuig ontploft. Zat jij erin, dan sneuvel je mee (keuze 3B). Daarna blijft een zwart wrak staan, dat na 30 s verdwijnt: nieuw kopen kan in de garage (keuze 4A).
func _destroy(_dir: Vector3) -> void:
	dead = true
	hp = 0.0
	all.erase(self)
	var parent := _vehicle.get_parent()
	var at := _vehicle.global_position
	var p = Game.player
	var riding := bestuurd == self
	bestuurd = null
	if riding and p != null and is_instance_valid(p):
		p.sneuvel()
	if _vehicle.has_method("on_vernield"):
		_vehicle.call("on_vernield")
	_vehicle.collision_layer = 0
	_vehicle.collision_mask = 0
	_vehicle.remove_from_group("voertuigen")
	_bar.visible = false
	Fx.explosion(parent, at + Vector3(0.0, 0.8, 0.0), float(_info.boom_fx))
	Game.note_blast(at, float(_info.boom))   # de knal raakt wie er vlak naast staat, laat bomen vallen en steekt planten aan
	Game.alert(at, 14.0, 5.0)
	_char()
	if _smoke == null:
		_smoke = Fx.burning(_vehicle, at + _info.smoke, false)
	if _fire == null:
		_fire = Fx.flame(_vehicle, _info.flame, float(_info.flame_h))
	Game.banner.emit("JE %s IS VERNIELD" % str(_info.name), "", 1.6)
	if Game.builds != null and Game.builds.has_method("vehicle_lost"):
		Game.builds.vehicle_lost(_vehicle, kind)
	_wreck_t = WRECK_STAY
	vernield.emit()


## Het wrak is zwartgeblakerd: elk onderdeel krijgt hetzelfde donkere materiaal.
func _char() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.06, 0.055, 0.05)
	mat.roughness = 0.95
	for mi in _vehicle.find_children("*", "MeshInstance3D", true, false):
		if not _bar.is_ancestor_of(mi):
			(mi as MeshInstance3D).material_override = mat


# ---------------------------------------------------------------- levensbalk

## Een levensbalk boven het voertuig, groen op donker (de vijandelijke zijn rood); hij kijkt altijd naar de camera.
func _build_bar() -> void:
	var w := float(_info.bar_w)
	_bar = Node3D.new()
	_bar.name = "Levensbalk"
	_bar.position.y = float(_info.bar_y)
	_vehicle.add_child(_bar)
	for is_fill in [false, true]:
		var quad := QuadMesh.new()
		quad.size = Vector2(w - 0.12 if is_fill else w, 0.17 if is_fill else 0.27)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.albedo_color = Color(0.42, 0.82, 0.3) if is_fill else Color(0.025, 0.03, 0.025, 0.88)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		quad.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position.z = 0.012 if is_fill else 0.0
		_bar.add_child(mi)
		if is_fill:
			_bar_fill = mi
	_bar.visible = false


func _physics_process(delta: float) -> void:
	if dead:
		_wreck_t -= delta
		if _wreck_t <= 0.0:
			_vehicle.queue_free()
		return
	var p: Node3D = Game.player
	var dist := p.global_position.distance_to(_vehicle.global_position) if p != null and is_instance_valid(p) else INF
	_bar.visible = bestuurd == self or dist < BAR_SEEN
	if _bar.visible:
		var f := clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
		var w := float(_info.bar_w) - 0.12
		_bar_fill.scale.x = maxf(f, 0.001)
		_bar_fill.position.x = -(1.0 - f) * w * 0.5
		(_bar_fill.mesh.material as StandardMaterial3D).albedo_color = Color(0.42, 0.82, 0.3).lerp(Color(0.94, 0.25, 0.16), clampf((0.55 - f) / 0.4, 0.0, 1.0))
