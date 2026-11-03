# Voorraadtrucks: verkeer (v186)

Dennis meldde (v182, native iPhone): de voorraadtrucks rijden door elkaar heen. Gevraagd: als er een laadt of lost moet de ander wachten tot hij klaar is of tot
er ruimte is, trucks mogen niet door elkaar heen, en ze mogen niet in de poort in de weg gaan staan. De regels staan in `scripts/voorraad_verkeer.gd`
(klasse `VoorraadVerkeer`, per truck één instantie); `scripts/voorraad_truck.gd` roept ze aan, `scripts/voorraad.gd` beheert de sleutels.

## Wat de trucks nu doen

| Regel | Hoe |
|---|---|
| **Rijstroken** | Een truck rijdt 1,8 m rechts van het midden van de weg (`VoorraadBaan.rijstrook`); heen en terug zitten dus 3,6 m uit elkaar en passeren elkaar. Bij een laad- of losplek loopt de strook over 10 m naar het midden, zodat de truck precies op zijn plek komt. Op de brug en in de stad (smal) rijdt hij over het midden. |
| **Eén laadt, de rest wacht** | Elke stapel en elk depot heeft een sleutel (`Voorraad.claim_resource`). Wie later komt wacht op een recht stuk weg 15 m voor de plek (niet in een bocht, nooit in of vlak voor de poort) tot de sleutel vrij is. De sleutel komt vrij als de truck die klaar is 11 m weg is. |
| **Poort vrij** | De poortvakken (de opening plus de ruimte waarin het hek schuift) zijn verboden om stil te staan. Een truck stopt er altijd vóór, ook als de truck voor hem pas voorbij de poort staat. De wachtplek bij een stapel ligt minstens 16 m buiten de poort. |
| **Kruispunt bij de poort** | De twee depots naast elkaar, het stuk ertussen en de poort zijn samen voor één truck tegelijk (sleutel `poort:n` of `poort:z`). Een truck die terugkomt pakt eerst de losplek en dan die sleutel; hij houdt hem tot hij gelost heeft en weer buiten de poort is. Zonder dit zwaaien trucks van twee depots in elkaar. |
| **Eén truck per stapel** | `Voorraad.pick_slot` stuurt niet meer dan `QUEUE_MAX` (1) truck tegelijk naar dezelfde stapel; een volgende kiest een andere stapel of wacht in het depot. Zo staat er geen rij op de weg. (Kiest de speler zelf een bestemming, dan komt er wel een rij: die wacht op de wachtplek.) |
| **Afstand houden** | Elke truck kijkt langs zijn eigen baan vooruit (met zijn echte vak, dus ook in bochten) en remt op tijd. Bij een tegenligger of kruising heeft de truck met lading terug voorrang, daarna de oudste; de ander blijft staan tot er ruimte is. |
| **Brug en stad** | Smal: één truck tegelijk, de volgende wacht vóór de brug. |
| **Gekochte truck** | Verschijnt pas als de laadplek van het depot vrij is (en niemand binnen 9 m staat); tot dan telt hij mee voor het maximum van 3 per depot en staat hij als "wacht tot de laadplek vrij is" in het depotpaneel. |
| **Vastzitten** | Wachten is normaal. Alleen een kring (A wacht op B, B op A, ook via een bezette plek) is een noodgeval: de truck die op een plek wacht (anders de laagste voorrang) rijdt 8 m achteruit over zijn eigen baan; trucks achter hem eerst. Helpt dat na 20 s niet, dan rijdt hij kort door de ander heen (teller `ghosts`, hoort in de tests 0 te zijn). |
| **Stapel leeg onderweg** | Wacht een truck op een stapel die intussen leeg is, dan gaat hij terug naar het depot. |

Bewust niet: een **wrak** blokkeert de weg niet (een wrak is uit het spel en trucks rijden er dwars doorheen).

## Metingen (headless, 60 fps, eigen botsvakken 6,6 × 2,2 m)

Beelden waarin twee trucks elkaar overlappen, per scenario (de oude situatie, v182, rijdt alle trucks in een rij door elkaar):

| Scenario | Overlap | Vastlopers | Ritten |
|---|---|---|---|
| v182, 3 trucks, 240 s | 943 beelden (15,7 s) | n.v.t. | — |
| v183, 3 trucks bij één depot, 200 s | **0** | 0 | 6 |
| v183, 3 trucks, bestemming bos (rij op de wachtplek), 200 s | **0** | 0 | 6 |
| v183, 3 trucks, bestemming stad (smalle brug), 200 s | **0** | 0 | 3 |
| v183, 2 depots (3 + 1 trucks), 300 s | **0** | 0 | 10 |
| v183, 2 depots (3 + 2 trucks), 300 s | **0** | 0 | 9 |
| v183, 2 depots (3 + 3 trucks), 300 s | 245 beelden (4 s, één keer) | 0 | 9 |

Het laatste scenario (6 trucks, twee depots naast elkaar, allemaal tegelijk onderweg) is het drukst dat het spel toelaat; daar kruisen twee trucks één keer
4 seconden lang in de bocht van het bospad. Dat is nog niet weg.

## Verhouding tot v185 (PR #206, FIFO)

Terwijl deze regeling klaar werd, kwam op main een andere oplossing (PR #206, door Codex): een centrale FIFO-rij waarbij maar één truck tegelijk een
volledige rit rijdt, met parkeerhavens bij het depot. Die maakt overlap onmogelijk, maar extra trucks leveren dan bijna niets extra op. Beide zijn in
dezelfde headless simulatie (60 fps, botsvak 6,6 × 2,2 m, wegwerpscript, niet in de repo) gemeten:

| Scenario | v185 (FIFO) | Deze regeling (v186) |
|---|---|---|
| 3 trucks bij één depot, 200 s | 3 ritten, 420 punten, overlap 0 | 5 ritten, 780 punten, overlap 0 |
| 6 trucks, twee depots, 300 s | 4 ritten, 560 punten, overlap 0 | 9 ritten, 1480 punten, overlap 4 s (één keer) |

Met deze regeling rijden trucks tegelijk en wachten ze op elkaar (zoals Dennis vroeg: "tot de ander klaar is of tot er ruimte is"). In v186 vervangt
dit de FIFO-regeling van v185 (`traffic_request`, parkeerhavens, `S.PARK`, de tests `voorraad_verkeer_unit_test` en `voorraad_verkeer_fastsim_test`
en de v185-workflow); de workflow `voorraad-verkeer.yml` draait nu de baan-, voorraad- en verkeerstest.

## Tests

- `tests/voorraad_verkeer_test.gd` (nieuw): rekenwerk (vakken, poortvak, smal stuk), 3 trucks 80 s zonder overlap, zonder noodgevallen, niet in de poort,
  geld komt binnen; daarna 90 s met de stad als bestemming: nooit twee trucks op de brug; een gekochte truck wacht tot de laadplek vrij is.
- `tests/voorraad_baan_test.gd`: rijstrook (zijde, uiteinden precies op de plek, glad, smal stuk). De grens voor de richtingssprong van de heenroute
  is van 0,12 naar 0,18 rad per 2 m gegaan, omdat `Voorraad.route` wegpunten vlak bij elkaar samenvoegt (heen en terug rijden dan dezelfde lijn).
- `tests/voorraad_test.gd`: ongewijzigd en groen.

## NIET GETEST

- **Native iPhone-app**: geen meting van beeldsnelheid of gedrag. De verkeersberekening is per truck elke 0,05 s een controle van een paar tientallen punten
  langs de baan tegen de andere trucks; dat is licht, maar niet op de telefoon gemeten.
- Niet met echte aanraking of met veel andere gevechten tegelijk; alleen de headless simulatie.
- Wat Dennis in het spel nog kan zien: een truck die even stilstaat voor een truck die laadt of lost (bedoeld), en trucks die bij twee depots naast elkaar
  om beurten door de poort gaan (bedoeld).
