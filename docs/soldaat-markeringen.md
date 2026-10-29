# Soldaatmarkeringen (v146)

Leesbaarheid van soldaten in Gevecht en Tactisch (keuze van Dennis: A, B, D, E, H).

- `scripts/soldier_mark.gd` (SoldierMark) hangt als kind aan elk SoldierModel (speler, vijanden, bondgenoten, wachten).
  - Ring op de grond: rood voor vijanden, groen voor bondgenoten. Jij hebt sinds v152 geen ring en geen pijl meer (Dennis wilde die terug weg).
  - Zacht randlicht (fresnel, tweede materiaallaag) langs het lichaam; strength-uniform wordt één keer per frame gezet.
  - Tactisch: het lichaam 30% groter (alleen het glb-model, botsing en raakvlak blijven gelijk).
  - Dode soldaten verliezen hun ring en grootte (leest `dead` van de ouder).
- Instelling "Markeringen soldaten" (`markeringen`): Aan, Alleen Tactisch, Uit. Standaard Aan.
- Test: `tests/soldaat_markering_test.gd`. Voor/na-beelden: `tests/zichtbaar_foto.gd` (`ZICHT_MODE=off|on`), resultaat in `docs/vq2/renders/markering-*.png`.
- Geen nieuw 3D-model, dus geen viewer-invoer. Niet gemeten op iPhone; kost per soldaat één vlak en één extra laag per lichaamsdeel.
