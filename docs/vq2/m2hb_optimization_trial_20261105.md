# M2HB-toren — technische optimalisatieproef (5 november 2026)

**Gebruikersbesluit:** het bestaande Meshy-model is visueel definitief goedgekeurd. **Geen veranderingen aan het ontwerp, geen vervangende gegenereerde toren.** Toestemming op 5 november voor technische verwerking, botsingen en bewegende delen; **niet** voor merge naar `main` of OTA-publicatie.

**Bron:** [door Dennis geleverd Meshy OBJ in Drive](https://drive.google.com/file/d/1gl5CrJgdwT8JSqOcK_vR22GlBdmffV4v/view?usp=drivesdk), originele bytes onaangeraakt. Het bestand met .obj-extensie is een ZIP met OBJ, MTL en diffuse 4096×4096 PNG. SHA-256 bron: `d023680c07b59a7505cc1a46c062b2b1de0477781c3324c6beac10eed495a94e`. Oorspronkelijk **2.486.536** triangles.

## Werkelijk vervaardigde proefexports

De exports zijn in de huidige ChatGPT-taakomgeving vervaardigd en als **`Bloedjungle_M2HB_Toren_Technisch_Pakket.zip`** bij de gesprekbijlagen beschikbaar gesteld. De grote GLB-binaries staan **niet** op deze GitHub-branch; voer pas bestandsintegratie uit zodra de bytes gecontroleerd op de projectassetlocatie staan. Verwar het bestaan van de exports niet met ingebouwde gamefunctionaliteit.

| Asset | Triangles | Resolutie | Bytes | SHA-256 |
|---|---:|---:|---:|---|
| `Bloedjungle_M2HB_Toren_LOD0.glb` | **162.806** | origineel albedo 4096² | 27.133.820 | `2ab1c100646305a62e6651c9179d9f9f9e004553388667b32513f75d4160eb9d` |
| `Bloedjungle_M2HB_Toren_LOD1.glb` | **49.443** | albedo 2048² | 8.935.220 | `ed18bcd8b604197a02764de83cbb0ed19fd2300e3c157aad4b698f51f21dbce3` |
| `Bloedjungle_M2HB_Toren_LOD2.glb` | **20.344** | albedo 1024² | 2.716.612 | `1e591fb4c8c4327448e9a9b5a57f4e75d4a87634ac04da3bc6f874a2daca2405` |

**Proces:** OBJ precies op oorspronkelijke `v/vt`-indexrelaties ingelezen, microcel-clustering (ruimtelijk + textuurcoördinaten) voor technische decimatie, onafhankelijke game-GLB's geëxporteerd, herladen via trimesh en de embedded texture/triangles/boundingbox gecontroleerd. Er is geen nieuwe vorm ontworpen en geen originele OBJ/MTL/PNG overschreven.

**Afmetingen:** uniforme schaal naar 6,0 m hoogte; buitenste zichtbare boundingbox ca. **4,50 × 3,41 × 6,00 m** (breedte×diepte×hoogte). Dit omvat de uitstekende Browning, rails en andere details; het is **geen bewijs** voor de voetafdruk van de dragende constructie. De eis van 2,6×2,6 m constructievoet moet in Blender apart worden nagemeten. Als de buitenvorm botst met het bestaande fort, niet non-uniform schalen of Meshy-model herontwerpen; oplossing eerst lokaal beoordelen.

## Visuele controle en beperkingen

- **LOD0:** een echte VTK-headlessrender uit de geproduceerde GLB toont de bedoelde torenvorm, kleur en M2; kandidaat voor de volgende Blender-/Godot-verwerking, maar nog **niet visueel vergeleken met een render van de originele 2,49M-face bron** en **niet door Dennis goedgekeurd**.
- **LOD1:** visuele vergelijking op dezelfde camera toont **duidelijk meer gaten/fragmentatie en vereenvoudiging rond rails en wapendelen**. **Niet als goedgekeurde iPhone-LOD gebruiken.**
- **LOD2:** technische import slaagt maar visuele kwaliteit nog niet beoordeeld. **Niet als goedgekeurde iPhone-LOD gebruiken.**
- **Geen losse MG-onderdelen, geen rig, geen werkelijke animatieclips, geen 3D-collision en geen Godot-gameplay** in deze exports. De OBJ had geen animaties. Technische scheiding van de originele MG vereist gecontroleerd Blender-werk zonder zichtbaar herontwerp.
- **Niet getest:** Godot-import, iPhone FPS/geheugen, blokkeren van muren, schutterhits, overnemen/klimmen, schieten, offscreen-beleg.
- De experimenten mogen niet als `5a-3b gereed` worden gemarkeerd. Controleer bron-vs-LOD0 visueel en valideer in native Godot voordat vier torens live worden.

## Vervolgstappen, binnen reeds gegeven toestemming

1. Lever/reproduceer de 4K LOD0-GLB op een voor Godot bereikbare assetlocatie; verifieer checksum. Bewaar de originele bron als autoritatieve visuele referentie.
2. Maak in Blender echte losse pivots voor `MG_Yaw`, `MG_Pitch`, `Muzzle`, `ShooterMount`, ladderankers en botsvormen, **met precies hetzelfde uiterlijk**. Verwijder of herwerk geen herkenbare delen zonder controle.
3. Implementeer in de bestaande scripts vier instances op de oorspronkelijke hoeken met 650 HP en bereik 36 m; een schutter en een toren hebben aparte hit-colliders.
4. Daarna 12 echte, persistente verdedigers, reserve-ladderbeklimming, 8×6-salvo's, sightline-tests en aansluiting op het veraf-beleg.
5. Laat Dennis de 3D-viewer / native iPhone vergelijken; pas na goedkeuring van zowel uiterlijk als gameplay kan dit uit Draft.

**Publicatie:** geen merge, geen OTA, geen wijziging van de door de gebruiker goedgekeurde uiterlijkkeuze.
