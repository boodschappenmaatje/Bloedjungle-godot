extends SceneTree
func _initialize():
	var n = load("res://assets/auto.glb").instantiate()
	root.add_child(n)
	var ap: AnimationPlayer = n.find_child("AnimationPlayer", true, false)
	print(ap.get_animation_list())
	for c in n.get_children(): print(c.name, " ", c.get_class())
	var r = n.find_child("Romp", true, false)
	print(r.mesh.get_blend_shape_count(), " ", r.mesh.get_blend_shape_name(0) if r.mesh.get_blend_shape_count() else "", " surfaces ", r.mesh.get_surface_count())
	for i in r.mesh.get_surface_count(): print(i, r.mesh.surface_get_material(i).resource_name)
	for w in ["Wiel_LV","DeurRV","Motorkap"]:
		var x = n.find_child(w, true, false); print(w, x.position, x.get_parent().name)
	quit()
