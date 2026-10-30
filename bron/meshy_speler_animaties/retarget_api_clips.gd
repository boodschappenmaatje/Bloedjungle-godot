extends SceneTree
## Zet de Meshy-API-clips (bron/meshy_speler_animaties/bronnen/*.glb, 24-bot API-rig in centimeters)
## over op het bestaande 28-bot Mixamo-skelet van de speler (assets/meshy_jungle_commando.glb).
##
## Methode (globale rustpose-delta): G_doel(t) = G_bron(t) * G_bron_rust^-1 * G_doel_rust, daarna per bot
## teruggerekend naar lokale rotatie. Alleen Hips krijgt een positie-track (geschaald op heupenhoogte).
## Horizontale heupverplaatsing wordt lineair weggehaald (root motion), verticale blijft, zoals in
## docs/meshy_player_animation_library_3.7.md.
##
## Godot negeert bron/ (.gdignore): kopieer eerst bronnen/*.glb naar res://tmp_api_import/ en draai
## godot --headless --import && godot --headless -s bron/meshy_speler_animaties/retarget_api_clips.gd
## (tmp_api_import/ daarna weer weghalen, niet committen).
## Oude regel:
## Schrijft resources/animations/meshy_player_animation_library_api.res en een rapport in de console.

const TARGET := "res://assets/meshy_jungle_commando.glb"
const SOURCES := ["A_gevecht", "B_herladen_geraakt", "C_dood", "D_bewegen", "E_klimmen_zitten", "F_houdingen", "G_mes_val"]
const OUT := "res://resources/animations/meshy_player_animation_library_api.res"
const FPS := 30.0
const LOOPS := ["Combat_Stance", "Walk_Forward_While_Shooting", "Walk_Backward_While_Shooting", "Walk_Backward_with_Gun",
	"Walk_Left_with_Gun", "Slow_Walk_Reload", "Running_Reload", "Ladder_Climb_Loop", "Fast_Ladder_Climb", "Slow_Ladder_Climb",
	"climbing_up_wall", "Chair_Sit_Idle_F", "Chair_Sit_Idle_M", "Crawl_Backward", "Cautious_Crouch_Walk_Backward",
	"Cautious_Crouch_Walk_Left", "Walk_Backward_with_Grenade", "Stumble_Walk", "Crawl_and_Look_Back"]
const MAP := {  # doelbot -> bronbot
	"Hips": "Hips", "Spine": "Spine", "Spine1": "Spine01", "Spine2": "Spine02", "Neck": "neck", "Head": "Head",
	"LeftShoulder": "LeftShoulder", "LeftArm": "LeftArm", "LeftForeArm": "LeftForeArm", "LeftHand": "LeftHand",
	"RightShoulder": "RightShoulder", "RightArm": "RightArm", "RightForeArm": "RightForeArm", "RightHand": "RightHand",
	"LeftUpLeg": "LeftUpLeg", "LeftLeg": "LeftLeg", "LeftFoot": "LeftFoot", "LeftToeBase": "LeftToeBase",
	"RightUpLeg": "RightUpLeg", "RightLeg": "RightLeg", "RightFoot": "RightFoot", "RightToeBase": "RightToeBase",
}


func _init() -> void:
	var tscene: Node = (load(TARGET) as PackedScene).instantiate()
	get_root().add_child(tscene)
	var tsk: Skeleton3D = tscene.find_child("Skeleton3D", true, false)
	var t_rest := _global_rests(tsk)
	var t_rot := {}   # doelbot-index -> rust-globale rotatie
	for b in tsk.get_bone_count():
		t_rot[b] = t_rest[b].basis.get_rotation_quaternion()
	var tmap := {}    # doelbot-index -> naam in bron
	for b in tsk.get_bone_count():
		var n := tsk.get_bone_name(b).replace("mixamorig_", "")
		if MAP.has(n):
			tmap[b] = MAP[n]
	var lib := AnimationLibrary.new()
	var seen := {}
	for src_name in SOURCES:
		var path := "res://tmp_api_import/%s.glb" % src_name
		var sscene: Node = (load(path) as PackedScene).instantiate()
		get_root().add_child(sscene)
		var ssk: Skeleton3D = sscene.find_child("Skeleton3D", true, false)
		var sap: AnimationPlayer = sscene.find_child("AnimationPlayer", true, false)
		var s_rest := _global_rests(ssk, true)
		var sidx := {}
		for b in ssk.get_bone_count():
			sidx[ssk.get_bone_name(b)] = b
		var s_rot := {}
		for b in ssk.get_bone_count():
			s_rot[b] = s_rest[b].basis.get_rotation_quaternion()
		# heupenschaal: doel-heupenhoogte / bron-heupenhoogte (eenheden verschillen: m tegenover cm)
		var hips_s: int = sidx["Hips"]
		var hips_t: int = tsk.find_bone("mixamorig_Hips")
		var scale_pos: float = t_rest[hips_t].origin.y / maxf(s_rest[hips_s].origin.y, 0.0001)
		var s_hips_rest_local: Vector3 = ssk.get_bone_rest(hips_s).origin
		for aname in sap.get_animation_list():
			var clip_name := String(aname)
			if clip_name == "RESET" or seen.has(clip_name):
				continue
			seen[clip_name] = true
			var a: Animation = sap.get_animation(aname)
			var out := _retarget(a, aname, sap, ssk, tsk, sidx, tmap, t_rot, s_rot, s_rest, t_rest, scale_pos, s_hips_rest_local, hips_s)
			out.loop_mode = Animation.LOOP_LINEAR if clip_name in LOOPS else Animation.LOOP_NONE
			lib.add_animation(clip_name, out)
			print("CLIP %-34s %5.2fs  tracks=%d  loop=%s" % [clip_name, out.length, out.get_track_count(), clip_name in LOOPS])
		sscene.queue_free()
	var err := ResourceSaver.save(lib, OUT)
	print("OPGESLAGEN ", OUT, " clips=", lib.get_animation_list().size(), " fout=", err)
	quit(0)


## Globale rust per bot, relatief aan de scène-wortel (inclusief skeletonknoop-transform).
func _global_rests(sk: Skeleton3D, in_scene := false) -> Array[Transform3D]:
	var res: Array[Transform3D] = []
	var sk_xf: Transform3D = _rel_xf(sk) if in_scene else sk.transform
	res.resize(sk.get_bone_count())
	for b in sk.get_bone_count():
		var par := sk.get_bone_parent(b)
		var local := sk.get_bone_rest(b)
		res[b] = (res[par] * local) if par >= 0 else local
	for b in res.size():
		res[b] = Transform3D(sk_xf.basis * res[b].basis, sk_xf.basis * res[b].origin)
	return res


func _retarget(a: Animation, aname: StringName, sap: AnimationPlayer, ssk: Skeleton3D, tsk: Skeleton3D, sidx: Dictionary, tmap: Dictionary,
		t_rot: Dictionary, s_rot: Dictionary, s_rest: Array, t_rest: Array, scale_pos: float, s_hips_rest_local: Vector3, hips_s: int) -> Animation:
	var out := Animation.new()
	out.length = a.length
	var frames := int(ceil(a.length * FPS)) + 1
	var tracks := {}
	for tb in tmap:
		var tr := out.add_track(Animation.TYPE_ROTATION_3D)
		out.track_set_path(tr, NodePath("%s:%s" % [_skel_path(), tsk.get_bone_name(tb)]))
		tracks[tb] = tr
	var hips_t := tsk.find_bone("mixamorig_Hips")
	var hip_tr := out.add_track(Animation.TYPE_POSITION_3D)
	out.track_set_path(hip_tr, NodePath("%s:mixamorig_Hips" % _skel_path()))
	var s_xf: Transform3D = _rel_xf(ssk)
	var s_basis: Basis = s_xf.basis
	var hips_first := Vector3.ZERO
	var hips_samples: Array[Vector3] = []
	var rot_samples := {}
	for f in frames:
		var t := minf(a.length, float(f) / FPS)
		sap.play(aname)
		sap.seek(t, true)
		sap.pause()
		ssk.force_update_all_bone_transforms()
		# globale bronrotaties op tijd t
		var g_s := {}
		for b in ssk.get_bone_count():
			var par := ssk.get_bone_parent(b)
			var lq := ssk.get_bone_pose_rotation(b)
			g_s[b] = (g_s[par] * lq) if par >= 0 else lq
		# doelglobalen
		var g_t := {}
		for b in tsk.get_bone_count():
			var par := tsk.get_bone_parent(b)
			var par_g: Quaternion = g_t[par] if par >= 0 else Quaternion.IDENTITY
			var q_local: Quaternion
			if tmap.has(b):
				var sb: int = sidx[tmap[b]]
				var gs: Quaternion = s_basis.get_rotation_quaternion() * g_s[sb]
				# globale delta t.o.v. de bron-rust, op het doel-rust gezet
				var s_rest_q: Quaternion = s_rest[sb].basis.get_rotation_quaternion()
				var gt: Quaternion = gs * s_rest_q.inverse() * t_rot[b]
				q_local = par_g.inverse() * gt
				g_t[b] = gt
				rot_samples[[b, f]] = q_local
			else:
				q_local = tsk.get_bone_rest(b).basis.get_rotation_quaternion()
				g_t[b] = par_g * q_local
		hips_samples.append(ssk.get_bone_pose_position(hips_s))
	# rotatie-tracks schrijven
	for tb in tmap:
		for f in frames:
			var q: Quaternion = rot_samples[[tb, f]]
			out.rotation_track_insert_key(tracks[tb], minf(a.length, float(f) / FPS), q.normalized())
	# heuppositie: delta t.o.v. bron-rust, geschaald; horizontale drift lineair weg
	var start := hips_samples[0]
	var last := hips_samples[hips_samples.size() - 1]
	var t_hips_rest: Vector3 = tsk.get_bone_rest(hips_t).origin
	var first_h := Vector3(start.x, 0, start.z)
	var drift := Vector3(last.x - start.x, 0, last.z - start.z)
	for f in frames:
		var k := float(f) / float(frames - 1)
		var p := hips_samples[f]
		var d := Vector3(p.x, p.y, p.z) - Vector3(start.x, 0, start.z) - drift * k - Vector3(0, s_hips_rest_local.y, 0)
		# bronskeleton kan geroteerd zijn t.o.v. doel: breng naar scèneruimte en terug naar doel-skeletruimte
		var d_scene: Vector3 = s_basis * d
		out.position_track_insert_key(hip_tr, minf(a.length, float(f) / FPS), t_hips_rest + d_scene * scale_pos)
	return out


func _skel_path() -> String:
	return "target_character/Skeleton3D"


## Transform van een node t.o.v. de scèneroot (zonder de root zelf), zonder dat de node in de boom hoeft te zitten.
func _rel_xf(n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur is Node3D and cur.get_parent() != null and cur.get_parent() is Node3D:
		xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf
