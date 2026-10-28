# Speelbare soldaat — Jungle-overlever

## Ontwerp

Een originele, gespierde jungle-overlever voor de speler: woodland-camouflageuniform met lange mouwen, militaire broek, laarzen, koppel en de bestaande hoofdband. Het ontwerp gebruikt de bestaande VQ2-soldaatgeometrie en PBR-kaarten; het kopieert geen specifieke acteur, filmposter of merkbeeld.

## Gameplaycontract

- Alleen de standaardlook van de speler verandert. Bondgenoten en vijanden behouden hun huidige looks.
- De bestaande VQ2-`Rig` (53 DEF-botten), alle game-animaties, wapenmount, IK, schiet-/geraakt-houdingen, colliders, maat en spelerlogica blijven gelijk.
- De huidige ongeklede look blijft beschikbaar als cosmetische keuze.
- Eerdere saves met de oude standaard `bloot` migreren één keer naar `jungle`. De bewegingssnelheidsbonus blijft 6%; andere voortgang, uitrusting en bonuswaarden veranderen niet.
- De bestaande high-quality bron is `soldaat_vq2.blend`; de geoptimaliseerde, geanimeerde Godot-export blijft `assets/soldaat_vq2.glb`.

## Materialen en animaties

De woodland-camouflage is de bestaande 1024 × 1024 base-color-, normal- en ORM-set van `Lijf_Uniform`; de mesh heeft 7.648 driehoeken. Koppel, hoofdband en laarzen blijven afzonderlijke, gerigde onderdelen met de bestaande atlas. Het spel blijft dezelfde clips gebruiken (`stil`, `lopen`, `rennen`, `schieten`, `herladen`, enz.). De iPhone-preview gebruikt de echte `lopen`-actie als die door USD Quick Look wordt ondersteund.

## Bestanden

- High-quality bron: `bron/soldaat_vq2/soldaat_vq2.blend`
- Godot-gameasset: `assets/soldaat_vq2.glb`
- Herhaalbare iPhone-variant: `bron/soldaat_vq2/maak_speler_jungle_preview.py`
- Afzonderlijke USDZ-preview wordt opgeslagen in iCloud Drive onder `Bloedjungle Previews/Player Jungle/1.0/`.

Dit is een uiterlijkvariant van de al gerigde soldaat, geen tweede mesh-/rigimplementatie. Daarom blijft de bestaande `.blend` en `.glb` de ene bewerkbare bron en ene geoptimaliseerde gameasset.
