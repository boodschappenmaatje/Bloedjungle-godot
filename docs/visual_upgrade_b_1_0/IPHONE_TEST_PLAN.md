# iPhone-testplan — Visual Upgrade B 1.0

De gebruiker voert de uiteindelijke toesteltest uit. Er is door het ontwikkelteam geen fysieke iPhone-test uitgevoerd. De CI-export controleert dat Godot de iOS-build kan maken; hij bewijst geen installatie, Metal-rendering, prestaties, thermiek of speelbaarheid op een iPhone.

## Testbuild

- PR: [#237 — Visual Upgrade B 1.0](https://github.com/boodschappenmaatje/Bloedjungle-godot/pull/237) (Draft)
- Commit: `997f386c869f2e12dbc4eacab925fe3ba1a5cfb3`
- iOS-export: [GitHub Actions-run 42304197774](https://github.com/boodschappenmaatje/Bloedjungle-godot/actions/runs/42304197774), geslaagd.
- Artifact: `bloedjungle-ios-unsigned-6e92a7fdab7ec94f8fd81d0a43a2baf94fa3eacc` (1.151.750.040 bytes, ongeveer 1,15 GB).

Download het artifact in de Actions-run en pak de ZIP uit. Laat de IPA met je eigen Apple-account ondertekenen en installeer hem via AltStore/AltServer of je gebruikelijke iOS-signingproces. Controleer vóór installatie de commit hierboven. Dit is een unsigned testbuild, geen OTA-release.

De aparte [Godot-capturerun](https://github.com/boodschappenmaatje/Bloedjungle-godot/actions/runs/42304197795) levert echte beelden uit de gamecamera en softwaremetingen; die zijn geen iPhone-prestatiemeting. Gebruik voor de vergelijking dezelfde bestaande grafische instellingen, camera en scène. Pas de renderresolutie niet aan om de visuele kwaliteit te beoordelen.

## Uitvoeren

Noteer eerst iPhone-model, iOS-versie, kwaliteit, render scale, Low Power Mode, accupercentage en of het toestel al warm is. Laat de game na het starten 30 seconden opwarmen.

1. **Stilstaande scène — 60 seconden.** Start bij het bospad en maak een schermopname. Controleer de gras- en grondstructuur, pad, plantcontact en zicht op soldaten en schietlijnen.
2. **Beweging en shimmer — 60 seconden.** Loop en ren over het pad en langs de oever. Noteer flikkering, LOD-sprongen, pop-in en planten die zichtlijnen blokkeren.
3. **Groot gevecht — minimaal 2 minuten.** Beweeg, vuur en test de zwaarste normale encounter. Noteer haperingen, laagste aanhoudende FPS en of besturing, HUD en camera responsief blijven.
4. **Rivier, kamp en gebouwen.** Beweeg langs de rivieroevers, muren en torens; controleer terreincontact, zichtbaarheid en collisions.
5. **Warmte.** Herhaal na minimaal 10 minuten spelen en noteer eventuele iOS-waarschuwing, warmte en zichtbare throttling.

De HUD-FPS is een momentopname, geen betrouwbare 1%-low. Voor frametijden en 1%-lows is een Metal System Trace in Xcode Instruments nodig. Als die meting niet wordt uitgevoerd, noteer dan letterlijk **niet gemeten**. De CI-metingen komen van Mesa llvmpipe-software en mogen niet als iPhone-FPS worden geïnterpreteerd.

## Resultaten invullen

- iPhone-model / iOS:
- Build-commit:
- Kwaliteit / render scale / Low Power Mode:
- Stilstaande FPS-bandbreedte na opwarming:
- Groot gevecht: laagste aanhoudende FPS / haperingen:
- Frametime en 1%-low (Instruments of **niet gemeten**):
- Shimmer, pop-in of LOD-sprongen:
- Temperatuur / thermische throttling na 10 minuten:
- Zichtlijnen, gameplay, besturing, HUD of collisionproblemen:
- Schermopname of aanvullende notities:

Mobiele en visuele acceptatie blijven open tot deze toesteltest is beoordeeld. Installatie van de unsigned IPA is de volgende teststap; de export op zichzelf is geen toestelbewijs.
