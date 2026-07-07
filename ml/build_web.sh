#!/usr/bin/env bash
# WEB build of the NEURO vs IK head-to-head (ml/reach_game.src) via emscripten.
# Same recipe as web/build_web.sh; the tinybrain artifact is embedded into the
# module's virtual FS so read_file("ml/models/reacher.json") works in-browser.
#
# Prereqs:
#   source ~/emsdk/emsdk_env.sh ; export EMSDK_PYTHON=/usr/bin/python3
set -euo pipefail
cd "$(dirname "$0")/.."
MACHIN="${MACHIN:-machin}"
RLWEB="${RLWEB:-/tmp/rlweb/raylib-5.0_webassembly}"
OUT=web/build-reach

if [ ! -f "$RLWEB/lib/libraylib.a" ]; then
    mkdir -p "$(dirname "$RLWEB")"
    curl -fsSL "https://github.com/raysan5/raylib/releases/download/5.0/raylib-5.0_webassembly.zip" -o /tmp/rlweb.zip
    unzip -qo /tmp/rlweb.zip -d "$(dirname "$RLWEB")"
fi

SRCS=(
  src/00_math.src src/01_armspec.src src/02_kinematics.src
  ml/vendor/tinybrain.src ml/reacher.src
  web/emscripten.src
  ml/reach_game.src
)

mkdir -p "$OUT"
echo "==> emitting C from machin"
cat "${SRCS[@]}" \
  | sed 's/^\t\tEndDrawing()$/\t\tEndDrawing()\n\t\temscripten_sleep(16)/' \
  | "$MACHIN" encode /dev/stdin \
  | "$MACHIN" build /dev/stdin --emit-c > "$OUT/game.raw.c"
{ echo '#include <signal.h>'; cat "$OUT/game.raw.c"; } > "$OUT/game.c"
rm -f "$OUT/game.raw.c"
echo "    $(wc -l < "$OUT/game.c") lines of C"

# the reach page: same shell, its own title/subtitle
sed -e 's|machin robotic arm — bakery pick &amp; place|NEURO vs IK — a tiny neural net races the analytic solver|' \
    "$OUT/../shell.html" > "$OUT/shell.html"

echo "==> emcc -> wasm"
emcc "$OUT/game.c" -o "$OUT/index.html" \
  -O2 \
  -Uunix -Ulinux -Wno-parentheses-equality \
  -I "$RLWEB/include" -L "$RLWEB/lib" -lraylib \
  -sUSE_GLFW=3 \
  -sASYNCIFY \
  -sALLOW_MEMORY_GROWTH=1 \
  -sASYNCIFY_STACK_SIZE=16384 \
  -sEXIT_RUNTIME=0 \
  --embed-file ml/models/reacher.json@ml/models/reacher.json \
  --shell-file "$OUT/shell.html"
rm -f "$OUT/game.c" "$OUT/shell.html"

echo "built $OUT/index.html (+ .js + .wasm)"