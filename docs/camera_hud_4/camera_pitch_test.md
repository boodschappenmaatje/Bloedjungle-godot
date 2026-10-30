# Camerahoek testen — Bloedjungle iPhone / Xogot

Deze proef maakt de **schuinheid** van de normale 3D-gameplaycamera instelbaar van **35° tot 75° boven de horizon**. Er is geen technisch bevestigde originele Dead Nation-pitch; deze waarden zijn bedoeld om zelf visueel te vergelijken.

## Gebruik
1. Open in Working Copy de branch `feature/camera-pitch-control-20261030` van `boodschappenmaatje/Bloedjungle-godot`, update en open `project.godot` in Xogot.
2. Start `scenes/main.tscn` met de telefoon liggend.
3. Ga naar **Pauze > Instellingen > Camerahoek · testen**.
4. Kies 40°, 53° (Bloedjungle-standaard), 65° of gebruik de schuifregelaar tussen 35° en 75°, in stappen van 1°.
5. Tik **TEST MET DEZE CAMERAHOEK** om het spel te hervatten. Maak voor elke hoek een screenshot vanaf dezelfde plek in de wereld.
6. De instelling wordt lokaal opgeslagen en blijft bij de volgende sessie behouden.

## Begrippen
- **35°:** meer horizontale diepte; silhouet van speler en tank groter zichtbaar, minder grondoppervlak in de verte.
- **53°:** bestaande Bloedjungle-kijkhoek vóór deze proef.
- **75°:** hoger, sterker van bovenaf; meer terrein zichtbaar en minder front-/zijaanzicht.

Dit is alleen de pitch; **FOV blijft 45°** en de normale gameplayafstand blijft onveranderd (22,5 m standaard / 20 m in bestaande gevechtscamerastand). De camera volgt de speler. Automatische tijdelijke kadrering voor tanks en grotere groepen blijft intact om afgesneden voertuigen te voorkomen. Editor-/bouwcamera blijven apart en krijgen niet de ingestelde gameplaypitch.

## Handmatige zoom verwijderd
Pinch-gebaren in de gameplay, muiswielzoom en de +/- zoomknoppen zijn uitgeschakeld. Alleen de hoek in Instellingen kan door de gebruiker worden veranderd; de gewone camera blijft tijdens gameplay in die gekozen hoek.

## Nog te verifiëren
- Open de instellingen op iPhone en beweeg de slider; de beweging mag de scrolllijst niet verschuiven.
- Vergelijk identieke gameplayposities met 40°, 53° en 65°.
- Controleer een bestelde en uitgeparkeerde tank; na het verlaten van de garage moet de camera goed blijven volgen.
- Controleer pinch: met twee vingers in het spel mag de cameraafstand niet veranderen.
- Controleer intacte touchsticks, schietknop en aanraakfuncties.
- Controleer of de instelling na herstart behouden blijft.

De featurebranch is niet naar main gemerged en niet via OTA gepubliceerd. Static source checks zijn gedaan; **Godot-runtime- en iPhone-tests zijn nog niet uitgevoerd**.
