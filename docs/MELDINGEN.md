# Foutenlogboek op afstand ("Meld probleem")

Sinds v221 schrijft de game een klein logboek mee (`scripts/logboek.gd`, hangt onder de autoload `Game`):

- **Fouten en waarschuwingen** van Godot en de scripts (eigen `Logger`, ontdubbeld met een teller, max. 80 soorten).
- **Metingen** om de 2 s, laatste 5 minuten: fps (gemiddeld en slechtste beeld), spelstand, groep, positie, HP, soldaten, vijanden, voertuig, groepsbevel.
- **Acties**: bevelen (troepselectie en bevelwiel), banners in beeld, start/einde, wissels van spelstand en bevel.
- **Context**: versie, toestelmodel (bijv. `iPhone15,2`), Godot-versie, GPU, schermmaat, enkele grafische instellingen, OTA-ketenstatus.

Geen naam, account, score-namen of andere persoonlijke gegevens.

## Wanneer gaat er iets weg?

Alleen als je op **MELDEN** (hoofdmenu) of **Meld probleem** (pauze) en dan op **VERSTUUR** tikt. Je kunt er een korte zin bij typen.
Liep het spel de vorige keer vast (niet netjes naar de achtergrond/afgesloten) of waren er fouten, dan biedt het hoofdmenu één keer aan om die vorige sessie te melden; TERUG wijst het af.
Lukt versturen niet (geen netwerk, project gepauzeerd) dan blijft het pakketje in `user://logboek/wachtrij/` (max. 5) en gaat het bij de volgende start alsnog.

## Waar komt het terecht?

Gratis Supabase-project **bloedjungle-meldingen** (`vipttighnsuxjwfkeokf`, eu-west-1), tabel `public.meldingen`
(`id, gemaakt, versie, oorzaak, tekst, platform, inhoud jsonb, gelezen`).

De game gebruikt de **publieke** (publishable) sleutel uit `scripts/meldingen_config.gd`. Die mag in deze publieke repo staan:
RLS en rechten laten `anon` alleen een melding **toevoegen** (met groottegrenzen); lezen, wijzigen en wissen kan er niet mee.

Let op: een gratis Supabase-project pauzeert na ongeveer een week zonder verkeer. Dan blijven meldingen in de wachtrij op de iPhone tot het project weer aan staat (Supabase-dashboard of Claude: `restore_project`).

## Meldingen lezen (Claude)

Via de Supabase-connector (`execute_sql`, project `vipttighnsuxjwfkeokf`):

```sql
select id, gemaakt, versie, oorzaak, tekst, platform,
       jsonb_array_length(inhoud->'fouten') as fouten
from meldingen where not gelezen order by gemaakt desc;

select inhoud->'fouten', inhoud->'acties', inhoud->'metingen' from meldingen where id = 1;

update meldingen set gelezen = true where id = 1;
```

Test: `godot --headless --path . --script tests/logboek_test.gd` (met `BLOEDJUNGLE_MELD_ECHT=1` gaat er ook één echte melding met oorzaak `test` heen).
