# Assault HQ 2.0 — rigging- en wapentest

Status: technische featurebranch-proef. Deze commit is niet gemerged en er is geen OTA-patch gepubliceerd.

## Bronmodel en rig

- Origineel uiterlijk: `source_assets/enemy_assault/export_Meshy_AI_2026-11-02_d5efc0.glb`.
- SHA-256: `4a730abf9e1bdfe38496e09d51a269ec99ffad07b6fdfbb82e558c511ee92803`.
- Bronbestand: 127.543.360 bytes. Het bestand blijft lokaal onder `source_assets/` en is niet in Git opgenomen.
- Technische basis: `assets/meshy_jungle_commando.glb`, Mixamo met 28 botten. Er is geen zichtbaar spelerdeel in de Assault-GLB opgenomen.
- De nieuwe body behield zijn eigen Meshy-mesh en PBR-set. De Blender-tool bracht gewichten over met een ruimtelijke nearest-4-sample van de bestaande Meshy-skin, normaliseerde ze en begrensde ze tot maximaal vier invloeden per vertex.
- In het ongereduceerde rigtestmodel zijn 1.777.586 bodyvertices en 3.296.450 bodytriangles gewogen. De 79 losse Meshy-geweercomponenten zijn uit de skinned body gehaald; het brongeweer zelf had 83.996 vertices en 158.446 triangles.

## Meshy-geweer en schietsysteem

Het Meshy-geweer staat als apart, star propmodel in de GLB en is het enige zichtbare geweer van de Assault. Het wordt via `WeaponModelAdapter.configure_existing_meshy()` losgemaakt van de bodymesh. De adapter gebruikt de nieuwe markers `Assault_RightHandGrip`, `Assault_LeftHandGrip`, `Assault_Muzzle`, `Assault_CasingEject`, `Assault_Magazine` en `Assault_Sight`. De twee arm-IK-ketens volgen de handgrepen; de loopmondmarker levert de projectielstart en de hulzenmarker de uitwerpplaats.

De bestaande vijandelijke `Enemy._shoot()` en `Bullet`-route blijven de gameplay leveren. `Data.ETYPES.assault` gebruikt de bestaande standaard-riflebalans (7 schade, 1,6 s tussen aanvallen, spreiding 0,08); Garand-effecten en tracers blijven via de bestaande rifle/Garand-selectie lopen. Het vijandensysteem heeft momenteel geen magazijnteller of automatische herlaadcyclus. De testbare `herladen`-actie verplaatst wel de linkerhandgreep naar het Meshy-magazijn en terug; dit is geen AI-munitieherlaadfunctie.

Er is geen bestaande vuurclip gevonden die tegelijk bij deze Meshy-ankers past. Daarom wordt `schieten` voor de Assault gekoppeld aan de bestaande rusthouding. De Assault houdt het geweer vast, de bestaande projectielcode vuurt vanaf de Meshy-loopmond en de losse mesh krijgt zichtbare terugslag. `Rifle_Aim_Turn_Right` is beschikbaar en verandert het skelet, maar is niet als Assault-vuurhouding geselecteerd omdat de hand- en wapenfit daarvoor niet is goedgekeurd.

## Mobiele runtimeasset

Runtimebestand: `assets/enemies/assault/assault_meshy_hq2_runtime.glb`.

| LOD | Bodytriangles | Geweertriangles | Totaal |
| --- | ---: | ---: | ---: |
| LOD0 | 11.999 | 1.800 | 13.799 |
| LOD1 | 3.500 | 700 | 4.200 |
| LOD2 | 1.400 | 300 | 1.700 |

Godot valideerde drie geskinte bodymeshes en drie ongeskinte geweermeshes, alle met één gedeeld materiaal. De runtime-GLB is 3.600.908 bytes (3,43 MiB), SHA-256 `be2e3cbda4eaace34ddeedfca078539376f5446020923b2046ba6e787d36d1d8`. De ingesloten PBR-texturen zijn teruggebracht naar 2K base color, 2K normal en 1K roughness/metallic. Godot maakte bij import drie afgeleide JPG-sidecars (samen 2.127.345 bytes); die zijn opnieuw uit de GLB te genereren.

LOD-afstanden in de SoldierModel: LOD0 tot 18 m, LOD1 van 18–36 m, LOD2 vanaf 36 m. Dit is in headless Godot op de ingestelde `visibility_range`-waarden gecontroleerd; een GPU-rendercapture van de overgangen is hier niet beschikbaar.

De mobiele asset gebruikt Blender Decimate voor de LOD-reductie en hergebruikt de bron-UV's en PBR-texturen. Er is voor deze proef geen handmatige retopologie of nieuwe normal-map-bake uitgevoerd.

## Animaties en gedrag

Beide bestaande bibliotheken zijn beschikbaar: 13 aanvullende clips plus 62 geretargete Meshy-API-clips (75 bronclips). De clips blijven inspecteerbaar via `tools/enemy_assault/list_animation_clips.gd`.

Godot controleerde dat de botpose verandert voor `Walking`, `Rifle_Aim_Turn_Right` en `dying_backwards`. De geïntegreerde Assault-test controleerde daarnaast de idle-/stilstaande-vuurhouding, de Meshy-handgrepen, projectielspawn, zichtbare geweerterugslag, herlaadgreep en het volledig afspelen van `dood1`. `enemy.gd` gebruikt de bestaande Assault-AI en de eerste golf bevat een Assault.

Niet alle 75 clips zijn visueel op het Assault-model nagekeken. Alleen geschikte clips worden door de Assault-AI gebruikt; een compatibele aim-fireclip, AI-magazijnbeheer en automatische AI-herlading blijven open werk.

## Uitgevoerde controles

- Blender 4.3.2: rigtest-GLB met 28 botten, nieuw Meshy-uiterlijk, afgescheiden geweer en genoemde anchors geëxporteerd. De bestaande speler is alleen als gewicht-/armaturebron gelezen.
- Godot 4.6.3 headless: runtime-import en rig/PBR/LOD-controle geslaagd. De gevraagde Godot 4.7.2 was in deze omgeving niet beschikbaar.
- `tests/assault_weapon_test.tscn`: geslaagd. IK-signaalafwijking bij idle/vuren: circa 5,8 mm rechts en 8,5 mm links. Tijdens terugslag: circa 0,6 mm rechts en 2,1 mm links; geweerterugslag 5,35 cm. Eén projectiel werd door de bestaande schietroute aangemaakt. Herlaadgreep bewoog naar het magazijn en terug. `dood1` speelde volledig af.
- `tools/enemy_assault/validate_rig.gd`: geslaagd; één skelet, 28 botten, drie skinned body-LOD's, drie statische geweer-LOD's en één gedeeld PBR-materiaal.
- `tools/enemy_assault/test_animation_clips.gd`: geslaagd voor de drie genoemde poseproeven.
- `tests/assault_type_test.gd`: geslaagd; klasse-ID, rifleconfiguratie en Assault-aanwezigheid in golf 1 gecontroleerd.
- `tests/meshy_player_integration_test.tscn`: geslaagd; bestaande Meshy-spelerintegratie en spelerammunitie bleven werken. De bestaande test meldt ook de bekende Garand-ankerbeperking in prone reload; dat is niet door deze Assault-wijziging veroorzaakt.
- `tests/smoke_test.gd`: headless golf-1-run eindigde na 85 gesimuleerde seconden in game over; de Assault verscheen in de golf en bewoog mee met de vijand-AI.
- Blender CPU-captures staan in `captures/`. Dit zijn twee camerahoeken van de gerigde rust-/wapenhouding, geen Godot- of iPhone-captures.

Er zijn geen FPS-, P99-frametime-, drawcall- of geheugencijfers gemeten. De headlessrenderer heeft geen echte GPU/display; prestaties en uiteindelijke visuele beoordeling moeten op Godot 4.7.2 en de iPhone 18 Pro Max worden gecontroleerd.

## Reproduceren

Met de originele GLB lokaal aanwezig:

```sh
blender -b --python tools/enemy_assault/rig_enemy_assault.py -- source_assets/enemy_assault/export_Meshy_AI_2026-11-02_d5efc0.glb source_assets/enemy_assault/rig_test/enemy_assault_meshy_weapon_rigged_test.glb
blender -b --python tools/enemy_assault/build_assault_mobile_lods.py -- source_assets/enemy_assault/rig_test/enemy_assault_meshy_weapon_rigged_test.glb assets/enemies/assault/assault_meshy_hq2_runtime.glb
godot --headless --path . -s tools/enemy_assault/validate_rig.gd
godot --headless --path . res://tests/assault_weapon_test.tscn --fixed-fps 60
```

De originele 127,5 MB GLB en de circa 156 MB rigtest-GLB zijn niet in de featurecommit opgenomen. Deze fase is op de featurebranch gebleven; merge en OTA zijn niet uitgevoerd.
