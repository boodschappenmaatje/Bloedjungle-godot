# M-47 Godot 4.7.2 testresultaten

Getest met **Godot 4.7.2.stable.official.ed1daf0bf**. De assettest, root-projectimport en de drie gevraagde regressietests zijn lokaal geslaagd. Er zijn geen gameplay- of grafische instellingen gewijzigd.

## Oorzaak en herstel van de rootimport

De lokale Godot-editorinstelling `filesystem/import/blender/blender_path` was leeg. Daardoor kon Godot Blender-bronbestanden niet via een ingesteld Blender-pad verwerken. In de gebruikersinstellingen is het pad gezet op `/usr/bin/blender` (Blender 4.3.2). Dit is alleen een lokale editorinstelling; geen projectinstelling.

De M-47-map in `docs/assets/m47-muurbreker-1.0/` bevat review- en bronbestanden, geen runtime-assets. Zonder uitsluiting probeerde de rootimport onder andere de review-BLEND te verwerken en zocht die naar niet meegeleverde losse afbeeldingen. Het bestand `.gdignore` markeert die map nu als documentatie. De originele M-47-bronnen zijn niet gewijzigd.

Daarna is een volledige import uitgevoerd:

```sh
Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path . --import
```

De lokale cachebouw eindigde met exitcode **0** en leverde 107 geïmporteerde scenes. Bij `assets/brandkraan.glb` logt Godot daarbij 12 bestaande `Basis ... must be normalized ... Quaternion`-regels. Diezelfde regels komen voor bij import van de ongewijzigde `brandkraan.glb` op `main`; ze staan los van M-47. Een koud, geïsoleerd main-cache-experiment op lokaal Linux gaf ook VQ2-textuurmeldingen; die scratch-run bleef lokaal noisy en geldt niet als CI-baseline. De repository-workflow voert eerst een cache-primeerpass en daarna een validatiepass uit; de officiële main-run slaagde voor beide. De officiële [main-run 42247986984](https://github.com/boodschappenmaatje/Bloedjungle-godot/actions/runs/42247986984) slaagde voor beide importstappen en de iOS-export. Na de cache-primeerpass eindigde de tweede featurebranch-import met exitcode **0**, 107 scenes en **0** `ERROR`/`SCRIPT ERROR`-regels. Met `.gdignore` verschijnen geen M-47-reviewbestanden in de rootimport. De vergelijking staat in [`logs/godot_4.7.2_import_comparison.log`](logs/godot_4.7.2_import_comparison.log); de schone featurebranch-herimport staat in [`logs/godot_4.7.2_root_import.log`](logs/godot_4.7.2_root_import.log).

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

De officiële Godot 4.7.2 iOS-exporttemplate is geïnstalleerd op `~/.local/share/godot/export_templates/4.7.2.stable/ios.zip`. De lokale Godot-exportstap genereert het Xcode-project. Deze Linux-omgeving heeft geen `xcodebuild`, waardoor hier geen IPA kan worden gebouwd. De bestaande [iOS unsigned IPA workflow](../../../.github/workflows/ios.yml) voert op `macos-26` de Godot-import, regressies, unsigned Xcode-build en IPA-validatie uit. De workflow wordt na push van deze PR-update gecontroleerd; de CI-run en het IPA-artifact worden daarna hier toegevoegd.

## Reproduceerbare commando's

```sh
Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path . --import
Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . -s tests/combat_bazooka_aim_test.gd --quit-after 1000
Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . -s tests/wapen_clips_test.gd
Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . -s tests/base_wall_hq2_test.gd
```
