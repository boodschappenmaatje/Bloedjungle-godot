extends SceneTree
## Creates a tiny runtime OTA bridge PCK from an already exported Godot patch.
## Keep only the COMPILED exported UpdatePanel script, not imported world assets.
## Usage: godot --headless --path . -s tools/make_ota_bootstrap.gd -- <large-delta.pck> <bridge.pck>

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Usage: make_ota_bootstrap.gd -- <exported-patch.pck> <bridge.pck>")
		quit(2)
		return
	var source_patch := args[0]
	var destination := args[1]
	if not FileAccess.file_exists(source_patch):
		push_error("Exported input pack not found: " + source_patch)
		quit(3)
		return
	if not ProjectSettings.load_resource_pack(source_patch, true):
		push_error("Cannot mount exported patch pack")
		quit(4)
		return
	var compiled_path := "res://scripts/update_panel.gdc"
	if not FileAccess.file_exists(compiled_path):
		push_error("Compiled UpdatePanel not in exported patch: " + compiled_path)
		quit(5)
		return
	var code_bytes := FileAccess.get_file_as_bytes(compiled_path)
	if code_bytes.is_empty():
		push_error("Compiled updater panel is empty")
		quit(6)
		return
	var temporary := "user://ota_bridge_panel.gdc"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		push_error("Cannot prepare compiled bootstrap script")
		quit(7)
		return
	file.store_buffer(code_bytes)
	file.close()
	var packer := PCKPacker.new()
	if packer.pck_start(destination) != OK:
		push_error("Cannot start bridge PCK")
		quit(8)
		return
	if packer.add_file(compiled_path, temporary) != OK:
		push_error("Cannot add updated panel script")
		quit(9)
		return
	if packer.flush() != OK:
		push_error("Cannot flush bridge PCK")
		quit(10)
		return
	print("OTA_BOOTSTRAP_PACKED_BYTES=%d" % FileAccess.get_file_as_bytes(destination).size())
	print("OTA_BOOTSTRAP_SCRIPT_SHA256=" + FileAccess.get_sha256(temporary))
	quit(0)
