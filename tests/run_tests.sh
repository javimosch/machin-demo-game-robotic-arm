#!/usr/bin/env bash
# Headless unit tests for the pure simulation core (math + armspec + kinematics).
# No raylib: the tested files contain no extern block, so this runs anywhere
# machin runs.
set -euo pipefail
cd "$(dirname "$0")/.."
MACHIN="${MACHIN:-machin}"

PURE="src/00_math.src src/01_armspec.src src/02_kinematics.src src/02b_hydraulics.src tests/test_kinematics.src"
OUT="$(mktemp --suffix=.mfl)"

cat $PURE | "$MACHIN" encode /dev/stdin > "$OUT"
"$MACHIN" run "$OUT"
