# Levendige legerbasis

Stappen die de basis levendiger maken (keuze van Dennis, 2026-10-27). Elke stap is een eigen Draft PR.

## Stap 1 (v140): patrouilles en alarm
- `scripts/patrouille.gd` (`Patrouille`, in `main.gd`): drie wachten (gewone `Ally`-soldaten met `guard = true`, niet in `Game.allies`, dus onafhankelijk van de kazerne).
- Pauze (`Game.state == "prep"`): ze wandelen heen en weer langs de binnenkant van de noord-, zuid- en westmuur (`Patrouille.line(i)`), blijven 3 tot 6 s op het eindpunt staan en keren om.
- Begint een golf: het alarmbestand `assets/geluid/alarm.mp3` (speelt één keer) en de wachten rennen naar hun post langs de muur (`Ally.POSTS`), waar ze op vijanden schieten zoals andere soldaten.
- Test: `tests/patrouille_test.gd`. Opnames: `tests/patrouille_foto.gd` (spelcamera). Geen nieuwe modellen, dus geen VQ2-assets. Geen iPhone-meting.

## Stap 2: slagboom en wachthuisje bij de poorten (v142)

- Bij de noord- en zuidpoort staan een slagboom en een wachthuisje (`assets/wachtpost.glb`, bron `bron/wachtpost/`, scripts `scripts/wachtpost.gd`). De arm gaat omhoog als de stalen poort open staat of kapot is en zakt weer als de poort dicht gaat.
- Het wachthuisje heeft botsing, je loopt er niet doorheen. Een vierde wacht staat voor het huisje bij de noordpoort en rent bij het alarm ook naar zijn post.
- Viewer: `tools/blender-vq2-viewer` (model Poortwachtpost, echte clip Open). Test: `tests/wachtpost_test.gd`.

### Aanvulling (v143): bewaker en sloop

- In het wachthuisje bij de noordpoort zit een wacht die vijanden in de buurt door het raam neerschiet (hij loopt niet meer naar de muur).
- Huisje en slagboom kunnen kapot: kogels van vijanden en explosies beschadigen ze (zie `scripts/wachtpost.gd`). Repareren kan in de wapenkamer.
- v144: ook jouw eigen kogels slopen het huisje (kogels van je soldaten niet).

## Stap 3: generator met stroomuitval (v145)

- In de westhoek van de basis staat een dieselgenerator (`assets/generator.glb`, bron `bron/generator/`, scripts `scripts/generator.gd` en `scripts/generator_body.gd`): draaiende koelventilator (echte clip `Draaien`), trilling en een zacht motorgeluid dat je hoort als je dichtbij bent (`assets/geluid/generator.wav`, uit numpy).
- Hij heeft botsing en kan kapot geschoten of opgeblazen worden: eerst rook, dan vuur, dan een explosie met schade in de buurt en een brandend wrak. Repareren kan in de wapenkamer ("Generator repareren").
- Is hij kapot, dan is de stroom weg (`Game.power = false`): zwaailampen bij de poorten en de straatlantaarns zijn uit. Latere stappen (zoeklichten, radiopost) hangen aan `Game.power`.
- Viewer: `tools/blender-vq2-viewer` (model Generator, clip Draaien, wrak). Tests: `tests/generator_test.gd`.
