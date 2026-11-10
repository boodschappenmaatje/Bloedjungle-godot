# Colt M1911A1 schot en inslag — ontwerp

## Doel
De goedgekeurde tweede mockup is de visuele richting: een korte, krachtige oranje-witte vuurflits, een zichtbare maar smalle amberkleurige kogelbaan, en sterke inslagen op beton en boomschors. De omgeving en het Colt-model blijven realistisch; het schietmoment mag arcade-energie hebben.

## Grenzen
- Alleen de Colt; bestaande audio, schade, vuursnelheid, besturing en andere wapens blijven intact.
- Betonnen muren: contactflits, stof, kleine brokjes, donker kogelgat.
- Hout en boomstammen: stof, enkele schorssplinters, donkere beschadiging.
- Kogelsporen blijven zichtbaar, maar de oudste verdwijnen bij een limiet.
- Bouw in bestaande Draft PR #269; geen merge of OTA vóór review in een geanimeerde 3D-viewer.
- De viewer toont het echte M1911 GLB-model en zijn schotclip plus een benadering van de Godot-effecten; een browserpreview bewijst geen iPhone-prestaties.

## Aanpak
A: bestaande deeltjes en decals verfijnen, goedkoop maar visueel beperkt. B: de bestaande Colt-flipbookflits koppelen aan eigen materiaalreacties met 3D-deeltjes en blijvende decals, onder de bestaande poollimieten. Gekozen: B.

## Acceptatie
Viewer kan schot naar muur of boom afspelen, pauzeren en scrubben. In Godot is de nieuwe look opt-in voor de Colt; legacy blijft beschikbaar voor A/B. Automatische tests controleren Colt-isolatie, impactmaterialen en effectlimieten. Een native iPhone-test volgt pas na afzonderlijk goedgekeurde distributie.
