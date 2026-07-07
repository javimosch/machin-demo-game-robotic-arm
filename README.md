# machin-demo-game-robotic-arm

A 3D simulation of a **robotic arm working at a table**, written in pure
[machin](https://github.com/javimosch/machin) (MFL) over [raylib](https://www.raylib.com/).
A real demo experiment and a reusable base toward a robotic arm in a
**boulangerie / panadería / bakery store** — autonomous pick-and-place of dough,
baguettes, trays.

The interesting parts are the three simulation pillars, two of them new to
machin's gamedev record:

- **Kinematics** — forward kinematics (rlgl matrix stack) + *analytic* inverse
  kinematics (base yaw + 2-link law of cosines).
- **Kinetics** — joints chase IK targets through velocity/acceleration-limited,
  critically-damped actuators, so the arm moves like a machine.
- **Hydraulics** — each joint driven by a flow-limited hydraulic cylinder with a
  pressure readout (upgradeable to a full pressure/force model).

See [`docs/BRAINSTORM.md`](docs/BRAINSTORM.md) for the full design.

## Status

- **Step 1 — static workcell.** ✅ Table, dough bin, baking tray, and the 4-DOF
  arm posed at rest (forward kinematics only), under a slowly orbiting camera.
  Validates the FFI, the FK rig, the scene, and the build pipeline.
- **Step 2 — IK + actuator core.** ✅ Pure-MFL forward + analytic inverse
  kinematics (base yaw + 2-link law of cosines, auto elbow-branch selection,
  joint limits, out-of-reach handling) and a damped, velocity/accel-limited
  actuator model. **31 headless unit tests pass** (`./tests/run_tests.sh`).
- **Step 3 — live arm.** ✅ The core is wired into the render loop: each frame
  picks a moving target, solves `ik_pick` (gripper held straight down), and
  drives the four joints toward it through the damped actuators on a fixed 60 Hz
  accumulator. The arm visibly chases a marker (green = reachable / red = out of
  reach); a tip-cube shows the actuators lagging then catching up.
- **Step 4 — flow-limited hydraulics.** ✅ The three pitch joints are actuated by
  hydraulic cylinders: a forward-only law-of-cosines linkage maps joint angle →
  cylinder length (drawn in world space as barrel + sliding rod), the valve's max
  **flow caps each joint's angular speed** through the local linkage ratio, and a
  **pressure proxy** (gravity load ÷ moment arm) shows on the HUD and tints each
  barrel toward red under load.
- **Step 5 — autonomous bakery loop.** ✅ **v1 MVP complete.** A pick-and-place
  state machine (`over-bin → descend → grasp → lift → over-tray → descend →
  release → retract`) lifts dough balls from the bin and sets them, one per slot,
  on the baking tray — the grasped ball is glued to the gripper, the released
  ball **falls under gravity** and settles golden in its slot, then the loop
  refills and repeats. Fully autonomous. **56 headless tests pass.**
- **Step 6 — grip-force + dough deformation.** ✅ The gripper closes to a target
  *force* (not all the way shut): too little won't hold, too much crushes the
  dough. Dough visibly squishes under grip force and turns dark/"spoiled" if
  over-crushed — the arm grips to a safe force so it never does. HUD shows live
  grip force. **75 headless tests pass.**

- **Step 7 — wrist roll (5th DOF) + baguettes.** ✅ A 5th joint (wrist roll about
  the tool axis) lets the gripper orient its payload. Items now come in two kinds
  — round boules and elongated **baguettes** — and the arm rolls the wrist to lay
  each baguette lengthwise into its slot. Roll is a rotary actuator (base yaw is
  too); the three pitch joints stay hydraulic. **81 headless tests pass.**

- **Step 8 — production line.** ✅ Four stations — **bin → proof → oven → cool** —
  with a routing scheduler that moves the most-advanced ready item one hop at a
  time. Proofing and baking are **timed processes** that run while items rest
  (dough visibly **rises** at the proof rack, turns **golden** when baked); the
  loaf is **scored** before the oven. Loops once every item has cooled.
- **Step 9 — conveyor feed + KPIs.** ✅ Raw dough arrives on an **animated feed
  conveyor**; a HUD KPI panel shows finished loaves, **throughput/min**, uptime,
  trays completed, and rejects, plus the live pipeline counts per station.
- **Multi-arm core + second arm.** ✅ Refactored to a frame-aware `[]Arm`
  (`02d_arm.src`: each arm carries its base frame, joints, FSM, and serviced
  station range — all pure/value-semantic). Added a **rail-mounted display arm**:
  it slides along a rail (a prismatic base axis) to pick **cooled** loaves and
  set them on a **client-facing display counter**, parking at a **charging dock**
  when idle. Two arms run concurrently with a clean handoff at the cool tray
  (`bin→proof→oven→cool` **→ rail →** `display`). **106 headless tests pass.**

## Neural reacher (ml/)

The arm is also a machine-learning benchmark: `ml/` trains a tiny neural network
(via [tinybrain](https://github.com/javimosch/tinybrain), vendored in
`ml/vendor/`) to do `ik_wrist_auto`'s job **in closed loop** — 13 inputs (joints,
joint velocities, wrist→target error at two scales) → 3 joint-velocity commands,
under the same vmax/amax actuator caps as the analytic controller. Because the
analytic IK is exact, it is a **ground-truth baseline** the learned policy is
measured against, honestly:

- **Pure evolution from scratch plateaus** far from the baseline (the Cartesian→
  joint mapping is a pose-dependent Jacobian — hard for a GA alone).
- The shipped pipeline is **behavior cloning + fine-tuning**: SGD clones the
  analytic controller from 4k expert-labeled states (half sampled in the
  near-target endgame regime) plus a DAgger round on the clone's own
  trajectories, then `evolve_run` with `warm_start` (a tinybrain feature this
  demo drove upstream) fine-tunes on the closed-loop episode score.
- **Result** (`ml/models/reacher.json`, committed): the fine-tuned policy
  **beats the analytic controller's episode score on training targets**
  (−21.06 vs −21.40) and reaches **46/50 held-out targets** within a 6 cm
  tolerance at a mean time-to-reach only ~4% slower than the IK (124 vs 120
  ticks). The remaining 4 are hover-just-outside failures — reported, not hidden.

Retrain (~2 min, deterministic): see the header of `ml/reach_train.src`.
The ml suite in `./tests/run_tests.sh` evaluates the committed artifact against
the analytic IK on 50 held-out targets — no retraining in tests.

**Watch them race — [arm.intrane.fr/reach](https://arm.intrane.fr/reach/)**:
`ml/reach_game.src` puts both controllers side by side chasing the *same*
random target sequence under the same actuator limits, with a live scoreboard
(targets reached at 6 cm sustained, mean time-to-reach). Blue = analytic IK,
green = the tinybrain artifact. Native: `ml/build_game.sh` → `./reach-game`;
web: `ml/build_web.sh` (same emscripten recipe as the main demo, the artifact
embedded in the module's virtual FS). In continuous chase mode (no reset
between targets — harder than the training protocol) the net still lands
44/50 vs the IK's 50/50.

## Test

```sh
./tests/run_tests.sh   # pure sim core + the ml reacher-vs-IK benchmark, headless (no raylib)
```

## Build & run

```sh
./build.sh        # vendors raylib 5.0 (static) if no system raylib, then builds
./robotic-arm     # run from the repo root
```

Esc quits.

> **Not a self-contained binary.** Like every raylib game, this links the system
> OpenGL/X11/audio stack and needs a display. machin's no-dependency single-binary
> property holds for the headless domain, not for GUI games.

## Web build (WebAssembly)

The same raylib renderer cross-compiles to WebAssembly via emscripten — the pure
MFL simulation core has no extern block, and the raylib renderer compiles to
WebGL — so the whole thing runs in a browser, no plugins:

```sh
source ~/emsdk/emsdk_env.sh && export EMSDK_PYTHON=/usr/bin/python3
RLWEB=/path/to/raylib-5.0_webassembly ./web/build_web.sh   # -> web/build/index.{html,js,wasm}
cd web/build && python3 -m http.server 8911                # serve locally
```

How it works: `web/build_web.sh` emits C with `machin build --emit-c`, injects a
per-frame `emscripten_sleep` (so the blocking main loop yields to the browser
under `-sASYNCIFY`), and links against raylib's web build with `emcc`
(`-sUSE_GLFW=3`). `web/emscripten.src` declares the `emscripten_sleep` FFI;
`web/shell.html` is the page. Verified in-browser: raylib 5.0 boots on the
`WEB (HTML5)` backend with a live WebGL context.

## Source layout

The files up to and including `02c` are the **pure simulation core** (no extern
block) — they are also exactly what the headless tests compile and run.

| file | what |
|---|---|
| `src/00_math.src` | scalar helpers + a plain `Vec3` value type |
| `src/01_armspec.src` | arm geometry, joint limits, rest pose, actuator params |
| `src/01b_layout.src` | product sizing, kinds, rest heights, run length |
| `src/01c_stations.src` | the production pipeline: station layout, routing, process timing |
| `src/02_kinematics.src` | forward + inverse kinematics, damped actuators |
| `src/02b_hydraulics.src` | flow-limited cylinder linkage + pressure proxy |
| `src/02c_task.src` | dough items, grip-force, gravity, processes, scheduler |
| `src/03_ffi.src` | raylib + rlgl FFI, `Vector3`/`Color` helpers, window + palette |
| `src/04_arm.src` | 4-DOF arm FK rendering + hydraulic cylinders |
| `src/05_scene.src` | table, dough bin, baking tray, floor |
| `src/06_main.src` | pick-and-place state machine + main loop |
| `tests/test_kinematics.src` | headless unit tests for the whole core |

Built with machin v0.80.0.
