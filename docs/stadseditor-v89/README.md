# Stadseditor v89: gemeten FPS-status

De statusbalk in de stadseditor toont nu de actuele gemeten frames per seconde en vergelijkt die met de ingestelde FPS-doelwaarde. De kleur en tekst geven aan of de meting op doel, eronder of laag is. De balk wordt twee keer per seconde ververst.

De oude waarde `181 / 100 · TE ZWAAR` was een vaste optelsom van handmatig toegekende objectkosten. Die waarde mat geen framesnelheid en beperkte het plaatsen van objecten niet. Hij is daarom uit de zichtbare editorstatus gehaald. De afzonderlijke sloopbare-gebouwenindicator en bestaande automatische kwaliteitsregeling blijven intact.

## Controle

`tests/stad_editor_2_test.gd` voert vaste metingen door de statusweergave om de doel-, onder-doel-, lage-FPS- en meetstatus te controleren.
