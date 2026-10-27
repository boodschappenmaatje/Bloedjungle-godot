class_name Generator
extends Node3D
## De dieselgenerator in de westhoek van de basis (assets/generator.glb, bron/generator). Hij levert de stroom: Game.power.
## Kapot schieten of opblazen: eerst rook, dan vuur, dan een explosie met schade in de buurt en een brandend wrak. Dan zijn alle lampen
## uit (zwaailampen bij de poorten, straatlantaarns). Repareren kan in de wapenkamer.

static var inst: Generator

const C := Data.COMPOUND
const POS := Vector3(-C + 1.8, 0.0, -10.0)
const YAW := -PI / 2.0         # voorkant (deuren, bedieningskast) kijkt naar het midden van de basis
const HP := 350.0
const COST := 400
const TAKE := {"bullet": 0.6, "melee": 0.5, "explosive": 1.0}
const BLAST_R := 7.0
const BLAST_DMG := 110.0
const LOOP := preload("res://assets/geluid/generator.wav")

var hp := HP
var down := false
var body: GeneratorBody
var model: Node3D
var wreck: Node3D
var _fx: Node3D
var _fan: AnimationPlayer
var _sound: AudioStreamPlayer3D
var _spawned := false
var _t := 0.0


func _enter_tree() -> void:
	inst = self


func _exit_tree() -> void:
	if inst == self:
		inst = null
		Game.power = true


func _process(delta: float) -> void:
	if not _spawned:
		if Game.state == "prep" or Game.state == "play":
			_spawned = true
			_spawn()
		return
	if down:
		return
	_t += delta
	# de motor trilt een heel klein beetje
	model.position.y = sin(_t * 94.0) * 0.0025
	model.rotation.z = sin(_t * 61.0) * 0.0012


func _spawn() -> void:
	var parent: Node = get_parent().get_node_or_null("Level")
	if parent == null:
		parent = get_parent()
	var scene := load("res://assets/generator.glb") as PackedScene
	model = _piece(scene, "Wrak")
	model.position = POS
	model.rotation.y = YAW
	parent.add_child(model)
	wreck = _piece(scene, "Generator")
	wreck.position = POS
	wreck.rotation.y = YAW
	wreck.visible = false
	parent.add_child(wreck)
	var gm: Node3D = wreck.find_child("Wrak", true, false)
	gm.position = Vector3.ZERO
	_fan = model.find_child("AnimationPlayer", true, false)
	_fan.get_animation("Draaien").loop_mode = Animation.LOOP_LINEAR
	_fan.play("Draaien")
	body = GeneratorBody.new()
	body.collision_layer = Kit.LAYER_WALL
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.9, 1.5, 1.3)
	cs.shape = bs
	cs.position = Vector3(0.0, 0.75, 0.0)
	body.add_child(cs)
	model.add_child(body)
	var st: AudioStreamWAV = LOOP.duplicate()
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = int(st.get_length() * st.mix_rate)
	_sound = AudioStreamPlayer3D.new()
	_sound.stream = st
	_sound.unit_size = 5.0
	_sound.max_distance = 45.0
	_sound.volume_db = -4.0
	_sound.position = Vector3(0, 0.8, 0)
	model.add_child(_sound)
	_sound.play()
	Game.power = true


## Een kopie van de glb zonder het onderdeel dat hier niet bij hoort.
static func _piece(scene: PackedScene, drop: String) -> Node3D:
	var root := Node3D.new()
	var m: Node3D = scene.instantiate()
	root.add_child(m)
	var other: Node = m.find_child(drop, true, false)
	if other:
		other.get_parent().remove_child(other)
		other.free()
	var keep: Node3D = m.find_child("Wrak" if drop == "Generator" else "Generator", true, false)
	if keep:
		keep.position = Vector3.ZERO
	return root


func mid() -> Vector3:
	return POS + Vector3.UP * 0.8


## Schade; kind: bullet, melee of explosive.
func damage(dmg: float, kind := "bullet") -> void:
	if (Game.state != "play" and Game.state != "prep") or dmg <= 0.0 or down or model == null:
		return
	var was := hp
	hp -= dmg * TAKE[kind]
	if randf() < 0.5:
		Fx.spark(self, mid() + Vector3(randf_range(-0.8, 0.8), 0.3, randf_range(-0.5, 0.5)), Vector3.UP)
	if hp < HP * 0.6 and was >= HP * 0.6:
		_fx = Fx.burning(self, mid() + Vector3.UP * 0.5, false)
		Game.banner.emit("GENERATOR BESCHADIGD", "", 1.2)
	if hp < HP * 0.3 and was >= HP * 0.3:
		if _fx != null and is_instance_valid(_fx):
			_fx.queue_free()
		_fx = Fx.burning(self, mid() + Vector3.UP * 0.5, true)
		_sound.pitch_scale = 0.82
	if hp <= 0.0:
		_break()


func _break() -> void:
	down = true
	hp = 0.0
	var at := mid()
	model.visible = false
	wreck.visible = true
	(body.get_child(0) as CollisionShape3D).disabled = true
	_sound.stop()
	_fan.stop()
	if _fx != null and is_instance_valid(_fx):
		_fx.queue_free()
	_fx = Fx.burning(self, at, true)
	Fx.explosion(self, at + Vector3.UP * 0.6, 1.5)
	Sfx.play("boom", 1.0, at)
	Game.note_blast(at, BLAST_R)
	Game.alert(at, 40.0, 6.0)
	Barrel.area_damage(at, BLAST_R, BLAST_DMG)
	Game.power = false
	Game.banner.emit("STROOMUITVAL", "De generator is kapot: alle lampen zijn uit. Repareer hem in de wapenkamer.", 3.0)


## Ontploffing op `at` met straal en schade (zoals Wachtpost.blast: vaten, granaten, raketten).
static func blast(at: Vector3, radius: float, dmg: float) -> void:
	if inst == null or inst.down or inst.model == null:
		return
	var d: float = maxf(0.0, Vector2(POS.x - at.x, POS.z - at.z).length() - 1.4)
	if d < radius:
		inst.damage(dmg * (1.0 - d / radius), "explosive")


func repair_cost() -> int:
	return COST if down else (COST / 3 if hp < HP else 0)


func repair() -> void:
	hp = HP
	if model == null:
		return
	model.visible = true
	wreck.visible = false
	(body.get_child(0) as CollisionShape3D).disabled = false
	if _fx != null and is_instance_valid(_fx):
		_fx.queue_free()
	_fx = null
	var was_down := down
	down = false
	_sound.pitch_scale = 1.0
	_sound.play()
	_fan.play("Draaien")
	Game.power = true
	if was_down:
		Game.banner.emit("STROOM HERSTELD", "", 1.6)
