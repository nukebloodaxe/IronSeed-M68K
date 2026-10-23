#!/bin/bash
# pack.sh STAGE : tar the tree (minus ROM, build output, emulator outputs) to dist/ironseed-ste-STAGE.tar.gz
set -e
R=$(cd "$(dirname "$0")/.." && pwd); cd "$R/.."
N=$(basename "$R"); mkdir -p "$R/dist"
OUT="$R/dist/ironseed-ste-$1.tar.gz"
tar czf "$OUT" --exclude="$N/rom/*.img" --exclude="$N/build" --exclude="$N/dist/*.tar.gz" --exclude="$N/.git" \
  --exclude="$N/hatari/c/*.BIN" --exclude="$N/hatari/c/DATA" --exclude="$N/hatari/c/SOUND" --exclude="$N/hatari/c/*.SCR" --exclude="$N/hatari/c/*.MOD" --exclude="$N/hatari/c/*.ISP" --exclude="$N/hatari/c/*.SAM" --exclude="$N/dist/IRONSEED" --exclude="$N/dist/*.wav" --exclude="$N/hatari/last.log" "$N"
echo "$OUT ($(du -h "$OUT" | cut -f1))"
