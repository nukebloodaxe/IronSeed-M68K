#!/bin/bash
# oracle_run.sh SCRIPT_PREFIX OUTDIR : one scripted session of the Linux reference build (the
# atari-ste-oracle branch of ironseed_fpc, built in $IRONSEED_SRC, default /root/ironseed_fpc) with
# the input scripts oracle/scripts/SCRIPT_PREFIX.<program>. OUTDIR gets the state dumps, the
# shot_*.raw screens and home/.ironseed (savegame.dir, saveN/).
set -e
R=$(cd "$(dirname "$0")/.." && pwd); S=${IRONSEED_SRC:-/root/ironseed_fpc}
OUT=$(mkdir -p "$2" && cd "$2" && pwd)
rm -rf "$OUT"/* ; mkdir -p "$OUT/home"
[ -x "$S/is" ] || { echo "no Linux oracle build in $S (see HANDOFF.md)"; exit 1; }
cd "$S"
HOME="$OUT/home" SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy IRONSEED_ORACLE="$OUT" \
  IRONSEED_INPUT="$R/oracle/scripts/$1" timeout 600 ./is > "$OUT/is.log" 2>&1
echo "oracle: $(ls "$OUT"/*.bin 2>/dev/null | wc -l) dumps, $(ls "$OUT"/shot_*.raw 2>/dev/null | wc -l) shots in $OUT"
