# Assetprestaties en Godot 4

## Bestandsgrootte

- 70 nieuwe binaire assets: 54 textuurmaps, 15 GLB-modellen en één HDRI. Samen 17.223.044 bytes (16,43 MiB).
- Vijf bestaande binaire assets op de branch: 3.472.976 bytes. Bestaand plus nieuw: 20.696.020 bytes (19,74 MiB), exclusief metadata, Blender-bronnen en Godot-caches.
- 18 Godot `StandardMaterial3D`-bestanden koppelen de drie PBR-maps per set. De 14 Poly Haven-sets hebben maximaal 512px effectief brondetail, ondanks 1024 × 1024 output.
- De HDRI is 2048 × 1024 en 4.434.394 bytes. Hij wordt nog niet als actieve belichting gebruikt.
- Git LFS is beschikbaar, maar geen van de nieuwe bestanden vereist LFS. Zo blijven gewone GitHub- en Xogot-downloads eenvoudig.

## Godot-import en plaatsing

Godot 4.6.3 importeerde JPEG-, GLB- en HDR-bestanden headless zonder fouten. Het downloadscript controleert de bron-SHA-256, de geplaatste SHA-256, bestandstype en afmetingen. Alle GLB's zijn glTF 2.0 zonder ontbrekende externe buffers of afbeeldingen; losse Kenney-kleurkaarten zijn bij het downloaden in de GLB ingepakt.

De eindcontrole vergeleek alle 70 bestanden met het manifest en de hashregistratie: nul ontbrekende, corrupte of dubbele bestanden. Godot laadde alle 18 `StandardMaterial3D`-bestanden met base color, normalmap en roughnessmap. De headless-import eindigde met code 0 en zonder fout- of waarschuwingsregels.

Godot maakt lokaal enkele PNG's uit ingepakte GLB-afbeeldingen. Die worden opnieuw gegenereerd en staan daarom in `.gitignore`. De `.glb`-bestanden en de `material.tres`-bestanden staan in Git.

De modellen volgen de glTF-conventie met Y omhoog. Schaal blijft per scene te kiezen. De palm is circa 1,5 m hoog en kan voor een grote palm 4–6× worden geschaald. De varen beslaat circa 9 × 2,7 × 8,5 broneenheden en vraagt voor een losse plant circa 0,1×. De vrachtwagenbasis is circa 2 × 2,15 × 2,75 broneenheden en vraagt mogelijk 1,5–2×. Deze maten komen van statische meshgrenzen; visuele plaatsing op Windows en iPhone is nog niet getest.

De modellen worden niet automatisch in het level geplaatst. Bestaande scenes, gameplay, shaders, projectinstellingen en exportinstellingen zijn niet gewijzigd. iPhone-geheugen- en frameratemetingen vereisen plaatsing in een scene en een echte Xogot-run.
