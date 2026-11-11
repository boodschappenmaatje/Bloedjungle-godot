extends SceneTree
## Menu's netjes (hoofdmenu, instellingen per tabblad, uitrusting, testgroep, pauze, einde, updates): maakt foto's en
## controleert dat alles binnen de veilige marges past zonder scrollen, dat geen naam midden in een woord afbreekt en
## dat elke keuzetekst in zijn vakje past.
## Liggend (iPhone, 1086x500 HUD-punten met inkeping):
##   BJ_TOUCH=1 BJ_SAFE=69,0,69,24 xvfb-run -a -s "-screen 0 1086x500x24" godot --rendering-driver opengl3 --path . -s tests/menu_foto.gd --resolution 1086x500 --fixed-fps 60
## Staand: BJ_SAFE=0,69,0,40 en 500x1086. MENU_OUT = uitvoermap, MENU_TAG = voorvoegsel; MENU_FOTO=0 slaat de foto's over.
var main: Node
var menu: Node
var frames := 0
var out := "/tmp/menu"
var tag := "menu"
var foto := true
var fails := 0
var steps: Array = []
var step := 0
var wait := 0


func _initialize() -> void:
	if OS.get_environment("MENU_OUT") != "":
		out = OS.get_environment("MENU_OUT")
	if OS.get_environment("MENU_TAG") != "":
		tag = OS.get_environment("MENU_TAG")
	foto = OS.get_environment("MENU_FOTO") != "0"
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main


func _check(what: String, ok: bool) -> void:
	if not ok:
		fails += 1
		print("FAIL ", tag, ": ", what)


func _vp() -> Vector2:
	return root.get_visible_rect().size


## Alles wat zichtbaar is in het blad moet binnen de veilige rand liggen.
func _inside(sheet: Control, name: String) -> void:
	var vp := _vp()
	var safe: Vector4 = load("res://scripts/ui.gd").safe_margins(vp, 0.0)
	var area := Rect2(Vector2(safe.x, safe.y), vp - Vector2(safe.x + safe.z, safe.y + safe.w)).grow(1.0)
	for c in sheet.find_children("*", "Control", true, false):
		var ctl := c as Control
		if not ctl.is_visible_in_tree() or ctl.size.x <= 0.0 or ctl is ScrollContainer:
			continue
		if not (ctl is Button or ctl is Label or ctl is LineEdit or ctl is HSlider):
			continue
		# binnen een scrollvak telt het zichtbare deel; daarvoor kijken we hieronder naar het scrollvak zelf
		var r := ctl.get_global_rect()
		_check("%s: %s '%s' valt buiten het scherm %s" % [name, ctl.get_class(), _txt(ctl), str(r)], area.encloses(r))
	for sc in sheet.find_children("*", "ScrollContainer", true, false):
		var s := sc as ScrollContainer
		if not s.is_visible_in_tree():
			continue
		_check("%s: scrollbalk zichtbaar" % name, s.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER or s.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED)
		var content := (s.get_child(0) as Control).size.y
		_check("%s: past niet zonder scrollen (%d van %d)" % [name, content, s.size.y], content <= s.size.y + 1.0)


func _txt(c: Control) -> String:
	if c is Button:
		return (c as Button).text.replace("\n", " ")
	if c is Label:
		return (c as Label).text.left(30)
	return ""


## Keuzevakjes: tekst past; namen: geen woord breder dan de kolom; tekst in knoppen van het hoofdmenu past in de knop.
func _fits(sheet: Control, name: String) -> void:
	for c in sheet.find_children("*", "Button", true, false):
		var b := c as Button
		if not b.is_visible_in_tree() or b.text == "":
			continue
		var f := b.get_theme_font("font")
		var fs := b.get_theme_font_size("font_size")
		var sb := b.get_theme_stylebox("normal")
		var room := b.size.x - sb.get_margin(SIDE_LEFT) - sb.get_margin(SIDE_RIGHT)
		for line in b.text.split("\n"):
			var w := f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			_check("%s: knoptekst '%s' past niet (%d > %d)" % [name, line, w, room], w <= room + 1.0)
	for c in sheet.find_children("*", "Label", true, false):
		var l := c as Label
		if not l.is_visible_in_tree() or l.text == "":
			continue
		var f := l.get_theme_font("font")
		var fs := l.get_theme_font_size("font_size")
		if l.autowrap_mode == TextServer.AUTOWRAP_OFF:
			var w := f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var p := l.get_parent() as Control
			if p is Button or (p != null and p.get_parent() is Button):
				var host: Control = p if p is Button else p.get_parent()
				var hr := host.get_global_rect()
				_check("%s: '%s' steekt buiten de knop" % [name, l.text], hr.grow(1.0).encloses(l.get_global_rect()) and w <= l.size.x + 1.0)
			continue
		for word in l.text.split(" ", false):
			var w := f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			_check("%s: woord '%s' breekt af (%d > %d)" % [name, word, w, l.size.x], w <= l.size.x + 1.0)


func _shot(name: String) -> void:
	if foto:
		root.get_viewport().get_texture().get_image().save_png(out + "/%s_%s.png" % [tag, name])


func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		menu = get_nodes_in_group("menus")[0]
		main.get_node("Hud/Sticks").set_process(false)
		if Progress.scores.is_empty():
			for i in 5:
				Progress.scores.append({"id": 900 + i, "name": ["Dennis", "Rambo", "Kees", "Sanne", "Joop"][i], "wave": 12 - i * 2, "score": 48200 - i * 7300, "kills": 300})
		steps = [
			["hoofdmenu", func(): menu.show_menu(), func(): return menu._sheets["menu"]],
		]
		for i in menu.SETTINGS_TABS.size():
			var idx: int = i
			steps.append(["instellingen_%d_%s" % [i + 1, String(menu.SETTINGS_TABS[i]["title"]).to_lower().replace(" & ", "_")], func():
				menu._open_settings("menu")
				menu._select_tab(idx), func(): return menu._pcs["settings"]])
		steps.append(["uitrusting", func(): menu._open_gear("menu"), func(): return menu._pcs["gear"]])
		steps.append(["testgroep", func(): menu._show("test"), func(): return menu._pcs["test"]])
		steps.append(["pauze", func(): menu._show("pause"), func(): return menu._pcs["pause"]])
		steps.append(["melden", func():
			menu._show("menu")
			menu.open_melden("menu"), func(): return menu._pcs["melden"]])
		steps.append(["einde", func():
			menu._over_title.text = "MISSIE MISLUKT"
			menu._over_reason.text = "JE BENT GESNEUVELD"
			menu._over_stats.score.text = "12.400"
			menu._over_stats.wave.text = "7"
			menu._over_stats.kills.text = "86"
			menu._over_save_row.visible = true
			menu._score_table(menu._over_scores)
			menu._show("over"), func(): return menu._pcs["over"]])
		steps.append(["updates", func():
			menu._show("menu")
			load("res://scripts/update_panel.gd").open(menu), func():
				for n in get_nodes_in_group("update_panel"):
					return n.get("_paneel")
				return null])
	if frames < 30 or step >= steps.size():
		if step >= steps.size() and frames > 30:
			print("MENU FOTO KLAAR (%s): %d fouten" % [tag, fails])
			quit(1 if fails > 0 else 0)
			return true
		return false
	var s: Array = steps[step]
	if wait == 0:
		(s[1] as Callable).call()
	wait += 1
	if wait == 8:
		var sheet: Control = (s[2] as Callable).call()
		_check("%s: blad niet gevonden" % s[0], sheet != null)
		if sheet != null:
			_inside(sheet, s[0])
			_fits(sheet, s[0])
		_shot(s[0])
		if s[0] == "updates":
			for n in get_nodes_in_group("update_panel"):
				n.queue_free()
		step += 1
		wait = 0
	return false
