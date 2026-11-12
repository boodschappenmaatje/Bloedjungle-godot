extends RefCounted
## Meldplek die nooit antwoordt (poort 9 op dit toestel): voor tests/logboek_test.gd, zodat de wachtrij getest wordt zonder echte melding.

const URL := "http://127.0.0.1:9/rest/v1/meldingen"
const SLEUTEL := "test"
