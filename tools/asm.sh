#!/bin/bash
# asm.sh SRC.s OUT.PRG : assemble a TOS program with vasm (68000, Devpac syntax).
# Include paths: the source's directory, kernel/, spikes/. Widens out-of-range .s branches first
# (tools/fixbranches.py), then fails on any assembler message.
set -e
R=$(cd "$(dirname "$0")/.." && pwd)
SRC=$(readlink -f "$1"); OUT=$(readlink -f "$2")
python3 -I "$R/tools/fixbranches.py" "$SRC" > /dev/null   # widen .s branches that went out of range
cd "$(dirname "$SRC")"
MSG=$(vasmm68k_mot $ASMDEFS -Ftos -m68000 -opt-brajmp -nowarn=2047 ${SYM:+-tos-flags=0} $([ -z "$SYM" ] && echo -nosym) -quiet -I"$R/kernel" -I"$R/spikes" -I"$R/build" -I"$R/game" -o "$OUT" "$SRC" 2>&1) || { echo "$MSG"; exit 1; }
[ -n "$SYM" ] && MSG=$(echo "$MSG" | grep -v "warning 22: target data type overflow" || true)   # (symbol builds: an equate wider than 32 bits in the table)
if echo "$MSG" | grep -qiE 'error|warn'; then echo "$MSG"; rm -f "$OUT"; exit 1; fi
echo "built $(basename "$OUT")"
