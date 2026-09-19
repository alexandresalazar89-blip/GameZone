# GameZone Platform Plan

Status: **A0 scaffold complete — awaiting approval before A1**

Repository: `alexandresalazar89-blip/GameZone`

Target: one Godot 4 Web/HTML5/WASM application that acts as a reusable launcher for isolated game modules. The first real module will be a faithful port of the supplied `pacman.swf`.

## 1. Fixed goals

- Godot 4 + GDScript only.
- One browser build for desktop, tablet, and phone.
- Keyboard/mouse, touch, and gamepad converge on shared InputMap actions.
- Shell code does not change when a new game is added.
- Games are isolated behind a stable module contract.
- Development games live under `res://games/<id>/`.
- Packaged games can be delivered as `.pck` files and registered externally.
- Pac-Man is a source-faithful port, not a remake.
- Decompiled ActionScript and extracted SWF assets are the only source of truth for Pac-Man behavior/content.

## 2. A0 decisions now committed

### Rendering and scaling

The project uses:

- renderer: `gl_compatibility`
- base logical viewport: `1280x720`
- stretch mode: `canvas_items`
- stretch aspect: `expand`

`expand` is the platform default because the launcher must fill different desktop, tablet, and phone aspect ratios without letterboxing the shell. Individual game modules will receive a bounded render surface from the shell so a game can preserve its own native aspect ratio when fidelity requires it.

### Web threading

The initial Web export preset is **single-threaded**.

Reason: it avoids requiring COOP/COEP headers and therefore keeps the first deployment compatible with ordinary static hosting such as GitHub Pages. If a future module genuinely needs Web threads, that will be a deliberate platform change with documented cross-origin isolation requirements.

### Current scaffold

```text
/
├── project.godot
├── export_presets.cfg
├── PLATFORM_PLAN.md
├── shell/
│   └── main.tscn
├── shared/
│   └── .gitkeep
├── games/
│   └── pacman/
│       └── .gitkeep
└── packs/
    └── .gitkeep
```

The A0 shell is intentionally inert. It contains no launcher behavior, InputMap setup, services, game contract, or Pac-Man logic.

## 3. Planned architecture

```text
Browser
└── Godot Web runtime
    └── Shell
        ├── Hub UI
        ├── Global overlay / Back-to-hub affordance
        ├── Touch controls
        └── GameManager
            └── Game host / dedicated SubViewport
                └── One active GameModule
                    ├── game-local scene tree
                    ├── game-local audio route
                    └── GameContext references only
```

The shell owns navigation and shared services. A game owns only its module subtree and the render target/context granted to it.

## 4. Phase A1 — Web and unified input foundation

A1 will be implemented before the module contract because input/web constraints affect every game.

Planned semantic actions:

- `move_up`
- `move_down`
- `move_left`
- `move_right`
- `action_a`
- `action_b`
- `pause`
- `back`

Bindings will include keyboard plus joypad buttons/axes. Touch UI will inject the same actions; games will never read raw keycodes, mouse buttons, screen touches, or joypad buttons directly.

A1 will also provide:

- reusable touch d-pad/stick + buttons;
- automatic touch UI visibility;
- input-device activity tracking for prompt changes;
- gamepad connect/disconnect and hot-swap handling;
- first-user-gesture audio unlock/resume;
- user-gesture-only fullscreen entry;
- tab blur / visibility pause policy;
- real-browser verification of Godot joypad events;
- documentation of any browser-specific limitations.

**Gate:** stop for approval after the input/web foundation is demonstrated.

## 5. Phase A2 — Stable game-module contract

Planned base API:

```text
GameModule
  metadata
  start(context)
  pause()
  resume()
  teardown()

signals
  game_exited
  score_changed(value)
  state_saved(data)
```

Planned `GameContext` capabilities:

- assigned render target / viewport;
- shared audio facade;
- namespaced save facade;
- semantic input action names;
- profile/settings access;
- controlled `exit()` back to the hub.

Isolation rules:

1. A module may not manipulate shell nodes.
2. A module may not write another game's save namespace.
3. A module may not leave audio or timers running after teardown.
4. A module may not register permanent globals/autoloads.
5. A module receives shell services through `GameContext`, not by hard-coded scene paths.
6. The shell instantiates entry scenes from metadata/registry data, not from game-specific branches in shell code.

**Gate:** stop for approval of the concrete contract before implementing services around it.

## 6. Phase A3 — Shared services

Planned autoloads/services:

- `GameManager`: registry, load, instance, unload, cleanup.
- `AudioManager`: master and per-game buses; stop/fade/cleanup on exit; Web unlock coordination.
- `SaveManager`: per-game slots under a game-id namespace using Web-persistent `user://` storage.
- `ProfileManager` / settings: player profile, global options, input remapping.

The service API exposed to games will be narrower than the full autoload API.

## 7. Phase A4 — Responsive shell

Hub requirements:

- responsive game grid;
- thumbnail/title/Play presentation;
- settings panel;
- controller focus navigation;
- touch navigation;
- keyboard navigation;
- persistent shell-owned Back-to-hub affordance while a game is active;
- clean transition: hub → game → teardown → hub.

No game-specific code will live in the hub.

## 8. Phase A5 — Packaging and registry

Development layout:

```text
res://games/<id>/
    game metadata
    entry scene
    source/assets
```

Packaged layout:

```text
/packs/<id>.pck
```

A registry manifest will describe installed games and their metadata/entry point. Adding a game may require adding/updating registry data, but **never editing shell source code**.

For Web runtime packs, A5 will explicitly prove the complete path rather than assume it:

1. fetch pack bytes over HTTP;
2. persist them into an accessible virtual filesystem location if required;
3. call Godot's resource-pack loader;
4. load the entry scene exposed by registry metadata;
5. unload the game and prove clean relaunch.

`ADD_A_GAME.md` will document both source-folder and `.pck` workflows.

## 9. Phase A6 — Platform acceptance

Before Pac-Man porting starts, two trivial independent stub games will prove:

- both appear through the registry;
- both launch without shell changes;
- both receive only semantic actions;
- keyboard works;
- gamepad works in a real browser;
- touch controls work on mobile/tablet;
- controller/touch can navigate the hub;
- game exit returns to the hub;
- relaunch is clean;
- one game's state does not leak to the other;
- one game's audio stops on teardown;
- responsive layout works across representative phone/tablet/desktop sizes;
- runtime-pack loading is exercised at least once.

Only after A6 passes does Part B begin.

## 10. Part B — Pac-Man port discipline

### B0 — Triage

Inspect the actual SWF and record:

- SWF version;
- AS1/AS2/AS3;
- frame rate;
- stage size;
- symbol count;
- sound count;
- obfuscation/decompiler quality.

Output: `games/pacman/PACMAN_PORT_PLAN.md`.

### B1 — Extraction

JPEXS FFDec exports all source and assets into an immutable raw area:

```text
games/pacman/
├── decompiled/   # raw, never edited
├── assets/       # prepared/imported assets
└── src/          # Godot port
```

Outputs:

- `ASSET_MANIFEST.md`
- `SYMBOL_MAP.md`
- `TIMELINE_MAP.md`

### B2 — Ruffle oracle

Run the original SWF in Ruffle and capture deterministic scenarios with scripted input. Reference captures will cover at least:

- initial spawn positions;
- ordinary movement;
- pellet scoring;
- power-pellet scoring/effects;
- ghost state/timing behavior actually present in this SWF;
- death sequence;
- level advance.

No arcade-Pac-Man assumptions may replace observation/source.

### B3 — Minimal Flash runtime shim

Implement only Flash semantics proven necessary by this SWF:

- fixed timestep at the SWF frame rate;
- timeline/sprite-frame stepping;
- Flash coordinates and transforms;
- alpha/rotation/scale adapters;
- display depth semantics required by this game;
- hit-test behavior required by this game;
- grid/tile support only if source requires it;
- shared semantic input actions;
- game-scoped audio hooks.

### B4/B5 — Asset reconstruction and 1:1 logic translation

- Preserve source symbol names and frame labels.
- Preserve ActionScript function/variable names where practical.
- Preserve order of operations and numerical behavior.
- Map `onEnterFrame` to the fixed SWF-step loop.
- Do not replace logic with famous arcade algorithms.
- Unclear/obfuscated behavior is a hard stop for review rather than a license to guess.

### B6 — Platform integration

Pac-Man implements the exact GameModule contract and uses shared actions only.

### B7 — Verification

Every divergence is traced back to source/oracle evidence.

Output `VERIFICATION.md` with:

- scenario;
- expected observation;
- Godot observation;
- frame/state diff;
- cause;
- source reference;
- fix.

`TRACEABILITY.md` maps ported behavior to ActionScript/symbol/timeline source.

### B8 — Browser packaging

Verify Pac-Man from the hub on desktop and mobile and exercise runtime-pack delivery if supported by the proven A5 path.

## 11. Required final documentation

Platform:

- `PLATFORM_PLAN.md`
- `ADD_A_GAME.md`
- shell/shared source
- two stub games
- Web export

Pac-Man:

- raw decompilation
- extracted/imported assets
- port source
- `PACMAN_PORT_PLAN.md`
- `ASSET_MANIFEST.md`
- `SYMBOL_MAP.md`
- `TIMELINE_MAP.md`
- `TRACEABILITY.md`
- `VERIFICATION.md`
- `FIDELITY_NOTES.md`

Root:

- final `README.md` with build/run, controls, browser/device support, architecture, and serving instructions.

## 12. Commit discipline

Commits remain small and system-scoped. After Part A becomes runnable, every subsequent commit must preserve a runnable shell unless a commit is explicitly marked as a transient development checkpoint.

Suggested prefixes:

- `chore(a0): ...`
- `feat(a1-input): ...`
- `feat(a2-contract): ...`
- `feat(a3-services): ...`
- `feat(a4-shell): ...`
- `feat(a5-packs): ...`
- `test(a6): ...`
- `port(pacman-bN): ...`

## 13. Review gates

Mandatory stop points:

1. **Now — A0 plan/scaffold approval.**
2. A1 input/web foundation approval.
3. A2 concrete module-contract approval.
4. Any Pac-Man decompilation ambiguity that would otherwise require invented behavior.
5. End of each B phase with evidence before continuing.

## 14. Known future prerequisite

The actual `pacman.swf` must be available to the working environment/repository before B0. The placeholder `FIRST_GAME_SWF: [path to pacman.swf]` is not treated as a real path, and no Pac-Man behavior will be inferred before the file is supplied.

---

**Current gate:** A0 is complete. No A1 work should begin until approval.
