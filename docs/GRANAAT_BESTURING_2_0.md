# Bloedjungle — Granaatbesturing 2.0 (optie B)

**Status:** kandidaat, afzonderlijke Draft PR; geen merge of OTA-publicatie.
**Aanleiding:** native iPhone-opname 6 november 2026: op de rechteronderhoek overlappen de uitrustingsknop, het granaatwiel en de rechterrichtstick functioneel. Bij richten kan onbedoeld een keuze uit het wiel volgen.

## Nieuwe mobiele bediening

1. **UITRUSTING** staat als afzonderlijke knop boven/links van de daadwerkelijke wapenbalk, duidelijk buiten de rechterstickcirkel.
2. Een tik op UITRUSTING opent uitsluitend het vierkeuzewiel. Op GRANAAT drukken **selecteert, maar gooit nooit**; het wiel sluit.
3. De eerstvolgende **nieuwe** rechterstickvinger neemt eigenaarschap van één worp. Stick bewegen toont bestaande `GrenadeAim`-boog, landingscirkel, obstakelkleuren, doelmarkers en waarschuwing voor zelfschade.
4. **Rechterstick loslaten buiten de middendodezone:** `Player.throw_grenade_at(target)` éénmaal. Doel en bereik blijven exact de bestaande 2–12 m. De granaatfysica (stuiteren, 1,7 s ontsteker, schade, zelfschade, huizen en botsingen) is ongewijzigd.
5. **Stick terug naar midden en loslaten / zonder echte richtbeweging tikken:** annuleert zonder een granaat te gebruiken. Ook het openen van een nieuw wiel, verlies van focus, beeldrotatie, pauze, overlijden, voertuigbetreding en ongeldige voorraad annuleren de modus.
6. Tijdens richten: de rechterstick kan **geen kogels afvuren** en activeert de M1911-hysterese niet. De bestaande infanterie-kogelrichtindicator verdwijnt ten gunste van de granaatboog. Na worp of annulering is de rechterstick weer normaal richten/schieten.

**Pointerveiligheid:** de vinger die het uitrustingswiel selecteert kan niet dezelfde vinger zijn die de granaat werpt; een nieuwe stick-touch is vereist. Alleen het aan die worp gekoppelde touch-ID kan de worp vrijgeven. Een tweede (linker) vinger en spook-release doen niets. De linkerstick kan blijven lopen tijdens het richten.

**Desktop:** bestaande G-/muissnelkoppelingen en de muisgerichte worp blijven onveranderd. De wijziging is geactiveerd op iPhone/touchplatform.

## Technische begrenzing

- `scripts/combat_buttons.gd`: uitrustingswiel en grenade-stick-state; blijft eigenaar van `GrenadeAim` en gebruikt het bestaande `aim_target()` met `AIM_DEAD/AIM_FULL`-afstandsomzetting. Geen nieuwe granaat- of physicsimplementatie.
- `scripts/touch_sticks.gd`: verkrijgt en onthoudt rechterstick-touch-ID, rapporteert de stickrichting en release naar CombatButtons; zet `Game.fire=false` in de gewapende en wielmodus.
- `scripts/player.gd`: voorkomt dat vuurwapen-aimassist de worprichting buigt en onderdrukt tijdelijk de gewone schietreticle.
- `scripts/grenade.gd`, `scripts/grenade_aim.gd` en de wapenschade blijven **ongewijzigd**.
- Uitrustingsknop volgt de echte positie van de wapenbalk, rekening houdend met schermstand en safe margins. Het mag de rechterstick niet overlappen.

## Acceptatie en regressies

- `tests/granaat_richten_test.gd`: echte touch-events: selectie zonder gooien, 2/5/8/12 m in 8 richtingen, middenannulering, klik zonder beweging, auto-blokkade, gebouwen, verkeerde vinger, twee keer loslaten, veiligheid van rechterstick en fysieke granaatbaan.
- Bestaande `tests/besturing_test.gd`, `tests/combat_infantry_feedback_test.gd`, `tests/m1911_ammo_reload_test.gd`, `tests/grote_kaart_test.gd` en `tests/auto_wapens_test.gd` blijven werken.
- Drie verplichte PR-workflows: Vijandbasis-regressie, iOS unsigned IPA (met granaattest), OTA-patch **preview**.
- Native iPhone-test na een latere expliciet goedgekeurde merge/publicatie: UITRUSTING → GRANAAT → rechterstick richting/afstand → loslaten, terug naar midden, multitouch, pauze/kaart, FPS op Hoog.

**Releasepoort:** geen merge naar `main` en geen nieuwe OTA-release voor deze feature zonder nieuwe expliciete gebruikersopdracht.
