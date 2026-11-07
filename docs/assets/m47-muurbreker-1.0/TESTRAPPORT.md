# M-47 Muurbreker Blender 1.0 — inspectierapport

**Status: geblokkeerd vóór assetproductie.** Er is geen nieuwe assetversie gegenereerd. Originele bestanden bleven ongewijzigd in `/tmp`.

## Verkrijging bronbestanden

Beide originelen zijn met de Drive `fetch`-downloadroute verkregen via de tijdelijke signed download-URL (de `download_file`-route had een limiet van 32 MiB).

- BLEND `1NMqUBBdEW484Dab1Jtmqf_84RFcm8qx_`: 62.820.483 bytes; herkend als Blender-bestand, opgeslagen met versie 4.04.
- GLB `1w07k_SetivIz8mmLEtxVneZ6IVmTkPZC`: 26.718.252 bytes; glTF binary v2.

## Batchinspectie (Blender 4.3.2)

| Bron | Mesh | Driehoeken | Materialen | Animaties |
| --- | --- | ---: | --- | --- |
| BLEND | `Mesh_0` | 631.171 | `Material_0` (Principled BSDF, image textures, normal map) | Geen actions |
| GLB | `Mesh_0` | 631.206 | `Material_0` (Principled BSDF, image textures, normal map) | Geen actions |

De GLB bevat daarnaast een 12-driehoeken `Cube` met standaardmateriaal. De bron- en GLB-triangeltellingen verschillen 35 driehoeken. Blender 4.3.2 waarschuwt dat de BLEND door een nieuwere Blender-binary is geschreven; de versie meldt expliciet mogelijk gegevensverlies bij openen.

## Niet aanwezig / niet geverifieerd

De bron bevat geen losse laadkamer en centrale kern en geen clips `Idle`, `Equip`, `Aim`, `Fire`, `Reload`. De gevraagde LOD's bestaan niet in deze bronnen. Scheiding van meshdelen, retopologie/decimatie, nieuwe animaties of opslaan vanuit een oudere Blender kan het goedgekeurde uiterlijk, PBR of onbekende nieuwere Blender-data wijzigen. Om die reden zijn zulke mutaties niet toegepast.

Godot 4.7.2 is niet geïnstalleerd/beschikbaar; deze omgeving heeft 4.6.3. Er is dus geen Godot-import-, schaal-, materiaal-, animatie- of regressietest volgens de vereiste versie uitgevoerd. Geen screenshots van een bewerkte of in Godot geladen asset geproduceerd.

## Conclusie

Er zijn geen resultaten voor LOD0 30k–60k, LOD1/LOD2, de vijf clips of losse mechanische onderdelen om aan te leveren of als intact te bevestigen. Voor veilige productie is een bronbestand nodig waarin beide mechanische onderdelen afzonderlijk beschikbaar zijn en compatibele Blender-versie, plus Godot 4.7.2 voor de vereiste verificatie. Dit rapport is de enige wijziging; bestaande gameplay, scenes en instellingen zijn ongemoeid.
