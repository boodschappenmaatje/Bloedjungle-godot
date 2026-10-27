class_name SoldierModel
extends Node3D
## Het geanimeerde mannetje (VQ2: realistisch lichaam uit assets/soldaat_vq2.glb; v1: Quaternius-pop uit assets/soldaat.glb,
## beide met de Mixamo-geweeranimaties), gebruikt door de speler, bondgenoten en vijanden. Kleurt het uniform en hangt een
## wapen in de rechterhand.

const SCENE := preload("res://assets/soldaat.glb")
## VQ2-mannetje (bron/soldaat_vq2): realistisch MakeHuman-lichaam op hetzelfde DEF-skelet met dezelfde clips, vier
## lichaamsvarianten en uitrusting per type. Instelling "soldaat" = "v1" valt terug op het oude model.
const SCENE_V2 := preload("res://assets/soldaat_vq2.glb")
const LOOKS := {
	"eigen": ["Lijf_Uniform", "Helm", "Vest", "Koppel", "Rugzak", "Laarzen"],
	"speler:bloot": ["Lijf_Bloot", "Hoofdband", "Koppel", "Laarzen"],
	"speler:mouwloos": ["Lijf_Mouwloos", "Hoofdband", "Koppel", "Laarzen"],
	"speler:uniform": ["Lijf_Uniform", "Hoofdband", "Koppel", "Laarzen"],
	"speler:vest": ["Lijf_Uniform", "Hoofdband", "Vest", "Koppel", "Laarzen"],
	"vijand:knife": ["Lijf_Vijand", "Bandana", "Laarzen_V"],
	"vijand:rifle": ["Lijf_Vijand", "Boonie", "Borsttuig", "Laarzen_V"],
	"vijand:rocket": ["Lijf_Vijand", "Pet", "Raketzak", "Laarzen_V"],
	"vijand:heavy": ["Lijf_Vijand", "Staalhelm", "Patroongordels", "Laarzen_V"],
}
const LOOPS := ["stil", "lopen", "rennen", "achteruit", "schieten", "klimmen", "zitten", "sprinten"]  # herladen en rollen spelen één keer
const CLIMB := preload("res://assets/klimmen.glb")  # klim-animatie uit bron/klimmen
const SIT := preload("res://assets/zitten.glb")  # zitten in de vrachtwagen, uit bron/zitten
const ACTIONS := preload("res://assets/acties.glb")  # rollen, sprinten en een nieuwe herlaadbeweging, uit bron/acties

var anim: AnimationPlayer
var current := ""
var _mats: Array[StandardMaterial3D] = []
var _base_cols: Array[Color] = []
var _flash := 0.0
var _flash_color := Color(0.9, 0.1, 0.05)
var _model: Node
var _band: MeshInstance3D
var _fire_anim: AnimationPlayer
var _overlay_clip := ""
var _shoot_pose := false
var _shoot_rate := 0.2
var _hit_pose_time := 0.0
var _weapon_mount: Node3D
var _weapon_kind := "m1911"
var _recoil := 0.0
var _pump_parts: Array[Node3D] = []
var _pump_rest: Array[Transform3D] = []
var _pump_tween: Tween
var v2 := false
var look := ""
var _uniform := Color.WHITE


## uniform = kleur van het uniform; look = sleutel uit LOOKS ("eigen" voor bondgenoten en wachten,
## "speler:<bovenlijf>" voor de speler, "vijand:<type>" voor vijanden).
func setup(uniform: Color, gun_kind := "rifle", look_ := "eigen") -> void:
	v2 = GameSettings.get_value("soldaat") != "v1"
	look = look_ if LOOKS.has(look_) else "eigen"
	_uniform = uniform
	var model := (SCENE_V2 if v2 else SCENE).instantiate()
	add_child(model)
	anim = model.find_child("AnimationPlayer", true, false)
	# de klim-animatie komt uit een eigen glb met hetzelfde skelet en wordt aan dit mannetje gehangen
	var cp: AnimationPlayer = CLIMB.instantiate().find_child("AnimationPlayer", true, false)
	var lib := anim.get_animation_library("")
	if not lib.has_animation("klimmen"):
		lib.add_animation("klimmen", cp.get_animation("klimmen"))
	if not lib.has_animation("zitten"):
		var sp: AnimationPlayer = SIT.instantiate().find_child("AnimationPlayer", true, false)
		lib.add_animation("zitten", sp.get_animation("zitten"))
	# rollen, sprinten en de nieuwe herlaadbeweging (die de oude, trage lus vervangt) komen uit bron/acties
	if not lib.has_animation("rollen"):
		var ap: AnimationPlayer = ACTIONS.instantiate().find_child("AnimationPlayer", true, false)
		for n in ["rollen", "sprinten", "herladen", "explosie_dood", "brand_rennen", "brand_val"]:
			if lib.has_animation(n):
				lib.remove_animation(n)
			lib.add_animation(n, ap.get_animation(n))
		lib.get_animation("herladen").loop_mode = Animation.LOOP_NONE
		lib.get_animation("rollen").loop_mode = Animation.LOOP_NONE
		lib.get_animation("explosie_dood").loop_mode = Animation.LOOP_NONE
		lib.get_animation("brand_rennen").loop_mode = Animation.LOOP_LINEAR   # in brand door napalm: wild rennen, daarna brand_val
		lib.get_animation("brand_val").loop_mode = Animation.LOOP_NONE
	for n in LOOPS:
		if anim.has_animation(n):
			anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	if v2:
		_model = model
		_setup_v2(uniform)
		_attach_gun(model, gun_kind)
		_setup_upper_body_animation()
		play("stil")
		return
	# eigen kopie van de materialen, zodat elk mannetje een eigen kleur en rode flits kan hebben
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var src := mi.get_active_material(s)
			var m: StandardMaterial3D = src.duplicate() if src is StandardMaterial3D else StandardMaterial3D.new()
			if m.resource_name != "M_Joints":
				m.vertex_color_use_as_albedo = true  # legercamouflage in de hoekkleuren; de uniformkleur kleurt het patroon
				mi.mesh = _camo_mesh(mi.mesh)
			m.albedo_color = _tint(uniform, m.resource_name == "M_Joints")
			mi.set_surface_override_material(s, m)
			_mats.append(m)
			_base_cols.append(m.albedo_color)
	_attach_gun(model, gun_kind)
	_model = model
	_setup_upper_body_animation()
	play("stil")


var _parts := {}   # naam -> MeshInstance3D (VQ2)


## VQ2: toont alleen het lichaam en de uitrusting van deze look. Ongebruikte delen worden weggegooid, behalve bij de
## speler (die kan in het menu van bovenlijf wisselen). Kledingmaterialen ("*_Kleding") krijgen de uniformtint.
func _setup_v2(uniform: Color) -> void:
	var keep: Array = LOOKS[look]
	var player := look.begins_with("speler")
	for mi: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		var used := false
		for k in LOOKS:
			if (k == look or (player and k.begins_with("speler"))) and mi.name in LOOKS[k]:
				used = true
		if not used:
			mi.queue_free()
			continue
		_parts[str(mi.name)] = mi
		mi.visible = mi.name in keep
		for s in mi.mesh.get_surface_count():
			var src := mi.get_active_material(s)
			var m: StandardMaterial3D = src.duplicate() if src is StandardMaterial3D else StandardMaterial3D.new()
			mi.set_surface_override_material(s, m)
			_mats.append(m)
			_base_cols.append(m.albedo_color)
	set_uniform(uniform)


## Kleurtoon van de uniformkleur met beperkte verzadiging en helderheid. De VQ2-kledingtextuur is bijna neutraal
## (camouflage in grijstinten met een zweem kleur), dus de tint bepaalt de camouflagesoort; zelfde formule als
## bron/soldaat_vq2/render_soldaat.py.
static func uniform_tint(c: Color) -> Color:
	var mx := maxf(maxf(c.r, c.g), maxf(c.b, 0.001))
	var lum := 0.3 * c.r + 0.59 * c.g + 0.11 * c.b
	var k := 0.42 * clampf(mx / 0.35, 0.45, 1.0)
	var f := func(v: float) -> float: return (lum / mx + (v / mx - lum / mx) * 0.85) * k
	return Color(f.call(c.r), f.call(c.g), f.call(c.b))


## Speler: ander bovenlijf (bloot, mouwloos, uniform, vest) zonder het model opnieuw te laden.
func set_top(top: String) -> void:
	if not v2 or not look.begins_with("speler"):
		return
	var key := "speler:" + top
	if not LOOKS.has(key):
		return
	look = key
	for n in _parts:
		(_parts[n] as MeshInstance3D).visible = n in LOOKS[key]


## Zet alleen de schiet- en geraakt-houding op de romp/armen bovenop de loopanimatie.
## Daardoor blijven de benen lopen terwijl de handen het wapen blijven richten.
func _setup_upper_body_animation() -> void:
	_fire_anim = AnimationPlayer.new()
	_fire_anim.name = "CombatUpperBody"
	add_child(_fire_anim)
	_fire_anim.root_node = _fire_anim.get_path_to(_model)
	_fire_anim.process_priority = 2  # pas de pose toe nadat de gewone loopanimatie het skelet heeft bijgewerkt
	var lib := AnimationLibrary.new()
	var base_lib := anim.get_animation_library("")
	for source_name in ["schieten", "geraakt"]:
		if not base_lib.has_animation(source_name):
			continue
		var upper := (base_lib.get_animation(source_name) as Animation).duplicate() as Animation
		for track in range(upper.get_track_count() - 1, -1, -1):
			var path := str(upper.track_get_path(track))
			if not _is_upper_body_track(path):
				upper.remove_track(track)
		upper.loop_mode = Animation.LOOP_LINEAR if source_name == "schieten" else Animation.LOOP_NONE
		lib.add_animation("fire" if source_name == "schieten" else "hit", upper)
	_fire_anim.add_animation_library("", lib)


static func _is_upper_body_track(path: String) -> bool:
	for bone in ["DEF-spine001", "DEF-spine002", "DEF-spine003", "DEF-shoulderL", "DEF-shoulderR", "DEF-upper_armL", "DEF-upper_armR", "DEF-forearmL", "DEF-forearmR", "DEF-handL", "DEF-handR"]:
		if path.ends_with(":" + bone):
			return true
	return false


func set_shoot_pose(active: bool, weapon: String, rate: float) -> void:
	_shoot_pose = active
	_weapon_kind = weapon
	_shoot_rate = rate
	_update_shoot_pose()


func _update_shoot_pose() -> void:
	if _fire_anim == null or _hit_pose_time > 0.0:
		return
	if _shoot_pose and _fire_anim.has_animation("fire"):
		if _overlay_clip != "fire":
			_fire_anim.play("fire", 0.06)
			_overlay_clip = "fire"
		_fire_anim.speed_scale = clampf(_fire_anim.get_animation("fire").length / maxf(_shoot_rate, 0.06), 0.45, 5.0)
	elif _overlay_clip != "":
		_fire_anim.stop()
		_overlay_clip = ""


## Korte bovenlichaamshouding bij een treffer; de AI en de loopanimatie blijven doorlopen.
func hit_reaction(dir: Vector3, strength := 1.0) -> void:
	if _fire_anim == null or not _fire_anim.has_animation("hit"):
		return
	var horizontal := Vector3(dir.x, 0.0, dir.z)
	if horizontal.length_squared() > 0.01:
		var local := global_transform.basis.inverse() * horizontal.normalized()
		_model.rotation.y = clampf(local.x * 0.035, -0.04, 0.04)
	_hit_pose_time = clampf(0.56 / maxf(strength, 0.7), 0.36, 0.62)
	_fire_anim.play("hit", 0.035)
	_fire_anim.speed_scale = _fire_anim.get_animation("hit").length / _hit_pose_time
	_overlay_clip = "hit"


## Ander uniform (camouflage) voor het mannetje, zonder het model opnieuw te laden.
static var _camo: ArrayMesh


## Zet woodland-camouflage in de hoekkleuren van het mannetje: vlekken uit 3D-ruis op de plek van elk hoekpunt in rust, dus ze
## zitten vast aan de ledematen en schuiven niet. Basis neutraal grijs (0,8), vlekken relatief daaraan (donkergroen, bruin, zand, zwart).
## Eén keer gemaakt en door alle mannetjes gedeeld.
static func _camo_mesh(src: Mesh) -> Mesh:
	if _camo != null:
		return _camo
	var arr: Array = src.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ns: Array[FastNoiseLite] = []
	for seed_ in [3, 11, 29, 47]:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.seed = seed_
		n.frequency = 5.0 if seed_ != 47 else 8.0
		ns.append(n)
	var cols := PackedColorArray()
	cols.resize(verts.size())
	for i in verts.size():
		var v := verts[i]
		var c := Color(0.8, 0.8, 0.8)
		if ns[0].get_noise_3dv(v) > 0.18:
			c = Color(0.95, 0.85, 0.55)     # zand
		if ns[1].get_noise_3dv(v) > 0.12:
			c = Color(0.38, 0.52, 0.30)     # donkergroen
		if ns[2].get_noise_3dv(v) > 0.22:
			c = Color(0.72, 0.46, 0.28)     # bruin
		if ns[3].get_noise_3dv(v) > 0.3:
			c = Color(0.12, 0.13, 0.11)     # zwart
		cols[i] = c
	arr[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_camo = mesh
	return mesh


## Het camouflagepatroon is neutraal grijs (0,8), dus de uniformkleur wordt iets donkerder; gewrichten blijven donker en effen.
func _tint(c: Color, joints: bool) -> Color:
	if joints:
		return c.darkened(0.45)
	return Color(minf(c.r * 1.0, 1.0), minf(c.g * 1.0, 1.0), minf(c.b * 1.0, 1.0))


func set_uniform(c: Color) -> void:
	_uniform = c
	if v2:
		for i in _mats.size():
			var nm := _mats[i].resource_name
			if nm.ends_with("_Kleding"):
				_mats[i].albedo_color = uniform_tint(c)
			elif nm != "Hoofdband":
				_mats[i].albedo_color = Color.WHITE
			_base_cols[i] = _mats[i].albedo_color
		return
	var i := 0
	for m in _mats:
		m.albedo_color = _tint(c, m.resource_name == "M_Joints")
		_base_cols[i] = m.albedo_color
		i += 1


## Hoofdband om het voorhoofd, in de kleur van de gekozen band.
func set_band(c: Color) -> void:
	if v2:
		for i in _mats.size():
			if _mats[i].resource_name == "Hoofdband":
				_mats[i].albedo_color = c
				_base_cols[i] = c
		return
	if _band == null:
		var skel: Skeleton3D = _model.find_children("*", "Skeleton3D", true, false)[0]
		var bone := skel.find_bone("DEF-head")
		if bone < 0:
			return
		var att := BoneAttachment3D.new()
		att.bone_name = "DEF-head"
		skel.add_child(att)
		_band = MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = 0.105
		t.outer_radius = 0.13
		_band.mesh = t
		_band.material_override = StandardMaterial3D.new()
		_band.position = Vector3(0, 0.1, 0)
		att.add_child(_band)
	(_band.material_override as StandardMaterial3D).albedo_color = c


const GUNS := preload("res://assets/wapens.glb")  # bron/wapens: M1911, Thompson, Garand, Trench, MG42, Bazooka
const GUN_OF := {"rifle": "Garand", "rocket": "Bazooka", "heavy": "MG42", "m1911": "M1911", "thompson": "Thompson",
	"garand": "Garand", "trench": "Trench", "mg42": "MG42", "bazooka": "Bazooka"}

var _hand: BoneAttachment3D
var _gun: Node3D
var _grip_basis := Basis.IDENTITY  # zet het wapen recht vooruit in de stilstaande houding


func _attach_gun(model: Node, gun_kind := "rifle") -> void:
	var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	_hand = BoneAttachment3D.new()
	_hand.bone_name = "DEF-handR"
	skel.add_child(_hand)
	# zoals gunMountMatrix() in de web-versie: in de stilstaande houding wijst het wapen recht vooruit
	anim.play("stil")
	anim.seek(0.05, true)
	var pose := skel.get_bone_global_pose(skel.find_bone("DEF-handR"))
	_grip_basis = pose.basis.orthonormalized().inverse()
	if not v2:   # het VQ2-model heeft de uitrusting al in de glb
		_attach_gear(skel)
	set_gun(gun_kind)


const GEAR := preload("res://assets/uitrusting.glb")  # bron/uitrusting: helm, rugzak, koppel, laarzen
const GEAR_BONE := {"Helm": "DEF-head", "Rugzak": "DEF-spine003", "Koppel": "DEF-hips", "LaarsL": "DEF-footL", "LaarsR": "DEF-footR"}


## Hangt de uitrusting aan de botten. De delen zijn gemodelleerd in de ruimte van het mannetje in de stilstaande houding;
## de omgekeerde botpose zet ze in de ruimte van het bot.
func _attach_gear(skel: Skeleton3D) -> void:
	var holder := GEAR.instantiate()
	for part in GEAR_BONE:
		var node := holder.find_child(part, true, false) as Node3D
		var bone := skel.find_bone(GEAR_BONE[part])
		if node == null or bone < 0:
			continue
		node.get_parent().remove_child(node)
		var att := BoneAttachment3D.new()
		att.bone_name = GEAR_BONE[part]
		skel.add_child(att)
		node.transform = skel.get_bone_global_pose(bone).affine_inverse()
		att.add_child(node)
		# eigen materiaal: de hoekkleuren moeten als albedo gelden, ook als de import dat niet voor ons doet (Xogot)
		for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			var gm := StandardMaterial3D.new()
			gm.vertex_color_use_as_albedo = true
			gm.roughness = 0.75
			mi.material_override = gm
		if node is MeshInstance3D:
			var gm2 := StandardMaterial3D.new()
			gm2.vertex_color_use_as_albedo = true
			gm2.roughness = 0.75
			(node as MeshInstance3D).material_override = gm2
	holder.queue_free()


## Hangt een ander wapen in de hand ("" = niets). Namen als in Data.WEAPONS, of het type vijand.
func set_gun(kind: String) -> void:
	if _gun:
		_gun.queue_free()
		_gun = null
	if not GUN_OF.has(kind) or _hand == null:
		return
	var holder := GUNS.instantiate()
	var node := holder.find_child(GUN_OF[kind], true, false) as Node3D
	if node == null:
		holder.queue_free()
		return
	node.get_parent().remove_child(node)
	holder.queue_free()
	node.owner = null
	# het model heeft de loop langs -Z, het mannetje kijkt langs +Z
	node.transform = Transform3D(_grip_basis * Basis(Vector3.UP, PI) * Basis.from_scale(Vector3.ONE * GUN_SCALE.get(kind, 1.0)), _grip_basis * Vector3(0.0, 0.0, GUN_FWD.get(kind, 0.0)))
	if _weapon_mount == null:
		_weapon_mount = Node3D.new()
		_weapon_mount.name = "RecoilMount"
		_hand.add_child(_weapon_mount)
	_weapon_mount.position = Vector3.ZERO
	_weapon_mount.rotation = Vector3.ZERO
	_weapon_mount.add_child(node)
	_gun = node
	_weapon_kind = kind
	_recoil = 0.0
	_pump_parts.clear()
	_pump_rest.clear()
	if kind == "trench":
		for part: Node3D in _gun.find_children("*", "MeshInstance3D", true, false):
			if part.name.to_lower().contains("pomp"):
				_pump_parts.append(part)
				_pump_rest.append(part.transform)


## Terugslag wordt in een eigen wapenhouder gedempt, zonder de loop- of richtbesturing te veranderen.
func shoot_recoil(kind: String) -> void:
	if not _weapon_mount:
		return
	var profile: Dictionary = Data.WEAPON_VISUALS.get(kind, Data.WEAPON_VISUALS["m1911"])
	_recoil = minf(1.35, _recoil + float(profile.get("recoil", 0.6)))
	_weapon_kind = kind
	if kind == "trench":
		_pump_shotgun()


func _pump_shotgun() -> void:
	if _pump_parts.is_empty():
		return
	if _pump_tween != null and _pump_tween.is_running():
		_pump_tween.kill()
	_pump_tween = create_tween().set_parallel()
	for i in _pump_parts.size():
		_pump_parts[i].transform = _pump_rest[i]
		var rearward := _pump_rest[i].origin + _pump_rest[i].basis * Vector3(0.0, 0.0, 0.065)
		_pump_tween.tween_property(_pump_parts[i], "position", rearward, 0.075)
	_pump_tween.chain()
	for i in _pump_parts.size():
		_pump_tween.tween_property(_pump_parts[i], "position", _pump_rest[i].origin, 0.11)


## Loopmonding berekend uit de echte meshgrenzen van het gekozen GLB-wapen.
func muzzle_position() -> Vector3:
	if _gun == null:
		return global_position + Vector3.UP * 1.55 + Vector3.FORWARD * 0.55
	var inverse := _gun.global_transform.affine_inverse()
	var min_z := INF
	var tip_points: Array[Vector3] = []
	for mi: MeshInstance3D in _gun.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var box := mi.get_aabb()
		var relative := inverse * mi.global_transform
		for x in 2:
			for y in 2:
				for z in 2:
					var corner := Vector3(box.position.x + box.size.x * x, box.position.y + box.size.y * y, box.position.z + box.size.z * z)
					var point := relative * corner
					if point.z < min_z - 0.002:
						min_z = point.z
						tip_points.clear()
						tip_points.append(point)
					elif point.z <= min_z + 0.018:
						tip_points.append(point)
	if tip_points.is_empty():
		return _gun.to_global(Vector3(0.0, 0.0, -0.55))
	var center := Vector3.ZERO
	for point in tip_points:
		center += point
	center /= tip_points.size()
	return _gun.to_global(center + Vector3(0.0, 0.0, -0.018))


## Uitwerpopening per model: plek en richting zijn gekoppeld aan de gemonteerde wapenmesh.
func casing_position() -> Vector3:
	if _gun == null:
		return muzzle_position() - Vector3.UP * 0.15
	var local_offset: Vector3 = {
		"m1911": Vector3(0.035, 0.095, -0.055),
		"thompson": Vector3(0.045, 0.105, -0.13),
		"garand": Vector3(0.035, 0.11, -0.16),
		"trench": Vector3(0.04, 0.105, -0.08),
		"mg42": Vector3(0.055, 0.13, -0.18),
	}.get(_weapon_kind, Vector3(0.04, 0.1, -0.1))
	return _gun.to_global(local_offset)


func casing_axes() -> Array[Vector3]:
	if _gun == null:
		return [global_transform.basis.x.normalized(), -global_transform.basis.z.normalized()]
	return [_gun.global_transform.basis.x.normalized(), -_gun.global_transform.basis.z.normalized()]


const GUN_FWD := {"bazooka": 0.0}
# wapens op echte grootte; de camera staat dichter op het mannetje
const GUN_SCALE := {}


## Speelt een animatie met een zachte overgang; doet niets als hij al speelt.
func play(clip: String, blend := 0.18, speed := 1.0) -> void:
	if current == clip or not anim.has_animation(clip):
		if current == clip:
			anim.speed_scale = speed
		return
	current = clip
	anim.play(clip, blend)
	anim.speed_scale = speed


## Lengte van een animatie in seconden (0 als hij niet bestaat); handig om een clip precies op een duur te laten passen.
func clip_length(clip: String) -> float:
	return anim.get_animation(clip).length if anim != null and anim.has_animation(clip) else 0.0


## Korte kleurflits bij een treffer; de kleur kan per doeltype verschillen.
func flash(color := Color(0.9, 0.1, 0.05)) -> void:
	_flash = 0.1
	_flash_color = color


func _process(delta: float) -> void:
	if _recoil > 0.0:
		_recoil = maxf(0.0, _recoil - delta * 5.5)
		if _weapon_mount:
			_weapon_mount.position = Vector3(0.0, 0.0, -_recoil * 0.025)
			_weapon_mount.rotation.x = -_recoil * 0.09
	if _hit_pose_time > 0.0:
		_hit_pose_time = maxf(0.0, _hit_pose_time - delta)
		if _hit_pose_time <= 0.0:
			_model.rotation.y = 0.0
			_update_shoot_pose()
	if _flash > 0.0:
		_flash -= delta
		for i in _mats.size():
			_mats[i].albedo_color = _flash_color if _flash > 0.0 else _base_cols[i]
