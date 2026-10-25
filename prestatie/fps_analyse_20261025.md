# Waarom geen 60 fps in de stad (v106 → v107)

Gemeten op 2026-10-25 in de sandbox: Godot 4.7.2, Mobile-renderer (zoals op de iPhone) via lavapipe, grafiek Ultra, boomschaduw Echt,
camera zoals in het spel. Meetscripts: `tools/fps_meting.gd` (draw calls, schaduw, scripttijd per plek) en `tools/warmup_meting.gd`
(shadercompilaties na het laadscherm). Niet gemeten: echte iPhone-, Safari- of Xogot-tijden. Die moeten op het toestel.

## Wat het screenshot al zegt
"36 FPS · 50%": de resolutieregelaar staat op zijn laagste stand (50%) en toch blijft het 36. Minder pixels helpt dus niet:
de iPhone loopt niet vast op pixels (GPU-vulling), maar op het aantal dingen dat hij per beeld moet klaarzetten en tekenen.

## Oorzaken, op volgorde

| # | Oorzaak | Gemeten | Winst | Uiterlijk | Status |
|---|---|---|---|---|---|
| 1 | Stadsgebouwen werpen schaduw met al hun losse stukjes (muurstukken voor het slopen, kozijnen, meubels): woonhuis 265, hotel 483, winkel 314, kerk 198. De schaduwkaart tekent ook gebouwen buiten beeld. | schaduw-draw-calls plein 690, straat 541, woonwijk 425 (in beeld maar 183-272). Jungle-basis: 189. | **groot**: plein 690 → 205, straat 541 → 314, woonwijk 425 → 125; render-CPU plein 8,5 → 4,0 ms | geen (voor/na-beeld gelijk op de pixel, behalve bewegend vuur) | **gebouwd in v107** |
| 2 | Schaduwafstand Ultra is 80 m, terwijl het beeld maar ~40-55 m diep is | 55 m i.p.v. 80: straat -177 schaduw-draw-calls | middel | schaduwen worden iets scherper | voorstel |
| 3 | Geparkeerde auto's, bussen en wrakken: elk 30-80 losse stukjes in de schaduw | straat: ~260 schaduw-draw-calls | middel | geen (zelfde truc als bij gebouwen) | volgende onzichtbare stap |
| 4 | Resolutieregelaar zakt naar 50% als het niet helpt | 36 fps bij 50% | geen fps, wel scherper beeld | beeld blijft scherper | voorstel |
| 5 | Ultra: 2 schaduwlagen, 4096-schaduwkaart, gloed en scherptediepte | niet apart te meten zonder iPhone | klein tot middel | merkbaar | alleen als 1-3 niet genoeg is |

Niet de oorzaak: scripts. Alle `_process`/`_physics_process` samen kosten ~1-2,5 ms per beeld (headless, pc-processor); geen enkel
script springt eruit (woonhuis 0,9-1,4 ms, auto/bus ~1,3 ms). Lampen: overdag 0 lampen aan. Fysica: 1-3 ms.

Totaal draw calls per beeld (in beeld + schaduw), voor → na v107:

| plek | v106 | v107 |
|---|---|---|
| jungle-basis | 249 | 249 |
| stadsrand | 548 | 388 |
| straat bij de bus | 724 | 497 |
| plein | 909 | 424 |
| woonwijk | 697 | 397 |

Ter vergelijking: de meting van 22 oktober in de jungle haalde 60 fps met gemiddeld 492 draw calls.

## Vooraf inladen
Gemeten hoeveel shader-pipelines Godot nog moet maken nadat het laadscherm weg is (elke nieuwe kan een hapering zijn):
~95 in v106. De meeste zijn "specialisaties" die Godot 4.7 op de achtergrond maakt (dan geen hapering), maar echte
pipelines kwamen pas bij de eerste krater (eigen shader) en het eerste buswrak. v107 zet in de warm-up nu ook vuur met licht,
opstijgende vonken, een vonk, een huls (laadt het hulsmodel uit wapens.glb, voorheen bij het eerste schot), een raketstart,
een vatwrak en een krater klaar, en wacht tot Godot klaar is met compileren in plaats van vast 8 beelden.

Gebouwen, straatset, auto's en bus zijn al bij het laden in de wereld geplaatst (en dus ingeladen); modellen die pas later
komen (Apache, vrachtwagen, kazerne, ...) staan al in de warm-up.

## Wat nodig is van de iPhone
Zet in Instellingen de prestatiemeting aan en speel een golf in de stad. De overlay toont "GPU ... · render-CPU ..." en
het rapport per golf staat in de app. Als render-CPU het grootst is, zijn 1-3 de juiste weg; is GPU het grootst, dan 2 en 5.
