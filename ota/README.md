# Updates zonder nieuwe IPA (OTA)

`basis.txt` bevat de commit waar de IPA van gebouwd is (de "base"). Een IPA krijgt deze waarde bij het bouwen mee in
`build_info.json`; de app past alleen patches toe die dezelfde base hebben.

Een update bestaat uit twee soorten stukken (manifest `schema` 3, gemaakt door `.github/workflows/ota.yml`):

- **Licht** (`licht`): alle gewijzigde scripts, scènes en kleine bestanden sinds de IPA. Klein; de app vervangt dit stuk bij elke
  update en laadt het als eerste (Updater), dus ook scripts en autoloads veranderen via een update.
- **Zwaar** (`zwaar`, een keten): gewijzigde modellen, texturen en geluid (`assets/**`, `source_assets/**`, `previews/**`). Elk stuk
  bevat alleen wat er sinds het vorige stuk veranderde; de eerste vergelijkt met de IPA (één groot stuk, eenmalig). De app downloadt alleen
  de stukken die hij mist en laadt ze bij elke start (`scripts/ota_keten.gd`, aangeroepen vanuit `Game._init`).
- **Brug** (`pck`): een piepkleine patch met alleen het nieuwe updatescherm. Apps met de oude updater uit de IPA geven downloads maar
  30 seconden; deze brug past daarin, daarna downloadt het nieuwe scherm zelf in blokken (hervatbaar, met procent, snelheid en tijd).

De splitsing is twee extra exportpresets (`tools/ota_presets.py`, afgeleid van "iOS"). Zware bestanden die scripts al bij het opstarten
met `preload` inladen kunnen niet via een vervolgstuk veranderen; `tools/ota_vroeg.py` ziet dat en de workflow begint dan een nieuwe
zware keten (één groot stuk).

Nieuwe IPA geïnstalleerd en wil je weer een lege keten? Zet in `basis.txt` een recentere commit, bouw een IPA (de workflow `ios.yml`
zet de base erin) en installeer die. Apps met een oudere base melden dan "installeer eerst de nieuwste IPA".

## Regels voor scripts (zware bestanden nooit met preload)

De zware keten wordt pas aangekoppeld in `Game._init`, **nadat** de scripts die Game, Sfx en hun klassen nodig hebben al gecompileerd zijn.
Een `preload("res://assets/...")` (of een preload van een scène/resource die zo'n bestand nodig heeft, zoals `vrachtwagen.tscn`) in zo'n
script faalt dan: het script compileert niet, en in het spel betekent dat o.a. een onzichtbare speler. Gebruik daarom `load()` op het moment
dat het nodig is, met een terugval als het bestand ontbreekt (zie `SoldierModel._laad_scene` en de terugvalketen voor het spelermodel).

- `tests/ota_vroeg_test.gd` faalt als er toch een zwaar bestand met preload staat (ook transitief, via scènes/resources).
- `tools/ota_simulatie.sh` bootst een telefoon na: IPA-basis + lichte patch + zware stukken, en start het spel (speler moet een zichtbaar model hebben).
- `tools/ota_brug_simulatie.sh` bootst de brug na: IPA-basis + alleen `brug.pck`; het updatescherm moet dan laden en zich opbouwen. Het scherm mag dus nooit een script of lid nodig hebben dat pas na de IPA bestaat (geen `preload` in `scripts/update_panel.gd`, alleen `load()` na een controle en `get()`). Brak dit, dan kom je op een telefoon met de brug niet meer in het updatemenu (v174, 2 november 2026). Snelle controle vooraf: `tests/ota_brug_test.gd`.
- `ota.yml` draait beide vlak vóór het manifest en de publicatie ("Safety net"). Slaagt dat niet, dan wordt er niets gepubliceerd.
  Bij een pull request levert de workflow alleen een preview (nooit gepubliceerd).

