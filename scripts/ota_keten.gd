extends RefCounted
## Laadt de kleine vervolgstukken van de updateketen (user://ota/keten.json) bij elke start, vlak na de actieve patch.
## Aangeroepen vanuit Game._init (de eerste autoload na de Updater). De actieve patch (Updater) is het lichte stuk met scripts en kleine bestanden; de zware stukken hier
## (modellen, texturen, geluid) komen daarna in volgorde, en daarna laden we het lichte stuk nog eens zodat dat voorrang houdt. Wordt de actieve patch teruggedraaid (crashbeveiliging), dan staat
## actief.json er niet meer en wordt er niets geladen. Niets laden bij een onvolledige of afwijkende keten.
##
## Let op: zware bestanden die scripts al bij het opstarten met preload inladen kunnen niet via een vervolgstuk veranderen, want ze zijn
## geladen voor dit wordt aangeroepen. De workflow (ota.yml, tools/ota_vroeg.py) begint dan automatisch een nieuwe zware keten.

const DIR := "user://ota"

## Wat er bij de laatste start met de keten gebeurde (voor het updatescherm, zodat te zien is waarom zware stukken wel of niet laden).
static var status := "keten nog niet gecontroleerd"
## Diagnose voor het Updates-scherm: laatste spelermodel- en vliegtuigmelding (leeg = nooit gezet).
static var speler := ""
static var vliegtuig := ""


static func _json(pad: String) -> Dictionary:
	if not FileAccess.file_exists(pad):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(pad))
	return d if d is Dictionary else {}


## Geeft het aantal geladen stukken (0 als er niets te laden was of de keten niet klopt).
static func laad(map := DIR) -> int:
	var actief := _json(map + "/actief.json")
	if actief.is_empty():
		status = "zware stukken niet geladen: geen actieve update (actief.json ontbreekt)"
		return 0
	var keten := _json(map + "/keten.json")
	if keten.is_empty():
		status = "zware stukken niet geladen: keten.json ontbreekt of is leeg"
		return 0
	if str(keten.get("basis", "")) != str(actief.get("base", "x")):
		status = "zware stukken niet geladen: basis klopt niet (keten %s, update %s)" % [str(keten.get("basis", "?")).left(7), str(actief.get("base", "?")).left(7)]
		return 0
	var lijst: Variant = keten.get("stukken", [])
	if not (lijst is Array) or (lijst as Array).is_empty():
		status = "zware stukken niet geladen: de keten heeft geen stukken"
		return 0
	for p in lijst:
		var pad := str(p.get("bestand", ""))
		var f := FileAccess.open(pad, FileAccess.READ) if FileAccess.file_exists(pad) else null
		if f == null or f.get_length() != int(p.get("grootte", -1)):
			push_warning("OtaKeten: stuk ontbreekt of is onvolledig, de keten wordt niet geladen: " + pad)
			status = "zware stukken niet geladen: %s ontbreekt of is onvolledig (%d van %d bytes)" % [pad.get_file().left(30), f.get_length() if f != null else 0, int(p.get("grootte", 0))]
			return 0
	var n := 0
	for p in lijst:
		if ProjectSettings.load_resource_pack(str(p.bestand), true):
			n += 1
		else:
			push_warning("OtaKeten: kon stuk niet laden: " + str(p.bestand))
	# Het lichte stuk (de actieve patch) heeft voorrang op de zware stukken (bijv. gegenereerde bestanden die in beide zitten).
	status = "zware stukken geladen: %d van %d" % [n, (lijst as Array).size()]
	var licht := str(actief.get("bestand", ""))
	if licht != "" and FileAccess.file_exists(licht):
		ProjectSettings.load_resource_pack(licht, true)
	return n
