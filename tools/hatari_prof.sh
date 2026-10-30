#!/bin/bash
# hatari_prof.sh VBL0 VBL1 PRG : CPU profile of a program between two VBLs (symbols loaded,
# build it with SYM=1). Output: hatari/prof.log (per-symbol and per-address costs).
# FRCLK=1: VBL0/VBL1 are TOS's _frclock ($466, what a PROFILE build's own marks can log) instead
# of Hatari's VBL count (the two differ by the boot: Phase 6o found the windows ~300 VBLs apart).
R=$(cd "$(dirname "$0")/.." && pwd); V0=$1; V1=$2; PRG=$3; shift 3
T=$(mktemp -d)
C='VBL'; [ -n "$FRCLK" ] && C='($466).l'
printf 'b %s = %s :trace :once :file %s/a.ini\nb %s = %s :once :file %s/b.ini\n' "$C" "$V0" "$T" "$C" "$V1" "$T" > "$T/start.ini"
printf 'symbols prg\nprofile on\n' > "$T/a.ini"
printf 'profile symbols 30\nprofile callers\nprofile addresses\nscreenshot %s/done.png\n' "$T" > "$T/b.ini"
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy hatari --machine ste --memsize 4096 \
  --tos "${ISTE_ROM:-$R/rom/tos162us.img}" --harddrive "$R/hatari/c" --gemdos-drive c --drive-a false --drive-b false \
  --fast-forward on --sound off --statusbar off --confirm-quit false \
  --parse "$T/start.ini" --auto "$PRG" "$@" > "$R/hatari/prof.log" 2>&1 < <(sleep 900) &
P=$!
for i in $(seq 1 300); do sleep 1; [ -s "$T/done.png" ] && break; done
kill -9 $P 2>/dev/null; wait $P 2>/dev/null; rm -rf "$T"
