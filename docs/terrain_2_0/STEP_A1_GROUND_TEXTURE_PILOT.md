# Bloedjungle Terrain 2.0 — A: betere grondtexturen (kleine pilot)

**Status:** A1-pilot uitgevoerd; visuele beoordeling in Draft PR #231 open.
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

## A1-resultaat (5 november 2026)

Alleen `shaders/ground.gdshader` is functioneel gewijzigd. De bestaande gras- en aardefoto's schalen iets groter; de kleurschommelingen van gras, droge plekken en bladstrooisel zijn kleiner. Kleine, scherpe moddervlekken zijn teruggedrongen en de overgang is breder. Paden, kampgrond, oevers, moeras en alle `discard`-uitsparingen volgen dezelfde bestaande formules. Samplers, mesh en collider zijn niet uitgebreid. De bestaande `detail_mip_bias`, mipmapfiltering en afstandsdemping blijven actief; een bewegende mobiele camera is niet getest op shimmer.

### Vergelijking

De [reproduceerbare capturetest](../../tests/terrain_a1_capture.gd) gebruikt `scenes/main.tscn`, de echte spelcamera met vaste helling van 53° en afstand van 28 m, een vaste seed, 1280×720, 60 vaste frames/s, dag/helder/kwaliteit hoog/wind uit. `before` is commit `0b5e0df`; `after` is dezelfde branch met alleen de A1-shaderaanpassing. Beide reeksen zijn opgenomen met Godot 4.6.3, OpenGL Compatibility op Mesa llvmpipe. De native Mobile-renderer en iPhone zijn hiermee niet beoordeeld.

| Plek | Voor | Na | Naast elkaar |
| --- | --- | --- | --- |
| Wachttoren/kamp en noordpoort | [PNG](captures/before/kamp.png) | [PNG](captures/after/kamp.png) | [JPG](captures/compare/kamp.jpg) |
| Bospad | [PNG](captures/before/bospad.png) | [PNG](captures/after/bospad.png) | [JPG](captures/compare/bospad.jpg) |
| Rivier en brug | [PNG](captures/before/rivier.png) | [PNG](captures/after/rivier.png) | [JPG](captures/compare/rivier.jpg) |

Reproductie na een Godot-import (met een werkende grafische display):

```bash
TERRAIN_A1_OUT=/tmp/terrain-a1/after DISPLAY=:99 BJ_INSTANT=1 godot \
  --rendering-driver opengl3 --path . -s tests/terrain_a1_capture.gd \
  --resolution 1280x720 --fixed-fps 60
```

Voor de baseline: voer dezelfde opdracht uit op commit `0b5e0df` met de capturetest overgenomen en `TERRAIN_A1_OUT=/tmp/terrain-a1/before`.

### Controles en kosten

- De Godot-editorimport eindigde met exitcode 0. De gerenderde `main.tscn`-beelden leverden geen `SHADER ERROR`, scriptfout of parsefout op. Godot meldde bij de Compatibility-renderer waarschuwingen over screen-space AA en depth of field en bij afsluiten resourcelekken.
- Gericht: `surface_filtering_test`, `poort_test`, `poort_auto_test`, `kwaliteit_test`, `jeep_respawn_feedback_test` en `vijand_m2_toren_test` slaagden. Zo zijn oppervlakfiltering, poorten, instellingen, jeep en vijanden afzonderlijk gecontroleerd.
- De algemene testwrapper voert ook `team_commands_fixture` uit. Daar slaagde de controller voor 68 checks, maar `hud_wheel_test.tscn` kon niet compileren wegens ontbrekende typen `ArtillerieAim` en `Artillerie`. Deze assetvrije fixture staat buiten A1; de wrapper is daarom **niet volledig groen**.
- Geen nieuwe samplers, geometrie of extra texture-lookups in A1. De extra GPU-kosten zijn daarom naar verwachting verwaarloosbaar, maar er is geen mobiele frametijd gemeten. Native iPhone FPS en touchgedrag: **NIET GETEST**.
