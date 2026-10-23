#!/bin/bash
# hatari_trap.sh SYMBOL [N] [hatari args] : run until the program reaches SYMBOL (build with
# SYM=1), print the last N (default 60) executed instructions (hatari/trap.log). Symbols are
# loaded at VBL 2600 (the program has started by then).
R=$(cd "$(dirname "$0")/.." && pwd); SYM=$1; N=${2:-60}; shift 2
T=$(mktemp -d)
printf 'b VBL = 2600 :quiet :file %s/start2.ini\n' "$T" > "$T/start.ini"
printf 'symbols prg\nhistory on\nb pc = %s :file %s/hit.ini\n' "$SYM" "$T" > "$T/start2.ini"
printf 'history %s\nr\nscreenshot %s/done.png\n' "$N" "$T" > "$T/hit.ini"
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy hatari --machine ste --memsize 4096 \
  --tos "${ISTE_ROM:-$R/rom/tos162us.img}" --harddrive "$R/hatari/c" --gemdos-drive c --drive-a false --drive-b false \
  --fast-forward on --sound off --statusbar off --confirm-quit false \
  --parse "$T/start.ini" "$@" > "$R/hatari/trap.log" 2>&1 < <(sleep 1800) &
P=$!
for i in $(seq 1 900); do sleep 1; [ -s "$T/done.png" ] && break; done
kill -9 $P 2>/dev/null; wait $P 2>/dev/null; rm -rf "$T"
sed -n '/Reading debugger commands from .*hit.ini/,$p' "$R/hatari/trap.log" | grep -v '^Changed' | tail -$((N+30))
