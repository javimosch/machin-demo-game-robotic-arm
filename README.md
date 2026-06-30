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
  actuator model. **31 headless unit tests pass** (`./tests/run_tests.sh`) —
  FK/IK round-trips, azimuth, reach limits, actuator convergence. The GUI still
  renders the static rest pose; step 3 wires the core into the loop.

Roadmap (additive, each step verified before the next):

3. Wire IK → damped actuators → the rendered arm; track a moving target.
4. Hydraulic cylinders (flow-limited) + pressure HUD.
5. Pick-and-place state machine + grasp/attach + payload gravity → autonomous loop.

## Test

```sh
./tests/run_tests.sh   # encodes + runs the pure simulation core, headless (no raylib)
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

## Source layout

The first three files are the **pure simulation core** (no extern block) — they
are also exactly what the headless tests compile and run.

| file | what |
|---|---|
| `src/00_math.src` | scalar helpers + a plain `Vec3` value type |
| `src/01_armspec.src` | arm geometry, joint limits, rest pose, actuator params |
| `src/02_kinematics.src` | forward + inverse kinematics, damped actuators |
| `src/03_ffi.src` | raylib + rlgl FFI, `Vector3`/`Color` helpers, window + palette |
| `src/04_arm.src` | 4-DOF arm forward-kinematics rendering |
| `src/05_scene.src` | table, dough bin, baking tray, floor |
| `src/06_main.src` | orbit camera + main loop |
| `tests/test_kinematics.src` | headless unit tests for the core |

Built with machin v0.80.0.
