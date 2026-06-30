#!/usr/bin/env bash
# Build the WEB version: reuse the raylib renderer, compiled to WebAssembly via
# emscripten. The pure sim core + render layer are emitted to C by machin, then
# emcc links them against raylib's web build. The blocking main loop is made
# browser-friendly with -sASYNCIFY + a per-frame emscripten_sleep (injected by
# sed into the EndDrawing line — no source edits).
#
# Prereqs:
#   * emscripten active:  source ~/emsdk/emsdk_env.sh ; export EMSDK_PYTHON=/usr/bin/python3
#   * raylib web prebuilt at $RLWEB (raylib-5.0_webassembly)
set -euo pipefail
cd "$(dirname "$0")/.."
MACHIN="${MACHIN:-machin}"
RLWEB="${RLWEB:-/tmp/rlweb/raylib-5.0_webassembly}"
OUT=web/build

# pure core + web FFI + render layer + main (note: web/emscripten.src adds the
# emscripten_sleep extern; sed adds the call after EndDrawing)
SRCS=(
  src/00_math.src src/01_armspec.src src/01b_layout.src
  src/02_kinematics.src src/02b_hydraulics.src src/02c_task.src
  web/emscripten.src
  src/03_ffi.src src/04_arm.src src/05_scene.src src/06_main.src
)

mkdir -p "$OUT"
echo "==> emitting C from machin"
cat "${SRCS[@]}" \
  | sed 's/^        EndDrawing()$/        EndDrawing()\n        emscripten_sleep(16)/' \
  | "$MACHIN" encode /dev/stdin \
  | "$MACHIN" build /dev/stdin --emit-c > "$OUT/game.raw.c"
# emscripten is strict about implicit includes the native gcc path tolerated
{ echo '#include <signal.h>'; cat "$OUT/game.raw.c"; } > "$OUT/game.c"
rm -f "$OUT/game.raw.c"
echo "    $(wc -l < "$OUT/game.c") lines of C"

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
  --shell-file web/shell.html

echo "built $OUT/index.html (+ .js + .wasm)"
