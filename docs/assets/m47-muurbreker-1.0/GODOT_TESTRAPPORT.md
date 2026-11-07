# M-47 Godot 4.7.2 testresultaten

## Geïsoleerde assettest — PASS

Getest met **Godot 4.7.2.stable.official.ed1daf0bf**, gedownload van de officiële Godot GitHub-release. De aparte Godot-testprojectmap laadt de GLB via een symlink rechtstreeks uit de bestaande PR-map. De scene verandert geen game-scene, gameplayscript of grafische projectinstelling. Screenshot: [`m47_godot_4_7_2.png`](../../../tests/m47_godot/screenshots/m47_godot_4_7_2.png).

32 controles PASS:

- Animated GLB laadt als `PackedScene`; bevat `AnimationPlayer`.
- `Idle`, `Equip`, `Aim`, `Fire`, `Reload` zijn aanwezig en elke clip speelt/loopt vooruit.
- LOD0, LOD1 en LOD2 laden elk met albedo, normal, roughness en metallic-texture.
- Geïmporteerde bounds/orientatie zijn circa **1,9 × 0,7 × 0,4 m**, met lengte langs de X-as.
- Afstandsselector bij 2 m, 8 m en 20 m toont telkens exact één LOD. De testscene blijft de actieve LOD op camerafstand selecteren.
- De bestaande `soldaat_vq2.glb` met echte `DEF-handR`/`DEF-handL` bones laadt. De M-47-proefmontage is 0,72 schaal en staat binnen 0,25 m van het werkelijke handbotten-middelpunt. Dit is een geïsoleerde previewmount, geen gameplay-integratie.
- Screenshot gerenderd met Xorg dummy display en Mesa llvmpipe/OpenGL compatibility.

Herhalen:

```sh
cd tests/m47_godot
Godot_v4.7.2-stable_linux.x86_64 --headless --editor --import --quit
DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 Godot_v4.7.2-stable_linux.x86_64 --rendering-method gl_compatibility
```

## Bestaande regressies

- `tests/combat_bazooka_aim_test.gd`: procesexit **0**, eindassertie `COMBAT BAZOOKA AIM TEST PASS`. De draai rapporteert tegelijk bestaande hoofdscene-fouten door niet gebouwde GLB-importcache (`has_animation` op null, ontbrekende actor-node en `Wiel_LV`-sleutels). Daarom is dit een PASS van de testasserties, maar geen schone runtime-regressie.
- `tests/wapen_clips_test.gd`: **FAIL, exit 6**. Geïmporteerde wapen-scènes zijn null in deze root-projectrun; Trench- en MG42-bewegingscontroles lezen daardoor 0 m.
- `tests/base_wall_hq2_test.gd`: **FAIL / geblokkeerd**. Drie export/PBR-configuratieasserties slagen, maar `assets/base_wall_hq2.glb` kan niet als `PackedScene` worden geladen omdat `.godot/imported/base_wall_hq2.glb-….scn` ontbreekt. De root-projectimport leverde geen geïmporteerde scene-cache op; er zijn geen muurassets of muurcode gewijzigd.

## iOS-export

De root-presets bevatten een iOS-preset. De Godot 4.7.2-exportpoging faalde: de exporttemplate ontbreekt op `~/.local/share/godot/export_templates/4.7.2.stable/ios.zip`; daarnaast meldt de headless root-export een niet ingestelde Blender-editorpad. Er is geen IPA gemaakt. Geen Xcode-export of fysieke iPhone-test geclaimd.
