#!/usr/bin/env bash
# Headless unit tests for the pure simulation core (math + armspec + kinematics).
# No raylib: the tested files contain no extern block, so this runs anywhere
# machin runs.
set -euo pipefail
cd "$(dirname "$0")/.."
MACHIN="${MACHIN:-machin}"

PURE="src/00_math.src src/01_armspec.src src/01b_layout.src src/01c_stations.src src/02_kinematics.src src/02b_hydraulics.src src/02c_task.src src/02d_arm.src tests/test_kinematics.src"
OUT="$(mktemp --suffix=.mfl)"

cat $PURE | "$MACHIN" encode /dev/stdin > "$OUT"
"$MACHIN" run "$OUT"

# ml suite: the neural reacher (vendored tinybrain) benchmarked vs the analytic
# IK, using the committed artifact ml/models/reacher.json. Also headless.
ML="src/00_math.src src/01_armspec.src src/02_kinematics.src ml/vendor/tinybrain.src ml/vendor/evolve.src ml/reacher.src ml/reach_test.src"
OUT2="$(mktemp --suffix=.mfl)"
cat $ML | "$MACHIN" encode /dev/stdin > "$OUT2"
"$MACHIN" run "$OUT2"
