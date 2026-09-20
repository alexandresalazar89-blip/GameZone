# B3_ACCEPTANCE — Minimal Flash Runtime Shim in Godot

Status: **B3 COMPLETE / PASS — STOP / WAIT FOR GO BEFORE B4.**

Final tested code candidate:

`bbe85f72df5bea4b76e11588b587ffc148bb921f`

Validation workflow:

- **Platform Web Build and Evidence #105**
- Run ID: `35508227460`
- Build: PASS
- Deploy: PASS
- Live desktop smoke: PASS

## Scope

B3 implements only the Flash primitives required by this Pac-Man SWF.

It does **not** implement:

- maze construction;
- pellet/scoring logic;
- ghost AI;
- Pac-Man movement rules;
- game timelines/assets recreation;
- gameplay state machines.

Those remain B4/B5.

Pac-Man is **not** added to `games/registry.json`; hub integration remains B6.

## GameModule shell

Files:

- `games/pacman/pacman_game_module.gd`
- `games/pacman/main.tscn`
- `games/pacman/metadata.tres`

Native size:

`360 × 420`

The module is tested through the real A2 `GameManager` using a temporary registry.

Observed render metrics in a 1000×600 host:

`display=(514.2857, 600.0)`

This proves native 360×420 rendering with keep-aspect/pillarbox behavior.

## 1. Fixed Flash clock — PASS

Implementation:

`games/pacman/runtime/flash_fixed_clock.gd`

Contract:

- fixed **21 fps**;
- fixed step **1 / 21 s**;
- ~**47.619047619 ms** per tick;
- elapsed wall time is only accumulated to decide how many fixed ticks to emit;
- gameplay receives ticks, not variable delta.

Evidence:

```text
[B3_CLOCK] PASS fps=21 step_ms=47.6190476190476 ticks=42
[B3_MODULE] ... fixed_ticks=21
```

The isolated test feeds exactly two seconds of elapsed time and obtains exactly 42 ticks.

The `PacmanGameModule` dispatches 21 fixed `flash_enter_frame` ticks for one second.

## 2. MovieClip-equivalent — PASS

Implementation:

`games/pacman/runtime/flash_movie_clip.gd`

Implemented semantics:

- `_x`
- `_y`
- `_visible`
- `_currentframe`
- `gotoAndPlay(target)`
- `gotoAndStop(target)`
- keyed attached children for Flash-style dynamic clip access.

Real source labels used in tests:

- Pac-Man sprite 40: `Die -> frame 6`
- Snd sprite 92:
  - `Chomp1 -> 2`
  - `Chomp2 -> 4`
  - `EatGhost -> 6`
  - `EatFruit -> 19`

Dynamic children prove the source-shaped access pattern equivalent to:

- `Ghost[1]`
- `Ghost["K1"]`

Evidence:

```text
[B3_MOVIECLIP] PASS x=123.5 y=87.25 Die=6 EatGhost=6 keyed_children=2
```

## 3. Shape-level hitTest — PASS

Implementation:

`games/pacman/runtime/flash_hit_shape.gd`

Hit regions are explicit polygons transformed into world space and intersected with `Geometry2D.intersect_polygons`.

The test includes a stronger guard than simple overlap:

- two polygon bounding boxes overlap;
- their actual polygons do not;
- `hitTest` correctly returns false.

It then verifies real polygon overlap returns true and separated shapes return false.

Evidence:

```text
[B3_HITTEST] PASS polygon_overlap=true separated=false bbox_false_positive_rejected=true
```

This is appropriate for later `Pacman.Hit.hitTest(Shape.Hit)`; sprite bounding boxes are not used.

## 4. Shared semantic input — PASS

Implementation:

`games/pacman/runtime/pacman_input_reader.gd`

The reader consumes only the A1/A2 shared action names from `GameContext`:

- `move_up -> 0`
- `move_right -> 1`
- `move_down -> 2`
- `move_left -> 3`

These direction numbers match the decompiled source's `setPacMove(d)` convention.

No raw keyboard, touch, mouse or gamepad device code exists in the Pac-Man runtime reader.

Evidence:

```text
[B3_INPUT] PASS shared_actions=move_up,move_right,move_down,move_left
```

Keyboard/touch/gamepad device mapping remains owned by the existing platform InputMap.

## 5. Scoped audio — PASS

Implementation:

`games/pacman/runtime/flash_audio_clip.gd`

The unit test uses the real source timeline mapping:

- Snd `EatGhost` label -> frame 6;
- frame 6 starts SWF sound ID 90;
- extracted asset: `games/pacman/decompiled/sounds/90.mp3`.

The trigger is routed through the existing A2 `GameAudioScope`/AudioManager bus.

Evidence:

```text
[B3_AUDIO] PASS label=EatGhost asset=90.mp3 bus=Game_pacman_b3_audio_test teardown_silence=true
```

The test verifies:

- an `AudioStreamPlayer` is created;
- it uses the game-scoped bus;
- the bus exists while the scope is active;
- `end_game` removes the bus/scope;
- no player remains audible after teardown.

## 6. Flash random(n) — PASS

Implementation:

`games/pacman/runtime/flash_random.gd`

Semantics:

`random(n) = floor(rand * n)`

with result range:

`0 .. n-1`

The wrapper is:

- nondeterministically randomized by default;
- optionally seedable for deterministic port-side tests.

`not_random(n)` is exactly:

`random(n) == 0`

which represents the source idiom `!random(n)`.

Evidence:

```text
[B3_RANDOM] PASS seeded_repeatable=true range=[0,n-1] not_random=1/n_semantics
```

The fixed-seed test compares 128 values from two independent generators and verifies identical sequences.

## GameModule / SubViewport integration — PASS

The integration test creates a temporary one-game registry pointing to Pac-Man metadata and launches through the real `GameManager`.

Evidence:

```text
[B3_MODULE] PASS native=360x420 display=(514.2857, 600.0) fixed_ticks=21 registry_permanent_unchanged=true
```

It also verifies A2 audio teardown on unload.

The permanent platform registry remains unchanged, so the public hub still reports exactly three A4 games.

## Single-threaded Web regression — PASS

The normal platform export remained single-threaded:

```text
Build configuration: Emscripten 4.0.20, single-threaded, no GDExtension support.
```

The same workflow passed local desktop/mobile Web smoke and deployed GitHub Pages.

Live smoke after B3:

```text
[A4] A4_BOOT_OK games=3 packs=1 cards=3
[A4_WEB_TEST] ALL_GAMES_RELAUNCH_FLOW_OK
[WEB_TEST] RESOURCE_OK index.html 200
[WEB_TEST] RESOURCE_OK index.pck 200
[WEB_TEST] RESOURCE_OK index.wasm 200
[WEB_TEST] RESOURCE_OK packs/stub_packed.pck 200
[WEB_TEST] COOP_COEP_ABSENT
```

This confirms B3 did not alter the launcher or the single-threaded Web contract.

## Unit-test files

- `tests/pacman_b3/test_fixed_clock.gd`
- `tests/pacman_b3/test_movie_clip.gd`
- `tests/pacman_b3/test_hit_shape.gd`
- `tests/pacman_b3/test_input_reader.gd`
- `tests/pacman_b3/test_audio.gd`
- `tests/pacman_b3/test_random.gd`
- `tests/pacman_b3/test_module_contract.gd`

These are now part of the normal platform CI.

## Gate

**B3 is CLOSED / PASS.**

No B4 asset/timeline recreation and no B5 gameplay logic has started.

**STOP HERE. Wait for explicit user GO before B4.**
