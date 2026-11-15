# Dambreuk-plan stap 3a: bij de dam komen en C4 plakken (v241)

**Keuzes van Dennis (15 november 2026):** 1B 2A 3A 4A 5C 6A 7A 8A 9A. Keuzekaart: https://claude.ai/artifact/Q14atDhwXwjAQjKcoZjoR2.
**Status:** zelfde Draft PR als stap 1 en 2 (#316). Native iPhone: **NIET GETEST**.

## Wat er is
| Keuze | Gebouwd | Waar |
| --- | --- | --- |
| 1B bergpad | Pad (8 m breed) van de westflank langs de noordrand van de kaart, buiten de vijandbasis om, de kloof in (17 m breed) tot de voet van de dam | `scripts/dam_pad.gd` (`DamPad.segments`), `Data.clamp_world(p, voet)` |
| 2A voet, jeep en tank | Pad en kloof gelden voor alles; helling en kroon alleen voor soldaten (`voet = true`) | `Data.clamp_world`, `player.gd` |
| 7A kroon en loopbrug | Helling in de oostwand (23 graden), kroon op 16 m, trap naar de loopbrug op 20,8 m (`Data.ground_y` volgt), borstwering zodat je alleen via de trapuiteinden omhoog gaat | `DamPad.height`, `Dam._build_barriers` |
| 4A twee van drie deuren | Elke sluisdeur 900 levenspunten; twee kapot = Kraken (5 s) en Breken; de clips Kraken/Breken spelen | `Dam.blast`, `Dam._breach` |
| 9A zwaar spul | Tankgranaat, bazooka-raket, artillerie, M-47 en luchtaanval doen 3x schade op de deur (horizontale afstand tot de deur, een granaat op de achterkant telt). Kogels en handgranaten niet | `Dam.blast_alle` naast `VijandM2Toren.blast` |
| 3A en 5C C4 | Zevende generaalskracht in het wiel (een rangpunt). Drie ladingen per spel (`Game.c4_ladingen`). Op de kroon of loopbrug bij een deur: plakken (rood lampje). Elders of bij een geplakte lading: ontsteken, na 5 s gaan ze af (2400 schade, 7 m). 3 s tussen twee handelingen | `scripts/c4_dam.gd`, `Rang` (`max_niveau`), `Dam.plant_c4` / `ontsteek_c4` |
| 6A bewaakt | Zes wachters (verdedigerssoldaten) op de kloofbodem; plakken geeft alarm (45 m) | `Dam._spawn_wachters` |
| 8A | Waarschuwing (sirene + banner) bij het kraken. Meegesleurd worden hoort bij stap 3 (vloed) | |

## Eerlijke aantekeningen
- **Uitleg 5C:** "eenmaal per spel" is gelezen als: C4 kies je één keer (een rangpunt) en je krijgt drie ladingen voor het hele spel, zonder bijvullen. Zeg het als je het anders bedoelde.
- **MG-torens (6A):** nog niet. De M2-toren hangt aan de muren van de vijandbasis; voor de dam komen ze later.
- **Alleen kroon-zicht:** het bergpad is een strook in het terrein, geen aparte weg met textuur (komt bij de Meshy-dam).
- **Routes van troepen/voertuigen:** de A*-routezoeker kent het pad nog niet: bevelen naar de dam lopen alleen direct. Handmatig rijden en lopen werkt.
- Water en vloed zijn stap 3. Nu breekt de dam alleen (stukken vallen, geen water).
- iPhone: **NIET GETEST** (fps, aanraking, geheugen).

## Tests
`tests/dam_pad_test.gd` (begaanbaarheid, hoogtes, een lopende route van het pad tot de loopbrug), `tests/dam_c4_test.gd` (schade, plakken, ontsteken, twee deuren kapot = kraken en breken, C4 via `Rang`, zes wachters), `tests/bergland_test.gd` aangepast (kloofbodem voor de dam).

## Fix v242 (Dennis' melding op v241: "bij de dam komen kan niet, bergen in de weg")
Oorzaak (nagelopen met `tests/dam_loop_test.gd`, een echte speler met botsing en bomen): het pad werkte, maar was onzichtbaar en de ingang achter de vijandbasis was maar ongeveer 16 m breed; wie recht naar het noorden liep botste tegen de onzichtbare kaartrand (z -285) en zag alleen bergen.
Aanpassing: de hele noordrand tussen x -128 en x -36 is een brede strook (20 m), de kloof is vanaf de kaartrand (z -285) 36 m breed open (recht naar het noorden lopen werkt), een zichtbare donkere aardeweg (`DamPad.build_road`) en een bord "DAM >>>" bij het begin. Tests: `dam_pad_test` (recht naar het noorden op vier plekken, noordrand open), `dam_loop_test` (fysiek lopen van het pad tot de kroon: PASS). Jeep en tank gebruiken dezelfde `clamp_world` (zonder helling en kroon); fysiek gereden is dat niet, alleen de clamp is getest.
