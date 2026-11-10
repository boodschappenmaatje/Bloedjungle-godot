# Graphics 2.0 (v205)

Plan en keuzes van Dennis (10 november 2026): geen diepte en geen mooie belichting waren het probleem, effecten eerst,
minimaal 100 fps op de native iPhone-app, camera meestal op 40 graden, één grote sprong. Dit document beschrijft wat er
gebouwd is en hoe je het test.

## Schakelaars (Instellingen)

| Instelling | Standaard | Wat het doet |
| --- | --- | --- |
| Graphics 2.0: Aan / Klassiek | Aan | Klassiek geeft exact het beeld van vóór v205 |
| Test: Graphics 2.0 effecten | Aan | schokgolf, flits, rookzuil, stofring, voertuigstof, fellere kogelsporen |
| Test: Graphics 2.0 belichting | Aan | lage zon, echte schaduwen, gloed, koel schaduwlicht, kleurtabel, contactschaduw |
| Test: Graphics 2.0 diepte | Aan | hoogtemist, laaghangende nevel, natte glans op modder |

Graphics 2.0 werkt bovenop de grafiekstand Hoog of Ultra. In stand Laag doet het niets.

## Wat er gebouwd is

**Effecten** (`scripts/fx.gd`, `shaders/g2_schokgolf.gdshader`, `scripts/graphics2_wereld.gd`)
- Explosie: korte felle flits, schokgolf van stof over de grond (hooguit 4 tegelijk), stofring die laag wegrolt, rookzuil
  die 6,5 s blijft hangen en meedrijft (hooguit 5 tegelijk). De lichtflits is feller (16 in plaats van 9), reikt verder
  (22 m in plaats van 15 m) en dooft trager; het maximum van 3 explosielichten tegelijk is ongewijzigd.
- De vuurbal is 25% feller, zodat hij met de gloed straalt. Kogelsporen zijn twee keer zo fel.
- Stof achter elk rijdend voertuig binnen 55 m (hooguit 6 voertuigen tegelijk).

**Belichting** (`scripts/atmosphere.gd`)
- Dag: zon op 25 graden in plaats van 33, warmer en sterker; de schaduwkant krijgt koel blauw licht.
- Echte schaduwen in twee delen tot 64 m, schaduwkaart 2048 (Ultra 4096). Palmen en rotsen werpen echte schaduw.
- Gloed aan, ook in stand Hoog. Kleurtabel per tijdstip (dag, avond, nacht).
- Contactschaduw: zachte donkere vlek onder elke soldaat en elk voertuig binnen 46 m. Eén MultiMesh, één tekenopdracht.

**Diepte** (`scripts/atmosphere.gd`, `shaders/g2_nevel.gdshader`, `shaders/ground.gdshader`)
- Hoogtemist onder 2,4 m en zongloed in de mist.
- Laaghangende nevel: één vlak van 160 m dat met de speler meeschuift, slierten vast aan de wereld, niet in het kamp.
- Natte glans op modder, oevers en moeras.

## Snelheid

- De resolutieregelaar (`PerfGovernor`) werkt zoals voorheen en houdt op een 120 Hz-scherm ongeveer 112 fps aan.
- Kwaliteitstrap 1 zet de nevel en hoogtemist uit (naast gloed en de tweede schaduwkaart, zoals al gold).
- Kwaliteitstrap 2 halveert het aantal rookzuilen.

## Niet gebouwd

- Heuvels als achtergrond: op 40 graden met de camera op 22,5 m ziet de speler ongeveer 40 tot 60 m ver. De horizon komt
  niet in beeld, dus een heuvelrand zou onzichtbaar zijn.
- Zonnevlekken als apart effect: de echte palmschaduwen geven dat schaduwspel al.
- Lichte onscherpte in de verte: staat uit, kost op mobiel relatief veel.
- Beloopbare heuvels, nieuwe modellen, MetalFX, Forward+: buiten dit plan.

## Testen

- `tests/graphics2_test.gd` (headless): schakelaar, testknoppen, bovengrenzen, kwaliteitstrap, klassiek = oude waarden.
- `tests/graphics2_foto.gd`: voor-en-na-beelden vanuit de spelcamera op 40 graden (zie de kop van het bestand).
- Native iPhone: **NIET GETEST**. De sandbox gebruikt software-Vulkan; die zegt niets over fps op de iPhone.
