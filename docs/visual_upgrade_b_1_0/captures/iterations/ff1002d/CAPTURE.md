# Echte Godot-captures — gerichte terrein-/foliagepass

- Codecommit: `ff1002deb27e081e53c426672bcf6851b2f445b4` (shader/understorypass: `8d1ed47`)
- Godot Actions-run: [42460199664](https://github.com/boodschappenmaatje/Bloedjungle-godot/actions/runs/42460199664), geslaagd
- Artifact: `13609722999` (PNG's en ruwe meetdata; 28.055.608 bytes)
- Engine: Godot 4.7.2.stable.official, Mobile / Forward Mobile, Vulkan 1.4.318
- Adapter: llvmpipe (LLVM 20.1.2, 256 bits), Linux-software-rendering; geen fysieke GPU
- Uitvoer: 1280×720, render scale 100%, High, dag, helder weer, MSAA 2; bestaande hoofdscene en cameracamera (`main.tscn`, ongewijzigde `Camera`-rig), FOV 45°, camera-pitch 53°; deterministische seed 20261106
- Locaties: bospad `(7, 0, -57)`, rivier `(14, 0, -80)`, kamp `(-20, 0, -32)`, combatspeler `(0, 0, -44)` met 80 vijanden
- PNG's zijn rechtstreeks door `tests/visual_b_capture.gd` uit de actieve Godot-renderer opgeslagen. Niet AI-gegenereerd of nabewerkt. `metrics.json` bevat software-renderdiagnostiek, geen telefoonbenchmark.

## Visuele beoordeling

De terreinshader geeft de gras-/grondmix en de padschouders wat meer breakup, en de foliagegroepen zijn losser geschaald/geplaatst zonder de aantallen te verhogen. In deze echte renders zijn de grote open grondvlakken echter nog steeds vlak en groen-bruin egaal; het pad blijft een vrij smalle, uniforme baan; lage foliage herhaalt dezelfde rozet-/varen-silhouetten en maakt aan de randen een dichte band. Bij de rivier oogt het water vlak en een brede radiale plant rond de speler trekt aandacht/vermindert leesbaarheid. De stap is zichtbaar maar beperkt en haalt de premium C-kwaliteitsrichting niet. Dit is geen visuele acceptatie.

De ingebrande HUD-waarde `1 FPS` en alle `metrics.json`-frametijden komen van llvmpipe-software op Linux. Ze mogen niet naar iPhone-, Metal- of GPU-prestaties worden vertaald. Fysieke iPhone-tests zijn niet uitgevoerd.
