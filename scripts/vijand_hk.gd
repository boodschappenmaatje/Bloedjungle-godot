class_name VijandHk
extends Node3D
## Het vijandelijke hoofdkwartier (Generals-plan stap D2, onderdeel 5a-2): Dennis' eigen model "Enemy hk" (Meshy), teruggebracht
## tot ~45.000 driehoeken (assets/vijand_hk.glb, bron/vijand_hk). Slopen = winnen: kogels, raketten, granaten, artillerie, tankgranaten
## en ontploffingen beschadigen het; op 0 stort het in en win je (Game.win). Onderweg: rook (60%), vuur (30%) en een levensbalk boven het dak.
## Het staat op een vaste plek in de vijandbasis (VijandBasis); de voorkant (deur, "HQ") kijkt naar de poort in de zuidmuur.

static var inst: VijandHk

const MODEL := "res://assets/vijand_hk.glb"
const LOD_WISSEL := 80.0   # m: daarachter wordt het eenvoudige model (5.000 driehoeken) getoond
const HP := 2500.0
## Kogels doen weinig tegen beton; raketten, granaten, artillerie en tankgranaten volle schade.
const TAKE := {"bullet": 0.1, "melee": 0.05, "explosive": 1.0}
## Botsblok: de kern van het gebouw zonder de steunberen onderaan (gemeten in bron/vijand_hk/maten.json), dak op 4,6 m.
const KERN := Vector3(7.4, 4.7, 7.3)
const KERN_MIDDEN := Vector3(0.0, 0.0, -0.5)
const PUIN_HOOGTE := 1.5   # m: het botsblok van de puinhoop
const BAR_BREED := 7.0
const BAR_Y := 9.4
const BLAST_R := 9.0

var hp := HP
var down := false
var hi: Node3D
var lod: Node3D
var wreck: Node3D
var body: VijandHkBody
var _cs: CollisionShape3D
var _fx: Node3D
var _bar: Node3D
var _bar_fill: MeshInstance3D
var _bar_t := 0.0

static var _mat_bg: StandardMaterial3D
static var _mat_fill: StandardMaterial3D


func _enter_tree() -> void:
	inst = self


func _exit_tree() -> void:
	if inst == self:
		inst = null


func _ready() -> void:
	_model()
	body = VijandHkBody.new()
	body.name = "Botsblok"
	body.collision_layer = Kit.LAYER_WALL | Kit.LAYER_BUNKER
	body.collision_mask = 0
	_cs = CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = KERN
	_cs.shape = bs
	_cs.position = KERN_MIDDEN + Vector3(0.0, KERN.y * 0.5, 0.0)
	body.add_child(_cs)
	add_child(body)
	_make_bar()


func _model() -> void:
	if not ResourceLoader.exists(MODEL):
		# zonder het model (bijvoorbeeld de OTA-keten nog niet geladen) toch een blok, zodat slopen en winnen werken
		hi = Node3D.new()
		Kit.box(hi, KERN_MIDDEN, KERN, Kit.flat(Color("5b6038")))
		add_child(hi)
		return
	var root := (load(MODEL) as PackedScene).instantiate() as Node3D
	add_child(root)
	hi = root.find_child("Romp", true, false) as Node3D
	lod = root.find_child("Romp_LOD1", true, false) as Node3D
	wreck = root.find_child("Wrak", true, false) as Node3D
	for n: Node3D in [hi, lod, wreck]:
		if n is MeshInstance3D:
			(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if hi is MeshInstance3D:
		(hi as MeshInstance3D).visibility_range_end = LOD_WISSEL
	if lod is MeshInstance3D:
		(lod as MeshInstance3D).visibility_range_begin = LOD_WISSEL
	if wreck is MeshInstance3D:
		# de ingestorte versie gebruikt dezelfde textures, maar zwart van het vuur
		var wm := (wreck as MeshInstance3D).get_active_material(0)
		if wm is StandardMaterial3D:
			var dark := (wm as StandardMaterial3D).duplicate() as StandardMaterial3D
			dark.albedo_color = Color(0.2, 0.19, 0.18)
			dark.roughness = 1.0
			dark.metallic = 0.0
			(wreck as MeshInstance3D).material_override = dark
	if wreck != null:
		wreck.visible = false


func _make_bar() -> void:
	if _mat_bg == null:
		_mat_bg = _bar_mat(Color(0, 0, 0, 0.65), 10)
		_mat_bg.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_fill = _bar_mat(Color(0.86, 0.2, 0.12), 11)
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	_bar = Node3D.new()
	_bar.position = Vector3(0.0, BAR_Y, 0.0)
	_bar.visible = false
	add_child(_bar)
	var bg := MeshInstance3D.new()
	bg.mesh = q
	bg.material_override = _mat_bg
	bg.scale = Vector3(BAR_BREED + 0.3, 0.75, 1)
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar.add_child(bg)
	_bar_fill = MeshInstance3D.new()
	_bar_fill.mesh = q
	_bar_fill.material_override = _mat_fill
	_bar_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar.add_child(_bar_fill)
	_set_bar()


static func _bar_mat(col: Color, prio: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.no_depth_test = true
	m.render_priority = prio
	m.albedo_color = col
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _set_bar() -> void:
	var f := clampf(hp / HP, 0.0, 1.0)
	_bar_fill.scale = Vector3(maxf(0.02, BAR_BREED * f), 0.45, 1)
	_bar_fill.position.x = -BAR_BREED * 0.5 + BAR_BREED * f * 0.5


func _process(delta: float) -> void:
	if down:
		_bar.visible = false
		return
	_bar_t = maxf(0.0, _bar_t - delta)
	# de balk staat in beeld als je dichtbij bent of net schade deed
	var p = Game.player
	var near: bool = p != null and is_instance_valid(p) and Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length() < 75.0
	_bar.visible = (near or _bar_t > 0.0) and (Game.state == "play" or Game.state == "prep")


## Het midden van het gebouw op halve hoogte, in wereldcoördinaten.
func mid() -> Vector3:
	return global_position + KERN_MIDDEN + Vector3.UP * 2.3


## Schade; kind: bullet, melee of explosive.
func damage(dmg: float, kind := "bullet") -> void:
	if down or dmg <= 0.0 or (Game.state != "play" and Game.state != "prep"):
		return
	var was := hp
	hp = maxf(0.0, hp - dmg * float(TAKE.get(kind, 1.0)))
	_bar_t = 4.0
	_set_bar()
	if randf() < 0.4:
		Fx.spark(self, mid() + Vector3(randf_range(-3.0, 3.0), randf_range(-0.8, 1.2), randf_range(-3.0, 3.0)), Vector3.UP)
	if hp < HP * 0.6 and was >= HP * 0.6:
		_fx = Fx.burning(self, global_position + Vector3(1.6, 4.7, -1.0), false)
		Game.banner.emit("VIJANDELIJK HK BESCHADIGD", "", 1.4)
	if hp < HP * 0.3 and was >= HP * 0.3:
		if _fx != null and is_instance_valid(_fx):
			_fx.queue_free()
		_fx = Fx.burning(self, global_position + Vector3(1.6, 4.7, -1.0), true)
		Game.banner.emit("HET HK STAAT IN BRAND", "", 1.4)
	if hp <= 0.0:
		_sloop()


## Het hoofdkwartier stort in: vuurbal, puinhoop en de missie is geslaagd.
func _sloop() -> void:
	down = true
	hp = 0.0
	var at := mid()
	if hi != null:
		hi.visible = false
	if lod != null:
		lod.visible = false
	if wreck != null:
		wreck.visible = true
	(_cs.shape as BoxShape3D).size = Vector3(KERN.x, PUIN_HOOGTE, KERN.z)
	_cs.position = KERN_MIDDEN + Vector3(0.0, PUIN_HOOGTE * 0.5, 0.0)
	if _fx != null and is_instance_valid(_fx):
		_fx.queue_free()
	_fx = Fx.burning(self, global_position + Vector3(0.0, 1.0, -0.5), true)
	Fx.explosion(self, at, 2.4, Fx.CHUNKS_BARREL)
	Sfx.play("boom", 1.0, at)
	Game.note_blast(at, BLAST_R)
	Game.alert(at, 60.0, 8.0)
	for i in 3:
		get_tree().create_timer(0.3 + 0.35 * i).timeout.connect(func() -> void:
			if is_inside_tree():
				Fx.explosion(self, at + Vector3(randf_range(-3.0, 3.0), randf_range(-1.5, 1.0), randf_range(-3.0, 3.0)), 1.6, Fx.CHUNKS_GROUND)
				Sfx.play("boom", 0.8, at))
	var cam: Camera3D = null
	var p = Game.player
	if p != null and is_instance_valid(p):
		cam = p.get_parent().get_node_or_null("Camera") as Camera3D
	if cam != null and cam.has_method("combat_impulse"):
		cam.call("combat_impulse", 0.12)
	Game.banner.emit("VIJANDELIJK HOOFDKWARTIER GESLOOPT", "", 3.0)
	Game.win("Het vijandelijke hoofdkwartier is gesloopt na %d aanvalsgroepen" % Game.wave)


## Ontploffing op `at` met straal en schade (zoals Generator.blast: vaten, granaten, raketten, artillerie, tankgranaten).
static func blast(at: Vector3, radius: float, dmg: float) -> void:
	if inst == null or inst.down:
		return
	var c := inst.global_position + KERN_MIDDEN
	var d := Vector2(maxf(absf(at.x - c.x) - KERN.x * 0.5, 0.0), maxf(absf(at.z - c.z) - KERN.z * 0.5, 0.0)).length()
	if d < radius:
		inst.damage(dmg * (1.0 - d / radius), "explosive")
