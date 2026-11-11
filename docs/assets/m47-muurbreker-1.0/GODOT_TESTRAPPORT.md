# M-47 Godot 4.7.2 testresultaten

Getest met **Godot 4.7.2.stable.official.ed1daf0bf**. De assettest, root-projectimport en de drie gevraagde regressietests zijn lokaal geslaagd. Er zijn geen gameplay- of grafische instellingen gewijzigd.

## Oorzaak en herstel van de rootimport

De vorige macOS CI-run [42391046748](https://github.com/boodschappenmaatje/Bloedjungle-godot/actions/runs/42391046748) liet zien dat Godot de M-47-review-GLB en `M47_Muurbreker_Blender_1.0.blend` onder `docs/` als projectassets scande. De headless-runner had geen Blender-pad en meldde `Blender path is invalid or not set`; daarna ontbraken geïmporteerde texturen en GLB-scenes, waarna onder meer `surface_filtering_test.gd` faalde met vijf ontbrekende `.ctex`-mipmaps. De root-importcache was dus onvolledig doordat reviewbestanden buiten de runtime-assets werden meegeïmporteerd.

De M-47-map in `docs/assets/m47-muurbreker-1.0/` bevat review- en bronbestanden, geen runtime-assets. `.gdignore` markeert die map nu als documentatie, zodat de headless-runner de BLEND niet hoeft te openen. Voor lokale Blender-import is het lege `filesystem/import/blender/blender_path` ingesteld op `/usr/bin/blender` (Blender 4.3.2); dit is alleen een gebruikersinstelling. De originele M-47-bronnen zijn niet gewijzigd.

Daarna is een volledige import uitgevoerd:

```sh
Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path . --import
```

De lokale cachebouw eindigde met exitcode **0** en leverde 107 geïmporteerde scenes. Bij `assets/brandkraan.glb` logt Godot daarbij 12 bestaande `Basis ... must be normalized ... Quaternion`-regels. Diezelfde regels komen voor bij import van de ongewijzigde `brandkraan.glb` op `main`; ze staan los van M-47. De vorige CI-run meldde daarnaast cache-afhankelijke VQ2-textuurfouten. De repository-workflow primeert de cache vóór de validatiepass. Na `.gdignore` eindigde de tweede featurebranch-import met exitcode **0**, 107 scenes en **0** `ERROR`/`SCRIPT ERROR`-regels.

De nieuwe [macOS CI-run 42395675534](https://github.com/boodschappenmaatje/Bloedjungle-godot/actions/runs/42395675534) op PR #238 slaagde voor `Prime Godot asset import cache`, `Import and validate project`, `Export iOS project` en artifact-upload. Daarmee is de ontbrekende Blender-path blokkade uit [run 42391046748](https://github.com/boodschappenmaatje/Bloedjungle-godot/actions/runs/42391046748) verholpen. De CI- en artifactcontroles staan samengevat in [`logs/github_actions_42395675534.log`](logs/github_actions_42395675534.log). De importvergelijking staat in [`logs/godot_4.7.2_import_comparison.log`](logs/godot_4.7.2_import_comparison.log); de lokale schone featurebranch-herimport staat in [`logs/godot_4.7.2_root_import.log`](logs/godot_4.7.2_root_import.log).

## M-47 assetcontrole — PASS

De geïsoleerde testscene rapporteert **32 PASS** en `M47_GODOT_TEST PASS`:

- Geanimeerde GLB importeert als `PackedScene` met `AnimationPlayer`.
- `Idle`, `Equip`, `Aim`, `Fire` en `Reload` importeren en lopen vooruit.
- LOD0, LOD1 en LOD2 hebben albedo, normal, roughness en metallic uit de originele PBR-kaarten.
- Afmetingen en X-asoriëntatie komen overeen met de bron; de spelerhanden en montagepositie worden gecontroleerd.
- Op 2 m, 8 m en 20 m is telkens precies één LOD actief.
- Screenshot: [`m47_godot_4_7_2.png`](../../../tests/m47_godot/screenshots/m47_godot_4_7_2.png).
- Volledige uitvoer: [`logs/godot_4.7.2_m47_asset_validation.log`](logs/godot_4.7.2_m47_asset_validation.log).

## Bestaande regressies — PASS

| Test | Resultaat |
| --- | --- |
| `tests/combat_bazooka_aim_test.gd` | Exit 0; `COMBAT BAZOOKA AIM TEST PASS` |
| `tests/wapen_clips_test.gd` | Exit 0 met de voorgeschreven `--fixed-fps 60`; `WAPENCLIPS TEST OK` |
| `tests/base_wall_hq2_test.gd` | Exit 0; `BASE WALL HQ2 TEST PASS (0 failures)` |

De volledige featurebranch-logs en de uitkomsten van de drie tests vanuit de detached `main`-worktree staan in [`logs/`](logs/). De lokale main-testvergelijking gebruikte dezelfde geïmporteerde GLB-cache om verschillen in testscripts en gameplaycode te controleren; de officiële main-workflow is de onafhankelijke CI-baseline. Godot rapporteert bij het afsluiten enkele bestaande resource/ObjectDB-opruimwaarschuwingen. Alle drie assertions slagen op beide commits met dezelfde vaste tijdstap. De relevante test-, gameplay- en assetbestanden verschillen niet van `main`. De bestaande [iOS workflow op main, run 42247986984](https://github.com/boodschappenmaatje/Bloedjungle-godot/actions/runs/42247986984) slaagde ook bij `Import and validate project`.

## iOS export

De officiële Godot 4.7.2 iOS-exporttemplate is geïnstalleerd op `~/.local/share/godot/export_templates/4.7.2.stable/ios.zip`. De lokale Linux-export maakte het Xcode-project maar kon geen IPA bouwen omdat `xcodebuild` daar ontbreekt. De bestaande workflow bouwde en valideerde op `macos-26` de unsigned IPA: CI meldt `** BUILD SUCCEEDED **`, controleert de IPA-zip zonder fouten en vindt `Payload/Bloedjungle-ios.app/Info.plist`. Het artifact `bloedjungle-ios-unsigned-57822ee1ad3a410b7e461414d7262712c23da17e` is geüpload (1.144.244.995 bytes); `godot-diagnostics-57822ee1ad3a410b7e461414d7262712c23da17e` bevat de CI-logs. Beide artifacts staan bij [run 42395675534](https://github.com/boodschappenmaatje/Bloedjungle-godot/actions/runs/42395675534). Er is geen installatie op een fysiek iPhone uitgevoerd.

## Reproduceerbare commando's

```sh
Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path . --import
Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . -s tests/combat_bazooka_aim_test.gd --quit-after 1000
Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . -s tests/wapen_clips_test.gd
Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . -s tests/base_wall_hq2_test.gd
```
