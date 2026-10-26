# iOS-build, AltStore en updates

## Reproduceerbare CI-build

`.github/workflows/ios.yml` gebruikt Godot **4.7.2** (editor en exporttemplates, vastgepind) op `macos-26` met Xcode 26, importeert het project, exporteert de iOS Xcode-projectbestanden en bouwt arm64 met Xcode. De workflow verpakt de app zonder Apple-ondertekening als IPA-artifact. De IPA is bedoeld voor sideloading en AltStore Classic ondertekent hem tijdens installatie. De workflow heeft geen secrets nodig. Hij draait handmatig via Actions en bij wijzigingen aan de game op `main` of deze featurebranch.

Godot meet FPS en frametime, renderstatistieken en door Godot gerapporteerd videogeheugen. CPU- en GPU-tijd zijn geen betrouwbare Godot-monitors; gebruik Instruments (Time Profiler, Metal System Trace en Allocations) op een echte iPhone voor die metingen. iOS kan ProMotion beperken door Low Power Mode, thermische toestand en systeembeleid. Een keuze van 90/120 garandeert die framerate niet.

## Installatie met Windows en iPhone

1. Download de `bloedjungle-ios-unsigned-...` artifact bij een geslaagde GitHub Actions-run en pak het ZIP-downloadbestand uit tot `Bloedjungle.ipa`.
2. Installeer AltServer op Windows vanaf de officiële AltStore-site. Installeer iTunes en iCloud voor Windows rechtstreeks van Apple wanneer AltServer daarom vraagt; meld je daarin aan.
3. Verbind de iPhone via USB, vertrouw de computer, open AltServer en kies **Install AltStore** voor de iPhone. Vul Apple ID-gegevens alleen in AltServer zelf in.
4. Vertrouw op de iPhone het ontwikkelaarsprofiel via **Instellingen → Algemeen → VPN- en apparaatbeheer**. Zet **Ontwikkelaarsmodus** aan indien iOS daarom vraagt.
5. Open AltStore, ga naar **My Apps → +**, kies de IPA en laat AltStore hem ondertekenen/installeren. Vernieuw de app via AltServer op hetzelfde netwerk of via USB voordat de gratis ondertekening verloopt.

De repository moet voor GitHub Actions toegankelijk zijn voor de persoon die de artifact downloadt. Er is geen ingebouwde GitHub-token of private repository download in de app.

## Updates zonder nieuwe IPA (OTA)

De app kan resources en GDScript-wijzigingen (wapens, modellen, texturen, balans, menu's) via een **patch-PCK** binnenhalen uit de GitHub-release `updates` van deze repository. Bij het starten van het hoofdmenu verschijnt het updatescherm als er een nieuwere patch is; er wordt **niets gedownload of gewijzigd zonder dat jij op "Download en installeer" tikt**. Daarna de app helemaal afsluiten en opnieuw openen.

**Eenmalig instellen (token):** de repository is privé, dus de app heeft een alleen-lezen token nodig.
1. GitHub → Settings → Developer settings → Fine-grained tokens → Generate new token.
2. Repository access: *Only select repositories* → alleen `Bloedjungle-godot`. Permissions: *Contents: Read-only* (verder niets). Kies een verloopdatum.
3. In de app: Hoofdmenu of Pauze → **Updates** → token plakken → Opslaan. Het token blijft alleen op het toestel (`user://ota/token.cfg`) en zit niet in de IPA of de broncode.

**Hoe het werkt**
- `ota.yml` bouwt bij elke push naar `main` of `feature/native-ios-complete` een basis-PCK (de commit uit `ota/basis.txt`) en een patch-PCK (alleen het verschil met de huidige commit) en zet `manifest.json` + `patch-<versie>.pck` in de release `updates`.
- De app controleert grootte en SHA-256, en dat de patch bij de geïnstalleerde IPA hoort (`base`). Een patch voor een andere IPA wordt geweigerd.
- Crashbeveiliging: als de app twee keer na het laden van een patch niet stabiel is geworden (20 s), wordt de patch automatisch uitgeschakeld. Handmatig kan met "Terugdraaien naar de app-versie".

**Beperkingen**
- Engine-, iOS-native code, app-icoon en Info.plist vragen nog steeds een nieuwe IPA.
- Na een nieuwe IPA: zet `ota/basis.txt` op de commit van die IPA, anders groeit de patch mee.
- AltStore-ondertekening verloopt nog steeds na 7 dagen; vernieuwen blijft nodig.

## Updatefundament (oud, vervangen door OTA hierboven)

Deel het token nooit via de broncode of IPA.

## Validatie en beperkingen

De CI controleert import, headless startup, aanwezigheid van het Xcode-project, Xcode-build en IPA-inhoud. Lokale regressietests staan in `tests/`. Een macOS runner is vereist voor iOS-export/Xcode; Linux kan geen equivalent leveren. De workflow is op GitHub geslaagd (run #12 en latere runs op deze branch) en levert de IPA als artifact `bloedjungle-ios-unsigned-<commit>` (ongeveer 110 MB, bewaard 30 dagen).

### Wat aan de IPA is gecontroleerd (uit het artifact van run #12)
- Geldig ZIP/IPA-bestand met `Payload/Bloedjungle-ios.app`; **niet ondertekend** (geen `_CodeSignature` of `embedded.mobileprovision`), zoals AltStore wil.
- `CFBundleIdentifier` `nl.boodschappenmaatje.bloedjungle`, weergavenaam Bloedjungle, versie 1.0 (1), minimaal iOS 15.0, arm64, gebouwd met de iPhoneOS 26.5 SDK (Xcode 26.6).
- Alleen liggend (landscape) en `CADisableMinimumFrameDurationOnPhone` staat aan, zodat iOS meer dan 60 Hz mag tonen.
- Het app-icoon zit erin. Het uitvoerbestand is 86 MB; `Bloedjungle-ios.pck` is 137 MB en bevat de volledige game (scènes, scripts, modellen, shaders, effecten).

### Wat nog niet is gecontroleerd
- Installatie via AltStore, opstarten, touchbediening en echte FPS op een iPhone (dit moet op het toestel).
- Of iOS 90 of 120 Hz echt toestaat: dat hangt af van Low Power Mode, temperatuur en het toestel. Het spel zet zelf geen grens (`Engine.max_fps = 0`).
- Het automatisch laden van PCK-updates is niet gebouwd (zie Updatefundament).
