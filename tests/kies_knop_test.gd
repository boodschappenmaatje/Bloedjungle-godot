extends SceneTree
## Test: de KIES-knop (ster) opent het kiesscherm bij een echte tik en het scherm blijft open (regressie van v216: "als ik op de ster druk gebeurt er niks").
## Oorzaak toen: een vinger geeft eerst het nagebootste muisgebaar (de knop opent op button_down) en daarna in hetzelfde beeld de aanraking zelf; die
## tweede viel buiten het paneel en sloot het scherm meteen weer.
## Deel 1 bootst die volgorde na en draait ook headless (CI); deel 2 gebruikt echte aanrakingen via Input.parse_input_event (KIES, KRACHTEN-wiel, rechterstick) en
## draait alleen met een echt venster: BJ_TOUCH=1 BJ_SAFE=69,0,69,24 xvfb-run -a -s "-screen 0 1086x500x24" godot --rendering-driver opengl3 --path . -s tests/kies_knop_test.gd --resolution 1086x500 --fixed-fps 60
## Headless: godot --headless --path . --script tests/kies_knop_test.gd --fixed-fps 60
var main: Node
var game: Node
var combat: Node
var frames := 0
var fails := 0
var echt_venster := false


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(ok: bool, what: String) -> void:
	print(("OK   " if ok else "FAAL ") + what)
	if not ok:
		fails += 1


func _open() -> bool:
	return combat._keuze != null and is_instance_valid(combat._keuze) and not combat._keuze.is_queued_for_deletion()


func _touch(pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.pressed = pressed
	e.position = pos
	return e


func _touch_i(index: int, pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var e := _touch(pos, pressed)
	e.index = index
	return e


func _drag_i(index: int, pos: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	return e


func _stick_anchor() -> Vector2:
	return main.get_node("Hud/Sticks")._anchor(true)


func _process(_d: float) -> bool:
	frames += 1
	game = root.get_node("Game")
	if frames == 3:
		main.begin()
		for m in get_nodes_in_group("menus"):
			m._show("")
		game.prep_t = 9999.0
		combat = main.get_node("Hud").find_child("CombatButtons", true, false)
		echt_venster = DisplayServer.get_name() != "headless"
	if frames == 30:
		game.state = "play"
		game.player.driving = false    # het spel begint in de bouwwagen; Dennis speelt te voet
		game.add_score(840)
	if frames == 36:
		# deel 1: de volgorde van een vinger op de iPhone, zonder afhankelijk te zijn van de vensterafmetingen
		_check(game.rang_punten == 1 and combat._air2.visible, "KIES-knop zichtbaar met een punt over")
		var ver := Vector2(900, 400)
		combat._air2.button_down.emit()          # 1. het nagebootste muisgebaar: de knop opent het scherm
		_check(_open(), "de knop opent het kiesscherm")
		root.push_input(_touch(ver, true))       # 2. dezelfde vinger als aanraking, in hetzelfde beeld
		_check(_open(), "dezelfde aanraking sluit het scherm niet meer")
		root.push_input(_touch(ver, false))
		_check(_open(), "ook na het loslaten blijft het scherm open")
	if frames == 40:
		_check(_open(), "een paar beelden later nog steeds open")
		# een nieuwe tik ernaast (ander beeld) sluit het scherm wel
		root.push_input(_touch(Vector2(5, 5), true))
		root.push_input(_touch(Vector2(5, 5), false))
		_check(not _open(), "een latere tik buiten het paneel sluit het scherm")
		_check(game.rang_punten == 1, "sluiten kost geen punt")
	if frames == 44:
		combat._air2.button_down.emit()
		_check(_open(), "opnieuw openen lukt")
		_check(combat._keuze.kies("napalm") and int(game.krachten.get("napalm", 0)) == 1 and game.rang_punten == 0, "kiezen geeft het punt aan napalm")
	if frames == 48:
		_check(not _open(), "zonder punten sluit het scherm vanzelf")
		if not echt_venster:
			_klaar()
		else:
			# deel 2: echte aanrakingen (Input.parse_input_event), alleen met een echt venster
			game.krachten = {}
			game.rang_punten = 1
			game.changed.emit()
	if echt_venster and frames == 54:
		Input.parse_input_event(_touch(combat._air2.get_global_rect().get_center(), true))
	if echt_venster and frames == 56:
		_check(_open(), "echte aanraking: het kiesscherm staat er")
		Input.parse_input_event(_touch(combat._air2.get_global_rect().get_center(), false))
	if echt_venster and frames == 62:
		_check(_open(), "echte aanraking: na het loslaten blijft het open")
		if _open():
			var kaart: Rect2 = combat._keuze._cards[1]    # napalm
			Input.parse_input_event(_touch(kaart.get_center(), true))
			Input.parse_input_event(_touch(kaart.get_center(), false))
	if echt_venster and frames == 68:
		# daarna de krachtenknop zelf met echte aanrakingen: een tik opent het wiel (zoals UITRUSTING), kiezen zet de rechterstick klaar,
		# een nieuwe rechteraanraking richt en loslaten vuurt af
		game.kracht_sel = "napalm"
		game.changed.emit()
	if echt_venster and frames == 74:
		var ck: Vector2 = combat._air.get_global_rect().get_center()
		Input.parse_input_event(_touch(ck, true))
		Input.parse_input_event(_touch(ck, false))
	if echt_venster and frames == 80:
		_check(combat._wheel_kind == "support" and combat._wheel_sticky, "echte aanraking: een tik op KRACHTEN opent het wiel, ook met één kracht")
		var w1: Vector2 = combat._wheel_center()
		Input.parse_input_event(_touch(w1 + Vector2(70, 0), true))    # napalm staat rechts
		Input.parse_input_event(_touch(w1 + Vector2(70, 0), false))
	if echt_venster and frames == 86:
		_check(combat._wheel_kind == "" and game.kracht_sel == "napalm" and combat.kracht_stick_armed, "echte aanraking: NAPALM kiezen sluit het wiel en zet de rechterstick klaar")
		_check(not game.kracht_cd.has("napalm") and combat._place == null, "kiezen vuurt niets af")
		Input.parse_input_event(_touch_i(1, _stick_anchor(), true))
	if echt_venster and frames == 89:
		Input.parse_input_event(_drag_i(1, _stick_anchor() + Vector2(40, 0)))
	if echt_venster and frames == 92:
		_check(combat._air_vis != null and is_instance_valid(combat._air_vis) and combat._air_vis.visible, "echte aanraking: de rechterstick toont de napalmstrook")
		_check(not game.fire, "echte aanraking: in krachtstand schiet de rechterstick geen kogels")
		Input.parse_input_event(_touch_i(1, _stick_anchor() + Vector2(40, 0), false))
	if echt_venster and frames == 98:
		_check(game.kracht_cd.has("napalm") and not combat.kracht_stick_armed, "echte aanraking: loslaten vuurt napalm af, afkoeling loopt")
		game.krachten = {"satelliet": 1}
		game.kracht_sel = "satelliet"
		game.kracht_cd.clear()
		game.changed.emit()
	if echt_venster and frames == 104:
		var cs: Vector2 = combat._air.get_global_rect().get_center()
		Input.parse_input_event(_touch(cs, true))
		Input.parse_input_event(_touch(cs, false))
	if echt_venster and frames == 110:
		var w2: Vector2 = combat._wheel_center()
		Input.parse_input_event(_touch(w2 + Vector2(0, 70), true))    # satelliet staat onder
		Input.parse_input_event(_touch(w2 + Vector2(0, 70), false))
	if echt_venster and frames == 116:
		_check(combat.kracht_stick_armed and game.satelliet_t <= 0.0, "echte aanraking: SATELLIET kiezen zet de stick klaar zonder hem te gebruiken")
		Input.parse_input_event(_touch_i(1, _stick_anchor(), true))
	if echt_venster and frames == 119:
		Input.parse_input_event(_drag_i(1, _stick_anchor() + Vector2(0, 40)))
	if echt_venster and frames == 122:
		Input.parse_input_event(_touch_i(1, _stick_anchor() + Vector2(0, 40), false))
	if echt_venster and frames == 128:
		_check(game.satelliet_t > 0.0 and game.kracht_cd.has("satelliet"), "echte aanraking: slepen en loslaten gebruikt de satelliet")
		# met twee krachten kiest een tik op REPARATIE die kracht (links) en zet de stick klaar
		game.krachten = {"satelliet": 1, "reparatie": 1}
		game.kracht_sel = "satelliet"
		game.kracht_cd.clear()
		game.satelliet_t = 0.0
		game.changed.emit()
	if echt_venster and frames == 134:
		var cw: Vector2 = combat._air.get_global_rect().get_center()
		Input.parse_input_event(_touch(cw, true))
		Input.parse_input_event(_touch(cw, false))
	if echt_venster and frames == 140:
		_check(combat._wheel_kind == "support" and combat._wheel_sticky, "echte aanraking: een tik op KRACHTEN opent het wiel")
		var w3: Vector2 = combat._wheel_center()
		Input.parse_input_event(_touch(w3 + Vector2(-70, 0), true))
		Input.parse_input_event(_touch(w3 + Vector2(-70, 0), false))
	if echt_venster and frames == 146:
		_check(combat._wheel_kind == "" and game.kracht_sel == "reparatie" and combat.kracht_stick_armed, "echte aanraking: een tik op REPARATIE kiest die kracht en zet de stick klaar (%s)" % game.kracht_sel)
		_klaar()
	return false


func _klaar() -> void:
	print("KIES KNOP TEST KLAAR, fouten: %d" % fails)
	quit(1 if fails > 0 else 0)
