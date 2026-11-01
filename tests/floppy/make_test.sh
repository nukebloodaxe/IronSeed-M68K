#!/bin/bash
# make_test.sh (Phase 8): the floppy test folder: build/floppy_test = a NOMUSIC game folder (tools/mkgame.sh)
# with the four programs built -DFLPNF=1 (prompts announced to the Hatari driver through NatFeats).
# Then: tests/floppy/flp_cg.sh 16000 (intro + crewgen + save from the floppies; leaves the s4 save on
# the save disk: build/floppy_s4save is extracted from it) and tests/floppy/flp_main.sh m1 m9 ...
set -e
R=$(cd "$(dirname "$0")/../.." && pwd); cd "$R"
G=build/floppy_test
rm -rf $G; NOMUSIC=1 tools/mkgame.sh $G > /dev/null
for p in is intro crewgen main; do ASMDEFS=-DFLPNF=1 tools/asm.sh game/$p.s $G/$(echo $p | tr a-z A-Z).PRG > /dev/null; done
echo "test folder: $G"
