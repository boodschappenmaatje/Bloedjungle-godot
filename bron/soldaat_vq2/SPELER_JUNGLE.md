# Eerdere spelerlook — woodland Jungle-overlever (v1)

> Deze versie is bewaard als de eerdere look uit PR #135. De goedgekeurde standaard is nu de gedetailleerde Jungle Commando Tiger Stripe uit [JUNGLE_COMMANDO.md](JUNGLE_COMMANDO.md).

## Eerder ontwerp

Een originele, gespierde jungle-overlever voor de speler: woodland-camouflageuniform met lange mouwen, militaire broek, laarzen, koppel en de bestaande hoofdband. Het ontwerp gebruikt de bestaande VQ2-soldaatgeometrie en PBR-kaarten; het kopieert geen specifieke acteur, filmposter of merkbeeld.

## Behouden contract

- Alleen de standaardlook van de speler verandert. Bondgenoten en vijanden behouden hun huidige looks.
- De VQ2-`Rig` (53 DEF-botten), game-animaties, wapenmount, IK, colliders, schaal en spelerlogica blijven gelijk.
- Deze eerdere woodland-look blijft aanwezig in de geoptimaliseerde VQ2-bron.
- Eerdere saves met de oude standaard `bloot` migreren één keer naar `jungle`. De bewegingssnelheidsbonus blijft 6%; andere voortgang, uitrusting en bonuswaarden veranderen niet.
- De bestaande high-quality bron is `soldaat_vq2.blend`; de geoptimaliseerde, geanimeerde Godot-export blijft `assets/soldaat_vq2.glb`.

## Oud materiaal en preview

De woodland-camouflage gebruikte de bestaande 1024 × 1024 base-color-, normal- en ORM-set van `Lijf_Uniform`; de mesh heeft 7.648 driehoeken. De vroegere preview staat nog in iCloud Drive onder `Bloedjungle Previews/Player Jungle/1.0/`.

## Bestanden

- Oudere shared high-quality bron: `bron/soldaat_vq2/soldaat_vq2.blend`
- Oudere gedeelde Godot-gameasset: `assets/soldaat_vq2.glb`
- Oorspronkelijke previewgenerator: `bron/soldaat_vq2/maak_speler_jungle_preview.py`

Dit is een uiterlijkvariant van de al gerigde soldaat, geen tweede mesh-/rigimplementatie. Daarom blijft de bestaande `.blend` en `.glb` de ene bewerkbare bron en ene geoptimaliseerde gameasset.
