# B2_ACCEPTANCE — Ruffle Observable Oracle

Status: **B2 COMPLETE WITH DOCUMENTED ORACLE LIMITATIONS — STOP / WAIT FOR GO BEFORE B3.**

Final capture candidate:

- Commit: `e91a826dce009336e06419d4556b569651cf7d21`
- Workflow: **Pac-Man B2 Ruffle Probe #19**
- Run: https://github.com/alexandresalazar89-blip/GameZone/actions/runs/35498392611
- Oracle artifact: `pacman-b2-oracle-suite`
- Artifact SHA-256: `438769ff8f7d0befb27c2d5a5c98ba2a2cf305a5e9f3d92a5976aaaec9e666bd`
- Probe artifact: `pacman-b2-ruffle-probe`
- Probe SHA-256: `7e86ef9ac84357c70774a673f09aae60e2dc3b307abb49a3def5ad2736d5e3c1`

## Ruffle fidelity probe

Pinned emulator:

`Ruffle 0.7.0-nightly.2026.9.19-nightly (28f2fccd19db20fe9797097e24aa1c83d815c398)`

The original SWF reports and renders as:

- SWF version 6 / AVM1;
- 360×420;
- 21 fps.

Observable probe result:

- title screen renders;
- maze renders completely;
- pellets render/disappear;
- Pac-Man moves from fixed replay input;
- four ghosts render and move;
- frightened visual state renders;
- score renders and changes;
- audio is present.

Probe audio:

- approximately **-12.9 dB mean**;
- **0 dB peak**;
- active, non-silent gameplay audio captured.

### Ruffle warnings and oracle boundary

Ruffle logs two relevant warning classes.

1. Legacy external `LoadVars` / promo content cannot be loaded from the local file context. This is unrelated to the Pac-Man gameplay loop and produced no gameplay anomaly.

2. Symphonia logs repeated MP3 `invalid main_data_begin` warnings. Audio remains observably present and continuous enough for sound-event reference, but because of this warning **B7 must not use sample-perfect PCM/waveform equality against Ruffle**. Use sound event presence/timing and source asset identity instead.

No visual/gameplay emulation defect was observed in the probe that invalidates Ruffle as the gameplay oracle.

## Fixed-frame input replay

All input schedules are JSON and use frame numbers at exactly **21 fps**.

The final suite's maximum dispatch lateness was below 1 ms; one SWF frame is ~47.619 ms.

The replay mechanism is therefore precise enough for B7. Ghost divergence remains attributable to the SWF's own `random()`, not the input injector.

Replay files:

- `oracle/replays/pellet_line.json`
- `oracle/replays/power_right.json`
- `oracle/replays/tunnel_left.json`
- `oracle/replays/tunnel_right.json`
- `oracle/replays/rng_motion.json`
- generated source-derived long route retained in the oracle artifact.

## Deterministic captures

### Pellet line — PASS

Visible score sequence:

`0 → 10 → 20 → 30 → 40 → 50 → 60 → 70`

This is a clean seven-pellet `+10` reference.

### Power pellet — PASS

Visible score sequence:

`0 → 10 → … → 160 → 170 → 220`

The final transition is:

`170 → 220 = +50`

which matches the clone's source behavior:

- base pellet: +10;
- power bonus: additional +40.

The captured image analysis also finds four frightened-blue ghost components in sampled frames approximately **186–252**. Later ghost paths are not deterministic.

### Left tunnel wrap — PASS

The shortened source-derived route reaches the tunnel before ghost interference.

Observable Pac-Man centroid around the edge transition:

- frame 193: approximately `x=47.4, y=184.2`
- frame 198: approximately `x=305.7, y=186.4`

This is the visible left-edge → right-edge wrap.

Exact source assignment remains:

`Pacman._x = OFFX + 336; pacX=28; nextX=27`

The exact numerical assignment comes from ActionScript; the screen oracle confirms the visible transition.

### Right tunnel wrap — PASS

Observable edge transition:

- frame 189: approximately `x=321.2, y=185.9`
- frame 194: approximately `x=70.9, y=182.6`

This is the visible right-edge → left-edge wrap.

Exact source assignment:

`Pacman._x = OFFX - 12; pacX=-1; nextX=0`

Again, the assignment is source-backed; the Ruffle capture validates the visible result.

## RNG captures

The identical `rng_motion` replay was captured **five times**.

Ghost positions differ between runs at the same observable frames, confirming in practice that a fixed input trace does not produce a stable ghost trajectory.

Therefore B7 policy remains:

- do **not** frame/pixel-diff ghost paths;
- validate only legal direction choices;
- validate the `Shape._visible` frightened random branch;
- validate `ghBest` tendency when the best branch is selected;
- validate source-faithful collision / ghost-eat / respawn transitions.

## Death / Game Over

Three long source-derived route attempts were captured.

All three visibly contain ghost interactions, death/life loss and ultimately **Game Over**, with differing outcomes due to RNG. These are valid references for the appearance/timing of death once a collision event is aligned, but not for the absolute global frame at which collision occurs.

## Level clear limitation

The long replay is derived from the actual 28×31 `Maze` literal and plans visits to all **244** pellet/power cells.

Three runs were captured.

All three were interrupted by RNG ghost deaths before a successful level clear.

Therefore:

**B2 does not claim a successful level-clear Ruffle oracle.**

No internal variables were patched and ghosts were not disabled to manufacture one.

## Extra life at 10,000 limitation

The rule is deterministic in source:

`s = Math.floor(score / 10000)`

and the extra-life branch is already mapped in `DETERMINISM_POLICY.json`.

However, an observable-only Ruffle scenario cannot cleanly isolate 10,000 points:

- one pellet-complete level yields **2600** deterministic pellet/power points;
- reaching 10,000 naturally needs multiple level clears and/or ghost/fruit scoring;
- those paths are exposed to ghost/fruit RNG.

B2 therefore **does not claim an extra-life visual capture**. B7 must verify this rule literally against the source rather than inventing a Ruffle state injection.

## Audio evidence

Every final captured scenario has non-silent `capture.wav`.

Use these files for:

- event presence;
- approximate onset/transition timing;
- correlation with visible pellet/power/death state.

Do not use sample-perfect waveform equality because of the documented Ruffle MP3 decoder warnings.

## Acceptance scenario registry

Canonical machine-readable scenario definitions and statuses:

`games/pacman/oracle/B2_SCENARIOS.json`

Every scenario is explicitly marked **DETERMINISTIC** or **RNG**, including scenarios that could not be isolated or completed without violating the observable-only rule.

## Gate

**B2 is COMPLETE with the explicit limitations above.**

The oracle contains only observable screen/audio evidence plus fixed replay input schedules.

**STOP HERE. B3 has NOT started. Wait for explicit user GO.**
