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

**Step 1 — static workcell.** ✅ Table, dough bin, baking tray, and the 4-DOF
arm posed at rest (forward kinematics only), under a slowly orbiting camera.
This validates the FFI, the FK rig, the scene, and the build pipeline.

Roadmap (additive, each step verified before the next):

2. Pure-MFL IK + actuator module with headless `machin run` unit tests.
3. Wire IK → damped actuators → the rendered arm; track a moving target.
4. Hydraulic cylinders (flow-limited) + pressure HUD.
5. Pick-and-place state machine + grasp/attach + payload gravity → autonomous loop.

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

| file | what |
|---|---|
| `src/01_ffi.src` | raylib + rlgl FFI, color/vec helpers, window + palette constants |
| `src/02_math3d.src` | Vec3 module over raylib's `Vector3` |
| `src/03_arm.src` | 4-DOF arm geometry + forward-kinematics rendering |
| `src/04_scene.src` | table, dough bin, baking tray, floor |
| `src/05_main.src` | orbit camera + main loop |

Built with machin v0.80.0.
