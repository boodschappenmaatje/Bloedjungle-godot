# Stadseditor v88: contextbalk alleen bij selectie

De werkbalk met **Draai**, **Spiegel**, **Kopie**, **Wis** en **Kwast** verschijnt alleen wanneer de speler in **BEWERK** een bestaand stadsobject op de kaart heeft geselecteerd. Het kiezen van een categorie of bouwkaart en het plaatsen van een object toont de werkbalk niet.

De werkbalk blijft verborgen in de veilige **KIJK**-stand en verdwijnt zodra de selectie weg is of het object wordt verwijderd. Bestaande plaatsings-, selectie- en objectacties blijven verder gelijk.

## Controle

`tests/stad_editor_2_test.gd` controleert dat de werkbalk verborgen blijft bij bouwkaartselectie en plaatsen, verschijnt bij selectie van een geplaatst object en verdwijnt na wissen.
