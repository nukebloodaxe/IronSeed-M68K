#!/bin/bash
# run_hatari.sh VBLS OUT.png [hatari args...]
# Boots a 4 MB STE headless (TOS from $ISTE_ROM, default rom/tos162us.img), C: = hatari/c,
# takes a screenshot at VBL n and kills the emulator. Typical extra args:
#   --auto 'C:\PROG.PRG'      start a program after boot
# Floppies are disabled so TOS boots straight to C:.
R=$(cd "$(dirname "$0")/.." && pwd)
V=$1; OUT=$(readlink -f "$2"); shift 2
ROM=${ISTE_ROM:-$R/rom/tos162us.img}
T=$(mktemp -d)
printf 'b VBL = %s :quiet :file %s/hit.ini\n' "$V" "$T" > "$T/start.ini"
printf 'screenshot %s\n' "$OUT" > "$T/hit.ini"
rm -f "$OUT"
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy hatari --machine ste --memsize 4096 \
  --tos "$ROM" --harddrive "$R/hatari/c" --gemdos-drive c --drive-a false --drive-b false \
  --fast-forward on --sound off --statusbar off --confirm-quit false \
  --parse "$T/start.ini" "$@" > "$R/hatari/last.log" 2>&1 < <(sleep 900) &
P=$!
for i in $(seq 1 300); do sleep 1; [ -s "$OUT" ] && { sleep 1; break; }; done
kill -9 $P 2>/dev/null; wait $P 2>/dev/null; rm -rf "$T"
if [ -s "$OUT" ]; then echo "screenshot $OUT (${i}s)"; else echo "FAILED"; tail -5 "$R/hatari/last.log"; exit 1; fi
