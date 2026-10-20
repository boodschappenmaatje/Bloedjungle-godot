# Assetprestaties en Godot 4

- Materiaalsets gebruiken alleen base color, Normal GL en roughness. De 2K-bronbestanden worden tijdens downloaden tot 1024 × 1024 JPEG verkleind. NormalDX en onnodige AO/height-maps worden niet toegevoegd.
- Modellen zijn zelfstandige GLB 2.0-bestanden. Het script controleert de binaire container, meshes en ontbrekende externe buffer- of afbeeldingsbestanden. Werkelijke meterschaal en oriëntatie moeten bij plaatsing in een scene worden bekeken.
- De 2K-HDRI is alleen bibliotheekmateriaal; de huidige belichting en renderinstellingen blijven intact. Een panoramische HDRI kan relatief veel geheugen kosten op iPhone, dus pas na een apparaatmeting gebruiken.
- De bestaande tank, Apache en soldaat staan op hun huidige locatie. De nieuwe modellen worden niet automatisch in het level geplaatst en verhogen daardoor het huidige runtime-geheugengebruik niet.
- Git LFS is aanwezig. Toegevoegde bestanden blijven onder GitHub's bestandslimiet; LFS wordt voor deze batches niet ingeschakeld om Xogot en gewone ZIP-downloads eenvoudig te houden.

Een Godot 4 headless-importtest en exacte omvang worden na de laatste batch hier genoteerd.
