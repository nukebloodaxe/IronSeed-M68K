#!/bin/bash
# gen_layout.sh [IRONSEED_SRC] : regenerate build/layout.i + build/layout.json and the converted data in build/data
set -e
R=$(cd "$(dirname "$0")/.." && pwd); S=${1:-${IRONSEED_SRC:-/root/ironseed_fpc}}
mkdir -p "$R/build"
ARGS=""; for f in utils_ data cargtool combat comm comm2 crewgen explore utils2 journey intro saveload crew2 crewinfo info usecode display weird gmouse starter ending; do ARGS="$ARGS --pas $S/$f.pas"; done
python3 -I "$R/tools/rec2equ.py" $ARGS --globals "$S/data.pas" --skip-global screen --skip-global canary_ \
  --equ "$R/build/layout.i" --json "$R/build/layout.json" \
  --check shiptype=1586 --check systems=6750 --check cargo=3625 --check rescargo=500 --check events=1024 \
  --check logs=512 --check logpending=512 --check alientype=31 --check planarray=33000 --check colors=768
python3 -I "$R/tools/convdata.py" "$R/build/layout.json" "$R/tools/datafiles.json" "$S/data" "$R/build/data" > "$R/build/convdata.log"
echo "converted $(ls "$R/build/data" | wc -l) data files (log: build/convdata.log)"
python3 -I "$R/tools/gen_font.py" "$S/data.pas" "$R/build/font.i"
python3 -I "$R/tools/gen_sndtab.py" "$R/build/snd_tables.i"
