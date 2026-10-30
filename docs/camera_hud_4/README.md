# Tactical Hybrid 4.1 — camera en HUD

Branch: `feature/tactical-hybrid-gameplay-visibility` · [Draft PR #157](https://github.com/boodschappenmaatje/Bloedjungle-godot/pull/157). Geen merge naar main of OTA vanuit deze branch.

## Echte gameplaybeelden

Deze PNG's komen rechtstreeks uit Godot 4.6.3 met de speelbare scène `tests/tactical_hybrid_4.tscn`, op Linux Xorg 1280×720 met OpenGL Compatibility en Mesa llvmpipe. Er is geen beeld gegenereerd of in een editor samengesteld.

- [Begin gevecht: soldaat, M1911, volledige Tiger en twaalf vijanden](41_combat_60.png). Alle twaalf vijandposities projecteerden binnen het scherm.
- [Speler in beweging en schietend](41_combat_120.png). Tien vijandposities projecteerden binnen het scherm; de tank bleef volledig zichtbaar.
- [Camera volgt de speler verder](41_combat_150.png). De speler ging van `(0, 0, -52)` naar `(4,48, 0, -52)` meter, terwijl de camera van ongeveer `x=-0,09` naar `x=3,29` meter volgde.

De scène gebruikt de bestaande Meshy-speler, M1911, Tiger, twee bondgenoten en twaalf levende rifle-vijanden. De vijand-AI en het gewone schietpad van `Player._shoot()` draaien. Voor een reproduceerbare kijkproef heeft de speler in deze scène 10.000 HP, bewegen de vijanden op 45% van hun normale snelheid en staan tank en bondgenoten stil. Dit geldt uitsluitend voor deze testscène. Bij de opname schuift het opnamescript de speler over de grond om cameravolging vast te leggen; de normale touchbesturing is afzonderlijk getest.

## Instellingen

- Camera: 53° boven de horizontaal, 45° FOV, standaard 22,5 m en gevechtsstand 20 m. Bij een nabije tank of meerdere bondgenoten kiest de camera een bredere uitsnede; hij scant per 0,4 s, houdt de groep 2 s vast en zoomt langzamer terug. Bewust handmatig inzoomen via pinch of muiswiel krijgt voorrang.
- Zichtbaarheid: normale soldaatschaal, selectiering en richtingstreep, minder felle dagbelichting en kleine gezondheidsstrepen boven verre vijanden. De strepen volgen de instelling `markeringen` en gebruiken geen extra realtime licht.
- HUD: compacte zwart-gouden statusbalk, radar, wapenkaart en actiecluster. De getekende sticks zijn kleiner, terwijl hun aanraakzones 76 logische punten blijven. De iPhone-schaalfactor gebruikt circa 500 logische punten schermhoogte.
- Texturen: de reeds in de GLB aanwezige PBR-afbeeldingen van Tiger, Meshy-soldaat en M1911 worden als Basis Universal in Godot ingebed (`gltf/embedded_image_handling=2`). Er zijn geen nieuwe Meshy-generaties of modelbestanden.

## Xogot op iPhone 18 Pro Max

1. Open `boodschappenmaatje/Bloedjungle-godot` in Working Copy en kies branch `feature/tactical-hybrid-gameplay-visibility`. Haal de nieuwste commit op.
2. Open die checkout in Xogot als Godot-project via `project.godot`. Laat Xogot de eerste assetimport afronden.
3. Open `tests/tactical_hybrid_4.tscn`, houd de iPhone liggend en kies **Run Current Scene**. Deze scène zet de Meshy-soldaat en markeringen alleen voor deze sessie aan; opgeslagen instellingen blijven behouden.
4. Controleer links bewegen, rechts richten en schieten, herladen, Sprint tikken en vasthouden voor de rol, het wapen kiezen en pinch-zoom buiten de knoppen en sticks. Kijk of de volledige tank en vijanden zichtbaar blijven terwijl je langs de tank loopt.
5. Open voor een gewone missie `scenes/main.tscn`. Zet zo nodig de FPS-weergave aan in **Instellingen** en maak een opname tijdens beweging en gevecht. Alleen zo kan de FPS op dit toestel worden beoordeeld.

Deze branch verschijnt niet via de bestaande OTA-updateknop; Xogot moet het branchproject zelf openen.

## Controles en grenzen

Lokaal met Godot 4.6.3 geslaagd: `tests/tactical_material_check.gd` (25 getextureerde tankoppervlakken, 1 Meshy-soldaat, 2 M1911, 22 VQ2-soldaat), `camera_test.gd`, `hud_layout_test.gd`, `combat_visuals_test.gd`, `stick_test.gd` en `meshy_player_integration_test.tscn`. `tank_mik_test.gd` eindigde met exitcode 0. De opname had geen scriptfouten. De headless runner meldt bij afsluiten nog de bestaande waarschuwing over 11 resources.

De opnamescriptmeting `Performance.TIME_PROCESS` was gemiddeld **399,891 ms over 91 frames** op Mesa llvmpipe bij 1280×720. Dit is een Linux-softwaremeting met twaalf vijanden en zegt niets betrouwbaars over de iPhone GPU. **iPhone 18 Pro Max FPS: NIET GETEST.** De eis van geen grote FPS-terugval op het toestel kan daarom pas met de Xogot-test worden bevestigd.
