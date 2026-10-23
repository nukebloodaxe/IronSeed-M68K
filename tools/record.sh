#!/bin/bash
# record.sh VBLS OUT.mp4 [FROM_S TO_S] [hatari args...] : run Hatari headless with sound and
# record every frame (no fast-forward frame skipping) until VBL n, then make an MP4 (the
# 320x200 picture cropped from the border, AAC sound), optionally cut to FROM..TO seconds.
#   tools/record.sh 4900 dist/scene.mp4 52 71 --auto 'C:\IS.PRG'
R=$(cd "$(dirname "$0")/.." && pwd)
V=$1; OUT=$(readlink -f "$2"); shift 2
CUT=""
if [[ "$1" =~ ^[0-9.]+$ && "$2" =~ ^[0-9.]+$ ]]; then CUT="-ss $1 -to $2"; shift 2; fi
T=$(mktemp -d)
printf 'b VBL = %s :quiet :file %s/hit.ini\n' "$V" "$T" > "$T/start.ini"
printf 'screenshot %s/done.png\n' "$T" > "$T/hit.ini"
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy hatari --machine ste --memsize 4096 \
  --tos "${ISTE_ROM:-$R/rom/tos162us.img}" --harddrive "$R/hatari/c" --gemdos-drive c --drive-a false --drive-b false \
  --fast-forward on --frameskips 0 --sound 25033 --statusbar off --confirm-quit false --crop true \
  --avirecord --avi-vcodec png --png-level 1 --avi-file "$T/rec.avi" \
  --parse "$T/start.ini" "$@" > "$T/log.txt" 2>&1 < <(sleep 1800) &
P=$!
for i in $(seq 1 1200); do sleep 1; [ -s "$T/done.png" ] && { sleep 2; break; }; done
kill -INT $P 2>/dev/null; sleep 3; kill -9 $P 2>/dev/null; wait $P 2>/dev/null
ffmpeg -v error -y $CUT -i "$T/rec.avi" -vf "crop=640:400:96:${CROPY:-64},format=yuv420p" -c:v libx264 -crf 18 -c:a aac -b:a 128k "$OUT"
rm -rf "$T"
[ -s "$OUT" ] && echo "recorded $OUT ($(du -h "$OUT" | cut -f1))" || { echo FAILED; exit 1; }
