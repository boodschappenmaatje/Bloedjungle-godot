class_name HqRoofGun
extends Node3D
## Automatisch dakgeweer van het hoofdkwartier (niveau 3, Generals-plan stap 3): een MG 42 (het bestaande VQ2-model uit
## assets/wapens.glb) op een stalen statief met schild en munitiekist. Het wordt in BUILD_TIME seconden zichtbaar opgebouwd
## (Godot-gestuurd, geen Blender-clip), draait daarna zelf naar de dichtstbijzijnde vijand en schiet binnen RANGE meter.
## Treffers van het dakgeweer tellen als die van een soldaat (src "soldaat"); de score telt wel voor je rang.

const BUILD_TIME := 10.0
const RANGE := 25.0
const FIRE_RATE := 0.1        # s tussen twee schoten
const DAMAGE := 17.0
const SPEED := 90.0
const AMMO := 300
const MOUNT_Y := 0.62         # hoogte van de wieg boven het dak
const SPOT_LOCAL := Vector3(1.65, 5.17, 0.1)   # dakplek in modelruimte van het hoofdkwartier (vrij van schotel, luik en zoeklicht)
const GUN_PAD := "res://assets/wapens.glb"
const NEST_R := 0.66          # straal van het zandzaknest (hart van de zakken)
const NEST_BAG := 0.6         # schaal van de zandzakken uit assets/props.glb (0,37 m lang)
const NEST_COURSES := 3
const NEST_OPEN := Vector2(60.0, 300.0)   # hoekbereik (graden, 0 = oost) waar het nest dicht is: west, noord en zuid; oost is de dakrand

var ammo := AMMO
var built := false
var build_t := 0.0
var aim := 0.0                # draairichting (rad), 0 = naar +Z
var shots_fired := 0

var _fire_t := 0.0
var _plate: Node3D
var _legs: Array[Node3D] = []
var _post: Node3D
var _cradle: Node3D
var _shield: Node3D
var _box: Node3D
var _mount: Node3D            # draait mee met het richten
var _gun: Node3D
var _weld: OmniLight3D
var _spark_t := 0.0
var _stage_done := {}
var _nest: Array[Node3D] = []   # de lagen van het zandzaknest; vallen een voor een neer tijdens de bouw


func _ready() -> void:
	add_to_group("hq_gun")
	position = SPOT_LOCAL
	_build_parts()
	_apply_build(0.0)


## animate = true: zichtbaar opbouwen (BUILD_TIME s). false: staat er meteen (spel laden, test).
func start(animate: bool) -> void:
	if animate:
		build_t = 0.0
		built = false
		_weld = OmniLight3D.new()
		_weld.light_color = Color(1.0, 0.7, 0.35)
		_weld.omni_range = 3.5
		_weld.light_energy = 0.0
		_weld.shadow_enabled = false
		_weld.position = Vector3(0.0, 0.3, 0.0)
		add_child(_weld)
	else:
		build_t = BUILD_TIME
		_finish(false)


func progress() -> float:
	return clampf(build_t / BUILD_TIME, 0.0, 1.0)


func refill() -> void:
	ammo = AMMO + int(Game.upg.get("sentry", 0)) * 70


func _build_parts() -> void:
	var steel := Kit.flat(Color("2d302c"), 0.55, 0.65)
	var olive := Kit.flat(Color("4a5430"), 0.8, 0.1)
	var dark := Kit.flat(Color("1c1d1b"), 0.5, 0.7)
	_plate = Node3D.new()
	_plate.name = "Plaat"
	add_child(_plate)
	Kit.box(_plate, Vector3(0, 0.03, 0), Vector3(0.95, 0.06, 0.95), steel)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Kit.cylinder(_plate, Vector3(sx * 0.38, 0.07, sz * 0.38), 0.035, 0.03, dark, 6)   # bouten
	for i in 3:
		var a := TAU * float(i) / 3.0 + 0.4
		var leg := Node3D.new()
		leg.name = "Poot%d" % i
		leg.position = Vector3(cos(a) * 0.14, 0.06, sin(a) * 0.14)
		add_child(leg)
		var strut := Kit.box(leg, Vector3(cos(a) * 0.16, 0.26, sin(a) * 0.16), Vector3(0.06, 0.52, 0.06), steel)
		strut.rotation = Vector3(sin(a) * 0.32, 0.0, -cos(a) * 0.32)
		_legs.append(leg)
	_post = Node3D.new()
	_post.name = "Paal"
	_post.position = Vector3(0, 0.06, 0)
	add_child(_post)
	Kit.cylinder(_post, Vector3(0, 0.25, 0), 0.07, 0.5, steel, 10)
	Kit.cylinder(_post, Vector3(0, 0.5, 0), 0.1, 0.06, dark, 10)
	_mount = Node3D.new()
	_mount.name = "Draaipunt"
	_mount.position = Vector3(0, MOUNT_Y, 0)
	add_child(_mount)
	_cradle = Node3D.new()
	_cradle.name = "Wieg"
	_mount.add_child(_cradle)
	Kit.box(_cradle, Vector3(0, 0.02, 0.0), Vector3(0.26, 0.05, 0.34), steel)
	Kit.box(_cradle, Vector3(-0.11, 0.1, 0.0), Vector3(0.03, 0.16, 0.2), steel)
	Kit.box(_cradle, Vector3(0.11, 0.1, 0.0), Vector3(0.03, 0.16, 0.2), steel)
	_shield = Node3D.new()
	_shield.name = "Schild"
	_mount.add_child(_shield)
	Kit.box(_shield, Vector3(0, 0.27, 0.34), Vector3(0.62, 0.42, 0.035), olive)
	Kit.box(_shield, Vector3(0, 0.36, 0.34), Vector3(0.24, 0.05, 0.04), dark)     # sleuf voor de loop
	Kit.box(_shield, Vector3(0, 0.06, 0.34), Vector3(0.62, 0.04, 0.05), steel)
	_box = Node3D.new()
	_box.name = "Munitiekist"
	_mount.add_child(_box)
	Kit.box(_box, Vector3(0.3, 0.07, 0.02), Vector3(0.2, 0.15, 0.3), olive)
	Kit.box(_box, Vector3(0.3, 0.158, 0.02), Vector3(0.2, 0.02, 0.3), steel)
	Kit.box(_box, Vector3(0.3, 0.16, 0.14), Vector3(0.08, 0.04, 0.06), Kit.flat(Color("b8a14a"), 0.4, 0.8))   # patroongordel
	_gun = _load_gun()
	if _gun != null:
		_mount.add_child(_gun)
	_build_nest()


## Zandzaknest: een hoefijzer van drie lagen om het geweer, open naar de dakrand (oost) die de rug dekt. Echte zandzakken uit
## assets/props.glb (Kit.prop_mesh), per laag een eigen knooppunt zodat de lagen tijdens de bouw een voor een neervallen.
func _build_nest() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var arc := deg_to_rad(NEST_OPEN.y - NEST_OPEN.x)
	var n := int(arc * NEST_R / (0.62 * NEST_BAG * 0.92))
	var bag_h := 0.2 * NEST_BAG * 1.15
	for c in NEST_COURSES:
		var layer := Node3D.new()
		layer.name = "NestLaag%d" % (c + 1)
		add_child(layer)
		var xf: Array = [[], [], []]
		for i in n:
			var th := deg_to_rad(NEST_OPEN.x) + arc * (float(i) + 0.5 + (0.5 if c % 2 == 1 else 0.0)) / float(n)
			if th > deg_to_rad(NEST_OPEN.y):
				continue
			var yaw := atan2(-cos(th), -sin(th)) + rng.randf_range(-0.1, 0.1) + (PI if rng.randf() < 0.5 else 0.0)
			var pos := Vector3(cos(th) * NEST_R, 0.06 + bag_h * 0.5 + float(c) * bag_h * 0.9, sin(th) * NEST_R)
			var b := Basis.from_euler(Vector3(0.0, yaw, 0.0)).scaled(Vector3(NEST_BAG, NEST_BAG * 1.15, NEST_BAG))
			xf[rng.randi() % 3].append(Transform3D(b, pos))
		for v in 3:
			if not xf[v].is_empty():
				Kit.scatter(layer, Kit.prop_mesh(Kit.BAGS[v]), _nest_material(Kit.prop_mesh(Kit.BAGS[v])), xf[v])
		_nest.append(layer)


## De props-zakken zijn geelbruin; in het zonlicht op het dak worden ze oranje. Iets grijzer, zodat ze bij de beige wal eronder passen.
func _nest_material(mesh: Mesh) -> Material:
	var base := mesh.surface_get_material(0) as StandardMaterial3D
	if base == null:
		return null
	var m := base.duplicate() as StandardMaterial3D
	m.albedo_color = Color(0.74, 0.72, 0.66)
	return m


## De MG 42 uit assets/wapens.glb: de loop wijst naar -Z in het model, het draaipunt kijkt naar +Z, dus een halve slag.
func _load_gun() -> Node3D:
	var ps = load(GUN_PAD)
	if not ps is PackedScene:
		return null
	var holder: Node = (ps as PackedScene).instantiate()
	var mg := holder.find_child("MG42", true, false) as Node3D
	if mg == null:
		holder.queue_free()
		return null
	mg.get_parent().remove_child(mg)
	mg.owner = null
	mg.name = "MG42"
	mg.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 0.17, -0.1))
	holder.queue_free()
	return mg


func _process(delta: float) -> void:
	if not built:
		build_t += delta
		_apply_build(build_t)
		_weld_fx(delta)
		if build_t >= BUILD_TIME:
			_finish(true)
		return
	_fire(delta)


func _stage(t: float, from: float, to: float) -> float:
	return smoothstep(0.0, 1.0, clampf((t - from) / (to - from), 0.0, 1.0))


## Opbouw in fasen: zandzaknest (drie lagen vallen neer), plaat, poten, paal, schild en kist, geweer neerlaten (BUILD_TIME = 10 s).
func _apply_build(t: float) -> void:
	var k := t / BUILD_TIME
	for c in _nest.size():
		var sn := _stage(t, 0.4 + float(c), 1.4 + float(c))
		_nest[c].visible = sn > 0.0
		_nest[c].position.y = (1.0 - sn) * 0.6
	var s1 := _stage(t, 0.0, 1.5)
	_plate.scale = Vector3(s1, maxf(s1, 0.01), s1)
	_plate.visible = s1 > 0.0
	for i in _legs.size():
		var si := _stage(t, 1.5 + float(i) * 0.5, 3.0 + float(i) * 0.5)
		_legs[i].scale = Vector3(1.0, maxf(si, 0.01), 1.0)
		_legs[i].visible = si > 0.0
	var s3 := _stage(t, 3.5, 5.5)
	_post.scale = Vector3(1.0, maxf(s3, 0.01), 1.0)
	_post.visible = s3 > 0.0
	var s4 := _stage(t, 5.5, 7.5)
	_cradle.visible = s4 > 0.0
	_cradle.scale = Vector3.ONE * maxf(s4, 0.01)
	_shield.visible = s4 > 0.0
	_shield.position = Vector3(0, (1.0 - s4) * 0.9, 0)
	var s5 := _stage(t, 7.5, 8.5)
	_box.visible = s5 > 0.0
	_box.scale = Vector3.ONE * maxf(s5, 0.01)
	if _gun != null:
		var s6 := _stage(t, 8.2, 9.6)
		_gun.visible = s6 > 0.0
		_gun.position.y = 0.17 + (1.0 - s6) * 1.1
		if s6 >= 1.0 and not _stage_done.has("land"):
			_stage_done["land"] = true
			Sfx.play("thud", 1.0, global_position)
	if k >= 0.96:
		# laatste halve seconde: het geweer draait even heen en weer als test
		var w := (t - BUILD_TIME * 0.96) / (BUILD_TIME * 0.04)
		_mount.rotation.y = sin(w * TAU) * 0.5
	for mark in [[1.5, "plaat"], [3.4, "nest"], [3.0, "poten"], [5.5, "paal"], [7.5, "schild"]]:
		if t >= mark[0] and not _stage_done.has(mark[1]):
			_stage_done[mark[1]] = true
			Sfx.play("thud", 0.8, global_position)


func _weld_fx(delta: float) -> void:
	if _weld != null and is_instance_valid(_weld):
		_weld.light_energy = (1.2 + randf() * 1.4) if fmod(build_t, 0.5) < 0.35 else 0.15
	_spark_t -= delta
	if _spark_t > 0.0 or build_t > BUILD_TIME - 0.6:
		return
	_spark_t = randf_range(0.18, 0.4)
	var parent: Node = Game.defs if Game.defs != null and is_instance_valid(Game.defs) else get_tree().current_scene
	if parent == null:
		return
	var h := clampf(build_t / BUILD_TIME, 0.0, 1.0)
	var at := to_global(Vector3(randf_range(-0.2, 0.2), 0.05 + h * 0.75, randf_range(-0.2, 0.2)))
	Fx.spark(parent, at, Vector3.UP)


func _finish(announce: bool) -> void:
	built = true
	build_t = BUILD_TIME
	_apply_build(BUILD_TIME)
	_mount.rotation.y = 0.0
	if _weld != null and is_instance_valid(_weld):
		_weld.queue_free()
		_weld = null
	ammo = AMMO + int(Game.upg.get("sentry", 0)) * 70
	if announce and (Game.state == "play" or Game.state == "prep"):
		Game.banner.emit("DAKGEWEER KLAAR", "Schiet automatisch binnen %d m" % int(RANGE), 2.0)


func _nearest_enemy() -> Node3D:
	var from := global_position
	var best: Node3D = null
	var bd := RANGE
	for e in Game.enemies:
		if not is_instance_valid(e) or e.get("dead") == true:
			continue
		var d := Vector2(e.global_position.x - from.x, e.global_position.z - from.z).length()
		if d < bd:
			bd = d
			best = e
	return best


## Richt en schiet. Los van _process zodat de test het geweer direct kan laten schieten.
func _fire(delta: float) -> void:
	_fire_t -= delta
	if Game.state != "play":
		return
	var e := _nearest_enemy()
	if e == null:
		return
	var from := global_position
	var ta := atan2(e.global_position.x - from.x, e.global_position.z - from.z)
	aim += angle_difference(aim, ta) * minf(1.0, delta * 10.0)
	# draairichting in de ruimte van het hoofdkwartier (schaal en draaiing van de ouder meegerekend)
	var parent3d := get_parent() as Node3D
	var base_yaw := parent3d.global_rotation.y if parent3d != null else 0.0
	_mount.rotation.y = aim - base_yaw
	if ammo > 0 and _fire_t <= 0.0 and absf(angle_difference(aim, ta)) < 0.2:
		_fire_t = FIRE_RATE
		ammo -= 1
		shots_fired += 1
		_shoot(e, aim + randf_range(-0.045, 0.045))


func _shoot(e: Node3D, ang: float) -> void:
	var parent: Node = Game.defs if Game.defs != null and is_instance_valid(Game.defs) else get_tree().current_scene
	if parent == null:
		return
	var up: float = float(Game.upg.get("sentry", 0))
	var fwd := Vector3(sin(ang), 0.0, cos(ang))
	var muzzle := Vector3(global_position.x, 0.0, global_position.z) + fwd * 0.9
	muzzle.y = global_position.y + MOUNT_Y * 0.92 + 0.15
	var dist := Vector2(e.global_position.x - muzzle.x, e.global_position.z - muzzle.z).length()
	var b := Bullet.fire(parent, muzzle, ang, SPEED, DAMAGE * (1.0 + up * 0.25), 0.6, true, true, 0, 0.0, maxf(0.0, (muzzle.y - 1.3) / maxf(4.0, dist - 1.1)))
	b.src = "soldaat"
	Fx.muzzle(parent, muzzle, "mg42", ang)
	Sfx.play("sentry", 0.9, muzzle)
