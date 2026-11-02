extends Node3D
## Het hoofdkwartier (HK): het hart van de basis, uit assets/hoofdkwartier.glb (Blender-bron: bron/hoofdkwartier/).
## Het staat op de plek van de oude bunker en neemt zijn rol over (zelfde botsblok, zelfde basisgezondheid).
## Clips: Radar-loop (schotel draait), Open/Dicht (pantserdeur, opent als je terugkomt), Wapperen-loop (vlag).
## Godot doet: knipperend rood lampje, avondgloed van de lampen, camouflagenet als alfa-doek, schadelagen,
## niveau-onderdelen en de afstandsversie (LOD1).

const LOD_SWITCH := 45.0
const MODEL := "res://assets/hoofdkwartier.glb"
const MODEL_LOD := "res://assets/hoofdkwartier_lod1.glb"
const MODEL_SCALE := 0.92   # 5,0 m model op het 4,6 m botsblok van de bunker
## Vlag: een ster per niveau. Niveau 1 is het doek uit de glb, niveau 2 en 3 wisselen de albedo-textuur (gemaakt door de Blender-bron).
const FLAG_ALBEDO := {2: "res://assets/hoofdkwartier_vlag_s2_albedo_1024.jpg", 3: "res://assets/hoofdkwartier_vlag_s3_albedo_1024.jpg"}
const FLAG_ALBEDO_LOD := {2: "res://assets/hoofdkwartier_lod1_vlag_s2_albedo_512.jpg", 3: "res://assets/hoofdkwartier_lod1_vlag_s3_albedo_512.jpg"}

var model: Node
var model_lod: Node
var _red: Array[StandardMaterial3D] = []
var _amber: Array[StandardMaterial3D] = []
var _t := 0.0
var _night := false
var _door_anim: AnimationPlayer
var _levels_shown := -1
var _flags: Array = []   # [{mat, tex1, lod}]: doekmateriaal per model met zijn oorspronkelijke textuur (een ster)


func _ready() -> void:
	add_to_group("hq")
	scale = Vector3.ONE * MODEL_SCALE
	model = _load(MODEL, 0.0, LOD_SWITCH)
	model_lod = _load(MODEL_LOD, LOD_SWITCH, 0.0)
	_night = GameSettings.get_value("time") != "day"
	_apply_level(1)
	_apply_damage(1.0)
	var perks := HqPerks.new()   # radar en bouwtijd (niveau 2), dakgeweer en artillerie (niveau 3)
	perks.name = "Voordelen"
	add_child(perks)
	set_process(true)


func _load(path: String, range_begin: float, range_end: float) -> Node:
	var m: Node = (load(path) as PackedScene).instantiate()
	add_child(m)
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var g := mi as MeshInstance3D
		if String(g.name).begins_with("Icosphere"):
			g.visible = false   # losse bol zonder materiaal uit de Blender-export (zit toch binnen in het gebouw)
			continue
		g.visibility_range_begin = range_begin
		g.visibility_range_end = range_end
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var mat := g.get_active_material(0)
		if not (mat is StandardMaterial3D):
			continue
		var sm := mat as StandardMaterial3D
		match sm.resource_name:
			"Vlagdoek_olijf_goud":
				var cloth := sm.duplicate() as StandardMaterial3D
				g.material_override = cloth
				_flags.append({"mat": cloth, "tex1": cloth.albedo_texture, "lod": path == MODEL_LOD})
			"HK_Camonet":
				var own := sm.duplicate() as StandardMaterial3D
				own.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				own.alpha_scissor_threshold = 0.5
				own.cull_mode = BaseMaterial3D.CULL_DISABLED
				g.material_override = own
			"HK_Schade":
				var own2 := sm.duplicate() as StandardMaterial3D
				own2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				own2.cull_mode = BaseMaterial3D.CULL_DISABLED
				own2.no_depth_test = false
				g.material_override = own2
				g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			"HK_Lamp_rood":
				var r := sm.duplicate() as StandardMaterial3D
				r.emission_enabled = true
				g.material_override = r
				_red.append(r)
			"HK_Lamp_amber":
				var a := sm.duplicate() as StandardMaterial3D
				a.emission_enabled = true
				g.material_override = a
				_amber.append(a)
	var ap: AnimationPlayer = m.find_child("AnimationPlayer", true, false)
	if ap:
		# Eén AnimationPlayer speelt maar één clip tegelijk: radar en vlag krijgen elk een eigen speler (zelfde wortel),
		# de oorspronkelijke speler houdt de deur (Open en Dicht).
		_loop_player(m, ap, "RadarSpeler", ["Radar-loop", "Radar"])
		_loop_player(m, ap, "VlagSpeler", ["Wapperen-loop", "Wapperen"])
		if path == MODEL:
			_door_anim = ap
	return m


func _loop_player(m: Node, ap: AnimationPlayer, pname: String, names: Array) -> void:
	for n in names:
		if not ap.has_animation(n):
			continue
		var anim := ap.get_animation(n)
		anim.loop_mode = Animation.LOOP_LINEAR
		var p2 := AnimationPlayer.new()
		p2.name = pname
		m.add_child(p2)
		p2.root_node = ap.root_node
		var lib := AnimationLibrary.new()
		lib.add_animation(n, anim)
		p2.add_animation_library("", lib)
		p2.play(n)
		p2.seek(randf() * 2.0, true)
		return


func _process(delta: float) -> void:
	_t += delta
	var blink := 1.0 if fmod(_t, 1.6) < 0.25 else 0.08
	for r in _red:
		r.emission_energy_multiplier = blink * 3.0
	var amber := 3.0 if _night else 0.35
	for a in _amber:
		a.emission_energy_multiplier = amber
	var lvl: int = Game.hq_level
	if lvl != _levels_shown:
		_apply_level(lvl)
	var ratio: float = Game.base_hp / maxf(Game.base_max, 1.0)
	_apply_damage(ratio)


func _apply_level(lvl: int) -> void:
	_levels_shown = lvl
	for f in _flags:
		var mat := f["mat"] as StandardMaterial3D
		var files: Dictionary = FLAG_ALBEDO_LOD if f["lod"] else FLAG_ALBEDO
		if lvl >= 2 and files.has(mini(lvl, 3)) and ResourceLoader.exists(files[mini(lvl, 3)]):
			mat.albedo_texture = load(files[mini(lvl, 3)]) as Texture2D
		else:
			mat.albedo_texture = f["tex1"] as Texture2D
	for m in [model, model_lod]:
		if m == null:
			continue
		for pair in [["Niveau2", lvl >= 2], ["Niveau3", lvl >= 3]]:
			var n := m.find_child(pair[0], true, false) as Node3D
			if n:
				n.visible = pair[1]


var _dmg_shown := -1


func _apply_damage(ratio: float) -> void:
	var stage := 0 if ratio > 0.6 else (1 if ratio > 0.3 else 2)
	if stage == _dmg_shown:
		return
	_dmg_shown = stage
	for m in [model, model_lod]:
		if m == null:
			continue
		var s1 := m.find_child("Schade1", true, false) as Node3D
		var s2 := m.find_child("Schade2", true, false) as Node3D
		if s1:
			s1.visible = stage >= 1
		if s2:
			s2.visible = stage >= 2


## De pantserdeur gaat open als je terugkomt na sneuvelen en sluit weer.
func open_door() -> void:
	if _door_anim == null or not _door_anim.has_animation("Open"):
		return
	_door_anim.play("Open")
	await get_tree().create_timer(2.4).timeout
	if is_instance_valid(_door_anim) and _door_anim.has_animation("Dicht"):
		_door_anim.play("Dicht")
