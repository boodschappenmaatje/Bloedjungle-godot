extends RefCounted
## Waar de knop "Meld probleem" zijn pakketje naartoe stuurt: het gratis Supabase-project "bloedjungle-meldingen".
## De sleutel hieronder is de PUBLIEKE (publishable) sleutel. Die mag in deze publieke repo staan: de database laat
## hem alleen een nieuwe melding toevoegen (tabel meldingen, RLS-regel "game mag melding toevoegen"). Lezen, wijzigen
## en wissen kan er niet mee; dat doet Claude met de beheertoegang tot het project. Zie docs/MELDINGEN.md.

const URL := "https://vipttighnsuxjwfkeokf.supabase.co/rest/v1/meldingen"
const SLEUTEL := "sb_publishable_RSUvTIrQshRSYZG1XVN1RA_xWdkk9BR"
