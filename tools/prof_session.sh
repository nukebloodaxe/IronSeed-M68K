#!/bin/bash
# prof_session.sh SESSION VBL0 VBL1 : CPU profile of MAIN.PRG between two frames of an oracle session
# (oracle/scripts/SESSION.main, its "# setup" applied as tests/check_main.sh does). Builds MAIN with
# symbols (SYM=1) into hatari/c; the profile is in hatari/prof.log (tools/hatari_prof.sh), and a
# per-symbol summary is printed. Needs the s4 save (tests/check_crewgen.sh).
R=$(cd "$(dirname "$0")/.." && pwd); cd "$R"
S=$1; V0=$2; V1=$3
SETUP=$(sed -n 's/^# *setup //p' oracle/scripts/$S.main)
if [ -n "$SETUP" ]; then python3 tools/mksave.py build/layout.json build/oracle_s4/home 3 /tmp/prof_setup 3 hatari/c $SETUP > /dev/null || exit 1; fi
SYM=1 tools/asm.sh game/main.s hatari/c/MAIN.PRG || exit 1
python3 tools/st_script.py oracle/scripts/$S.main hatari/c/INPUT.MN
rm -rf hatari/c/*.SCR hatari/c/D0*.BIN hatari/c/CRASH.TXT hatari/c/TEMP
tools/hatari_prof.sh $V0 $V1 'C:\MAIN.PRG'
rm -f hatari/c/INPUT.MN
[ -n "$SETUP" ] && python3 tools/mksave.py build/layout.json build/oracle_s4/home 3 build/setup_none 3 hatari/c > /dev/null
tools/asm.sh game/main.s hatari/c/MAIN.PRG > /dev/null
sed -n '/[Pp]rofile/,$p' hatari/prof.log | head -60
