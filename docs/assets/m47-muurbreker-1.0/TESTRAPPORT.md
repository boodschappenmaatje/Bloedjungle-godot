# M-47 Muurbreker Blender 1.0 — testrapport

**Resultaat:** Blender-productie, GLB-validatie en de 32 geïsoleerde Godot 4.7.2-assetcontroles zijn geslaagd. De bazooka-, wapenclips- en HQ2-muurregressies slagen. De bestaande macOS-workflow bouwde en valideerde een unsigned iOS-IPA in [CI-run 42395675534](https://github.com/boodschappenmaatje/Bloedjungle-godot/actions/runs/42395675534); het IPA- en Godot-diagnosticsartifact zijn daar beschikbaar.

## Invoer en onveranderlijk origineel

`M47_Muurbreker_original.glb` is de ongewijzigde GLB uit de opgegeven Drive-map. De Blender-pipeline importeert deze GLB in een nieuwe scene. Het originele meshobject blijft als verborgen referentie behouden; LOD's worden op aparte kopieën gemaakt. De originele BLEND is niet geopend.

## Geometry en PBR

| Onderdeel | Driehoeken | UV | Materiaal |
| --- | ---: | --- | --- |
| Origineel | 631.206 | aanwezig | `Material_0` |
| LOD0 | 50.000 | behouden | `Material_0` |
| LOD1 | 25.000 | behouden | `Material_0` |
| LOD2 | 9.999 | behouden | `Material_0` |
| Draaiende kern | 92 | — | apart metallic staal |
| Laadkamer (testonderdeel) | 12 | — | apart metallic staal |

De drie originele, ingebedde 2048×2048 kaarten zijn gecontroleerd na GLB-herimport: `Image_0` albedo/base color, `Image_1` packed ORM (groen → roughness, blauw → metallic) en `Image_2` normal map. Alle drie zijn in de export ingebed. De originele en LOD0 Cycles-renders zijn onder dezelfde camera en belichting vergeleken; silhouet, UV/PBR-detail en goedgekeurde materiaalindruk blijven visueel behouden. Renders zijn previews zonder denoising, wegens ontbrekende OpenImageDenoise in deze Blender-build.

## Animaties

De laadkamer en kern zijn aparte testgeometrie; de originele mesh is niet opgesplitst of beschadigd. De GLB bevat vijf clips met bonekanalen voor root, kern en/of laadkamer:

| Clip | Lengte | Beweging gecontroleerd |
| --- | ---: | --- |
| Idle | 48 frames | kernrotatie en kleine laadkamerbeweging |
| Equip | 36 frames | root positionering en kernrotatie |
| Aim | 30 frames | root positionering en kernrotatie |
| Fire | 18 frames | root-terugslag, kernrotatie, laadkamerslag |
| Reload | 60 frames | laadkamerslag en kernrotatie |

## Uitgevoerde controles

- Blender 4.3.2 batch: source GLB import, LOD-generatie, Cycles PBR-renders, animatie-opbouw, GLB-export.
- Herhaalbare scripts vanaf de repositorybron uitgevoerd: `build_lods_and_renders.py`, daarna `rig_animations_and_export.py`.
- Geëxporteerde GLB opnieuw geïmporteerd in Blender; `validation.json` bevestigt vijf werkelijk bewegende acties, de genoemde driehoektellingen, één PBR-materiaal op de LOD's en ingebedde textuurkaarten.
- Screenshots: `screenshots/pbr-original.png`, `screenshots/pbr-lod0.png`, plus `idle.png`, `equip.png`, `aim.png`, `fire.png`, `reload.png`.
- Godot 4.7.2 `ed1daf0bf`: geïsoleerde M-47-import/PBR/LOD/animatie/montagecontrole **32 PASS**; de drie gevraagde root-projectregressies en de macOS iOS-workflow slagen. Details en logs staan in [GODOT_TESTRAPPORT.md](GODOT_TESTRAPPORT.md) en [`logs/`](logs/).

## Artefacten

- `M47_Muurbreker_Blender_1.0.blend` — bewerkbare scene met referentie, LOD's, rig en actions.
- `M47_Muurbreker_1.0_animated.glb` — geanimeerde glTF met LOD0–2 en vijf clips.
- `validation.json` — Blender-herimportcontroles.
- `build_lods_and_renders.py`, `rig_animations_and_export.py` — batchproductiescripts.
- `M47_Muurbreker_original.glb` — ongewijzigde bronreferentie.

## Godot 4.7.2, regressies en iOS-export

De volledige rootimport, cache-oorzaak, drie regressies, iOS-template en exportstatus zijn vastgelegd in [GODOT_TESTRAPPORT.md](GODOT_TESTRAPPORT.md). De lokale Godot 4.7.2-uitvoeringslogs staan in [`logs/`](logs/). De testscene met de echte VQ2-speler en handbotten staat in `tests/m47_godot/`.
