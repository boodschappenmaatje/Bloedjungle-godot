# iPhone-testplan — Visual Upgrade B 1.0 (kwaliteitsrichting C)

De echte toestelcontrole is voor de gebruiker. Er is door ons geen fysieke iPhone-test uitgevoerd. De geslaagde unsigned export bewijst alleen dat Godot de iOS-build kan maken; niet dat deze is ondertekend, geïnstalleerd, op Metal is gerenderd of performant is.

## Testbuild

- Draft PR: [#237 — Natural Jungle Pass (C direction)](https://github.com/boodschappenmaatje/Bloedjungle-godot/pull/237)
- Branch-codecommit: `6e7701a26332a6c3f9b4767d5ebd6934a45ae52a` (de huidige PR-head bevat daarna alleen documentatie)
- iOS-export: [GitHub Actions-run 42425169497](https://github.com/boodschappenmaatje/Bloedjungle-godot/actions/runs/42425169497) — geslaagd.
- Unsigned IPA-artifact: `bloedjungle-ios-unsigned-b2753d6f6c9d058891cbef18aab7033d0cf1ef97`, artifact-id `13596000239`, 1.156.345.676 bytes; downloadbaar t/m 7 december 2026.
- Echte Godot-preview: [run 42425169412](https://github.com/boodschappenmaatje/Bloedjungle-godot/actions/runs/42425169412), [bospad PNG](captures/iterations/6e7701a/bospad.png). Dit is Linux llvmpipe software-Vulkan en geen iPhone-prestatiebewijs.

Open export-run 42425169497, download artifact 13596000239 en pak de ZIP uit. Onderteken de IPA met je eigen Apple-account en installeer via AltStore/AltServer of je bestaande iOS-installatieproces. Controleer dat de run bij branch-codecommit `6e7701a` hoort. Dit is een testbuild, geen OTA-release.

De bestaande grafische instellingen blijven staan. Pas renderresolutie niet aan om de visuele kwaliteit te beoordelen; de export bevat dezelfde speelinstellingen als de branch. De captureworkflow bevat voor het bospad ook een aparte 100%-schaalopname.

## Uitvoeren op de iPhone

Noteer iPhone-model, iOS-versie, kwaliteitsinstelling, render scale, Low Power Mode en accupercentage. Laat de game na starten 30 seconden opwarmen.

1. **Bospad — stilstaand, 60 seconden.** Maak een schermopname. Beoordeel grond- en grasdetail, zichtbare lage planten, pad en zicht op soldaten en schietlijnen.
2. **Bospad en rivier — beweging, 60 seconden.** Loop en ren langs het pad en de oever. Noteer shimmer, flikkering, LOD-sprongen, pop-in en planten die zichtlijnen blokkeren.
3. **Groot gevecht — minimaal 2 minuten.** Speel een representatieve zware encounter. Noteer aanhoudende haperingen en of besturing, camera en HUD responsief blijven.
4. **Kamp, gebouwen en oevers.** Controleer terreincontact, routes, zichtlijnen en collisions rond muren, torens, gebouwen en rivieroevers.
5. **Warmte — na minimaal 10 minuten spelen.** Noteer warmte, iOS-waarschuwingen en zichtbare throttling.

De HUD-FPS is een momentopname. Frametime en 1%-low zijn alleen gemeten als je daarvoor een Metal System Trace met Xcode Instruments maakt; anders vul je **niet gemeten** in. Shimmer, grote gevechten en thermiek blijven eveneens **niet gemeten** totdat de fysieke test is uitgevoerd. De `1 FPS` in de bijgevoegde CI-captures is llvmpipe-software en geen iPhone-uitkomst.

## Resultaten

- iPhone-model / iOS:
- Buildcommit:
- Kwaliteit / render scale / Low Power Mode:
- Bospad: FPS-bandbreedte en haperingen:
- Groot gevecht: laagste aanhoudende FPS en haperingen:
- Frametime / 1%-low (Instruments of **niet gemeten**):
- Shimmer / pop-in / LOD-sprongen:
- Warmte / throttling na 10 minuten:
- Zichtlijnen, besturing, HUD of collisions:
- Visuele indruk ten opzichte van de gekozen C-kwaliteitsrichting:
- Schermopname / notities:

Visuele acceptatie blijft open totdat de gebruiker de echte gamebuild heeft beoordeeld ten opzichte van de gekozen C-kwaliteitsrichting. Mobiele acceptatie blijft open totdat de fysieke iPhone-test is uitgevoerd en de resultaten zijn vastgelegd.
