# machin-demo-game-robotic-arm — Brainstorm & Design

A 3D simulation of a **robotic arm working at a table**, written in pure MFL
(machin) over raylib. Built as a *real demo experiment* and a reusable base for
future experiments toward a robotic arm in a **boulangerie / panadería / bakery
store** (pick-and-place of dough, baguettes, croissants, trays).

> Status: brainstorm / pre-implementation. Decisions locked below; scope tiers
> defined; nothing built yet.

---

## 1. Why this is a good machin demo (the dogfood angle)

A robotic arm is a **kinematic chain of joints** — which is exactly what
machin's proven rendering primitives already model. Everything we need exists
*except two layers*, and those two are the whole point of the experiment:

| Pillar | machin status | Source |
|---|---|---|
| Forward kinematics (draw the arm) | ✅ proven | cyberpunk fauna: nested `rlPushMatrix`/`rlTranslatef`/`rlRotatef` |
| 3D scene, orbit camera, table | ✅ proven | solar / player demos |
| Payload physics (fall, rest, stack) | ✅ proven | physics demo: verlet + gravity + ground collision |
| Vec3 / math3d module | ✅ proven | solar demo |
| **Inverse kinematics** (reach a target) | 🆕 **new layer** | this demo |
| **Actuator / joint dynamics** (smooth, mechanical motion) | 🆕 **new layer** | this demo |
| **Hydraulics** (flow-limited cylinders + pressure) | 🆕 **new layer** | this demo |

**The dogfood headline:** this is the demo that brings **inverse kinematics +
actuator simulation** into machin's gamedev record.

---

## 2. Locked decisions

| Decision | Choice | Rationale |
|---|---|---|
| **Arm architecture** | **Articulated RRR + wrist (~4-DOF)** | Base yaw + 2–3 link planar arm + wrist/gripper. Classic "industrial arm" look. IK is *analytic & robust* (no iterative solver to stabilize). |
| **Hydraulics fidelity (v1)** | **Flow-limited + drawn cylinders** | Cylinders rendered; valve/flow limits piston speed; pressure readout. Structured so the full pressure/force model is a drop-in upgrade. |
| **v1 task + payload** | **Dough balls, bin → tray, autonomous** | Spheres are the simplest payload; autonomous loop is trivial to verify by screenshot (no keystroke injection available in this env). |

---

## 3. Architecture

### 3.1 Degrees of freedom

```
        gripper (open/close)
         |
        wrist  (revolute, pitch) ......... J4
         |
        forearm
         |
        elbow  (revolute, pitch) ......... J3
         |
        upper arm
         |
        shoulder (revolute, pitch) ....... J2
         |
        base   (revolute, yaw around Y) .. J1
      ===============  table  ===============
```

- **J1 base yaw** — rotates the whole arm around the vertical axis to face the target column.
- **J2 shoulder + J3 elbow** — the 2-link planar reach (in the vertical plane defined by J1).
- **J4 wrist pitch** — keeps the gripper pointing down (or at a chosen approach angle).
- **Gripper** — a 1-DOF open/close (two fingers); not part of IK, driven by the task state machine.

### 3.2 Kinematics

- **Forward kinematics (rendering):** the rlgl matrix stack, one
  `rlPush`/`rlTranslate`/`rlRotate` per joint, drawing each link at its local
  origin (proven pattern). Also used to compute the gripper world-frame for
  grasping.
- **Inverse kinematics (the new layer):** *analytic*, two stages —
  1. **Base yaw:** `J1 = atan2(target.x - base.x, target.z - base.z)`.
  2. **Planar 2-link reach:** project the target into J1's plane, solve
     shoulder+elbow with the **law of cosines** (the standard 2-link IK). Pick
     the **elbow-up** solution. Clamp to joint limits; if the target is out of
     reach, solve for the closest reachable point (clamp the planar distance to
     `L2 + L3`).
  3. **Wrist:** `J4 = desired_approach_angle - (J2 + J3)` so the gripper holds a
     fixed world orientation (pointing down) regardless of arm pose.
  - CCD (cyclic coordinate descent) is held in reserve for a future 6-DOF arm.

### 3.3 Kinetics / actuator dynamics (the new layer)

IK yields **target** joint angles each frame. Joints **never snap** — each
chases its target through an actuator with:
- max angular velocity, max angular acceleration,
- a **critically-damped** controller (or simple accel-toward-target with
  velocity clamp), so motion has lag, easing, and clean settling.

This is what sells "a real machine moving" rather than a rig teleporting.

### 3.4 Hydraulics (v1: flow-limited + drawn)

Each revolute joint is **actuated by a hydraulic cylinder** — a prismatic piston
linked to the joint by a lever arm. As the piston extends (length `s`), the joint
angle `θ` changes through the linkage geometry (`θ = f(s)`, invertible).

v1 model per cylinder:
- A control valve commands flow `Q` toward the target length.
- `|Q| ≤ Q_max` ⇒ a **flow-limited piston speed** ⇒ a realistic top joint speed.
- A **pressure proxy** = effort needed to move against the current load
  (payload mass + gravity torque); shown on a gauge / colored cylinder.

Drawn as two telescoping bodies (barrel + rod) between the link anchor points,
extending/retracting visibly.

**Upgrade path (v2 → full model):** replace the flow integrator with
pressure dynamics — `Q → ΔV → P = k·ΔV`, `F = P·A − load − friction`,
`a = F/m`, integrate piston position. Flow-*and*-force limited, with a live
pressure gauge. The v1 interfaces (target length, current length, load) are
chosen so this swaps in without touching the kinematics/task layers.

### 3.5 The bakery task layer

- **Table** with a **dough bin** (source, holds N dough balls) and a **baking
  tray** (destination, a grid of slots).
- **Payload:** dough balls = spheres. (Baguettes = capsules, croissants =
  curved — later.)
- **Pick-and-place state machine** (autonomous, looping):

  ```
  IDLE
    → MOVE_OVER_PICK   (IK target = above next dough ball)
    → DESCEND          (lower onto the ball)
    → GRASP            (close gripper; attach ball to gripper frame)
    → LIFT             (raise to safe height)
    → MOVE_OVER_TRAY   (IK target = above next free tray slot)
    → DESCEND          (lower into slot)
    → RELEASE          (open gripper; detach; ball settles under gravity)
    → RETRACT          (raise; advance slot/source indices)
    → IDLE (repeat until tray full, then reset)
  ```

- **Grasping:** when the gripper world-frame is within radius of a ball and the
  state is GRASP, the ball **parents to the gripper** (its world pos = gripper
  pos each frame). On RELEASE it detaches and falls (gravity + rest on
  tray/table from the physics demo).

### 3.6 Camera & HUD

- Orbit camera around the table (auto-rotate slowly, or fixed 3/4 view for v1).
- HUD (screen space, after `EndMode3D`): current state, J1–J4 angles, cylinder
  pressures/extensions, balls placed / total, FPS.

---

## 4. Scope tiers

**v1 (MVP — the real base):**
4-DOF arm · analytic IK · damped actuators · flow-limited drawn cylinders ·
one dough bin → tray grid · autonomous pick-and-place loop · orbit camera · HUD.
*Proves the entire loop end-to-end and is verifiable by screenshot.*

**v2 (additive):**
- Full pressure/force hydraulic model + pressure gauges.
- More payloads (baguettes, croissants) with shape-aware grasp.
- Conveyor belt as a moving source.
- Interactive mode: mouse moves a 3D target marker; arm IK-tracks; click to
  grasp/release; keyboard jog.
- Stacking, multiple trays, throughput counter (a "bakery KPI").

**Future experiments (the north-star this seeds):**
6-DOF arm (CCD IK) · collision-aware path planning · two arms cooperating ·
dough deformation · oven/proofing stations · a real bakery cell layout.

---

## 5. Known machin gotchas to design around

(from the gamedev skill — the ones this demo will actually hit)

- **No implicit int→float.** Keep all world coords as floats; wrap concrete-int
  math with `float()`. Joint angles, lengths, pressures all `f64`/`f32`.
- **cstructs can't be fields of MFL `type` structs.** Use **parallel slices**
  for any raylib handle (`Color`, etc.). Arm state lives in plain MFL structs
  (`Vec3`, joint arrays) — no cstructs there, so this is mostly about colors.
- **Non-empty `[]struct` literals unsupported** — build with `append`.
- **`a < -b` lexer trap** — write `a < 0.0 - b`.
- **rlgl matrix stack** for all joint transforms (headerless extern block).
- **Fixed-timestep sim** (60 Hz accumulator) for the actuator + hydraulic
  integration — decouple physics from frame rate (proven in solar).
- **Verify autonomously:** the autonomous loop means we screenshot a running
  binary; also factor the IK + actuator math into pure functions for
  `machin run` headless unit tests (law-of-cosines reach, angle limits).

---

## 6. Open questions (for later, not blocking v1)

1. Link lengths / table scale — pick realistic-ish proportions or stylized?
2. Gripper: parallel two-finger (simple) vs. suction cup (common for dough)?
   v1 = two-finger; suction is a trivial visual swap later.
3. Approach angle: always straight-down (simplest) vs. tiltable? v1 = down.
4. How many dough balls / tray slots for v1? (e.g. 6 balls → 2×3 tray.)
5. Color/material style — clean industrial (white/steel/orange) vs. warm bakery?
