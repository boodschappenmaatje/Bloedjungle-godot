extends SceneTree
## Test: M-47 Muurbreker (proefveld): model, muur, rook-atlassen, shader en het schot tot een blijvende doorgang.
## Draaien: godot --headless --path . -s tests/m47_vfx_test.gd --fixed-fps 60

var field: Node
var frames := 0
var fails := 0
var impacts := 0
var klaar := false


func _initialize() -> void:
	field = load("res://scenes/m47_proefveld.tscn").instantiate()
	root.add_child(field)


func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FOUT ") + msg)
	if not ok:
		fails += 1


func _process(_d: float) -> bool:
	frames += 1
	if frames == 5:
		var tex := M47Vfx.textures()
		_check(tex["sliert"] is Texture2D and tex["sliert"].get_width() == 768, "rook-atlas sliert 768x768")
		_check(tex["stof"] is Texture2D and tex["stof"].get_width() == 768, "stof-atlas 768x768")
		_check(load("res://shaders/m47_honingraat.gdshader") is Shader, "honingraat-shader laadt")
		_check(field.weapon_anim != null, "M-47 heeft een AnimationPlayer")
		for c in ["Idle", "Equip", "Aim", "Fire", "Reload"]:
			_check(field.weapon_anim.has_animation(c), "clip " + c)
		_check(field.wall.body.collision_layer != 0 and not field.wall.kapot, "muur heel met botsing")
		field.vfx.impact.connect(func(_p): impacts += 1)
		field.vfx.klaar.connect(func(): klaar = true)
		field.schiet()
	if frames > 5 and field.wall.kapot and frames % 30 == 0 and not klaar:
		_check(field.wall.body.collision_layer == 0, "botsing weg na de breuk (kogels gaan erdoor)")
	if klaar:
		_check(impacts == 1, "precies één inslag (%d)" % impacts)
		_check(field.wall.kapot, "muur blijft kapot (permanente doorgang)")
		field.reset_all()
		_check(not field.wall.kapot and field.wall.body.collision_layer != 0, "herstellen zet de muur terug")
		print("M47_VFX_TEST ", "OK" if fails == 0 else "FOUT %d" % fails)
		quit(0 if fails == 0 else 1)
	if frames > 1500:
		_check(false, "time-out: schot werd niet afgerond")
		quit(1)
	return false
