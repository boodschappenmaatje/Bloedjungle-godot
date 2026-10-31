# Bloedjungle VQ2 mobile model viewer

This static Three.js viewer loads the real final GLBs and the fixed originals
from `assets/vq2_baseline` (main commit `967e9c2`). It supports 360° touch orbit,
pinch zoom, identical-camera comparison, the game's 58°/28 m/45° FOV camera,
material-map inspection, and actual GLB clips with play/pause/restart/scrubbing.
The unanimated models explicitly say **Geen animaties in dit model**.

From the repository root:

```sh
python3 -m http.server 8000
# open http://localhost:8000/tools/blender-vq2-viewer/
```

On an iPhone on the same Wi-Fi, use `http://YOUR_COMPUTER_LAN_IP:8000/` followed
by that viewer path. Serve the repository root, not only this directory. A file
URL cannot fetch the neighbouring GLBs because browsers restrict local fetches.

The bundled runtime has no CDN dependency. To reproduce it:

```sh
cd tools/blender-vq2-viewer
npm ci
npm run build
node test.mjs  # requires Chromium at /usr/bin/chromium or CHROMIUM=/path
```

`test.mjs` exercises the real rendered scenes, all seven animated-jeep clips,
expected wheel/steering/MG/turret transforms, material modes, camera presets,
mobile viewport layout and two-finger pinch. Chromium touch emulation is not
a physical Safari/Xogot device test.

To package a portable static-host artifact, run from the repository root:

```sh
python3 tools/publish_vq2_site.py /tmp/bloedjungle-vq2-site
```

Three.js 0.180.0 is pinned; its MIT license is in `THREE-LICENSE.txt`.

## Airfield HQ 2.0

Select **Airfield HQ 2.0** to inspect the isolated WWII airfield replacement:
the hangar, tower, runway, support props and defensive perimeter. The **Afstand
en LOD** control switches the full-detail and mobile GLBs; **Materiaalbeeld**
shows PBR, albedo, normal, roughness and wireframe views. The clip selector
plays both sliding doors and the blinking red marker-light morph. The iPhone
USDZ preview is in iCloud Drive under `Bloedjungle Previews/Airfield HQ/2.0/`.
The web viewer was checked in desktop Safari; no physical iPhone browser or
frame-rate test was performed.

## Personenauto

De viewer bevat ook `assets/auto.glb` (Personenauto, bron `bron/auto/`): zes echte GLB-clips (deuren, motorkap, kofferklep, ruitenwissers, knipperlichten, alarm) en een keuzelijst **Schadefase** (heel, beschadigd, zwaar, brandend, wrak) die de echte shape key `Deuk`, het verkoolde materiaal en losse onderdelen gebruikt. Brand, rook, ontploffing en vliegende onderdelen zijn Godot-effecten: zie `scenes/auto_demo.tscn` en `tests/auto_foto.gd`. Test: `node test-auto.mjs` (Chromium; zet `CHROMIUM=` als het pad afwijkt).

## Stadsbus

De viewer bevat ook `assets/bus.glb` (Stadsbus, bron `bron/bus/`): acht echte GLB-clips (voordeur, middendeur, motorluik, knielen, lichten, ruitenwissers, knipperlichten, alarm) en de keuzelijst **Schadefase** (heel, beschadigd, zwaar, brandend, wrak, ontploffing). Brand, rook, ontploffing en vliegende onderdelen zijn viewer-voorbeelden; de echte effecten zitten in Godot (`scenes/bus_demo.tscn`, `tests/bus_foto.gd`). Test: `node test-bus.mjs`. Een los telefoonbestand met knoppen per onderdeel maak je met `python3 tools/bus-viewer/bouw.py uit.html`.

## Straaljager (napalm-luchtsteun)

De viewer bevat ook `assets/straaljager.glb` (bron `bron/straaljager/`): drie echte GLB-clips (Vliegen-loop, Bocht, Aanval) met bewegende rolroeren, naverbranders en romp. `node test-straaljager.mjs` controleert dat elke clip de verwachte nodes echt beweegt. Het loslaten van de bommen en de napalm-vlam zijn Godot-effecten (`scripts/napalm_aanval.gd`, test `tests/killstreak_test.gd`). Geen iPhone/Safari/Xogot-meting uitgevoerd.

## Soldaat (mannetjes)

Model **Soldaat** vergelijkt de oude pop (`assets/soldaat.glb`, V1) met het realistische mannetje (`assets/soldaat_vq2.glb`, bron `bron/soldaat_vq2/`). De keuzelijst **Rol / uitrusting** toont dezelfde looks als het spel (eigen soldaat, speler met bloot/mouwloos/uniform/vest, vijand mes/geweer/raket/zwaar), met dezelfde uniformtint als `SoldierModel.uniform_tint()`. Alle 17 echte clips spelen op beide modellen: de tien uit `soldaat.glb` plus klimmen, zitten en de acties uit hun eigen glb, zoals in Godot. Wapen, terugslag en de bovenlijfhouding bij schieten/treffers zijn Godot (`tests/soldaat_foto.gd`). Test: `node test-soldaat.mjs`. Geen iPhone/Safari-meting uitgevoerd.

## Poortwachtpost

De viewer bevat ook `assets/wachtpost.glb` (bron `bron/wachtpost/`): slagboom met de echte GLB-clip `Open` (arm 82° omhoog) en het wachthuisje, te tonen samen of apart. Het wachthuisje heeft geen clips. Test: `node test-wachtpost.mjs`. Geen iPhone/Safari-meting uitgevoerd.

## Generator

De viewer bevat ook `assets/generator.glb` (bron `bron/generator/`): dieselgenerator met de echte GLB-clip `Draaien` (koelventilator) en het zwartgeblakerde wrak, samen of apart. Rook, vuur, explosie, geluid en trilling zijn Godot-effecten (`scripts/generator.gd`, `tests/generator_test.gd`, opnames `tests/generator_foto.gd`). Test: `node test-generator.mjs`. Geen iPhone/Safari-meting uitgevoerd.

## Munitiekist (Meshy-test)

Model **Munitiekist** vergelijkt de procedurele `Kist_Munitie` uit `assets/props.glb` (V1, de rest van props.glb verborgen) met `assets/munitiekist_meshy.glb`: een Meshy text-to-3D-kist, in Blender op maat gezet, AI-letters weggepoetst, 2.500 driehoeken met opnieuw gebakken 1K-PBR (bron `bron/munitiekist_meshy/`). Geen clips. Test: `node test-munitiekist.mjs`. Geen iPhone/Safari-meting uitgevoerd.

## Meshy M1911

Model **M1911 · Meshy** vergelijkt de oorspronkelijke M1911 uit `assets/wapens.glb` met `assets/meshy_m1911.glb`. De Meshy-bron blijft ongewijzigd in `assets/meshy_weapon.glb`; `bron/wapens/maak_meshy_m1911.py` maakt de geoptimaliseerde 1K-PBR-gameversie met frame en bewegende slede als aparte meshes, vijf echte GLB-clips en circa 29.000 driehoeken. De Meshy-speler houdt het pistool via het M1911-profiel en tweehandige IK vast. Test: `node test-m1911.mjs`. Geen fysieke iPhone/Safari/Xogot-meting uitgevoerd.
