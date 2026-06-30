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
- Verify rendering: run backgrounded with `DISPLAY=:0`, `sleep ~2.5`, then
  `DISPLAY=:0 import -window root /tmp/shot.png`, read the PNG, `kill`.
- The arm runs **autonomously** (no keystroke injection available here), so a
  screenshot of a running build is the gameplay check. Factor IK/actuator math
  into pure functions and unit-test headless with `machin run` first.

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
- Steps 2–5: see README roadmap.
