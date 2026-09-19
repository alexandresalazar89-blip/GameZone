# A2 Acceptance Gate

Status: **IMPLEMENTED AND VERIFIED — AWAITING USER GO BEFORE A3.**

A2 tested candidate:

`c69df4f23ae8157794687d1830576dbb5fb7c89d`

GitHub Actions run:

https://github.com/alexandresalazar89-blip/GameZone/actions/runs/35447683017

Public Web build:

https://alexandresalazar89-blip.github.io/GameZone/

## Contract implemented

- `GameMetadata`: id, title, version, controls text, thumbnail, entry scene, native size.
- `GameModule`: stable lifecycle `start(context)`, `pause()`, `resume()`, `teardown()`.
- Signals: `game_exited`, `score_changed(value)`, `state_saved(data)`.
- `GameContext`: game id, dedicated render viewport, scoped audio, scoped saves, semantic InputMap action names and controlled `exit()`.
- Registry-driven discovery from `games/registry.json`; the shell has no per-game launch branches.

## Shared services implemented

- `GameManager`
  - loads metadata/entry scenes from the registry;
  - owns lifecycle and cleanup;
  - creates a dedicated `SubViewport` per active game;
  - relays module score/save signals;
  - unloads the module and render surface on exit.
- `AudioManager`
  - creates a per-game bus and audio root;
  - exposes a scoped audio facade;
  - stops and removes game audio scope on unload.
- `SaveManager`
  - writes to `user://gamezone_saves/<game_id>/<slot>.json`;
  - exposes only a game-scoped facade to modules;
  - same slot names in different games remain isolated.

## Aspect-ratio contract

A game declares its own `native_size`. Its `SubViewport.size` remains that native size.

The shell renders its viewport texture through `TextureRect.STRETCH_KEEP_ASPECT_CENTERED` over a black host surface. This produces letterbox/pillarbox rather than stretching the module to the shell aspect ratio.

Verified headless against a 1000x600 host:

- `stub_wide`: native 320x180 -> display 1000x562.5.
- `stub_tall`: native 240x320 -> display 450x600.

The live 1440x900 browser build also reports `keep-aspect letterbox=true` for the tall game.

## Two independent stub modules

### stub_wide

- native 320x180 (16:9)
- semantic movement actions only
- A: score + scoped audio
- B: save to `contract_probe`
- Pause: local counter
- Back: `context.exit()`

### stub_tall

- native 240x320 (3:4)
- same semantic input contract
- same slot name `contract_probe`, but its own namespace
- independent score/state/audio lifecycle

## Automated contract evidence

From the A2 contract smoke:

```text
[A2_TEST] REGISTRY_OK count=2
[A2][AudioManager] begin game=stub_wide bus=Game_stub_wide
[A2][GameManager] launch id=stub_wide native=(320, 180)
[A2_TEST] WIDE_VIEWPORT_OK 320x180 display=(1000.0, 562.5)
[A2][AudioManager] end game=stub_wide
[A2_TEST] AUDIO_SCOPE_TEARDOWN_OK wide
[A2][AudioManager] begin game=stub_tall bus=Game_stub_tall
[A2][GameManager] launch id=stub_tall native=(240, 320)
[A2_TEST] TALL_VIEWPORT_OK 240x320 display=(450.0, 600.0)
[A2_TEST] SAVE_NAMESPACE_OK same-slot different-game
[A2][AudioManager] end game=stub_tall
[A2_TEST] CONTEXT_EXIT_OK
[A2_TEST] CONTRACT_SMOKE_OK
```

## Browser evidence

Local exported build:

- desktop Chromium: **PASS**
- Pixel 7 emulation: **PASS**
- `[A2] A2_BOOT_OK games=2`

Live GitHub Pages build:

- Godot 4.7.2 stable
- Emscripten 4.0.20
- **single-threaded**
- `[A2] A2_BOOT_OK games=2`
- `index.html`: HTTPS 200
- `index.pck`: HTTPS 200
- `index.wasm`: HTTPS 200
- COOP: absent
- COEP: absent
- page errors: none
- desktop Chromium live: **PASS**

## A1 caveat remains open

`BL-001` remains open in `BACKLOG.md`:

Physical gamepad hot-swap/detection/prompts/actions still require real hardware validation before any public release. A2 does not close or bypass that item.

## Gate

**STOP HERE. Do not start A3 until explicit user GO.**
