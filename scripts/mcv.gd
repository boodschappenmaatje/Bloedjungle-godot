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
	if not Data.mcv_mode or not Game.mcv_deployed:
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
	_build_block_model()
	_build_ghost()
	_build_button()
	_board()


func _build_block_model() -> void:
	var body := Node3D.new()
	body.name = "Blokmodel"
	add_child(body)
	Kit.box(body, Vector3(0, 0.55, 0.6), Vector3(3.6, 1.7, 6.6), Kit.olive())              # laadbak met het opgevouwen hoofdkwartier
	Kit.box(body, Vector3(0, 0.55, -3.3), Vector3(3.4, 2.0, 1.9), Kit.olive())              # cabine
	Kit.box(body, Vector3(0, 2.0, -3.9), Vector3(3.0, 0.7, 0.7), Kit.flat(Color("2b3a40"), 0.3))   # voorruit
	Kit.box(body, Vector3(0, 2.25, 0.6), Vector3(3.0, 0.5, 6.0), Kit.rust())                # dak van de laadbak
	var wheel := CylinderMesh.new()
	wheel.top_radius = 0.62
	wheel.bottom_radius = 0.62
	wheel.height = 0.5
	var mat := Kit.flat(Color("1c1d1b"), 0.95)
	for z in [-3.1, -0.9, 1.3, 3.1]:
		for x in [-1.85, 1.85]:
			var mi := MeshInstance3D.new()
			mi.mesh = wheel
			mi.material_override = mat
			mi.position = Vector3(x, 0.62, z)
			mi.rotation.z = PI / 2.0
			body.add_child(mi)


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


func _build_button() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
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
		return
	var p = Game.player
	var live: bool = Game.state == "prep" and not deploying and not Game.build_mode
	var want_speed := 0.0
	var mv := Game.move
	if live and mv.length() > 0.15:
		# de wagen draait naar de kant waar je de stick duwt; ligt die achter hem, dan rijdt hij achteruit
		var want := atan2(-mv.x, -mv.y)
		var diff := wrapf(want - rotation.y, -PI, PI)
		var reverse := absf(diff) > 2.3
		if reverse:
			diff = wrapf(diff - PI, -PI, PI)
		rotation.y += clampf(diff, -TURN * delta, TURN * delta)
		var align := 1.0 - 0.6 * minf(absf(diff) / 1.2, 1.0)
		want_speed = (-REVERSE if reverse else SPEED * align) * minf(mv.length() * 1.3, 1.0)
	_speed = move_toward(_speed, want_speed, ACCEL * delta)
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
	Game.base_pos = at
	Game.base_yaw = yaw
	Game.mcv_deployed = true
	Game.prep_t = Data.MCV_RUST   # de klok van de eerste vijandelijke groep begint nu
	Game.free_depot = 1           # een gratis voorraaddepot (met eerste truck) om zelf neer te zetten
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
	Game.banner.emit("HOOFDKWARTIER STAAT", "Zet je gratis voorraaddepot neer via BOUW · eerste groep over %d min" % roundi(Data.MCV_RUST / 60.0), 5.0)
	Sfx.play("buy")
	Game.changed.emit()
	PerfMonitor.note("mcv uitgeklapt: %d planten weggehaald" % removed)
	queue_free()
