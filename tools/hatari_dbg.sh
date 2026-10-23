#!/bin/bash
# hatari_dbg.sh VBL "cmd1;cmd2;..." [hatari args] : at VBL n run debugger commands (output in hatari/dbg.log)
R=$(cd "$(dirname "$0")/.." && pwd); V=$1; CMDS=$2; shift 2
T=$(mktemp -d)
printf 'b VBL = %s :quiet :file %s/hit.ini\n' "$V" "$T" > "$T/start.ini"
echo "$CMDS" | tr ';' '\n' > "$T/hit.ini"; echo "screenshot $T/done.png" >> "$T/hit.ini"
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy hatari --machine ste --memsize 4096 \
  --tos "${ISTE_ROM:-$R/rom/tos162us.img}" --harddrive "$R/hatari/c" --gemdos-drive c --drive-a false --drive-b false \
  --fast-forward on --sound off --statusbar off --confirm-quit false \
  --parse "$T/start.ini" "$@" > "$R/hatari/dbg.log" 2>&1 < <(sleep 900) &
P=$!
for i in $(seq 1 300); do sleep 1; [ -s "$T/done.png" ] && break; done
kill -9 $P 2>/dev/null; wait $P 2>/dev/null; rm -rf "$T"
sed -n '/Reading debugger commands from .*hit.ini/,$p' "$R/hatari/dbg.log" | grep -v '^Changed'
