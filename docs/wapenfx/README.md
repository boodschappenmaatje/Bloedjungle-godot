# Wapeneffecten AAA (shotgun en M1911)

Gekozen door Dennis op 11 november 2026: **1A 2A 3A 4A 5C 6A 7A 8A 9A**. Alleen de shotgun (Winchester M1897, id `trench`) en het pistool (M1911A1, id `m1911`) krijgen de nieuwe effecten. Thompson, Garand, MG42 en de jeep-MG blijven zoals ze zijn (vervolg na jouw oordeel).

Aan/uit: Instellingen > BEELD > **Wapeneffecten (shotgun, pistool)**: Nieuw of Klassiek. Klassiek geeft exact het oude gedrag. Trilling apart: Instellingen > GELUID & BESTURING > **Trilling bij schieten**.

## Wat er per schot gebeurt

| Keuze | Laag | Uitwerking |
|---|---|---|
| 1A | Vlam | Flipbook (4x4 beelden) plat op loophoogte, dus van bovenaf goed zichtbaar. Pistool klein en scherp, shotgun een grote vuurbal met zijvlammen. Het oude pistoolplaatje stond rechtop en was vanuit de spelcamera bijna onzichtbaar. |
| 2A | Licht | Zachte lichtvlek op de grond (geen schaduw) plus een kort omni-licht, maximaal 2 tegelijk. |
| 3A | Sporen | Dun, kort lichtstreepje (pistool 1,1 m, korrel 0,62 m) in plaats van de 2,2 m dikke staaf. Alle 9 shotgunkorrels hebben nu een spoor. |
| 4A | Rook | Pluim van wolkjes die uit de loop drijft, afremt, opzwelt en vervaagt (shotgun 6, pistool 2). Een klein rookje bij herladen, alleen binnen 3,5 s na schieten. |
| 5C | Landing en treffer | Een kogel die niets raakt zakt in zijn laatste 40% naar de grond en laat daar stof, aarde en grassprieten achter; pistool ook een gaatje van 20 s. Raakt hij een vijand: bloedspat in de richting van het schot, een extra stevige terugslag in zijn animatie en een tik. |
| 6A | Hulzen | Pistool: groter messing hulsje. Shotgun: rood met koperen bodem. Ze stuiteren één keer en tinken. |
| 7A | Gevoel | Camerakick (shotgun 0,028, pistool 0,008), bestaande wapenstoot van de soldaat, haptische tik op iOS en Android. |
| 8A | Geluid | Shotgun: eigen gelaagd bestand (knal, dreun, gas, pompklak op 0,36 s, jungle-staart). Pistool: bestaande opname plus een staart. Hulsje-tink en treffertik. |

## Geluid: let op
De geluiden zijn **zelf gesynthetiseerd** (`bron/wapenfx/maak_geluid.py`), geen echte opnames: er was geen offline CC0-bron met een betrouwbare licentie. Ze zijn bedoeld als stevige tussenstap; een echte opname kan later één-op-één dezelfde bestandsnaam krijgen in `assets/wapenfx/geluid/`. Op de iPhone beluisteren is nog nodig.

## Prestatiebudget (alles uit voorraden, geen schaduwkaarten)
- Vlam: max 4 per wapen tegelijk, lichtvlek max 4, licht max 2, rook max 22, stof max 14.
- Bestaande grenzen blijven gelden: 48 flash-quads, 40 bursts, 36 hulzen.
- Alleen binnen 38 m van de camera. Boven de grenzen wordt een effect overgeslagen, nooit de frametijd opgerekt.
- Kogelspoor: 1 vlak per kogel (geen bol meer).
- Meting op de iPhone: **NIET GETEST**. Xogot-fps telt niet als maatstaf.

## Bronnen en tests
- `bron/wapenfx/maak_wapenfx.py`: vlam-flipbooks en rook (numpy, vaste seeds). `maak_geluid.py`: geluiden.
- `assets/wapenfx/`: plaatjes, shader en geluiden. `scripts/wapenfx.gd`: alle logica en voorraden.
- `tests/wapenfx_test.gd`: voorraden begrensd, Klassiek ongewijzigd, spoor, huls, landing, opruimen.
- `tests/wapenfx_foto.gd`: voor/na-opnames met identieke camera en seed (`BJ_WFX=nieuw|klassiek`).
