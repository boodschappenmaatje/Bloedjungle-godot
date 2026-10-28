# Native iPhone Asset Test Zone 2.0

De assettest is een aparte Godot-scène die bereikbaar blijft via **3D Asset Test Zone · Bunker** in het hoofdmenu. Ze verandert geen gameplay-scène, camera-rig, algemene rendererinstelling of OTA-release.

## HUD en bediening

- De ingeklapte HUD toont de actuele framecadans en, na een voltooide meting, gemiddelde FPS en 1%-low. Tik **TEST** om de compacte instellingen te openen.
- In de uitgeklapte HUD kies je scenario, camerastand en belichting. De knoppen zijn minimaal 48 logische pixels hoog; de HUD gebruikt de bestaande veilige schermmarges.
- Sleep over het model om te draaien en knijp om in/uit te zoomen. De cameramodi **Gameplay · Normaal** en **Gameplay · Gevecht** volgen `scripts/camera_rig.gd`: FOV 45°, respectievelijk 58°/28 m en 48°/16 m. De gameplay-look-ahead van 7% van de afstand (5% in portret) blijft op een vaste scènefocus toegepast. **Schuin** en **Voorzijde** zijn inspectiestanden.
- **Standaardbelichting** gebruikt de veldkleur en zon zonder shadow map. **Verbeterde belichting** gebruikt dezelfde scène met warmere zon, meer omgevingslicht en schaduwen. Dit zijn uitsluitend lokale testscene-instellingen.

## Reproduceerbare scenario's

| Code | Inhoud |
| --- | --- |
| A · Baseline | Eén bunker en eenvoudige ruwe veldgrond. |
| B · Jungleomgeving | Eén bunker, drie bestaande `jungle.glb` clusters, militaire props en veldmeubilair. |
| C · Drie bunkers | Drie identieke bunkers op vaste posities; verder geen extra objectgroepen. |
| D · Zware stresstest | Drie bunkers, jungle, props, veldmeubilair, wachtpost, wachttoren en woonhuis. |

Alle assets komen uit de bestaande repository. Scenario's gebruiken vaste aantallen, rotaties en posities. Houd bij vergelijkingen camera, scenario, belichting, resolutie en apparaat gelijk.

## Meting

Tik **START 30 S**. De scène warmt eerst 5 seconden op; daarna verzamelt ze de `_process`-delta van elk frame gedurende 30 seconden. De HUD houdt resource-monitors licht bij en berekent sorteerstatistieken pas na de opname om sorteerkosten uit het meetvenster te houden.

- Gemiddelde FPS = aantal gemeten frames / totale gemeten tijd.
- Minimum en maximum FPS zijn afgeleid van respectievelijk de langste en kortste frame-delta.
- 1%-low FPS = rekenkundig gemiddelde van de FPS van de traagste `ceil(1% × aantal frames)` frames, gerangschikt op frametime.
- p99-frametime = nearest-rank 99e percentiel van de frametimes in milliseconden.
- De gerapporteerde display-refreshrate komt uit Godots display API. Een gemiddelde binnen 2% van die waarde wordt als **waarschijnlijke refresh/vsync-limiet** gemarkeerd; het bewijst geen ongelimiteerde GPU-capaciteit.

Na een complete opname slaat **BEWAAR JSON** `user://bunker_asset_test_v2_latest.json` op met samenvatting, scenario/profiel, apparaat/renderer, refreshrate en de volledige reeks frametimes.

Geheugenvelden blijven gescheiden:

- **Godot allocatie** is `Performance.MEMORY_STATIC`, niet het totale procesgeheugen.
- **Renderergeheugen** is de Godot video-memoryschatting; nul/onbeschikbaar wordt als `n/b` getoond.
- **Proces-RSS** heeft geen draagbare Godot-API en is daarom `n/b`/JSON `null`, nooit een verzonnen nul.
- Draw calls en rendererprimitieven worden alleen getoond wanneer de monitor een positieve waarde levert; rendererprimitieven zijn geen exacte mesh-triangle count.

Per-frame process-delta is een bruikbare meting van de cadence die de scène ontvangt, maar synchronisatie-/GPU-tijd is geen onafhankelijke GPU-profiler. Headless-resultaten valideren functionaliteit, niet iPhone-prestaties. Een werkelijke 60/120-FPS-uitspraak vereist een 30-secondenrun op de fysieke iPhone, na opwarming, met bewaarde JSON en vaste testcondities.

## Lokale validatie

Met Godot 4.7.2:

```sh
godot --headless --editor --path . --import
godot --headless --path . -s tests/bunker_asset_test.gd
godot --headless --path . -s tests/bunker_asset_test_zone_v2_test.gd
```

De regressietest controleert scenario-aantallen, bestaande GLB-import, camera-profielen en de deterministische berekening van 1%-low en p99. Dit is geen vervanging voor de daadwerkelijke iPhone-test.
