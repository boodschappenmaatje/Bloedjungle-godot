# Terrain 2.0 — A2: droge-aarde PBR-proef zonder extra texturen

**Status: uitsluitend plan; nog GEEN gameplay-/shaderwijziging, nog GEEN Godot/iPhone-test.**  
Branch: `feature/terrain-2-0-a2-dirt-pbr-pilot`, afgeleid van `main` op `0802f5a6f8e4d531c6b5ea6aa4ac527c22ecdd75` (6 november 2026).  
Werkregel: Draft PR, **NIET mergen, geen OTA-publicatie** zonder uitdrukkelijke toestemming.

## Code-inspectie (actuele main)

- `scripts/level.gd::_ground()`: één vlakke `PlaneMesh` + afzonderlijke `StaticBody3D`-collider; gebruikt `shaders/ground.gdshader`.
- De shader heeft 8 bestaande sampler2D-uniforms. Kleur/textuur-overgangen uit A1, kamp, paden, modderoevers, moeras, `river`/`pits`/`pad`-uitsparingen blijven leidend.
- `dirt_normal` is **al** gekoppeld aan `assets/textures/terrain/dry_earth/normal_gl.jpg`. `NORMAL_MAP_DEPTH` is `dm * 0.55 * normal_detail`, met een op pixelgrootte gebaseerde afstandsdemping tegen shimmering.
- `dirt_height` is **feitelijk** gekoppeld aan `assets/textures/terrain/dry_earth/roughness.jpg`: één roughnesssample beïnvloedt momenteel het blendmasker als hoogteproxy (`hgt`).
- De shader heeft `render_mode specular_disabled` en `ROUGHNESS = 1.0`. Enkel die roughness-output aanpassen geeft daardoor geen overtuigend zichtbaar PBR-effect zolang specular uit staat.
- De vier aanwezige fotomaterialen `grass`, `jungle_ground`, `dry_earth` en `gravel_rock` hebben allemaal `normal_gl.jpg` en `roughness.jpg` met bestaande VRAM-gecomprimeerde ETC2/ASTC-imports en mipmaps. A2 gebruikt **geen** extra materiaalkaarten.
- `project.godot`: standaard Godot Mobile-renderer, inclusief iOS; `tests/surface_filtering_test.gd` controleert mipmaps/actieve kwaliteitsinstellingen.
- De brede oude Draft PR #91 is **niet** de basis van A2 en mag niet worden gecherry-pickt: die omvat ook nieuwe licht- en materiaallagen.

## Implementatie door Codex: één minimale proef A2.1

**Wijzig functioneel alleen `shaders/ground.gdshader`.** Houd alle algebra van `dm`, kleur, routes, weather, `discard` en bestaande `NORMAL_MAP`-oriëntatie onaangeroerd.

1. Maak de bestaande `dirt_height`-texturelookup lokaal herbruikbaar: lees dezelfde roughnesssample één keer, gebruik hem vervolgens **ongewijzigd** voor de bestaande `hgt`/blendberekening én daarnaast voor `ROUGHNESS`. **Geen extra lookup, nieuwe sampler, asset, import, parameter of shaderuniform.**
2. Stel de materiaalroughness bij voor alleen de zichtbare aardecomponent (`dm`), met het grasmateriaal nagenoeg mat. Begin bij een terughoudende band van ongeveer 0.80–0.98 en voorkom glimmende modder/plastic glans. Laat de lokale roughnessvariatie op afstand afnemen met de al aanwezige `pixel_span`/`micro_detail`-strategie; houd ALBEDO en blending pixel-identiek.
3. Omdat `specular_disabled` roughness zichtbaar blokkeert: maak een **kleine, expliciete proef** waarbij alleen deze grondshader weer speculaire materiaalrespons krijgt, zonder andere licht-, environment- of quality-instellingen te wijzigen. Houd specular zwak en evalueer op Godot Mobile en echte iPhone. Bij significante schittering, shimmering of meetbare GPU-kosten: deze variant **niet doorzetten**; documenteer het als niet haalbaar in A2.1.
4. Houd bestaande `dirt_normal`, `NORMAL_MAP_DEPTH = dm * 0.55 * normal_detail` en `detail_mip_bias` als uitgangspunt. Alleen als de renderbeelden objectief te vlak blijven, is een kleine aanpassing van de **bestaande** normalsterkte toegestaan, binnen dezelfde shader en met een afzonderlijke voor/na-vergelijking. Geen parallax, tessellatie, displacement of nieuwe normalmaps.
5. Geen aanpassing van `scripts/level.gd`, terreinmesh, colliders, voertuigen, NPC, AI, inputs, camera, HUD, schaduwen, weer-, renderer- of kwaliteitsprofielen. Geen wijziging aan `specular_disabled` in andere shaders.

### Expliciet buiten A2.1

- Geen 4/5-laags PBR-systeem of nieuwe gras/jungle/grind-normal- of roughnesslagen: dat vereist meer samplers en vormt een **latere aparte keuze**.
- Geen nieuwe terreinhoogte, greppels, 3D-begroeiing, decals of voet-/bandensporen.
- Geen nieuwe assets, downloads, texture-upscaling of textuurcompressieaanpassingen.

## Bewijs en acceptatie vóór een eventuele merge

1. **Baseline vs A2:** gebruik de echte `scenes/main.tscn`-gamecamera, vaste posities kamp/wachttoren, bospad en rivier/brug; dezelfde seed, FOV, kwaliteit, resolutieschaal, belichting/tijd, weer en frames. Maak voor/na-images op dag/helder/High. Controleer daarnaast rivier en natte bodem bij regen.
2. **Materialen:** aarde heeft subtieler microreliëf bij lichtbeweging zonder plastic reflecties; gras blijft mat, soldaten en vijanden zijn leesbaar. Controleer oriëntatie van `normal_gl` en geen omgedraaide normal. Donkere stroken of specular highlights langs paden zijn een afkeuring.
3. **Veiligheid:** verificatie met statische diff: alleen grondshader + bewijs/testdocumenten wijzigen. Controleer bestaande uitsparingen voor rivier, loopgraven en helipad en het ongewijzigde `dm`-masker; geen aanpassing aan `StaticBody3D` of bewegings-/schietlogica.
4. **Tests:** Godot 4.7.2 import en shadercompile, `tests/surface_filtering_test.gd`, relevante kaart-/rivier-/jeep-/kwaliteitstests en bestaande fixture; vermijd 'groen' als stdout fouten bevat maar proces exit 0. Test met echte Mobile-renderer als beschikbaar; de Compatibility/llvmpipe-captures zijn slechts aanvullende controle.
5. **Shaderbudget:** baseline **8 samplers, 13 texture calls en 3 discard-locaties**; A2.1 streeft aantoonbaar exact hetzelfde aantal nastreef. Geen extra drawcalls, geometrie, resident texture-payload, of viewport-/lichtbronnen toevoegen. Specular-toename wel als mogelijk extra GPU-werk rapporteren.
6. **iPhone (acceptatie voor FPS):** native iPhone-app op dezelfde resolutieschaal, kwaliteit, scène en camera; minstens 3 herhaalde runs met gemiddeld FPS, 1% low en eventueel GPU-frametijd, plus 60 seconden langzaam draaien rond kamp en bospad op shimmering. Bij consistente frametijdtoename van circa 5% of duidelijke shimmer: terugdraaien/afwijzen. **Niet getest** vermelden zolang native data ontbreekt. Geen automatische performanceclaim op basis van desktop/software-renderer.
7. Eerst bewijs aan de Draft PR toevoegen. **Niet mergen en geen OTA-publicatie**, ook niet als alle desktopchecks slagen, totdat de gebruiker de keuze expliciet goedkeurt.

## Codex-opdracht voor het vervolg

Werk op **deze branch en dezelfde Draft PR**. Lees `AGENTS.md`, `docs/terrain_2_0/STEP_A1_GROUND_TEXTURE_PILOT.md` en dit document. Bouw **uitsluitend A2.1** en hergebruik bestaande `dry_earth` normal/roughnessmaps; besteed geen extra texture-samplers. Bewijs vóór/na, gerichte regressies en Mobile-renderer-budget. Rapporteer eerlijk alle nog niet uitgevoerde native iPhone-tests. Laat Draft en **niet mergen**.
