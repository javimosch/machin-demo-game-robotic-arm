# SKILL: machin-demo-game-robotic-arm

Specifics for *this* repo. The shared substrate (raylib FFI, build/verify,
rlgl matrix stack, the int→float gotcha) lives in the `machin-gamedev` skill —
read that first.

## What this is

A 3D robotic-arm sim: a 4-DOF articulated arm doing (eventually autonomous)
pick-and-place of dough balls from a bin to a baking tray. Base for a bakery
robot experiment. Three pillars: kinematics (FK + analytic IK), kinetics
(damped actuators), hydraulics (flow-limited cylinders). Design in
`docs/BRAINSTORM.md`.

## Build & verify

- `./build.sh` → `./robotic-arm`. Vendors raylib 5.0 static; system raylib
  preferred if present.
- `./tests/run_tests.sh` → headless unit tests for the pure core. It concatenates
  ONLY `src/00_math.src src/01_armspec.src src/02_kinematics.src` + the test, then
  `machin encode | machin run`. These files contain **no extern block**, which is
  why they run without linking raylib — keep the simulation core extern-free.
- Verify rendering: run backgrounded with `DISPLAY=:0`, `sleep ~2.5`, then
  `DISPLAY=:0 import -window root /tmp/shot.png`, read the PNG, `kill`.
- The arm runs **autonomously** (no keystroke injection available here), so a
  screenshot of a running build is the gameplay check; the headless tests cover
  the math.

## Architecture split (important)

- **Pure core** (`00_math`, `01_armspec`, `02_kinematics`): no extern, plain
  `Vec3` value type, headless-testable. One source of truth for geometry.
- **Render layer** (`03_ffi`, `04_arm`, `05_scene`, `06_main`): the only extern
  block; converts `Vec3` → raylib `Vector3` via `vec2r()`/`v3()`.
- IK: `ik_pick(target) -> j1,j2,j3,j4,ok` auto-selects the elbow branch and
  wraps the wrist angle to keep the gripper pointing down. `ik_wrist_auto(w)`
  for a bare wrist target. Actuators: `joint_step(Joint, target, dt, vmax, amax,
  gain)` returns the advanced `Joint` (value semantics).

## Conventions specific to this repo

- **Angles are DEGREES** at the rendering boundary (rlRotatef); the IK/actuator
  layer will work in radians and convert at the edge (`deg2rad`/`rad2deg`).
- **FK convention:** links extend along local **+Y**; pitch joints (shoulder,
  elbow, wrist) rotate around local **+Z**; the base yaws around **+Y**. The
  whole chain is `rlPushMatrix` … nested `rlTranslatef`/`rlRotatef` … draw at the
  local origin (`v3z()`) … `rlPopMatrix`. See `draw_arm`.
- **Table top surface is the y=0 plane.** Pedestal, bin, tray all sit on it;
  the floor grid is at `FLOOR_Y()`.
- `DrawCube`/`DrawSphere` respect the rlgl matrix stack (draw at the local
  origin and let the matrix place them).
- `Vector3` is raylib's cstruct; the `vadd/vsub/...` helpers in `02_math3d.src`
  operate on it directly (its fields are named, so `.x/.y/.z` work).

## Step status

- **Step 1 ✅** static workcell + FK rest pose + orbit camera. Builds & renders.
- **Step 2 ✅** pure IK + actuator core; 31 headless tests pass. GUI unchanged.
- **Step 3 ✅** live arm: `ik_pick` → damped joints @ fixed 60 Hz, tracks a
  moving target, gripper held down. Verified by screenshot.
- **Step 4 ✅** flow-limited hydraulics: `02b_hydraulics.src` — forward-only
  linkage `cyl_len(θ)`, flow→speed cap `cyl_vmax`, `cyl_pressure` proxy. Drawn as
  world-space cylinders (`draw_hydraulics` in 04_arm), pressure on HUD + barrel
  tint. Verified by screenshot.
- **Step 5 ✅ (v1 MVP)** autonomous pick-and-place: `01b_layout.src` (shared
  bin/tray/slot/dough positions) + `02c_task.src` (Dough type, grasp/release,
  `dough_fall` gravity). The state machine lives in `06_main.src` (`enter_phase`
  / `task_step`, 10 phases). Grasped ball glued to `fk_tip`; released ball falls
  and settles golden in its slot; loops + resets. **56 headless tests pass.**
  Verified by screenshot across a full cycle.
- **Step 6 ✅** grip-force control + dough deformation (gentle handling: grip to a
  force, squish, spoil).
- **Step 7 ✅** wrist roll (5th DOF) + baguettes (oriented payloads via
  `DrawCapsule`).
- **Step 8 ✅** production line: bin→proof→oven→cool stations + routing scheduler
  (`choose_job`), timed proof-rise + oven-bake, scoring. Pure logic in
  `01c_stations.src` + `02c_task.src`.
- **Step 9 ✅** conveyor feed (animated) + KPI HUD (throughput/min, uptime, baked
  count, rejects).
- **Multi-arm core ✅ (refactor)** the singleton-globals arm became a pure
  `Arm` value type in `02d_arm.src` — base frame (position + yaw + rail), 5
  joints, its own FSM + job + serviced station range — held in a `[]Arm`.
  Frame transforms (`world_to_local`/`local_to_world`) let an arm sit/face
  anywhere; `arm_drive`/`arm_fsm` are pure (value-in/out, mutate the shared
  `[]Dough`). `06_main` is now a thin world loop over the arms. Behavior is
  identical with one pedestal arm (base 0). **97 headless tests.** This is the
  foundation for N arms (e.g. a rail-mounted display arm).

## Verifying when the WM hides the window

The dev machine is multi-workspace and actively used, so a launched game window
often lands on another workspace (root screenshots miss it) and headless-GPU
screenshots can hang. Reliable trick: temporarily add `fn TakeScreenshot(string)`
to the raylib extern and a one-shot `if cam_a > T { TakeScreenshot("cap.png") }`
in the loop — the game writes its own framebuffer to disk regardless of
workspace. Revert the probe before committing.

## Hydraulics notes

- The cylinder model is **forward-only** on purpose: `cyl_len(θ)` (law of cosines)
  and `ds/dθ` are all we compute, so there's no monotonicity/invertibility
  requirement and it works across the full joint range. The "flow limit" is real:
  `joint_vmax` feeds `cyl_vmax = qmax/|ds/dθ|` into `joint_step`'s velocity cap.
- Cylinders are drawn in **world space** via `DrawCylinderEx` (world endpoints),
  computed from the same `link_dir`/`link_norm` helpers the sim uses — they do
  NOT ride the `draw_arm` matrix stack.
- Upgrade path to the full pressure/force model: keep the interfaces, replace the
  flow follower with `Q→ΔV→P, F=P·A−load−friction`, integrate the piston.

## Known limitations / next polish

- **Elbow-branch flip:** `ik_wrist_auto` picks by feasibility, so a sweeping
  target can switch elbow branches mid-motion (a large, smooth-but-big elbow
  swing). Fix when it matters: pick the branch closest to the current elbow
  angle (continuity), e.g. an `ik_pick_continuous(target, prev_j3)`.
- **State persistence pattern:** the live joints live in a package-global
  `[]Joint` (`g_joints`), initialized once via `init_joints()` and updated with
  `g_joints[i] = joint_step(...)` each fixed step. Globals persist across frames;
  the slice element-assignment is visible because slices are reference-ish.
