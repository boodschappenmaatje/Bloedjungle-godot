# iPhone-testplan — Visual Upgrade B 1.0 (C-kwaliteitsrichting)

De gebruiker voert de fysieke toesteltest uit. Er is door ons geen iPhone-test gedaan. De geslaagde unsigned export bewijst alleen dat Godot een iOS-project kon exporteren; niet dat die build ondertekend, geïnstalleerd, op Metal gerenderd of performant is.

## Testbuild

- Draft PR: [#237 — Natural Jungle Pass (C direction)](https://github.com/boodschappenmaatje/Bloedjungle-godot/pull/237)
- Codecommit van de build: `ff1002deb27e081e53c426672bcf6851b2f445b4`.
- iOS-export: [Actions-run 42460949217](https://github.com/boodschappenmaatje/Bloedjungle-godot/actions/runs/42460949217), geslaagd.
- Unsigned artifact: `bloedjungle-ios-unsigned-ff1002deb27e081e53c426672bcf6851b2f445b4`, id **`13609419743`**, 1.156.344.069 bytes; verloopt 8 december 2026.
- Download de ZIP op de tab **Artifacts** van de run, pak hem uit en onderteken de iOS-app met je eigen Apple-account. Installeer via AltStore/AltServer of je bestaande iOS-installatieproces. Dit is een lokale testbuild, geen OTA-release.

## Instellingen en captures

De build gebruikt de bestaande instellingen. Pas render scale niet aan om de visuele kwaliteit te beoordelen. Er is voor de referentiepass op 100% capture scale gewerkt, zodat renderresolutie de kwaliteitsbeoordeling niet beperkt.

De vier echte Godot-beelden staan in [captures/iterations/ff1002d/](captures/iterations/ff1002d/): bospad, rivier, kamp en combat met 80 vijanden. Dit zijn Linux Mobile/Vulkan renders op llvmpipe software. De zichtbare `1 FPS` is niet van een iPhone en mag niet als toestelmeting worden gelezen.

## Uitvoeren op de iPhone

Noteer iPhone-model, iOS-versie, kwaliteit, render scale, Low Power Mode en accupercentage. Laat de game na starten 30 seconden opwarmen.

1. **Bospad — stilstaand, 60 seconden.** Maak een schermopname. Beoordeel bosgrond, grasdetail, pad, plantgroepering en zichtbaarheid van soldaten/schietlijnen.
2. **Bospad en rivier — bewegen, 60 seconden.** Loop en ren langs pad en oever. Noteer shimmer, flikkering, LOD-sprongen, pop-in, watergedrag en planten die de speler of zichtlijn bedekken.
3. **Groot gevecht — minimaal 2 minuten.** Speel een representatieve zware encounter. Noteer haperingen en of besturing, camera en HUD responsief blijven.
4. **Kamp, gebouwen en oevers.** Controleer terreincontact, routes, zichtlijnen en collisions rond muren, torens, gebouwen en rivieroevers.
5. **Warmte — na minimaal 10 minuten.** Noteer toestelwarmte, iOS-waarschuwingen en zichtbare throttling.

HUD-FPS is een momentopname. Frametime en 1%-low zijn alleen gemeten als je een Metal System Trace met Xcode Instruments maakt; vul anders **niet gemeten** in. De vier scènes zijn nog niet op een iPhone gemeten. Shimmer, gevechtsperformance en thermiek blijven **niet gemeten** tot jij ze fysiek test.

## Resultaten

- iPhone-model / iOS:
- Buildcommit:
- Kwaliteit / render scale / Low Power Mode:
- Bospad: FPS-bandbreedte en haperingen:
- Groot gevecht: laagste aanhoudende FPS en haperingen:
- Frametime / 1%-low (Instruments of **niet gemeten**):
- Shimmer / pop-in / LOD-sprongen:
- Water / oever / planten die zicht blokkeren:
- Warmte / throttling na 10 minuten:
- Zichtlijnen, besturing, HUD of collisions:
- Visuele indruk ten opzichte van de gekozen C-kwaliteitsrichting:
- Schermopname / notities:

Visuele acceptatie blijft open omdat de nieuwe renders nog steeds vlakke open grond, eenvoudige padtextuur en herhaalde/dichte jungle-randen tonen. Mobiele acceptatie blijft open tot de gebruiker de fysieke iPhone-test heeft uitgevoerd en de resultaten heeft vastgelegd.
