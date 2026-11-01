extends SceneTree
## Zware bestanden (modellen, texturen, geluid) mogen niet vroeg geladen worden: de OTA-keten met die bestanden wordt pas
## aangekoppeld nadat de autoload-scripts gecompileerd zijn. Een preload("res://assets/...") (of een preload van een scène/resource
## die zo'n bestand nodig heeft) in een script dat Game of Sfx bij het compileren ophaalt, maakt die scripts dan stuk en de speler
## onzichtbaar. Gebruik load() op het moment dat het nodig is. Zie ota/README.md.
## godot --headless --path . -s tests/ota_vroeg_test.gd

const ZWARE_MAPPEN := ["res://assets/", "res://source_assets/", "res://previews/"]
const ZWARE_EXT := ["glb", "gltf", "png", "jpg", "jpeg", "webp", "wav", "mp3", "ogg", "exr", "hdr", "tga", "blend"]
const RESOURCE_EXT := ["tscn", "scn", "tres", "res"]

var fails := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		printerr("FOUT: ", msg)


func _zwaar(pad: String) -> bool:
	if pad.get_extension().to_lower() not in ZWARE_EXT:
		return false
	for m in ZWARE_MAPPEN:
		if pad.begins_with(m):
			return true
	return false


## Alle bestanden waar `pad` (recursief) van afhangt, behalve scripts (die staan al in de vroege lijst).
func _afhankelijk(pad: String, gezien: Dictionary, uit: Array) -> void:
	if gezien.has(pad) or pad.get_extension().to_lower() not in RESOURCE_EXT:
		return
	gezien[pad] = true
	for d in ResourceLoader.get_dependencies(pad):
		var p: String = str(d).split("::")[-1] if "::" in str(d) else str(d)
		if p.begins_with("uid://"):
			var id := ResourceUID.text_to_id(p)
			p = ResourceUID.get_id_path(id) if ResourceUID.has_id(id) else ""
		if p == "":
			continue
		uit.append([pad, p])
		_afhankelijk(p, gezien, uit)


func _run() -> void:
	var out: Array = []
	var code := OS.execute("python3", ["-I", ProjectSettings.globalize_path("res://tools/ota_vroeg.py"), "--lijst"], out, true)
	_check(code == 0, "tools/ota_vroeg.py --lijst werkt niet (exit %d)" % code)
	var vroeg: PackedStringArray = str(out[0]).split("\n", false) if out.size() > 0 else PackedStringArray()
	_check(vroeg.size() > 10, "de lijst met vroeg geladen bestanden is verdacht klein (%d)" % vroeg.size())
	var gezien := {}
	var n_res := 0
	for f in vroeg:
		var pad := "res://" + f
		_check(not _zwaar(pad), "zwaar bestand wordt vroeg geladen (preload of class-afhankelijkheid): %s" % pad)
		if pad.get_extension().to_lower() in RESOURCE_EXT and FileAccess.file_exists(pad):
			n_res += 1
			var deps: Array = []
			_afhankelijk(pad, gezien, deps)
			for paar in deps:
				_check(not _zwaar(paar[1]), "%s hangt af van het zware bestand %s en wordt vroeg geladen" % [paar[0], paar[1]])
	# alle preloads in alle scripts: een preload van een scène/resource met zware afhankelijkheden is nooit goed, ook niet buiten de vroege lijst
	var re := RegEx.create_from_string('preload\\("(res://[^"]+)"\\)')
	for script_pad in _scripts("res://scripts"):
		var tekst := FileAccess.get_file_as_string(script_pad)
		for m in re.search_all(tekst):
			var doel := m.get_string(1)
			_check(not _zwaar(doel), "%s: preload van zwaar bestand %s (gebruik load())" % [script_pad, doel])
			if doel.get_extension().to_lower() in RESOURCE_EXT and FileAccess.file_exists(doel):
				var deps2: Array = []
				_afhankelijk(doel, {}, deps2)
				for paar in deps2:
					_check(not _zwaar(paar[1]), "%s: preload van %s, dat het zware bestand %s nodig heeft (gebruik load())" % [script_pad, doel, paar[1]])
	print("OTA_VROEG_TEST vroege bestanden=%d resources=%d fouten=%d" % [vroeg.size(), n_res, fails])
	quit(1 if fails > 0 else 0)


func _scripts(map: String) -> Array:
	var res: Array = []
	for f in DirAccess.get_files_at(map):
		if f.ends_with(".gd"):
			res.append(map + "/" + f)
	return res
