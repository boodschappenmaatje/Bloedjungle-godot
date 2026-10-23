# Stadseditor v87: veilige KIJK-stand

De stadseditor opent voortaan in **KIJK**. Je kunt de kaart met één vinger slepen en met twee vingers bewegen en zoomen. Kaartaanrakingen kunnen in deze stand geen object plaatsen, selecteren, verplaatsen of wissen. Ook gum, kwast, sneltoetsen, contextacties en ongedaan maken zijn vergrendeld.

Tik op **BEWERK** boven de categorieën om wijzigingen toe te staan. Tik op **KIJK** om terug te gaan; lopende acties worden afgebroken en een gekozen object of wisactie blijft niet klaarstaan.

De linkerknoppen gebruiken horizontale iconen en labels om binnen de iPhone-safe-area te passen in liggende weergaven. De editor leest de actuele veilige schermruimte van het apparaat; de lay-out gebruikt geen vaste uitsparingmaat.

## Controles

- `tests/stad_editor_2_test.gd`: standaardvergrendeling, veilig kaartpannen, gum blokkeren, bewuste overgang naar bewerken, bediening, paneelstanden, safe areas en overlap op 934×430, 844×390 en 736×414.
- `tests/stad_editor_view_test.gd`: bestaande camera-, objectselectie-, touch- en compacte schermcontroles.

Uitgevoerd op Godot 4.7.2: editorintegratie 3372 controles in SCHUIN en BOVEN (0 fouten); cameracontroles 170 (0 fouten); bestaande stadseditor-, wegenlijn-, stad-, menu- en HUD-layouttests geslaagd. Dit controleert de safe-area-indeling met gesimuleerde schermranden; een fysieke iPhone 18 Pro Max/Xogot-praktijktest is niet uitgevoerd.

Godot 4.7 headless-opdrachten:

```sh
godot --headless --path . --editor --quit
godot --headless --path . --audio-driver Dummy -s tests/stad_editor_2_test.gd --fixed-fps 60
godot --headless --path . --audio-driver Dummy -s tests/stad_editor_view_test.gd --fixed-fps 60
```
