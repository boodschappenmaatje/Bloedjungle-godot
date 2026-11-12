# F2 Garnizoen — native iPhone-acceptatieplan

Datum: 12 november 2026. Status: voorbereid, **niet native getest**, niet via OTA gepubliceerd in de gecontroleerde PR-run.

## Broncontrole

- Implementatie: [PR #299](https://github.com/boodschappenmaatje/Bloedjungle-godot/pull/299), **merged** in main; head SHA `6d98b47c9e70c364e79a88e64b8418bbb08cae77`.
- Vijandbasis CI: [run 43202516686](https://github.com/boodschappenmaatje/Bloedjungle-godot/actions/runs/43202516686), succes; stap 'Garnizoen in de stad (F2)' geslaagd.
- iOS unsigned export: [run 43202516717](https://github.com/boodschappenmaatje/Bloedjungle-godot/actions/runs/43202516717), succes; unsigned IPA artifact beschikbaar. Dit is niet een fysieke iPhone-test.
- OTA-preview: [run 43202516683](https://github.com/boodschappenmaatje/Bloedjungle-godot/actions/runs/43202516683), succesvol; 'Publish to the updates release' **skipped**. Een groene OTA-run betekent geen publicatie.
- Let op: een bestaande geïnstalleerde iPhone-build bevat F2 niet noodzakelijk. Test pas nadat de werkelijk geïnstalleerde build/patch aantoonbaar de F2-wijzigingen bevat. Publicatie vereist een afzonderlijke toestemming.

## Testmatrix native iPhone

| # | Scenario / actie | Acceptatie |
|---|---|---|
| 1 | Start de missie op de native iPhone; ga naar de stad | Geen crash, geen weggevallen touchcontrols, stabiel beeld |
| 2 | Bekijk kerk, hotel, magazijn en benzinestation | Vijandelijke bewoners en rode dakstippen / kaartmarkering verschijnen zoals ontworpen |
| 3 | Selecteer eigen soldaten in BEVEL, kies VERPLAATS of VERDEDIG, tik op een geschikt huis | Soldaten lopen naar de voordeur en nemen beschikbare plaatsen in; overloop verdedigt bij de deur |
| 4 | Selecteer een eigen bezet gebouw zonder actief bevel, tik ERUIT | Eigen soldaten verlaten het gebouw en blijven bestuurbaar |
| 5 | Observeer gevecht bij kerk/hotel, inclusief raam aan doelzijde | Kogels en flits komen uit ramen; er wordt niet door massieve muren geschoten |
| 6 | Vuur met gewoon wapen en vervolgens granaat/raket op bezet gebouw | Kogelschade is gereduceerd; explosies werken volgens ontworpen schadecontract |
| 7 | Schakel alle verdedigers van een gebouw uit | GEBOUW VRIJ + 150 voorraad éénmaal; radar/kaartstatus klopt |
| 8 | Laat een bezet gebouw instorten | Alle bewoners sneuvelen; geen spooksoldaten of resterende kaartmarkeringen |
| 9 | Bedien BEVEL, radar, grote kaart, ERUIT en bestaande schiet-/granaatknoppen op iPhone | Geen overlap, mis-taps, vastlopende sticks of onbedoeld schieten |
| 10 | Herhaal 2–8 tijdens een druk gevecht, met meerdere bezette huizen en bestaande voertuigen | Geen crash, grote frametime-spikes of langdurige FPS-daling; meet FPS en noteer grafiekstand |

## Meetprotocol

- Noteer iPhone-model, grafiekpreset, upscaling, verversingslimiet en exacte build/OTA-versie.
- Maak minimaal één opname van: (a) huis bezetten/ERUIT, (b) raamgevecht/explosies, (c) druk stadsgevecht met FPS-overlay.
- Doel is mooie graphics én rond 60 FPS native, maar claim geen resultaat voordat er echte toestelmetingen zijn.
- Registreer per scenario **PASS / FAIL / NIET GETEST**, zichtbare fout, en zo mogelijk tijdcode/screenshot.
- Geef bij FAIL een reproduceerbaar stappenplan en laat correcties uitsluitend op een nieuwe featurebranch en Draft PR maken. Daarna regressies, iOS-build en nieuwe afzonderlijke goedkeuring.

## Releasepoort

- **Nu geen OTA-publicatie en geen merge.** F2 is reeds gemerged via PR #299; dit document brengt geen gamecode over.
- Voor de latere native test: controleer eerst de precieze build en vraag expliciet akkoord om de patch via OTA te publiceren. Een alleen voorbereid preview-artifact is niet genoeg voor een test in de geïnstalleerde app.
- Pas na gebruikersbevestiging van de toesteltest wordt de F2-status 'af / native geaccepteerd' in het canonieke Generals-plan opgenomen.
- Daarna: nieuwe actualiteitscontrole en volgende keuzekaart (E2 is inmiddels Draft PR #301; geen eerdere ontwerpkeuzes opnieuw laten kiezen).
