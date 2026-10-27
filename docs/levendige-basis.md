# Levendige legerbasis

Stappen die de basis levendiger maken (keuze van Dennis, 2026-10-27). Elke stap is een eigen Draft PR.

## Stap 1 (v140): patrouilles en alarm
- `scripts/patrouille.gd` (`Patrouille`, in `main.gd`): drie wachten (gewone `Ally`-soldaten met `guard = true`, niet in `Game.allies`, dus onafhankelijk van de kazerne).
- Pauze (`Game.state == "prep"`): ze wandelen heen en weer langs de binnenkant van de noord-, zuid- en westmuur (`Patrouille.line(i)`), blijven 3 tot 6 s op het eindpunt staan en keren om.
- Begint een golf: sirene (8 pieptonen, afwisselend `claxon` en `alarm`) en de wachten rennen naar hun post langs de muur (`Ally.POSTS`), waar ze op vijanden schieten zoals andere soldaten.
- Test: `tests/patrouille_test.gd`. Opnames: `tests/patrouille_foto.gd` (spelcamera). Geen nieuwe modellen, dus geen VQ2-assets. Geen iPhone-meting.
