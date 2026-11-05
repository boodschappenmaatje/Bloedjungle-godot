# Bloedjungle Terrain 2.0 — A: betere grondtexturen (kleine pilot)

**Status:** uitvoeringsplan; shaderwijziging en Godot-tests volgen nog.  
**Branch:** `feature/terrain-2-0-a-ground-texture-pilot` (afgeleid van `main` op `59c4f71`).  
**Werkafspraak:** Draft PR; geen merge, geen release en geen OTA-publicatie zonder aparte expliciete toestemming.

## Vastgestelde beginsituatie

- `scripts/level.gd::_ground()` maakt één vlakke `PlaneMesh` met een afzonderlijke grondcollider en koppelt `shaders/ground.gdshader`.
- De shader mengt bestaande albedotexturen van `grass`, `jungle_ground`, `dry_earth` en `gravel_rock`, naast bestaande noise-texturen.
- De bronbibliotheek heeft normal- en roughnessmaps, maar de actieve grondshader gebruikt alleen een `dry_earth`-normalmap en stelt `ROUGHNESS = 1.0` in; `specular_disabled` staat aan.
- De shader bevat bestaande paden, oevers, moeras, kampgrond en uitsparingen voor rivier, loopgraven en helikopterplatform. Deze moeten intact blijven.
- Eerdere Draft PR #91 behandelt een veel groter grafisch pakket (58 bestanden); **niet** cherry-picken of samenvoegen in deze pilot.

## Mini-implementatie door Codex — uitsluitend stap A1

1. **Baseline:** maak voor/na vergelijkingen vanuit dezelfde Godot-camera, tijd/weer/kwaliteit en zo mogelijk dezelfde posities bij wachttoren/kamp, bospad en rivier. Noteer oorspronkelijke shaderinstellingen en eventuele waarschuwingen.
2. **Kleine visuele wijziging:** pas **alleen `shaders/ground.gdshader`** aan om het kleurcontrast, de textuurschaal en de gras/aarde-overgangen rustiger en natuurlijker te maken. Gebruik **uitsluitend bestaande texturen en samplers**. Vermijd harde groene/bruine vlekken, herhalende patronen en detailflikkering; behoud het leesbare top-down-schietbeeld.
3. **Niet in A1:** geen heightmap, mesh-/colliderwijzigingen, nieuwe texturen/downloads, extra texture-samplers, 3D-gras, decals, nieuwe shadersystemen, belichting/weer/kwaliteitsprofielen of wijzigingen aan gameplay. De PBR-normal/roughness-uitbreiding komt pas als **aparte volgende microstap A2**, na beoordeling van A1 en met mobile-renderer budget.
4. **Verificatie:** controleer shadercompilatie/Godot-import, start van `scenes/main.tscn`, bestaande grondkanten/uitsparingen, weg-/poortzichtbaarheid, en dat de botsingen, rijroutes en vijanden ongemoeid zijn. Voeg voor/na captures en een korte kostennotitie toe op dezelfde PR.
5. **Prestatiebeoordeling:** geen nieuwe samplers of geometrie in A1; vergelijking op dezelfde renderinstellingen. Native iPhone FPS is leidend, maar **NIET GETEST** totdat werkelijk op een iPhone gemeten. Bij zichtbare shimmer, verlies van leesbaarheid of relevante mobiele FPS-daling: A1 afstellen of terugdraaien.

## Acceptatiecriteria

- Grond oogt minder als een egale groene plaat met bruine geschilderde vlekken; gras, junglegrond en aarde mengen rustiger.
- Geen gewijzigde collisions, navigatie, animaties, bouwlogica, schietschade, jeepbesturing, terrein-hoogte of grondgeometrie.
- Rivier-, loopgraaf- en helipaduitsparingen blijven functioneel en visueel correct.
- Voorgestelde wijziging is eenvoudig terug te draaien, beperkt tot de bestaande ground shader plus deze documentatie/testbewijs.
- Draft PR blijft open voor visuele goedkeuring. **Niet mergen en geen OTA** zonder instructie van gebruiker.

## Codex opdracht

Werk verder op de bestaande branch `feature/terrain-2-0-a-ground-texture-pilot` en de bestaande Draft PR; maak geen nieuwe branch/PR. Lees `AGENTS.md` en dit document. Implementeer uitsluitend A1 (geen A2). Run de beschikbare gerichte Godot/CI-controles, voeg reproduceerbare voor/na screenshots en concrete resultaten toe. Rapporteer eerlijk wat niet kon worden getest. Behoud bestaande gameplay, grafische gebruikersinstellingen en OTA-workflow. Laat de PR in Draft staan.
