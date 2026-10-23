#!/bin/bash
# st_listing.sh PROG.s OUT.lst : a vasm listing of a program (find a crash's text offset in it:
# grep "^00:000OFFSET" OUT.lst)
R=$(cd "$(dirname "$0")/.." && pwd); SRC=$(readlink -f "$1"); OUT=$(readlink -f "$2")
cd "$(dirname "$SRC")" && vasmm68k_mot $ASMDEFS -Ftos -m68000 -opt-brajmp -nowarn=2047 -quiet -I"$R/kernel" -I"$R/spikes" \
  -I"$R/build" -I"$R/game" -L "$OUT" -Lall -o /dev/null "$SRC" 2>&1 | grep -v "warning 22\|^$" ; echo "listing: $OUT"
