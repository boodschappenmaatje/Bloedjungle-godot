# MotionBricks — fase 2: retargeting en echte Godot-preview

**Repository:** boodschappenmaatje/Bloedjungle-godot  
**Branch:** feature/motionbricks-integration-1-0 (Draft PR #319)  
**Uitgangspunt:** fase 1 rapport op dezelfde branch, 16 november 2026.  
**Status:** uitvoeringsspecificatie; retargeting en Godot-integratie **nog niet gerealiseerd**.

## Doel

Laat aantoonbaar door MotionBricks.cpp gegenereerde `walk` en `walk_gun` animaties zien op een bestaand Bloedjungle-soldatenmodel in de geïsoleerde Godot-preview, naast de oude loopanimatie. Voor de eerste retargettest heeft het 28-bot Mixamo-model `assets/meshy_jungle_commando.glb` de voorkeur; een afzonderlijke 53-bot DEF-test op `assets/soldaat_jungle_commando.glb` is daarna vereist. Geen bestaande gameplay of basisconfiguratie wijzigen.

## Implementatievolgorde

1. **Bron vastzetten.** Gebruik de fase 1 geverifieerde MotionBricks.cpp-commit `60a5f4c0b5eef3d893d4a8c253cc3fc68924c559` en documenteer de GGML 0.20.2 override. Gebruik de modelhashes uit het upstream-downloadscript; commit geen GGUF-gewichten of gegenereerde tijdelijke modellen.
2. **Echte beweging genereren.** Produceer ten minste één `walk` en één `walk_gun` chunk met 30 FPS, 34 G1-gewrichten, lokale XYZW-quaternions en rootposities. Sla naast de gebakken animaties traceerbare metadata op (modelcommit, modelhash, stijl, frames, FPS, schaal/assen, duur).
3. **Skeletmetadata meten.** Lees de exacte namen, parent-indexen, restposes, botassen en karakterhoogte van G1 en de bestaande Mixamo-rig uit. Maak een expliciete G1→Mixamo-mapping met omzetting van gestapelde G1 pitch/yaw/roll-articulaties naar menselijke heup-, knie-, enkel-, schouder- en elleboogketens. Niet simpelweg botten op naam of index koppelen.
4. **Retargeting.** Zet G1 Y-up/meters om naar de rigcoördinaten en corrigeer restrotaties/segmentlengten. Verwerk pelvis/root, voeten, toe-contact en bovenlichaam. Behoud menselijke rigvingers in rustpose waar G1 geen equivalent heeft. Normaliseer quaternions en controleer discontinuïteiten.
5. **Bake.** Exporteer alleen de minimaal benodigde, deterministische Godot-animaties (.tres of compatibel GLB) onder `prototypes/motionbricks/`, zonder MotionBricks-inferentie op de renderthread of in de iOS-build.
6. **Geïsoleerde viewer.** Toon een bestaande soldaat en bied een directe omschakeling tussen oud lopen, MotionBricks walk en MotionBricks walk_gun. Vermeld expliciet in de viewer welke clip MotionBricks-data gebruikt. Voeg indien mogelijk video/captures van dezelfde camera en afspeelsnelheid toe.
7. **Test en rapport.** Automatiseer checks voor frameaantal, tijdstappen, eindige transformaties, quaternionnormen, botlengten, voeten, rootverplaatsing en clip-overgangen. Test headless scene-load, handmatige visuele posevalidatie en regressie van de bestaande clips. Geef meetresultaten met PASS/FAIL/NOT TESTED; geen ongefundeerde kwaliteitsclaim.

## Acceptatiecriteria

- [ ] `walk` en `walk_gun` hebben **aantoonbare echte MotionBricks.cpp-output** als bron (geen Mixamo-vervanging, procedurele verzinsels of placeholder).
- [ ] G1→Mixamo mapping is reproduceerbaar, inclusief restposes, assen, schaal en root.
- [ ] Op een geskinnde bestaande soldaat worden beide gebakken bewegingen in Godot werkelijk afgespeeld.
- [ ] Preview kan betrouwbaar vergelijken met de bestaande loopclip.
- [ ] Animatie bevat geen zichtbare omgedraaide knieën, geflipte polsen, zwevende voeten of abrupte loops zonder expliciet gedocumenteerde beperkingen.
- [ ] Validatie noemt tests en status; Windows en fysieke iPhone worden **NOT TESTED** genoemd tenzij daadwerkelijk uitgevoerd.
- [ ] Geen wijziging aan bestaande gameplay, input, grafische defaults of instellingen.
- [ ] Geen nieuwe grote modelweights in de game en geen live inference in iOS.
- [ ] Draft PR blijft open; **geen merge of OTA** zonder apart akkoord.

## Reeds bekende risico's

- De upstream G1-robotrig heeft 34 gewrichten en verschilt fundamenteel van de 28-bot Mixamo- en 53-bot DEF-rigs.
- De officiële Chromium UI-test uit fase 1 is FAIL; native inferentie is wel bewezen.
- De fase 1 CPU-planmetingen van 149–199 ms zijn containerwaarden, geen fysieke iPhone- of Windows-metingen.
- Godot 4.7.2 headless afsluiting meldde zeven ObjectDB-instances; opnieuw controleren of dit regressies betreft.
- De eerder goedgekeurde opschoning betreft uitsluitend lokaal aangemaakte, niet-gecommitte .uid-sidecars; geen brede git clean.

## Volgende releasepoort

Een visueel beoordeelbare MotionBricks-preview en aantoonbare retargeted clips zijn verplicht vóór enige bespreking van merge, OTA of runtime-MCP/GDExtension-integratie.
