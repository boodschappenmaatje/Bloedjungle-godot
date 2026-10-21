class_name Bridge
extends Node3D
## De houten ophaalbrug (assets/brug.glb, gemaakt in Blender): de klep draait om een scharnier aan de zuidoever omhoog,
## bediend met een hendel in het kastje naast de brug. Omhoog = de rivier is dicht (alleen nog de ondiepte);
## omlaag = je kunt eroverheen lopen en rijden. De animaties heten Omhoog en Omlaag.

enum {DOWN, RISING, UP, LOWERING}

const REACH := 3.4          # afstand tot het kastje waarop de knop verschijnt
const LEAF_Z0 := -3.4       # de klep loopt (in Godot-z ten opzichte van het midden van de rivier) van hier...
const LEAF_Z1 := 6.2        # ...tot hier (het scharnier)
const RAIL_X := 2.72

var state := DOWN
var model: Node3D
var anim: AnimationPlayer
var _leaf_rails: StaticBody3D
var _water: StaticBody3D
var _lamp_r: Node3D
var _lamp_g: Node3D
var _box: Node3D


func _ready() -> void:
	model = (load("res://assets/brug.glb") as PackedScene).instantiate()
	Kit.skin(model, "brug")
	add_child(model)
	anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_lamp_r = model.find_child("LampRood", true, false) as Node3D
	_lamp_g = model.find_child("LampGroen", true, false) as Node3D
	_box = model.find_child("KastjePunt", true, false) as Node3D
	if anim:
		anim.animation_finished.connect(_on_done)
		# de glb rust omhoog; begin met de klep omlaag (einde van Omlaag), want de staat is DOWN
		anim.play("Omlaag")
		anim.seek(anim.current_animation_length, true)
		anim.stop(true)
	# leuningen van de vaste delen (altijd) en van de klep (alleen als hij omlaag ligt)
	_rail_body(Vector3(0, 0, 6.8), 1.2)    # zuidoprit
	_rail_body(Vector3(0, 0, -4.8), 2.8)   # noordoprit
	_leaf_rails = _rail_body(Vector3(0, 0, (LEAF_Z0 + LEAF_Z1) / 2.0), LEAF_Z1 - LEAF_Z0)
	# als de brug omhoog staat, sluit dit blok de rivier af (zelfde laag als de onzichtbare oevers)
	_water = StaticBody3D.new()
	_water.collision_layer = Kit.LAYER_WATER
	_water.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(6.6, 3.0, 2.0 * (Data.RIVER_HALF + 0.7))
	cs.shape = bs
	cs.position = Vector3(0, 1.5, 0)
	_water.add_child(cs)
	add_child(_water)
	_apply()


func _rail_body(pos: Vector3, length: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Kit.LAYER_WALL
	body.collision_mask = 0
	body.position = pos
	for sx in [-1.0, 1.0]:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.2, 1.2, length)
		cs.shape = bs
		cs.position = Vector3(sx * RAIL_X, 0.6, 0)
		body.add_child(cs)
	add_child(body)
	return body


func is_down() -> bool:
	return state == DOWN


func box_pos() -> Vector3:
	return _box.global_position if _box else global_position


func near_player() -> bool:
	var pl = Game.player
	return pl != null and pl.elev <= 1.0 and pl.global_position.distance_to(box_pos()) < REACH


## Staat er iemand op de klep? Dan blijft hij liggen.
func occupied() -> bool:
	var pts: Array = [Game.player.global_position] if Game.player else []
	for e in Game.enemies:
		pts.append(e.global_position)
	for a in Game.allies:
		pts.append(a.global_position)
	for p in pts:
		var l: Vector3 = to_local(p)
		if absf(l.x) < 3.0 and l.z > LEAF_Z0 - 0.5 and l.z < LEAF_Z1 + 0.5:
			return true
	return false


func toggle() -> void:
	if state == RISING or state == LOWERING or (Game.state != "play" and Game.state != "prep"):
		return
	if state == DOWN:
		if occupied():
			Game.banner.emit("BRUG", "Er staat nog iemand op de brug", 1.6)
			return
		state = RISING
		if anim:
			anim.play("Omhoog")
	else:
		state = LOWERING
		if anim:
			anim.play("Omlaag")
	Sfx.play("click")
	_apply()
	Game.changed.emit()


func _on_done(name: StringName) -> void:
	if name == &"Omhoog":
		state = UP
		Sfx.play("thud", 1.0, global_position)
	elif name == &"Omlaag":
		state = DOWN
		Sfx.play("thud", 1.0, global_position)
	_apply()
	Game.changed.emit()


func _apply() -> void:
	var down := state == DOWN
	_leaf_rails.process_mode = Node.PROCESS_MODE_INHERIT if down else Node.PROCESS_MODE_DISABLED
	for c in _leaf_rails.get_children():
		(c as CollisionShape3D).disabled = not down
	for c in _water.get_children():
		(c as CollisionShape3D).disabled = down
	if _lamp_g:
		_lamp_g.visible = down
	if _lamp_r:
		_lamp_r.visible = not down
