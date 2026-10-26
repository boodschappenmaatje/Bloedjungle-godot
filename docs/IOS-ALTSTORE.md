# iOS-build, AltStore en updates

## Reproduceerbare CI-build

`.github/workflows/ios.yml` gebruikt Godot 4.7.0 exporttemplates op `macos-14`, importeert het project, exporteert de iOS Xcode-projectbestanden en bouwt arm64 met Xcode. De workflow verpakt de app zonder Apple-ondertekening als IPA-artifact. De IPA is bedoeld voor sideloading en AltStore Classic ondertekent hem tijdens installatie. De workflow heeft geen secrets nodig. Hij draait handmatig via Actions en bij wijzigingen aan de game op `main` of deze featurebranch.

Godot meet FPS en frametime, renderstatistieken en door Godot gerapporteerd videogeheugen. CPU- en GPU-tijd zijn geen betrouwbare Godot-monitors; gebruik Instruments (Time Profiler, Metal System Trace en Allocations) op een echte iPhone voor die metingen. iOS kan ProMotion beperken door Low Power Mode, thermische toestand en systeembeleid. Een keuze van 90/120 garandeert die framerate niet.

## Installatie met Windows en iPhone

1. Download de `bloedjungle-ios-unsigned-...` artifact bij een geslaagde GitHub Actions-run en pak het ZIP-downloadbestand uit tot `Bloedjungle.ipa`.
2. Installeer AltServer op Windows vanaf de officiële AltStore-site. Installeer iTunes en iCloud voor Windows rechtstreeks van Apple wanneer AltServer daarom vraagt; meld je daarin aan.
3. Verbind de iPhone via USB, vertrouw de computer, open AltServer en kies **Install AltStore** voor de iPhone. Vul Apple ID-gegevens alleen in AltServer zelf in.
4. Vertrouw op de iPhone het ontwikkelaarsprofiel via **Instellingen → Algemeen → VPN- en apparaatbeheer**. Zet **Ontwikkelaarsmodus** aan indien iOS daarom vraagt.
5. Open AltStore, ga naar **My Apps → +**, kies de IPA en laat AltStore hem ondertekenen/installeren. Vernieuw de app via AltServer op hetzelfde netwerk of via USB voordat de gratis ondertekening verloopt.

De repository moet voor GitHub Actions toegankelijk zijn voor de persoon die de artifact downloadt. Er is geen ingebouwde GitHub-token of private repository download in de app.

## Updatefundament

Code- en enginewijzigingen vereisen een volledige IPA-installatie. Externe PCK's zijn nog niet automatisch geactiveerd: resources kunnen verwijzingen of scripts bevatten en Godot kan bij runtime niet veilig aantonen dat een willekeurige PCK compatibel is. Laat automatische PCK-download en -activering uit totdat een distributieserver publiek of geauthenticeerd via een passend gebruikersaccount beschikbaar is en integratie-/rollbacktests slagen. Deel geen repositorytoken in de app.

Voor toekomstige resource-only patches is het beoogde manifest versie, minimale gameversie, platform, SHA-256, bestandsgrootte en HTTPS-download-URL. Download naar een tijdelijke map onder `user://`, valideer schema, compatibiliteit, grootte en hash, laad resources pas na volledige verificatie, behoud de laatst bekende werkende versie en herstel die bij laadfout. Externe GDScript/code is uitgesloten. Tot die implementatie getest is, controleert de app geen externe updatebron.

## Validatie en beperkingen

De CI controleert import, headless startup, aanwezigheid van het Xcode-project, Xcode-build en IPA-inhoud. Lokale regressietests staan in `tests/`. Een macOS runner is vereist voor iOS-export/Xcode; Linux kan geen equivalent leveren. De echte IPA-artifact ontstaat pas wanneer de workflow op GitHub uitgevoerd is. Installatie, touchscreen en FPS moeten daarna nog op een echte iPhone worden gecontroleerd.
