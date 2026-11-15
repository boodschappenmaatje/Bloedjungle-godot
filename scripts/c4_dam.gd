class_name C4Dam
extends RefCounted
## De kracht C4 (dambreuk stap 3a, Dennis' keuzes 3A en 5C): drie springladingen per spel, geen herlaadtijd.
## Sta op de kroon of de loopbrug van de dam bij een sluisdeur en gebruik C4: de lading wordt geplakt (een knipperend lampje).
## Gebruik je C4 ergens anders of staat er al een lading, dan worden alle geplakte ladingen ontstoken; na 5 s gaan ze af.


## Returns false als er niets gebeurde (geen kosten, geen afkoeling).
static func gebruik() -> bool:
	var dam := Dam.current
	var p = Game.player
	if dam == null or not is_instance_valid(dam) or p == null or not is_instance_valid(p):
		Game.banner.emit("C4", "Er is hier geen dam om op te plakken", 2.0)
		return false
	if dam.breaching or dam.broken:
		return false
	var gate := dam.nearest_gate(p.global_position)
	if gate >= 0 and not dam.gate_c4[gate]:
		if Game.c4_ladingen <= 0:
			Game.banner.emit("GEEN C4 MEER", "Alle ladingen zijn op", 2.0)
			return false
		dam.plant_c4(gate)
		Game.c4_ladingen -= 1
		Game.banner.emit("C4 GEPLAKT", "Nog %d lading(en). Loop weg en gebruik C4 om te ontsteken" % Game.c4_ladingen, 3.0)
		Sfx.play("click", 1.0)
		Game.changed.emit()
		return true
	if dam.c4_geplakt() > 0:
		if dam.ontsteek_c4():
			Game.changed.emit()
			return true
		return false
	Game.banner.emit("C4", "Ga bij een sluisdeur op de loopbrug staan", 2.2)
	return false
