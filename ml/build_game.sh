#!/usr/bin/env bash
# Build the NEURO vs IK head-to-head (ml/reach_game.src). Vendors static raylib
# if no system one (same cache as the main build.sh).
set -euo pipefail
cd "$(dirname "$0")/.."
MACHIN="${MACHIN:-machin}"
MODS="src/00_math.src src/01_armspec.src src/02_kinematics.src ml/vendor/tinybrain.src ml/reacher.src ml/reach_game.src"
if pkg-config --exists raylib 2>/dev/null || [ -f /usr/include/raylib.h ]; then
    "$MACHIN" encode $MODS > reach-game.mfl
else
    RL="raylib-5.0_linux_amd64"; D="vendor/$RL"
    if [ ! -f "$D/lib/libraylib.a" ]; then
        mkdir -p vendor
        if [ -d "/tmp/rl/$RL" ]; then cp -r "/tmp/rl/$RL" vendor/
        else curl -fsSL "https://github.com/raysan5/raylib/releases/download/5.0/$RL.tar.gz" | tar xz -C vendor; fi
    fi
    INC="$PWD/$D/include"; LIB="$PWD/$D/lib"
    "$MACHIN" encode $MODS | sed "s#header \"raylib.h\"#cflags \"-I${INC} -L${LIB}\" header \"raylib.h\"#; s#link \"raylib\"#link \":libraylib.a\"#" > reach-game.mfl
fi
"$MACHIN" build reach-game.mfl -o reach-game
rm -f reach-game.mfl
echo "built ./reach-game — run from the repo root (loads ml/models/reacher.json)"
