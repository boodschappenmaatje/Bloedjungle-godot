# MotionBricks Integratie 1.0 — fase 1 rapport

**Status:** onderzoeksproef afgerond; volledige integratie niet gebouwd
**Gecontroleerd:** 16 november 2026
**Godot:** 4.7.2 stable
**Game-branch:** `feature/motionbricks-integration-1-0`

## Samenvatting

MotionBricks.cpp is in deze Linux-ontwikkelcontainer als CPU-runtime gebouwd.
Met het gepubliceerde G1 F32-model genereerde de native API geldige 30 FPS
animatiechunks van 44 frames en 34 gewrichten. Drie gemeten plannen duurden
149–199 ms op deze container. De officiële browserdemo start lokaal en de
native HTTP-flowtest slaagt; de volledige Chromium-flow faalt bij het starten
van een geüploade Kimodo-clip. Daarom is alleen de modelinferentie bewezen, niet
de gehele browserflow of een Godot/MotionBricks-koppeling.

De bestaande Bloedjungle-modellen gebruiken een 53-bot DEF-skelet of een
28-bot Mixamo-skelet. MotionBricks G1 geeft een andere, robotgerichte 34-bots
hiërarchie. Er is dus een expliciete, gevalideerde retargetstap nodig voordat
de beweging als natuurlijke soldaatanimatie kan worden beoordeeld.

Fase 1 voegt alleen een aparte Godot-preview van één bestaand
junglecommando-model toe. Die speelt de bestaande clips `stil`, `lopen` en
`rennen` af. De preview toont duidelijk dat MotionBricks nog niet naar dit
skelet is geretarget. Er zijn geen gameplay-, instellingen-, graphics-
of OTA-bestanden gewijzigd.

## 1. Soldaten, rigs en animaties in Bloedjungle

Godot 4.7.2 heeft de GLB-bestanden rechtstreeks gelezen en de rig/clipmetadata
geïnspecteerd.

| Bestand / groep | Skelet | Aanwezige bewegingen / rol |
|---|---:|---|
| `assets/soldaat.glb` | 53 botten, `DEF-*` | 10 kernclips, waaronder stil, lopen, rennen, schieten, herladen, geraakt en dood |
| `assets/soldaat_vq2.glb` | hetzelfde 53-bot `DEF-*` | VQ2 soldaat; dezelfde kernclips |
| `assets/soldaat_jungle_commando.glb` | hetzelfde 53-bot `DEF-*` | Junglecommando voor spelerpreview; dezelfde kernclips |
| `assets/meshy_jungle_commando.glb` | 28 botten, `mixamorig_*` | RunFast, Running en Walking als ingebouwde clips |
| `assets/enemies/assault/assault_meshy_hq2_runtime.glb` | 28 botten, `mixamorig_*` | Meshy-vijand; de gameplayclipbibliotheek wordt door de soldaatcode geleverd |
| `bron/meshy_speler_animaties/bronnen/*.glb` | 24 botten, Mixamo-achtige namen, centimeters | Ruwe Meshy API-rig en zeven groepen animatiebestanden; samen 62 aanvullende clips |

De bestaande `bron/meshy_speler_animaties/retarget_api_clips.gd` retarget de
62 Meshy-clips naar het 28-bot Mixamo-skelet via globale rustpose-delta's,
een heuphoogteschaal en afzonderlijke root-motionbehandeling. Dat is een
bestaande specifieke omzetting; zij levert geen G1-naar-DEF of G1-naar-Mixamo
retarget op.

## 2. MotionBricks.cpp — repository, API, licenties en gewichten

Gecontroleerde upstream: [`localai-org/motion-bricks.cpp`](https://github.com/localai-org/motion-bricks.cpp),
commit `60a5f4c0b5eef3d893d4a8c253cc3fc68924c559`.

- De upstream-runtime is C++23/GGML met een opaque, stabiele C ABI. De
  inference-API levert roottranslaties en lokale XYZW-rotaties voor `g1skel34`.
- De controller vraagt richting, facing, snelheid en een stijl aan en plant
  batches van 24–64 frames. De gepubliceerde styles zijn G1-stijlen zoals
  `walk`, `walk_gun`, `walk_stealth` en `injured_walk`.
- De inference-interface verwacht een canoniek Y-up/meter/30 FPS-frame en
  posegrenzen. De opgegeven poses zijn voorwaarden voor generatie, geen exacte
  vastgezette poses. De applicatie blijft verantwoordelijk voor wereldplaatsing,
  seam blending, retargeting en afspeelschema.
- Het model bevat 183.148.382 F32-parameters. De gepubliceerde GGUF- en
  stylebestanden zijn samen 733.427.543 bytes (699,5 MiB); de vier
  model-GGUF's nemen ongeveer 699 MiB in. De upstream-downloader controleerde
  de SHA-256-hashes tijdens deze proef. De bestanden staan alleen in `/tmp`
  en zijn niet aan Bloedjungle toegevoegd.
- De runtimebroncode valt onder Apache-2.0. De oorspronkelijke modelgewichten
  en de conversie vallen onder de NVIDIA Open Model License. Herdistributie
  vereist de licentietekst en de vermelding “Licensed by NVIDIA Corporation
  under the NVIDIA Open Model License.” Gebruik is ook onderworpen aan NVIDIA
  Trustworthy AI- en handelsvoorwaarden. De gamebuild mag de gewichten daarom
  niet zonder die voorwaarden meeleveren.

### Buildafhankelijkheden en upstream-afwijking

Upstream documenteert CMake 3.25+, een C++23-compiler, GGML, Python 3 en Ninja;
de webdemo gebruikt daarnaast Go 1.26+ en Chromium. Deze container had GCC 14,
3 CPU-cores en 9 GiB beschikbaar geheugen. CMake/Ninja en Go zijn tijdelijk
onder `/tmp` geïnstalleerd; er zijn geen systeem- of projectafhankelijkheden
toegevoegd.

De upstream-commit verwijst als GGML-submodule naar commit
`0a249dd4d2f4dfcd962123a3d881f73f93588ccf`, maar de publieke GGML-repository
kan die SHA niet vinden (GitHub API geeft “No commit found”). Upstream zelf
documenteert in `patches/ggml/README.md` versie 0.20.2, commit
`8c63e70982c95ceb862e3a1073a2c1beef75d60a`. De tijdelijke proef gebruikte die
gedocumenteerde GGML-revisie als CMake-bronmap, zonder de MotionBricks-bron of
de Bloedjungle-repository te wijzigen. Dit is een reproduceerbare
compatibiliteitsproef, maar geen bewijs dat de upstream-submodulepin zelf
correct is.

## 3. Installatie- en runtimeproef

| Proef | Resultaat |
|---|---|
| MotionBricks CPU-configuratie en volledige native build | **PASS** — CMake configureerde en bouwde de C/C++-library, CLI en tests (100 buildstappen) |
| Model en styles downloaden | **PASS** — upstream-script bevestigde bestandsgrootte en SHA-256 |
| Gerichte native tests: C API, inference API, inference met model, batchmodel | **PASS** — 4/4 |
| CLI modelinspectie | **PASS** — herkende `g1skel34`, 34 gewrichten en 183.148.382 parameters |
| Native demo HTTP-flowtest | **PASS** — de test controleert echte modeloutput: 24+ frames, 34 gewrichten, roots/rotaties, stijlwissel en batchvorm |
| CPU-planmeting | **PASS** — 3 plannen; 44 frames × 34 gewrichten; 149, 180 en 199 ms; 5.984 rotatiescalars per plan |
| Officiële Chromium-flowtest | **FAIL** — herhaaldelijk timeout bij “non-interruptible Kimodo playback” na upload/selectie; browserstatus bleef `ready`. Dit onderdeel is niet als werkend gevalideerd. |
| Godot 4.7.2 geïsoleerde soldaatpreview | **PASS** — headless geladen en 60 frames gedraaid, exitcode 0; geen parse- of scriptfout. Bij afsluiten meldde Godot generiek 7 gelekte ObjectDB-instances. |
| Windows-build, iPhone-installatie of native iPhone-profiel | **NIET GETEST** |

De CPU-planmeting is een 3-core Linux-containerresultaat, met twee inference-
threads. Zij is geen voorspelling voor een Windows-pc of iPhone 18 Pro Max.
Tijdens de losse demo-run mat Linux 732.272 KiB (circa 715 MiB) RSS voor het
proces met het model geladen; dit is geen gemeten piekgeheugen.

## 4. Compatibiliteit en retargeting

MotionBricks publiceert bewegingen voor een 34-joint Unitree G1-skelet. Dit
skelet is robotgericht: de benen hebben afzonderlijke pitch/roll/yaw-heupassen,
de armen afzonderlijke schouder- en polsassen en iedere hand eindigt in één
`*_hand_roll_skel`-joint. Het bevat geen menselijke vingerketens.

Bloedjungle's standaard soldaat heeft 53 DEF-botten met vingers. De Meshy-speler
heeft 28 Mixamo-botten met onder meer `Hips`, `Spine`, `LeftArm`, `LeftForeArm`
en `LeftHand`. De naamgeving, aantallen, hiërarchieën, rustoriëntaties en
lichaamsverhoudingen komen niet overeen. Alleen joints op naam kopiëren zou
schouder-/polsrotaties verkeerd verdelen en kan armen, voeten en roothoogte
vervormen.

Er is nog geen gecontroleerde mapping, geen retargeted MotionBricks-clip en
geen visuele vergelijking op een geskinnde Bloedjungle-soldaat. Eerst is een
G1→Mixamo mapping nodig met expliciete assen, restpose- en segmentcorrectie,
root-unitconversie, voet-/teenbehandeling en seam/loop-controles. Daarna moet
de DEF-variant afzonderlijk worden gevalideerd. De huidige Meshy-retargeter kan
als codepatroon dienen, maar is niet voldoende als G1 mapping.

## 5. Aanbevolen Godot-bridge en MCP

**Aanbeveling voor fase 2: offline genereren en vooraf retargeten.** Laat een
lokale CPU-tool of localhost-demo MotionBricks-chunks genereren. Zet de 34-joint
output in een losse, herhaalbare retargetstap om naar een Godot
`AnimationLibrary` (`.tres`) of GLB-animatie. Importeer alleen de uiteindelijke
animatiebestanden in game. Bestaande SoldierModel- en gameplaybesturing blijven
dan verantwoordelijk voor locomotie, wapen-/bovenlijfposes en afspelen.

Een GDExtension zou op Windows een native DLL en op iOS een apart gebouwde
statische library en GGML CPU-backend vereisen, plus modelopslag, threading en
licentie-/assetlevering. De upstream-proef bevat geen geteste iOS-build of
Metal-integratie. Live modelinferentie op iPhone is daarom geen verstandige
eerste bridge. Als later runtimegeneratie nodig is, moet die asynchroon in
chunks lopen met een bestaande animatie als fallback; pas na native iPhone-
metingen kan over GDExtension of een beveiligde lokale service worden beslist.

De huidige MotionBricks-webdemo bindt standaard aan `127.0.0.1:8080`. De
projecttools bevatten geen Godot-editor-MCP-server. MCP is niet nodig om
animaties te genereren of af te spelen. Voor toekomstig editorwerk is een
lokale stdio-bridge of strikt loopback-endpoint voldoende; stel geen
ongeauthenticeerde Godot- of demo-WebSocket op een netwerkinterface open.

## 6. Prestatierisico: 60 FPS

60 FPS geeft 16,7 ms per beeld. De gemeten inferentie van 149–199 ms is op deze
container ongeveer 9–12 beeldbudgetten, dus niet geschikt als synchrone
berekening per renderframe. Een plan bevatte 44 frames bij 30 FPS (ongeveer
1,47 s beweging); de 16-frame replan-cadans uit de demo is ongeveer 533 ms.
De container gebruikte daarvan 28–37% voor één plan, maar iPhone-prestaties en
thermisch gedrag zijn onbekend.

Ook de 699,5 MiB model/stylebestanden en ongeveer 715 MiB gemeten resident
geheugen vormen risico's voor downloadgrootte en geheugenruimte naast de game.
Voor de 60 FPS-doelstelling moet MotionBricks voorlopig alleen content maken
vooraf; Godot speelt de gebakken animatie af en mag de AI-inferentie niet in de
renderthread uitvoeren. Native iPhone 18 Pro Max FPS, geheugen en batterijduur
blijven **NIET GETEST**.

## 7. Geïsoleerde preview en vervolgstappen

Open `prototypes/motionbricks/motionbricks_soldier_preview.tscn` met Godot 4.7.2.
De scene gebruikt het bestaande `soldaat_jungle_commando.glb`, toont één
soldaat en kan met `1`, `2` en `3` tussen bestaande stil-, loop- en renclips
schakelen. De overlay vermeldt dat MotionBricks-output nog niet op dit DEF-rig
staat. Er zijn geen modellen of animatiebestanden gekopieerd.

Voor een volgende, expliciet goed te keuren stap:

1. Maak een reproduceerbare G1→Mixamo/DEF restpose- en botmapping, met
   conversie tussen 30 FPS G1-joints en de Godot-rig.
2. Genereer één gecontroleerde walk- en walk-gun-chunk uit de lokale CLI/demo.
3. Bake de retargeted output naar een tijdelijke `.tres` of GLB en toon die in
   deze preview naast de bestaande loopclip.
4. Voeg numerieke checks toe voor quaternion-normalisatie, botlengtes, root
   displacement, voetcontact, clipseams en framebudget; inspecteer renders.
5. Pas na goedkeuring een Windows-package en een echte native iPhone-proef
   plannen. Publiceer niets naar OTA zonder afzonderlijke toestemming.
