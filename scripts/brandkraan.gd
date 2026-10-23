class_name Brandkraan
extends StaticBody3D
## Brandkraan in de stad. Schiet hem kapot, ontploft er iets vlakbij of rijd er met een voertuig overheen: de dop knalt eraf en er spuit
## een straal van ruim 3 m hoog. De animatie komt uit Blender (bron/straatmeubilair/maak_straatmeubilair.py, assets/brandkraan.glb):
## clip Spuit (dop vliegt eraf, straal en druppels komen op gang) gevolgd door Spuiten (lus). Mist, druppels en een groeiende plas zijn
## deeltjes en een schijf in code. Na SPRAY_TIME seconden is de leiding leeg.

const MODEL := preload("res://assets/brandkraan.glb")
const HP := 30.0
const SPRAY_TIME := 45.0
const DRIVE_OVER := 0.6   # marge rond de botsvorm van een voertuig; de kraan is massief, dus het voertuig staat er tegenaan
const NOZZLE := Vector3(0.0, 1.0, 0.0)

static var all: Array = []

var hp := HP
var sprayed := false
var _model: Node3D
var _anim: AnimationPlayer
var _water: Array[Node3D] = []
var _timer := 0.0
var _hiss := 0.0
var _check := 0.0
var _fx: Array[Node] = []


func _ready() -> void:
	all.append(self)
	collision_layer = Barrel.LAYER   # kogels botsen ertegen en roepen hit() aan, je loopt er niet doorheen
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(0.75, 1.4, 0.75)
	cs.shape = b
	cs.position = Vector3(0, 0.7, 0)
	add_child(cs)
	_model = MODEL.instantiate()
	add_child(_model)
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for n in _model.find_children("*", "Node3D", true, false):
		if String(n.name) == "Straal" or String(n.name).begins_with("Druppel"):
			_water.append(n)
			n.visible = false


func _exit_tree() -> void:
	all.erase(self)


## Een ontploffing elders (Game.note_blast): kraan binnen de straal knalt open.
static func catch_blast(at: Vector3, radius: float) -> void:
	for k: Brandkraan in all.duplicate():
		if is_instance_valid(k) and not k.sprayed and k.global_position.distance_to(at) < radius + 0.5:
			k.burst()


func hit(dmg: float, dir: Vector3, _from_player: bool) -> void:
	if sprayed:
		return
	hp -= dmg
	Fx.spark(get_parent(), global_position + Vector3.UP * 0.5, -dir)
	if hp <= 0.0:
		burst()


func _physics_process(delta: float) -> void:
	if sprayed:
		_timer += delta
		_hiss -= delta
		if _hiss <= 0.0 and _timer < SPRAY_TIME:
			_hiss = 1.0
			Sfx.play("spuit", 0.45, global_position)
		if _timer >= SPRAY_TIME:
			_stop()
		return
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.1
	for v in get_tree().get_nodes_in_group("voertuigen"):
		if is_instance_valid(v) and _raakt(v):
			burst()
			return


## Staat dit voertuig tegen of op de kraan? De kraan is een botsvorm waar voertuigen niet doorheen kunnen, dus meet tegen hun botsdoos.
func _raakt(v: Node3D) -> bool:
	var cs := v.get_node_or_null("Shape") as CollisionShape3D
	if cs == null or not (cs.shape is BoxShape3D):
		return Vector2(v.global_position.x - global_position.x, v.global_position.z - global_position.z).length() < 2.0
	var half := (cs.shape as BoxShape3D).size * 0.5
	var p := cs.to_local(global_position)
	return absf(p.x) < half.x + DRIVE_OVER and absf(p.z) < half.z + DRIVE_OVER and absf(p.y) < half.y + 1.5


## De dop knalt eraf en het water spuit.
func burst() -> void:
	if sprayed:
		return
	sprayed = true
	var night := GameSettings.get_value("time") != "day"
	for n in _water:
		n.visible = true
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var mesh := (n as MeshInstance3D).mesh   # het water licht 's nachts zacht op, anders is het zwart
			for i in mesh.get_surface_count():
				var wm := mesh.surface_get_material(i) as StandardMaterial3D
				if wm != null:
					wm.emission_enabled = night
					wm.emission = Color(0.22, 0.3, 0.4)
	if _anim != null and _anim.has_animation("Spuit"):
		_anim.play("Spuit")
		_anim.animation_finished.connect(_loop, CONNECT_ONE_SHOT)
	var parent := get_parent()
	Fx.dust(parent, global_position + Vector3(0, 0.3, 0))
	Sfx.play("spuit", 0.9, global_position)
	Game.alert(global_position, 22.0, 3.0)
	_add_fx()
	PerfMonitor.note("brandkraan spuit")


func _loop(_name: StringName) -> void:
	if _anim == null or not sprayed or _timer >= SPRAY_TIME:
		return
	for n in ["Spuiten", "Spuiten-loop"]:
		if _anim.has_animation(n):
			_anim.play(n)
			return


func _add_fx() -> void:
	# 's avonds is water geen wit: de deeltjes zijn onbelicht, dus kleur ze zelf donkerder
	var tint := Color(0.85, 0.92, 1.0) if GameSettings.get_value("time") == "day" else Color(0.3, 0.38, 0.5)
	var white := [Color(tint, 0.0), Color(tint, 0.3), Color(tint, 0.0)]
	var offs := [0.0, 0.25, 1.0]
	# nevel boven in de straal, nevel en opspattend water onderaan
	var top := Fx._puff(14, 1.5, 1.5, false, Fx._ramp(white, offs), Vector2(0.4, 1.2), 2.0)
	top.position = Vector3(0, 2.6, 0)
	var foot := Fx._puff(14, 1.2, 1.1, false, Fx._ramp(white, offs), Vector2(0.8, 1.6), 1.6)
	foot.position = Vector3(0, 0.15, 0)
	foot.spread = 85.0
	# fijne druppels die uit de opening schieten en terugvallen
	var drops := Fx._spray(60, 1.3, Vector3(0.025, 0.05, 0.025), Color(0.82, 0.92, 1.0, 0.7), 4.5, 6.6, 18.0, 9.8, false)
	drops.position = NOZZLE
	var dm := (drops.mesh as BoxMesh).material as StandardMaterial3D
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.albedo_color = Color(tint, 0.7)
	for p: CPUParticles3D in [top, foot, drops]:
		add_child(p)
		p.emitting = true
		_fx.append(p)
	# plas: groeit in een paar seconden tot 2,4 m straal
	var pool := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 0.005
	cm.radial_segments = 24
	cm.rings = 1
	pool.mesh = cm
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.03, 0.05, 0.06, 0.4)
	pm.roughness = 0.05
	pm.metallic = 0.3
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pool.material_override = pm
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pool.position = Vector3(0, 0.14, 0)
	pool.scale = Vector3(0.1, 1, 0.1)
	add_child(pool)
	create_tween().tween_property(pool, "scale", Vector3(2.4, 1, 2.4), 9.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_fx.append(pool)


## Leiding leeg: straal weg, de plas blijft nog liggen.
func _stop() -> void:
	set_physics_process(false)
	if _anim != null:
		_anim.stop()
	for n in _water:
		n.visible = false
	for n in _fx:
		if is_instance_valid(n) and n is CPUParticles3D:
			(n as CPUParticles3D).emitting = false
