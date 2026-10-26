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

## Personenauto

De viewer bevat ook `assets/auto.glb` (Personenauto, bron `bron/auto/`): zes echte GLB-clips (deuren, motorkap, kofferklep, ruitenwissers, knipperlichten, alarm) en een keuzelijst **Schadefase** (heel, beschadigd, zwaar, brandend, wrak) die de echte shape key `Deuk`, het verkoolde materiaal en losse onderdelen gebruikt. Brand, rook, ontploffing en vliegende onderdelen zijn Godot-effecten: zie `scenes/auto_demo.tscn` en `tests/auto_foto.gd`. Test: `node test-auto.mjs` (Chromium; zet `CHROMIUM=` als het pad afwijkt).

## Stadsbus

De viewer bevat ook `assets/bus.glb` (Stadsbus, bron `bron/bus/`): acht echte GLB-clips (voordeur, middendeur, motorluik, knielen, lichten, ruitenwissers, knipperlichten, alarm) en de keuzelijst **Schadefase** (heel, beschadigd, zwaar, brandend, wrak, ontploffing). Brand, rook, ontploffing en vliegende onderdelen zijn viewer-voorbeelden; de echte effecten zitten in Godot (`scenes/bus_demo.tscn`, `tests/bus_foto.gd`). Test: `node test-bus.mjs`. Een los telefoonbestand met knoppen per onderdeel maak je met `python3 tools/bus-viewer/bouw.py uit.html`.

## Straaljager (napalm-luchtsteun)

De viewer bevat ook `assets/straaljager.glb` (bron `bron/straaljager/`): drie echte GLB-clips (Vliegen-loop, Bocht, Aanval) met bewegende rolroeren, naverbranders en romp. `node test-straaljager.mjs` controleert dat elke clip de verwachte nodes echt beweegt. Het loslaten van de bommen en de napalm-vlam zijn Godot-effecten (`scripts/napalm_aanval.gd`, test `tests/killstreak_test.gd`). Geen iPhone/Safari/Xogot-meting uitgevoerd.
