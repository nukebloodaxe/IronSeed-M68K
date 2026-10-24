#!/bin/bash
# reglint.sh [--abi] : tools/reglint.py over the vasm listings of all four programs (build/ must be
# generated: tools/gen_layout.sh / mkgame.sh). Prints the reports; exit 1 if there are any.
R=$(cd "$(dirname "$0")/.." && pwd); T=$(mktemp -d); N=0
for P in is intro crewgen main; do
  "$R/tools/st_listing.sh" "$R/game/$P.s" "$T/$P.lst" > /dev/null
  OUT=$(python3 -I "$R/tools/reglint.py" "$T/$P.lst" "$@" --src "$R/game" "$R/kernel" 2>/dev/null)
  [ -n "$OUT" ] && { echo "== ${P^^}.PRG"; echo "$OUT"; N=$((N + $(echo "$OUT" | wc -l))); }
done
rm -rf "$T"; echo "reglint: $N reports"; [ $N -eq 0 ]
