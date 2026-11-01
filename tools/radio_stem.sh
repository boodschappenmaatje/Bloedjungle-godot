#!/usr/bin/env bash
# Maakt van de losse stemopnames de radiomeldingen (stem A "veldradio": iets hogere toon, smalle band,
# lichte ruis, kleine vervorming, radioklik ervoor en een korte klik erna). Gebruik:
#   tools/radio_stem.sh <map met bronopnames> <uitvoermap>
# De ruwe opnames staan bewust NIET in de repo (de stem van Dennis); alleen het resultaat.
set -euo pipefail
BRON=${1:?bronmap}; UIT=${2:?uitvoermap}; mkdir -p "$UIT"
maak() { # bronbestand uitvoernaam
  ffmpeg -y -loglevel error -i "$BRON/$1.wav" \
    -f lavfi -i "anoisesrc=color=white:amplitude=0.02:duration=8:seed=7" \
    -f lavfi -i "anoisesrc=color=white:amplitude=0.5:duration=0.05:seed=3" \
    -f lavfi -i "anoisesrc=color=white:amplitude=0.4:duration=0.04:seed=5" \
    -filter_complex "
[0]silenceremove=start_periods=1:start_threshold=-45dB,areverse,silenceremove=start_periods=1:start_threshold=-45dB,areverse,
 aformat=channel_layouts=mono,asetrate=48000*1.07,aresample=48000,atempo=1/1.07,
 highpass=f=450,lowpass=f=2800,acompressor=threshold=-24dB:ratio=8:makeup=6,alimiter=limit=0.8[v];
[1]highpass=f=800,lowpass=f=3500[n];
[v][n]amix=inputs=2:duration=first:weights=1 0.5:normalize=0,acrusher=bits=10:mix=0.3:mode=lin[m];
[2]highpass=f=1200,lowpass=f=3200,afade=t=out:st=0:d=0.05,aformat=sample_rates=48000:channel_layouts=mono[k1];
[3]highpass=f=1200,lowpass=f=3200,afade=t=out:st=0:d=0.04,volume=0.6,aformat=sample_rates=48000:channel_layouts=mono[k2];
[k1][m][k2]concat=n=3:v=0:a=1[a];
[a]loudnorm=I=-16:TP=-1.5:LRA=7,aresample=22050[o]" \
    -map "[o]" -ac 1 -c:a pcm_s16le "$UIT/$2.wav"
}
maak Building_complete bouw_klaar_1
maak Building_ready bouw_klaar_2
maak Building_destroyed gebouw_vernield_1
maak Building_lost gebouw_vernield_2
maak Base_under_attack basis_aanval_1
maak Enemy_attacking_the_base_1 basis_aanval_2
maak Enemy_attacking_the_base_2 basis_aanval_3
maak Unit_ready eenheid_klaar_1
maak Soldier_ready_for_duty eenheid_klaar_2
