# A4 Acceptance Gate — Runtime PCK Packaging + Platform Acceptance

Status: **CLOSED / PASS.**

A4 is accepted after automated/headless validation, live GitHub Pages validation, physical-phone validation reported PASS by the user, and the final desktop mouse-routing regression fix.

Tested final A4 code candidate:

`69a4ae4ba71e8744a514008aec4e4f0958047104`

Final GitHub Actions run:

https://github.com/alexandresalazar89-blip/GameZone/actions/runs/35455929887

Public Web build:

https://alexandresalazar89-blip.github.io/GameZone/

Documentation-only commits after the tested code candidate do not change the runtime candidate.

## Final gate status

- Registry-driven hub: ✅
- In-tree modules: ✅
- Runtime `.pck` modules: ✅
- Runtime Web HTTP fetch -> VFS -> `load_resource_pack()`: ✅
- Packed game appears without shell-specific integration: ✅
- Build/staging of packs driven by registry: ✅
- Launch / exit / relaunch all games: ✅
- Save namespace isolation: ✅
- Audio teardown: ✅
- Keep-aspect / letterbox: ✅
- Single-threaded Web export: ✅
- COOP absent: ✅
- COEP absent: ✅
- Desktop Chromium live: ✅
- Desktop mouse routing regression: ✅
- Keyboard focus launch: ✅
- Gamepad navigation/actions in emulation: ✅
- Physical phone A4 test: ✅
- Physical gamepad: ⏸️ deferred — BL-001
- Input remapping UI: ⏸️ backlog — BL-002

## Runtime PCK contract

The registry accepts two source types:

- `source: "tree"`: resources ship in the main export.
- `source: "pack"`: resources ship as a separate runtime PCK.

For Web runtime packs:

1. load the base registry;
2. resolve `pack_url` relative to the current page;
3. call `window.fetch(pack_url)`;
4. obtain `response.arrayBuffer()`;
5. convert to `PackedByteArray`;
6. write bytes to `user://gamezone_packs/<id>.pck`;
7. mount with `ProjectSettings.load_resource_pack(..., false)`;
8. resolve the packed metadata and entry scene;
9. add the game to the normal `get_installed_games()` list;
10. let the existing hub create its card automatically.

The runtime pack cannot replace existing shell resources because `load_resource_pack` is called with replacement disabled.

## ADD_A_GAME proof

`ADD_A_GAME.md` was followed to add `stub_packed`.

The resulting registry contains:

- `stub_tall` — in-tree;
- `stub_wide` — in-tree;
- `stub_packed` — runtime PCK.

No per-game launch branch was added to the shell.

Pack build and Web staging are also registry-driven:

- `tools/build_runtime_packs.gd`
- `tools/stage_runtime_packs.gd`

The workflow no longer requires a hardcoded copy command for each new runtime pack.

## Runtime-pack proof

The A4 smoke verified that the packed resource path is absent before mounting and becomes available only after `load_resource_pack()`.

```text
[A4_PACK_BUILD] PACK_BUILT id=stub_packed files=3 bytes=4440
[A4_TEST] PACK_TARGET_ABSENT_BEFORE_LOAD_OK
[A4] PACK_LOAD_OK id=stub_packed
[A4_TEST] PACK_RUNTIME_LOAD_OK games=3 packs=1
[A4_TEST] PACK_KEEP_ASPECT_OK native=256x192 display=(800.0, 600.0)
[A4_TEST] PACK_EXIT_CLEAN_OK
[A4_TEST] PACK_RELAUNCH_OK
[A4_TEST] SAVE_NAMESPACE_ALL_GAMES_OK
[A4_TEST] ALL_GAMES_CYCLE_OK
[A4_TEST] PLATFORM_ACCEPTANCE_SMOKE_OK
[A4_PACK_STAGE] PACK_STAGED id=stub_packed bytes=4440 url=packs/stub_packed.pck
[A4_PACK_STAGE] ALL_PACKS_STAGED_OK count=1
```

## Final desktop mouse-routing regression

Physical desktop testing discovered a real A4 bug:

- `action_a` includes left mouse click;
- the hub global `_input` handler treated any `action_a` as "launch focused card";
- therefore a click anywhere in the hub launched whichever card had focus.

Final fix:

- focus-based `action_a` activation now accepts only `InputEventKey` or `InputEventJoypadButton`;
- mouse and touch remain on the existing direct card `_on_card_gui_input` path;
- `_on_card_gui_input` was not changed.

Headless regression evidence:

```text
[A4_TEST] GLOBAL_MOUSE_ACTION_IGNORED_FOR_FOCUS_LAUNCH_OK focused=stub_packed
[A3_TEST] KEYBOARD_FOCUS_NAV_OK first=stub_packed second=stub_tall
[A3_TEST] KEYBOARD_ACTION_A_LAUNCH_OK id=stub_tall
[A3_TEST] GAMEPAD_FOCUS_NAV_EMULATION_OK id=stub_packed
[A3_TEST] GAMEPAD_ACTIONS_EMULATION_OK id=stub_packed
```

## Final browser evidence — local

Desktop Chromium:

```text
[A4] A4_BOOT_OK games=3 packs=1 cards=3
[A4_WEB_TEST] EMPTY_HUB_CLICK_NO_LAUNCH_OK
[A4_WEB_TEST] CARD_CLICK_LAUNCH_OK id=stub_packed
[A4_WEB_TEST] ALL_GAMES_RELAUNCH_FLOW_OK {
  "allGames":["stub_packed","stub_tall","stub_wide"],
  "rounds":[
    ["stub_packed","stub_tall","stub_wide"],
    ["stub_packed","stub_tall","stub_wide"]
  ],
  "launchCount":7,
  "hubReturnCount":7,
  "relaunchEach":true,
  "audioTeardown":true
}
```

Pixel 7 emulation after the desktop fix:

```text
[A4] A4_BOOT_OK games=3 packs=1 cards=3
[A4_WEB_TEST] MOBILE_CARD_TOUCH_LAUNCH_OK id=stub_packed
```

This verifies that restricting global focus activation to keyboard/gamepad did not break the card touch path.

## Final GitHub Pages live evidence

The final desktop Chromium test ran against the deployed HTTPS site:

```text
[A4] A4_BOOT_OK games=3 packs=1 cards=3
[A4_WEB_TEST] EMPTY_HUB_CLICK_NO_LAUNCH_OK
[A4_WEB_TEST] CARD_CLICK_LAUNCH_OK id=stub_packed
[A4_WEB_TEST] ALL_GAMES_RELAUNCH_FLOW_OK {
  "allGames":["stub_packed","stub_tall","stub_wide"],
  "rounds":[
    ["stub_packed","stub_tall","stub_wide"],
    ["stub_packed","stub_tall","stub_wide"]
  ],
  "launchCount":7,
  "hubReturnCount":7,
  "relaunchEach":true,
  "audioTeardown":true
}
[WEB_TEST] RESOURCE_OK index.html 200 https://alexandresalazar89-blip.github.io/GameZone/index.html
[WEB_TEST] RESOURCE_OK index.pck 200 https://alexandresalazar89-blip.github.io/GameZone/index.pck
[WEB_TEST] RESOURCE_OK index.wasm 200 https://alexandresalazar89-blip.github.io/GameZone/index.wasm
[WEB_TEST] RESOURCE_OK packs/stub_packed.pck 200 https://alexandresalazar89-blip.github.io/GameZone/packs/stub_packed.pck
[WEB_TEST] HTTPS_RESOURCES_OK
[WEB_TEST] COOP_COEP_ABSENT
```

Run #64 conclusions:

- build: **success**
- A1 smoke: **success**
- A2 smoke: **success**
- A3 hub + input regression smoke: **success**
- A4 runtime pack smoke: **success**
- local desktop browser: **success**
- local Pixel 7 emulation: **success**
- Pages deploy: **success**
- live desktop Chromium: **success**

## Physical phone result

User report:

```text
PHONE A4: PASS em toda a linha (telemóvel OK).
```

This closes the physical-phone portion of A4.

## Rendering and isolation

- `stub_packed`: native 256x192, keep-aspect verified.
- `stub_tall`: native 240x320.
- `stub_wide`: native 320x180.
- Each game keeps its dedicated `SubViewport`.
- Letterbox/pillarbox remains in effect instead of stretching.
- Save namespaces remain per game.
- Audio scopes return to zero on teardown.

## Versions

See `PLATFORM_VERSIONS.md`.

Current tested platform:

- Godot **4.7.2.stable.official.ed1daf0bf**
- Emscripten **4.0.20**
- Web **single-threaded**
- Registry schema **2**

## Deferred backlog remains mandatory

- `BL-001` — physical gamepad hot-swap/detection/prompts/actions. Still open; no physical hardware was available.
- `BL-002` — input remapping UI. Still open.

Neither backlog item is closed, removed, or bypassed by A4 acceptance.

## Gate

**A4 is CLOSED / PASS.**

**STOP HERE. Part B / Pac-Man has NOT been started and requires an explicit user GO.**
