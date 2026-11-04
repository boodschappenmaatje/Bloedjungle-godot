class_name WallDiagnostics
extends RefCounted
## Alleen een visuele A/B-diagnose; verandert geen collisions, raycasts of gameplay.
## De camera roept dit na zijn normale muur-occlusiestap aan.
const MODES := ["normal", "no_wall", "no_berm", "no_shadow", "lod0", "lod1", "lod2"]

static func apply(tree: SceneTree, mode: String) -> void:
	if not MODES.has(mode):
		mode = "normal"
	var force_lod := mode.begins_with("lod")
	for node in tree.get_nodes_in_group("base_wall_visual"):
		var visual := node as MultiMeshInstance3D
		if visual == null:
			continue
		# Save authored ranges/links before any forced LOD test. Never touch mesh data.
		if not visual.has_meta("_wall_diag_visibility_parent"):
			visual.set_meta("_wall_diag_visibility_parent", visual.visibility_parent)
			visual.set_meta("_wall_diag_range_begin", visual.visibility_range_begin)
			visual.set_meta("_wall_diag_range_margin", visual.visibility_range_begin_margin)
		if force_lod:
			visual.visibility_parent = NodePath()
			visual.visibility_range_begin = 0.0
			visual.visibility_range_begin_margin = 0.0
			visual.visible = visual.name.ends_with("_Wall_LOD" + mode.substr(3))
		else:
			visual.visibility_parent = visual.get_meta("_wall_diag_visibility_parent")
			visual.visibility_range_begin = float(visual.get_meta("_wall_diag_range_begin"))
			visual.visibility_range_begin_margin = float(visual.get_meta("_wall_diag_range_margin"))
			# The camera just updated visible normally. Do not force it back on:
			# that would undo the real occlusion behavior we are investigating.
			if mode == "no_wall":
				visual.visible = false
	# Berm and shadow nodes are normally static; retain their original visibility.
	_set_auxiliary_visibility(tree, "base_wall_berm", mode != "no_berm")
	_set_auxiliary_visibility(tree, "base_wall_shadow", mode != "no_shadow")


static func _set_auxiliary_visibility(tree: SceneTree, group: String, enabled: bool) -> void:
	for node in tree.get_nodes_in_group(group):
		var visual := node as GeometryInstance3D
		if visual == null:
			continue
		# Avoid changing state in the normal gameplay path until a diagnostic
		# mode has actually touched this node.
		if not visual.has_meta("_wall_diag_original_visible"):
			if enabled:
				continue
			visual.set_meta("_wall_diag_original_visible", visual.visible)
		visual.visible = enabled and bool(visual.get_meta("_wall_diag_original_visible"))
