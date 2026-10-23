#!/bin/bash
# asm.sh SRC.s OUT.PRG : assemble a TOS program with vasm (68000, Devpac syntax).
# Include paths: the source's directory, kernel/, spikes/. Fails on any assembler message.
set -e
R=$(cd "$(dirname "$0")/.." && pwd)
SRC=$(readlink -f "$1"); OUT=$(readlink -f "$2")
cd "$(dirname "$SRC")"
MSG=$(vasmm68k_mot $ASMDEFS -Ftos -m68000 ${SYM:+-tos-flags=0} $([ -z "$SYM" ] && echo -nosym) -quiet -I"$R/kernel" -I"$R/spikes" -I"$R/build" -I"$R/game" -o "$OUT" "$SRC" 2>&1) || { echo "$MSG"; exit 1; }
if echo "$MSG" | grep -qiE 'error|warn'; then echo "$MSG"; rm -f "$OUT"; exit 1; fi
echo "built $(basename "$OUT")"
