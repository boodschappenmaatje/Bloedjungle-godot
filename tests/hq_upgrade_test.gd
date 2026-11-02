extends SceneTree
## Het hoofdkwartier upgraden via de echte wapenkamer: tab Basis, kaart "Hoofdkwartier upgraden", knop "Upgrade · 1.500" en daarna "Upgrade · 2.500".
## godot --headless --path . --script tests/hq_upgrade_test.gd --fixed-fps 60

var main: Node
var frames := 0
var fails := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


## De knop van de kaart met deze titel (de kaart is de PanelContainer waar het label in zit).
func _kaart_knop(shop, titel: String) -> Button:
	for l in shop._items.find_children("*", "Label", true, false):  # _items = het nieuwste raster (het oude is al vrijgegeven)
		if (l as Label).text == titel:
			var n: Node = l
			while n != null and not (n is PanelContainer):
				n = n.get_parent()
			if n != null:
				for b in n.find_children("*", "Button", true, false):
					return b
	return null


func _process(_d: float) -> bool:
	frames += 1
	var g = root.get_node("Game")
	if frames == 2:
		main.get_node("Hud/Sticks").set_process(false)
	if frames == 4:
		main.begin()
	if frames == 12:
		var shops := main.find_children("*", "Shop", true, false)
		_check("wapenkamer (Shop) bestaat", shops.size() == 1)
		var shop = shops[0]
		print("staat van het spel voor open(): ", g.state)
		_check("tussen de golven (prep) kun je de wapenkamer openen", g.state == "prep")
		g.points = 2000
		var base0: float = g.base_max
		shop.open()
		shop._tab = 2   # Basis
		shop._render()
		_check("wapenkamer is open", g.state == "shop")
		var knop := _kaart_knop(shop, "Hoofdkwartier upgraden")
		_check("kaart 'Hoofdkwartier upgraden' staat in de tab Basis", knop != null)
		if knop != null:
			_check("knop toont de prijs van niveau 2", knop.text.contains("1.500") and not knop.disabled)
			knop.pressed.emit()
			_check("niveau 2 na de aankoop", g.hq_level == 2)
			_check("1.500 punten betaald", g.points == 500)
			_check("sterkte +400", is_equal_approx(g.base_max, base0 + 400.0))
			var knop2 := _kaart_knop(shop, "Hoofdkwartier upgraden")
			_check("niveau 3 kost 2.500 en is nog niet te koop met 500 punten", knop2 != null and knop2.text.contains("2.500") and knop2.disabled)
			g.points = 2500
			shop._render()
			knop2 = _kaart_knop(shop, "Hoofdkwartier upgraden")
			_check("met 2.500 punten is de knop actief", knop2 != null and not knop2.disabled)
			knop2.pressed.emit()
			_check("niveau 3 na de aankoop", g.hq_level == 3)
			_check("sterkte nog +500", is_equal_approx(g.base_max, base0 + 900.0))
			var knop3 := _kaart_knop(shop, "Hoofdkwartier upgraden")
			_check("daarna staat er Max", knop3 != null and knop3.text == "Max" and knop3.disabled)
	if frames == 16:
		print("klaar, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false
