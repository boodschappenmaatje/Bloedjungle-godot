# Wereld per start — stap W2: rivier

Losse feature (geen onderdeel van `docs/GENERALS_PLAN.md`), vervolg op [W1](wereld-per-start-w1.md), gestart in de
projectthread "Ontwerp wereld die elke start anders is" (9 november 2026). Keuzekaart:
https://claude.ai/artifact/KniXqmh47fKQ1Cwn2AdJvS. Dennis' keuze voor deze stap: **3B** — "kronkel anders, brug+
doorwaadplaats schuiven mee".

## Afwijking van de letterlijke keuzekaart (bewust, gemeld aan Dennis)

De brug staat niet los in de wereld: Dennis' eigen, met de hand gebouwde stadsstraten (`scripts/stad_data.gd`,
`StadData.ITEMS`) sluiten precies op x=0 op de brug aan, en de stadseditor gaat daar ook van uit. Als de brug zelf
meeschuift, breekt dat zijn straten en editor-workflow bij elke willekeurige seed. Daarom is deze stap gebouwd als:
de **brug blijft vast op x=0**, en de **rivierkronkel (vorm) en de doorwaadplaats (FORD_X)** schuiven wel mee per
seed. Dit is in de projectthread gemeld vóór de bouw; er kwam geen bezwaar.

## Wat deze stap doet

- `scripts/data.gd`: `FORD_X` is van `const` naar `static var` gegaan. Nieuw: `_randomize_river()`, aangeroepen
  vanuit `randomize_world_seed()` en expliciet bij elke wereld-herbouw. Bij de vaste `WORLD_SEED_DEFAULT` zet deze
  functie exact de oude vaste waarden terug (dezelfde rivierkronkel, `FORD_X = 38.0`) — editor, headless en tests
  blijven dus ongewijzigd. Bij een willekeurige seed worden twee gecombineerde sinustermen (amplitude, frequentie,
  fase) opnieuw geloot binnen een bereik rond de oude vorm, en `FORD_X` krijgt een nieuwe waarde tussen 20 en 65 m
  (links of rechts van de brug), ruim weg van de brug zelf en van de kaartrand. `BRIDGE_X` blijft een `const` op
  `0.0`.
- `scripts/level.gd`, `scripts/river.gd`: geven de nieuwe `Data._river_amp1/_freq1/_phase1/_amp2/_freq2/_phase2`
  door aan de grond- en waterbuffers via `set_shader_parameter`, zodat de visuele rivier (bodemtextuur + wateroppervlak)
  exact dezelfde kronkel volgt als `Data.river_z(x)`.
- `shaders/ground.gdshader`, `shaders/water.gdshader`: dezelfde zes uniforms toegevoegd; de oude vaste constanten in
  de rivierformule zijn vervangen door deze uniforms (met de oude waarden als standaard, dus niets verandert als
  level.gd ze niet expliciet zet).
- `scripts/route.gd` en alle andere plekken die de rivier/brug/doorwaadplaats gebruiken (apache.gd, fx.gd,
  hud_extra.gd, jungle_geluid.gd, mcv.gd, stad.gd, voorraad.gd) lazen al dynamisch via `Data.river_z()` /
  `Data.BRIDGE_X` / `Data.FORD_X` — daar is niets aan gewijzigd, die volgen vanzelf mee.

## Tests

- **Nieuw:** `tests/rivier_seed_test.gd` — bij de vaste standaard-seed blijft de rivierformule en `FORD_X=38.0`
  exact gelijk aan vroeger; twee verschillende willekeurige seeds geven aantoonbaar een andere kronkel én een
  andere `FORD_X` (binnen de grenzen 20–65 m); dezelfde seed geeft twee keer precies dezelfde rivier terug
  (reproduceerbaar); terug naar de standaard-seed geeft weer exact de oude rivier (geen lekkage tussen seeds). De
  brug (`BRIDGE_X`) blijft in alle gevallen op 0. Resultaat: `RIVIER SEED TEST OK`, 0 fouten.
- `tests/aanval_basis_test.gd` aangepast: las `FORD_X` via `get_script_constant_map()`, wat alleen voor `const`
  werkt. Nu via `dt.get("FORD_X")`, want het is een `static var` geworden. Test blijft groen.
- Volledige rondje gedraaid: `rivier_seed_test`, `rivier_test`, `brug_test`, `aanval_basis_test`, `mcv_test`,
  `mcv_voorraad_test`, `voorraad_test`, `wereld_seed_test` (W1), `jungle_test`, `smoke_test` — allemaal groen op de
  vaste standaard-seed, geen regressies.

## Voor/na-opnames

Gemaakt met `tools/rivier_seed_foto.gd` (nieuw, headless + Xvfb + Vulkan, dezelfde speelcamera, steeds bij de brug
op x=0, net ten zuiden van de rivier voor de kronkel van dat moment), zie `/mnt/project-files/wereld/w2_opnames/`:

- `voor_standaard.png` — de vaste standaard-seed: de oude vertrouwde brug en rivierkronkel, `FORD_X = 38.0`.
- `na_seed_4242.png` — willekeurige seed 4242: andere kronkel van de oevers, `FORD_X = 34,77`.
- `na_seed_99001.png` — willekeurige seed 99001: weer een andere kronkel, `FORD_X = 62,56`.

De brug zelf staat op alle drie de opnames op dezelfde plek (x=0) — dat is de bewuste keuze hierboven. Het verschil
zit in de vorm van de oevers/rivierloop en in waar de doorwaadplaats ligt (niet in beeld bij de brug, maar elders
op de kaart; zie de `FORD_X`-waarden hierboven).

## Prestaties

Geen nieuwe geometrie, geen nieuwe materialen: alleen bestaande rivier-/watermeshes met andere shader-uniforms en
een andere x-positie voor de doorwaadplaats-oever. De wereld wordt nog steeds precies één keer gebouwd bij het
laden; geen gemeten effect op laadtijd. **Native iPhone NIET GETEST.**
