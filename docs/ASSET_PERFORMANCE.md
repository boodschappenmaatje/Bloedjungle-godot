# Assetprestaties en Godot 4

## Bestandsgrootte en detail

- 71 nieuwe binaire bestanden: 54 texturemaps, 16 GLB-modellen en één HDRI. Samen 17.322.936 bytes (16,52 MiB).
- Vijf bestaande binaire bestanden op deze branch: 3.472.976 bytes. Samen met de assetbibliotheek: 20.795.912 bytes (19,83 MiB), exclusief metadata, Blender-bronnen en Godot-caches.
- 18 PBR-materiaalsets gebruiken drie maps per set. Van die 54 maps hebben er 12 echte 2048×2048-brondetail (4 sets, output 1024×1024); 42 maps uit de andere 14 sets hebben maximaal 512px brondetail, ondanks 1024×1024-output.
- Geen nieuwe 1K- of 2K-textuurbron kon worden opgehaald: Poly Haven API/downloadhosts antwoordden met proxy-403. De bestaande texturen blijven intact.
- De HDRI is 2048×1024 en 4.434.394 bytes en wordt niet automatisch als actieve belichting gebruikt.
- Git LFS is beschikbaar; geen bestand vereist LFS.

## Modellen

De nieuwe H-Hut GLB is 98 KiB, 1.627 driehoeken, één mesh, één materiaal, geen afbeeldingen of externe dependencies. Blender-bronmaat is ongeveer 38×28×6 m; Y-up is toegepast en een scene kan de maat schalen. De overige objecten zijn herbruikbare losse GLB's. Bestaande Apache, tank, soldaat en Jeep-verwijzing zijn niet vervangen of gedupliceerd.

Er zijn geen nieuwe vegetatiemodellen met transparantie of extra foliage-overdraw toegevoegd. De H-Hut heeft geen transparante texturen. GLB-assets bevatten hun gebruikte materialen/afbeeldingen intern; er zijn geen ontbrekende externe afhankelijkheden.

## Import en projectintegriteit

Godot 4.6.3 headless importeert de JPEG-, GLB- en HDR-assets. De volledige assetbatch is via de manifest- en lock-hashes gecontroleerd; alle 18 `StandardMaterial3D`-sets moeten elk base color, `normal_gl` en roughness behouden. De H-Hut is eveneens headless geïmporteerd. Statische controles verifiëren GLB 2.0-headers, meshes en afwezigheid van losse URI-dependencies.

Bestaande scenes, gameplay, shaders, renderer, projectinstellingen en exportinstellingen zijn niet aangepast. Import bewijst geen artistieke plaatsing of iPhone-framerate; daarvoor is een Xogot-run op toestel nodig. De huidige bibliotheek is geschikt als input voor Visual Upgrade 4, met de genoemde ontbrekende militaire modellen en beperkt brondetail als resterende kwaliteitsgaten.
