class_name Mcv
extends CharacterBody3D
## De bouwwagen (MCV) van de MCV-start (Dennis, 7 november 2026, docs/GENERALS_PLAN.md "Stap MCV"). Je begint in de wagen, rijdt hem naar een
## plek en klapt hem uit: de wagen wordt het hoofdkwartier (Bunker + Hoofdkwartier-model + voorplein, zoals voorheen in het vaste kamp) en de
## speler stapt eruit. Uitklappen kan maar één keer per spel; bij een nieuw spel kies je opnieuw.
## Eerste versie met een blok als model (stap 1); het echte model volgt na een goedgekeurde Asset Design Specification.
## Voorkant van de wagen is -Z (zoals de jeep); het hoofdkwartier krijgt dezelfde draaiing, zijn deur kijkt dus naar de achterkant van de wagen.

const SPEED := 7.0           # m/s vooruit
const REVERSE := 3.0
const ACCEL := 4.0
const TURN := 1.25           # rad/s draaien naar de kant waar je de stick duwt
const HALF := Vector3(1.9, 1.6, 4.2)   # botsblok van de wagen (halve maten)
const FOOT_CENTER := Vector2(0.0, 2.0)   # voetafdruk van het hoofdkwartier met voorplein in lokale (x, z)
const FOOT_SIZE := Vector2(14.0, 16.0)
const RIVER_MARGIN := 12.0   # zo ver moet je minstens van het water blijven om uit te klappen
const EDGE_MARGIN := 14.0    # en van de rand van de kaart
const DEPLOY_TIME := 1.4     # s tussen "UITKLAPPEN" en het staan van het hoofdkwartier
const PARK_X := 8.6          # m: de wagen parkeert zijwaarts naast het hoofdkwartier (lokaal +X), met de kraan op bereik van het gebouw
const PARK_EIND_Z := -0.45   # m: eindplek van de wagen (lokaal z); de kraan staat dan ongeveer naast het midden van het gebouw
const KEER_Z := -14.0        # m: de wagen rijdt eerst zo ver naar voren, zwenkt naar de zijkant en zet dan achteruit in
const PARK_Z := KEER_Z       # voor de plaatscontrole: het verste punt van de route
const LIFT_T := 1.8           # s: de laadbak kantelt de container omhoog
const KANTEL := 0.45          # rad (26 graden): zo schuin staat de container als hij van de laadbak glijdt
const SLIDE_D := 5.5          # m: zo ver rijdt de wagen door terwijl de container eraf glijdt en landt
const PARK_SPEED := 3.2      # m/s (met zachte start en stop)
const PARK_ACHTER := 2.6     # m/s achteruit
const KEER_WACHT := 0.6      # s: stilstaan voor het achteruitzetten
const WAGEN_L := 5.5         # m: wielbasis voor de stuurhoek
const PARK_REGION := {"name": "wagen", "center": Vector2(4.3, -7.0), "size": Vector2(10.6, 16.0), "yaw": 0.0}
const START_POS := Vector3(0.0, 0.0, 6.0)   # de kale open plek op de oorsprong (er worden daar geen bomen geplant)

var deploying := false
var deployed := false
var _speed := 0.0
var _ghost: MeshInstance3D
var _ghost_mat: StandardMaterial3D
var _status := {"valid": true, "reason": "", "vegetation": 0}
var _status_t := 0.0
var _btn: ActionBtn
var _board_done := false
var _model: McvModel
var _layer: CanvasLayer
var _steer := 0.0
var _park_from := Vector3.ZERO
var _park_to := Vector3.ZERO
var _park_t := -1.0          # s sinds het wegrijden (-1 = niet bezig)
var _park_basis := Basis.IDENTITY
var _park_yaw := 0.0
var _route: Array = []        # [{p: Vector2 (lokaal x, z), s: afstand}] voorwaarts: recht door, bocht naar de zijkant
var _route_len := 1.0
var _terug_len := 1.0
var _heading := 0.0
var _park_play := false
var _pre := 0.0               # s: de container wordt opgetild
var _geland := false          # de container staat op de grond
var _raakt := false           # de achterrand heeft de grond geraakt
var _opbouw   # McvOpbouw
var _park_last := 0.0


# ---------------------------------------------------------------- plekkeuze (statisch, ook voor de bouwregels)

## Ligt dit punt binnen het speelgebied (de kaart minus een rand)?
static func in_play_area(p: Vector3, margin := 0.0) -> bool:
	return absf(p.x) <= Data.WORLD_X - margin and p.z <= Data.WORLD_Z_S - margin and p.z >= -Data.WORLD_Z_N + margin


## Staat dit punt aan jouw kant van de rivier (zuid, de kant van de speler), met een speling van `margin` m van het water?
static func dry_side(p: Vector3, margin := 0.0) -> bool:
	return p.z - Data.river_z(p.x) >= Data.RIVER_HALF + margin


static func footprint_regions() -> Array:
	return [{"name": "hoofdkwartier", "center": FOOT_CENTER, "size": FOOT_SIZE, "yaw": 0.0}]


## Negen punten van de voetafdruk (hoeken, randmiddens en midden) in de wereld.
static func footprint_points(at: Vector3, yaw: float) -> Array:
	var out: Array = []
	var basis := Basis(Vector3.UP, yaw)
	for iu in 3:
		for iv in 3:
			var l := Vector3(FOOT_CENTER.x + (iu - 1) * FOOT_SIZE.x * 0.5, 0.0, FOOT_CENTER.y + (iv - 1) * FOOT_SIZE.y * 0.5)
			out.append(at + basis * l)
	# de wagen blijft na het uitklappen voor het hoofdkwartier staan: ook die plek moet droog zijn en binnen de kaart liggen
	out.append(at + basis * Vector3(0.0, 0.0, KEER_Z - 4.4))
	out.append(at + basis * Vector3(PARK_X, 0.0, KEER_Z))
	out.append(at + basis * Vector3(PARK_X, 0.0, PARK_EIND_Z))
	out.append(at + basis * Vector3(PARK_X, 0.0, PARK_EIND_Z + 4.4))
	return out


## Mag het hoofdkwartier hier staan? Geeft {valid, reason, vegetation}. Bomen, struiken, varens en rotsen zijn geen bezwaar: die verdwijnen.
## `world` en `exclude` (voor de wagen zelf) zijn nodig voor de botsingscontrole op muren en gebouwen; zonder world wordt die overgeslagen.
static func site_status(at: Vector3, yaw: float, world: World3D = null, exclude: Array[RID] = []) -> Dictionary:
	for p: Vector3 in footprint_points(at, yaw):
		if not in_play_area(p, EDGE_MARGIN):
			return {"valid": false, "reason": "Te dicht bij de rand van de kaart", "vegetation": 0}
		if not dry_side(p, RIVER_MARGIN):
			return {"valid": false, "reason": "Te dicht bij de rivier", "vegetation": 0}
	if world != null:
		var shape := BoxShape3D.new()
		shape.size = Vector3(FOOT_SIZE.x, 2.0, FOOT_SIZE.y)
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = shape
		q.collision_mask = Kit.LAYER_WALL | Kit.LAYER_BUNKER
		q.exclude = exclude
		var l := Vector3(FOOT_CENTER.x, 1.0, FOOT_CENTER.y)
		q.transform = Transform3D(Basis(Vector3.UP, yaw), at + Basis(Vector3.UP, yaw) * l)
		if not world.direct_space_state.intersect_shape(q, 1).is_empty():
			return {"valid": false, "reason": "Er staat iets in de weg", "vegetation": 0}
	return {"valid": true, "reason": "", "vegetation": Foliage.count_clearable_in_regions(footprint_regions(), at, yaw)}


## Draait het uitgeklapte hoofdkwartier (met voorplein en deur) om zijn midden: `delta_yaw` radialen erbij. Lukt alleen als de nieuwe voetafdruk vrij is
## van gebouwen en andere massieve dingen (de eigen delen tellen niet mee). Begroeiing en rotsen in de nieuwe voetafdruk verdwijnen. Geeft {ok, reason}.
static func rotate_hq(tree: SceneTree, delta_yaw: float) -> Dictionary:
	var holder := tree.get_first_node_in_group("mcv_hq") as Node3D
	if holder == null or not Game.mcv_deployed:
		return {"ok": false, "reason": "Er staat nog geen hoofdkwartier"}
	var new_yaw := wrapf(Game.base_yaw + delta_yaw, -PI, PI)
	var ex: Array[RID] = []
	for c in holder.find_children("*", "CollisionObject3D", true, false):
		ex.append((c as CollisionObject3D).get_rid())
	var st := site_status(Game.base_pos, new_yaw, holder.get_world_3d(), ex)
	if not st.valid:
		return {"ok": false, "reason": str(st.reason)}
	holder.rotation.y = new_yaw
	Game.base_yaw = new_yaw
	Foliage.clear_for_building(holder.get_instance_id(), footprint_regions(), Game.base_pos, new_yaw, Foliage.BUILD_CLEAR_MARGIN, true)
	var p = Game.player
	if p != null and is_instance_valid(p):
		p.home = Game.base_home()   # je komt na sneuvelen weer voor de deur terug
	Game.changed.emit()
	return {"ok": true, "reason": ""}


## Valt dit wereldpunt op het uitgeklapte hoofdkwartier (met voorplein)? Voor de tik in het bouwscherm.
static func hq_hit(g: Vector3) -> bool:
	if not Game.mcv_deployed:
		return false
	var local := Vector2(g.x - Game.base_pos.x, g.z - Game.base_pos.z).rotated(Game.base_yaw)
	return absf(local.x) <= FOOT_SIZE.x * 0.5 and absf(local.y - FOOT_CENTER.y) <= FOOT_SIZE.y * 0.5


# ---------------------------------------------------------------- de wagen zelf

func _ready() -> void:
	add_to_group("mcv")
	add_to_group("voertuigen")
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	# Voertuiglaag (32), niet de bunkerlaag: de camera schiet elke beeld een straal (muur + bunker, ook van binnenuit) en zou anders tegen de wagen botsen
	# en vlak boven hem komen te hangen (zichtbaar in de iPhone-opname van 8 november). Vijanden en kogels zijn er voor het uitklappen niet.
	collision_layer = 32
	collision_mask = Kit.LAYER_WALL | Kit.LAYER_BUNKER | Kit.LAYER_NATURE | Kit.LAYER_WATER | 32
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = HALF * 2.0
	cs.shape = bs
	cs.position.y = HALF.y
	add_child(cs)
	_model = McvModel.new()
	add_child(_model)
	_build_ghost()
	_build_button()
	_board()


## Het spookbeeld van de voetafdruk: groen = hier kan je uitklappen, rood = niet.
func _build_ghost() -> void:
	_ghost = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(FOOT_SIZE.x, 0.06, FOOT_SIZE.y)
	_ghost.mesh = bm
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mat.albedo_color = Color(0.2, 0.9, 0.3, 0.28)
	_ghost.material_override = _ghost_mat
	_ghost.position = Vector3(FOOT_CENTER.x, 0.08, FOOT_CENTER.y)
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ghost)
	var park := MeshInstance3D.new()   # de plek waar de wagen blijft staan
	var pm := BoxMesh.new()
	pm.size = Vector3(4.2, 0.05, 8.8)
	park.mesh = pm
	park.material_override = _ghost_mat
	park.position = Vector3(PARK_X, 0.01, PARK_EIND_Z + 0.2 - FOOT_CENTER.y)   # kind van de hoofdgrond: verdwijnt er samen mee
	park.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.add_child(park)


func _build_button() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_layer = layer
	_btn = ActionBtn.make("enter", "UITKLAPPEN")
	_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_btn.offset_left = ActionBtn.slot_x(2)
	_btn.offset_right = ActionBtn.slot_x(2) + ActionBtn.SIZE.x
	_btn.offset_top = -126.0
	_btn.offset_bottom = -126.0 + ActionBtn.SIZE.y
	_btn.pressed.connect(deploy)
	layer.add_child(_btn)


## De speler zit in de wagen: onzichtbaar, zonder botsing, de camera volgt hem (en dus de wagen).
func _board() -> void:
	var p = Game.player
	if p == null or _board_done:
		return
	_board_done = true
	p.driving = true
	p.visible = false
	p.collision_mask = 0
	p.velocity = Vector3.ZERO
	p.global_position = Vector3(global_position.x, 0.0, global_position.z)
	Game.banner.emit("KLAP JE WAGEN UIT", "Rijd naar een plek, groen = hier kan het", 4.0)


func _physics_process(delta: float) -> void:
	if deployed:
		_park_step(delta)
		return
	var p = Game.player
	var live: bool = Game.state == "prep" and not deploying and not Game.build_mode
	var want_speed := 0.0
	var steer_want := 0.0
	var mv := Game.move
	if live and mv.length() > 0.15:
		# de wagen draait naar de kant waar je de stick duwt; ligt die achter hem, dan rijdt hij achteruit
		var want := atan2(-mv.x, -mv.y)
		var diff := wrapf(want - rotation.y, -PI, PI)
		var reverse := absf(diff) > 2.3
		if reverse:
			diff = wrapf(diff - PI, -PI, PI)
		steer_want = clampf(diff * 1.2, -1.0, 1.0)
		rotation.y += clampf(diff, -TURN * delta, TURN * delta)
		var align := 1.0 - 0.6 * minf(absf(diff) / 1.2, 1.0)
		want_speed = (-REVERSE if reverse else SPEED * align) * minf(mv.length() * 1.3, 1.0)
	_speed = move_toward(_speed, want_speed, ACCEL * delta)
	_steer = move_toward(_steer, 0.0 if want_speed == 0.0 else steer_want * 0.5, 2.0 * delta)
	_model.drive(_speed, _steer, delta)
	if absf(_speed) > 0.01:
		velocity = -global_transform.basis.z * _speed
		move_and_slide()
		Foliage.ram(self, absf(_speed), 3.0, 5.0)   # zwaar voertuig: palmen en jungle-bomen vallen om
		global_position.y = 0.0
		if get_slide_collision_count() > 0:
			_speed *= 0.5
		var flat := Vector2(global_position.x, global_position.z)
		var clamped := Data.clamp_world(flat)
		if clamped != flat:
			global_position = Vector3(clamped.x, 0.0, clamped.y)
	if p != null and is_instance_valid(p):
		p.global_position = Vector3(global_position.x, 0.0, global_position.z)
		p.face = rotation.y + PI
	_status_t -= delta
	if _status_t <= 0.0:
		_status_t = 0.1
		_status = site_status(global_position, rotation.y, get_world_3d(), [get_rid()])
		_ghost_mat.albedo_color = Color(0.2, 0.9, 0.3, 0.28) if _status.valid else Color(0.95, 0.2, 0.15, 0.32)
	_btn.visible = live
	_btn.disabled = not _status.valid
	_btn.dock(2)


# ---------------------------------------------------------------- uitklappen

## Knop UITKLAPPEN: klopt de plek, dan klapt de wagen uit (kort wachten, dan staat het hoofdkwartier er).
func deploy() -> void:
	if deployed or deploying or Game.state != "prep":
		return
	var st := site_status(global_position, rotation.y, get_world_3d(), [get_rid()])
	if not st.valid:
		Game.banner.emit("HIER KAN HET NIET", str(st.reason), 2.2)
		return
	deploying = true
	_speed = 0.0
	Game.banner.emit("UITKLAPPEN...", "", DEPLOY_TIME)
	Sfx.play("thud", 0.8)
	await get_tree().create_timer(DEPLOY_TIME).timeout
	if is_inside_tree():
		deploy_now()


## Het hoofdkwartier komt op de plek van de wagen. Los aanroepbaar voor tests (geen wachttijd en geen plekcontrole).
func deploy_now() -> void:
	if deployed:
		return
	deployed = true
	deploying = false
	var at := Vector3(global_position.x, 0.0, global_position.z)
	var yaw := rotation.y
	var level := get_parent().get_node_or_null("Level")
	if level == null:
		level = get_parent()
	var holder := Node3D.new()
	holder.name = "MCV-hoofdkwartier"
	holder.position = at
	holder.rotation.y = yaw
	holder.add_to_group("mcv_hq")
	level.add_child(holder)
	# alles wat er staat verdwijnt: bomen, struiken, varens, gras en rotsen
	var removed := Foliage.clear_for_building(holder.get_instance_id(), footprint_regions(), at, yaw, Foliage.BUILD_CLEAR_MARGIN, true)
	BaseProps.build_hq(holder)
	# de wagen blijft als commandokern voor het hoofdkwartier staan: ook die strook wordt vrijgemaakt
	removed += Foliage.clear_for_building(get_instance_id(), [PARK_REGION], at, yaw, Foliage.BUILD_CLEAR_MARGIN, true)
	_opbouw = McvOpbouw.new()
	_opbouw.start(holder)   # het hoofdkwartier groeit in 20 s met steigers, nadat de wagen is weggereden en uitgeklapt
	Game.base_pos = at
	Game.base_yaw = yaw
	Game.mcv_deployed = true
	Game.prep_t = Progress.eerste_rust()   # de klok van de eerste vijandelijke groep begint nu
	Game.free_depot = 1           # een gratis voorraaddepot (met eerste truck) om zelf neer te zetten
	Game.free_towers = 4          # en vier gratis wachttorens (daarna 100 per stuk, alleen bij je hoofdkwartier)
	Game.free_wall = true
	Game.bcam = Vector3(at.x, at.z, 1.0)
	var p = Game.player
	if p != null and is_instance_valid(p):
		p.driving = false
		p.visible = true
		p.collision_mask = p.get("_mask0")
		p.velocity = Vector3.ZERO
		p.home = Game.base_home()
		p.global_position = p.home
		p.face = yaw
	Game.banner.emit("DE WAGEN KLAPT UIT", "Bouw via BOUW je gratis depot, muren en 4 gratis torens · eerste groep over %d min" % roundi(Data.MCV_RUST / 60.0), 5.0)
	Sfx.play("buy")
	Game.changed.emit()
	PerfMonitor.note("mcv uitgeklapt: %d planten weggehaald" % removed)
	_start_park()


## De wagen blijft staan als commandokern: hij is geen bestuurbaar voertuig meer en rijdt eerst uit het kamp (lokaal -Z).
func _start_park() -> void:
	remove_from_group("mcv")
	remove_from_group("voertuigen")
	add_to_group("mcv_wagen")
	collision_layer = 0   # tijdens het wegrijden staat de speler bij het hoofdkwartier: de wagen mag hem niet wegduwen
	for n in [_layer, _ghost]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_speed = 0.0
	_park_from = global_position
	_park_basis = global_transform.basis
	_park_yaw = rotation.y
	_maak_route()
	_park_t = 0.0
	_park_play = false
	_pre = 0.0
	_geland = false
	_raakt = false
	_model.los_container()
	Sfx.play("spuit", 0.9)
	Sfx.play("gate", 0.8)
	_model.set_schild_omhoog(true)
	if _opbouw != null:
		_opbouw.wagen = self


func _container_staat() -> void:
	Sfx.play("thud", 1.0)
	Sfx.play("boom", 0.3)
	var c := _model.container_pos()
	var b := Basis(Vector3.UP, rotation.y)
	for dx in [-1.0, 1.0]:
		for dz in [-1.8, 1.8]:
			McvFx.puff(get_parent(), c + b * Vector3(dx, 0.15, dz), 1.2, Color(0.6, 0.53, 0.42), 9, 1.0)


func _park_step(delta: float) -> void:
	if _park_t < 0.0:
		return
	if _pre < LIFT_T:
		# de laadbak kantelt de container omhoog, de wagen wacht
		_pre = minf(_pre + delta, LIFT_T)
		_model.zet_kantel(KANTEL * smoothstep(0.0, 1.0, _pre / LIFT_T), 0.0)
		return
	_park_t += delta
	var dur_v := _route_len / PARK_SPEED * 1.25
	var dur_a := _terug_len / PARK_ACHTER * 1.25
	var v := 0.0
	var k := 0.0
	var achteruit := false
	var pos2: Vector2
	var hoek := 0.0
	if _park_t < dur_v:
		var kv := _park_t / dur_v
		var ev := smoothstep(0.0, 1.0, kv)
		var r := _route_punt(ev * _route_len)
		pos2 = r[0]
		hoek = r[1]
		v = (_route_len / dur_v) * (6.0 * kv * (1.0 - kv))
		var stuur := clampf(atan(WAGEN_L * (hoek - _heading) / maxf(0.001, v * delta)), -McvModel.MAX_STEER, McvModel.MAX_STEER) if v > 0.2 and delta > 0.0 else 0.0
		_heading = hoek
		_model.drive(v, stuur, delta)
		k = 0.5 * kv
	elif _park_t < dur_v + KEER_WACHT:
		pos2 = Vector2(PARK_X, KEER_Z)
		hoek = 0.0
		_model.drive(0.0, 0.0, delta)
		k = 0.5
	else:
		var ka := clampf((_park_t - dur_v - KEER_WACHT) / dur_a, 0.0, 1.0)
		var ea := smoothstep(0.0, 1.0, ka)
		pos2 = Vector2(PARK_X, lerpf(KEER_Z, PARK_EIND_Z, ea))
		hoek = 0.0
		v = (_terug_len / dur_a) * (6.0 * ka * (1.0 - ka))
		achteruit = true
		_model.drive(-v, 0.0, delta)
		k = 0.5 + 0.5 * ka
	global_position = _park_from + _park_basis * Vector3(pos2.x, 0.0, pos2.y)
	rotation.y = _park_yaw + hoek
	Foliage.ram(self, v, 3.0, 5.0)
	var dist := minf(Vector2(pos2.x, pos2.y).length(), 1e6)
	# de wagen rijdt vooruit en de container glijdt van de laadbak: de achterrand raakt de grond, dan klapt de voorkant omlaag
	var q := clampf(dist / SLIDE_D, 0.0, 1.0) if not achteruit and _park_t < dur_v else 1.0
	if not _geland:
		var zak := McvModel.BAK_HOOGTE * smoothstep(0.0, 1.0, clampf((q - 0.3) / 0.45, 0.0, 1.0))
		var kant := KANTEL * (1.0 - smoothstep(0.0, 1.0, clampf((q - 0.75) / 0.25, 0.0, 1.0)))
		_model.zet_kantel(kant, zak)
		if q >= 0.75 and not _raakt:
			_raakt = true
			Sfx.play("thud", 0.7)
			var c0 := _model.container_pos()
			McvFx.puff(get_parent(), c0 + Basis(Vector3.UP, rotation.y) * Vector3(0.0, 0.2, 1.9), 1.3, Color(0.6, 0.53, 0.42), 9, 1.0)
		if q >= 1.0:
			_geland = true
			_container_staat()
	if k >= 1.0 and not _park_play and _geland and _park_t >= dur_v + KEER_WACHT + dur_a:
		_park_play = true
		_model.play_uitklappen()
		Sfx.play("spuit", 0.9)
	if _park_play and _model.uitklappen_klaar():
		if _opbouw != null and is_instance_valid(_opbouw):
			_opbouw.begin()
		_park_t = -1.0
		collision_layer = 32


## De route: recht naar voren (de container glijdt eraf), dan een S-bocht naar de zijkant (lokaal +X) en achteruit inparkeren.
func _maak_route() -> void:
	_route.clear()
	var s := 0.0
	var vorig := Vector2.ZERO
	var p0 := Vector2(0.0, -SLIDE_D)
	_route.append({"p": Vector2.ZERO, "s": 0.0, "h": 0.0})
	var n := 24
	for i in range(1, n + 1):
		var u := float(i) / float(n)
		var p := Vector2(0.0, -SLIDE_D * u)
		s += (p - vorig).length()
		_route.append({"p": p, "s": s, "h": 0.0})
		vorig = p
	var p3 := Vector2(PARK_X, KEER_Z)
	var c1 := p0 + Vector2(0.0, -4.5)
	var c2 := p3 + Vector2(0.0, 4.5)
	var m := 60
	for i in range(1, m + 1):
		var u := float(i) / float(m)
		var w := (1.0 - u) * (1.0 - u) * (1.0 - u) * p0 + 3.0 * (1.0 - u) * (1.0 - u) * u * c1 + 3.0 * (1.0 - u) * u * u * c2 + u * u * u * p3
		var d := 3.0 * (1.0 - u) * (1.0 - u) * (c1 - p0) + 6.0 * (1.0 - u) * u * (c2 - c1) + 3.0 * u * u * (p3 - c2)
		s += (w - vorig).length()
		_route.append({"p": w, "s": s, "h": atan2(-d.x, -d.y)})
		vorig = w
	_route_len = s
	_terug_len = absf(PARK_EIND_Z - KEER_Z)
	_heading = 0.0


## Punt en stand (draaihoek om Y, t.o.v. de beginrichting) op afstand s langs de voorwaartse route.
func _route_punt(s: float) -> Array:
	var i := 1
	while i < _route.size() - 1 and float(_route[i].s) < s:
		i += 1
	var a: Dictionary = _route[i - 1]
	var b: Dictionary = _route[i]
	var u := clampf((s - float(a.s)) / maxf(0.0001, float(b.s) - float(a.s)), 0.0, 1.0)
	return [(a.p as Vector2).lerp(b.p as Vector2, u), lerp_angle(float(a.h), float(b.h), u)]
