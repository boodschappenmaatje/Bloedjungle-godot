extends SceneTree
## Prints the imported Godot materials of the HQ2.3 airfield GLBs, so a missing albedo texture,
## missing mipmaps or emissive/unshaded surfaces are visible without a renderer.

const SCENES := [
	"res://assets/airfield_hq_v23/pavement/Airfield_Runway_Slab_HQ23_LOD0.glb",
	"res://assets/airfield_hq_v23/pavement/Airfield_Taxiway_HQ23_Compact_LOD0.glb",
	"res://assets/airfield_hq_v23/pavement/Airfield_Apron_Slab_HQ23_LOD0.glb",
	"res://assets/airfield_hq_v23/tower/Control_Tower_HQ_23.glb",
	"res://assets/airfield_hq_v23/hangar/Airfield_HQ_23_Compact_LOD0.glb",
	"res://assets/airfield_hq_v23/psp/PSP_plate_library.glb",
]

var problems := 0

func _initialize() -> void:
	for path in SCENES:
		var packed := load(path) as PackedScene
		if packed == null:
			print("MISSING ", path)
			problems += 1
			continue
		var root := packed.instantiate()
		var seen := {}
		print("== ", path.get_file())
		for node in root.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			if mi.mesh == null:
				continue
			for s in mi.mesh.get_surface_count():
				var m := mi.get_active_material(s) as BaseMaterial3D
				if m == null or seen.has(m):
					continue
				seen[m] = true
				var tex := m.albedo_texture
				var info := "albedo=%s tex=%s mip=%s nrm=%s rough=%.2f metal=%.2f emis=%s shading=%d" % [
					m.albedo_color.to_html(false), tex.resource_path.get_file() if tex else "-",
					str(tex.get_image().has_mipmaps()) if tex and tex.get_image() else "-",
					"y" if m.normal_enabled and m.normal_texture else "-", m.roughness, m.metallic,
					str(m.emission_enabled), m.shading_mode]
				print("  ", m.resource_name, " | ", info)
				if tex == null and m.albedo_color.v > 0.85 and m.albedo_color.a > 0.9 and not path.contains("PSP_plate_library"):
					print("    !! bright untextured albedo")
					problems += 1
				if tex and tex.get_image() and not tex.get_image().has_mipmaps():
					print("    !! albedo texture without mipmaps (moire/flicker at game distance)")
					problems += 1
		if path.contains("PSP_plate_library"):
			print("  note: PSP white source albedo is replaced at runtime by AirfieldPavementModules._psp_material")
		root.free()
	print("AIRFIELD MATERIAL PROBE problems=", problems)
	quit(1 if problems > 0 else 0)
