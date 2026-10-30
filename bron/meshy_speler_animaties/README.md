# Meshy-speler: extra animaties via de Meshy-API

Aanvulling op `docs/meshy_player_animation_library_3.7.md` (de 13 app-clips). Deze 62 clips zijn **via de Meshy-API** besteld op dezelfde speler (30-10-2026):

1. `POST /openapi/v1/rigging` met `assets/meshy_jungle_commando.glb` (5 credits) → rig-taak `01a18b88-1709-77cf-bce7-e580117991cb`. De API-rig heeft **24 botten**, andere namen (`Spine01`, `neck`, `head_end`, zonder `mixamorig:`) en centimeter-eenheden, dus niet rechtstreeks inwisselbaar met het 28-bot Mixamo-skelet van het spel.
2. `POST /openapi/v1/animations` met 7 groepen van 9 `action_ids` (3 credits per actie, 189 credits). Taak-ids en actie-ids: `bronnen/meshy_taken.json`. De ruwe GLB's staan in `bronnen/` (Godot negeert `bron/`).
3. `retarget_api_clips.gd` zet elke clip over op het bestaande spelerskelet met een globale rustpose-delta (zie de kop van het script) en schrijft `resources/animations/meshy_player_animation_library_api.res`. Horizontale heupverplaatsing is weggehaald (zoals bij de 13 app-clips); verticale blijft (opstaan, vallen, klimmen).

## Clips per groep (loops gemarkeerd met ↻)

- **Gevecht/bewegen met geweer:** Combat_Stance ↻ (idle), Walk_Forward_While_Shooting ↻, Walk_Backward_While_Shooting ↻, Walk_Backward_with_Gun ↻, Walk_Left_with_Gun ↻, Side_Shot, Rifle_Turn_Left, Combat_Idle_Turn_Left, Gun_Hold_Left_Turn
- **Herladen/geraakt:** Standing_Reload, Kneeling_Reload, Running_Reload ↻, Slow_Walk_Reload ↻, Gunshot_Reaction, Hit_Reaction, Hit_Reaction_to_Waist, Electrocution_Reaction, Slap_Reaction
- **Dood:** Shot_and_Fall_Backward, Shot_and_Fall_Forward, Shot_and_Slow_Fall_Backward, Shot_in_the_Back_and_Fall, Shot_and_Blown_Back (explosie), Fall_Dead_from_Abdominal_Injury, Knock_Down, Knock_Down_1, Strangled_and_Fall_Forward
- **Rollen/gooien:** Roll_Dodge, Forward_Roll_and_Fire, Roll_Behind_Cover, Run_Jump_and_Roll, Over_Shoulder_Throw, Crouch_Pull_and_Throw, Crouch_Charge_and_Throw, Walk_Backward_with_Grenade ↻, Stumble_Walk ↻
- **Klimmen/zitten:** Fast_Ladder_Climb ↻, Ladder_Climb_Loop ↻, Slow_Ladder_Climb ↻, climbing_up_wall ↻, Chair_Sit_Idle_F ↻, Chair_Sit_Idle_M ↻, Stand_to_Sit_Transition_M, Sit_to_Stand_Transition_M, Sit_to_Stand_Transition_F
- **Houdingen:** Kneel_on_One_Knee_and_Stand, Stand_To_Side_Lying, Crawl_and_Look_Back ↻, Crawl_Backward ↻, Prone_Reach_Help, Crouch_and_Push_Forward, Cautious_Crouch_Walk_Backward ↻, Cautious_Crouch_Walk_Left ↻, Crouch_and_Step_Back
- **Mes/val:** Attack, Weapon_Combo, Weapon_Combo_1, Elbow_Strike, Kung_Fu_Punch, sliding_stumble, falling_down, Fall1, (Combat_Stance staat al bij gevecht)

## Status

- Visueel gecontroleerd op de speler in Godot 4.7.2 (4 momenten per clip). Geen vervormde mesh, kruipen/vallen ligt plat, hurken zakt door de heupen.
- **Gekoppeld aan het spel** in `scripts/soldier_model.gd` (alleen de Meshy-speler, instelling `soldaat = meshy`): `MESHY_ALIASES` zet de namen die het spel al aanroept op API-clips: `achteruit`→Walk_Backward_with_Gun, `geraakt`→Hit_Reaction, `dood1`→Shot_and_Fall_Backward, `dood2`→Shot_and_Fall_Forward, `explosie_dood`→Shot_and_Blown_Back, `rollen`→Roll_Dodge, `klimmen`→Fast_Ladder_Climb, `zitten`→Chair_Sit_Idle_M, `steken`→Attack, `brand_val`→falling_down, `brand_rennen`→Stumble_Walk.
- Spelacties spelen nu rechtstreeks op de AnimationPlayer in plaats van via de AnimationTree. De tree negeerde `speed_scale`, waardoor loop-tempo, koprol-duur en achteruitlopen niet klopten. De tree blijft alleen voor de clip-review (`play_meshy_library_clip`). Achteruitlopen (negatief tempo op `lopen`) speelt nu `achteruit`.
- Buiten de geweerhoudingen (`MESHY_HOLD`: stil, lopen, rennen, sprinten, achteruit, schieten) gaat de arm-IK uit en verdwijnt het wapen, anders blijft het geweer los van het lichaam hangen tijdens rollen, vallen, klimmen en zitten. Een wapen op de rug of in de hand is een vervolgstap.
- Getest: `tests/meshy_player_integration_test.tscn` PASS (aliassen, tempo, achteruit, wapen aan/uit, plus alle eerdere handgreep-tests). Opnames in het spel: `tests/meshy_player_actions_foto.tscn`.
- Niet gedaan: handgreep-IK met de Garand op `achteruit` (IK trekt de handen er wel naar toe, de afstand is niet gemeten), `herladen`/`schieten` blijven de zelfgemaakte Godot-clips, iPhone-prestaties, `.res` is ~4 MB (30 fps; kan naar 15 fps).
