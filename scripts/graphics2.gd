class_name Graphics2
## Graphics 2.0 (plan 10 nov 2026): één schakelaar voor het nieuwe beeld, met per onderdeel een testknop.
## - Effecten: schokgolf, flits, blijvende rook, stofring, feller licht uit explosies, stof achter voertuigen.
## - Belichting: lage warme zon, echte schaduwen, gloed, koele schaduwkleur, filmkleur, contactschaduw.
## - Diepte: laaghangende nevel, hoogtemist, natte glans op modder.
## Staat de hoofdschakelaar op Klassiek, dan is het beeld precies zoals vóór v205.


static func on() -> bool:
	return GameSettings.get_value("g2") == "on"


static func fx() -> bool:
	return on() and GameSettings.get_value("g2_fx") == "on"


static func light() -> bool:
	return on() and GameSettings.get_value("g2_licht") == "on"


static func depth() -> bool:
	return on() and GameSettings.get_value("g2_diepte") == "on"
