# M-47 Visual Upgrade 2.1 — geïsoleerd testrapport

**Status:** 41 capturechecks PASS, 36 aparte performancechecks PASS, vier lokale wapen/muurregressies PASS. Alle VFX-code en beelden staan onder `tests/m47_vfx/`. De bestaande M-47 GLB, gameplay, bazooka, player controls, gedeelde scenes en projectinstellingen zijn niet gewijzigd. Getest met de officiële Godot `4.7.2.stable.official.ed1daf0bf`.

## Vergelijking met het aangeleverde doelbeeld

| Fase | VFX 2.0 vóór | Visual Upgrade 2.1 na |
| --- | --- | --- |
| Laden en afvuren | Kleine, moeilijk leesbare kern en korte flits | Zichtbare blauwe rotor, versnellende originele Idle-kern, gemeten terugslag van de testmontage en vooraf aangemaakte sterflits |
| Projectiel | Kleine bol en dun spoor dat al over de volledige baan zichtbaar was | Grotere blauwe kern met witte accenten, twee draaiende ringen en vier vonkpunten; 100-segments rookspiraal wordt pas zichtbaar als het projectiel passeert |
| Inslag | Eén zwakke hexring, beperkte stof | Cluster van zeven zeshoekige lijnen, korte centrumflits, 28 stofdeeltjes, 12 rookdeeltjes en 8 inslagvonken |
| Muur | Wand en collision verdwijnen, acht kubusachtige stukken | Permanente doorgang met achterblijvend frame, onregelmatige breukrand, één gerenderde puinlaag en acht fysieke tetraëdrische brokstukken |

[Projectiel vóór](screenshots/before_vfx20_projectile.png) · [projectiel na](screenshots/after_vfx21_projectile.png) · [mondingsflits na](screenshots/after_vfx21_muzzle_flash.png)
[Inslag vóór](screenshots/before_vfx20_impact.png) · [inslag na](screenshots/after_vfx21_impact.png) · [blijvende doorgang](screenshots/after_vfx21_breach.png) · [video, 5,23 s](screenshots/m47_vfx_preview.mp4)

**Visuele beperking:** de nieuwe Godot-captures halen de aangeleverde conceptafbeelding niet exact. Het doelbeeld heeft een gedetailleerde jungleomgeving, volumetrische rook, elektrische lichtspreiding en complexe gebarsten steen; deze geïsoleerde testscene heeft vereenvoudigde geometrie en een testbaan. Daarom blijft dit een Draft-iteratie. De voor/na-beelden tonen de feitelijke afstand tot het doelbeeld.

## Asset, collision en budget

De goedgekeurde geanimeerde GLB blijft via een relatieve symlink ongewijzigd. De originele `Idle`, `Equip`, `Aim`, `Fire` en `Reload` clips bewegen in Godot. LOD0 heeft 50.000 driehoeken, LOD1/LOD2 zijn aanwezig, er wordt één LOD tegelijk getekend en albedo/normal/roughness/metallic importeren. De testwand gebruikt de bestaande VQ2-betontexturen als read-only bron.

De projectielray raakt de wand vóór de inslag. Bij de doorgang worden de bestaande wandcollider en collision layer uitgeschakeld; dezelfde ray passeert daarna de opening. Acht onregelmatige brokstukken houden elk een eigen convex collision shape. Dit zijn testobjecten; bestaande gameplaylogica is niet aangepast.

| Budget | Gemeten |
| --- | ---: |
| VFX-driehoeken inclusief particle-meshes | 3.744 |
| Eenmalige particles, vier emitters | 64 |
| Tijdelijke rigid bodies | 8 |
| Vooraf gemaakte projectielen / flitsen / emitters | 1 / 2 / 4 |
| Dynamische schaduwen in de testscene | 0 |
| Fullscreen postprocessing | 0 |

## Controles en performance

- `run_test.sh`: 41 checks PASS met captures; 36 checks PASS in de aparte run zonder PNG/video-encoding. Godot meldde geen script- of rendererfouten in die runs.
- Tweede volledige root-import uit VFX 2.0 blijft het uitgangspunt voor de ongewijzigde gameplay; de vier relevante regressies zijn op deze branch opnieuw uitgevoerd: `surface_filtering_test.gd`, `combat_bazooka_aim_test.gd`, `wapen_clips_test.gd` en `base_wall_hq2_test.gd`, alle PASS. Zie `logs/v21_*.log`.
- Laatste no-capture run op Xvfb/Mesa llvmpipe, 1280×720: 4–20 software-FPS, piekprocesduur 169,51 ms, 130 draw calls, 228.730 gerenderde primitives. Statisch procesgeheugen: 66.116.169 bytes vóór, 86.778.641 bytes na en 104.855.437 bytes piek.

Deze software-renderwaarden zijn geen iPhone-meting. **60 FPS op iPhone is niet aangetoond**; er was geen fysieke iPhone met GPU-profiler beschikbaar. De particlegrens, effectpool en uitgeschakelde dynamische schaduwen beperken de VFX-kosten, maar een 60-FPS-claim vereist een apparaatmeting.

De eerdere VFX 2.0 iOS- en OTA-previewruns horen bij commit `6d75022`; voor deze nieuwe implementatie moet CI opnieuw lopen. Er is niets gemerged of naar OTA gepubliceerd.
