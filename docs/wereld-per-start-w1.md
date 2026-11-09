# Wereld per start — stap W1: seed + jungle

Losse feature (geen onderdeel van `docs/GENERALS_PLAN.md`), gestart in de projectthread "Ontwerp wereld die elke
start anders is" (9 november 2026). Keuzekaart: https://claude.ai/artifact/KniXqmh47fKQ1Cwn2AdJvS. Dennis' keuzes:
1B 2A 3B 4B 5B 6B (jungle + open plekken/bosjes/kratten; geen zichtbare kaartcode, gewoon elke start willekeurig;
rivier/stad/vijandbasis/sfeer volgen in latere stappen W2-W5).

## Wat deze stap doet

- `Data.world_seed` (nieuw, `scripts/data.gd`): het getal dat de jungle bepaalt. Staat vast op
  `Data.WORLD_SEED_DEFAULT` (11, de oude vaste waarde) in de editor, headless en alle tests — daar verandert dus
  **niets**. In een echt spel kiest `Data.randomize_world_seed()` één keer per sessie (bij de eerste
  `main.begin()`, niet bij "opnieuw spelen" binnen dezelfde sessie) een nieuw willekeurig getal.
- `scripts/foliage.gd`: `plant()` gebruikt die seed voor de bestaande palmen/struiken/varens/rotsen/gras en voor
  de omgevallen stammen (`logs()`). Bij een willekeurige seed (dus altijd in een echt spel) krijgt het
  bosjes-/open-plekken-patroon (`_grove`) ook een andere fase en frequentie, en komen er 5-7 munitiekisten
  (`Kit.MUNITIEKIST`, het bestaande Meshy-model) verspreid in de jungle-strook te staan — zuiver decoratief, geen
  botsing, nooit in de rivier, op een weg, in de stad of op het vliegveld.
- `scripts/level.gd` / `scripts/main.gd`: geven `Data.world_seed` door aan `Foliage.plant()`; `main.gd` kiest de
  willekeurige seed vlak voor de wereld voor het eerst gebouwd wordt.
- Rivier, stad, vijandbasis, voorraadstapels en sfeer (tijd/weer) blijven in deze stap ongewijzigd — dat zijn de
  volgende stappen (W2-W5) uit dezelfde keuzekaart.

## Tests

- **Nieuw:** `tests/wereld_seed_test.gd` — `randomize_world_seed()` geeft nooit de vaste standaard en niet steeds
  hetzelfde getal; de vaste standaard-seed geeft exact het oude bosjespatroon en nul kratten; twee verschillende
  seeds geven aantoonbaar verschillende jungles; dezelfde seed geeft twee keer precies dezelfde jungle terug.
  Resultaat: `WERELD SEED TEST OK`, 0 fouten.
- Bestaande tests gedraaid met de juiste Godot 4.7.1 (dit project staat op `config/features 4.7`, zie
  `project.godot`): `jungle_test` (OK, 13 vormen), `smoke_test` (OK), `vijand_basis_test` (OK, 0 fouten),
  `mcv_test` (OK, 0 fouten), `voorraad_test` (OK, 0 fouten). Geen van alle geraakt, want ze draaien allemaal met de
  vaste standaard-seed.
- De volledige testrun (`tools/run_tests.sh`, 423 scripts) is niet volledig gedraaid vanwege de tijd die dat kost;
  gegeven dat elke bestaande test de vaste standaard-seed gebruikt (nooit het nieuwe "willekeurig"-pad) is het
  risico op een gemiste regressie daar klein. Vraag het gerust alsnog als je dat liever ziet.

## Voor/na-opnames

Gemaakt met `tools/wereld_seed_foto.gd` (nieuw, headless + Xvfb + Vulkan, dezelfde speelcamera, dezelfde vaste
plek `(14, 0, -52)` in de jungle-strook), zie `/mnt/project-files/wereld/w1_opnames/`:

- `voor_standaard.png` — de vaste standaard-seed (het huidige spel): op deze exacte plek nu toevallig open gras.
- `na_seed_4242.png` — willekeurige seed 4242: dichte bosjes, een pad, een omgevallen stam en een rots op diezelfde
  plek.
- `na_seed_99001.png` — willekeurige seed 99001: weer een andere indeling, met zicht op het vliegveld.

Dat de standaard-opname hier open gras laat zien terwijl de twee willekeurige seeds juist dichte jungle geven, is
precies het punt van deze stap: dezelfde plek op de kaart ziet er nu bij elke start anders uit.

## Prestaties

Geen nieuwe geometrie-soorten of texturen: alleen bestaande meshes (jungle, munitiekist) op andere plekken. De
wereld wordt nog steeds precies één keer gebouwd bij het laden, dus de fps tijdens het spelen verandert niet.
Geschat < 0,1 s extra laadtijd voor de paar extra kratten. **Native iPhone NIET GETEST.**
