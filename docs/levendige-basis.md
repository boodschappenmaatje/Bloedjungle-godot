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
