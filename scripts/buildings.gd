class_name Buildings
extends Node3D
## Gebouwen die je neerzet (nu de kazerne, zoals BUILD_DEFS in 16d-base.js): spookbeeld, plaatsen en de kazerne
## die rekruten opleidt. De rekruten zelf zijn Ally (ally.gd).

const DEFS := {
	"kazerne": {"name": "Kazerne", "cost": 1000, "size": Vector3(4.4, 2.2, 3.2), "max": 3},
}
# per niveau: soldaten tegelijk, seconden per rekruut, gezondheid, schade en wat het niveau kost
const LEVELS := [null,
	{"max": 2, "time": 10.0, "hp": 100.0, "dmg": 16.0},
	{"max": 4, "time": 7.0, "hp": 115.0, "dmg": 18.0, "cost": 1200},
	{"max": 6, "time": 5.0, "hp": 130.0, "dmg": 21.0, "cost": 1800}]
const TRAIN_COST := 250
const DOOR := 2.5  # afstand van het midden tot het punt voor de deur

var _ghost: MeshInstance3D
var _ghost_kind := ""


func _ready() -> void:
	add_to_group("buildings")


func count(kind: String) -> int:
	var n := 0
	for b in Game.buildings:
		if b.kind == kind:
			n += 1
	return n


## Plek en draaiing van het gebouw: een paar meter voor de speler, met de deur naar hem toe.
func spot(kind: String) -> Dictionary:
	var a: float = Game.player.face
	var at: Vector3 = Game.player.global_position + Vector3(sin(a), 0, cos(a)) * 4.0
	at.y = 0.0
	return {"at": at, "yaw": a + PI}


func can_place(kind: String, at: Vector3, yaw: float) -> bool:
	if Vector2(at.x, at.z).length() > Data.WORLD_R - 4.0:
		return false
	if count(kind) >= DEFS[kind].max:
		return false
	# de poortwegen blijven vrij
	if absf(at.x) < Data.GATE_GAP + 3.0 and absf(absf(at.z) - Data.COMPOUND) < 4.0:
		return false
	var sz: Vector3 = DEFS[kind].size
	var shape := BoxShape3D.new()
	shape.size = Vector3(sz.x + 0.4, 1.0, sz.z + 0.4)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = Kit.LAYER_WALL | Kit.LAYER_BUNKER
	q.transform = Transform3D(Basis(Vector3.UP, yaw), at + Vector3(0, 0.8, 0))
	if not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty():
		return false
	# de deur moet op vrij terrein uitkomen
	var door := at + Vector3(sin(yaw), 0, cos(yaw)) * (sz.z / 2.0 + 1.0)
	var q2 := PhysicsShapeQueryParameters3D.new()
	var s2 := SphereShape3D.new()
	s2.radius = 0.5
	q2.shape = s2
	q2.collision_mask = Kit.LAYER_WALL | Kit.LAYER_BUNKER
	q2.transform = Transform3D(Basis.IDENTITY, door + Vector3(0, 0.8, 0))
	return get_world_3d().direct_space_state.intersect_shape(q2, 1).is_empty()


func place() -> void:
	var kind: String = Game.build_arm
	if kind == "" or Game.player == null or (Game.state != "play" and Game.state != "prep"):
		return
	var sp := spot(kind)
	if not can_place(kind, sp.at, sp.yaw) or not Game.can_afford_build(DEFS[kind].cost):
		Sfx.play("ping")
		return
	Game.pay_build(DEFS[kind].cost)
	var node := Node3D.new()
	node.position = sp.at
	node.rotation.y = sp.yaw
	add_child(node)
	var model: Node = (load("res://assets/kazerne.glb") as PackedScene).instantiate()
	Kit.skin(model, kind)
	node.add_child(model)
	var sz: Vector3 = DEFS[kind].size
	Kit.collider(node, Vector3(0, sz.y / 2.0, 0), Vector3(sz.x, sz.y, sz.z), Kit.LAYER_WALL)
	Game.buildings.append({"kind": kind, "node": node, "at": sp.at, "yaw": sp.yaw, "lv": 1, "queue": 0, "train_t": 0.0})
	Sfx.play("thud")
	Game.build_arm = ""
	Game.changed.emit()


func door_of(b: Dictionary) -> Vector3:
	return b.at + Vector3(sin(b.yaw), 0, cos(b.yaw)) * DOOR


## De kazerne bij wiens deur de speler staat (of null).
func near_barracks() -> Variant:
	if Game.player == null:
		return null
	for b in Game.buildings:
		if b.kind == "kazerne" and (Game.player.global_position - door_of(b)).length() < 3.2:
			return b
	return null


func soldiers_alive() -> int:
	var n := 0
	for a in Game.allies:
		if is_instance_valid(a):
			n += 1
	return n


func queued() -> int:
	var n := 0
	for b in Game.buildings:
		n += b.queue
	return n


func room(b: Dictionary) -> int:
	return LEVELS[b.lv].max - soldiers_alive() - queued()


func recruit(b: Dictionary) -> void:
	if room(b) <= 0 or not Game.pay_points(TRAIN_COST):
		return
	if b.queue == 0:
		b.train_t = LEVELS[b.lv].time
	b.queue += 1
	Game.changed.emit()


func upgrade(b: Dictionary) -> void:
	var nx: Variant = LEVELS[b.lv + 1] if b.lv + 1 < LEVELS.size() else null
	if nx == null or not Game.pay_build(nx.cost):
		return
	b.lv += 1
	for a in Game.allies:
		if is_instance_valid(a):
			a.set_level(nx.hp, nx.dmg)
	Sfx.play("reload")
	Game.changed.emit()


func _spawn(b: Dictionary) -> void:
	var lv: Dictionary = LEVELS[b.lv]
	var a := Ally.new()
	add_child(a)
	a.global_position = door_of(b)
	a.face = b.yaw
	a.setup(lv.hp, lv.dmg, Game.allies.size())
	Game.allies.append(a)
	Sfx.play("reload")
	Game.banner.emit("NIEUWE REKRUUT", "", 1.0)
	Game.changed.emit()


func _physics_process(delta: float) -> void:
	_update_ghost()
	if Game.state != "play" and Game.state != "prep":
		return
	for b in Game.buildings:
		if b.queue > 0:
			b.train_t -= delta
			if b.train_t <= 0.0:
				b.queue -= 1
				_spawn(b)
				b.train_t = LEVELS[b.lv].time


func _update_ghost() -> void:
	var k: String = Game.build_arm
	if k == "" or Game.player == null or (Game.state != "play" and Game.state != "prep"):
		if _ghost:
			_ghost.visible = false
		return
	if _ghost == null:
		_ghost = MeshInstance3D.new()
		_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ghost.material_override = m
		add_child(_ghost)
	if _ghost_kind != k:
		var bm := BoxMesh.new()
		bm.size = DEFS[k].size
		_ghost.mesh = bm
		_ghost_kind = k
	var sp := spot(k)
	var sz: Vector3 = DEFS[k].size
	_ghost.visible = true
	_ghost.global_position = sp.at + Vector3(0, sz.y * 0.5, 0)
	_ghost.rotation.y = sp.yaw
	var ok := can_place(k, sp.at, sp.yaw) and Game.can_afford_build(DEFS[k].cost)
	(_ghost.material_override as StandardMaterial3D).albedo_color = Color(0.25, 0.95, 0.35, 0.3) if ok else Color(0.95, 0.2, 0.15, 0.35)
