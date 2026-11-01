# GENERALS_PLAN.md — Bloedjungle wordt een C&C Generals-achtige RTS met een speelbare soldaat

**Canoniek ontwerpdocument voor Claude Code (`CLAUDE.md`) en ChatGPT Codex (`AGENTS.md`).** Beide lezen dit bestand en volgen dezelfde keuzes. Wijzig het plan hier, niet in een van de twee korte bestanden. Vastgesteld door Dennis op 2026-11-01 via de keuzepagina; de ruwe keuzes staan onderaan.

## Doel
Bloedjungle krijgt het ritme en de systemen van *Command & Conquer: Generals* (2003): voorraad ophalen, basis opbouwen in een techboom, eenheden produceren met tegen-eenheden (counters), een vijandelijke basis slopen, en generaalskrachten. **De eigen twist:** de speler is zelf een soldaat in het leger en loopt, schiet en bestuurt voertuigen terwijl hij ook de basis en het team commandeert. Visuele stijl blijft onze realistische militaire jungle (zie `referentie-stijl.png`), geen kopie van de Generals-look. Kopieer geen assets, namen, stemmen of teksten van het originele spel.

## Beslissingen van Dennis
1. **De huidige golven (waves) gaan eruit.** Ze passen niet meer bij de game. De tegenstander wordt een **vijandelijke basis in de stad** die je moet slopen (D2). Bestaande golfcode, golf-HUD en de gebieden/kaart-PR #69 worden dan herbruikt of verwijderd: overleg bij die stap eerst wat blijft (bijvoorbeeld routes, bezette gebieden, kaart).
2. **Volgorde: de Generals-kern eerst** (fase 1 hieronder).
3. Realistische stijl, weinig op het scherm, native iPhone-app is de acceptatietest (zie `CLAUDE.md`/`AGENTS.md`).

## Wat wel gekozen is (prioriteit P1 eerst; S klein, M middel, L groot)
| Id | Onderdeel | P | Werk |
|---|---|---|---|
| A1 | Voorraaddepot + voorraadtruck: voorraadstapels op de kaart raken op, een truck rijdt heen en weer (nieuw model) | P1 | L |
| A2 | Zelf voorraad halen: speler kan de truck besturen of kisten oppakken voor bonus | P2 | S |
| A3 | Olieboortoren veroveren voor geld per minuut (nieuw model) | P2 | M |
| A4 | Stroom die echt telt: generator wordt centrale; te weinig stroom remt torens, radar en productie | P2 | M |
| A5 | Geldkisten uit wrakken | P3 | S |
| B1 | Bouwtijd met steigers en voortgangsbalk (verkopen/repareren blijven) | P1 | M |
| B3 | Hoofdkwartier (Command Center) als hart van de basis, vervangt de bunker als doel (nieuw model) | P1 | M |
| B4 | Techboom: gebouwen ontgrendelen elkaar | P1 | S |
| B5 | De vier "binnenkort"-gebouwen: Ziekenboeg, Munitiedepot, Werkplaats, Radiopost (nieuwe modellen) | P2 | L |
| B6 | Echte verdedigingsbouw: luchtafweer, raketbunker, betonbunker waar soldaten in kunnen | P2 | L |
| C1 | Bouwrij met meerdere eenheden + verzamelpunt | P1 | M |
| C2 | Soorten soldaten: geweerschutter, raketsoldaat, sluipschutter, hospik, ingenieur | P1 | L |
| C3 | Steen-papier-schaar: pantsertypes, raketten tegen tanks, luchtafweer tegen lucht | P1 | M |
| C4 | Veteraanrangen met strepen | P2 | S |
| C5 | Upgrades per gebouw | P2 | M |
| C6 | Artillerie of luchtafweervoertuig (nieuw model) | P3 | L |
| D2 | **Vijandelijke basis in de stad slopen om te winnen** | P1 | L |
| D3 | Vijand die zelf voorraad haalt en bouwt | P3 | L |
| D4 | Facties met eigen kleur (wij olijfgroen, vijand rood/zand) | P2 | M |
| E1 | Generaalsrang met sterren; elke rang laat een kracht kiezen; killstreaks blijven als snelle beloning | P1 | M |
| E2 | Meer krachten: artillerie, parachutisten, spionagesatelliet, noodreparatie, P-47-aanval | P2 | M |
| F2 | Garnizoen: soldaten in stadsgebouwen schieten uit de ramen | P1 | L |
| F4 | Radar alleen met radiopost | P3 | S |
| G1 | Radiomeldingen (korte Nederlandse stem/tekst: "Eenheid gereed", "Basis onder vuur") | P1 | S |
| G2 | Commandobalk in de tactische stand (uitzoomen = Generals-overzicht) | P2 | M |
| G3 | Kader slepen om te selecteren, groepen onthouden | P2 | M |
| G4 | Teamkleur-accenten | P2 | S |
| G5 | Stemmetjes bij bevelen | P3 | M |
| H1 | Na sneuvelen terugkomen bij het hoofdkwartier (twist) | P1 | S |
| H2 | Leiderschap: soldaten bij de speler schieten beter (twist) | P2 | S |
| H3 | Vertraging bij het geven van bevelen in tactische stand (twist) | P2 | S |

## Niet gekozen (niet bouwen zonder nieuwe vraag)
- B2 "Jij bent de bouwer" (gebouw groeit alleen als de speler erbij staat) en een bulldozer: **niet gekozen.** Bouwen gaat via de bestaande bouwmodus met bouwtijd (B1). Vraag Dennis nog wie de bouwer is voordat je dit uitwerkt.
- D1 Vijandelijke voertuigen als golf-uitbreiding: niet gekozen. Counters (C3) en de vijandelijke basis (D2) hebben wel vijandelijke voertuigen nodig; stem dit af bij de start van fase 2.
- E3 Superwapen, F1 Fog of war, F3 Techgebouwen veroveren (olie A3 wel), H4 Vijandelijke generaal.
- A2-twist en andere ideeën zonder vinkje staan niet op de planning.

## Fasering (Generals-kern eerst)
**Fase 1 — kern:** B3 hoofdkwartier, B1 bouwtijd met steigers, B4 techboom, A1 voorraaddepot + truck, C1 bouwrij + verzamelpunt, G1 radiomeldingen, H1 terugkomen bij het hoofdkwartier.
**Fase 2 — leger en vijand:** C2 soldatensoorten, C3 counters, D2 vijandelijke basis (golven eruit), F2 garnizoen, E1 generaalsrang, D4 facties.
**Fase 3 — verdieping (P2):** A2, A3, A4, B5, B6, C4, C5, E2, G2, G3, G4, H2, H3.
**Fase 4 — later (P3):** A5, C6, D3, F4, G5.

## Hoe we werken (voor Claude én Codex)
- **Eén stap per keer.** Dennis test elke stap voordat de volgende begint. Begin geen volgende fase zonder zijn "ga door".
- **Per stap:** korte voorstelbeschrijving, eigen featurebranch, **Draft PR**, tests (`tests/`) en voor/na-opnames. **Niet naar `main` mergen en niet naar de gedeelde OTA publiceren** zonder afzonderlijke uitdrukkelijke goedkeuring (zie `CLAUDE.md`/`AGENTS.md`).
- **Nieuwe 3D-modellen** (hoofdkwartier, voorraadtruck, olietoren, gebouwen, soldatensoorten): volg `docs/ASSET_QUALITY_STANDARD.md` en eerst ontwerpoverleg; viewer in `tools/blender-vq2-viewer/`.
- **Behoud** bestaande gameplay: bouwmodus (`scripts/buildings.gd`, `build_mode.gd`), teamwiel (`team_commands.gd`), killstreaks (`streak.gd`), tactische camera, bestuurbare voertuigen en vliegtuig, sloopsysteem. Meubels hebben collision (vaste regel).
- **Prestaties:** native iPhone-app draait nu ~110 fps; meld "NIET GETEST" als geen native meting beschikbaar is.
- Taal van de gebruiker: Nederlands.

## Hoe Generals het doet (korte referentie)
Voorraad = geld (trucks tussen stapel en depot, stapels raken op); stroom door centrales; bouwer bouwt in een techboom; productie in wachtrij met verzamelpunt; steen-papier-schaar tussen eenheden; veteraanrangen; generaalsrang met krachten en afkoeltijd; garnizoen in gebouwen; teamkleuren en commandobalk onderaan; radiomeldingen.

## Huidige stand van het spel (v162, 2026-11-01)
Wel: punten per kill + start-bouwkrediet; bouwmodus (kazerne, garage, helipad, vliegveld, zandzakken, muur; verkopen/repareren); kazerne traint rekruten (3 niveaus); garage jeep/tank/truck; helipad Apache; vliegveld P-47; generator met `Game.power`; teamwiel (aanvallen/verplaatsen/verdedigen/volgen); killstreaks Versterking en Napalm; tactische camera; wachten en patrouilles; sloopsysteem; golven met 7 vaste routes (gaan eruit). Niet: voorraad-economie, bouwtijd, techboom, hoofdkwartier, vijandelijke voertuigen of basis, veteranen, krachten per rang, fog of war.
Het vliegveld op basismaat wordt in een aparte thread afgehandeld (`docs`/PR daarvan).

## Ruwe keuzes van Dennis (2026-11-01)
Opmerking bij Tegenstander: "De golven (waves) zoals we nu hebben moet eruit dit past niet bij onze game meer."
Aangevinkt: A1-A5, B1 B3 B4 B5 B6, C1-C6, D2 D3 D4, E1 E2, F2 F4, G1-G5, H1 H2 H3, volgorde "Generals-kern eerst".
Keuzepagina: https://claude.ai/artifact/VNoxTR8VvsKn44oDdD3Jq1
