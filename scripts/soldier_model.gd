class_name SoldierModel
extends Node3D
## Het geanimeerde mannetje (VQ2: realistisch lichaam uit assets/soldaat_vq2.glb; v1: Quaternius-pop uit assets/soldaat.glb,
## beide met de Mixamo-geweeranimaties), gebruikt door de speler, bondgenoten en vijanden. Kleurt het uniform en hangt een
## wapen in de rechterhand.

const SCENE := preload("res://assets/soldaat.glb")
## VQ2-mannetje (bron/soldaat_vq2): realistisch MakeHuman-lichaam op hetzelfde DEF-skelet met dezelfde clips, vier
## lichaamsvarianten en uitrusting per type. Instelling "soldaat" = "v1" valt terug op het oude model.
const SCENE_V2 := preload("res://assets/soldaat_vq2.glb")
## Player-only Showcase variant: Tiger Stripe + compact commando equipment; shared VQ2 stays unchanged for allies/enemies.
const SCENE_PLAYER := preload("res://assets/soldaat_jungle_commando.glb")
## Experimental player-only Meshy/Mixamo rig from the isolated, already-reviewed lab.
## The file is byte-identical to the user-supplied remesh/rig export; NPCs never select it.
const SCENE_MESHY_PLAYER_PATH := "res://assets/meshy_jungle_commando.glb"
## Mesh-free shared animation source extracted from the supplied same-rig library.
const MESHY_ANIMATION_LIBRARY := preload("res://resources/animations/meshy_player_animation_library.res")
const MESHY_API_LIBRARY := preload("res://resources/animations/meshy_player_animation_library_api.res")   # 62 clips uit de Meshy-API, zie bron/meshy_speler_animaties
## Namen die het spel al aanroept -> Meshy-API-clip. Zonder deze tabel blijft de Meshy-speler bij die acties stilstaan.
const MESHY_ALIASES := {
	"achteruit": "Walk_Backward_with_Gun", "geraakt": "Hit_Reaction", "dood1": "Shot_and_Fall_Backward",
	"dood2": "Shot_and_Fall_Forward", "explosie_dood": "Shot_and_Blown_Back", "rollen": "Roll_Dodge",
	"klimmen": "Fast_Ladder_Climb", "zitten": "Chair_Sit_Idle_M", "steken": "Attack", "brand_val": "falling_down",
	"brand_rennen": "Stumble_Walk",
}
## Alleen in deze clips houdt de Meshy-speler het geweer vast (IK aan, wapen zichtbaar); in de andere (rollen, vallen,
## klimmen, zitten, mes) zou het wapen los van het lichaam blijven hangen.
const MESHY_HOLD := ["stil", "lopen", "rennen", "sprinten", "achteruit", "schieten"]
const MESHY_GARAND_PROFILE = preload("res://resources/weapon_profiles/garand_meshy.tres")
const MESHY_WEAPON_ADAPTER_SCRIPT := preload("res://scripts/weapon_model_adapter.gd")
const LOOKS := {
	"eigen": ["Lijf_Uniform", "Helm", "Vest", "Koppel", "Rugzak", "Laarzen"],
	"speler:jungle": ["Lijf_JungleCommando", "Uniform_Jacket_Shell", "Uniform_Trousers_Shell", "Hair_Cropped",
		"Vest_JungleCommando", "Vest_JungleCommando_Back", "Vest_JungleCommando_Details", "Koppel", "Laarzen", "Mag_Pouches", "Radio_Field", "IFAK_Pouch",
		"Gloves_Closed", "Knee_Reinforcements", "Elbow_Reinforcements"],
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
const LOCOMOTION := ["lopen", "rennen", "achteruit"]
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
var _gun_anim: AnimationPlayer   # echte GLB-clips van de bewegende wapendelen (slede, hendel, pomp), zie bron/wapens
var v2 := false
var meshy_player := false
var look := ""
var _uniform := Color.WHITE
var _mesh_skeleton: Skeleton3D
var _mesh_right_ik: SkeletonIK3D
var _mesh_left_ik: SkeletonIK3D
var _mesh_armed := true
var _mesh_right_target: Marker3D
var _mesh_weapon_adapter: Variant
var _mesh_action_player: AnimationPlayer
var _mesh_animation_tree: AnimationTree
var _mesh_animation_playback: AnimationNodeStateMachinePlayback
var _mesh_clip_map: Dictionary = {}


## uniform = kleur van het uniform; look = sleutel uit LOOKS ("eigen" voor bondgenoten en wachten,
## "speler:<bovenlijf>" voor de speler, "vijand:<type>" voor vijanden).
func setup(uniform: Color, gun_kind := "rifle", look_ := "eigen") -> void:
	meshy_player = GameSettings.get_value("soldaat") == "meshy" and look_.begins_with("speler:")
	v2 = GameSettings.get_value("soldaat") != "v1"
	look = look_ if LOOKS.has(look_) else "eigen"
	_uniform = uniform
	var model_scene: PackedScene
	if meshy_player:
		model_scene = ResourceLoader.load(SCENE_MESHY_PLAYER_PATH) as PackedScene
		if model_scene == null:
			push_error("Meshy player GLB did not import as a PackedScene")
			return
	else:
		model_scene = SCENE if not v2 else (SCENE_PLAYER if look.begins_with("speler:") else SCENE_V2)
	var model := model_scene.instantiate()
	add_child(model)
	anim = model.find_child("AnimationPlayer", true, false)
	if meshy_player:
		_model = model
		_setup_meshy_player(uniform, gun_kind)
		play("stil")
		SoldierMark.attach(self)
		return
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
		_setup_pose()
		play("stil")
		SoldierMark.attach(self)
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
	SoldierMark.attach(self)


var _parts := {}   # naam -> MeshInstance3D (VQ2)
var pose: SoldierPose   # benen los van de romp draaien, treffers per richting en wapen vasthouden (alleen VQ2)
var _palm_r := Vector3.ZERO   # midden van de rechterhandpalm in de ruimte van DEF-handR
const HOLD_CLIPS := ["stil", "lopen", "rennen", "schieten", "geraakt"]   # hierin houdt hij het wapen met beide handen vast


## Geeft SoldierPose het wapen en de stand van de wapenknoop in de hand door.
func _sync_hold() -> void:
	if pose == null:
		return
	pose.gun_n = _gun.transform if _gun != null else Transform3D.IDENTITY
	pose.weapon = String(GUN_OF.get(_weapon_kind, "")).to_lower() if _gun != null else ""
	pose.hold = current in HOLD_CLIPS


func _setup_pose() -> void:
	var skel: Skeleton3D = _model.find_children("*", "Skeleton3D", true, false)[0]
	pose = SoldierPose.new()
	pose.name = "SoldierPose"
	skel.add_child(pose)
	pose.setup_skeleton(skel)
	_palm_r = pose.palm_offset("R")
	pose.palm_l = pose.palm_offset("L")
	if look == "speler:jungle":
		# The source Garand foregrip is beyond this rig's two-bone left-arm reach
		# during locomotion. Bring the player support hand to the receiver; other
		# soldier looks retain their shared weapon-specific grip table.
		pose.left_hold_overrides["garand"] = Vector3(-0.12, 0.08, 0.0)
	if _gun != null:   # het wapen hing al in de hand: zet het op de handpalm
		_gun.transform.origin += _palm_r
	_sync_hold()


## Draaiing van de benen t.o.v. de romp (radialen, + = naar rechts van het gezicht). 0 = benen kijken mee met de romp.
func set_leg_yaw(yaw: float) -> void:
	if pose != null:
		pose.leg_yaw = yaw


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


## Meshy-player-only setup: keep the Mixamo skeleton and the shared gameplay-facing SoldierModel API.
## This path does not touch the 53-bone DEF model used by allies, enemies, or the fallback player.
func _setup_meshy_player(uniform: Color, gun_kind: String) -> void:
	var skels := _model.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty() or anim == null:
		push_error("Meshy player GLB has no Skeleton3D or AnimationPlayer")
		return
	var skel := skels[0] as Skeleton3D
	_mesh_skeleton = skel
	var required := ["mixamorig_RightShoulder", "mixamorig_RightArm", "mixamorig_RightForeArm", "mixamorig_RightHand",
		"mixamorig_LeftShoulder", "mixamorig_LeftArm", "mixamorig_LeftForeArm", "mixamorig_LeftHand"]
	for bone in required:
		if skel.find_bone(bone) < 0:
			push_error("Meshy player rig is missing expected Mixamo bone: " + bone)
			return
	# Duplicate the centrally extracted animation-only resource per player instance. The
	# original GLB remains untouched and its mesh/skin are not duplicated into the library.
	var old_lib := anim.get_animation_library("")
	var lib := MESHY_ANIMATION_LIBRARY.duplicate(true) as AnimationLibrary
	if old_lib != null:
		for old_name in old_lib.get_animation_list():
			if not lib.has_animation(old_name):
				lib.add_animation(old_name, old_lib.get_animation(old_name).duplicate(true))
		anim.remove_animation_library("")
	anim.add_animation_library("", lib)
	for api_clip in MESHY_API_LIBRARY.get_animation_list():
		if not lib.has_animation(api_clip):
			lib.add_animation(api_clip, MESHY_API_LIBRARY.get_animation(api_clip))
	for alias in MESHY_ALIASES:
		_alias_meshy_clip(lib, alias, MESHY_ALIASES[alias])
	_alias_meshy_clip(lib, "stil", "Idle")
	_alias_meshy_clip(lib, "lopen", "Walking")
	_alias_meshy_clip(lib, "rennen", "Running")
	_alias_meshy_clip(lib, "sprinten", "RunFast")
	for clip in ["lopen", "rennen", "sprinten"]:
		lib.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	if not lib.has_animation("Idle"):
		_add_meshy_idle(lib, skel)
	if not lib.has_animation("stil"):
		_alias_meshy_clip(lib, "stil", "Idle")
	_build_meshy_animation_tree(lib)
	for mi: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		if mi.name == "Icosphere":
			mi.hide()
	_attach_gun_meshy(skel, gun_kind)
	_setup_meshy_weapon_ik(skel)
	_setup_meshy_actions()
	set_uniform(uniform)


## Godot 4.7's imported clips are routed through three explicit posture states. Each
## state's 1D blend space contains only real supplied clips; absent idles/transitions
## are intentionally not synthesized or connected to gameplay controls.
func _build_meshy_animation_tree(lib: AnimationLibrary) -> void:
	var machine := AnimationNodeStateMachine.new()
	_mesh_clip_map.clear()
	var posture_clips := {
		"STAND": ["stil", "lopen", "rennen", "sprinten", "Rifle_Aim_Turn_Right", "Rifle_Charge_inplace", "Run_and_Shoot", "Stand_Up2", "Hit_in_Back_While_Running", "dying_backwards"],
		"CROUCH": ["Cautious_Crouch_Walk_Forward", "Cautious_Crouch_Walk_Right_inplace", "Crouch_Walk_Left_with_Gun"],
		"PRONE": ["Prone_Reload"],
	}
	for posture in posture_clips:
		var blend_space := AnimationNodeBlendSpace1D.new()
		blend_space.min_space = 0.0
		blend_space.max_space = float(posture_clips[posture].size() - 1)
		blend_space.snap = 1.0
		for index in posture_clips[posture].size():
			var clip_name: String = posture_clips[posture][index]
			if not lib.has_animation(clip_name):
				continue
			var clip_node := AnimationNodeAnimation.new()
			clip_node.animation = clip_name
			clip_node.resource_name = clip_name
			blend_space.add_blend_point(clip_node, float(index), -1, clip_name)
			_mesh_clip_map[clip_name] = {"posture": posture, "position": float(index)}
			if posture == "STAND" and clip_name in ["stil", "lopen", "rennen", "sprinten"]:
				_mesh_clip_map[{"stil": "Idle", "lopen": "Walking", "rennen": "Running", "sprinten": "RunFast"}[clip_name]] = _mesh_clip_map[clip_name]
		machine.add_node(posture, blend_space, Vector2.ZERO)
	var stand_to_crouch := AnimationNodeStateMachineTransition.new()
	stand_to_crouch.xfade_time = 0.22
	machine.add_transition("STAND", "CROUCH", stand_to_crouch)
	var crouch_to_stand := AnimationNodeStateMachineTransition.new()
	crouch_to_stand.xfade_time = 0.22
	machine.add_transition("CROUCH", "STAND", crouch_to_stand)
	var crouch_to_prone := AnimationNodeStateMachineTransition.new()
	crouch_to_prone.xfade_time = 0.22
	machine.add_transition("CROUCH", "PRONE", crouch_to_prone)
	var prone_to_crouch := AnimationNodeStateMachineTransition.new()
	prone_to_crouch.xfade_time = 0.22
	machine.add_transition("PRONE", "CROUCH", prone_to_crouch)
	var stand_to_prone := AnimationNodeStateMachineTransition.new()
	stand_to_prone.xfade_time = 0.22
	machine.add_transition("STAND", "PRONE", stand_to_prone)
	var prone_to_stand := AnimationNodeStateMachineTransition.new()
	prone_to_stand.xfade_time = 0.22
	machine.add_transition("PRONE", "STAND", prone_to_stand)
	_mesh_animation_tree = AnimationTree.new()
	_mesh_animation_tree.name = "MeshyAnimationTree"
	_mesh_animation_tree.tree_root = machine
	_mesh_animation_tree.root_node = NodePath("..")
	_model.add_child(_mesh_animation_tree)
	_mesh_animation_tree.anim_player = _mesh_animation_tree.get_path_to(anim)
	_mesh_animation_tree.active = true
	_mesh_animation_playback = _mesh_animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	_mesh_animation_playback.start("STAND")
	_mesh_animation_tree.set("parameters/STAND/blend_position", 0.0)


## Explicit clip review hook used by the isolated animation-library test/preview.
## It selects only clips in the supplied library and never invents stance content.
func play_meshy_library_clip(clip_name: String, speed := 1.0) -> bool:
	if not meshy_player or _mesh_animation_tree == null or not _mesh_clip_map.has(clip_name):
		return false
	var selection: Dictionary = _mesh_clip_map[clip_name]
	_mesh_animation_tree.active = true
	_mesh_animation_tree.set("parameters/%s/blend_position" % selection.posture, selection.position)
	_mesh_animation_playback.travel(selection.posture)
	anim.speed_scale = speed
	current = clip_name
	return true


func _attach_gun_meshy(skel: Skeleton3D, gun_kind: String) -> void:
	var actor := get_parent() as Node3D
	if actor == null:
		push_error("Meshy weapon adapter requires the existing player body as its parent")
		return
	_mesh_weapon_adapter = MESHY_WEAPON_ADAPTER_SCRIPT.new()
	_mesh_weapon_adapter.name = "WeaponModelAdapter"
	actor.add_child(_mesh_weapon_adapter)
	var visual_name: String = GUN_OF.get(gun_kind, "Garand")
	var profile: Resource = MESHY_GARAND_PROFILE if visual_name == "Garand" else null
	if not _mesh_weapon_adapter.configure(visual_name, profile):
		_mesh_weapon_adapter.queue_free()
		_mesh_weapon_adapter = null
		push_error("WeaponModelAdapter could not load visual: " + visual_name)
		return
	_gun = _mesh_weapon_adapter.weapon
	_weapon_mount = _mesh_weapon_adapter
	_gun_anim = _mesh_weapon_adapter.animation_player
	_weapon_kind = gun_kind
	if _mesh_right_target == null:
		_mesh_right_target = Marker3D.new()
		_mesh_right_target.name = "MeshyRightHandGripTarget"
		actor.add_child(_mesh_right_target)
	_mesh_right_target.position = _mesh_weapon_adapter.profile.mount_position
	if _mesh_right_ik == null:
		_mesh_right_ik = _make_meshy_arm_ik(skel, "MeshyRightArmIK", "mixamorig_RightShoulder", "mixamorig_RightHand", _mesh_right_target)
	if _mesh_left_ik == null:
		_mesh_left_ik = _make_meshy_arm_ik(skel, "MeshyLeftArmIK", "mixamorig_LeftShoulder", "mixamorig_LeftHand", _mesh_weapon_adapter.left_hand_grip)
	else:
		_mesh_left_ik.target_node = _mesh_left_ik.get_path_to(_mesh_weapon_adapter.left_hand_grip)
	_setup_meshy_actions()
	_recoil = 0.0


func _make_meshy_arm_ik(skel: Skeleton3D, ik_name: String, root_bone: String, tip_bone: String, target: Node3D) -> SkeletonIK3D:
	var ik := SkeletonIK3D.new()
	ik.name = ik_name
	ik.root_bone = root_bone
	ik.tip_bone = tip_bone
	ik.min_distance = 0.01
	ik.max_iterations = 32
	skel.add_child(ik)
	ik.target_node = ik.get_path_to(target)
	ik.start()
	return ik


func _setup_meshy_weapon_ik(skel: Skeleton3D) -> void:
	# _attach_gun_meshy created and started both chains after the actor entered the tree.
	if _mesh_right_ik == null or _mesh_left_ik == null:
		push_error("Meshy rig could not establish both arm IK chains")
	return


func _setup_meshy_actions() -> void:
	if _mesh_action_player != null:
		_mesh_action_player.free()
		_mesh_action_player = null
	if _mesh_weapon_adapter == null or _mesh_weapon_adapter.profile == null:
		return
	var actor := get_parent() as Node3D
	_mesh_action_player = AnimationPlayer.new()
	_mesh_action_player.name = "MeshyWeaponActions"
	_mesh_action_player.root_node = NodePath("..")
	actor.add_child(_mesh_action_player)
	var lib := AnimationLibrary.new()
	var reload := Animation.new()
	reload.resource_name = "herladen"
	reload.length = 1.5
	reload.loop_mode = Animation.LOOP_NONE
	var track := reload.add_track(Animation.TYPE_POSITION_3D)
	reload.track_set_path(track, NodePath("WeaponModelAdapter/%s/LeftHandGrip:position" % _mesh_weapon_adapter.weapon.name))
	var grip: Vector3 = _mesh_weapon_adapter.profile.left_hand_grip
	var mag: Vector3 = _mesh_weapon_adapter.profile.magazine_local
	for key in [[0.0, grip], [0.30, mag], [0.78, mag], [1.5, grip]]:
		reload.track_insert_key(track, key[0], key[1])
	lib.add_animation("herladen", reload)
	_mesh_action_player.add_animation_library("", lib)


func _set_gun_meshy(kind: String) -> void:
	if _mesh_weapon_adapter != null:
		_mesh_weapon_adapter.free()
		_mesh_weapon_adapter = null
	if _mesh_action_player != null:
		_mesh_action_player.free()
		_mesh_action_player = null
	_weapon_kind = kind
	if _mesh_skeleton != null:
		_attach_gun_meshy(_mesh_skeleton, kind)


func _alias_meshy_clip(lib: AnimationLibrary, alias: String, source: String) -> void:
	if lib.has_animation(alias) or not lib.has_animation(source):
		return
	lib.add_animation(alias, lib.get_animation(source))


func _add_meshy_idle(lib: AnimationLibrary, skel: Skeleton3D) -> void:
	var idle := Animation.new()
	idle.resource_name = "Idle"
	idle.length = 2.4
	idle.loop_mode = Animation.LOOP_LINEAR
	for bone in ["mixamorig_Spine2", "mixamorig_Neck", "mixamorig_Head"]:
		var index := skel.find_bone(bone)
		if index < 0:
			continue
		var track := idle.add_track(Animation.TYPE_ROTATION_3D)
		idle.track_set_path(track, NodePath("target_character/Skeleton3D:" + bone))
		var rest := skel.get_bone_pose_rotation(index)
		var swing := deg_to_rad(0.8 if bone == "mixamorig_Spine2" else 0.25)
		idle.track_insert_key(track, 0.0, rest)
		idle.track_insert_key(track, idle.length * 0.5, rest * Quaternion(Vector3.RIGHT, swing))
		idle.track_insert_key(track, idle.length, rest)
	lib.add_animation("Idle", idle)


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


## Alleen de duw van de treffer op romp en hoofd (VQ2), zonder de schiet- of trefferhouding van de armen te overschrijven.
func flinch(dir: Vector3, strength := 1.0) -> void:
	if pose != null:
		pose.kick(dir, strength)


## Korte bovenlichaamshouding bij een treffer; de AI en de loopanimatie blijven doorlopen.
func hit_reaction(dir: Vector3, strength := 1.0) -> void:
	if pose != null:
		pose.kick(dir, strength)
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
			if nm == "JungleCommando_Camo":
				# Keep the approved default Tiger Stripe palette; other existing camo choices still tint it.
				_mats[i].albedo_color = Color.WHITE if c == Color("4b5a2c") else uniform_tint(c)
			elif nm.ends_with("_Kleding"):
				_mats[i].albedo_color = uniform_tint(c)
			elif nm == "Commando Hair · Short Dark Brown":
				# Keep the GLB's dark baseColorFactor. Whitening every non-camouflage material
				# erased this factor and made the cropped hair appear pale in the actual game.
				_mats[i].albedo_color = Color(0.012, 0.007, 0.005, 1.0)
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
	if meshy_player:
		_set_gun_meshy(kind)
		return
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
	_gun_anim = _gun_player(holder, node, GUN_OF[kind])
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
	if pose != null:
		node.transform.origin += _palm_r
		_sync_hold()
	_recoil = 0.0


## Zet de clips van één wapen ("<wapen>_schot", "<wapen>_leeg") in een eigen speler op het wapen. De paden in het GLB
## beginnen bij de scènewortel; hier loopt de speler vanaf het wapen zelf, dus het voorvoegsel valt weg.
func _gun_player(holder: Node, gun: Node3D, gun_name: String) -> AnimationPlayer:
	var src := holder.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if src == null:
		return null
	var lib := AnimationLibrary.new()
	for clip in src.get_animation_list():
		if not String(clip).begins_with(gun_name + "_"):
			continue
		var a := src.get_animation(clip).duplicate() as Animation
		for t in range(a.get_track_count() - 1, -1, -1):   # de clip bevat ook de (stilstaande) delen van de andere wapens
			var path := String(a.track_get_path(t))
			if path.begins_with(gun_name + "/"):
				a.track_set_path(t, NodePath(path.substr(gun_name.length() + 1)))
			elif path.begins_with(gun_name + "_") or path == gun_name:
				pass
			else:
				a.remove_track(t)
		a.loop_mode = Animation.LOOP_NONE
		lib.add_animation(String(clip).trim_prefix(gun_name + "_"), a)
	if lib.get_animation_list().is_empty():
		return null
	var player := AnimationPlayer.new()
	player.name = "WapenClips"
	gun.add_child(player)
	player.root_node = NodePath("..")
	player.add_animation_library("", lib)
	return player


## Speelt een wapenclip: bij een schot schuift de slede, hendel of pomp mee; "leeg" laat de slede open staan.
func _gun_clip(clip: String) -> void:
	if _gun_anim != null and _gun_anim.has_animation(clip):
		_gun_anim.play(clip)


## Brengt de wapendelen terug in rust (na het herladen).
func gun_reset() -> void:
	if _gun_anim != null and _gun_anim.has_animation("schot"):
		_gun_anim.play("schot")
		_gun_anim.seek(0.0, true)
		_gun_anim.pause()


## Terugslag wordt in een eigen wapenhouder gedempt, zonder de loop- of richtbesturing te veranderen.
func shoot_recoil(kind: String, empty := false) -> void:
	if not _weapon_mount:
		return
	var profile: Dictionary = Data.WEAPON_VISUALS.get(kind, Data.WEAPON_VISUALS["m1911"])
	_recoil = minf(1.35, _recoil + float(profile.get("recoil", 0.6)))
	_weapon_kind = kind
	_gun_clip("leeg" if empty and _gun_anim != null and _gun_anim.has_animation("leeg") else "schot")


## Loopmonding berekend uit de echte meshgrenzen van het gekozen GLB-wapen.
func muzzle_position() -> Vector3:
	if _mesh_weapon_adapter != null and _mesh_weapon_adapter.muzzle != null:
		return _mesh_weapon_adapter.muzzle.global_position
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
	if _mesh_weapon_adapter != null and _mesh_weapon_adapter.casing_eject != null:
		return _mesh_weapon_adapter.casing_eject.global_position
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
	if _mesh_weapon_adapter != null:
		return [_mesh_weapon_adapter.global_transform.basis.x.normalized(), -_mesh_weapon_adapter.global_transform.basis.z.normalized()]
	if _gun == null:
		return [global_transform.basis.x.normalized(), -global_transform.basis.z.normalized()]
	return [_gun.global_transform.basis.x.normalized(), -_gun.global_transform.basis.z.normalized()]


const GUN_FWD := {"bazooka": 0.0}
# wapens op echte grootte; de camera staat dichter op het mannetje
const GUN_SCALE := {}


## Speelt een animatie met een zachte overgang; doet niets als hij al speelt.
func play(clip: String, blend := 0.18, speed := 1.0) -> void:
	if meshy_player:
		_play_meshy_clip(clip, blend, speed)
		return
	if current == clip or not anim.has_animation(clip):
		if current == clip:
			anim.speed_scale = speed
		return
	current = clip
	if pose != null:
		if not clip in LOCOMOTION:
			pose.leg_yaw = 0.0   # alleen bij lopen draaien de benen los van de romp
		pose.hold = clip in HOLD_CLIPS
	anim.play(clip, blend)
	anim.speed_scale = speed


func _play_meshy_clip(clip: String, blend: float, speed: float) -> void:
	if anim == null:
		return
	if speed < 0.0 and clip == "lopen" and anim.has_animation("achteruit"):
		clip = "achteruit"   # de lus achterstevoren afspelen is niet meer nodig
		speed = -speed
	if clip == "herladen":
		if current != clip:
			current = clip
			play_meshy_library_clip("stil", speed)
			current = clip
			if _mesh_action_player != null and _mesh_action_player.has_animation("herladen"):
				_mesh_action_player.play("herladen", 0.08)
		if _mesh_action_player != null:
			_mesh_action_player.speed_scale = speed
		return
	if current == clip:
		anim.speed_scale = speed
		return
	if _mesh_action_player != null and _mesh_action_player.is_playing():
		_mesh_action_player.stop()
		if _mesh_weapon_adapter != null:
			_mesh_weapon_adapter.left_hand_grip.position = _mesh_weapon_adapter.profile.left_hand_grip
	# Spelacties spelen rechtstreeks op de AnimationPlayer: de AnimationTree negeert speed_scale (loopsnelheid,
	# koprol-duur) en kan een eenmalige clip niet opnieuw starten. De tree blijft alleen voor de clip-review.
	if not anim.has_animation(clip):
		return
	if _mesh_animation_tree != null:
		_mesh_animation_tree.active = false
	_set_meshy_armed(clip in MESHY_HOLD)
	current = clip
	anim.play(clip, blend)
	anim.speed_scale = speed


## Geweer vasthouden: beide arm-IK-ketens aan en het wapen zichtbaar, of allebei uit.
func _set_meshy_armed(armed: bool) -> void:
	if _mesh_right_ik == null or _mesh_left_ik == null or armed == _mesh_armed:
		return
	_mesh_armed = armed
	if armed:
		_mesh_right_ik.start()
		_mesh_left_ik.start()
	else:
		_mesh_right_ik.stop()
		_mesh_left_ik.stop()
	if _mesh_weapon_adapter != null:
		_mesh_weapon_adapter.visible = armed


## Lengte van een animatie in seconden (0 als hij niet bestaat); handig om een clip precies op een duur te laten passen.
func clip_length(clip: String) -> float:
	return anim.get_animation(clip).length if anim != null and anim.has_animation(clip) else 0.0


## Korte kleurflits bij een treffer; de kleur kan per doeltype verschillen.
func flash(color := Color(0.9, 0.1, 0.05)) -> void:
	_flash = 0.1
	_flash_color = color


func _process(delta: float) -> void:
	if pose != null:
		pose.recoil = _recoil
	if _recoil > 0.0:
		_recoil = maxf(0.0, _recoil - delta * 5.5)
	if _mesh_weapon_adapter != null and _mesh_weapon_adapter.profile != null:
		_mesh_weapon_adapter.position = _mesh_weapon_adapter.profile.mount_position + Vector3(0.0, 0.0, -_recoil * 0.06)
		_mesh_weapon_adapter.rotation = _mesh_weapon_adapter.profile.mount_rotation + Vector3(-_recoil * 0.2, 0.0, 0.0)
	elif _recoil > 0.0 and _weapon_mount:
		_weapon_mount.position = Vector3(0.0, 0.0, -_recoil * 0.06)
		_weapon_mount.rotation.x = -_recoil * 0.2
	if _hit_pose_time > 0.0:
		_hit_pose_time = maxf(0.0, _hit_pose_time - delta)
		if _hit_pose_time <= 0.0:
			_model.rotation.y = 0.0
			_update_shoot_pose()
	if _flash > 0.0:
		_flash -= delta
		for i in _mats.size():
			_mats[i].albedo_color = _flash_color if _flash > 0.0 else _base_cols[i]
