#!/usr/bin/env bash
# Build machin-demo-game-robotic-arm.
# Source order. The first three files are the PURE simulation core (no extern);
# they are also what tests/run_tests.sh compiles & runs headless.
#   src/00_math.src       — scalars + plain Vec3 value type
#   src/01_armspec.src    — arm geometry, limits, rest pose, actuator params
#   src/02_kinematics.src — forward + inverse kinematics, damped actuators
#   src/03_ffi.src        — raylib + rlgl FFI, Vector3/Color helpers, palette
#   src/04_arm.src        — 4-DOF arm forward-kinematics rendering
#   src/05_scene.src      — table, dough bin, baking tray, floor
#   src/06_main.src       — orbit camera + main loop
# Vendors raylib 5.0 if no system raylib is found. machin v0.48.0+.
set -euo pipefail
cd "$(dirname "$0")"
MACHIN="${MACHIN:-machin}"
BIN=robotic-arm
COMBINED=app.mfl

SRCS="src/00_math.src src/01_armspec.src src/02_kinematics.src src/03_ffi.src src/04_arm.src src/05_scene.src src/06_main.src"

have_system_raylib() {
    pkg-config --exists raylib 2>/dev/null && return 0
    [ -f /usr/include/raylib.h ] || [ -f /usr/local/include/raylib.h ]
}

if have_system_raylib; then
    cat $SRCS | "$MACHIN" encode /dev/stdin > "$COMBINED"
else
    RL_VER=5.0
    RL_TAR="raylib-${RL_VER}_linux_amd64"
    RL_DIR="vendor/${RL_TAR}"
    CACHE="/tmp/rl/${RL_TAR}"
    if [ ! -f "${RL_DIR}/lib/libraylib.a" ]; then
        if [ -f "${CACHE}/lib/libraylib.a" ]; then
            echo "using cached raylib from ${CACHE}"
            mkdir -p vendor
            cp -r "${CACHE}" "${RL_DIR}"
        else
            echo "vendoring raylib ${RL_VER}..."
            mkdir -p vendor
            curl -fsSL "https://github.com/raysan5/raylib/releases/download/${RL_VER}/${RL_TAR}.tar.gz" \
                | tar xz -C vendor
        fi
    fi
    INC="$PWD/${RL_DIR}/include"
    LIB="$PWD/${RL_DIR}/lib"
    tmp="$(mktemp)"
    cat $SRCS | "$MACHIN" encode /dev/stdin \
        | sed "s#header \"raylib.h\"#cflags \"-I${INC} -L${LIB}\" header \"raylib.h\"#; s#link \"raylib\"#link \":libraylib.a\"#" \
        > "$tmp"
    mv "$tmp" "$COMBINED"
fi

"$MACHIN" build "$COMBINED" -o "$BIN"
echo "built ./$BIN"
